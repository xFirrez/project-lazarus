# Project Lazarus — QA test plan (Vesper Peak 1.0)

> Step 16 scope 2 / AC-16.7. Every feature in GAME_DESIGN and VESPER_PEAK has at least one case. **Method**: `A` = automated (headless suite, reproducible: the command in *Test*), `R` = rendered automated check (xvfb + lavapipe), `H` = human (needs a GPU, real input, ears or judgement; listed in PROGRESS *Human tasks*). Results are from the Step 16 release-candidate run (1.0.0-rc1) on 2026-11-13; see §4 for the run log and §5 for the bug list.
>
> Severity: **S1** crash / data loss / progress-blocking · **S2** major feature broken · **S3** minor feature issue / visual bug · **S4** polish.

## 1. How to run the plan

```bash
tools/check.sh                         # lint, format, boundary, unit (incl. test_balance, test_release, test_aim_slowdown)
tools/run_tests.sh integration
tools/net_tests.sh                     # all multi-process loopback scenarios
for s in smoke round_flow nav_validate flow perks progression specials quest presentation balance; do tools/run_sim.sh $s; done
tools/run_sim.sh survival --rounds=10 --god=1
tools/run_sim.sh perf_arena --map=vesper_peak
tools/run_sim.sh high_rounds           # AC-16.4 (≈ 20 min)
RECONNECT_CYCLES=5 tools/net_tests.sh reconnect
COOP4_ROUNDS=60 tools/net_tests.sh coop4   # network soak (≈ 25 min); AC-16.2 asks for 2 h on desktop
tools/export.sh all --channel=rc       # release builds + Linux smoke + exported-binary co-op smoke
```

## 2. Test cases

| ID | Feature (doc ref) | M | Test | Result |
|---|---|---|---|---|
| **Foundation & net** |||||
| QA-001 | Boot → main menu, version shown (GDD §15) | A | unit `test_ui_navigation`, `test_release` | Pass |
| QA-002 | Solo uses the same host path (ARCH §4) | A | `net_tests.sh solo` | Pass |
| QA-003 | Host / join over ENet, replication error < 0.25 m @ 100 ms | A | `net_tests.sh replication` | Pass |
| QA-004 | Host loss → clients back to menu with a message | A | `net_tests.sh host_loss` | Pass |
| QA-005 | Version mismatch refused (Step 16) | A | unit `test_release` (protocol), `Net._on_msg_hello` | Pass |
| QA-006 | Clock sync, NetSim, interpolation | A | unit `test_clock_sync`, `test_net_sim`, `test_interpolation_buffer` | Pass |
| **Player (GDD §3)** |||||
| QA-010 | Walk / sprint / crouch / slide / mantle speeds | A | integration `test_player_motor`, `test_movement_course` | Pass |
| QA-011 | Owner-movement validation (speed hack corrected) | A | `net_tests.sh speedhack`, unit `test_movement_validator` | Pass |
| QA-012 | Course at 100 ms without corrections | A | `net_tests.sh course` | Pass |
| QA-013 | Health regen, damage direction | A/R | unit `test_health_regen`, visual `damage_direction` | Pass |
| QA-014 | Downed / revive / bleedout / spectate / game over | A | `net_tests.sh survival`, `run_sim.sh round_flow` | Pass |
| QA-015 | Input map, rebinding, hold / toggle, gamepad aim slowdown | A | unit `test_input_map`, `test_player_input`, `test_ui_navigation`, `test_aim_slowdown` | Pass |
| QA-016 | Movement feel | H | AC-2.7 | Not executed (human) |
| **Weapons (GDD §4, §7, §9)** |||||
| QA-020 | Damage model per hitzone, falloff, penetration | A | unit `test_damage_model`, integration `test_gun_range` | Pass |
| QA-021 | Fire rate / reload / inventory | A | unit `test_weapon_fire_rate`, `test_weapon_reload`, `test_weapon_inventory` | Pass |
| QA-022 | 23 weapons match the roster spec (incl. Step 16 tuning) | A | unit `test_weapons_spec`, `test_weapon_definitions` | Pass |
| QA-023 | Projectiles, explosives, self-damage, equipment | A | integration `test_projectiles`, `test_equipment`, unit `test_explosive_damage` | Pass |
| QA-024 | Host-validated hit claims, forged claims rejected | A | `net_tests.sh weapons`, unit `test_hit_validator` | Pass |
| QA-025 | Forge upgrades for every weapon (×2, mags, behaviours) | A | unit `test_forge_upgrades`, `run_sim.sh progression` | Pass |
| QA-026 | Ray Pistol / Nova Mk.II, Conduit / Requiem | A | unit `test_wonder_weapons`, `test_chain_lightning`, integration `test_ray_pistol` | Pass |
| QA-027 | Weapon tiering (wall < box < upgraded < wonder) | A | `run_sim.sh balance`, unit `test_balance` | Pass |
| QA-028 | Viewmodel / ADS sight alignment, presentation | A/R | integration `test_weapon_presentation`, visual `viewmodel_ads` | Pass |
| QA-029 | Gunplay / wonder-weapon feel | H | AC-3.7, AC-11.6, AC-12.7 | Not executed (human) |
| **Zombies (GDD §5)** |||||
| QA-030 | Archetype health curve, tiers, counts, caps | A | unit `test_zombie_archetype`, `test_round_curve`, `test_balance` (to r200) | Pass |
| QA-031 | Navigation, pursuit, barricades, traversal links | A | integration `test_zombie_nav`, `test_zombie_pursuit`, `test_zombie_barricade` | Pass |
| QA-032 | Zombie replication (32 zombies, late join, bandwidth) | A | `net_tests.sh zombies` | **Fail** (host 10/10 checks; client `smooth_motion` max step 0.60 m — I-023, container-only interpolation flake, S3, reproduced on earlier commits) |
| QA-033 | Reactions, model, animation | A | integration `test_zombie_reactions`, `test_zombie_model` | Pass |
| QA-034 | AI budget at 32 zombies, full map | A | `run_sim.sh perf_arena --map=vesper_peak` | Pass |
| QA-035 | Galvanic special rounds (schedule, rifts, Max Ammo) | A | unit `test_special_rounds`, `run_sim.sh specials` | Pass |
| QA-036 | Warden (plates, core, attacks, phases) | A | integration `test_warden`, integration `test_wonder_zombies` | Pass |
| QA-037 | High rounds to 60: spawning, pools, numerics, memory | A | `run_sim.sh high_rounds` | Pass* — full run (rounds 1–3, 10…50, 55–60; 8,756 spawns, 4,108 kills, memory +1.8 %, 0 orphans, 0 errors) passed 13 / 14 checks; the 14th (Warden detection) was a test bug, fixed and re-verified with `--plan=1,2,3,10` |
| **Rounds & economy (GDD §2, §6)** |||||
| QA-040 | Round flow, intermission, game over | A | `run_sim.sh round_flow` | Pass |
| QA-041 | Spawn fairness (no spawns ≤ 8 m / in view) | A | `run_sim.sh survival --rounds=10 --god=1` | Pass |
| QA-042 | Points rules, co-op rules, late-join points | A | unit `test_points_rules`, `test_coop_rules` | Pass |
| QA-043 | Economy pacing vs §6.3 (model) | A | `run_sim.sh balance` | Pass |
| QA-044 | Economy pacing, 5 human solo runs | H | AC-16.5 | Not executed (human) |
| QA-045 | Purchase race without double spend | A | `net_tests.sh survival` | Pass |
| **Box, perks, power-ups (GDD §8, §10, §11)** |||||
| QA-050 | Relic Box roll weights, bad luck, doll, move, Fire Sale | A | unit `test_relic_box_roller`, `net_tests.sh box` | Pass |
| QA-051 | 7 perks: effects, cap, loss on down, Second Wind ×3 | A | unit `test_perks`, `run_sim.sh perks` | Pass |
| QA-052 | Perks + power-ups replicated, timers agree < 100 ms | A | `net_tests.sh perks` | Pass |
| QA-053 | Power-up drop rates / bag | A | unit `test_powerup_dropper` | Pass |
| **Map (VESPER_PEAK)** |||||
| QA-060 | Markers unchanged vs baseline, sightlines | A | integration `test_vesper_markers`, `test_vesper_art` | Pass |
| QA-061 | Navigation coverage, spawner reach | A | `run_sim.sh nav_validate` | Pass |
| QA-062 | Map flow, door order, perk spacing | A | `run_sim.sh flow` | Pass |
| QA-063 | Gondola, lift, chute, bridge (riders, late join) | A | `net_tests.sh traversal` | Pass |
| QA-064 | Relays, bridge, Forge, traps, hazards | A | `run_sim.sh progression`, `net_tests.sh progression` | Pass |
| QA-065 | Buildable Conduit (parts, workbench, box unlock) | A | unit `test_buildables`, `run_sim.sh specials` | Pass |
| QA-066 | Easter egg stages 0–6, failure rules, rewards | A | unit `test_quest_graph`, `run_sim.sh quest` | Pass |
| QA-067 | Easter egg co-op: late join, carry hand-off, reconnect | A | `net_tests.sh quest` | Pass |
| QA-068 | Lore, Journal persistence | A | unit `test_journal`, `run_sim.sh quest` | Pass |
| QA-069 | Easter egg human run | H | AC-14.6 | Not executed (human) |
| QA-070 | Art / atmosphere visual review | H | AC-13.6 | Not executed (human) |
| **Co-op (GDD §13)** |||||
| QA-080 | Lobby: unique characters, ready, chat, countdown | A | `net_tests.sh lobby`, unit `test_lobby_state` | Pass |
| QA-081 | Late join mid-round | A | `net_tests.sh late_join` | Pass |
| QA-082 | Reconnect restores points / weapons / perks | A | `net_tests.sh reconnect` | Pass |
| QA-083 | Reconnect stress (5 kills / relaunches) | A | `RECONNECT_CYCLES=5 net_tests.sh reconnect` | Pass (5 / 5 reconnects restored) |
| QA-084 | 4 players at 150 ms / 3 % loss: bandwidth, state hashes | A | `net_tests.sh coop4` | Pass |
| QA-085 | 4-player soak: hashes every round, memory ≤ 10 % | A | `COOP4_ROUNDS=60 net_tests.sh coop4` | Pass (60 rounds, 1,160 s, 180 / 180 state hashes, host memory +5.6 %, clients +2.0 / 2.5 / 3.5 %) |
| QA-086 | Internet session / Steam | H | AC-7.6 | Not executed (human) |
| **Presentation & audio (GDD §15, §16, §18)** |||||
| QA-090 | Screens navigable, settings persist | A | unit `test_ui_navigation`, `test_config_roundtrip` | Pass |
| QA-091 | HUD resolution / scale matrix | R | `visual_tests.sh hud_matrix` (Step 15) | Pass (Step 15 run; HUD unchanged in Step 16) |
| QA-092 | Audio audit, mix peaks, music, quips, pause | A | `run_sim.sh presentation` | Pass |
| QA-093 | Quality presets | A | integration `test_quality_presets` | Pass |
| QA-094 | Presentation / VO review | H | AC-15.6 | Not executed (human) |
| **Release (Step 16)** |||||
| QA-100 | Smoke on vesper_peak (no errors) | A | `run_sim.sh smoke` | Pass |
| QA-101 | Linux + Windows release export | A | `tools/export.sh all` | Pass |
| QA-102 | Exported Linux binary plays a 4-player match headless | A | `export.sh` smoke | Pass |
| QA-103 | Two exported binaries connect (ENet loopback) | A | `export.sh` co-op smoke | Pass |
| QA-104 | Crash log capture after a killed run | A | unit `test_release` | Pass |
| QA-105 | Shader warm-up runs behind the loading card; 0 draw-time compiles after it | R | rendered run (lavapipe), `hitches` | Pass (581 materials, 51 particle systems; 0 draw compiles) |
| QA-106 | Clean-machine Windows / Linux builds connect | H | AC-16.6 | Not executed (human) |
| QA-107 | GPU performance targets, no hitch > 50 ms | H | AC-16.3 (`hitches` console command) | Not executed (human) |

## 3. Result summary

| | Cases |
|---|---|
| Total | 72 |
| Executed (automated A / R) | 63 |
| Passed | 62 (98.4 %) |
| Failed (triaged) | 1 — QA-032 client smoothness check: I-023, S3, container-only (frame hitches under 4 concurrent headless processes); replication, late join, bandwidth and hit acceptance all pass |
| Not executed (human, listed in PROGRESS *Human tasks*) | 9 |

**AC-16.7: 98.4 % of executed cases pass (≥ 95 %), every failure triaged. No open S1 / S2 bugs (AC-16.1).**

## 4. Run log

| Command | Result |
|---|---|
| `tools/check.sh` | Pass — 41 unit scripts / 226 tests (new: `test_balance`, `test_release`, `test_aim_slowdown`) |
| `tools/run_tests.sh integration` | Pass — 20 scripts / 92 tests |
| `tools/net_tests.sh` (all 18 scenarios, after the I-019 fix) | 37 / 38 peer results pass; `zombies_client smooth_motion` fails (I-023) |
| `run_sim.sh` smoke, round_flow, nav_validate, flow, perks, progression, specials, quest, presentation, balance | All pass (nav: 29 tiles, 0 uncovered; flow legs within targets) |
| `run_sim.sh survival --rounds=10 --god=1` | Pass — 0 unfair spawns (min distance 8.0 m), memory drift +2.9 %, 0 orphans |
| `run_sim.sh high_rounds` (full plan to r60) | 13 / 14 checks (see QA-037); p99 frame 13 ms, 2 frames > 50 ms (worst 94 ms, headless CPU, before / after round jumps), 0 draw-time compiles |
| `RECONNECT_CYCLES=5 net_tests.sh reconnect` | Pass, 5 / 5 |
| `COOP4_ROUNDS=60 net_tests.sh coop4` (150 ms / 30 ms / 3 %) | Pass — 180 / 180 hashes, 12 KB/s per client, RTT ≈ 320 ms |
| `tools/export.sh all --channel=rc` | Pass — Linux 76 MB, Windows 110 MB; exported Linux binary: 4-player bot match (p99 12 ms headless, 0 hitches), two exported binaries connected |
| Rendered run (xvfb + lavapipe Vulkan) | Shader warm-up 581 materials + 51 particle systems behind the card, 0 draw-time pipeline compiles afterwards |

## 5. Bug list (Step 16 bug bash, triaged)

| Id | Sev | Found by | Description | Status |
|---|---|---|---|---|
| I-036 | S4 | QA-103 | Release templates print one engine-side `Attempt to disconnect a nonexistent connection from 'Net' … tree_exited` line when a session closes; not seen with the editor binary, no functional effect | Open (engine-side); filtered in the export smoke |
| I-037 | S2 | QA-101 | `--exec` commands that end the session during `Net.session_started` (e.g. `quit`) made Net emit `peer_joined` with a null peer → 17 script errors in release builds | **Fixed** (Net re-checks the session after `session_started`) |
| I-038 | S3 | QA-104 | `CrashLog` used `OS.is_process_running`, which on Unix only works for child processes and logs an engine error for any other pid (would print an error at every start with a stale lock) | **Fixed** (`/proc/<pid>` on Linux) |
| I-039 | S4 | QA-105 | `VesperArt.cull_gameplay_meshes` timer fired after the map was freed (leaving / quitting within 0.5 s of load, e.g. the menu backdrop) → script error | **Fixed** (root re-checked when the timer fires) |
| I-040 | S3 | QA-027 | Model 37 (1500) and .357 Revolver (1000) were weaker than the 500-point wall-buys (viable to r6 / r4) | **Fixed** by tuning (160 × 8 pellets, 210 damage; GDD tuning log) |

Carried-over open issues (all S3/S4, see PROGRESS *Unresolved issues*): I-002, I-005, I-007–I-013, I-015–I-030, I-032–I-035. No open S1 / S2.
