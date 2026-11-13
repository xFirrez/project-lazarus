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
| QA-001 | Boot → main menu, version shown (GDD §15) | A | unit `test_ui_navigation`, `test_release` | RESULT_UNIT |
| QA-002 | Solo uses the same host path (ARCH §4) | A | `net_tests.sh solo` | RESULT_NET_solo |
| QA-003 | Host / join over ENet, replication error < 0.25 m @ 100 ms | A | `net_tests.sh replication` | RESULT_NET_replication |
| QA-004 | Host loss → clients back to menu with a message | A | `net_tests.sh host_loss` | RESULT_NET_host_loss |
| QA-005 | Version mismatch refused (Step 16) | A | unit `test_release` (protocol), `Net._on_msg_hello` | RESULT_UNIT |
| QA-006 | Clock sync, NetSim, interpolation | A | unit `test_clock_sync`, `test_net_sim`, `test_interpolation_buffer` | RESULT_UNIT |
| **Player (GDD §3)** |||||
| QA-010 | Walk / sprint / crouch / slide / mantle speeds | A | integration `test_player_motor`, `test_movement_course` | RESULT_INT |
| QA-011 | Owner-movement validation (speed hack corrected) | A | `net_tests.sh speedhack`, unit `test_movement_validator` | RESULT_NET_speedhack |
| QA-012 | Course at 100 ms without corrections | A | `net_tests.sh course` | RESULT_NET_course |
| QA-013 | Health regen, damage direction | A/R | unit `test_health_regen`, visual `damage_direction` | RESULT_UNIT |
| QA-014 | Downed / revive / bleedout / spectate / game over | A | `net_tests.sh survival`, `run_sim.sh round_flow` | RESULT_NET_survival |
| QA-015 | Input map, rebinding, hold / toggle, gamepad aim slowdown | A | unit `test_input_map`, `test_player_input`, `test_ui_navigation`, `test_aim_slowdown` | RESULT_UNIT |
| QA-016 | Movement feel | H | AC-2.7 | Not executed (human) |
| **Weapons (GDD §4, §7, §9)** |||||
| QA-020 | Damage model per hitzone, falloff, penetration | A | unit `test_damage_model`, integration `test_gun_range` | RESULT_INT |
| QA-021 | Fire rate / reload / inventory | A | unit `test_weapon_fire_rate`, `test_weapon_reload`, `test_weapon_inventory` | RESULT_UNIT |
| QA-022 | 23 weapons match the roster spec (incl. Step 16 tuning) | A | unit `test_weapons_spec`, `test_weapon_definitions` | RESULT_UNIT |
| QA-023 | Projectiles, explosives, self-damage, equipment | A | integration `test_projectiles`, `test_equipment`, unit `test_explosive_damage` | RESULT_INT |
| QA-024 | Host-validated hit claims, forged claims rejected | A | `net_tests.sh weapons`, unit `test_hit_validator` | RESULT_NET_weapons |
| QA-025 | Forge upgrades for every weapon (×2, mags, behaviours) | A | unit `test_forge_upgrades`, `run_sim.sh progression` | RESULT_SIM_progression |
| QA-026 | Ray Pistol / Nova Mk.II, Conduit / Requiem | A | unit `test_wonder_weapons`, `test_chain_lightning`, integration `test_ray_pistol` | RESULT_INT |
| QA-027 | Weapon tiering (wall < box < upgraded < wonder) | A | `run_sim.sh balance`, unit `test_balance` | RESULT_SIM_balance |
| QA-028 | Viewmodel / ADS sight alignment, presentation | A/R | integration `test_weapon_presentation`, visual `viewmodel_ads` | RESULT_INT |
| QA-029 | Gunplay / wonder-weapon feel | H | AC-3.7, AC-11.6, AC-12.7 | Not executed (human) |
| **Zombies (GDD §5)** |||||
| QA-030 | Archetype health curve, tiers, counts, caps | A | unit `test_zombie_archetype`, `test_round_curve`, `test_balance` (to r200) | RESULT_UNIT |
| QA-031 | Navigation, pursuit, barricades, traversal links | A | integration `test_zombie_nav`, `test_zombie_pursuit`, `test_zombie_barricade` | RESULT_INT |
| QA-032 | Zombie replication (32 zombies, late join, bandwidth) | A | `net_tests.sh zombies` | RESULT_NET_zombies |
| QA-033 | Reactions, model, animation | A | integration `test_zombie_reactions`, `test_zombie_model` | RESULT_INT |
| QA-034 | AI budget at 32 zombies, full map | A | `run_sim.sh perf_arena --map=vesper_peak` | RESULT_SIM_perf_arena |
| QA-035 | Galvanic special rounds (schedule, rifts, Max Ammo) | A | unit `test_special_rounds`, `run_sim.sh specials` | RESULT_SIM_specials |
| QA-036 | Warden (plates, core, attacks, phases) | A | integration `test_warden`, integration `test_wonder_zombies` | RESULT_INT |
| QA-037 | High rounds to 60: spawning, pools, numerics, memory | A | `run_sim.sh high_rounds` | RESULT_SIM_high_rounds |
| **Rounds & economy (GDD §2, §6)** |||||
| QA-040 | Round flow, intermission, game over | A | `run_sim.sh round_flow` | RESULT_SIM_round_flow |
| QA-041 | Spawn fairness (no spawns ≤ 8 m / in view) | A | `run_sim.sh survival --rounds=10 --god=1` | RESULT_SIM_survival |
| QA-042 | Points rules, co-op rules, late-join points | A | unit `test_points_rules`, `test_coop_rules` | RESULT_UNIT |
| QA-043 | Economy pacing vs §6.3 (model) | A | `run_sim.sh balance` | RESULT_SIM_balance |
| QA-044 | Economy pacing, 5 human solo runs | H | AC-16.5 | Not executed (human) |
| QA-045 | Purchase race without double spend | A | `net_tests.sh survival` | RESULT_NET_survival |
| **Box, perks, power-ups (GDD §8, §10, §11)** |||||
| QA-050 | Relic Box roll weights, bad luck, doll, move, Fire Sale | A | unit `test_relic_box_roller`, `net_tests.sh box` | RESULT_NET_box |
| QA-051 | 7 perks: effects, cap, loss on down, Second Wind ×3 | A | unit `test_perks`, `run_sim.sh perks` | RESULT_SIM_perks |
| QA-052 | Perks + power-ups replicated, timers agree < 100 ms | A | `net_tests.sh perks` | RESULT_NET_perks |
| QA-053 | Power-up drop rates / bag | A | unit `test_powerup_dropper` | RESULT_UNIT |
| **Map (VESPER_PEAK)** |||||
| QA-060 | Markers unchanged vs baseline, sightlines | A | integration `test_vesper_markers`, `test_vesper_art` | RESULT_INT |
| QA-061 | Navigation coverage, spawner reach | A | `run_sim.sh nav_validate` | RESULT_SIM_nav_validate |
| QA-062 | Map flow, door order, perk spacing | A | `run_sim.sh flow` | RESULT_SIM_flow |
| QA-063 | Gondola, lift, chute, bridge (riders, late join) | A | `net_tests.sh traversal` | RESULT_NET_traversal |
| QA-064 | Relays, bridge, Forge, traps, hazards | A | `run_sim.sh progression`, `net_tests.sh progression` | RESULT_NET_progression |
| QA-065 | Buildable Conduit (parts, workbench, box unlock) | A | unit `test_buildables`, `run_sim.sh specials` | RESULT_SIM_specials |
| QA-066 | Easter egg stages 0–6, failure rules, rewards | A | unit `test_quest_graph`, `run_sim.sh quest` | RESULT_SIM_quest |
| QA-067 | Easter egg co-op: late join, carry hand-off, reconnect | A | `net_tests.sh quest` | RESULT_NET_quest |
| QA-068 | Lore, Journal persistence | A | unit `test_journal`, `run_sim.sh quest` | RESULT_UNIT |
| QA-069 | Easter egg human run | H | AC-14.6 | Not executed (human) |
| QA-070 | Art / atmosphere visual review | H | AC-13.6 | Not executed (human) |
| **Co-op (GDD §13)** |||||
| QA-080 | Lobby: unique characters, ready, chat, countdown | A | `net_tests.sh lobby`, unit `test_lobby_state` | RESULT_NET_lobby |
| QA-081 | Late join mid-round | A | `net_tests.sh late_join` | RESULT_NET_late_join |
| QA-082 | Reconnect restores points / weapons / perks | A | `net_tests.sh reconnect` | RESULT_NET_reconnect |
| QA-083 | Reconnect stress (5 kills / relaunches) | A | `RECONNECT_CYCLES=5 net_tests.sh reconnect` | RESULT_RECON_STRESS |
| QA-084 | 4 players at 150 ms / 3 % loss: bandwidth, state hashes | A | `net_tests.sh coop4` | RESULT_NET_coop4 |
| QA-085 | 4-player soak: hashes every round, memory ≤ 10 % | A | `COOP4_ROUNDS=60 net_tests.sh coop4` | RESULT_SOAK |
| QA-086 | Internet session / Steam | H | AC-7.6 | Not executed (human) |
| **Presentation & audio (GDD §15, §16, §18)** |||||
| QA-090 | Screens navigable, settings persist | A | unit `test_ui_navigation`, `test_config_roundtrip` | RESULT_UNIT |
| QA-091 | HUD resolution / scale matrix | R | `visual_tests.sh hud_matrix` (Step 15) | Pass (Step 15 run; HUD unchanged in Step 16) |
| QA-092 | Audio audit, mix peaks, music, quips, pause | A | `run_sim.sh presentation` | RESULT_SIM_presentation |
| QA-093 | Quality presets | A | integration `test_quality_presets` | RESULT_INT |
| QA-094 | Presentation / VO review | H | AC-15.6 | Not executed (human) |
| **Release (Step 16)** |||||
| QA-100 | Smoke on vesper_peak (no errors) | A | `run_sim.sh smoke` | RESULT_SIM_smoke |
| QA-101 | Linux + Windows release export | A | `tools/export.sh all` | RESULT_EXPORT |
| QA-102 | Exported Linux binary plays a 4-player match headless | A | `export.sh` smoke | RESULT_EXPORT |
| QA-103 | Two exported binaries connect (ENet loopback) | A | `export.sh` co-op smoke | RESULT_EXPORT |
| QA-104 | Crash log capture after a killed run | A | unit `test_release` | RESULT_UNIT |
| QA-105 | Shader warm-up runs behind the loading card; 0 draw-time compiles after it | R | rendered run (lavapipe), `hitches` | Pass (581 materials, 51 particle systems; 0 draw compiles) |
| QA-106 | Clean-machine Windows / Linux builds connect | H | AC-16.6 | Not executed (human) |
| QA-107 | GPU performance targets, no hitch > 50 ms | H | AC-16.3 (`hitches` console command) | Not executed (human) |

## 3. Result summary

SUMMARY_PLACEHOLDER

## 4. Run log

RUNLOG_PLACEHOLDER

## 5. Bug list (Step 16 bug bash, triaged)

| Id | Sev | Found by | Description | Status |
|---|---|---|---|---|
| I-036 | S4 | QA-103 | Release templates print one engine-side `Attempt to disconnect a nonexistent connection from 'Net' … tree_exited` line when a session closes; not seen with the editor binary, no functional effect | Open (engine-side); filtered in the export smoke |
| I-037 | S2 | QA-101 | `--exec` commands that end the session during `Net.session_started` (e.g. `quit`) made Net emit `peer_joined` with a null peer → 17 script errors in release builds | **Fixed** (Net re-checks the session after `session_started`) |
| I-038 | S3 | QA-104 | `CrashLog` used `OS.is_process_running`, which on Unix only works for child processes and logs an engine error for any other pid (would print an error at every start with a stale lock) | **Fixed** (`/proc/<pid>` on Linux) |
| I-039 | S4 | QA-105 | `VesperArt.cull_gameplay_meshes` timer fired after the map was freed (leaving / quitting within 0.5 s of load, e.g. the menu backdrop) → script error | **Fixed** (root re-checked when the timer fires) |
| I-040 | S3 | QA-027 | Model 37 (1500) and .357 Revolver (1000) were weaker than the 500-point wall-buys (viable to r6 / r4) | **Fixed** by tuning (160 × 8 pellets, 210 damage; GDD tuning log) |

Carried-over open issues (all S3/S4, see PROGRESS *Unresolved issues*): I-002, I-005, I-007–I-013, I-015–I-030, I-032–I-035. No open S1 / S2.
