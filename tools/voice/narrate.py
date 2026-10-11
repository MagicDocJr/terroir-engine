#!/usr/bin/env python3
"""The intro's narration with ElevenLabs text-to-speech (game/src/view3d/intro.json → game/assets3d/audio/voice/*.mp3).

The key is read from $ELEVENLABS_API_KEY or from C:\\Users\\Aleksander\\.config\\terroir\\elevenlabs.key (never from the
repo, never printed). The game only plays the rendered files; it never calls the API.

  python3 tools/voice/narrate.py voices                 # the voices on the account (name, id, labels)
  python3 tools/voice/narrate.py library "deep narrator"  # search the shared voice library
  python3 tools/voice/narrate.py samples ID [ID …]       # one test line per voice → game/shots/voice_samples/
  python3 tools/voice/narrate.py render [--voice ID] [--only CLIP] [--force]
                                                         # every clip; unchanged text/voice/settings are skipped
Clips: region_<mosel|cote-dor|napa>, plot_<plot id>, winery, welcome (view3d.gd play_intro).
"""
import hashlib, json, os, sys, urllib.error, urllib.parse, urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
INTRO = os.path.join(ROOT, "game", "src", "view3d", "intro.json")
OUT = os.path.join(ROOT, "game", "assets3d", "audio", "voice")
SAMPLES = os.path.join(ROOT, "game", "shots", "voice_samples")
KEY_FILES = ["/mnt/c/Users/Aleksander/.config/terroir/elevenlabs.key", os.path.expanduser("~/.config/terroir/elevenlabs.key")]
API = "https://api.elevenlabs.io"
SAMPLE_TEXT = ("This is the Mosel, the largest steep-slope wine region in the world. Your land is Blauschiefer-Hang: "
               "one point two hectares of blue Devonian slate. Welcome to your estate.")


def key() -> str:
    k = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    for f in KEY_FILES:
        if not k and os.path.exists(f):
            k = open(f, encoding="utf-8").read().strip()
    if not k:
        sys.exit("No ElevenLabs key: set ELEVENLABS_API_KEY or write it to " + KEY_FILES[0])
    return k


def call(path: str, body=None, accept="application/json"):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"xi-api-key": key(), "Content-Type": "application/json", "Accept": accept},
                                 method="POST" if body is not None else "GET")
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        sys.exit(f"ElevenLabs {e.code}: {e.read().decode(errors='replace')[:300]}")


def clips(data: dict) -> dict:
    out = {f"region_{k}": v["text"] for k, v in data["regions"].items()}
    out.update({f"plot_{k}": v["text"] for k, v in data["plots"].items()})
    out["winery"] = data["winery"]["text"]
    out["welcome"] = data["welcome"]["text"]
    return out


def tts(text: str, voice_id: str, v: dict) -> bytes:
    body = {"text": text, "model_id": v.get("model", "eleven_multilingual_v2"),
            "voice_settings": {"stability": v.get("stability", 0.55), "similarity_boost": v.get("similarity_boost", 0.8),
                               "style": v.get("style", 0.15), "use_speaker_boost": True}}
    return call(f"/v1/text-to-speech/{voice_id}?output_format=mp3_44100_128", body, "audio/mpeg")


def main() -> None:
    a = sys.argv[1:] or ["render"]
    data = json.load(open(INTRO, encoding="utf-8"))
    v = data["voice"]
    if a[0] == "voices":
        for x in json.loads(call("/v1/voices"))["voices"]:
            labels = ", ".join(f"{k}: {val}" for k, val in (x.get("labels") or {}).items())
            print(f"{x['name']:<28} {x['voice_id']}  {labels}")
    elif a[0] == "library":
        q = urllib.parse.quote(" ".join(a[1:]) or "narrator")
        for x in json.loads(call(f"/v1/shared-voices?page_size=20&search={q}"))["voices"]:
            print(f"{x['name']:<28} {x['voice_id']}  {x.get('gender','')}, {x.get('age','')}, {x.get('accent','')} — {(x.get('description') or '')[:70]}")
    elif a[0] == "samples":
        os.makedirs(SAMPLES, exist_ok=True)
        names = {x["voice_id"]: x["name"].split(" - ")[0].split()[0] for x in json.loads(call("/v1/voices"))["voices"]}
        for vid in a[1:]:
            audio = tts(SAMPLE_TEXT, vid, v)          # before opening the file: a failed call leaves no empty file
            path = os.path.join(SAMPLES, f"{names.get(vid, vid)}_{vid}.mp3")
            open(path, "wb").write(audio)
            print("sample", path)
    elif a[0] == "render":
        vid = a[a.index("--voice") + 1] if "--voice" in a else v.get("voice_id", "")
        if not vid:
            sys.exit('No voice: set "voice_id" in game/src/view3d/intro.json or pass --voice ID')
        only = a[a.index("--only") + 1] if "--only" in a else None
        os.makedirs(OUT, exist_ok=True)
        man_path = os.path.join(OUT, "manifest.json")
        man = json.load(open(man_path)) if os.path.exists(man_path) else {}
        chars = 0
        for cid, text in clips(data).items():
            if only and cid != only:
                continue
            h = hashlib.sha1(json.dumps([text, vid, v], sort_keys=True).encode()).hexdigest()
            path = os.path.join(OUT, f"{cid}.mp3")
            if man.get(cid) == h and os.path.exists(path) and "--force" not in a:
                continue
            audio = tts(text, vid, v)
            open(path, "wb").write(audio)
            man[cid] = h
            chars += len(text)
            json.dump(man, open(man_path, "w"), indent=1)
            print("voice", cid, f"{os.path.getsize(path) // 1024} KB")
        print(f"DONE ({chars} characters rendered)")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
