# Vintage in Review Implementation Plan

> Executed inline (owner: "agree, go ahead"), TDD per task, one whole-branch review at the end.

**Goal:** a season strip and 6–8 cause cards at the top of the Vintage report. Each card links a season event or choice to
the Tasting-sheet line it shaped, and feeds the review queue.

**Spec:** `docs/superpowers/specs/2026-10-03-vintage-in-review-design.md`

**Architecture:**
- `VintageReview.Cards/Strip` in the sim, built from the Wines' `CauseLinks` plus season, provenance and Lot state.
- `VintageReport.Build` adds a `review` object.
- The bridge's `ReviewSeen(vintage)` enqueues the Causes once.
- `report.gd` draws the strip (animated) and the cards.

## Global constraints
- ADR 0001 (no UI computation).
- ADR 0002 (state only up to the bottling).
- Descriptive tone: no verdict words.
- Every card is linked to a Cause tagged on a sheet of the Vintage.
- CONTEXT.md terms.
- Build via `scripts/build-game.sh`. Tests: `cd sim && ~/.dotnet/dotnet test -v q`.

## Review Focus
1. **A Vintage with no bottled Wine, or a Wine without a sheet** → no `review` object, and no crash.
2. **An old save opened again** → the review shows (it is computed, not stored). The Causes are enqueued only once, through
   the game flag.
3. **A blend across Blocks or Vintages** → the evidence uses the Vintage's own Lots. The phenology comes from the best
   Wine's largest component of that Vintage.
4. **An easy year with few Causes** → fewer cards, never padded.
5. **Verdict wording creeping into card text** → a test scans every card's text.

## Tasks
1. **`VintageReview.cs` and report integration.** Tests in `VintageReviewTests`:
   - a frost card for Côte d'Or 2016, with the date and shoot loss;
   - a warm card for Mosel 2018;
   - every Cause is on a sheet;
   - at most 8 cards, sorted;
   - no verdict words;
   - no review without Wines.
2. **Bridge `ReviewSeen`, the `report.gd` section** (strip control with sweep, skip and replay; cards fade in), the
   harness and capture screenshots.
3. **Docs** (`docs/science/vintage-review.md`, CONTEXT, README, backlog), all checks, the final review, the fix pass, and
   a local merge.
