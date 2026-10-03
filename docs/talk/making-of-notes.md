# Talk notes: building a game from scratch with only AI

Working notes for a future talk by the owner. Open questions (audience, length, date) are at the bottom. Numbers are from
2026-10-03; refresh them before the talk (see "How to refresh the numbers").

## The pitch in one line

A realistic winemaking simulator and wine-study tool: real weather from 1990 to 2025, cited science, a 3D Godot game.
Built in about a week by AI, with the owner writing zero code.

## Numbers (2026-10-03)

**Calendar:** 8 days (first commit 2026-09-26) and 159 commits, 83 of them feat/fix.

**Code:**
- About 8,200 lines of C# simulation, plus 3,100 lines of tests (207 tests).
- About 15,200 lines of GDScript UI.

**Science:** 20 docs, about 56,000 words, every in-game fact cited. Two of the owner's coursebooks are used as a
cross-check oracle (paraphrased, never copied).

**Design:** 9 specs, 9 implementation plans, 3 architecture decision records.

**Feedback loops:**

| Loop | Time |
|---|---|
| Sim tests | 20 s |
| Incremental game build | 3 s |
| UI harnesses | 4–7 s each |
| Full capture (37 screens + save/load) | 28 s |
| Fuzz | 77 s |

Everything takes about 2.5 minutes in series, or **85 s in parallel with `scripts/check.sh`** (added 2026-10-03).

**One week-long agent session:** about 2,400 tool calls (1,670 shell commands, 250 file reads, 130 file writes) and 32
sub-agents for reviews and research. The owner's own messages are a small fraction of the session.

## Why it worked (the architecture that makes AI fast)

1. **A headless, deterministic simulation core** (ADR 0001). Every outcome is testable in seconds without the game, and
   ideas can be probed from the command line (`qualitysweep`, scenario grids).
2. **The game never computes outcomes.** Godot only draws JSON from a bridge, so almost everything is testable without
   rendering.
3. **Harnesses drive the real game and screenshot it.** They are the AI's eyes, and they look great on stage: the app
   races through its screens in seconds.
4. **Tooling chosen for AI verification, not human ergonomics:** text-based, CLI-drivable and headless-testable (a
   project rule from day one).
5. **Science as the oracle.** Cited docs, `UNVERIFIED` marks for unbacked numbers, labelled simplifications. The AI
   checks itself against sources, not vibes.

## The workflow (show as a diagram)

1. Idea, then research agents (web, papers, the owner's books).
2. Spec, which the owner approves.
3. Implementation plan.
4. Inline TDD: watch the test fail, then pass.
5. A ledger of every judgement call ("Ruling: … — why — cost if wrong").
6. Harness runs and screenshot review.
7. An independent reviewer agent on the most capable model.
8. One fix pass, each fix test-first.
9. Local merge, and push when the owner says so.

## Stories worth telling

- **The independent reviewer found real bugs every single time,** for example:
  - lessons queued only when you won a medal;
  - a fault sentence on the wrong card;
  - a learn-card quiz that could be farmed into "Known";
  - a scenario overwriting your main save.
- **"Every new-oak wine is outstanding."** A calibration sweep showed 61 % of wines Very good or better. The cause: the
  oak aroma summed the strengths of four compounds. Fixed from the physics, not by fudging thresholds.
- **The AI caught a textbook contradiction against its own content.** Checking the 12 learn cards and 34 Causes against
  the owner's coursebooks found a chain that read backwards (over-cropping giving riper wine) and a "struck match"
  descriptor the book assigns to SO₂, not H₂S.
- **The book overruled the research.** The Level 3 coursebook itself teaches the four-criteria quality count, so the
  "quality as an argument" plan was revised: the count kept, the argument added.
- **A test player that played wrong.** The scripted player stepped 3 days at a time, so cellar choices locked before
  it set them. Found during medal tuning, fixed once in a shared player.
- **Real growers changed the game's goals.** Research showed Burgundy growers chaptalised a little in 2016 to keep
  acid balance, so the planned "no chaptalisation" gold medal was dropped: it would have taught the wrong lesson.
- **The same layout bug five times:** a label collapsing into a vertical column of letters, caught only by the AI looking
  at screenshots. This became the automatic layout check (devex work, 2026-10-03).
- **No future knowledge (ADR 0002).** The famous-vintage briefings are validated so they never reveal what the year will
  bring; the debrief reveals it afterwards.

## Recorded videos (2026-10-03)

Godot's Movie Maker, `scripts/record.sh`, writes to `game/shots/video/` (not in git; regenerate any time):

| Video | Length | What it shows |
|---|---|---|
| `capture.mp4` | 47 s | the full game, from setup through the season to bottling and the report |
| `scenarios.mp4` | 11 s | a famous vintage, from briefing to gold medal and debrief |
| `practice.mp4` | 18 s | Tasting practice exercises and the Wine Fair |
| `learning.mp4` | 26 s | spaced review sessions and the learn cards |
| `fuzz.mp4` | 1 min 33 s | random clicking through two seasons: the chaos test |

**Lesson learnt:** Movie Maker films every frame, including frames where a harness waits for a background task. Cap
recordings (`--quit-after`) and always rebuild before recording.

## Demo ideas

- A recorded harness run (Godot Movie Maker), sped up: the AI clicking through a whole season, the Wine Fair and a
  famous vintage in under a minute.
- A visual change report: before and after screenshots of a feature.
- A live `scripts/check.sh`: tests, build and every harness in about a minute, with a summary table.
- A git-history timeline: features per day.
- A screenshot time-lapse across commits.
- The ledger: show real "Ruling:" lines, the AI deciding on the owner's behalf and saying what it costs if wrong.

## Honest limits to mention

- The AI needs the owner for taste and purpose; it decides craft questions itself.
- Calibration that needs an expert stays `UNVERIFIED` (the quality spread awaits a Level 3 reviewer).
- Rate limits and session limits interrupted work twice. The ledger and specs made it resumable.
- Some features are partly modelled (for example no rot in Napa 2011), and these are labelled as simplifications.

## How to refresh the numbers

```bash
git rev-list --count HEAD; git log --reverse --format=%ad --date=short | head -1
find sim/src -name '*.cs' | xargs cat | wc -l; grep -rhE '\[(Fact|Theory)\]' sim/tests | wc -l
find game/src -name '*.gd' | xargs cat | wc -l; cat docs/science/*.md | wc -w
bash scripts/check.sh   # loop timings and the summary table
```

## Open questions (ask the owner)

- Audience (developers, managers, wine people?), slot length, date, and recording or live.
- Show the game first, or the process first?
