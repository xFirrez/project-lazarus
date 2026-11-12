# Project Lazarus — Progress Tracker

> **Single source of truth for project status.** Every coding session reads this first and updates it last.
> Full step definitions and acceptance criteria text: [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md). Criteria are referenced by ID here.
> Status values: `Not started` · `In progress` · `Blocked` · `Complete` · `Complete (with deferrals)`.
> Checkbox legend: `[ ]` not met · `[x]` met (automated or verified) · `[~]` deferred (reason required in *Deferrals*) · `[H]` awaiting HUMAN verification.

---

## Current state

| Field | Value |
|---|---|
| Current milestone | **M4 Gameplay complete** (automated criteria; Step 12: wonder weapons, Conduit buildable, Galvanic special rounds, Warden archetype in its arena; AC-12.6 GPU + AC-12.7 feel = human checks). Previous: **M3 Whole map playable** (automated criteria; Step 8: full Vesper Peak greybox — 12 zones, 14 doors, power, gondola / lift / chute / bridge, markers, nav + flow validation; AC-8.7 GPU perf and AC-8.8 flow playtest = human checks) |
| Next step to start | **Step 13 — Vesper Peak art & atmosphere (→ M5)** |
| Engine version | Godot **4.7.2-stable** (`tools/godot_version.txt`); GUT 9.7.1; gdtoolkit 4.5.0 |
| Last updated | 2026-11-12 (Step 12 session) |
| Main branch playable? | **Yes** — `godot --path game` → main menu v1 (Solo / Host co-op → map select → **lobby** / Join ip / Settings); default map `vesper_peak` (**full greybox**: 12 zones from the Arrival Station down to the Reactor Lower Ring, 14 doors, main power switch in the Generator Hall, gondola, freight lift, laundry chute, debug-extendable Reactor Bridge, `minimap` debug overlay): 4 survivors (Calloway, Orlov, Brandt, Ashcombe), pings (middle mouse / Z), late join + reconnect; rounds, points, D01/D02, **all 10 wall-buys** (incl. Ice Axe + tripmines), the **Relic Box** (7 locations, doll relocation, `firesale`), **7 Vigor Tonic machines** (cap 4, loss on down, Second Wind solo self-revive ×3), **6 power-ups** (drops, timers, `powerup <id>`), **Resonance Relays R1–R3 → Reactor Bridge → Lazarus Forge** (23 upgraded weapons with camo, alt-fire key B), **traps T1–T3**, **hazards** (fuel drums, icicles, lab breaker), **wonder weapons** (Mk.I Ray Pistol / Nova Mk.II, Lazarus Conduit / Lazarus Requiem with pulse; box + Forge; `give raygun` / `give conduit`), the **Conduit buildable** (3 parts + Lab Workbench), **Galvanic special rounds** (rifts, warning build-up, Max Ammo; `special_round`), the **Warden** (`spawn_warden`, test map `warden_arena`), **23 weapons** + Drummer Decoy (Q) + tripmines (4), barricade rebuild, downs/revives, game over. Test maps too (sandbox, movement course, gun range, lookdev courtyard, **nav_torture** with zombies via `spawn_zombie`; first-person movement + 4 weapons, knife, frags; solo + co-op); work lives on branch `claude/project-lazarus` |

---

## Step status overview

| Step | Title | Status | Checkpoint | Last session |
|---|---|---|---|---|
| 0 | Planning & design documents | **Complete** | — | 2026-11-11 |
| 1 | Foundation, toolchain & networked skeleton | **Complete** | — | 2026-11-11 |
| 2 | Player controller & movement feel | **Complete** (AC-2.7 awaiting human) | — | 2026-11-11 |
| 3 | Weapon framework & gunplay feel (→ M0) | **Complete** (AC-3.7 awaiting human) | — | 2026-11-11 |
| 4 | Art direction, asset pipeline & look development | **Complete** (AC-4.3 / AC-4.4 awaiting human) | 4A + 4B | 2026-11-11 |
| 5 | Zombie AI, animation & networked enemies | **Complete (with deferrals)** (AC-5.5 desktop + AC-5.8 awaiting human) | 5A + 5B | 2026-11-11 |
| 6 | Core survival loop (→ M1 First Playable) | **Complete** (AC-6.8 awaiting human) | 6A + 6B | 2026-11-12 |
| 7 | Online co-op, lobby & player characters (→ M2) | **Complete** (AC-7.6 awaiting human) | 7A + 7B | 2026-11-12 |
| 8 | Vesper Peak full greybox (→ M3) | **Complete** (AC-8.7 / AC-8.8 awaiting human) | 8A + 8B | 2026-11-12 |
| 9 | Arsenal, wall-buys & Relic Box | **Complete (with deferrals)** (AC-9.7 awaiting human; authored weapon art deferred) | 9A + 9B | 2026-11-12 |
| 10 | Vigor Tonics & power-ups | **Complete (with deferrals)** (AC-10.5 / AC-10.6 awaiting human; authored machine models deferred) | — | 2026-11-12 |
| 11 | Relays, Lazarus Forge, traps & hazards | **Complete (with deferrals)** (AC-11.6 awaiting human; authored Forge / relay / trap models deferred) | 11A + 11B | 2026-11-12 |
| 12 | Wonder weapons & special enemies (→ M4) | **Complete (with deferrals)** (AC-12.6 GPU + AC-12.7 awaiting human; authored wonder-weapon / Galvanic / Warden models deferred to Step 13) | 12A + 12B | 2026-11-12 |
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
- [x] AC-3.1 Damage/falloff/penetration/RPM unit tests (`test_damage_model.gd`, `test_weapon_fire_rate.gd`, `test_weapon_definitions.gd`)
- [x] AC-3.2 Reload state machine edge cases (`test_weapon_reload.gd`)
- [x] AC-3.3 Range integration: per-hitzone damage, penetration count (`test_gun_range.gd`)
- [x] AC-3.4 Net hit claims + host validation (`net_tests.sh weapons`, `test_hit_validator.gd`)
- [x] AC-3.5 No viewmodel clipping; ADS alignment (`visual_tests.sh viewmodel_ads` at 1920×1080: 0.0 px error ×4; `test_weapon_presentation.gd`)
- [x] AC-3.6 Pools/decals capped, no memory growth (`test_mp40_60s_pools_capped_no_growth`)
- [H] AC-3.7 [HUMAN] Gunplay feel review
- [x] **M0 reached** (automated: move + shoot in the gun range, 2 peers at 100 ms; [H] LAN session with a friend)

### Step 4 — Art direction & pipeline
- [x] AC-4.1 Scripted kit, correct collision, grid snapping (`tools/blender/build_kit.sh`, 16 pieces; `test_kit_grid.gd`)
- [x] AC-4.2 Retargeted zombie animations + bone hitboxes (BoneMap → SkeletonProfileHumanoid; 12-clip library; `test_zombie_model.gd`)
- [H] AC-4.3 [HUMAN] Look-dev perf (High ≥120 FPS ref, Medium ≥60 FPS min) — automated part met: ≤ 780 draw calls (budget 1500), shadow lights 5/8 (High), 4/4 (Medium) (`visual_tests.sh lookdev_perf`)
- [H] AC-4.4 [HUMAN] Reference screenshots approved — 5 shots + first-person M1911 committed in `docs/screenshots/step4/`
- [x] AC-4.5 ASSET_LICENSES complete (all Step 4 assets generated in-house; tools listed)
- [x] AC-4.6 Runtime quality preset switching (`Graphics` autoload; `test_quality_presets.gd`; only the renderer needs a restart)

### Step 5 — Zombie AI
- [x] AC-5.1 32 zombies reach targets on all floors; no permanent stuck (`test_zombie_nav.gd`: 32/32 on F1 / F2 / F3, last arrival 19 / 28 / 24 s; 3–10 stuck/far re-queues per run respawn near the target)
- [x] AC-5.2 Multi-floor pursuit; path-distance targeting (`test_zombie_pursuit.gd`: wall case picks the path-nearer player, door re-bake retargets; height gained only on the stairs; balcony drop link used; bot route F1→F2→F3 pursued, attacked on all 3 floors, 0 re-queues)
- [x] AC-5.3 Barricade tear/climb flow, replicated (`test_zombie_barricade.gd`: 6 planks at 1.00 s / 0.80 s (run), climb, pursue, second zombie waits; `net_tests.sh zombies`: plank counts match on the client)
- [x] AC-5.4 Hit reactions, gibs, crawlers, ragdoll pool (`test_zombie_reactions.gd`; `visual_tests.sh zombie_showcase`)
- [x] AC-5.5 AI+nav ≤ 1.5 ms avg / ≤ 3 ms p99 @32 — container: 0.89 ms avg / 1.57 ms p99 (`run_sim.sh perf_arena`); [H] desktop confirm
- [x] AC-5.6 ≤ 15 KB/s zombie snapshots (9.4–9.5 KB/s @32, 100 ms / 2% loss); ≥ 98% hit-claim acceptance on moving targets (77/77) (`net_tests.sh zombies`)
- [x] AC-5.7 10-minute soak, clean log (`run_sim.sh soak`: 600 simulated s, 316 kills, 383 spawns, 0 errors / AI warnings)
- [H] AC-5.8 [HUMAN] Threatening, readable zombies

### Step 6 — Core survival loop
- [x] AC-6.1 Round formulas rounds 1–50 × 1–4 players (`test_round_curve.gd`: count / hp / interval / caps / tier mix, table-driven vs. an independent formula; GDD r15 typo logged)
- [x] AC-6.2 Round end/requeue/intermission correctness (`run_sim.sh round_flow`: re-queue back in the queue, no early end, ends only at killed == total, intermission 10.0 s, event order, last-2 promotion)
- [x] AC-6.3 Spawn fairness over 20-round soak (`run_sim.sh survival --rounds=20 --god=1`: 2,415 spawns, **0** within 8 m / in LOS, min 8.01 m, 0 stalls)
- [x] AC-6.4 Economy correctness + no double-spend (`test_points_rules.gd`, `round_flow`: hit 10 once per shot, head kill 100, purchases, refusal with UI/audio, ammo full; `net_tests.sh survival`: host + client ×2 request D02 in the same window → one 1000 charge)
- [x] AC-6.5 Doors: nav + spawners + late-join replication (`round_flow`: D01 opens, Z03 unlocked + active, path from a Z03 spawner to the player; `net_tests.sh survival`: client joining after D01 sees it open + Z03 unlocked)
- [x] AC-6.6 Downed/revive/bleedout/game over in co-op (`net_tests.sh survival` @100 ms/2 %: revive 4.02 s, 50 % HP, weapon back; bleedout 45.02 s, −10 %, weapons reset, spectate, respawn next round; all down → game over on both, client screen shown)
- [x] AC-6.7 4-bot soak (`run_sim.sh survival --rounds=15 --god=0`: died naturally at round 13, 0 errors, memory +2.5 %, orphans flat)
- [H] AC-6.8 [HUMAN] Solo round 8+ and LAN co-op playtest
- [x] **M1 reached** (automated criteria; AC-6.8 confirms the fun)

### Step 7 — Online co-op
- [x] AC-7.1 4-client NetSim 10-round state convergence (`net_tests.sh coop4`: host + 3 clients at 150 ms ±30 ms, 3 % loss, client aim bots through the real hit-claim path + host SurvivalBot, D01/D02 bought along the way: **30 / 30 state hashes match** over rounds 1–10 — round, zones, doors, barricades, flags, every player's points / weapons / lethals / perks, zombie count; 0 mismatches)
- [x] AC-7.2 Late join < 2 s, correct state (`net_tests.sh late_join`: client joins mid-round 3 → full state in **0.33 s**, world digest equals the host's (D01 open, barricade 2 planks), flag replicated, 1250 points, spectates, spawns at round 4 with the M1911)
- [x] AC-7.3 Reconnect restores state (`net_tests.sh reconnect`: client SIGKILLed and relaunched with the same profile — both before (1 s) and after (6 s) the host's timeout: 3210 points, kills stat, M14 + mirrored ammo, perk, character restored; one ledger row; waits and respawns next round)
- [x] AC-7.4 ≤ 25 KB/s per client (`coop4` phase A, 32 zombies + 4 players at 150 ms / 3 %: **12.4–12.5 KB/s avg, 13.4 KB/s peak** per client)
- [x] AC-7.5 4 characters + third-person anims + arms (`test_coop_rules`, `test_lobby_state`, `net_tests.sh lobby`: unique per lobby, taken pick refused; `test_survivor_model`: 4 retargeted models, 18 clips, per-class holds change the arm pose, locomotion under the hold layer, downed / revive / slide; arms tinted per character; `visual_tests.sh survivor_showcase` → `docs/screenshots/step7/`) — [H] visual review of the poses
- [H] AC-7.6 [HUMAN] Internet session 10+ rounds (steps in `docs/sessions/2026-11-12_step-7.md`, guide `docs/NETWORKING.md`)
- [x] **M2 reached** (automated criteria; AC-7.6 confirms over the internet)

### Step 8 — Vesper Peak greybox
- [x] AC-8.1 All zones/doors with canonical ids, costs, unlocks (`test_vesper_markers`: 12 zone volumes + MapDefinition zones with symmetric adjacency, 14 doors with §2.2 costs = 17,000, each unlocking its zones; `flow` sim buys all 14 in order → all 12 zones unlocked; `nav_validate`: every spawner of every zone paths to its activation zones once open)
- [x] AC-8.2 nav_validate passes (`tools/run_sim.sh nav_validate`: 28 tiles disjoint, 2,261 polygons; 51,707 player-reachable standable cells, **0 uncovered**, 1/64 subsample all path to the spawn; 70 spawners reach own + adjacent zones; 66 unreachable decor islands (prop tops), **0 player-reachable**; definitions D-055)
- [x] AC-8.3 Travel-time targets met (`tools/run_sim.sh flow`: Z01 → Z13 Lower Ring **35.7 s** sprint (≤ 75); worst perk → nearest perk **25.6 s** (≤ 35); worst zone → perk 15.6 s; sprinting nav bot completes the 14-leg loop through every zone in 157 s, 0 stuck legs)
- [x] AC-8.4 Gondola / lift / chute in solo + co-op (`net_tests.sh traversal` at 100 ms ±20, 2 %: client rides the gondola Z01 → Z07 and the lift Z06 → Z12 with **0 movement corrections**, arrives at the stations; a zombie boards the lift, rides down and walks off toward the host; grate shot → chute slide lands in Z12. Solo: `flow` / `nav_validate` + debug `machine`)
- [x] AC-8.5 Power-on sequence + replication (`PWR_MainSwitch` → `power.main` flag; PoweredLights cascade by zone (0.7 s per step from Z09), klaxon + sting; `traversal` client joins after power-on: flag + 38 lights powered; machines refuse without power)
- [x] AC-8.6 Marker manifest complete (`maps/vesper_peak/markers_manifest.json`, 108 typed markers + live nodes; `test_vesper_markers`: all present with kind + zone, 7 perks, 7 box locations, 14 lore, 8 reels, 3 relays, 5 ravens)
- [H] AC-8.7 [HUMAN] Full-map greybox perf baseline — automated part met: `run_sim.sh perf_arena --map=vesper_peak` (32 zombies, 4 bots, all doors open) host AI **1.29–1.42 ms avg** (≤ 1.5, every run) / p99 **2.7–3.2 ms** across 7 runs (budget 3.0 — borderline in the container, I-016); tile-local snap + path time cap, D-056; GPU FPS on Medium = human
- [H] AC-8.8 [HUMAN] Flow playtest (solo + co-op), steps in `docs/sessions/2026-11-12_step-8.md`
- [x] **M3 reached** (automated criteria; AC-8.7 / AC-8.8 confirm on hardware)

### Step 9 — Arsenal & Relic Box
- [x] AC-9.1 All weapon stats match spec table (`tests/unit/test_weapons_spec.gd` vs `tests/data/weapons_spec.json`: 23 weapons + 5 equipment)
- [x] AC-9.2 Full animation/audio set per weapon; ADS alignment (`test_weapon_presentation`: all 23 < 1 px at 1080p; draw/fire/reload partial+empty or shell set/sprint clips; mech/body/tail/interior tail/reload/raise audio; world model with Muzzle). Models are the **greybox+ fallback** (see Deferrals)
- [x] AC-9.3 Projectile splash/self-damage/crossbow sticking (`test_explosive_damage` unit + `test_projectiles` integration)
- [x] AC-9.4 Box roll statistics + doll/relocation rules (`test_relic_box_roller`: 100k rolls, worst deviation 0.18 pp)
- [x] AC-9.5 Box co-op ownership + synchronized carousel + late join (`net_tests.sh box`)
- [x] AC-9.6 Decoy attraction (`test_equipment`: 3 zombies within 25 m pulled for 8 s, 0 attacks on the player, the 62.8 m-by-path zombie isn't, explosion at 8 s)
- [H] AC-9.7 [HUMAN] Weapon + box review (steps in `docs/sessions/2026-11-12_step-9.md`)

### Step 10 — Tonics & power-ups
- [x] AC-10.1 Perk effects measured (`test_perks` + `run_sim.sh perks`: reload ×0.5, HP 250, fire rate ×1.33 + double hitscan damage, +7 % / 10 s sprint, hip −40 % / head +25 %, revive 2 s, third slot)
- [x] AC-10.2 Cap, loss on down, Second Wind variants (`run_sim.sh perks`: cap 4, all perks + Pack Mule's 3rd weapon lost, 3 solo self-revives then the machine vanishes, 4th down = game over; `net_tests.sh perks`: co-op revive 2.24 s)
- [x] AC-10.3 Drop simulation rules (`test_powerup_dropper`: rounds 1–10 avg 2.23 solo / 3.00 4p, worst round 4, no trap/Nuke drops, bag + conditions) — after the threshold tuning in *Proposed design changes*
- [x] AC-10.4 Power-ups replicate; timers agree within 100 ms (`net_tests.sh perks`: host-time timer flag identical, client clock error median 12 ms; all 6 effects in `run_sim.sh perks`)
- [H] AC-10.5 [HUMAN] Machine visuals approved (`docs/screenshots/step10/`, greybox+ machines)
- [H] AC-10.6 [HUMAN] Perks/power-ups feel impactful

### Step 11 — Relays, Forge, traps, hazards
- [x] AC-11.1 Relay sequence + bridge + replication (`run_sim.sh progression`: power gate, 20 s defend, pause outside the zone, bridge, reactor stage; `net_tests.sh progression`: client relay start, pause replicated, late-join flags)
- [x] AC-11.2 Forge upgrades every conventional weapon correctly (`test_forge_upgrades` over all 23; sim: 5000 / Fire Sale ignored / 5 s / owner take / 15 s expiry / Free Upgrade; net: client job + owner lock)
- [x] AC-11.3 All upgraded behavior changes implemented (`test_forge_upgrades` checklist + live sim checks; Ray Pistol / Conduit upgrades with the weapons in Step 12)
- [x] AC-11.4 Traps per spec + replication (sim: kills, 50 / kill to activator, player 110 HP/s, cooldown, freeze + shatter; net: client activation + points, FROZEN on client)
- [x] AC-11.5 Hazards + resets (sim: drums chain + respawn after 3 rounds, icicles + regrow after 2, breaker stun / recharge; net: drum death / respawn)
- [H] AC-11.6 [HUMAN] Forge feels rewarding (`docs/screenshots/step11/`, steps in the session report)

### Step 12 — Wonder weapons & specials
- [x] AC-12.1 Ray Pistol spec + upgrade bounce (`test_wonder_weapons`, `test_ray_pistol`: 55 m/s, 1000 + splash 1200→300 / 3 m, self ≤ 25, box weight 1.5, Nova bounces once)
- [x] AC-12.2 Conduit chains/stun/pulse + upgrade (`test_chain_lightning` dummy cluster, `test_wonder_zombies`: 6 struck ≤ 6 m, ×0.75 falloff, 1.5 s stun, pulse 8 m / 3 s no damage, Requiem 11 struck / flat 4 jumps / 2.5 s / kill arcs)
- [x] AC-12.3 Buildable parts/workbench/box unlock (`test_buildables` seeded locations; `run_sim.sh specials`; `net_tests.sh wonder` client pickup shared)
- [x] AC-12.4 Special round scheduling/scaling/Max Ammo (`test_special_rounds` 200 seeds × 50 rounds; sim: 50 rounds through RoundDirector = schedule, 6 → 8 count, 400 HP, rifts 1.5 s, warning, Max Ammo on the last kill)
- [x] AC-12.5 Warden archetype in test arena (`test_warden`: plates / core / slam / charge / summon / phases / coolant, telegraphs ≥ 0.6 s; 2-bot kill at round 20 in 4.28 min)
- [H] AC-12.6 VFX performance — automated part met (arcs / bursts / lights within WonderFx caps with 10 chained + 32 alive, host chain resolve ≤ 4 ms); GPU frame spikes need the owner
- [H] AC-12.7 Wonder weapons + special rounds feel
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
| 2026-11-12 | 12 | `tools/check.sh` | Pass | 35 unit scripts / 193 tests (new `test_wonder_weapons`, `test_chain_lightning`, `test_special_rounds`, `test_buildables`) |
| 2026-11-12 | 12 | `tools/run_tests.sh integration` | Pass | 22 scripts / 85+ tests (new `test_ray_pistol`, `test_wonder_zombies`, `test_warden`; Warden r20 2p kill 256.5 s) |
| 2026-11-12 | 12 | `tools/run_sim.sh specials` (new) | Pass | buildables flow, special round (rifts, burst, Max Ammo), warning, 50-round schedule, Warden rules |
| 2026-11-12 | 12 | `tools/net_tests.sh wonder` (new) | Pass | client part pickup shared, client Conduit chain + ELECTROCUTED copies + arcs, client Ray Pistol burst, special round + rifts + atmosphere, Warden plates replicated |
| 2026-11-12 | 11 | `tools/check.sh` | Pass | 31 unit scripts / 173 tests (new `test_forge_upgrades`: 7 tests over the 23 upgrades + traps) |
| 2026-11-12 | 11 | `tools/run_sim.sh progression` (new) | Pass | 88 checks: relays (pause, 20.0 s defend), bridge / Forge / reactor, Forge 5.0 s + 15 s expiry + Free Upgrade, upgraded behaviors live, traps T2 / T3, hazards |
| 2026-11-12 | 11 | `tools/net_tests.sh progression` (new) | Pass | host 25 / client 20 checks at 100 ms ±20 / 2 %: late-join relay + trap flags, client relay / Forge / trap, FROZEN + splash + drum replication |
| 2026-11-12 | 11 | Regression: `run_tests.sh integration`, `run_sim.sh smoke round_flow perks`, `net_tests.sh weapons box perks late_join reconnect survival traversal solo` | Pass | all green (integration, 3 sims, 8 net tests) |
| 2026-11-12 | 11 | `tools/visual_tests.sh docs/screenshots/step11 forge_showcase` (new) | Pass | 13 frames (relays idle / charging / active, reactor dormant / stabilized + bridge, Forge forging / offer, traps active, breaker puddles, camo row); camo veins and marker-post hiding fixed after review |
| 2026-11-12 | 10 | `tools/check.sh` | Pass | 30 scripts / 166 tests (new `test_perks`: stat fold, perk data vs §8, each perk measured on the components; `test_powerup_dropper`: 30-round simulation 1p / 4p × 100 matches, trap / Nuke kills, threshold growth stop, bag, conditions, cap 4) |
| 2026-11-12 | 10 | `tools/run_sim.sh perks` (new) | Pass | 56 checks: 7 machines on markers, power gating, Second Wind 500 without power, 3 s drink (weapon lowered), owned / cap refusals, HP 250, reload halved, 3 weapons; 3 solo self-revives (perks + 3rd weapon lost) → machine vanishes → 4th down game over; Max Ammo (mag kept), Insta-Kill one hit + 30 s timer, Double Points hit = 20, Nuke all dead in ~2 s +400 no drops, Carpenter +200 all planks, Fire Sale, bullet-kill drop at a reachable spot, none from a trap kill, expiry |
| 2026-11-12 | 10 | `tools/net_tests.sh perks` (new) | Pass ×3 | 100 ms ±20, 2 %: co-op price 1500, client buys Quickdraw through the machine (3000 paid, drink, perk + halved reload on the client), Second Wind revive of the downed host 2.24 s, client picks Max Ammo (reserve refilled, mag kept) + Insta-Kill, identical timer flag, clock error median 12 ms, perks lost on down on both peers |
| 2026-11-12 | 10 | `tools/net_tests.sh box reconnect late_join survival solo weapons traversal lobby` | Pass | reconnect now restores Pack Mule + the third weapon; lobby passed on re-run (teardown ENet flake like I-019) |
| 2026-11-12 | 10 | `tools/net_tests.sh zombies` | Client FAIL (pre-existing) | `smooth_motion` max step 1.26 m — **fails identically on the Step 9 commit** (I-023) |
| 2026-11-12 | 10 | `tools/run_tests.sh integration`, `run_sim.sh smoke round_flow` | Pass | 16 scripts / 72 tests |
| 2026-11-12 | 10 | `tools/net_tests.sh coop4` | Pass (host: I-019 only) | 1st run found a real bug (Nuke queue held a zombie freed before its staggered kill → script error; fixed). 2nd run: every check passes, 0 hash mismatches with perks in the digest, ~12.3 KB/s per client; host harness FAIL only from the known teardown ENet error (I-019) |
| 2026-11-12 | 10 | `tools/visual_tests.sh docs/screenshots/step10 perk_showcase` (new) | Pass | 7 machines off / on + power-up row (opengl3 fallback); fixed oversized sparkle quads and bottles hidden inside the cabinet after the first review |
| 2026-11-12 | 9 | `tools/check.sh` | Pass | 28 scripts / 151 tests (new: `test_weapons_spec` — 23 weapons + equipment vs the spec JSON, distinct sound signatures, box pool items defined; `test_relic_box_roller` — 100,000 rolls within ±1 % of the weights (worst 0.18 pp, 21 eligible items), doll 0 % on spins 1–4 and in Fire Sales, 15 → 75 % ramp, ~15 % measured on spin 5, relocation never the same location, bad-luck bonus; `test_explosive_damage` — splash falloff, self-damage ≤ 60) |
| 2026-11-12 | 9 | `tools/run_tests.sh integration` | Pass | 16 scripts (new `test_projectiles`: LAW direct 1500 + splash, China Lake bounces then explodes, crossbow sticks to the dummy (750 on impact, splash after 1.5 s) and to the floor; `test_equipment`: decoy pull + explosion, tripmine set off by a zombie (2 carried, 4 placed max), Ice Axe replaces the knife; `test_weapon_presentation` now covers all 23 weapons) |
| 2026-11-12 | 9 | `tools/net_tests.sh box` (AC-9.5) | Pass | vesper_peak at 100 ms ±20, 2 %: box moved to Box_Z07 before the join → client sees Box_Z07; client spin (950) → spinner = client, host's take refused, carousel samples identical on both peers and ending on the result, client takes the AK-47; doll → refund + relocation to a different location on both peers after 4 s; Fire Sale → all 7 present, cost 10 |
| 2026-11-12 | 9 | `tools/net_tests.sh late_join reconnect traversal survival solo weapons coop4` | Pass (coop4: I-019 only) | All checks pass; `weapons` 3/3 after the I-014 burst fix (failed once before it); coop4 every check passes (12.2 KB/s per client, 32 zombies seen) but the host log has the known teardown ENet error (I-019) |
| 2026-11-12 | 9 | `tools/run_sim.sh smoke`, `nav_validate`, `flow` | Pass | nav_validate 0 uncovered / 70 spawners; flow Z01 → Z13 35.7 s (unchanged) |
| 2026-11-12 | 7 | `tools/check.sh` | Pass | 25 scripts / 137 tests (new: `test_lobby_state` — slots, unique characters, reservations for reconnects, ready / countdown reset, chat sanitising, round trip; `test_coop_rules` — late-join points, 4 characters + §13 colours + distinct sleeves, Steam lobby metadata, Steam absent = graceful, name-tag fade, ping kinds + cues) |
| 2026-11-12 | 7 | `tools/run_tests.sh integration` | Pass | 13 scripts / 59 tests (new `test_survivor_model`: retargeted skeletons, 18 clips, triangle budget 9.8–10.8k, per-class holds differ ≥ 4°, crouch bends legs with the rifle hold kept, downed hips on the ground, fire/reload one-shots, placeholder + authored M1911 arms tinted) |
| 2026-11-12 | 7 | `tools/net_tests.sh` (all 12) | Pass except pre-existing flakes | New: **lobby** (host + 2 clients + refused 3rd: unique characters, chat, countdown 3.0 s, round held until all scene-ready, starting round 2, late join off refused, game over → return to lobby), **late_join** (0.33 s), **reconnect** (fast + slow rejoin), **coop4** (30/30 hashes, 12.5 KB/s). `replication` "no_visible_snapping" fails ~3/4 and `weapons` "client_saw_host_fire_burst" intermittently **on the Step 6 commit too** in this container (I-012, I-014) |
| 2026-11-12 | 7 | `tools/run_sim.sh smoke`, `round_flow`; `tools/visual_tests.sh survivor_showcase lobby_ui` | Pass | Screenshots: `docs/screenshots/step7/` (lobby, main menu, map select, survivors' holds and states, first-person arms) |
| 2026-11-12 | 6 | `tools/check.sh` | Pass | 23 scripts / 124 tests (new: `test_round_curve` — N(r,p) rounds 1–50 × 1–4 players, hp(r) 1–50, spawn interval, alive caps, tier mix anchors; `test_points_rules` — hit/kill points by zone/kind, repair cap 500, penalties rounded to 10) |
| 2026-11-12 | 6 | `tools/run_tests.sh integration` | Pass | 12 scripts / 53 tests. Fixed a pre-existing flake in `test_zombie_pursuit` (door re-bake is threaded and could outlast the 180-frame window under `--fixed-fps`; the test now waits for the bake) |
| 2026-11-12 | 6 | `tools/run_sim.sh round_flow` (AC-6.2, 6.4, 6.5) | Pass | 30 checks: intro → r1 6 zombies @150 HP, re-queue keeps total, no early end, intermission 10.0 s, r2 8 @250 HP, last 2 promoted to Run, insufficient funds refused, D01 −750 + Z03 unlocked + nav path 31.9 m from a Z03 spawner, no double buy, M14 −500, ammo full refused, ammo −250, 2 planks +20, solo down → game over at r2 with summary |
| 2026-11-12 | 6 | `tools/run_sim.sh survival --rounds=20 --god=1` (AC-6.3) | Pass | 4 SurvivalBots (local + 3 host bots), bot damage ×3: 20 rounds, 2,154 kills, **2,415 spawns, 0 unfair**, min distance 8.01 m, 0 stalls, 260 re-queues (all respawned), memory drift +2.8 % (r3 → r20), orphans 0 → 0; 2,851 simulated s in 7.5 min |
| 2026-11-12 | 6 | `tools/run_sim.sh survival --rounds=15 --god=0` (AC-6.7) | Pass | 4 SurvivalBots, god off, normal damage: died naturally — all four down at **round 13** (game over), 744 kills, 831 spawns / 0 unfair, 76 re-queues, **0 errors**, memory +2.5 % (r3 → r13), orphans 0 → 0; 1,341 simulated s |
| 2026-11-12 | 6 | `tools/net_tests.sh survival` (AC-6.4, 6.5, 6.6) + all earlier net tests | Pass | vesper_peak, 100 ms ±20 ms, 2 % loss: late-join D01 / Z03 / points / round; purchase race single charge [500, 1500]; host down → −5 % (950), last stand; client revive 4.02 s, 50 HP, M1911 back; client bleedout 45.02 s, −10 %, weapons [m1911], spectating, respawn at next round with full HP; one up → no game over; both down → game over on both, client game-over screen |
| 2026-11-12 | 6 | `tools/run_sim.sh smoke` (now vesper_peak, 12 s), `perf_arena`, `soak --duration=120`, `tools/screenshot.sh vesper_peak` | Pass | smoke: round 1 starts, zombies spawn fairly, 0 errors, 0 orphans (also sandbox, nav_torture); perf_arena AI 0.95 ms avg / 1.67 ms p99 (no regression); shots `docs/screenshots/vesper_peak_shot_*.png` |
| 2026-11-11 | 5 | `tools/check.sh` | Pass | 21 scripts / 116 tests (new: `test_zombie_snapshot`, `test_zombie_archetype`: 15 B per zombie, 2 cm round trip, tick wrap, 32 zombies < 15 KB/s; GDD health curve / speeds / attack / tear numbers; voice cap 10 with nearest-steals) |
| 2026-11-11 | 5 | `tools/run_tests.sh integration` | Pass | 12 scripts / 53 tests / 518 asserts. **Nav (AC-5.1):** 32 jog zombies from random spawners (risers on 3 floors + 2 barricaded windows) reach Target_F1 / F2 / F3: 32/32 each, median 12 / 14 / 11 s, last 19 / 28 / 24 s; windows, vent and balcony drop all used; path budget peak 6/frame; AI 0.7–0.8 ms avg. **Pursuit (AC-5.2):** wall test picks B (9 m path) over A (2 m straight, 33 m path); opening D1 re-bakes and retargets to A; F1→F2 climb only on the stair footprint; balcony → atrium via the drop link in < 8 s; scripted bot route across 3 floors: attacked on floors 0/1/2, 0 re-queues. **Barricade (AC-5.3):** planks 6→0 at 1.00 s (walk) / 0.80 s (run) intervals, climb after the last, 2nd zombie WAITs then follows. **Reactions (AC-5.4):** head / stomach / left-right reacts; 400 dmg on 1000 HP staggers 0.6 s; lethal headshot gibs the head (bone collapsed, chunks); explosion at the legs → crawler (1.0 m/s, crawl state, legs gibbed), above the hips or bullets → no crawler; 10 deaths: ≤ 6 simulating ragdolls, 4 frozen, settled on the floor, all corpses freed after fade |
| 2026-11-11 | 5 | `tools/run_sim.sh perf_arena` (AC-5.5) | Pass | 60 s @ 60 Hz after 5 s warm-up, 32 zombies (walk/jog/run/sprint) pursuing the local avatar + 3 looping bots on F1/F2/F3: **AI + nav 0.89 ms avg, 1.57 ms p99**, 9.3 ms max (single spike); 12,244 path queries, peak 6/frame, 0 re-queues (11 in an earlier run); CSV `docs/screenshots/step5/perf_arena.csv` |
| 2026-11-11 | 5 | `tools/run_sim.sh soak` (AC-5.7) | Pass | 600 simulated s (`--fixed-fps 60`, 2.5 min wall): 24–31 alive, kill every 1.5 s (head/torso/limb, 25% explosive), barricades rebuilt every 40 s, doors toggled every 60 s: 316 kills, 383 spawns, 43 re-queues, 21 crawlers, 316 ragdolls, 492 gib chunks, 0 errors, 0 AI warnings, no leaked actors; AI 0.65 ms avg / 1.09 p99 in the last window |
| 2026-11-11 | 5 | `tools/net_tests.sh zombies` (AC-5.3, AC-5.6) + all earlier net tests | Pass | nav_torture, 100 ms ±20 ms, 2% loss: 8 zombies before the join arrive via `_zfull`, 32 total; **zombie snapshots 9.4–9.5 KB/s**; interpolated max step 0.16–0.21 m/frame over 37k samples; client M1911 with scripted aim at moving zombies' torso hurtboxes: **77/77 claims accepted** (0 rejections); barricade planks and count match; host kill_all → 32 corpses, 0 alive on the client |
| 2026-11-11 | 5 | `tools/visual_tests.sh zombie_showcase` | Pass | opengl3: posed line-up (walk, attack wind-up, crawler, head look, head gib, ragdoll), 14 runners surround the player in rings (14/14 within 2.4 m), window planks torn with a zombie waiting; `docs/screenshots/step5/zombies_*.png` |
| 2026-11-11 | 4 | `tools/check.sh` | Pass | 19 scripts / 107 tests / 2068 asserts (no new unit suites; Step 4 tests are integration/visual) |
| 2026-11-11 | 4 | `tools/run_tests.sh integration` | Pass | 8 scripts / 40 tests / 431 asserts. **Kit:** 16 pieces match manifest bounds (±1 cm), colliders on layer 1 with surface tags; wall run (3 walls + window + door) blocks all 174 rays across seams, window/door openings open, 7 window sockets; 3×3 exterior floor patch: 0 holes in 529 samples, all `snow`; stair ramp monotonic and meets the 2 m landing. **Zombie:** 22 humanoid-profile bones (`%GeneralSkeleton`), 12 clips (idle/walk/run/crawl loop), 14 hitboxes follow the head bone within 2 mm over 7 clips × 3 times, head < 0.7 m at the end of `death_back`, 3 skin variants; 7.8k triangles. **Quality:** Low/Medium/High/Ultra switch at runtime (scale 0.75 FSR → 1.0, FXAA/MSAA, SSAO + vol. fog off on Low, shadow lights 2/4/8/12 by priority, particles 0.35→1.0, far 120→400 m) |
| 2026-11-11 | 4 | `tools/visual_tests.sh` (damage_direction, viewmodel_ads, **lookdev_perf**) | Pass | Now rendered with **Forward+ on lavapipe** (D-030). Look-dev (High / Medium): draw calls 546–780 (budget 1500), objects ≤ 1,332, primitives ≤ 320k; shadow-casting lights 5 ≤ 8 / 4 ≤ 4. ADS alignment still (0, 0) px for all 4 weapons incl. the new M1911 model. CSV: `docs/screenshots/step4/lookdev_perf.csv` |
| 2026-11-11 | 4 | `tools/net_tests.sh` (all), `tools/run_sim.sh smoke` (sandbox, gun_range, lookdev), `tools/run_coop_local.sh 2 --map=lookdev --netsim=100,20,0.02` | Pass | Third-person M1911 world model on puppets; no new shared state |
| 2026-11-11 | 4 | Blender generators (`tools/blender/build_all.sh`, Blender 5.3 `bpy`) | Pass | Re-runs reproduce identical geometry, colours and triangle sets; most GLBs byte-identical (multi-material joined meshes can differ in triangle order only) |
| 2026-11-11 | 3 | `tools/check.sh` | Pass | 19 scripts / 107 tests / 2068 asserts |
| 2026-11-11 | 3 | `tools/run_tests.sh integration` | Pass | 5 scripts / 28 tests. Per-hitzone damage exact for M1911 / MP40 / Kar98k at 10 m (head ×3 / ×4 / ×5, neck ×2, torso, limb ×0.75), MP40 24.0 at 40 m (60%), Model 37 pellets 4–8 hits at 5 m each = 130 × zone; penetration lane: Kar98k 4 dummies (400 / 300 / 225 / 168.75), MP40 and M1911 exactly 1; wood wall passes at ×0.75; knife lunge 2.3 m kills the 150 HP dummy, respawn 3 s; frag splash kills it; cooked frag explodes in hand at 3.5 s; ADS sight error < 1 px (1080p) for all 4; MP40 60+ s full-auto: decals 128 (cap), impacts 32, shells 40, tracers 32, flashes 12 — node growth 0, objects +17, static memory +49 KiB over 50 s |
| 2026-11-11 | 3 | Unit: fire rate (60 Hz ticks, 100 shots) | Pass | Average interval within ±1 ms of 60/RPM for M1911 (semi, clicking), MP40 (auto), Model 37 (pump), Kar98k (bolt) |
| 2026-11-11 | 3 | `tools/net_tests.sh` (solo, replication, host_loss, speedhack, course, **weapons**) | Pass | weapons @ 100 ms ±20 ms, 2% loss: hit marker in the same physics frame as the shot; Dummy_Kill 150 → 70 replicated to the client, kill replicated; host rejected forged claims DEAD_TARGET 1, RANGE 2 (claimed 300 m; knife at 12 m), RATE 3 (5 ms apart), 0 rejections during legit play; client saw the host's relayed fire burst |
| 2026-11-11 | 3 | `tools/visual_tests.sh` (damage_direction, **viewmodel_ads**) | Pass | 1920×1080 opengl3: ADS sight centroid error (0.0, 0.0) px for all 4 weapons; viewmodel covers 20.8% of the lower-right quadrant while standing 0.4 m from a wall; frames `docs/screenshots/viewmodel_*.png` |
| 2026-11-11 | 3 | `tools/run_sim.sh smoke` (sandbox, gun_range), `tools/screenshot.sh gun_range` | Pass | `docs/screenshots/gun_range_shot_*.png` |
| 2026-11-11 | 2 | `tools/check.sh` | Pass | 13 scripts / 64 tests / 1395 asserts |
| 2026-11-11 | 2 | `tools/run_tests.sh integration` (`--fixed-fps 60`) | Pass | 3 scripts / 16 tests. Walk 4.60, sprint 6.60, crouch 2.40 m/s (±3%); sprint 4.0 s, recharge 3.8 s (0.8 + 3.0, ±0.1); apex 1.0 m; slide 0.7 s + 1.0 s cooldown; bot course from all 4 spawns in 28.0 s (2 mantles, 1 slide, elevator, 5 m drops, no damage); 1.5 m ledge not mantleable; 1.5 m ceiling keeps crouch; slide ends crouched in the 1.3 m tunnel; shuttle carries the player; 10,000 random frames: 0 static overlaps, 0 fall-through (also checked with 7 other seeds) |
| 2026-11-12 | 8 | `tools/check.sh` (lint, format, boundary, unit) | Pass | 25 scripts / 137 tests |
| 2026-11-12 | 8 | `tools/run_tests.sh integration` | Pass | 14 scripts / 64 tests (new `test_vesper_markers`) |
| 2026-11-12 | 8 | `tools/run_sim.sh nav_validate` | Pass | 28 tiles, 2,261 polys, 51,707 reachable cells, 0 uncovered, 70 spawners OK, 0 harmful islands; ~5 s validation (1.09 M rays). Passed 3/3 consecutive runs |
| 2026-11-12 | 8 | `tools/run_sim.sh flow` | Pass | Z01→Z13 35.7 s; perk spacing ≤ 25.6 s; 14-leg bot loop 0 stuck |
| 2026-11-12 | 8 | `tools/run_sim.sh smoke`, `round_flow`, `survival --rounds=3 --god=1` | Pass | full map; navmesh 28 tiles bake ≈ 0.2–0.35 s at load |
| 2026-11-12 | 8 | `tools/run_sim.sh perf_arena` (`--map=vesper_peak` / nav_torture) | Pass (vesper: p99 borderline, I-016) | vesper 1.29–1.42 avg / 2.7–3.2 p99 ms over 7 runs; nav_torture 0.79 / 1.32 ms |
| 2026-11-12 | 8 | `tools/net_tests.sh traversal late_join reconnect survival zombies lobby coop4` | Pass (coop4 host: checks pass, teardown ENet error I-019) | traversal: 0 corrections on both rides; coop4 10/10 rounds agree, 12.3 KB/s per client |
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
| 2026-11-12 | 8 | perf_arena (**vesper_peak** full greybox, all doors open, 32 zombies, 4 bots) | headless | container CPU | — | — | 1.29–1.42 avg / 2.7–3.2 p99 | 28 nav tiles / 2.26 k polys; tile-local snap (was 2.7 / 5.2 with map-wide snap) |
| 2026-11-11 | 5 | perf_arena (nav_torture, 32 zombies, 4 bots) | headless | container CPU (4 vCPU) | — | — | 0.89 avg / 1.57 p99 | Host AI + navigation only (CrowdDirector accounting); visuals/animation not included. Desktop = [HUMAN] AC-5.5 (`ai_stats`, F3 overlay AI line) |
| 2026-11-11 | 4 | lookdev (5 shots) | High / Medium | container (lavapipe, CPU) | ~7–8 (CPU rasterizer, not meaningful) | — | — | Render-cost proxies: ≤ 780 draw calls, ≤ 320k primitives, 5 shadow lights. GPU FPS = [HUMAN] AC-4.3 |

### Network baselines

| Date | Step | Peers | NetSim profile | KB/s per client | Desyncs | Notes |
|---|---|---|---|---|---|---|
| 2026-11-12 | 7 | 4 (loopback) | 150 ms ±30 ms, 3% loss | 12.4–12.5 avg / 13.4 peak (all downstream traffic) at 32 zombies + 4 players | 0 (30/30 round-end state hashes) | RTT ~310–330 ms; join snapshot 0.33 s at 100 ms; reliable lobby/session traffic negligible |
| 2026-11-11 | 5 | 2 (loopback) | 100 ms ±20 ms, 2% loss | 9.4–9.5 for 32 zombies (stream 19 only; 489 B per 20 Hz packet) | 0 | Plus reliable spawn/death events; 100% of client hit claims on moving zombies accepted |
| 2026-11-11 | 3 | 2 (loopback) | 100 ms ±20 ms, 2% loss | ~1–2 while firing (MP40: 9 reliable shot claims/s batched per frame, ≈60 B each + 41 B unreliable fire burst relayed per shot) | 0 | Claims carry no damage; host recomputes |
| 2026-11-11 | 2 | 2 (loopback) | 100 ms ±20 ms, 2% loss | ~1 (player state 30 Hz: pos, yaw, pitch, flags, seq; snapshots 20 Hz) | 0 | Replication error max 0.015 m; 0 false corrections |
| 2026-11-11 | 1 | 2 (loopback) | 100 ms ±20 ms, 2% loss | < 1 (capsule state 30 Hz + snapshots 20 Hz, float32 positions) | 0 | Replication error max 0.016 m; quantization deferred to Step 5 |

---

## Unresolved issues

| ID | Severity (S1–S4) | Step found | Description | Owner/plan |
|---|---|---|---|---|
| I-028 | S3 | 12 | Galvanics / the Warden use the 0.3 m-radius zombie navmesh (the Warden's 0.55 m capsule can clip corners); the Warden's charge stops on navmesh edges | Accept for the greybox; revisit with Step 13 geometry |
| I-029 | S4 | 12 | Conduit arcs are host-resolved: the shooter sees its own arc after one round trip (no local prediction) | Acceptable at ≤ 150 ms; predict cosmetically in Step 16 if playtests complain |
| I-030 | S4 | 12 | The rift spawn picks spawner-adjacent navmesh points; open areas without spawners never get rifts | Fine on Vesper Peak (70 spawners); add rift markers in Step 13 if needed |
| I-002 | S4 | 2 | Headless `--fixed-fps` integration runs sometimes log "Jolt Physics job system exceeded the maximum number of jobs … Waiting for jobs" (engine warning; physics continues). Not seen in real-time runs | Marked benign in `tests/integration/player_test_helper.gd`; re-check after engine upgrades |
| ~~I-003~~ | S3 | 2 | **Fixed for map machines in Step 8** (D-052: host-driven deterministic gondola / lift). Test-map moving platforms (course elevator/shuttle) are simulated locally per peer, so a remote player riding one is seen on the host's copy of the platform only approximately | Step 8 makes traversal machines host-driven (D-020) |
| ~~I-004~~ | S4 | 3 | ~~Viewmodel/particles verified only with the Compatibility renderer~~ — **Fixed in Step 4:** container renders Forward+ via lavapipe (D-030); metallic viewmodels were black in Forward+ and now reflect a neutral sky (D-031). A GPU look check stays part of AC-3.7 | Closed |
| I-006 | S4 | 4 | Camera snow also falls inside interiors in the look-dev scene (per-zone `CameraSnow.intensity` is not driven yet) | Step 8/13 zone volumes set the intensity (0 indoors, light under skylights) |
| I-007 | S3 | 4 | Zombie v1 model is built from rigidly skinned primitive segments (reads as "puffy" at the torso; joints crease) — fine for Step 5 AI work, below the final art bar | Step 5B / 13: sculpted or CC0 replacement through the same BoneMap/HitboxProfile (drop-in, ART_PIPELINE §5) |
| I-005 | S3 | 3 | Frag grenades (and Step 9 Drummer Decoys, same RigidBody path) are simulated on every peer; a client's cosmetic copy can rest in a slightly different spot than the host's authoritative one (the explosion is shown at the host's position). Launcher / crossbow projectiles are deterministic kinematic (D-057) and match closely | Acceptable for co-op; could move frags/decoys to `Projectile` (grenade kind) in Step 16 |
| I-008 | S4 | 5 | Crowds produce a few stuck / far re-queues per minute (3–10 per 32-zombie run, 43 in the 10-min soak), mostly zombies boxed in by others at a window queue or in the 1.2 m corridor, and F3 spawns > 60 m from an F1 target. They respawn near the players (no lost zombies) | Watch on Vesper Peak (Step 8); tune STUCK_WINDOW / separation, or add a "push through" when blocked only by other zombies |
| I-009 | S4 | 5 | Ragdolls / death animation / corpses decide locally per peer, so a corpse can lie in a slightly different pose on each peer | Cosmetic; corpses aren't targets |
| I-010 | S4 | 6 | Vesper Peak slice: ~260 stuck/far re-queues across the 20-round 4-bot soak (≈ 11 % of spawns), mostly window queues on the gallery ledges where waiting zombies box each other in. Rounds still end correctly (re-queues return through the SpawnDirector queue) | Step 8: wider ledges / more window entrances in the full greybox; revisit I-008 tuning |
| I-011 | S4 | 6 | HUD v1 is functional placeholder art (fallback font, drawn tallies); prompts show "[F]" regardless of rebinding / gamepad | Step 15A (final HUD, input glyphs) |
| I-012 | S3 | 7 | `net_tests.sh replication` "no_visible_snapping" (max per-frame step of the interpolated host avatar) fails ~3 of 4 runs in this container (steps 0.3–7.7 m) — **reproduced on the Step 6 commit**, so it is environmental (frame hitches / clock) rather than a Step 7 regression; replication error itself stays < 0.13 m | Step 16 netcode polish: investigate interpolation under frame hitches (clamp per-frame catch-up), re-baseline the threshold on a desktop |
| I-013 | S4 | 7 | Under opengl3 + xvfb, quitting after a menu screen was shown prints "Texture with GL ID … leaked" (default-font glyph atlases); `godot_log_has_errors` ignores that exit message | Re-check with Step 15's final theme/fonts |
| ~~I-014~~ | S4 | 3 | ~~`net_tests.sh weapons` "client_saw_host_fire_burst" intermittent~~ — **fixed in Step 9**: the host now fires a 4-shot burst (one relayed shot was a single unreliable packet at 2 % loss); 3/3 runs pass | Closed |
| I-015 | S4 | 7 | Placeholder first-person arms (greybox guns) sit mostly below the screen edge at the current hip framing; the M1911's authored arms are tinted instead | Step 9/15 authored arms per weapon |
| I-016 | S3 | 8 | Full-map AI p99 is 2.7–3.2 ms in the container (budget 3.0; average 1.3–1.4 ms is within 1.5): long-path queries across 28 tiles and the large Courtyard tile. `perf_arena --map=vesper_peak` therefore fails ~1 run in 3 on p99 | Step 16: hierarchical zone routing / path caching; re-measure on desktop (AC-8.7) |
| I-017 | S4 | 8 | The 32 / 28 decor nav islands on prop tops (desks, fountain tiers, bay roofs) are harmless but `snap()` could in theory place a zombie on one when squeezed next to it | Watch in playtests; cap islands by raising region_min_size or non-walkable prop tops in Step 13 |
| I-018 | S4 | 8 | Greybox bullets pass through gondola cabin / lift platform (they sit on the player-clip layer so navigation ignores them) | Step 13: add a bullet-only collision layer for machine bodies |
| I-019 | S4 | 8 | `net_tests.sh coop4`: every host check passes (10/10 rounds agree), but one ENet "Unable to send packet on channel 0, max channels: 0" error is logged at teardown just after a client leaves, so the harness reports the host as failed (seen once in 2 runs this step) | Find the system that sends to a peer in the frame it disconnects (Step 9 session or 16) |
| I-020 | S4 | 8 | coop4 / survival logs show a few "far (≈1 km path)" re-queues on Vesper Peak: some path queries return detours many times the straight distance (Godot polygon A* on large polygons; see `edge_max_length`, D-051) | Re-queue handles it (zombie respawns near players); revisit with path post-checks / hierarchical routing (Step 16, with I-016) |
| I-021 | S4 | 9 | A Relic Box that relocates into a zone that is still locked can be unreachable until the door is bought (classic behaviour, GAME_DESIGN §10.2 is silent) | Human review (AC-9.7); option: restrict relocation to unlocked zones |
| I-022 | S4 | 9 | Projectile bolts stuck to a zombie that dies keep following the corpse until the fuse ends; the box display floats a greybox gun (no authored models yet) | Cosmetic |
| I-023 | S3 | 10 | `net_tests.sh zombies` client `smooth_motion` (max per-frame zombie step 1.26 m) fails on the Step 9 commit too — same environmental snapping family as I-012 | Step 16 netcode polish with I-012 |
| I-024 | S4 | 10 | Second Wind solo self-revive: zombies ignore the downed player but don't "scatter" (GAME_DESIGN §3.3); perk machines get a collider after spawn, so zombies path through them until the next tile re-bake | Step 16 polish: a short flee goal for the crowd; bake machine footprints with the map |
| I-025 | S4 | 11 | Dual wield (Gemini, Black Scorpions): the left gun is a static mirrored child of the right one (no own reload clip / arms); third person shows one gun | Step 13 (authored weapons) |
| I-026 | S4 | 11 | Zombies lured by a charging relay crowd it but never attack it (GAME_DESIGN §9.1 has no relay damage); a player in the zone stays the real target when nearer | Step 16 balance (decide whether relays take damage) |
| I-027 | S4 | 11 | Coolant Purge shatter is the normal gib death (forced limb gibs), no ice-shard VFX / frozen corpse material beyond the overlay | Step 13 / 15 VFX |
| I-001 | S4 | 1 | `tools/net_tests.sh` failed once (output not captured) while it was being tuned; 21 later consecutive runs passed. Possible rare timing flake in the multi-process tests | Watch CI; logs are kept in `.test-results/net/` and uploaded by CI on failure |

Severity: **S1** crash / data loss / progress-blocking · **S2** major feature broken · **S3** minor feature issue / visual bug · **S4** polish.

## Deferrals

| AC / item | Deferred to | Reason |
|---|---|---|
| ~~Owner-movement validation~~ | — | Done in Step 2 (D-016) |
| Settings UI for sensitivity / ADS multiplier / FOV / bob / shake / hold-toggle | Step 15 (15A menus) | Settings exist in `Config` and are live-editable with the `setting` console command; the menu screens are Step 15 work |
| ~~Downed state (last stand)~~ | — | Done in Step 6 (`DownedSystem`) |
| ~~`NetId` entity registry + reliable spawn/despawn~~ | — | Done in Step 5 for zombies (D-036); player avatars stay keyed by peer id |
| ~~Snapshot quantization~~ | — | Done in Step 5 for zombies (`ZombieSnapshot`, 15 B / zombie); player snapshots stay float32 (≤ 4 entries) |
| Foot-placement IK on near zombies (Step 5 scope 5) | Step 13 | Zombies are navmesh-snapped and the test/greybox floors are flat or ramp-like; IK matters once art stairs/rubble exist. `TwoBoneIK3D` is available in 4.7 and slots in as another SkeletonModifier3D on near zombies |
| `NavigationAgent3D` RVO avoidance (Step 5 scope 4) | Step 16 (if needed) | Replaced by custom separation + surround slots (D-034), which met the surround and budget criteria |
| ~~Window swipe + plank rebuild~~ | — | Done in Step 6 (`BarricadeRepair`, `ZombieSim` window swipe 1.6 m) |
| ~~Late-join policy and reconnect (GAME_DESIGN §13)~~ | — | Done in Step 7 (`MatchSession`, D-047) |
| ~~Kit-based greybox, real zone elevations, gondola dock, door bursts~~ | — | Done in Step 8 (box greybox with kit materials, D-053); Second Wind machine = marker until Step 10 |
| Kit *meshes* on the greybox, per-zone camera-snow intensity (I-006), occluders beyond floor/roof slabs, reverb areas | Step 13 | Step 8 uses box geometry with the kit materials (dimensions off the 2 m grid); one OccluderInstance3D per zone floor/roof + visibility ranges on small props; ambience markers only |
| S1 Director's Office / S2 Ice Grotto rooms | Step 13 / 14 | Entrances + content markers (L13, L14, crate, MB4) are placed; rooms come with the secrets |
| ~~Reactor Bridge extension on relays~~ (done Step 11); Z12 reactor-view gallery framing | Step 13 | The view is an art task (VESPER_PEAK §9.1) |
| Authored Lazarus Forge / relay / trap models (Step 11 scope 2 "final model"), map-dressed relay rooms, ice-shard / steam VFX polish | Step 13 (art pass) | Step 11 uses the **greybox+** path (procedural, animated) like Steps 9 / 10 |
| Final Forge / relay / trap / hazard sounds | Step 15 | `ProgressionAudio` placeholders under the final event names |
| ~~Ray Pistol "Nova Mk.II" / Lazarus Conduit "Lazarus Requiem" upgrades~~ | — | Done in Step 12 (`wonder_upgrades` in `upgrades_spec.json`) |
| Authored models: Ray Pistol, Lazarus Conduit, Galvanic, Warden, parts, workbench (scope 1/2/4/5 "final model") | Step 13 | Greybox+ procedural models now (GreyboxGun styles `ray_pistol` / `conduit`, electrodes / armor plates on the zombie rig, Warden = zombie rig ×1.65); authored art in the art pass |
| Galvanic / Warden dedicated animation clips (leap, death burst, slam, charge) | Step 13 | Reuse the 12-clip zombie library (wait = telegraph, drop = leap, attack = slam, stagger = charge recovery) |
| Special-round music / final audio | Step 15 | Synthesized placeholders (`WonderAudio`) |
| Bots replicated to clients | Not planned | Host bots are soak-test tooling (D-041) |
| ~~Remote-player downed / spectate animation~~ | — | Done in Step 7 (`SurvivorModel` downed_crawl / revive) |
| Steam live test (lobby, overlay invites, P2P) | Human (AC-7.6) / Step 16 | GodotSteam GDExtension is not vendored and no Steam client exists in the container; `SteamTransport` is implemented against GodotSteam's API and unit-tested for its pure parts (D-045). Direct IP + UPnP + VPN is the always-available path |
| ~~Drink animation trigger~~ (done Step 10), character quips / VO, character-coloured kill markers (optional), occluded-teammate outlines | Step 10 (drink) / Step 15 (VO, markers, outlines) | `SurvivorModel.play_action(&"drink")` exists; perks arrive in Step 10. Name tags render through walls meanwhile |
| Host bots in the lobby roster | Not planned | Bots are test tooling (D-041); they use a slot-based character |
| ~~Full `ProjectileBehavior` (launchers, crossbow)~~ | — | Done in Step 9 (`Projectile`, D-057); the Ray Pistol uses it in Step 12 |
| Authored viewmodel/world models + arms for the 22 non-M1911 weapons (Step 9 scope 2 "final art") | Step 13 (art pass) / Step 16 (known gap) | Step 9 used the plan's risk fallback **"greybox+"**: 8 class silhouettes in `GreyboxGun` (pistol, smg, rifle, shotgun, lmg, launcher, crossbow, scoped rifle) with per-weapon colour / proportions, code-built clips from per-weapon timings, all with Sight/Muzzle/Mag/Action markers so an authored GLB drops in via `viewmodel_scene` / `world_scene`. Asset strategy per weapon: scripted Blender model (`tools/blender/`, like the M1911) — none provided by a human yet |
| Hand-authored textures (256 px/m trims) | Step 13 | Step 4 kit/props use world-space triplanar detail noise + vertex-colour grime (no UVs); unique hero textures come with the art pass |
| Explicit LOD meshes / HLOD | Step 13 | Importer auto-LOD on every mesh now (`meshes/generate_lods`); HLOD/visibility ranges for the full map in 13D |
| Zombie animation set beyond 12 clips (3 walks, 2 jogs, lunge, rise, vent drop, electrocuted …, ARCHITECTURE §11.3) | Step 12 / 13 | Step 5 drives all 12 clips through the AnimationTree; rise = model rising from below the floor, vent = crawl clip, drop = falling pose, stagger = stomach react. More clips extend `build_zombie.py` or import CC0/Mixamo through the BoneMap |
| Recorded weapon audio | Step 15 | Synthesized per-weapon placeholders (`WeaponAudio`), distinct per weapon, now with interior/exterior tails (roof ray); box music-box melody / chimes / doll laugh are original synthesized placeholders (`RelicBoxAudio`) |
| ~~Tactical / placeable slots~~, ~~Pack Mule third slot~~ | — | Tactical (decoy) + placeable (tripmines) + melee upgrade done in Step 9 (D-059); Pack Mule's third slot is Step 10 |
| Wall-buy "weapon appears on the rack once bought" (VESPER_PEAK §5.1) and the wall-buy pickup animation beyond the draw clip | Step 13 / 15 | Stencil-on-canvas tarp + crate are in; the bought weapon raises with its draw clip |
| ~~Box Fire Sale *power-up*~~ | — | Done in Step 10 (PowerUpSystem) |
| Authored perk machine models (Step 10 scope 2 "final-quality models") and an animated first-person hand on the bottle | Step 13 (art pass) | Step 10 uses the **greybox+** path like Step 9: procedural machines (`PerkMachine._build_visual`) with a unique silhouette piece per perk (keg, bolts, double barrels, runner, cross, dial, mule), neon outline + sign + light in the perk colour, bottle window idle bob, vend drop, power-off state; the drink is a bottle tilted in the viewmodel. An authored GLB replaces `_build_visual` |
| Final jingles / stingers / announcer VO | Step 15 | Original placeholder melodies per perk (`PerkAudio`) and a formant "voice" per power-up (`PowerUpAudio`) under the final event names |

## Proposed design changes (awaiting human decision)

| Date | Proposed by (step) | Change | Rationale | Decision |
|---|---|---|---|---|
| 2026-11-12 | 11 | Forge / relay / trap / hazard numbers not in the docs (GAME_DESIGN tuning log, 2 rows): upgrade mags / reserves / behavior numbers (`tests/data/upgrades_spec.json`), relay lure 14 m (weak), trap player 110 HP/s, freeze 2.5 s, drum / icicle / puddle values | Docs give behaviors, not numbers | Agent decision (tuning log) |
| 2026-11-12 | 11 | Forge edge rules: the weapon leaves the loadout on insert; an untaken offer is lost (no refund); taking it with full slots replaces the held weapon; a Free Upgrade makes the next insert free; alt-fire = key B (gamepad 13) | §9.2 silent beyond "lost if not taken" | Agent decision |
| 2026-11-12 | 11 | `T3_Console` moved 10° → 52° on the Lower Ring (outside the −45°…45° freeze sector) | The lever stood inside its own trap | Agent decision (VESPER_PEAK §9.1) |
| 2026-11-12 | 10 | Power-up drop threshold **2000 ×1.14 → 600 ×1.06** per drop (growth still stops after round 20; max 4 / round; data in `content/powerups/powerup_rules.tres`) | The literal §11 numbers give ~1 drop per round (simulated 30 rounds, 1p and 4p) — contradicting §11's own target "about 4 drops per round early" and AC-10.3 (2–4). 600 / ×1.06 gives 2.2 (solo) / 3.0 (4p) per round in rounds 1–10 and ~2.9 later | Agent decision (tuning log; revisit in the AC-10.6 playtest) |
| 2026-11-12 | 10 | Perk rules not in §8: perk granted when the 3 s drink ends (downed mid-drink = lost, no refund); Pack Mule loss drops the **last-acquired** weapon; Second Wind self-revive takes 5 s (§3.3) and its 3 uses are per match (the machine vanishes after the 3rd *use*); free-perk crates ignore the cap; Bullseye snap = nearest visible head within 8° / 35 m; Quickdraw also speeds ADS; Insta-Kill doesn't apply to debug kills | §8 / §11 give effects, not edge rules | Agent decision |
| 2026-11-12 | 9 | Launcher / crossbow "damage + splash X (r)" read as: direct-hit damage to the zombie struck + splash X at the centre falling linearly to 0 at r; China Lake grenades explode on zombie contact or after 2.5 s; tripmines trigger on a zombie within 2 m in front (players never trigger), 1 s arming, 0.25 s beep; Drummer Decoy pulls by path distance ≤ 25 m for 8 s (`attract_time` = fuse) | GDD §4.3 gives the numbers, not the rules | Agent decision (data in the .tres) |
| 2026-11-12 | 9 | Tripmines and the Ice Axe are bought once (wall prompt shows "owned"); tripmines refill to 2 at each round start | §4.3 says "2 per round (refills)"; re-buying a refill makes no sense | Agent decision |
| 2026-11-12 | 6 | GDD §5.2 says solo round 15 = 75 zombies; its formula gives 90. Data follows the formula | Formula is the spec; the example looks like a typo | Agent decision (tuning log) |
| 2026-11-12 | 6 | Bleedout timer pauses while a teammate is reviving; purchases use a 0.35 s hold | §3.3 / §12 silent; classic behaviour, avoids accidental buys | Agent decision |
| 2026-11-11 | 3 | Frag damage "250 + splash 1200 at centre (r = 5 m)" interpreted as linear splash from 1200 at the centre to 250 at the 5 m edge; own frag deals up to 60 to the thrower (§3.2) | The table is ambiguous; this keeps both numbers meaningful | Agent decision (reversible in `frag.tres`) |
| 2026-11-11 | 3 | Sprinting does not cancel a reload (the reload continues while running); weapon switch and melee cancel it (ammo-in rule applies) | AC-3.2 asks for "behaves as specified" without a spec; this is the friendlier classic-Zombies-like choice | Agent decision |
| 2026-11-11 | 3 | Thin props (wood, sheet metal, tagged `thin_prop`) pass bullets with −25% damage per prop (max 2) | GAME_DESIGN §4.2 allows thin-prop penetration without a number | Agent decision |
| 2026-11-11 | 1 | Work is implemented on branch `claude/project-lazarus` (created from the planning branch `claude/lazarus-dev-roadmap-h093ya`, since `main` holds no plan), one cloud session per step, with a PR into `main` after the final step | Owner's instruction for sequential cloud sessions | Owner instruction |

---

## Human tasks (things only the project owner can do)

| Needed by | Task | Status |
|---|---|---|
| Step 12 | AC-12.6 (Conduit chain on 10 zombies + 32 alive: no frame > 25 ms on the reference GPU) and AC-12.7 feel review — steps in `docs/sessions/2026-11-12_step-12.md` | Open |
| Step 0 | Review and approve the planning documents; confirm original naming approach (GAME_DESIGN §1.3) | Open |
| Step 2+ | Run local playtests for [HUMAN] criteria (feel, visuals, performance on real GPU) | Recurring |
| Step 4 | Confirm the reference hardware (min + recommended GPUs) available for testing | Open |
| Step 4 | Optional: download Mixamo animations (requires Adobe account) if the scripted library is insufficient (import path: ART_PIPELINE §5) | Open |
| Step 4 | ~~Confirm Blender availability~~ — resolved: the container installs Blender 5.3 as the `bpy` pip module (`pip install bpy`); a local Blender 4.2+ also works (`$BLENDER`) | Done |
| Step 4 | AC-4.3 GPU performance on the look-dev scene and AC-4.4 art-direction approval (steps in `docs/sessions/2026-11-11_step-4.md`) | Open |
| Step 7 | **AC-7.6**: internet co-op session, 10+ rounds, host + ≥ 1 friend (steps in `docs/sessions/2026-11-12_step-7.md`, guide `docs/NETWORKING.md`); record the path used, join time, ping, issues | Open |
| Step 7 | Optional Steam: install GodotSteam GDExtension for Godot 4.7 into `game/addons/godotsteam/` (docs/NETWORKING.md §3) and test lobby + overlay invite with a friend (App ID 480) | Open |
| Step 7 | AC-7.5 visual review: survivors' third-person poses per weapon class (`docs/screenshots/step7/`, or watch a friend in co-op) and first-person sleeves | Open |
| Step 9 | **AC-9.7** weapon + Relic Box review (steps in `docs/sessions/2026-11-12_step-9.md`); optionally provide/approve weapon models (or approve scripted Blender models in Step 13) | Open |
| Step 8 | **AC-8.7** GPU FPS on Medium on the minimum spec with 32 zombies + 4 bots on the full greybox, and **AC-8.8** greybox flow playtest solo + co-op (steps in `docs/sessions/2026-11-12_step-8.md`) | Open |
| Step 10 | **AC-10.5** machine visual review (`docs/screenshots/step10/` or in game) and **AC-10.6** solo playtest (steps in `docs/sessions/2026-11-12_step-10.md`); decide on the drop-threshold tuning | Open |
| Step 11 | **AC-11.6** Forge / upgraded-weapon feel playtest + relay / trap / hazard review (`docs/screenshots/step11/`, steps in `docs/sessions/2026-11-12_step-11.md`) | Open |
| Step 13 | Optional: LightmapGI bakes on a desktop GPU | Open |
| Step 15 | Provide or approve music (jingles, EE song), VO approach (recorded vs. TTS), and fonts | Open |
| Any | Monitor Git LFS storage/bandwidth quota | Recurring |
| Step 1 | Quick desktop check: `godot --path game`, Solo, press `~` (console: try `help`, `net_status`, Tab completion, Up/Down history), F3 overlay; then `tools/run_coop_local.sh 2 --windowed` and walk both capsules | Open |
| Step 1 | Confirm the first GitHub Actions run of `.github/workflows/ci.yml` is green (Actions tab) | Open |
| Step 3 | AC-3.7 gunplay feel review + M0 LAN check (steps in `docs/sessions/2026-11-11_step-3.md`); log `wtune` changes in the GAME_DESIGN tuning log | Open |
| Step 5 | AC-5.5 desktop AI timing and AC-5.8 "threatening, readable zombies" review (steps in `docs/sessions/2026-11-11_step-5.md`) | Open |
| Step 6 | AC-6.8: solo playtest to round 8+ and a 2-player LAN playtest on vesper_peak (steps in `docs/sessions/2026-11-12_step-6.md`) | Open |
| Step 2 | AC-2.7 movement feel review on the movement course (steps in `docs/sessions/2026-11-11_step-2.md`); record any `tune` changes in the GAME_DESIGN tuning log | Open |

---

## Session history

Each session adds a row and a report file `docs/sessions/YYYY-MM-DD_step-N[-checkpoint].md`.

| Date | Step | Summary | Report |
|---|---|---|---|
| 2026-11-12 | 12 | Wonder weapons & special enemies (12A + 12B) → M4: Ray Pistol (plasma projectile, disintegrate) + Nova Mk.II (bounce), Lazarus Conduit (ChainLightning, electrocution stun, hold-to-pulse) + Lazarus Requiem (kill arcs), WonderFx (arcs / bursts / rings / rifts, capped), BuildableSystem (parts, shared inventory, workbench, box unlock), Galvanics (ZombieBehavior leap + burst), special-round flow (schedule, rifts, warning atmosphere, Max Ammo), Warden (plates, core, slam / charge / summon, phases, coolant, late-round rule gated), warden_arena test map, debug commands, unit / integration / sim / net tests (D-071…D-075) | [2026-11-12_step-12.md](sessions/2026-11-12_step-12.md) |
| 2026-11-12 | 11 | Relays, Forge, traps & hazards (11A + 11B): RelaySystem / ResonanceRelay (hold, defend, zone pause, weak lure) → MapRules.on_relays_complete (bridge, Forge wake, ReactorState); ForgeSystem / LazarusForge (5000 / Free Upgrade, 5 s, 15 s owner offer); 23 generated upgrades + Skullcrusher launcher, behavior fields, vesperite camo, upgraded sound layer; StatusEffects (slow / burn / freeze); TrapSystem T1–T3; HazardSystem H1–H3; upgraded wall ammo 4500; debug commands; progression sim / net / visual tests (D-066…D-070) | [2026-11-12_step-11.md](sessions/2026-11-12_step-11.md) |
| 2026-11-11 | 0 | Planning: architecture, roadmap, game design, map design, tracker, agent guide | (planning commit) |
| 2026-11-11 | 1 | Godot 4.7.2 project, autoloads, Net layer v1 (Offline/ENet, NetSim, clock sync, uid), console + overlay, sandbox with replicated capsules, tool scripts, CI | [2026-11-11_step-1.md](sessions/2026-11-11_step-1.md) |
| 2026-11-11 | 2 | PlayerCharacter (motor, camera rig, health + damage HUD, footsteps), PlayerTuning, movement course, host movement validation, health replication, bot/random drivers, integration + net + visual tests | [2026-11-11_step-2.md](sessions/2026-11-11_step-2.md) |
| 2026-11-11 | 3 | Weapon framework: WeaponDefinition/Runtime, hitscan/pellet/melee behaviors (+ projectile stub), inventory + frags, viewmodel (own camera/layer, procedural layers, clips), pooled FX, weapon HUD, Hurtbox/HitTarget/TargetRegistry, HitValidator + WeaponSync networking, 4 weapons + knife + frag, gun range, unit/integration/net/visual tests | [2026-11-11_step-3.md](sessions/2026-11-11_step-3.md) |
| 2026-11-11 | 4 | Art direction & pipeline: STYLE_GUIDE + ART_PIPELINE, Blender generators (16-piece kit, 7 props, zombie + 12-clip retargeted library, M1911 hero model), post-import material remap, 4 shaders + 31 materials, 4 environment presets, Graphics autoload + 4 quality presets, camera snow, ambience, look-dev scene + 5 reference shots, Forward+ screenshots via lavapipe | [2026-11-11_step-4.md](sessions/2026-11-11_step-4.md) |
| 2026-11-11 | 5 | Zombies: ZombieArchetype, ZombieActor (sim + visual), ZombieSim brain (rise / window tear + climb / drop / vent / pursue / surround / attack / stagger / crawler / stuck + far re-queue), CrowdDirector (path budget, LOD think, separation, slots, timing), ZombieSync replication (NetIds, quantized 20 Hz snapshots, late join), WorldSync (barricades, nav doors), AnimationTree visuals with head look, gibs, ragdoll pool, placeholder audio with voice priority, nav torture map, console commands, unit/integration/net/sim/visual tests | [2026-11-11_step-5.md](sessions/2026-11-11_step-5.md) |
| 2026-11-12 | 6 | Survival loop → M1: RoundCurve, RoundDirector, SpawnDirector (zones, fairness), ZoneManager, PointsLedger, Interactable framework (doors, wall-buys, barricade rebuild), DownedSystem (last stand, revive, bleedout, spectate, respawn, game over), HUD v1, game-over screen, round stings, M14 + Coachgun, Vesper Peak Arrival Station slice, SurvivalBots, unit/sim/net tests | [2026-11-12_step-6.md](sessions/2026-11-12_step-6.md) |
| 2026-11-12 | 7 | Online co-op → M2: Session autoload + LobbyState (unique characters, ready, chat, host settings, countdown), main menu v1 / map select / settings, scene-ready gate, MatchSession (late join WAITING + points, reconnect by uid incl. stale-connection replacement, match flags, state-hash convergence, bandwidth), UPnP + SteamTransport (GodotSteam, dynamic) + NETWORKING.md, CharacterDefinition ×4, survivor models + 18-clip survivor animation library (bpy), SurvivorModel AnimationTree, tinted first-person arms, name tags, pings, lobby / late_join / reconnect / coop4 net tests (D-045…D-050) | [2026-11-12_step-7.md](sessions/2026-11-12_step-7.md) |
| 2026-11-12 | 9 | Arsenal, wall-buys & Relic Box (9A + 9B): ProjectileBehavior + deterministic `Projectile` (rocket / bouncing grenade / sticky bolt), one splash path with self-damage, 17 new weapons (23 total) from a spec table + generator, greybox+ class models, interior tails, all 10 wall-buys (stencil-on-canvas), Drummer Decoy (zombie attractors), tripmines, Ice Axe, Relic Box (roller, 7 locations, carousel, doll relocation, Fire Sale API, audio set), box/firesale console commands, spec / roller / projectile / equipment / box tests (D-057…D-061) | [2026-11-12_step-9.md](sessions/2026-11-12_step-9.md) |
| 2026-11-12 | 10 | Vigor Tonics & power-ups: StatModifier / PlayerStats / PerkDefinition ×7 / PerkHolder, PerkSystem (purchase → 3 s drink → grant, cap 4, power, loss on down, Second Wind solo self-revive ×3 / co-op 2 s revive, Pack Mule 3rd slot, free perk crate), greybox+ PerkMachines, first-person bottle drink, perk jingles / stingers, bottle-cap HUD; PowerUpDropper (scored threshold + bag) and PowerUpSystem (6 power-ups + Free Upgrade stub, navmesh-reachable drops, host-time timers, Nuke / Carpenter / Fire Sale / Insta-Kill / Double Points / Max Ammo), drop visuals, announcer placeholders, HUD timers + flash; perk/powerup console commands; unit / sim / net / visual tests (D-062…D-065) | [2026-11-12_step-10.md](sessions/2026-11-12_step-10.md) |
| 2026-11-12 | 8 | Vesper Peak full greybox → M3: 12 zone scenes (VesperZone builders, kit materials), 14 doors (17,000), 70 spawners (windows, risers, vents, drops, climbs, bursts, pit rifts), NavTiles (28 tiles), power switch + PoweredLight cascade, gondola / freight lift (zombies ride) / laundry chute / Reactor Bridge, 108 typed markers + manifest, nav_validate + flow sims, traversal net test, minimap + map console, tile-local zombie snap (D-051…D-056) | [2026-11-12_step-8.md](sessions/2026-11-12_step-8.md) |
