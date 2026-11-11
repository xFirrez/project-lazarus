# Session-chain hand-off (read first)

Short hand-off file for the **sequential cloud sessions** implementing `docs/DEVELOPMENT_PLAN.md`, one step per session. The full tracker (ACs, test logs, issues, human tasks) is [docs/PROGRESS.md](docs/PROGRESS.md); how to run a step is [docs/AGENT_GUIDE.md](docs/AGENT_GUIDE.md).

## Protocol
- Branch: **`claude/project-lazarus`** (all steps). Created from `claude/lazarus-dev-roadmap-h093ya` (the planning branch; `main` has only a README).
- Each session: read this file + `git log`, implement **exactly one step**, run `tools/check.sh` + relevant tests, update this file and `docs/PROGRESS.md`, add `docs/sessions/<date>_step-N.md`, commit, push, then start the next session (`create_session`, `source_revision` and `outcome_branch` = `claude/project-lazarus`, effort `medium`).
- Never redo a step listed as done below. If a step can't be completed or verified, record the blocker here, push, and stop the chain.
- **Step count:** the owner's instructions say "15 steps", but `docs/DEVELOPMENT_PLAN.md` defines **16** (Step 16 = balance/optimization/QA/release candidate). Decision (Step 1 session): the chain implements all 16 plan steps, and the PR into `main` is opened after the final step (16). Do not merge.
- Environment setup in a fresh container: `tools/install_godot.sh` (Godot 4.7.2 → `~/.local/bin/godot`) and `pip install gdtoolkit==4.5.0`, then `export PATH=$HOME/.local/bin:$PATH`.

## Status
| Step | Status | Commit summary / notes |
|---|---|---|
| 1 Foundation, toolchain & networked skeleton | ✅ Done (2026-11-11) | Godot 4.7.2 project, autoloads, Net v1 (Offline/ENet, NetSim, clock sync, uid), console/overlay, sandbox with replicated capsules, tools, CI |
| 2 Player controller & movement feel | ✅ Done (2026-11-11) | PlayerCharacter + components, PlayerTuning, movement course, MovementValidator (D-016), health events (D-017), integration/net/visual tests; AC-2.7 feel review awaits the owner |
| 3 Weapon framework & gunplay feel | ✅ Done (2026-11-11) | WeaponDefinition/Runtime, hitscan/pellet/melee (+ projectile stub), inventory + frags, viewmodel (SubViewport layer 2), FX rings, weapon HUD, HitTarget/TargetRegistry, HitValidator + WeaponSync (D-021…D-026), 4 weapons + knife + frag, gun range; M0 reached (AC-3.7 feel review awaits the owner) |
| 4 Art direction, asset pipeline & look development | ⏭ Next | |
| 5 – 16 | Not started | |

## Context for the next session (Step 4)
- Weapons: `game/core/weapons/` (definition, runtime, behaviors/, controller, viewmodel, viewmodel_animations, greybox_gun, weapon_sync, hit_validator, target_registry, hit_target, target_dummy, hurtbox, grenade), data in `content/weapons/<id>/<id>.tres`. A real weapon model plugs in through `WeaponDefinition.viewmodel_scene`; the scene must have `Mag`, `Action`, `Muzzle`, `Eject`, `Sight` nodes (Sight = point that lands on screen centre in ADS) and use render layer 2 (`Viewmodel.LAYER`).
- Viewmodel renders in a transparent SubViewport with its own Environment (ambient only; Compatibility renderer verified, Forward+ not — I-004). The main camera culls layer 2. Screenshot shots hide CanvasLayers in group `hide_for_shots`.
- Hit targets: anything weapons damage extends `HitTarget` and adds `Hurtbox`es (physics layer 3); map-placed targets get ids from `TargetRegistry.scan` (tree order); zombies (Step 5) need host-assigned ids. Damage applies only on the host via `TargetRegistry.host_damage`.
- FX: `WeaponFx` rings (decals 128 …), impact look per surface in `core/vfx/impact_library.gd` (surface from `SurfaceTags`; `flesh` added). Step 4 materials should set PhysicsMaterial names / `surface` meta so impacts and footsteps pick the right surface.
- Tests: `tests/integration/weapon_test_helper.gd` (standalone gun range rig), `tools/net_tests.sh weapons`, `tools/visual_tests.sh [out_dir] [damage_direction|viewmodel_ads]`.
- Console (Step 3): `give`, `weapons`, `weapon_info`, `ammo`, `infinite_ammo`, `damage_numbers`, `wtune`, `recoil`, `spread`, `dummy_reset`, `hit_stats`.

## Context from Step 2
- Player: `game/core/player/player_character.tscn` (+ `motor_component.gd`, `camera_rig.gd`, `health_component.gd`, `footstep_component.gd`), tuning in `content/player/player_tuning.tres`. Input arrives as `PlayerInputFrame` (`fire`, `aim` already captured; sprint ends on fire/ADS). The camera is top-level (`player.camera`, horizontal FOV); add the viewmodel camera/layer there. `camera_rig.add_trauma()` for recoil shake. ADS sensitivity multiplier is applied when `aim` is held.
- Host damage API: `Match.current.players.damage_player(peer_id, amount, source_pos, type)`; hit claims should follow the same host-authoritative pattern. Test arenas live in `maps/_test/` (the course builder in `movement_course.gd` shows the box/waypoint helpers).
- Tests: integration suites run with `--fixed-fps 60`; use `tests/integration/player_test_helper.gd` (`spawn_player`, `step(self, n)` which also ignores the benign Jolt job warning). Net pair tests: `pair_test` in `tools/net_tests.sh`. Visual checks: `tools/visual_tests.sh`.
- Console: `tune`, `player_info`, `damage`, `heal`, `god`, `noclip`, `tp`, `respawn`, `speed_hack`, `setting`, `settings_save`.

## Context from Step 1
- Key files: `game/core/autoload/net.gd` (send_reliable / send_unreliable / register_message / register_stream), `game/core/net/player_sync.gd` (stream ids 16/17, 30 Hz state, 20 Hz snapshots), `game/core/player/temp_capsule.gd` (to be replaced by the Step 2 controller; keep `bot_driver` for tests), `game/core/autoload/game.gd` (CLI flags, state machine), `game/tests/net/*` (multi-process autotests; `tools/net_tests.sh`).
- Tests: `tools/check.sh` (unit + lint), `tools/net_tests.sh` (≈20 s), `tools/run_sim.sh smoke`, `tools/screenshot.sh sandbox`.
- Format with `gdformat --line-length 120 game/core game/tests game/maps tools`.
- No Vulkan in the container: screenshots use opengl3 (D-013).
