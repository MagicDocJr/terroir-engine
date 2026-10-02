# Tasting sheet 2 Implementation Plan

> Executed inline (owner: "go ahead and implement … don't ask questions till done"). TDD per task; one whole-branch review
> at the end.

**Goal:** bring the Tasting sheet in line with the systematic approach, spread the quality verdict, and show the absolute
climate class.

**Spec:** `docs/superpowers/specs/2026-10-02-tasting-sheet-2-design.md`

**Architecture:**
- The sim decides everything: `TastingSheetGenerator` writes the new lines, `TastingMarker` marks them, and `VintageFacts`
  gains the growing-season temperature.
- The UI renders the new JSON fields. The pickers stay generic.

## Global constraints
- ADR 0001: the UI never computes outcomes. ADR 0002: no future knowledge.
- Every fact is cited in `docs/science/`; design values are marked UNVERIFIED; game simplifications are labelled.
- No exam-board wording, and nothing copied from `reference/`.
- CONTEXT.md terms: "Tasting sheet", never "tasting note".
- Build C# via `scripts/build-game.sh`. Run the sim tests with `cd sim && ~/.dotnet/dotnet test`.

## Review Focus
1. **A faulty Wine** → no readiness line, and the readiness item is skipped in marking. It is never scored against "not
   for sale".
2. **A Wine with only one fruit family and nothing else** → "simple" is right. If the player ticks "simple" plus fruit,
   they get full credit.
3. **Old practice vintages tasted at great age** (a 1995 dry Riesling in 2025) → tired or too old, never "too young".
4. **Estate Wines tasted at bottling** (age ≈ 0) → never "too old"; a structured red can be "too young".
5. **A blind or pre-mark glass** → the new lines (fruit ripeness, flavours, simple) are stripped before marking.

## Tasks
1. **Sheet model and generator** (`TastingSheet.cs`), test `SheetTwoTests`:
   - brown and tawny colours;
   - other observations;
   - the fruit split and fruit ripeness;
   - "simple" and flavours;
   - development "tired";
   - the drinking window and four-option readiness;
   - the quality argument with integration;
   - Cause tags on the split families.
2. **Recalibration:**
   - a sweep test `Quality_SpreadsAcrossRandomPours` over 60 fixed seeds pins the target bands;
   - tune the thresholds;
   - a CLI `qualitysweep` command for the reviewer.
3. **Absolute climate:**
   - `VintageFacts.Gst` (Apr–Oct mean) and `VintageFacts.RegionClass`;
   - the Identify "because", the practice context and the Vintage card;
   - test `Climate_AbsoluteClassBesideRelative`.
4. **Marking and learning core:**
   - `TastingMarker` scales, categories and families, plus the new keys `fruitRipeness` and `flavours` in the sheet
     exercise;
   - "simple" in the aroma and flavour lists;
   - the faulty-readiness skip;
   - `Predictions` and `PracticeSession` fruit-family sets;
   - `PracticeJson` and `Snapshot` fields, with `Shown` stripping;
   - tests in `SheetTwoMarkingTests`.
5. **UI:**
   - multi-pick for flavours;
   - the sheet view shows other observations, fruit ripeness, flavours and the quality argument;
   - the Wines screen shows the quality argument;
   - the harness answers the new keys;
   - screenshot review.
6. **Docs, checks, review, merge:**
   - update `tasting-sheet.md` and the backlog;
   - run all suites, practice.sh, learning.sh, fuzz and capture;
   - final review subagent, then one fix pass;
   - merge locally.
