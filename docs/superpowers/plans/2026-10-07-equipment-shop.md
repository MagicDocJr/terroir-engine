# Equipment Shop Implementation Plan

> Inline execution with TDD per task, then one whole-branch review on the most capable model. Same method as the last
> features.

**Goal:** an easy-to-find Equipment shop selling frost protection (candles, wind machine, sprinklers) and a sorting table,
each with real, cited effects in the simulation.

**Spec:** `docs/superpowers/specs/2026-10-07-equipment-shop-design.md`

## Global constraints
- ADR 0001 (no UI computation).
- ADR 0002.
- Cited or `UNVERIFIED` numbers.
- Commands replayable.
- No pressure mechanics.
- CONTEXT terms.
- Verify with `scripts/check.sh`.

## Review Focus
1. **Buying with too little cash** → refused with a message; the card shows the gap. Cash never goes negative from a
   purchase.
2. **Old saves (no equipment)** → candles only; the old Frost tier High maps to candles (no wind machine owned).
3. **A frost night with wind (advective)** → the wind machine does nothing, as the card says.
4. **A Plot where an item is not offered** → no Buy button, and a reason shown.
5. **Rigorous sorting ordered without a table**, from an old save or a scripted command → refused, falling back to table
   sorting, with a message.

## Tasks
1. **Research** (agent): frost protection methods (wind machines, sprinklers, candles or heaters) — protected
   temperature, conditions, coverage, capital and running costs, regional use on the Mosel, Côte d'Or and Napa; and
   sorting tables — cost and the effect on rot removal. Write the results into `economy.md` and `phenology.md` §6 with
   sources.
2. **Sim:**
   - `data/equipment.json`, `Equipment.cs`, the `buy` command and ledger entry;
   - owned equipment in the state, the snapshot JSON, the frost model per method, and the sorting gate;
   - tests: purchase and replay, wind versus radiation night, sprinkler limit, sorting refusal, regional offers, and the
     old-save mapping.
3. **UI:**
   - the `equipment.gd` screen and nav entry, the intro card, and the first-message line;
   - contextual links in the frost warning, Programmes and harvest sorting;
   - harness steps;
   - screenshots reviewed through the layout check and the visual diff.
4. **Docs** (science, CONTEXT, README, backlog), `scripts/check.sh`, the final review, the fix pass, and a local merge.
