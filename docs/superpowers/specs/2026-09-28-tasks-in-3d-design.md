# Tasks in 3D — design

Status: design approved in conversation 2026-09-28 (owner: "yes, go ahead"). Owner answers: the player does a task on **one demonstration vine and the crew finishes the Block**. Vocabulary follows `CONTEXT.md`. Backlog items: "Hands-on tasks in 3D" and "Staff-assigned tasks done in 3D" (`docs/backlog.md`).

## 1. Goal

Staff give the player dated tasks. The player either walks to the place in the 3D world and makes the decision on a demonstration vine (or at the tank), after which the crew finishes the work, or lets the crew do it to the staff member's plan.

**Success looks like**
- Four task kinds exist: winter pruning, leaf removal, green harvest, cap management.
- Each task is announced in the Inbox with "Do it in 3D" and "Let the crew do it (plan: …)", has a due date, and falls back to the plan if the player does nothing.
- In 3D, a marked demonstration vine (or tank) accepts E, shows the options as clickable parts with an explanation, and after confirming animates the result; the crew then works the Block for a few days.
- The same decision made on the dashboard completes the task.
- Doing nothing reproduces today's game exactly: the first Vintage's outcomes and all existing tests are unchanged.
- Save/load reproduces tasks exactly.

**Non-goals** (backlog): saving wages by working yourself, harvesting in 3D, more task kinds (debudding, tying down, bâtonnage, topping up barrels), tasks with skill or quality differences between player and crew.

## 2. Principle

The task is another way to make a decision the simulation already has. It never computes an outcome in the UI and never changes the physics of the choice (ADR 0001). The simulation owns tasks as dated, saved state; the 3D view shows them and sends the chosen option.

Rejected: tasks held only in the UI — there would be nowhere for due dates, defaults and crew progress to live, and replay would lose them.

## 3. The four tasks

| Kind | Opens | Due (then the plan applies) | Options (effect through existing settings) | Plan |
|---|---|---|---|---|
| `Prune` (one per Block) | 15 January of every Vintage (first Vintage included) | 1 March, or budburst if earlier | canes of 6 / 8 / 11 buds per m² → `BudLoad` Low / Balanced / High | the Block's current `BudLoad` (Côte d'Or: Low, the Mentor's pruning) |
| `LeafRemoval` (one per Block) | the Block's fruit set | fruit set + 25 days (≈ bunch closure) | morning side / afternoon side / both / none → `LeafSide`, timing Early; or "later, at véraison" → timing Late with the chosen side | current `LeafSide` / `LeafTiming` |
| `GreenHarvest` (one per Block) | the Block's véraison | véraison + 21 days, or harvest if earlier | none / about a fifth / about two fifths of the bunches → `CropThinning` 0 / 1 / 2 | current `CropThinning` (0) |
| `CapManagement` (one per red Lot) | the Lot's fermentation start | fermentation start + 2 days | pump-over 2×/day / punch-down 2×/day / délestage + pump-over / gentle 1×/day → Lot choice `Cap management` 0–3 | the Lot's current choice (the Cellar master's plan) |

Science notes (cited in `docs/science/canopy-and-yield.md` and `extraction-and-oak.md`): winter pruning happens in dormancy and must be finished before budburst; fruit-zone leaf removal is done between fruit set and bunch closure (early) or around véraison (late); green harvest is done around véraison; cap management runs through the fermentation. All the underlying effects already exist and are cited; the tasks add only timing windows, which are standard practice (`UNVERIFIED` exact day counts, labelled "Game simplification").

## 4. Simulation

### 4.1 State
`FieldTask { Id, Kind, BlockId, LotId, Opened, Due, Status, Choice, DecidedBy, Decided, CrewFrom, CrewUntil }`
- `Status`: `Open` → `Done` (player: 3D or dashboard) | `Delegated` (player chose "let the crew") | `Planned` (due date passed; the plan applied).
- `DecidedBy`: `"3d"`, `"dashboard"`, `"crew"`.
- Crew window (visual only, game simplification): `CrewFrom = decision day`, `CrewUntil = CrewFrom + crewDays`, `crewDays = clamp(ceil(areaHa × hoursPerHa / crewHoursPerDay(labour)), 1, 10)` with hours per ha: pruning 80, leaf removal 40, green harvest 30 (`UNVERIFIED` design values); cap management: the cellar crew, 1 day.
- `GameSession.Tasks` (list), created deterministically in `StepDay`.

### 4.2 Commands
- `task <id> do <option>`: applies the option through the existing setting, `Status = Done`, `DecidedBy = "3d"` (the UI sends the same command from the dashboard task panel with `C = "dashboard"`).
- `task <id> delegate`: applies the plan, `Status = Delegated`.
- Existing setting commands (`block … budload/leafside/leaftiming/thinning`, `lot … Cap management`) on a Block or Lot with an open task of the matching kind complete it (`Done`, `DecidedBy = "dashboard"`).
- Due date passed: the plan applies (it is the current setting, so nothing changes), `Status = Planned`.

### 4.3 Messages
One Inbox message per task kind and opening (not per Block): e.g. "Winter pruning: Blocks A–D (due 1 Mar)". Sender: the Mentor in the first Vintage for pruning (it replaces today's pruning message, keeping its text), otherwise the Vineyard manager (tasks 1–3) or the Cellar master (cap management). Actions: "Do it in 3D" (`task3d:<first open id>`), "Let the crew do it (plan: …)" (`taskcrew:<kind>` for every open task of that kind and opening), "Open Plot & Blocks" / "Open Winery".

### 4.4 Snapshot
`tasks`: open tasks plus tasks whose crew is still working, each `{id, kind, title, block, lot, status, due, daysLeft, plan, planLabel, choice, options: [{value, label, why}], crewActive, crewUntil, where}`. `where` is `"vineyard"` or `"hall"`. The UI never works out options or effects.

## 5. Screens (2D)
- Inbox actions `task3d:<id>` (opens the 3D view at that task's marker) and `taskcrew:<kind>`.
- A compact **Tasks** strip on Plot & Blocks (vineyard tasks) and Winery (cap management): each open task with due date, "Do it in 3D", "Let the crew do it" and the option buttons (the dashboard route).
- The Mentor's plan step "prune" is done when every pruning task of the first Vintage is decided.

## 6. 3D
- **Markers:** each open task shows a stake with a coloured ribbon and a floating label ("Winter pruning · Block B · due 1 Mar") at the demonstration vine (the vine nearest the Block's headland on the middle row) or on top of the Lot's tank.
- **Prompt:** within 2.5 m the HUD shows "E: prune this vine" (or the task's verb). E enters the close-up.
- **Close-up:** the camera moves to a fixed close view of the vine (or tank top); the mouse is released; a side panel shows the task, the staff member's plan and, for the hovered option, its explanation. Options are clickable parts:
  - pruning: three canes laid along the wire, 6 / 8 / 11 buds (labelled), click one;
  - leaf removal: leaf clusters on the morning (east of the row) and afternoon (west) side, click a side, both, or "none"; a toggle "do it later, at véraison";
  - green harvest: the bunches; clicking a level highlights the bunches it would drop;
  - cap management: four tools at the tank (pump hose, plunger, délestage tank, "gentle" hose).
  "Confirm" plays a short animation (canes cut, leaves drop, bunches fall, the plunger pushes the cap) and sends `task <id> do <option>`; Esc leaves without deciding.
- **Crew:** while `crewActive`, the crew (existing `workers.gd` figures) works the task's Block ("prune" / "canopy" pose); this replaces the calendar-based pruning/canopy crews.
- All visuals are procedural (canes, leaves, bunches as simple meshes on the existing vine model) and cheap; nothing is baked.

## 7. Testing
- Sim (xUnit): tasks open on the right day with the right due date; the plan applies at the due date and changes nothing; `do` applies the option; `delegate` applies the plan; a dashboard setting command completes the task; cap management opens only for red Lots; first-Vintage outcomes unchanged (existing tests); save → load reproduces tasks byte for byte (snapshot equality, two Vintages).
- 3D (Godot headless harness `view3d_test.gd --tasktest`): builds a game at each task's opening, walks the player to the marker, presses E, picks an option, confirms, and checks the snapshot shows the task `Done` with the setting changed; saves close-up screenshots of all four tasks for review. `scripts/fuzz.sh` presses the new buttons.

## 8. Documentation
- `docs/science/canopy-and-yield.md`: task timing windows (pruning, leaf removal, green harvest) and crew days as labelled game simplifications.
- `docs/science/extraction-and-oak.md`: cap-management task window.
- `game/src/view3d/README.md`: contract additions (`task_chosen` signal, `focus_task(id)`), markers and close-up.
- `CONTEXT.md`: **Task** (a dated job from staff: do it yourself on a demonstration vine, or let the crew do it).
