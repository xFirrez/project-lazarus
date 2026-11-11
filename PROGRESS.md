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
| 2 Player controller & movement feel | ⏭ Next | |
| 3 – 16 | Not started | |

## Context for the next session
- Key files: `game/core/autoload/net.gd` (send_reliable / send_unreliable / register_message / register_stream), `game/core/net/player_sync.gd` (stream ids 16/17, 30 Hz state, 20 Hz snapshots), `game/core/player/temp_capsule.gd` (to be replaced by the Step 2 controller; keep `bot_driver` for tests), `game/core/autoload/game.gd` (CLI flags, state machine), `game/tests/net/*` (multi-process autotests; `tools/net_tests.sh`).
- Tests: `tools/check.sh` (unit + lint), `tools/net_tests.sh` (≈20 s), `tools/run_sim.sh smoke`, `tools/screenshot.sh sandbox`.
- Format with `gdformat --line-length 120 game/core game/tests game/maps tools`.
- No Vulkan in the container: screenshots use opengl3 (D-013).
