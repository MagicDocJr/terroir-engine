#!/usr/bin/env python3
"""Builds the ambience beds and one-shots the 3D views play, into game/assets3d/audio/ (gitignored).

Usage: fetch_audio.py <game/assets3d/audio> [--force]

Sources are CC0 recordings (BigSoundBank by Joseph Sardin, and one Wikimedia Commons file), each
licence checked on the file's own page before use; sounds without a good CC0 recording are
synthesised here. Pure Python 3 stdlib (no numpy/ffmpeg): source WAVs are read, resampled to
44.1 kHz 16-bit, filtered, cut, loop-crossfaded and levelled, then written with audio.json
(manifest) and CREDITS.md.

Idempotent and deterministic: downloads (and their licence metadata) are cached in <out>/.src/ and
skipped when present; an output is rebuilt only if its recipe changed (hash in audio.json) or with
--force. Randomness uses fixed seeds.
"""
import array, hashlib, json, math, os, random, re, struct, sys, urllib.parse, urllib.request

VERSION = 1  # bump to rebuild every output
RATE = 44100
UA = {"User-Agent": "terroir-engine (private hobby project; CC0 assets)"}
BSB = "https://bigsoundbank.com/"
COMMONS_API = "https://commons.wikimedia.org/w/api.php?"

# ---------------------------------------------------------------------------------------------
# Recipes. Segment times are seconds in the source recording, chosen by analysing the level and
# band energies of each file (steady stretches, no thunder/traffic/handling noise).
# ---------------------------------------------------------------------------------------------
BSB_PAGES = {
    "0907": "wind-in-shrub-s0907.html",           # Wind in shrub (countryside), stereo 180 s
    "0100": "forest-s0100.html",                  # Forest: varied birdsong, calm weather, stereo
    "0823": "small-stream-s0823.html",            # Small (mountain) stream, stereo, very steady
    "1552": "tractor-and-rollers-s1552.html",     # Tractor dragging rollers in a field
    "0492": "small-broth-in-a-pot-s0492.html",    # Liquid simmering: dense small bubbles
    "0150": "water-bubbles-s0150.html",           # Bubbles blown through liquid: gurgles
    "1157": "fridge-s1157.html",                  # Refrigerator compressor hum
    "0710": "electric-pump-water-s0710.html",     # Electric pump moving water
    "0085": "step-on-gravel-s0085.html",          # Footsteps on a gravel path
    "1318": "fast-steps-on-concrete-s1318.html",  # Shoe steps on concrete
    "1486": "air-leak-s1486.html",                # Air leak (hiss)
}
COMMONS_FILES = {
    "rain": "Light Rain Distant Thunder July 5th 2016.wav",  # rain on leaves in deep woods, stereo
}

BEDS = {
    # name: dict(src=[(kind, key, start, end, gain_db)], mono, hp, lp, loop seconds, target rms)
    "wind_leaves": dict(src=[("bsb", "0907", 3.0, 39.5, 0)], hp=60, loop=35.0, rms=-20),
    # skips 24-33 s, where one bird sings right at the mic and would stand out on every repeat
    "birds_day": dict(src=[("bsb", "0100", [(0.3, 24.0), (33.5, 54.0)], None, 0)], hp=250, loop=40.0, rms=-20),
    "rain": dict(src=[("commons", "rain", 58.0, 94.5, 0)], hp=150, loop=35.0, rms=-20,
                 limit_db=14, release=0.03),  # sparse close drops: brief, fast-release limiting
    "river": dict(src=[("bsb", "0823", 10.0, 41.5, 0)], hp=40, lp1=6000, loop=30.0, rms=-20),
    "tractor_distant": dict(src=[("bsb", "1552", 60.0, 97.5, 0)], mono=True, hp=40, lp1=5000,
                            agc=0.6, loop=36.0, rms=-20),
    "ferment_bubbling": dict(src=[("bsb", "0492", [(0.3, 13.5), (1.0, 9.8)], None, 0),
                                  ("bsb", "0150", 3.0, 24.5, -8)], mono=True, hp=80, loop=20.0, rms=-20),
    "cooling_hum": dict(src=[("bsb", "1157", 2.0, 33.5, 0)], mono=True, hp=30, loop=30.0, rms=-28),
    "pump": dict(src=[("bsb", "0710", [(0.2, 14.2), (2.0, 9.5)], None, 0)], mono=True, hp=40,
                 loop=19.5, rms=-20),
    "cellar_tone": dict(synth="cellar_tone", loop=30.0, rms=-28),
}
ONESHOTS = {
    # step sets: heel strikes detected automatically, the 5 most consistent kept
    "step_soil": dict(src=("bsb", "0085"), count=5, gap=0.45, max_len=0.40, hp=70),
    "step_concrete": dict(src=("bsb", "1318"), count=5, gap=0.45, max_len=0.42, hp=70),
    "co2_hiss": dict(src=("bsb", "1486"), cut=(5.0, 6.0), hp=300),
    "drip": dict(synth="drip", count=3),
}
XFADE = 1.5          # loop crossfade, seconds
PEAK_CEIL = -1.0     # dBFS ceiling for beds
MAX_LIMIT_DB = 6.0   # at most this much peak limiting to approach the RMS target
ONESHOT_PEAK = -6.0  # dBFS


# ---------------------------------------------------------------------------------------------
# Downloads + licence checks
# ---------------------------------------------------------------------------------------------
def http(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120)


def download(url, path):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with http(url) as r, open(path + ".part", "wb") as f:
        while True:
            b = r.read(1 << 20)
            if not b:
                break
            f.write(b)
    os.replace(path + ".part", path)
    print("  downloaded", os.path.basename(path))


def bsb_meta(cache, page):
    """Reads a BigSoundBank sound page, checks it is CC0 and returns author, title and WAV url.
    Cached as JSON so re-runs need no network."""
    sid = re.search(r"-s(\d{4})\.html$", page).group(1)
    path = os.path.join(cache, f"bsb_{sid}.json")
    if os.path.exists(path):
        return json.load(open(path))
    html = http(BSB + page).read().decode("utf-8", "replace")
    obj = faq = None
    for m in re.finditer(r"<script type=.application/ld\+json.>(.*?)</script>", html, re.S):
        d = json.loads(m.group(1))
        if d.get("@type") == "AudioObject":
            obj = d
        elif d.get("@type") == "FAQPage":
            faq = json.dumps(d)
    if not (obj and faq):
        raise SystemExit(f"could not parse {BSB + page}")
    ok = (obj.get("license") == BSB + "licenses.html" and obj.get("isAccessibleForFree") is True
          and "CC0" in faq and "Free and Royalty Free" in html)
    if not ok:
        raise SystemExit(f"licence check failed for {BSB + page}")
    meta = {"page": BSB + page, "title": obj["name"].split(" — ")[0], "description": obj.get("description", ""),
            "author": obj["author"]["name"] + " (BigSoundBank)",
            "licence": "CC0 1.0 (stated on the sound page; " + BSB + "licenses.html)",
            "wav": [e["contentUrl"] for e in obj["encoding"] if e["encodingFormat"] == "audio/wav"][0]}
    os.makedirs(cache, exist_ok=True)
    json.dump(meta, open(path, "w"), indent=1)
    return meta


def commons_meta(cache, key, title):
    path = os.path.join(cache, f"commons_{key}.json")
    if os.path.exists(path):
        return json.load(open(path))
    q = urllib.parse.urlencode({"action": "query", "format": "json", "titles": "File:" + title, "prop": "imageinfo",
                                "iiprop": "url|extmetadata"})
    page = next(iter(json.load(http(COMMONS_API + q))["query"]["pages"].values()))
    ii = page["imageinfo"][0]
    em = {k: re.sub(r"<[^>]+>", "", str(v["value"])).strip() for k, v in ii["extmetadata"].items()}
    lic = em.get("LicenseShortName", "")
    if lic not in ("CC0", "Public domain"):
        raise SystemExit(f"licence check failed for {title}: {lic}")
    artist = em.get("Artist", "?")
    if artist.startswith("http"):  # e.g. a freesound profile URL: keep the user name
        artist = artist.rstrip("/").rsplit("/", 1)[-1]
    meta = {"page": ii["descriptionurl"], "title": title, "description": em.get("ImageDescription", "")[:300],
            "author": artist + " (via Wikimedia Commons; original " + em.get("Credit", "") + ")",
            "licence": lic + " (" + em.get("UsageTerms", "") + ")", "wav": ii["url"].split("?")[0]}
    os.makedirs(cache, exist_ok=True)
    json.dump(meta, open(path, "w"), indent=1)
    return meta


def source(cache, kind, key):
    """Returns (meta, local wav path), downloading on first use."""
    if kind == "bsb":
        meta, wav = bsb_meta(cache, BSB_PAGES[key]), os.path.join(cache, f"bsb_{key}.wav")
    else:
        meta, wav = commons_meta(cache, key, COMMONS_FILES[key]), os.path.join(cache, f"commons_{key}.wav")
    download(meta["wav"], wav)
    return meta, wav


# ---------------------------------------------------------------------------------------------
# WAV I/O
# ---------------------------------------------------------------------------------------------
def read_wav(path, start=0.0, end=None):
    """Minimal RIFF reader (PCM 16/24/32-bit int, 32-bit float, WAVE_FORMAT_EXTENSIBLE) that decodes
    only [start, end) seconds. Returns (rate, [channel lists of floats in -1..1])."""
    with open(path, "rb") as f:
        head = f.read(12)
        assert head[:4] == b"RIFF" and head[8:12] == b"WAVE", path
        fmt = None
        while True:
            h = f.read(8)
            if len(h) < 8:
                raise SystemExit(f"no data chunk in {path}")
            cid, size = h[:4], struct.unpack("<I", h[4:])[0]
            if cid == b"fmt ":
                body = f.read(size + (size & 1))
                tag, ch, rate, _, _, bits = struct.unpack("<HHIIHH", body[:16])
                if tag == 0xFFFE:
                    tag = struct.unpack("<H", body[24:26])[0]
                fmt = (tag, ch, rate, bits)
            elif cid == b"data":
                tag, ch, rate, bits = fmt
                bpf = ch * bits // 8
                total = size // bpf
                a = max(0, int(start * rate))
                b = total if end is None else min(total, int(end * rate))
                f.seek(a * bpf, 1)
                raw = f.read((b - a) * bpf)
                break
            else:
                f.seek(size + (size & 1), 1)
    if tag == 3 and bits == 32:
        vals = array.array("f"); vals.frombytes(raw)
    elif tag == 1 and bits == 16:
        a16 = array.array("h"); a16.frombytes(raw); vals = [v / 32768.0 for v in a16]
    elif tag == 1 and bits in (24, 32):
        if bits == 24:
            n = len(raw) // 3
            buf = bytearray(n * 4)
            buf[1::4] = raw[0::3]; buf[2::4] = raw[1::3]; buf[3::4] = raw[2::3]
            raw = bytes(buf)
        a32 = array.array("i"); a32.frombytes(raw); vals = [v / 2147483648.0 for v in a32]
    else:
        raise SystemExit(f"unsupported wav format {fmt} in {path}")
    return rate, [list(vals[c::ch]) for c in range(ch)]


def write_wav(path, chans, seed):
    """16-bit PCM with TPDF dither (seeded, so output is byte-identical between runs)."""
    rng = random.Random(seed)
    n, nc = len(chans[0]), len(chans)
    out = array.array("h", bytes(2 * n * nc))
    for c, x in enumerate(chans):
        for i, v in enumerate(x):
            s = int(round(v * 32767.0 + (rng.random() - rng.random())))
            out[i * nc + c] = 32767 if s > 32767 else (-32768 if s < -32768 else s)
    tmp = path + ".part"
    with open(tmp, "wb") as f:
        data = out.tobytes()
        f.write(b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, nc, RATE, RATE * nc * 2, nc * 2, 16))
        f.write(b"data" + struct.pack("<I", len(data)) + data)
    os.replace(tmp, path)
    return [[v / 32768.0 for v in out[c::nc]] for c in range(nc)]


# ---------------------------------------------------------------------------------------------
# DSP
# ---------------------------------------------------------------------------------------------
def resample(x, rate):
    if rate == RATE:
        return x
    step = rate / RATE
    n = int((len(x) - 1) / step)
    out = [0.0] * n
    for j in range(n):
        p = j * step
        i = int(p)
        fr = p - i
        out[j] = x[i] + (x[i + 1] - x[i]) * fr
    return out


def biquad(x, kind, fc, q=0.7071):
    """RBJ cookbook 2nd-order high/low-pass."""
    w = 2 * math.pi * fc / RATE
    cw, al = math.cos(w), math.sin(w) / (2 * q)
    if kind == "lp":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    else:
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    a0, a1, a2 = 1 + al, -2 * cw, 1 - al
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def onepole_lp(x, fc):
    a = 1 - math.exp(-2 * math.pi * fc / RATE)
    y, s = [0.0] * len(x), 0.0
    for i, v in enumerate(x):
        s += a * (v - s)
        y[i] = s
    return y


def remove_dc(x):
    m = sum(x) / len(x)
    return [v - m for v in x]


def rms(chans):
    n = sum(len(x) for x in chans)
    return math.sqrt(sum(v * v for x in chans for v in x) / n) + 1e-12


def peak(chans):
    return max(abs(v) for x in chans for v in x) + 1e-12


def db(v):
    return 20 * math.log10(v)


def env_rms(x, hop):
    return [math.sqrt(sum(v * v for v in x[i:i + hop]) / hop) for i in range(0, len(x) - hop + 1, hop)]


def agc(chans, amount, win=1.0):
    """Slow level-riding: pulls a pass-by/approach towards the median level (amount 0..1)."""
    hop = int(RATE * 0.25)
    mono = [sum(c[i] for c in chans) / len(chans) for i in range(len(chans[0]))]
    e = env_rms(mono, hop)
    k = max(1, int(win / 0.25))
    sm = [math.sqrt(sum(v * v for v in e[max(0, i - k):i + k + 1]) / len(e[max(0, i - k):i + k + 1])) for i in range(len(e))]
    ref = sorted(sm)[len(sm) // 2]
    g = [(ref / max(v, 1e-9)) ** amount for v in sm]
    out = []
    for c in chans:
        y = [0.0] * len(c)
        for i in range(len(c)):
            p = i / hop - 0.5
            j = min(max(int(p), 0), len(g) - 1)
            j2 = min(j + 1, len(g) - 1)
            fr = min(max(p - j, 0.0), 1.0)
            y[i] = c[i] * (g[j] + (g[j2] - g[j]) * fr)
        out.append(y)
    return out


def limiter(chans, ceil, release=0.15):
    """Look-ahead peak limiter (5 ms look-ahead), linked across channels."""
    n, la = len(chans[0]), int(RATE * 0.005)
    req = [1.0] * n
    for i in range(n):
        m = max(abs(c[i]) for c in chans)
        if m > ceil:
            req[i] = ceil / m
    # sliding minimum over the next `la` samples
    from collections import deque
    dq, mn = deque(), [1.0] * n
    for i in range(n + la):
        if i < n:
            while dq and req[dq[-1]] >= req[i]:
                dq.pop()
            dq.append(i)
        j = i - la
        if j >= 0:
            while dq[0] < j:
                dq.popleft()
            mn[j] = req[dq[0]]
    rel = 1 - math.exp(-1 / (RATE * release))
    att = 1 - math.exp(-1 / (RATE * 0.001))
    g, s = [1.0] * n, 1.0
    for i in range(n):
        t = mn[i]
        s += (att if t < s else rel) * (t - s)
        g[i] = min(s, t)
    return [[c[i] * g[i] for i in range(n)] for c in chans]


def make_loop(chans, loop_s, xf_s):
    """Equal-power crossfade of the material after the loop point into the start, so the last
    sample runs straight on into the first."""
    L, X = int(loop_s * RATE), int(xf_s * RATE)
    out = []
    for c in chans:
        assert len(c) >= L + X, (len(c), L + X)
        y = c[:L]
        for i in range(X):
            t = (i + 0.5) / X * math.pi / 2
            y[i] = c[i] * math.sin(t) + c[L + i] * math.cos(t)
        out.append(y)
    return out


def splice(chans_list, xf_s=0.5):
    """Joins pieces end to end with short equal-power crossfades."""
    X = int(xf_s * RATE)
    out = [list(c) for c in chans_list[0]]
    for piece in chans_list[1:]:
        for o, p in zip(out, piece):
            for i in range(X):
                t = (i + 0.5) / X * math.pi / 2
                o[len(o) - X + i] = o[len(o) - X + i] * math.cos(t) + p[i] * math.sin(t)
            o.extend(p[X:])
    return out


def fades(x, fin_s, fout_s):
    y = list(x)
    fi, fo = int(fin_s * RATE), int(fout_s * RATE)
    for i in range(min(fi, len(y))):
        y[i] *= i / fi
    for i in range(min(fo, len(y))):
        y[len(y) - 1 - i] *= math.sin(i / fo * math.pi / 2) ** 2
    return y


def scale(chans, g):
    return [[v * g for v in c] for c in chans]


# ---------------------------------------------------------------------------------------------
# Synthesis (fixed seeds)
# ---------------------------------------------------------------------------------------------
def synth_cellar_tone(seconds, seed=11):
    """Room tone of a stone cellar: low 'pressure' rumble (leaky-integrated noise, 25-250 Hz) with a
    faint air/ventilation hiss band, slowly breathing in level. Game simplification: synthesised."""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    white = [rng.gauss(0, 1) for _ in range(n)]
    brown, s = [0.0] * n, 0.0
    for i, v in enumerate(white):
        s = 0.998 * s + v * 0.03
        brown[i] = s
    low = biquad(biquad(brown, "lp", 250), "hp", 25)
    air = biquad(biquad([rng.gauss(0, 1) for _ in range(n)], "lp", 2500), "hp", 400)
    ra, rl = rms([air]), rms([low])
    out = []
    for i in range(n):
        t = i / RATE
        mod = 1 + 0.12 * math.sin(2 * math.pi * t / 7.3) + 0.08 * math.sin(2 * math.pi * t / 3.1 + 1)
        out.append(low[i] / rl * mod + air[i] / ra * 0.08)
    return [out]


def schroeder(x, rt60=1.1, wet=0.28, tail=1.2):
    """Small stone-room reverb: 4 parallel combs + 2 all-passes."""
    n = len(x) + int(tail * RATE)
    src = x + [0.0] * (n - len(x))
    acc = [0.0] * n
    for d_ms in (29.7, 37.1, 41.1, 43.7):
        d = int(d_ms * RATE / 1000)
        g = 10 ** (-3 * d_ms / 1000 / rt60)
        buf = [0.0] * n
        for i in range(n):
            buf[i] = src[i] + (g * buf[i - d] if i >= d else 0.0)
        for i in range(n):
            acc[i] += buf[i] * 0.25
    for d_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = int(d_ms * RATE / 1000)
        y = [0.0] * n
        for i in range(n):
            xd = acc[i - d] if i >= d else 0.0
            yd = y[i - d] if i >= d else 0.0
            y[i] = -g * acc[i] + xd + g * yd
        acc = y
    acc = biquad(acc, "lp", 5000)
    return [src[i] * (1 - wet) + acc[i] * wet for i in range(n)]


def synth_drip(variant):
    """A water drop falling into a shallow pool in a cellar: tiny impact click plus the ringing air
    bubble whose pitch rises as it shrinks (Minnaert resonance), in a small stone-room reverb.
    Game simplification: synthesised."""
    rng = random.Random(100 + variant)
    f0 = (1150, 1650, 2250)[variant] * (1 + 0.05 * rng.random())
    tau = (0.030, 0.022, 0.017)[variant]
    rise = (0.9, 1.3, 1.6)[variant]  # relative pitch rise over the ring
    n = int(0.18 * RATE)
    x, ph = [0.0] * n, 0.0
    delay = int(0.004 * RATE)  # bubble rings a few ms after impact
    for i in range(n):
        t = i / RATE
        if i < int(0.0015 * RATE):
            x[i] += rng.gauss(0, 1) * 0.25 * (1 - i / (0.0015 * RATE))
        if i >= delay:
            tb = (i - delay) / RATE
            f = f0 * (1 + rise * (1 - math.exp(-tb / 0.03)))
            ph += 2 * math.pi * f / RATE
            a = math.exp(-tb / tau) * min(1.0, tb / 0.0008)
            x[i] += a * math.sin(ph)
    x = biquad(x, "hp", 300)
    return schroeder(x)


# ---------------------------------------------------------------------------------------------
# Build steps
# ---------------------------------------------------------------------------------------------
def load(cache, kind, key, start, end, mono=False, pre=0.5):
    """Decodes [start-pre, end), resampled to 44.1 kHz. Returns (meta, chans, pre_samples)."""
    meta, wav = source(cache, kind, key)
    a = max(0.0, start - pre)
    rate, ch = read_wav(wav, a, end + 0.3)  # small post-roll so rounding never leaves us short
    if mono and len(ch) > 1:
        ch = [[sum(v) / len(v) for v in zip(*ch)]]
    return meta, [resample(c, rate) for c in ch], int((start - a) * RATE)


def filt(chans, spec, pre):
    out = []
    for c in chans:
        c = remove_dc(c)
        c = biquad(c, "hp", spec.get("hp", 20))
        if spec.get("lp1"):
            c = onepole_lp(c, spec["lp1"])
        out.append(c[pre:])
    return out


def build_bed(cache, name, spec):
    need = spec["loop"] + XFADE
    metas = []
    if spec.get("synth"):
        chans = synth_cellar_tone(need + 0.5)
        chans = [biquad(c, "hp", 20)[int(0.5 * RATE):] for c in chans]
    else:
        layers = []
        for kind, key, a, b, gdb in spec["src"]:
            if isinstance(a, list):  # splice several ranges of one file to lengthen a short recording
                pieces = []
                for s, e in a:
                    meta, ch, pre = load(cache, kind, key, s, e, spec.get("mono"))
                    pieces.append(filt(ch, spec, pre))
                ch = splice(pieces)
            else:
                meta, ch, pre = load(cache, kind, key, a, b, spec.get("mono"))
                ch = filt(ch, spec, pre)
            metas.append(meta)
            layers.append(scale([c[:int(need * RATE)] for c in ch], 10 ** (gdb / 20)))
        nc = max(len(l) for l in layers)
        chans = [[0.0] * int(need * RATE) for _ in range(nc)]
        for l in layers:
            for c in range(nc):
                src = l[c % len(l)]
                assert len(src) >= len(chans[c]), (name, len(src), len(chans[c]))
                for i in range(len(chans[c])):
                    chans[c][i] += src[i]
        if spec.get("agc"):
            chans = agc(chans, spec["agc"])
    chans = make_loop(chans, spec["loop"], XFADE)
    chans = [remove_dc(c) for c in chans]
    ceil = 10 ** (PEAK_CEIL / 20)
    g = min(10 ** (spec["rms"] / 20) / rms(chans), ceil / peak(chans) * 10 ** (spec.get("limit_db", MAX_LIMIT_DB) / 20))
    chans = scale(chans, g)
    if peak(chans) > ceil:
        chans = limiter(chans, ceil, spec.get("release", 0.15))
    return chans, metas


def pick_steps(x, spec):
    """Finds footsteps as the loudest transient within +-gap/2 (the heel strike) on a 5 ms RMS
    envelope, walks back to the onset, and keeps the `count` steps whose level is closest to the
    median, so the variants are consistent. Returns sample ranges."""
    hop = RATE // 200
    e = env_rms(x, hop)
    floor = sorted(e)[len(e) // 10]
    W = int(spec["gap"] * 100)
    peaks = [i for i in range(len(e)) if e[i] > floor * 8 and e[i] == max(e[max(0, i - W):i + W + 1])]
    onsets = []
    for i in peaks:
        s = i
        while s > 0 and i - s < 12 and e[s - 1] > e[i] / 10:  # back to -20 dB, at most 60 ms
            s -= 1
        onsets.append(s)
    cands = []
    for k, (i, s) in enumerate(zip(peaks, onsets)):
        if s * hop < 0.05 * RATE:
            continue  # the recording starts mid-step
        end = min(s + int(spec["max_len"] * 200), onsets[k + 1] - 1 if k + 1 < len(onsets) else len(e))
        seg = e[s:end]
        stop = max(e[i] / 100, floor * 2)  # -40 dB re the strike, or just above the room noise
        L = min(max(j for j in range(len(seg)) if seg[j] > stop) + 4, len(seg))  # +20 ms
        if L >= 30:  # at least 150 ms
            cands.append((s, L, e[i]))
    if len(cands) < spec["count"]:
        raise SystemExit(f"only {len(cands)} usable steps found")
    med = sorted(c[2] for c in cands)[len(cands) // 2]
    best = sorted(cands, key=lambda c: (abs(db(c[2]) - db(med)), c[0]))[:spec["count"]]
    out = []
    for s, L, _ in sorted(best):
        a, b = s * hop, (s + L) * hop
        pk = max(abs(v) for v in x[a:b])
        lead = next(j for j in range(max(0, a - 2 * hop), b) if abs(x[j]) > pk * 0.05)
        out.append((max(0, lead - int(0.002 * RATE)), b))
    return out


def build_oneshots(cache, name, spec):
    """Returns [(filename, chans, metas)]."""
    peak_g = 10 ** (ONESHOT_PEAK / 20)
    res = []
    if spec.get("synth") == "drip":
        for v in range(spec["count"]):
            x = synth_drip(v)
            e = env_rms(x, RATE // 200)
            stop = max(e) / 300  # -50 dB
            L = max(i for i, val in enumerate(e) if val > stop) * (RATE // 200)
            x = fades(x[:L], 0.0, 0.03)
            res.append((f"drip_{v}.wav", scale([x], peak_g / peak([x])), []))
        return res
    kind, key = spec["src"]
    meta, wav = source(cache, kind, key)
    rate, ch = read_wav(wav)
    x = resample([sum(v) / len(v) for v in zip(*ch)] if len(ch) > 1 else ch[0], rate)
    x = biquad(remove_dc(x), "hp", spec["hp"])
    if spec.get("cut"):  # co2 puff: a slice of the steady hiss shaped into a short release
        a, b = (int(t * RATE) for t in spec["cut"])
        y = x[a:b]
        n = len(y)
        y = [v * min(1.0, i / (0.012 * RATE)) * (0.35 + 0.65 * math.exp(-i / (0.09 * RATE))) *
             math.exp(-i / (0.28 * RATE)) for i, v in enumerate(y)]
        y = fades(y, 0.0, 0.03)
        return [(f"{name}.wav", scale([y], peak_g / peak([y])), [meta])]
    for k, (a, b) in enumerate(pick_steps(x, spec)):
        y = fades(x[a:b], 0.001, 0.02)
        res.append((f"{name}_{k}.wav", scale([y], peak_g / peak([y])), [meta]))
    return res


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    out = os.path.abspath(args[0] if args else os.path.join(os.path.dirname(__file__), "..", "assets3d", "audio"))
    cache = os.path.join(out, ".src")
    os.makedirs(cache, exist_ok=True)
    mpath = os.path.join(out, "audio.json")
    old = {e["file"]: e for e in json.load(open(mpath))} if os.path.exists(mpath) else {}
    manifest = []

    def recipe_hash(name, spec):
        return hashlib.sha1(json.dumps([VERSION, XFADE, PEAK_CEIL, MAX_LIMIT_DB, ONESHOT_PEAK, name, spec],
                                       sort_keys=True).encode()).hexdigest()[:12]

    def entry(fname, chans, loop, metas, h, seed_note):
        return {"file": fname, "loop": loop, "seconds": round(len(chans[0]) / RATE, 3), "channels": len(chans),
                "rms_dbfs": round(db(rms(chans)), 1), "peak_dbfs": round(db(peak(chans)), 1),
                "source": " + ".join(m["page"] for m in metas) if metas else "synthesized",
                "author": " + ".join(dict.fromkeys(m["author"] for m in metas)) if metas else "Terroir Engine (synthesized in-house)",
                "licence": " + ".join(dict.fromkeys(m["licence"] for m in metas)) if metas else "CC0 (synthesized in-house)",
                "titles": [m["title"] for m in metas], "notes": seed_note, "recipe": h}

    def cached(fnames, h):
        return (not force and all(os.path.exists(os.path.join(out, f)) and old.get(f, {}).get("recipe") == h
                                  for f in fnames))

    for name, spec in BEDS.items():
        fname, h = name + ".wav", recipe_hash(name, spec)
        if cached([fname], h):
            manifest.append(old[fname]); print("skip", fname); continue
        chans, metas = build_bed(cache, name, spec)
        chans = write_wav(os.path.join(out, fname), chans, seed=int(h, 16) & 0xFFFFFFFF)
        note = ("synthesized; " if spec.get("synth") else "") + f"seamless loop ({XFADE}s equal-power crossfade)"
        manifest.append(entry(fname, chans, True, metas, h, note))
        print("built", fname, f"{manifest[-1]['seconds']}s rms {manifest[-1]['rms_dbfs']} peak {manifest[-1]['peak_dbfs']}")
    for name, spec in ONESHOTS.items():
        h = recipe_hash(name, spec)
        n = spec.get("count", 1)
        fnames = [f"{name}_{k}.wav" for k in range(n)] if "count" in spec else [name + ".wav"]
        if cached(fnames, h):
            manifest += [old[f] for f in fnames]; print("skip", ", ".join(fnames)); continue
        for fname, chans, metas in build_oneshots(cache, name, spec):
            chans = write_wav(os.path.join(out, fname), chans, seed=int(hashlib.sha1((h + fname).encode()).hexdigest()[:8], 16))
            note = "synthesized" if not metas else ("shaped slice of the recording" if spec.get("cut") else "single step cut from the recording")
            manifest.append(entry(fname, chans, False, metas, h, note))
            print("built", fname, f"{manifest[-1]['seconds']}s peak {manifest[-1]['peak_dbfs']}")

    json.dump(manifest, open(mpath + ".part", "w"), indent=1)
    os.replace(mpath + ".part", mpath)
    lines = ["# Audio credits", "", "Built by `game/tools/fetch_audio.py`. Recordings are CC0 (public-domain dedication); the licence",
             "was checked on each file's own page when downloaded. Synthesized sounds were generated in-house by the script.",
             "Every file was edited (resampled to 44.1 kHz/16-bit, filtered, trimmed, looped, levelled).", "",
             "| File | Source | Author | Licence |", "|---|---|---|---|"]
    for e in manifest:
        src = " + ".join(f"[{t}]({u})" for t, u in zip(e["titles"], e["source"].split(" + "))) if e["titles"] else "synthesized in-house"
        lines.append(f"| {e['file']} | {src} | {e['author']} | {e['licence']} |")
    lines += ["", "BigSoundBank asks (optionally) for the credit \"Additional sounds: Joseph SARDIN - BigSoundBank.com\"."]
    open(os.path.join(out, "CREDITS.md"), "w").write("\n".join(lines) + "\n")
    print(f"audio: {len(manifest)} files in {out}")


if __name__ == "__main__":
    main()
