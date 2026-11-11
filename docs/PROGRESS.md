# Project Lazarus — Progress Tracker

> **Single source of truth for project status.** Every coding session reads this first and updates it last.
> Full step definitions and acceptance criteria text: [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md). Criteria are referenced by ID here.
> Status values: `Not started` · `In progress` · `Blocked` · `Complete` · `Complete (with deferrals)`.
> Checkbox legend: `[ ]` not met · `[x]` met (automated or verified) · `[~]` deferred (reason required in *Deferrals*) · `[H]` awaiting HUMAN verification.

---

## Current state

| Field | Value |
|---|---|
| Current milestone | Planning complete — no milestone reached yet |
| Next step to start | **Step 1 — Foundation, toolchain & networked skeleton** |
| Engine version | *(to be pinned in Step 1)* |
| Last updated | 2026-11-11 (planning session) |
| Main branch playable? | No (no code yet) |

---

## Step status overview

| Step | Title | Status | Checkpoint | Last session |
|---|---|---|---|---|
| 0 | Planning & design documents | **Complete** | — | 2026-11-11 |
| 1 | Foundation, toolchain & networked skeleton | Not started | — | — |
| 2 | Player controller & movement feel | Not started | — | — |
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
- [ ] AC-1.1 Headless import clean; `check.sh` passes locally + CI
- [ ] AC-1.2 Unit tests: Config, NetSim, player_uid
- [ ] AC-1.3 Two-peer loopback sandbox, replicated positions within 0.2 m @100 ms
- [ ] AC-1.4 Solo via OfflineTransport, no special-case branches
- [ ] AC-1.5 Console commands + net overlay
- [ ] AC-1.6 Clean disconnect / host-loss handling
- [ ] AC-1.7 Screenshot pipeline works in container

### Step 2 — Player controller
- [ ] AC-2.1 Bot completes movement course (solo + client @100 ms)
- [ ] AC-2.2 Speeds / stamina within tolerance
- [ ] AC-2.3 Zero tunneling over 10k random frames
- [ ] AC-2.4 Damage/regen timing + feedback
- [ ] AC-2.5 Smooth remote motion under NetSim; speed-hack corrected
- [ ] AC-2.6 Crouch ceiling + slide edge cases
- [ ] AC-2.7 [HUMAN] Movement feel review

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
| 2026-11-11 | 0 | Documentation review | Pass | Planning docs created; no code yet |

### Performance baselines

| Date | Step | Scene | Preset | Hardware | Avg FPS | p99 frame ms | AI ms | Notes |
|---|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — | — |

### Network baselines

| Date | Step | Peers | NetSim profile | KB/s per client | Desyncs | Notes |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — |

---

## Unresolved issues

| ID | Severity (S1–S4) | Step found | Description | Owner/plan |
|---|---|---|---|---|
| — | — | — | — | — |

Severity: **S1** crash / data loss / progress-blocking · **S2** major feature broken · **S3** minor feature issue / visual bug · **S4** polish.

## Deferrals

| AC / item | Deferred to | Reason |
|---|---|---|
| — | — | — |

## Proposed design changes (awaiting human decision)

| Date | Proposed by (step) | Change | Rationale | Decision |
|---|---|---|---|---|
| — | — | — | — | — |

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

---

## Session history

Each session adds a row and a report file `docs/sessions/YYYY-MM-DD_step-N[-checkpoint].md`.

| Date | Step | Summary | Report |
|---|---|---|---|
| 2026-11-11 | 0 | Planning: architecture, roadmap, game design, map design, tracker, agent guide | (this commit) |
