# Project Lazarus — Agent Guide

> For any AI coding agent (or human) picking up work on Project Lazarus in a new session with no prior context. Read this file fully before writing code.

---

## 1. What this project is

Project Lazarus is a 3D first-person, round-based zombie survival game with solo and 4-player online co-op, built in **Godot 4 with typed GDScript**. The first (and currently only) map is **Vesper Peak**. Development follows a fixed roadmap of 16 steps; each session implements **one step or one checkpoint** of a step.

## 2. Reading order (every session)

1. `docs/PROGRESS.md`: current state, the next step, open issues, deferrals, human tasks.
2. `docs/DEVELOPMENT_PLAN.md`: **your assigned step** in full, plus its dependencies' acceptance criteria (what you can rely on).
3. `docs/ARCHITECTURE.md`: always read §3 (layout), §4 (runtime rules), §5 (networking). Read other sections as relevant.
4. `docs/GAME_DESIGN.md`: sections relevant to your step (numbers live here).
5. `docs/VESPER_PEAK.md`: if your step touches the map (canonical ids!).
6. The latest 1–2 reports in `docs/sessions/`.
7. Skim the existing code in the folders you will touch before adding anything.

If the user's instruction conflicts with these docs, **the user wins**. Note the deviation in PROGRESS.md under *Proposed design changes* (or the Decision Log, for architecture).

## 3. Non-negotiable rules

1. **Host authority.** Gameplay state changes only on the host. Clients send requests or claims. Never mutate shared state from a client (ARCHITECTURE §4, §5).
2. **One code path for solo and co-op.** No `if solo:` branches in gameplay systems. Test every feature with 2 peers (`tools/run_coop_local.sh 2`).
3. **`core/` never references `maps/`.** Map-specific behavior goes in `maps/<map>/scripts/` through `MapRules`, `MapDefinition`, or new generic hooks in core.
4. **Data-driven content.** Stats, prices and curves live in `.tres` resources, not hard-coded constants. GAME_DESIGN.md numbers must match the data.
5. **Typed GDScript everywhere.** Static types on every variable, parameter and return. Treat warnings as errors.
6. **Canonical ids.** Use the zone, door and object ids from VESPER_PEAK.md for node names, data and tests (`Z03`, `D05`, `R2`, `T1` …).
7. **Gameplay markers are sacred.** In map scenes, nodes under `Gameplay/` (spawners, interactables, machine markers) don't move during art passes unless the change is logged.
8. **No unlicensed assets.** Every third-party file gets an entry in `docs/ASSET_LICENSES.md` (source URL, author, license). If the license is unknown, don't use the file.
9. **Original identity.** Use the Project Lazarus names (GAME_DESIGN §1.3). Don't import names, logos, audio, models or voice lines from Call of Duty or any other commercial game.
10. **Never silently cut scope.** If something can't be done, log it as a deferral or issue with a reason and a plan.
11. **Leave `main` playable.** From Step 6 onward, the game must launch and be playable at the end of every session.

## 4. Godot 4 pitfalls (avoid Godot 3 syntax)

| Use (Godot 4) | Not (Godot 3) |
|---|---|
| `@export var x: int`, `@onready var n: Node = $N` | `export var`, `onready var` |
| `signal hit(amount: int)` / `hit.emit(5)` / `hit.connect(_on_hit)` | `emit_signal("hit")`, `connect("hit", self, "_on_hit")` |
| `CharacterBody3D` + `velocity` property + `move_and_slide()` | `KinematicBody`, `move_and_slide(velocity)` |
| `@rpc("any_peer", "call_local", "reliable")` | `remote`, `remotesync`, `master`, `puppet` |
| `multiplayer.get_unique_id()`, `is_multiplayer_authority()` | `get_tree().get_network_unique_id()` |
| `await get_tree().create_timer(1.0).timeout` | `yield(...)` |
| `Node3D`, `Transform3D`, `basis`, `global_position` | `Spatial`, `Transform`, `translation` |
| `super()` / `super.method()` | `.method()` |
| `FileAccess.open()`, `DirAccess` | `File.new()`, `Directory.new()` |
| `Callable(obj, "m")` / `obj.m` | `funcref` |
| `NavigationAgent3D` + `NavigationServer3D` | `Navigation` node |
| `PackedFloat32Array`, `PackedVector3Array` | `PoolRealArray`, `PoolVector3Array` |

Check the pinned engine version in `tools/godot_version.txt` and use only APIs available in it. When unsure, check the class reference for that version.

## 5. Implementing an assigned step

1. **Plan:** list the step's scope items and acceptance criteria and write a short plan (in your scratchpad or the session report draft). Identify which ACs are automated and which are [HUMAN].
2. **Branch:** work on the branch you were given (or `step-N-<slug>` if none was given). Commit in logical units with clear messages (`step5: crowd director path budget`).
3. **Build test-first where practical:** formulas, state machines and economy logic get unit tests before or with the code. Gameplay flows get headless integration tests.
4. **Add debug commands** for every new feature (console registry in `core/debug/`). Testing a round-30 feature must never require playing 30 rounds.
5. **Add feedback:** every interaction has visual and audio feedback (placeholder at minimum, registered through the `Audio` autoload with a named event).
6. **Networking pass:** before calling a feature done, run it with 2 peers under NetSim (`--netsim=100,20,0.02`). Add or extend a test in `game/tests/net/`. Extend the full-match snapshot if you added shared state (late join must work).
7. **Performance pass:** if you touched AI, VFX, rendering or anything per-frame, run the relevant benchmark and record numbers in PROGRESS.md.
8. **Checkpoint discipline:** if a step has checkpoints and you're running out of context or time, finish the current checkpoint cleanly (tests passing, docs updated) rather than leaving several half-done pieces.

## 6. Testing commands

| Command | Purpose |
|---|---|
| `tools/check.sh` | Lint, format check, core→maps boundary check, unit tests. **Run before every commit.** |
| `tools/run_tests.sh unit\|integration\|net\|all` | GUT test suites, headless |
| `tools/run_sim.sh <scenario> [args]` | Headless simulations: `smoke`, `soak --rounds 20 --bots 4`, `perf_arena`, `nav_validate vesper_peak`, `quest <stage>` |
| `tools/run_coop_local.sh <N> [--netsim=ms,jitter,loss] [--windowed]` | Host + N−1 clients on localhost |
| `tools/screenshot.sh <shot_set>` | Software-rendered screenshots of named camera shots → `docs/screenshots/` |
| `godot --path game` | Run the game (desktop) |

(Scripts are created in Step 1 and extended later. If one doesn't exist yet, creating it is part of your step.)

**Minimum bar before reporting completion:** `tools/check.sh` green, all tests for touched systems green, `run_sim.sh smoke` green (from Step 6 on), and a 2-peer manual or automated run of the new feature.

## 7. Updating documentation (end of every session)

1. **PROGRESS.md:**
   - Step status and checkpoint; tick AC checkboxes (`[x]` met, `[H]` awaiting human, `[~]` deferred with a row in *Deferrals*).
   - Add rows to the *Test results log*, plus performance and network baselines if measured.
   - Add new issues to *Unresolved issues* with severity; close fixed ones (strike through or remove them, and mention the fix in the session report).
   - Update *Current state* (next step, milestone, whether main is playable).
   - Add new *Human tasks* (playtests needed, assets needed).
   - Add a row to *Session history*.
2. **Session report** `docs/sessions/YYYY-MM-DD_step-N[-X].md` using the template in §10.
3. **Design/architecture docs:** if you changed a number, add a row to the GAME_DESIGN tuning log. If you changed an architecture decision, add a row to the ARCHITECTURE decision log. If you changed the map layout, update VESPER_PEAK.md and the marker manifest.
4. **ASSET_LICENSES.md** for any new third-party asset.

## 8. Things agents can't do in the cloud container

- **GPU performance and feel** checks → mark [H] and list the exact steps for the human to perform in the session report ("Launch `godot --path game`, run console `bench perf_arena`, report avg/p99 FPS").
- **LightmapGI baking** needs the desktop editor with a GPU → document it as a human task.
- **Steam** needs a running Steam client → implement and unit-test the transport, and leave the live test to the human.
- **Account-gated downloads** (Mixamo, some asset stores) → ask via *Human tasks*.
- Visuals: software-rendered screenshots are slow and approximate. Use them for composition and regression checks, not for final color or performance judgments.

## 9. Reporting completion (message to the user)

At the end of a session, reply with:

1. **Step / checkpoint** worked on and final status.
2. **What was built** (systems, scenes, assets), in a short list.
3. **Acceptance criteria:** each AC id with ✅ met / 🟡 awaiting human / ⏸ deferred (with reason) / ❌ not met.
4. **Test evidence:** commands run and results (pass counts, key numbers).
5. **Human actions needed:** exact playtest or verification instructions.
6. **Issues and risks** discovered, and suggested next session.
7. Confirmation that the docs were updated and the work was committed and pushed.

## 10. Session report template

```markdown
# Session report — YYYY-MM-DD — Step N[X]: <title>

## Goal
<one paragraph: what this session set out to do>

## Completed
- ...

## Acceptance criteria
| AC | Status | Evidence |
|---|---|---|
| AC-N.1 | met / [H] / deferred / not met | test name, command output summary, screenshot path |

## Tests run
- `tools/check.sh` → pass (N tests)
- ...

## Decisions & deviations
- <any design/architecture deviation + where it was logged>

## Known issues / follow-ups
- <issue ids added to PROGRESS.md>

## Human verification needed
1. <exact steps>

## Next recommended session
<step / checkpoint and any prep needed>
```

## 11. Conventions

- **Files:** `snake_case.gd`, `snake_case.tscn`; class names `PascalCase` via `class_name`. One class per file.
- **Node naming:** `PascalCase`; gameplay markers named by canonical id (`D05_SurgicalDoors`, `R2_Relay`, `Box_Z07`).
- **Resources:** definitions in `content/<category>/<id>/<id>.tres`; ids are `snake_case` `StringName`s (`&"mp40"`, `&"ironhide_stout"`).
- **Signals:** past tense (`zombie_killed`, `door_opened`). RPC functions prefixed `_rpc_` (`_rpc_request_purchase`).
- **Logging:** `Log.info(&"category", "message")`. No bare `print()` in committed code.
- **Comments:** explain *why*, not *what*. Every system file starts with a short header comment naming its responsibility and authority (host/client/both).
- **Commits:** prefix with the step (`step3:`), imperative mood, one concern per commit.
- **Tests:** `test_<system>_<behavior>.gd`, in `tests/unit|integration|net/`.

## 12. When something in the plan seems wrong

The plan is a strong baseline, not scripture. If you find a real problem (a dependency gap, an infeasible criterion, a design flaw):

1. Don't silently diverge.
2. Make the smallest reasonable decision that keeps the project moving.
3. Record it: PROGRESS.md *Proposed design changes* (for design), the ARCHITECTURE decision log (for tech), and explain it in your completion report.
