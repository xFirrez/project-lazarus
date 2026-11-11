# Project Lazarus — Progress Tracker

> **Single source of truth for project status.** Every coding session reads this first and updates it last.
> Full step definitions and acceptance criteria text: [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md). Criteria are referenced by ID here.
> Status values: `Not started` · `In progress` · `Blocked` · `Complete` · `Complete (with deferrals)`.
> Checkbox legend: `[ ]` not met · `[x]` met (automated or verified) · `[~]` deferred (reason required in *Deferrals*) · `[H]` awaiting HUMAN verification.

---

## Current state

| Field | Value |
|---|---|
| Current milestone | Step 2 complete — no milestone reached yet (M0 after Step 3) |
| Next step to start | **Step 3 — Weapon framework & gunplay feel** |
| Engine version | Godot **4.7.2-stable** (`tools/godot_version.txt`); GUT 9.7.1; gdtoolkit 4.5.0 |
| Last updated | 2026-11-11 (Step 2 session) |
| Main branch playable? | Test maps only (sandbox, movement course; first-person movement, solo + co-op); work lives on branch `claude/project-lazarus` |

---

## Step status overview

| Step | Title | Status | Checkpoint | Last session |
|---|---|---|---|---|
| 0 | Planning & design documents | **Complete** | — | 2026-11-11 |
| 1 | Foundation, toolchain & networked skeleton | **Complete** | — | 2026-11-11 |
| 2 | Player controller & movement feel | **Complete** (AC-2.7 awaiting human) | — | 2026-11-11 |
| 3 | Weapon framework & gunplay feel (→ M0) | Not started | — | — |
| 4 | Art direction, asset pipeline & look development | Not started | 4A / 4B | — |
| 5 | Zombie AI, animation & networked enemies | Not started | 5A / 5B | — |
| 6 | Core survival loop (→ M1 First Playable) | Not started | 6A / 6B | — |
| 7 | Online co-op, lobby & player characters (→ M2) | Not started | 7A / 7B | — |
| 8 | Vesper Peak full greybox (→ M3) | Not started | 8A / 8B | — |
| 9 | Arsenal, wall-buys & Relic Box | Not started | 9A / 9B | — |
| 10 | Vigor Tonics & power-ups | Not started | — | — |
| 11 | Relays, Lazarus Forge, traps & hazards | Not started | 11A / 11B | — |
| 12 | Wonder weapons & special enemies (→ M4) | Not started | 12A / 12B | — |
| 13 | Vesper Peak art & atmosphere (→ M5) | Not started | 13A / 13B / 13C / 13D | — |
| 14 | Easter egg, lore & secrets | Not started | 14A / 14B | — |
| 15 | Presentation & audio finalization (→ M6) | Not started | 15A / 15B | — |
| 16 | Balance, optimization, QA & release (→ M7 1.0) | Not started | 16A / 16B | — |

---

## Acceptance criteria checklists

### Step 0 — Planning
- [x] ARCHITECTURE.md, DEVELOPMENT_PLAN.md, GAME_DESIGN.md, VESPER_PEAK.md, PROGRESS.md, AGENT_GUIDE.md created
- [x] Roadmap self-review completed (DEVELOPMENT_PLAN §20)
- [H] Human review and approval of the plan

### Step 1 — Foundation
- [x] AC-1.1 Headless import clean; `check.sh` passes locally + CI (CI workflow `.github/workflows/ci.yml`; see test log for the first CI run)
- [x] AC-1.2 Unit tests: Config, NetSim, player_uid
- [x] AC-1.3 Two-peer loopback sandbox, replicated positions within 0.2 m @100 ms
- [x] AC-1.4 Solo via OfflineTransport, no special-case branches
- [x] AC-1.5 Console commands + net overlay (interactive `~` console UI: [H] quick check, see human tasks)
- [x] AC-1.6 Clean disconnect / host-loss handling
- [x] AC-1.7 Screenshot pipeline works in container (opengl3 fallback, D-013)

### Step 2 — Player controller
- [x] AC-2.1 Bot completes movement course (solo from all 4 spawns: `test_movement_course.gd`; client @100 ms ±20 ms, 2% loss: `net_tests.sh course`, 0 host corrections)
- [x] AC-2.2 Speeds / stamina within tolerance (`test_player_motor.gd`)
- [x] AC-2.3 Zero tunneling over 10k random frames (`test_player_tunneling.gd`, static geometry; moving platforms excluded — see test note)
- [x] AC-2.4 Damage/regen timing + feedback (`test_health_regen.gd`; `tools/visual_tests.sh` screenshots; host→client damage in `net_tests.sh replication`)
- [x] AC-2.5 Smooth remote motion under NetSim; speed-hack corrected (`net_tests.sh replication`, `speedhack`)
- [x] AC-2.6 Crouch ceiling + slide edge cases (`test_movement_course.gd`)
- [H] AC-2.7 [HUMAN] Movement feel review

### Step 3 — Weapons
- [ ] AC-3.1 Damage/falloff/penetration/RPM unit tests
- [ ] AC-3.2 Reload state machine edge cases
- [ ] AC-3.3 Range integration: per-hitzone damage, penetration count
- [ ] AC-3.4 Net hit claims + host validation
- [ ] AC-3.5 No viewmodel clipping; ADS alignment
- [ ] AC-3.6 Pools/decals capped, no memory growth
- [ ] AC-3.7 [HUMAN] Gunplay feel review
- [ ] **M0 reached**

### Step 4 — Art direction & pipeline
- [ ] AC-4.1 Scripted kit, correct collision, grid snapping
- [ ] AC-4.2 Retargeted zombie animations + bone hitboxes
- [ ] AC-4.3 [HUMAN] Look-dev perf (High ≥120 FPS ref, Medium ≥60 FPS min) + automated draw-call/light checks
- [ ] AC-4.4 [HUMAN] Reference screenshots approved
- [ ] AC-4.5 ASSET_LICENSES complete
- [ ] AC-4.6 Runtime quality preset switching

### Step 5 — Zombie AI
- [ ] AC-5.1 32 zombies reach targets on all floors; no permanent stuck
- [ ] AC-5.2 Multi-floor pursuit; path-distance targeting
- [ ] AC-5.3 Barricade tear/climb flow, replicated
- [ ] AC-5.4 Hit reactions, gibs, crawlers, ragdoll pool
- [ ] AC-5.5 AI+nav ≤ 1.5 ms avg / ≤ 3 ms p99 @32 ([HUMAN] desktop confirm)
- [ ] AC-5.6 ≤ 15 KB/s zombie snapshots; ≥ 98% hit-claim acceptance on moving targets
- [ ] AC-5.7 10-minute soak, clean log
- [ ] AC-5.8 [HUMAN] Threatening, readable zombies

### Step 6 — Core survival loop
- [ ] AC-6.1 Round formulas rounds 1–50 × 1–4 players
- [ ] AC-6.2 Round end/requeue/intermission correctness
- [ ] AC-6.3 Spawn fairness over 20-round soak
- [ ] AC-6.4 Economy correctness + no double-spend
- [ ] AC-6.5 Doors: nav + spawners + late-join replication
- [ ] AC-6.6 Downed/revive/bleedout/game over in co-op
- [ ] AC-6.7 4-bot soak to round 15, stable memory, no orphans
- [ ] AC-6.8 [HUMAN] Solo round 8+ and LAN co-op playtest
- [ ] **M1 reached**

### Step 7 — Online co-op
- [ ] AC-7.1 4-client NetSim 10-round state convergence
- [ ] AC-7.2 Late join < 2 s, correct state
- [ ] AC-7.3 Reconnect restores state
- [ ] AC-7.4 ≤ 25 KB/s per client
- [ ] AC-7.5 4 characters + third-person anims + arms
- [ ] AC-7.6 [HUMAN] Internet session 10+ rounds
- [ ] **M2 reached**

### Step 8 — Vesper Peak greybox
- [ ] AC-8.1 All zones/doors with canonical ids, costs, unlocks
- [ ] AC-8.2 nav_validate passes
- [ ] AC-8.3 Travel-time targets met
- [ ] AC-8.4 Gondola / lift / chute in solo + co-op
- [ ] AC-8.5 Power-on sequence + replication
- [ ] AC-8.6 Marker manifest complete
- [ ] AC-8.7 [HUMAN] Full-map greybox perf baseline
- [ ] AC-8.8 [HUMAN] Flow playtest
- [ ] **M3 reached**

### Step 9 — Arsenal & Relic Box
- [ ] AC-9.1 All weapon stats match spec table
- [ ] AC-9.2 Full animation/audio set per weapon; ADS alignment
- [ ] AC-9.3 Projectile splash/self-damage/crossbow sticking
- [ ] AC-9.4 Box roll statistics + doll/relocation rules
- [ ] AC-9.5 Box co-op ownership + synchronized carousel + late join
- [ ] AC-9.6 Decoy attraction
- [ ] AC-9.7 [HUMAN] Weapon + box review

### Step 10 — Tonics & power-ups
- [ ] AC-10.1 Perk effects measured
- [ ] AC-10.2 Cap, loss on down, Second Wind variants
- [ ] AC-10.3 Drop simulation rules
- [ ] AC-10.4 Power-ups replicate; timers agree within 100 ms
- [ ] AC-10.5 [HUMAN] Machine visuals approved
- [ ] AC-10.6 [HUMAN] Perks/power-ups feel impactful

### Step 11 — Relays, Forge, traps, hazards
- [ ] AC-11.1 Relay sequence + bridge + replication
- [ ] AC-11.2 Forge upgrades every conventional weapon correctly
- [ ] AC-11.3 All upgraded behavior changes implemented
- [ ] AC-11.4 Traps per spec + replication
- [ ] AC-11.5 Hazards + resets
- [ ] AC-11.6 [HUMAN] Forge feels rewarding

### Step 12 — Wonder weapons & specials
- [ ] AC-12.1 Ray Pistol spec + upgrade bounce
- [ ] AC-12.2 Conduit chains/stun/pulse + upgrade
- [ ] AC-12.3 Buildable parts/workbench/box unlock
- [ ] AC-12.4 Special round scheduling/scaling/Max Ammo
- [ ] AC-12.5 Warden archetype in test arena
- [ ] AC-12.6 VFX performance ([HUMAN] GPU confirm)
- [ ] AC-12.7 [HUMAN] Wonder weapons + special rounds feel
- [ ] **M4 reached**

### Step 13 — Art & atmosphere
- [ ] 13A Exterior · [ ] 13B Sanatorium · [ ] 13C Underground · [ ] 13D Reactor + global pass
- [ ] AC-13.1 Marker diff unchanged
- [ ] AC-13.2 nav_validate after art
- [ ] AC-13.3 [HUMAN] Full-map performance targets
- [ ] AC-13.4 Ambience/reverb/vignettes complete
- [ ] AC-13.5 Landmark sightlines
- [ ] AC-13.6 [HUMAN] Visual review per checkpoint
- [ ] **M5 reached**

### Step 14 — Easter egg & lore
- [ ] AC-14.1 Each stage solo + 4-player
- [ ] AC-14.2 No permanent lock on failure
- [ ] AC-14.3 Late join/reconnect per stage
- [ ] AC-14.4 Finale + rewards + badge
- [ ] AC-14.5 Lore, reels, secrets, Journal persistence
- [ ] AC-14.6 [HUMAN] Full EE run without debug

### Step 15 — Presentation & audio
- [ ] AC-15.1 All screens navigable (M/KB/gamepad), rebinding persists
- [ ] AC-15.2 HUD resolution/scale matrix
- [ ] AC-15.3 No unaccepted placeholder audio
- [ ] AC-15.4 Mix: no clipping; VO intelligible
- [ ] AC-15.5 Credits complete
- [ ] AC-15.6 [HUMAN] Presentation review
- [ ] **M6 reached**

### Step 16 — Balance, optimization, QA, release
- [ ] AC-16.1 No S1/S2 bugs
- [ ] AC-16.2 2-hour solo + 4p sessions stable
- [ ] AC-16.3 [HUMAN] Performance targets; no hitches > 50 ms
- [ ] AC-16.4 Round-60 bot soak; [HUMAN] round-50 beatable
- [ ] AC-16.5 [HUMAN] Economy pacing within ±2 rounds
- [ ] AC-16.6 [HUMAN] Clean-machine builds connect
- [ ] AC-16.7 QA plan ≥ 95% pass
- [ ] **M7 reached — Vesper Peak 1.0**

---

## Test results log

Record automated results (command, pass/fail counts, key numbers) and human verification outcomes. Newest first.

| Date | Step | Test / check | Result | Notes |
|---|---|---|---|---|
| 2026-11-11 | 2 | `tools/check.sh` | Pass | 13 scripts / 64 tests / 1395 asserts |
| 2026-11-11 | 2 | `tools/run_tests.sh integration` (`--fixed-fps 60`) | Pass | 3 scripts / 16 tests. Walk 4.60, sprint 6.60, crouch 2.40 m/s (±3%); sprint 4.0 s, recharge 3.8 s (0.8 + 3.0, ±0.1); apex 1.0 m; slide 0.7 s + 1.0 s cooldown; bot course from all 4 spawns in 28.0 s (2 mantles, 1 slide, elevator, 5 m drops, no damage); 1.5 m ledge not mantleable; 1.5 m ceiling keeps crouch; slide ends crouched in the 1.3 m tunnel; shuttle carries the player; 10,000 random frames: 0 static overlaps, 0 fall-through (also checked with 7 other seeds) |
| 2026-11-11 | 2 | `tools/net_tests.sh` (solo, replication, host_loss, speedhack, course) | Pass | NetSim 100 ms ±20 ms, 2% loss. Replication: remote sprint-circle max error 0.007–0.015 m, max per-frame step 0.15–0.17 m (no snapping), 0 corrections for a legit client; host damage 40 from the client's left → client HP 60, indicator at ~105°, regen to 100. Speed hack ×3: 4 corrections in 3 s, validated speed 8.6–9.1 m/s (limit 10.5) while the client tried ~14 m/s. Client course run: completed in 27.9 s, RTT ~210 ms, 0 corrections |
| 2026-11-11 | 2 | `tools/visual_tests.sh` | Pass | Indicator redness left/right 0.64/0.00 (hit from left), 0.00/0.71 (from right); corner vignette −0.15 → +0.05 and stronger at 70% missing. Frames: `docs/screenshots/damage_hud_*.png` |
| 2026-11-11 | 2 | `tools/run_sim.sh smoke`, `tools/screenshot.sh movement_course` | Pass | `docs/screenshots/movement_course_shot_*.png` |
| 2026-11-11 | 1 | `tools/check.sh` (import, gdlint, gdformat, boundary, prints, unit) | Pass | 9 scripts / 36 tests / 1092 asserts |
| 2026-11-11 | 1 | `tools/net_tests.sh` solo / replication / host_loss | Pass | NetSim 100 ms ±20 ms, 2% loss on both peers. Connect 0.43 s; replicated host capsule max error 0.011–0.016 m (mean 0.001 m, 301 samples); client capsule removed 0.017 s after peer_left; client back in menu with "Host disconnected" ~1.9 s after host kill -9 |
| 2026-11-11 | 1 | `tools/run_coop_local.sh 3 --netsim=100,20,0.02` | Pass | both clients see 3 capsules ~0.55 s after launch |
| 2026-11-11 | 1 | `tools/run_sim.sh smoke` | Pass | 5 s solo, no errors, 0 orphan nodes |
| 2026-11-11 | 1 | `tools/screenshot.sh sandbox` | Pass | `docs/screenshots/sandbox_overview.png`, `sandbox_ramps.png` (opengl3/llvmpipe, overlay visible) |
| 2026-11-11 | 0 | Documentation review | Pass | Planning docs created; no code yet |

### Performance baselines

| Date | Step | Scene | Preset | Hardware | Avg FPS | p99 frame ms | AI ms | Notes |
|---|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — | — |

### Network baselines

| Date | Step | Peers | NetSim profile | KB/s per client | Desyncs | Notes |
|---|---|---|---|---|---|---|
| 2026-11-11 | 2 | 2 (loopback) | 100 ms ±20 ms, 2% loss | ~1 (player state 30 Hz: pos, yaw, pitch, flags, seq; snapshots 20 Hz) | 0 | Replication error max 0.015 m; 0 false corrections |
| 2026-11-11 | 1 | 2 (loopback) | 100 ms ±20 ms, 2% loss | < 1 (capsule state 30 Hz + snapshots 20 Hz, float32 positions) | 0 | Replication error max 0.016 m; quantization deferred to Step 5 |

---

## Unresolved issues

| ID | Severity (S1–S4) | Step found | Description | Owner/plan |
|---|---|---|---|---|
| I-002 | S4 | 2 | Headless `--fixed-fps` integration runs sometimes log "Jolt Physics job system exceeded the maximum number of jobs … Waiting for jobs" (engine warning; physics continues). Not seen in real-time runs | Marked benign in `tests/integration/player_test_helper.gd`; re-check after engine upgrades |
| I-003 | S3 | 2 | Test-map moving platforms (course elevator/shuttle) are simulated locally per peer, so a remote player riding one is seen on the host's copy of the platform only approximately | Step 8 makes traversal machines host-driven (D-020) |
| I-001 | S4 | 1 | `tools/net_tests.sh` failed once (output not captured) while it was being tuned; 21 later consecutive runs passed. Possible rare timing flake in the multi-process tests | Watch CI; logs are kept in `.test-results/net/` and uploaded by CI on failure |

Severity: **S1** crash / data loss / progress-blocking · **S2** major feature broken · **S3** minor feature issue / visual bug · **S4** polish.

## Deferrals

| AC / item | Deferred to | Reason |
|---|---|---|
| ~~Owner-movement validation~~ | — | Done in Step 2 (D-016) |
| Settings UI for sensitivity / ADS multiplier / FOV / bob / shake / hold-toggle | Step 15 (15A menus) | Settings exist in `Config` and are live-editable with the `setting` console command; the menu screens are Step 15 work |
| Downed state (last stand) | Step 6 | Step 2 provides the hook: at 0 HP the host restores the player after 3 s (placeholder) |
| `NetId` entity registry + reliable spawn/despawn | Step 5 | First needed for zombies; player avatars are keyed by peer id |
| Snapshot quantization | Step 5 | Bandwidth is negligible with ≤ 4 capsules |

## Proposed design changes (awaiting human decision)

| Date | Proposed by (step) | Change | Rationale | Decision |
|---|---|---|---|---|
| 2026-11-11 | 1 | Work is implemented on branch `claude/project-lazarus` (created from the planning branch `claude/lazarus-dev-roadmap-h093ya`, since `main` holds no plan), one cloud session per step, with a PR into `main` after the final step | Owner's instruction for sequential cloud sessions | Owner instruction |

---

## Human tasks (things only the project owner can do)

| Needed by | Task | Status |
|---|---|---|
| Step 0 | Review and approve the planning documents; confirm original naming approach (GAME_DESIGN §1.3) | Open |
| Step 2+ | Run local playtests for [HUMAN] criteria (feel, visuals, performance on real GPU) | Recurring |
| Step 4 | Confirm the reference hardware (min + recommended GPUs) available for testing | Open |
| Step 4 | Optional: download Mixamo animations (requires Adobe account) if CC0 libraries are insufficient | Open |
| Step 4 | Confirm Blender availability (container install or local run of `tools/blender/` scripts) | Open |
| Step 7 | Have a friend available for an internet co-op test; install Steam client if Steam transport is used | Open |
| Step 13 | Optional: LightmapGI bakes on a desktop GPU | Open |
| Step 15 | Provide or approve music (jingles, EE song), VO approach (recorded vs. TTS), and fonts | Open |
| Any | Monitor Git LFS storage/bandwidth quota | Recurring |
| Step 1 | Quick desktop check: `godot --path game`, Solo, press `~` (console: try `help`, `net_status`, Tab completion, Up/Down history), F3 overlay; then `tools/run_coop_local.sh 2 --windowed` and walk both capsules | Open |
| Step 1 | Confirm the first GitHub Actions run of `.github/workflows/ci.yml` is green (Actions tab) | Open |
| Step 2 | AC-2.7 movement feel review on the movement course (steps in `docs/sessions/2026-11-11_step-2.md`); record any `tune` changes in the GAME_DESIGN tuning log | Open |

---

## Session history

Each session adds a row and a report file `docs/sessions/YYYY-MM-DD_step-N[-checkpoint].md`.

| Date | Step | Summary | Report |
|---|---|---|---|
| 2026-11-11 | 0 | Planning: architecture, roadmap, game design, map design, tracker, agent guide | (planning commit) |
| 2026-11-11 | 1 | Godot 4.7.2 project, autoloads, Net layer v1 (Offline/ENet, NetSim, clock sync, uid), console + overlay, sandbox with replicated capsules, tool scripts, CI | [2026-11-11_step-1.md](sessions/2026-11-11_step-1.md) |
| 2026-11-11 | 2 | PlayerCharacter (motor, camera rig, health + damage HUD, footsteps), PlayerTuning, movement course, host movement validation, health replication, bot/random drivers, integration + net + visual tests | [2026-11-11_step-2.md](sessions/2026-11-11_step-2.md) |
