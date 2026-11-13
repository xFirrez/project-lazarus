# Project Lazarus — Development Plan

> The roadmap: 16 major steps, each built to fit one focused coding session. The bigger steps have named **checkpoints** (A/B/C…). A checkpoint can be a session of its own if the work runs long.
> Status lives in [PROGRESS.md](PROGRESS.md). How to run a session is in [AGENT_GUIDE.md](AGENT_GUIDE.md). The technical rules are in [ARCHITECTURE.md](ARCHITECTURE.md).
> Acceptance criteria have IDs (`AC-<step>.<n>`). PROGRESS.md tracks them by ID. Criteria tagged **[HUMAN]** need a person on real hardware, such as checking feel, visuals on a GPU, or internet play.

---

## 0. Planning summary

### 0.1 Strategy

1. **Feel first, content second.** Steps 2, 3 and 5 build movement, gunplay and zombie AI in dedicated test arenas before any map exists. These three systems decide whether the game is fun, and they are cheap to iterate on when nothing else depends on them yet.
2. **Multiplayer from Step 1.** The networked skeleton exists before the player controller does. Every later system is written host-authoritative and tested with 2+ peers in the same step that builds it. No step adds co-op support afterwards.
3. **Playable early, then always playable.** Step 6 delivers a real survival loop (rounds, points, doors, barricades, downs) in the Arrival Station. From then on, `main` is always a playable game.
4. **Greybox the whole map before final art.** Step 8 makes all of Vesper Peak playable in greybox so flow, routes, spawns and pacing are proven first. Final art (Step 13) swaps meshes and never moves gameplay markers.
5. **Visual quality is planned work, not "later".** Step 4 sets the look and the pipeline early. Each feature step ships its own final-quality assets: perk machines, the box, weapons. Step 13 is a dedicated environment art pass with checkpoints for each area.
6. **The Easter egg is designed now and built last.** VESPER_PEAK §7 fixes the locations, so Step 8 reserves them in the greybox and Steps 11–12 build the mechanics it reuses. Step 14 then wires up a quest whose pieces already exist in the world.

### 0.2 Step overview

| # | Step | Milestone after completion | Checkpoints |
|---|---|---|---|
| 1 | Foundation, toolchain & networked skeleton | — | — |
| 2 | Player controller & movement feel | — | — |
| 3 | Weapon framework & gunplay feel | **M0: "Feels good"** (move + shoot in test range, 2 players) | — |
| 4 | Art direction, asset pipeline & look development | — | 4A pipeline, 4B look-dev scene |
| 5 | Zombie AI, animation & networked enemies | — | 5A sim/nav, 5B visuals/anim/net |
| 6 | Core survival loop | **M1: First Playable** (Arrival Station survival, solo + LAN co-op) | 6A rounds/economy, 6B downs/HUD/game over |
| 7 | Online co-op, lobby & player characters | **M2: Play with friends** (internet co-op) | 7A sessions/lobby, 7B characters/teammate UX |
| 8 | Vesper Peak full greybox | **M3: Whole map playable** (greybox) | 8A upper map, 8B underground + validation |
| 9 | Arsenal, wall-buys & Relic Box | — | 9A framework + 12 weapons, 9B remaining weapons + box |
| 10 | Vigor Tonics & power-ups | — | — |
| 11 | Power progression: relays, Lazarus Forge, traps & hazards | — | 11A relays/forge, 11B traps/hazards/upgrade variants |
| 12 | Wonder weapons & special enemies | **M4: Gameplay complete** (all core systems in greybox) | 12A Ray Pistol + Conduit, 12B Galvanics + special rounds |
| 13 | Vesper Peak art & atmosphere | **M5: Visually complete map** | 13A exterior, 13B sanatorium, 13C underground, 13D reactor + lighting/perf |
| 14 | Easter egg, lore & secrets | — | 14A quest engine + stages 0–3, 14B stages 4–6 + Warden + secrets |
| 15 | Presentation & audio finalization | **M6: Content complete** | 15A UI/menus, 15B audio/music/VO |
| 16 | Balance, optimization, QA & release candidate | **M7: Vesper Peak 1.0** | 16A balance/QA, 16B perf/net soak/release |

**Realistic session count:** 16 steps, roughly **24–28 sessions** once checkpoints are counted, plus bug-fix sessions as needed. I went over the 10–15 range on purpose. Folding presentation into the final step, or the Easter egg into the art pass, would overload those sessions. Those two areas are where quality matters most.

### 0.3 Dependency graph

```
1 ─▶ 2 ─▶ 3 ─┬─────────────▶ 6 ─▶ 7 ─▶ 8 ─┬─▶ 9 ─▶ 10 ─▶ 11 ─▶ 12 ─▶ 14 ─▶ 15 ─▶ 16
             │              ▲              │                        ▲
        4 ───┴─▶ 5 ─────────┘              └─────────▶ 13 ──────────┘
   (4 can run in parallel with 2–3; 5 needs 1, 3 [hitboxes/damage] and 4 [rig pipeline])
   (13 needs 8 [final layout]; 13A/B/C can start once 8 is done and run in parallel with 9–12;
    14 needs 11, 12 and ideally 13)
```

### 0.4 Rules that apply to every step

- **Definition of Done (every step):**
  1. All acceptance criteria for the step are met, or explicitly deferred with a reason in PROGRESS.md.
  2. `tools/check.sh` passes: lint, format, unit tests, and the core→maps boundary check.
  3. Integration and net tests for the touched systems pass headless.
  4. Every new behavior works in **solo and in a 2-peer loopback session**, unless the step says otherwise.
  5. No new errors or warnings in the Godot log during a 5-minute play session or simulation.
  6. Debug console commands exist for the new feature, so it can be tested without playing for an hour.
  7. Docs are updated: PROGRESS.md (status, AC checkboxes, test results), plus any design or architecture change logged in the relevant doc. A session report goes in `docs/sessions/`.
  8. Work is committed in logical commits and pushed.
- **Audio and feedback hooks:** every feature step adds audio events and placeholder sounds at minimum, with final sounds where available. Silence is never acceptable for an interaction.
- **No regressions:** each step re-runs the previous milestone's smoke test (`tools/run_sim.sh smoke`).

---

## Step 1 — Foundation, toolchain & networked skeleton

**Objective:** A clean Godot 4 project with the folder layout, autoloads, test and lint tooling, CI, debug console, and a minimal **networked** sandbox: two instances connect and see each other's placeholder capsule move.

**Dependencies:** none.

**Scope:**
1. Install and pin the Godot 4 stable headless binary (`tools/godot_version.txt`, `tools/install_godot.sh`). Create `game/project.godot` with: Forward+ renderer, Jolt physics, 60 Hz physics, physics interpolation on, the input map (all actions from GAME_DESIGN §3, rebindable), physics layer names (world, player, zombie_hitbox, zombie_body, interactable, projectile, trigger, nav_obstacle), and render layers (world, viewmodel, ui3d).
2. Folder skeleton per ARCHITECTURE §3, with `.gitattributes` for LFS patterns and a `.gitignore` covering `.godot/` and exports.
3. Autoloads: `Log`, `Config` (settings load/save), `EventBus`, `Net`, `Game` (state machine with placeholder screens), `Content` (definition registry that scans `content/` and `maps/`), `Audio` (bus layout: Master, Music, SFX, Weapons, Zombies, UI, VO, Ambience), `Pools`, `Debug`.
4. **Net layer v1:** `NetTransport` interface with `OfflineTransport` and `EnetTransport`. Session host/join by IP:port, peer join/leave events, `player_uid` generation and persistence, a reliable RPC event channel, an unreliable `send_bytes` snapshot channel, clock sync, and the **NetSim** wrapper (latency, jitter, loss). Command line: `--host`, `--join=127.0.0.1`, `--netsim=100,20,0.02`.
5. **Debug console** (toggle with `~`): command registry with typed args, autocomplete, history, and log view. Overlays: FPS/frame time, net stats (RTT, in/out bytes per second, loss).
6. Test tooling: GUT installed; `tools/run_tests.sh`, `tools/check.sh` (gdlint, gdformat --check, tests, and a grep check that `core/` does not reference `maps/`); `tools/run_coop_local.sh` (starts a headless host and N headless or windowed clients); `tools/screenshot.sh` (xvfb + lavapipe).
7. GitHub Actions CI: import, check, unit tests, net loopback test.
8. `maps/_test/sandbox.tscn`: floor, ramps, boxes. Each peer spawns a capsule driven by temporary WASD; positions are replicated through the snapshot channel with interpolation.
9. Create `docs/ASSET_LICENSES.md`, `docs/sessions/`, and the `CLAUDE.md` pointer.

**Deliverables:** runnable project, CI workflow, tool scripts, sandbox scene, net layer v1, debug console.

**Acceptance criteria:**
- AC-1.1 `godot --headless --path game --quit` imports with zero errors. `tools/check.sh` passes locally and in CI.
- AC-1.2 Unit tests exist and pass for: Config round-trip, NetSim delay/loss statistics (±10% of configured), `player_uid` persistence.
- AC-1.3 `tools/run_coop_local.sh 2` starts a host and a client. The client connects within 2 s and both peers see two capsules. An automated net test asserts that a remote capsule's replicated position is within 0.2 m of the authoritative one after the interpolation delay, at 100 ms simulated latency.
- AC-1.4 Solo mode (`OfflineTransport`) runs the same sandbox with no code branches specific to solo.
- AC-1.5 Console commands `help`, `net_status`, `netsim <ms> <jitter> <loss>`, `quit` work. The net overlay shows live RTT and bandwidth.
- AC-1.6 Disconnecting a client cleanly removes its capsule on the host. Killing the host returns the client to the menu with a "Host disconnected" message.
- AC-1.7 `tools/screenshot.sh sandbox` produces a PNG in the cloud container, which proves the visual verification path works.

**Verification:** run all scripts, record outputs in the session report, commit a CI badge in the README.

**Risks:** Godot version drift → pin the version. Software Vulkan rendering might fail in the container → fall back to `--rendering-driver opengl3` for screenshots only, and document it.

---

## Step 2 — Player controller & movement feel

**Objective:** First-person movement that feels fluid and responsive, as specified in GAME_DESIGN §3.1, networked, with health/damage feedback and regeneration.

**Dependencies:** Step 1.

**Scope:**
1. `PlayerCharacter` scene with the components from ARCHITECTURE §6.1. `PlayerInputFrame` captures input once per frame; mouse look uses raw relative motion with no acceleration.
2. `MotorComponent`: ground acceleration and friction, air control, sprint with stamina, crouch (capsule resize with ceiling check), slide (sprint+crouch), jump, mantle (≤ 1.2 m ledges), step-up and stair smoothing, slope handling, and moving-platform support (needed for the gondola and freight lift later).
3. `CameraRig`: yaw/pitch with clamps, FOV setting, sprint FOV kick (+5°), head bob and strafe tilt (scaled by setting), landing dip, crouch/slide camera height transitions, and trauma-based screen shake.
4. `HealthComponent`: HP, damage intake API (amount, source position, type), regen per GAME_DESIGN §3.2, a red vignette shader, directional damage indicators, low-health heartbeat with audio muffling (a low-pass on the SFX bus), and death/downed hooks. Full downed behavior comes in Step 6.
5. Footstep system: surface detection through physics-material tags, with per-surface sound sets (placeholders) for walk, sprint and land. Remote players' footsteps are spatialized.
6. Networking: owner-authoritative movement at 30 Hz. The host validates max speed and teleport distance and corrects on violation. Remote players are puppets: interpolated, with a placeholder third-person capsule plus head.
7. `maps/_test/movement_course.tscn`: stairs (various rises), ramps, 1.0/1.2/1.5 m ledges, narrow 0.8 m gaps, doorways, a 20 m sprint lane with timing gates, a slide tunnel, a moving platform, and a 5 m and 10 m drop.
8. Settings: sensitivity, ADS multiplier (stored for Step 3), FOV, bob scale, shake scale, and hold/toggle for sprint and crouch.
9. Gamepad basics: look curve, deadzones.
10. Bot input driver: feeds synthetic `PlayerInputFrame`s so tests can walk a route.

**Deliverables:** player scene, movement course, unit and integration tests, tuning values in a `PlayerTuning` resource matching GAME_DESIGN.

**Acceptance criteria:**
- AC-2.1 Automated: a bot reaches every waypoint on the movement course (stairs, ramps, mantle ledges, 0.8 m gap, slide tunnel) without getting stuck, in solo and as a client at 100 ms latency.
- AC-2.2 Automated: measured walk/sprint/crouch speeds are within ±3% of the GAME_DESIGN values. Sprint duration and recharge are within ±0.1 s.
- AC-2.3 Automated: the player never ends a frame intersecting static geometry. 10,000 random-input frames on the course produce zero tunneling.
- AC-2.4 Damage → regen timing matches the spec (3.0 s delay, 100 HP/s) in a unit test. Vignette and indicator respond to the damage direction (screenshot test).
- AC-2.5 Net: a remote player's motion appears smooth (no visible snapping) at 100 ms ± 20 ms jitter with 2% loss; position error under 0.3 m at steady state. A speed-hack test (client sends 3× speed) is corrected by the host.
- AC-2.6 Ceiling check: you can't uncrouch under a 1.5 m ceiling. The slide ends cleanly into a crouch under low geometry.
- AC-2.7 **[HUMAN]** Feel review: movement described as "responsive, not floaty, not icy" on the movement course. Any tuning changes go into the GAME_DESIGN tuning log.

**Risks:** "feel" is subjective → expose all tuning in one resource, plus a console command `tune <param> <value>` for live adjustment during the human review.

---

## Step 3 — Weapon framework & gunplay feel

**Objective:** The complete weapon *system*, data-driven and networked, with 4 representative weapons whose feel is first-class: M1911, MP40, Model 37 pump, Kar98k. Built on greybox models with procedural animation layers.

**Dependencies:** Step 2.

**Scope:**
1. `WeaponDefinition` resource schema (ARCHITECTURE §6.2) and `WeaponRuntime` state machine: idle, firing, cooldown, reloading (partial/empty, ammo-in point, cancel), switching (raise/lower), ADS in/out, sprinting (blocks fire), melee interrupt.
2. Behaviors: `HitscanBehavior` (penetration, falloff, hitzones), `PelletBehavior`, `MeleeBehavior` (knife lunge). A stub `ProjectileBehavior` interface comes now, with the full version in Step 9.
3. Inventory: 2 primary slots plus a config-driven slot count (3 for Pack Mule later), switching by key, scroll and gamepad, lethal grenade (cookable frag with bounce physics and splash damage), knife melee.
4. **Viewmodel system:** a separate viewmodel camera and render layer with its own FOV, and an `AnimationPlayer` for authored clips (draw, holster, reload partial/empty, fire, sprint loop, melee). Procedural layers: spring recoil (position + rotation), mouse-lag sway, movement bob synced to the footstep phase, ADS alignment via a per-weapon sight offset, a landing kick, and an idle breathing scope sway for snipers.
5. Spread and recoil: hip cone (bloom with fire and movement), ADS cone, recoil patterns as Curve2D resources with randomness, and recovery.
6. **Feedback:** pooled muzzle flash (mesh + light, 1–2 frames), shell ejection (pooled rigid bodies with a lifetime cap), tracers, an impact library by surface (spark/dust/wood chips/snow puffs/flesh), decals (pooled, capped at 128), hit markers (hit/headshot/kill), hit and kill sounds, crosshair bloom visualization, camera kick.
7. **Damage pipeline:** `Hurtbox` component with hitzones, `DamageInfo` struct, and hit claims sent to the host and validated by `HitValidator` (ARCHITECTURE §5.1). Target dummies with hitzones show damage numbers (debug-only toggle).
8. Networking: other players see and hear fire (fire-burst events), the third-person muzzle flash, and the impacts. Ammo is mirrored on the host.
9. `maps/_test/gun_range.tscn`: dummies at 5/10/20/40 m, a moving dummy track, a penetration lane with 4 dummies in a row, and surface test walls (concrete, wood, metal, snow, flesh).
10. Audio: layered fire sounds (mechanical, body, tail), reload events keyed to animation tracks, dry fire. Placeholders are allowed, but every weapon must sound distinct.

**Deliverables:** weapon framework, 4 definitions with greybox viewmodels, gun range, tests.

**Acceptance criteria:**
- AC-3.1 Unit: damage falloff, hitzone multipliers, penetration loss, and fire-rate timing for all 4 weapons match their definitions (±1 ms RPM accuracy averaged over 100 shots).
- AC-3.2 Unit: reload state machine edge cases (cancel before/after ammo-in, reload with empty reserve, swap during reload, sprint during reload) behave as specified.
- AC-3.3 Integration: a scripted bot fires each weapon at dummies and the recorded damage equals the expected values per hitzone. Penetration damages exactly *n* dummies.
- AC-3.4 Net: with 2 peers at 100 ms latency, the shooter sees the hit marker the same frame as the shot (local), the host applies the damage, and the dummy's health replicates. The host rejects hit claims beyond weapon range, faster than the RPM allows, or on dead targets (automated test).
- AC-3.5 Viewmodel never clips into walls (separate layer). ADS sight alignment is centered within 1 px at 1080p for all 4 weapons (screenshot test).
- AC-3.6 Performance: firing the MP40 continuously at a wall for 60 s keeps the decal and pool counts at their caps with no memory growth.
- AC-3.7 **[HUMAN]** Gunplay review: each weapon feels distinct; hit feedback is "satisfying"; recoil is readable. Tuning gets logged.
- **Milestone M0** reached: move + shoot in the gun range with a friend on LAN.

**Risks:** greybox viewmodels look poor → this step judges *feel*, and Step 4 supplies the first proper weapon model. Keep procedural layers strong so simple meshes still feel good.

---

## Step 4 — Art direction, asset pipeline & look development

**Objective:** Lock in the visual identity and a repeatable pipeline for environment kits, props, weapons and characters. Produce a **look-dev scene**, a small finished-quality slice of the Vesper Peak courtyard and a lobby corner, that sets the bar for every later art task.

**Dependencies:** Step 1. Can run in parallel with Steps 2–3. Needed before Step 5 (zombie rig) and Step 8 (kit dimensions).

**Checkpoints:** **4A** pipeline + kits + rig; **4B** look-dev scene + style guide.

**Scope:**
1. **Style guide** (`docs/STYLE_GUIDE.md`): palette swatches per area (VESPER_PEAK §8), silhouette rules, texel-density target (e.g. 256 px/m for environment trims), bevel and edge-highlight approach, material list, lighting rules (shadow-casting light budget), VFX language (energy = green additive with noise; fire = orange; electricity = blue-white arcs), and the UI typography direction.
2. **Blender pipeline** (`tools/blender/`): a headless install check, `export_glb.py` (applies modifiers, names collisions with Godot's `-col`/`-colonly` suffixes, LODs), and generator scripts for the **modular kit** (walls, floors, stairs, window frames with barricade sockets, door frames, trims, pipes, railings) on a 2 m / 0.5 m grid. Each kit piece has collision and a nav-friendly floor.
3. **Godot import conventions:** import presets (mesh compression, LOD generation, texture compression/mipmaps), naming conventions, and an automatic material remap to the shared materials in `content/materials/`.
4. **Shared materials and shaders:** stylized PBR base (palette + trim + vertex-color grime), triplanar snow accumulation (exterior), frosted glass, emissive vesperite energy (noise scroll + fresnel), zombie skin (wrap lighting, wound masks, rot tint), wet/icy floor variants, and a wind-sway vertex shader (tarps, cables, lamps).
5. **Environment rendering setup:** `WorldEnvironment` presets (exterior storm, interior warm, underground, reactor) with AgX/Filmic tonemap, volumetric fog, glow, SSAO, color grading LUT, and camera-attached snow particles. Shadow and fog quality tied to the quality presets.
6. **Character pipeline:** a CC0 humanoid base rigged to a standard humanoid skeleton, the Godot retargeting setup (`SkeletonProfileHumanoid`), an in-place animation library imported from CC0 sources (or Mixamo if the human downloads it), and a documented workflow for adding animations. Produce the **first zombie model** (orderly variant) with the zombie-skin material, its hitbox bone mapping, and LODs.
7. **First hero weapon model:** a final-quality M1911 viewmodel (arms + pistol) and world model, replacing the greybox from Step 3, to prove the weapon art path (silhouette, materials, animation sockets).
8. **Look-dev scene** `maps/_test/lookdev.tscn`: a 30×30 m courtyard corner (frozen fountain, a military truck, sandbags, a lamp post, the sanatorium façade with lit windows) plus one lobby corner with a perk-machine-sized placeholder. Includes final lighting, fog, snow and audio ambience.
9. `docs/ASSET_LICENSES.md` populated for every imported asset.
10. Quality presets (Low/Medium/High/Ultra) defined and switchable at runtime.

**Deliverables:** style guide, Blender scripts and kit v1, materials and shaders, environment presets, character/animation pipeline with the first zombie, the M1911 hero model, look-dev scene, reference screenshots in `docs/screenshots/step4/`.

**Acceptance criteria:**
- AC-4.1 Every kit piece is generated reproducibly from script (`tools/blender/build_kit.sh`) and imports with correct collision. Kit pieces snap on the grid without gaps (automated placement test scene).
- AC-4.2 The zombie model is retargeted and plays ≥ 5 animations from the library in a test scene. Hitbox colliders follow bones during animation.
- AC-4.3 The look-dev scene renders at ≥ 120 FPS on "High" on the reference mid-range GPU **[HUMAN]**, and at ≥ 60 FPS on "Medium" on the minimum spec **[HUMAN]**. Draw calls ≤ 1,500, and shadow-casting lights within budget (automated monitor log).
- AC-4.4 Reference screenshots (5 fixed camera shots) are committed. The human approves the art direction **[HUMAN]** or gives notes that are applied before the step closes.
- AC-4.5 All assets are logged in `ASSET_LICENSES.md` with source URL and license. There are no assets of unknown license.
- AC-4.6 Switching quality presets at runtime works without a restart (or explicitly requires one for renderer-level changes, with a UI note).

**Risks (high):** the art quality ceiling depends on asset sources. Mitigations: lean on strong lighting, fog and color, which carry a stylized look; mix CC0 kits with scripted Blender pieces; let the human contribute or commission hero assets (weapons, machines) later through a documented drop-in process. Blender may not be installable in the container → fall back to the human running the scripts locally, or use pre-made CC0 models.

---

## Step 5 — Zombie AI, animation & networked enemies

**Objective:** Zombies that navigate a complex multi-floor environment convincingly, attack, react to damage, and die with weight. Host-simulated and smoothly replicated, with a stable performance budget at 32 alive.

**Dependencies:** Steps 1 and 3 (damage/hitzones); Step 4 (rig/animation pipeline).

**Checkpoints:** **5A** simulation, navigation, crowd and performance (headless-testable); **5B** visual animation, reactions, gibs, audio, replication polish.

**Scope:**
1. `ZombieActor` = `ZombieSim` + `ZombieVisual` (ARCHITECTURE §7). `ZombieArchetype` resource: speed tiers, attack data, hitzone multipliers, audio, model variants.
2. **Navigation:** a test map `maps/_test/nav_torture.tscn` with 3 floors, stairs, a ramp, narrow corridors, doors that toggle, drop-downs (navigation links), windows with barricade sockets (navigation links with a "traverse" action), vents, and obstacles. Navmesh baking per region, with agent radius and height tuned to the zombie capsule.
3. **Brain** state machine (ARCHITECTURE §7.2). Includes barricade approach/tear/climb, pursue with re-path budgeting, surround offsets, attack with telegraphed wind-up, stagger on high damage, crawler conversion (explosive leg damage), stuck detection and re-queue, and target selection by path distance (ignores downed players).
4. `CrowdDirector`: path-query budget, think-rate staggering, LOD by distance, separation and avoidance (`NavigationAgent3D` avoidance + custom separation), and per-frame time accounting exposed to the debug overlay.
5. **Visuals:** `AnimationTree` with a locomotion blend by speed tier and playback-rate matching, attack layers, an additive hit-react layer (head/left/right/stomach), death animations blending into ragdoll (physical bones, with a pool limit of 6 simultaneous ragdolls; older ones freeze into static meshes and fade), limb and head gibs on high damage or explosives (pooled), crawler locomotion, and procedural head-look toward the target. Foot placement IK is limited to near zombies.
6. **Audio:** voice priority system (max 10 voiced zombies), idle/aggro/attack/death sets, footsteps, and barricade sounds.
7. **Replication:** zombie spawn/despawn events; snapshot fields (NetId, quantized position, yaw, locomotion tier, action enum + action start tick, health bucket, flags such as crawler/burning/stunned); client interpolation; and client-side hitboxes matching their interpolated pose so favor-the-shooter hits line up.
8. Debug: `spawn_zombie <tier> [n]`, `zombie_freeze`, `zombie_debug` (draw paths, targets, states), `kill_all`, an AI time overlay.
9. Unit and integration tests (below), including a 32-zombie performance benchmark scene.

**Deliverables:** zombie actor and archetype (base zombie, 1 model variant with 3 material variants), nav torture map, crowd director, tests, benchmark CSV.

**Acceptance criteria:**
- AC-5.1 Integration (headless): in the nav torture map, 32 zombies spawned at random spawners reach a stationary target on each floor within the expected time. 0 zombies are permanently stuck after 120 s; stuck re-queue fires for any that are.
- AC-5.2 Integration: a bot player moving a scripted route across floors is pursued correctly. Zombies use stairs, not walls, and take drop links when shorter. Path-distance targeting picks the nearer player by path, not by straight line (test case with players either side of a wall).
- AC-5.3 Barricade flow: a zombie approaches the window, tears planks one at a time (timing per spec), climbs through, and pursues. The barricade state replicates.
- AC-5.4 Hit reactions: headshots produce a head react, and lethal headshots can pop the head (gib). Explosive leg damage creates crawlers. Deaths produce a ragdoll or animation, within pool limits.
- AC-5.5 **Performance:** with 32 zombies pursuing 4 bot players in the benchmark scene, host AI + nav ≤ 1.5 ms/frame average and ≤ 3 ms at p99 on the reference CPU (headless measurement in container as proxy; **[HUMAN]** confirmation on desktop).
- AC-5.6 Net: at 100 ms latency with 2% loss, the 32-zombie snapshot bandwidth is ≤ 15 KB/s per client and client zombie motion is visually smooth. A client's hit claims on moving zombies are accepted ≥ 98% of the time in an automated test with scripted aim (validates hitbox/interpolation alignment).
- AC-5.7 No spawn, path or animation errors in the log during a 10-minute soak with continuous respawning.
- AC-5.8 **[HUMAN]** Zombies "look and feel threatening": wind-ups are readable, groups surround rather than conga-line, deaths feel weighty.

**Risks (high):** crowd navigation quality and performance. Mitigations: strict budgets from day one; separation and surround offsets; a fallback plan (ARCHITECTURE §12 GDExtension); test maps that mirror Vesper Peak's hardest cases (stairs, windows, vents, lifts).

---

## Step 6 — Core survival loop → **M1 First Playable**

**Objective:** A real round-based survival game in a playable version of the **Arrival Station** (greybox with kit pieces): rounds, spawning, barricades, the points economy, purchasable doors, wall-buys, downed/revive/bleedout, game over, and HUD v1, in solo and LAN co-op.

**Dependencies:** Steps 2, 3, 5.

**Checkpoints:** **6A** rounds, spawning, barricades, economy, interactables, doors; **6B** downed/revive/bleedout, HUD v1, game over, soak test.

**Scope:**
1. `Match` object and `MapDefinition`/`MapRules` interfaces (ARCHITECTURE §9). A minimal `vesper_peak` map folder with Z01 Arrival Station plus stub rooms behind D01 and D02 (a small part of Z03 and Z06) so door purchases mean something.
2. `RoundDirector`: round state machine, zombie count/health/speed formulas (GAME_DESIGN §5.2) in a `RoundCurve` resource, intermission timer, round start/end events, last-zombie speed promotion.
3. `SpawnDirector`: spawner types (window, riser, vent), active-zone filtering, line-of-sight and distance fairness rules, alive cap by player count, spawn interval curve.
4. `ZoneManager`: zone volumes, the adjacency/unlock graph, and which zones contain players.
5. **Barricades:** 6 planks, tear/repair interactions, repair points with a per-round cap, plank board animation and sounds.
6. **Economy:** `PointsLedger` (host-authoritative, per player): earning events per GAME_DESIGN §6.1, spending with validation, HUD point popups.
7. **Interactable framework** (ARCHITECTURE §8): prompts with cost, hold-to-use, conditions, request→validate→execute flow. Doors/debris D01/D02 with open animations, nav connection and zone unlock. Wall-buys (M14, Coachgun) with ammo-refill pricing. The M14 and Coachgun definitions are added (greybox models are acceptable).
8. **Downed/Revive/Bleedout** (GAME_DESIGN §3.3): last-stand pistol, crawl, bleedout timer, revive hold, the 5% points penalty, spectate after bleedout, respawn next round, game over conditions. Second Wind is not yet available, so a solo down = game over for now.
9. **HUD v1** (functional, clean, roughly styled): round counter, points (own + teammates), ammo, lethal count, prompts, hit markers, damage vignette, downed/revive progress, teammate downed markers.
10. **Game over screen v1:** rounds survived and per-player stats (kills, headshots, downs, revives, points).
11. **Round audio:** placeholder round start/end stings, a round-change HUD animation.
12. **Bot players for soak tests:** simple behavior (move between waypoints, shoot the nearest zombie, repair barricades, buy doors when affordable).
13. Debug: `give_points`, `set_round`, `god`, `notarget`, `open_all_doors`, `skip_round`, `down_me`.

**Deliverables:** a playable Arrival Station slice, round/spawn/economy systems, the interactable framework, the downed system, HUD v1, game over v1, a soak test.

**Acceptance criteria:**
- AC-6.1 Unit: zombie count, health and spawn interval match GAME_DESIGN for rounds 1–50 and 1–4 players (table-driven test).
- AC-6.2 Integration: a round ends only when all of its zombies are dead. Re-queued (stuck/far) zombies are respawned and still count. The intermission timer and events fire in order.
- AC-6.3 Spawn fairness: across a 20-round bot soak, 0 spawns occur within 8 m of a player or in a player's line of sight (logged and asserted).
- AC-6.4 Economy: points earned per hit/kill type match the spec. Purchases deduct correctly; insufficient funds are refused with audio/UI feedback; simultaneous purchase requests from two clients are resolved without double-spending (net test).
- AC-6.5 Doors: buying D01 connects the navigation (zombies path through) and activates Z03's spawners; the door state replicates to a late-joining client.
- AC-6.6 Downed/revive works in 2-peer co-op with correct timings. Bleedout leads to spectate, then respawn next round with the starting loadout. All downed means game over on all peers.
- AC-6.7 Soak: 4 bot players survive to round 15 (god mode off, bot aim tuned) or die naturally, with zero errors, stable memory (±5%), and no orphan nodes (`Performance.OBJECT_ORPHAN_NODE_COUNT` stays flat).
- AC-6.8 **[HUMAN]** Solo playtest to round 8+ and a 2-player LAN playtest: "the loop is fun, rounds escalate, barricades matter".
- **Milestone M1** reached.

---

## Step 7 — Online co-op, lobby & player characters → **M2 Play with friends**

**Objective:** Make co-op easy to set up over the internet and pleasant to play: a lobby flow, Steam lobbies and invites (with direct-IP fallback), late join, reconnect, four player characters with third-person animation, teammate identification, and pings. Plus thorough automated network testing.

**Dependencies:** Step 6.

**Checkpoints:** **7A** sessions, lobby, Steam transport, late join, reconnect; **7B** characters, third-person animation, teammate UX, ping.

**Scope:**
1. Main menu v1: Solo / Host / Join (IP) / Steam (if available) / Settings / Quit. Map select screen built to list `MapDefinition`s (only Vesper Peak for now).
2. **Lobby:** 4 slots, character selection (unique per player), ready-up, host settings (late join on/off, starting round for testing in dev builds), chat (text, minimal), and a countdown that loads all peers. Loading waits until every peer reports "scene ready" before round 1.
3. **SteamTransport** via GodotSteam (addon pinned): create a friends-only lobby, invite through the Steam overlay, join via invite or friend list, and lobby metadata (map, players, round). Development uses App ID 480. If GodotSteam is unavailable for the pinned engine version, implement the **fallback plan**: direct IP + a documented VPN (e.g. Tailscale) setup + UPnP port mapping attempt; decide and log the choice.
4. **Full match state snapshot** for late join: doors, barricades, round, power flags, box location, player states, and quest flags placeholder.
5. **Late join** per GAME_DESIGN §13; **reconnect** retains player state keyed by `player_uid`; a clear message when the host leaves.
6. **Player characters:** 4 stylized character models (Calloway, Orlov, Brandt, Ashcombe) through the Step 4 pipeline. Third-person animation set: locomotion blend, crouch, slide, jump, weapon-holding poses per weapon class (pistol, rifle, shotgun, LMG), fire/reload upper-body layers, downed crawl, revive, drink. First-person arms tinted per character (sleeve variants).
7. **Teammate UX:** name tags (distance fade), color-coded points list, downed icons with bleedout ring visible through walls, off-screen indicators, revive prompts, and character-colored hit markers for kills (optional).
8. **Ping system:** contextual ping (location, zombie, item, machine) with a world marker and short audio cue.
9. **Network test suite:** an automated 4-client loopback session with NetSim (150 ms, 30 ms jitter, 3% loss) plays 10 rounds with bots and asserts state convergence (points, doors, round, health) at round end; bandwidth logging; a reconnect test; a late-join test.

**Deliverables:** lobby and menu flow, Steam transport (or the documented fallback), late join/reconnect, 4 characters with third-person animations, teammate HUD, pings, net test suite.

**Acceptance criteria:**
- AC-7.1 Automated: a 4-client loopback session at 150 ms/30 ms/3% plays 10 bot rounds; all peers agree on round, door states, each player's points/weapons/perks, and zombie count at every round end (hash comparison).
- AC-7.2 Late join mid-round: the joiner receives the full state in < 2 s on loopback, spawns at the next round start with the correct points, and sees correct doors and barricades.
- AC-7.3 Reconnect: a client killed with SIGKILL and relaunched rejoins and gets its points, weapons and (non-downed) perks restored.
- AC-7.4 Bandwidth: ≤ 25 KB/s per client downstream at 32 zombies + 4 players (logged).
- AC-7.5 Characters: all 4 are selectable and unique per lobby; third-person animations are correct for each weapon class; first-person arms match the character.
- AC-7.6 **[HUMAN]** Internet session: host + at least 1 friend over the internet (Steam or fallback) play 10+ rounds; join flow takes < 1 minute; record ping and any issues in PROGRESS.md.
- **Milestone M2** reached.

**Risks:** GodotSteam compatibility and NAT traversal. Mitigation: the transport abstraction plus an always-available direct-IP path; test early (this step comes before map building for that reason).

---

## Step 8 — Vesper Peak full greybox → **M3 Whole map playable**

**Objective:** Build all of Vesper Peak's layout (VESPER_PEAK §2–5) in greybox using the modular kit with gameplay-accurate dimensions: all zones, doors, barricades, spawners, navigation, the power switch, traversal (gondola, freight lift, chute, bridge placeholder), and **reserved markers** for every later feature (perks, box locations, wall-buys, traps, relays, workbench, EE objects, lore items).

**Dependencies:** Step 7 (stable networked loop); kit from Step 4.

**Checkpoints:** **8A** upper map: Z01, Z03, Z04, Z05, Z06, Z07, the gondola, Sky Bridge; **8B** underground: Z08–Z13, the freight lift, chute, reactor ring, plus whole-map validation.

**Scope:**
1. One scene per zone (VESPER_PEAK §9 conventions) with `Geometry/`, `Gameplay/` (markers), `Nav/`, `Lighting/` (greybox lighting good enough to read spaces), and `Audio/` (ambient placeholders).
2. All 14 doors with costs, open animations (greybox), nav connections, and zone unlocks. Zone adjacency for spawner activation authored in `map_definition.tres`.
3. All barricaded windows and spawners per VESPER_PEAK §3, including risers, vents, climb points, door bursts, and pit climbs.
4. **Power:** the main switch in Z09 with a map-wide power-on sequence (lights cascade by zone, the `main` circuit event). Machines don't exist yet; markers listen for the event.
5. **Traversal:** gondola (moving platform with the player carried by the motor's moving-platform support; zombies can't board; networked deterministic motion), freight lift (zombies can ride — navigation link handled by a dynamic nav region or a "lift link" state), laundry chute (one-way trigger with a teleport-with-transition or a physical slide), and the Reactor Bridge (extendable; in this step toggled by a debug command).
6. **Marker nodes** (typed, named per canonical ids) for: perk machines, box locations, wall-buys, traps, hazards, relays, the Forge, workbench, Conduit part spawns, EE objects (radio, fountain shard, morgue drawers and symbols, pod, core socket, nodes, pylons), lore items, music boxes, ravens, and secret room entrances.
7. **Navigation validation tool** (`tools/run_sim.sh nav_validate vesper_peak`): checks reachability spawner→zones and that every nav polygon is reachable; flags isolated islands; reports any player-standable area that zombies can't reach (detected by sampling standable points from collision).
8. **Flow validation:** bot route that opens all doors in a defined order and travels a loop through every zone; travel time measurements versus VESPER_PEAK §2 targets.
9. Wall-buys present in this step: M14, Coachgun (existing), with other wall-buy markers in place. The temporary box/perk placeholders do nothing.
10. Occlusion setup: an occluder per zone and visibility ranges (performance baseline for the full map).
11. Minimap-style debug overlay (top-down zone graph with player and zombie dots) for testing.

**Deliverables:** complete greybox map, nav validation tool, flow bot, performance baseline, an updated VESPER_PEAK.md with any layout changes and the reasoning.

**Acceptance criteria:**
- AC-8.1 Every zone and door in VESPER_PEAK §2.1–2.2 exists with the canonical id, the correct cost, and a working purchase that unlocks navigation and spawners.
- AC-8.2 `nav_validate` passes: 0 unreachable player-standable regions; every spawner reaches its activation zones; no nav islands.
- AC-8.3 Flow bot: total sprint travel Z01→Z13 via the shortest route ≤ 75 s; no route or perk marker is more than 35 s from another perk marker.
- AC-8.4 Gondola, freight lift and chute work in solo and in 2-peer co-op at 100 ms (rider positions stay correct, nobody falls through, zombies behave correctly on the lift).
- AC-8.5 Power-on sequence works and replicates; late joiners see the power state.
- AC-8.6 All markers from VESPER_PEAK exist (automated check lists every canonical id from a manifest file `maps/vesper_peak/markers_manifest.json`).
- AC-8.7 Performance baseline: the full map with 32 zombies and 4 bots holds ≥ 60 FPS on Medium on the minimum spec in greybox **[HUMAN]**; AI/nav budget is still met (automated).
- AC-8.8 **[HUMAN]** Greybox flow playtest (solo + co-op): routes are understandable, loops work for training, no frustrating navigation. Layout notes get applied, or logged as issues.
- **Milestone M3** reached.

**Risks:** the map is large. Keep greybox simple (kit walls and blocks); focus on dimensions and flow, not decoration. Cut minor rooms rather than routes if the session runs long (log it).

---

## Step 9 — Arsenal, wall-buys & Relic Box

**Objective:** The full conventional weapon roster (GAME_DESIGN §4.3) with final-quality models, animations and audio; all wall-buys placed; equipment (tripmines, Drummer Decoy, Ice Axe); and the complete **Relic Box** with reveal animation, relocation and Fire Sale support.

**Dependencies:** Steps 3, 4, 8.

**Checkpoints:** **9A** finish `ProjectileBehavior` (launchers, crossbow, LAW, with splash falloff and self-damage) + the first 12 weapons (all wall-buys + ARs) with final art; **9B** remaining weapons + equipment + Relic Box.

**Scope:**
1. Weapon definitions for all 23 conventional weapons + equipment, with full stats matching GAME_DESIGN; per-class animation sets (shared rigs per class with per-weapon offsets to keep the workload sane).
2. Weapon art: viewmodel + world model + wall-buy display + box display (the same world model). The asset strategy per weapon is documented: scripted Blender model / CC0 base / human-provided.
3. Weapon audio: distinct fire, reload and handling sets per weapon (interior/exterior tails).
4. **Wall-buys:** all 10 from VESPER_PEAK §5.1 with the stencil-on-canvas visual, purchase/ammo/upgraded-ammo pricing (upgraded ammo becomes active in Step 11), and weapon pickup animations.
5. **Equipment:** tripmines (placeable, triggered by zombies, limit 4 placed per player, replicated), Drummer Decoy (zombie attraction override in the brain, explosion), Ice Axe (melee upgrade).
6. **Relic Box:** box model and animations (lid, light pillar, weapon cycle carousel with deceleration, doll result, lift-away and teleport-in), weighted pool with conditions and bad-luck protection (GAME_DESIGN §10), relocation logic, Fire Sale mode support (box API: `activate_all_locations(duration)`), ownership of the floating weapon, and an audio set (original music-box melody, chimes, doll laugh).
7. Networking: box state machine on the host with results broadcast; all peers see the same carousel (seeded) ending on the true result.
8. Debug: `give <weapon_id>`, `box_force <weapon_id|doll>`, `box_move <location>`, `firesale`.

**Acceptance criteria:**
- AC-9.1 Every weapon in GAME_DESIGN §4.3 (except wonder weapons) exists with stats matching the table (automated comparison of definition vs. a parsed spec table in `tests/data/weapons_spec.json`).
- AC-9.2 Every weapon has a viewmodel with draw/fire/reload (partial + empty)/sprint animations, a world model and a full audio set; ADS alignment test passes for all.
- AC-9.3 Projectile weapons: splash falloff and self-damage match the spec (unit + integration tests); the crossbow sticks to zombies and walls.
- AC-9.4 Relic Box statistics: 100,000 simulated rolls match the configured weights within ±1% (excluding ineligible items); the doll never appears in the first 4 uses at a location or during a Fire Sale; relocation always picks a different location.
- AC-9.5 Co-op: only the spinner can take the weapon; the carousel ends on the same weapon on all peers; the box location replicates to late joiners.
- AC-9.6 Decoy pulls all zombies within 25 m (path distance) away from players for 8 s (integration test).
- AC-9.7 **[HUMAN]** Weapon review: each weapon is distinguishable and fun; the box feels like an exciting gamble.

**Risks:** art workload of ~24 weapons. Mitigations: shared receivers/components across similar guns, per-class animation rigs, and an acceptable fallback of "high-quality greybox+" for low-priority box weapons if time runs out (logged in PROGRESS.md as a known gap to revisit in Step 16).

---

## Step 10 — Vigor Tonics & power-ups

**Objective:** All 7 perk machines working with distinctive models, jingles and effects; the perk cap; perk loss on down; Second Wind's solo/co-op variants; and all 6 power-ups with drops, presentation and effects.

**Dependencies:** Steps 6, 8, 9 (Fire Sale needs the box).

**Scope:**
1. `PerkDefinition` resources and a `PerkHolder` with stat modifiers applied through a generic `StatModifier` system (health max, reload speed, fire rate, double-bullet flag, move speed, sprint stamina, revive time, hip spread, aim snap, headshot bonus, extra weapon slot).
2. Machine scenes for all 7 with final-quality models (Step 4 pipeline): unique silhouettes, signage, neon/lighting, idle animation, power-off state, purchase animation (bottle drop), and the drinking animation in first person (bottle model per perk).
3. Original jingles (short idle loops + purchase stingers). Placeholders are acceptable if the music isn't ready, but the hooks must be in place; final versions come in Step 15.
4. Rules: perk cap 4, power requirement (except Second Wind), loss on down, Second Wind solo self-revive (3 uses, machine vanishes after the 3rd) and co-op revive-speed variant, and Pack Mule third-slot loss rules.
5. Perk HUD icons (bottle caps) in acquisition order.
6. `PowerUpSystem`: drop scoring algorithm and bag (GAME_DESIGN §11), spawn reachable on navmesh, presentation (rotating model, bob, glow, particles, blinking), pickup, global effects, timers on the HUD with circular countdown, announcer VO placeholder, stacking/reset rules. Nuke staggered kills and Carpenter rebuild integrate with existing systems.
7. Free perk crate interface (used by S1 Director's Office later) and the `Free Upgrade` power-up stub (used in Step 11).
8. Debug: `perk <id>`, `perk_all`, `powerup <id>`, `drop_rate <multiplier>`.

**Acceptance criteria:**
- AC-10.1 Each perk's effect is measurable in an automated test (e.g., reload time halves with Quickdraw; HP 250 with Ironhide; fire rate ×1.33 and double hitscan bullets with Twin-Fire).
- AC-10.2 Perk cap is enforced; perks are lost on down; Second Wind solo self-revive works 3 times and the machine then disappears; the co-op revive time is 2 s with Second Wind.
- AC-10.3 Power-up drop simulation over 30 rounds yields 2–4 drops per round on average early, never > 4 per round, never from trap kills, and follows the bag rules.
- AC-10.4 All 6 power-ups work and replicate; timers agree on all peers within 100 ms (clock-sync check).
- AC-10.5 Machines visually distinct in screenshot review; power-off/on states are correct **[HUMAN]** final approval.
- AC-10.6 Solo playtest **[HUMAN]**: perks feel impactful; power-ups noticeable and exciting.

---

## Step 11 — Power progression: Relays, Lazarus Forge, traps & hazards

**Objective:** Vesper Peak's mid-game progression: Resonance Relays → Reactor Bridge → Lazarus Forge; upgraded versions of every conventional weapon; the three traps; and the environmental hazards.

**Dependencies:** Steps 8, 9, 10.

**Checkpoints:** **11A** relays, bridge, Forge machine and sequence, upgraded weapon definitions + camo; **11B** traps (T1–T3), hazards (H1–H3), upgraded behavior changes (e.g., M16 underbarrel launcher, dual-wield variants), upgraded wall ammo.

**Scope:**
1. Relays R1–R3 (VESPER_PEAK §5): hold, defend (attraction of zombies toward the relay using the Decoy attraction mechanism at a weaker strength), pause rules, progress UI, audio and VFX; all three → bridge extension cinematic beat (camera-less: big audio + visual, the bridge animates).
2. **Lazarus Forge:** final model (industrial anvil-press built around a vesperite conduit), the 5 s sequence (arcs, hammering, flash), floating result with owner lock and 15 s expiry, in-use lock, and a `Free Upgrade` token consumption.
3. **Upgraded weapons:** definitions for every upgrade in GAME_DESIGN §9.3; an animated vesperite-gold camo shader; an upgraded firing sound layer; behavior changes (dual-wield support in the viewmodel system, alt-fire underbarrel, explosive rounds, slow-on-hit, decoy bolts, bounce bolts placeholder for the Ray Pistol in Step 12).
4. **Traps** T1 (electric floor), T2 (steam), T3 (coolant freeze + shatter): generic `Trap` implementation + map-specific VFX/audio; player damage rules; activator points.
5. **Hazards** H1 (fuel drums: respawn), H2 (icicles: regrow), H3 (lab breaker: electrified puddles).
6. Wall-buy upgraded ammo (4500).
7. Debug: `relays_complete`, `forge <weapon_id>`, `trap <id>`.

**Acceptance criteria:**
- AC-11.1 The relay sequence works solo and in co-op; pause rules are correct; the bridge opens and the reactor visual state changes; replicated for late joiners.
- AC-11.2 The Forge upgrades every conventional weapon; damage ×2 and magazine changes match the definitions (automated over all weapons); owner lock and expiry work; Fire Sale doesn't affect the cost.
- AC-11.3 Every upgraded behavior change listed in GAME_DESIGN §9.3 is implemented (checklist test per weapon).
- AC-11.4 Traps kill zombies passing through, damage players per spec, award activator points, and respect cooldown; replicated.
- AC-11.5 Hazards work and reset as specified.
- AC-11.6 **[HUMAN]** The Forge sequence feels like a reward; upgraded weapons feel substantially stronger.

---

## Step 12 — Wonder weapons & special enemies → **M4 Gameplay complete**

**Objective:** The Mk.I Ray Pistol and the Lazarus Conduit (including the build quest and both upgrades), Galvanic special rounds, and the Warden boss *archetype* (used fully by the Easter egg in Step 14).

**Dependencies:** Steps 5, 9, 11.

**Checkpoints:** **12A** Ray Pistol + Conduit + buildable parts/workbench + both Forge upgrades; **12B** Galvanics, special-round flow, Warden archetype (combat behaviors, phases, armor plates) in a test arena.

**Scope:**
1. **Ray Pistol:** final model (original retro design), glowing projectile with travel time, splash with falloff, self-damage, green disintegration death effect, distinctive audio; upgrade "Nova Mk.II" with a color shift, bounce and increased stats.
2. **Lazarus Conduit:** final model (crank-capacitor rifle with glass coils), chain-lightning behavior (target selection, jumps, falloff), electrocution stun state in the zombie brain, pulse alt-fire, arc VFX (procedural line/mesh arcs with glow), audio; upgrade "Lazarus Requiem".
3. **Buildable system (generic, `core/world/buildables`):** part pickups (shared team inventory, HUD), randomized spawn options from `MapDefinition`, workbench build hold, first-claim + box pool unlock.
4. **Galvanics:** model + animations (sprint, leap, electric death burst), archetype, rift spawner with telegraph, plank-disable on death, special round flow (warning, fog/lights change, music, last-kill Max Ammo), mixed spawns from round 20.
5. **Warden archetype:** model + animations; armor plate system (damage reduction per plate, plate break VFX), core weak point, slam/charge/summon attacks with telegraphs, phase thresholds, freeze-by-coolant response; spawned via debug in a test arena (the full finale integration is Step 14). The rare late-round appearance rule is implemented but gated behind a `MapRules` flag (enabled in Step 14 after balancing).
6. Debug: `give raygun`, `give conduit`, `special_round`, `spawn_warden`.

**Acceptance criteria:**
- AC-12.1 Ray Pistol: projectile speed, splash, self-damage and box rarity per spec (unit + integration); upgrade bounce works.
- AC-12.2 Conduit: chains to the correct number of targets within jump range, damage falloff correct, stun duration correct, pulse works; upgraded version per spec (automated with a dummy cluster).
- AC-12.3 Buildable: parts spawn at one of two locations per match (seeded test), shared in co-op, build requires power, the box pool includes the Conduit only after the first build.
- AC-12.4 Special rounds occur on the scheduled rounds (simulation over 50 rounds), with the telegraph, correct counts and health scaling, and a Max Ammo drop on the last kill.
- AC-12.5 Warden: plates, core, attacks and phases function in the test arena; telegraphs ≥ 0.6 s; it can be killed by a 2-player team with upgraded weapons at round 20 health in 3–6 minutes (bot or human measurement).
- AC-12.6 Visual effects stay within performance budget (Conduit chain on 10 zombies + 32 alive: no frame spikes > 25 ms on the reference GPU **[HUMAN]**; particle and light counts within caps automatically).
- AC-12.7 **[HUMAN]** Wonder weapons feel "dramatically different and powerful"; special rounds are tense but fair.
- **Milestone M4** reached: every core gameplay system exists in greybox Vesper Peak. A full-length run (power → Forge → wonder weapons → round 30+) is possible.

---

## Step 13 — Vesper Peak art & atmosphere → **M5 Visually complete map**

**Objective:** Turn the greybox into the final, cohesive, atmospheric Vesper Peak described in VESPER_PEAK §3 and §8, without moving gameplay markers, while staying within performance budgets.

**Dependencies:** Steps 4, 8. Best after 12 (systems stable), but 13A–C can run in parallel with Steps 9–12 if markers are final.

**Checkpoints (each likely its own session):**
- **13A Exterior:** Z01 Arrival Station (interior + gondola dock), Z06 Frozen Courtyard, Z07 Communications Array + radar tower, Sky Bridge, gondola cabin & cable, mountain backdrop (distant peaks, skybox/moon, cloud layers), storm system (gust events, wind shader, snow density zones), searchlights.
- **13B Sanatorium:** Z03 Lobby (+ S1 Director's Office), Z04 East Wing, Z05 Operating Theater (glass dome).
- **13C Underground:** Z08 Boiler House, Z09 Generator Hall (power-on light cascade sequence polish), Z10 Morgue & Tunnels, Z11 Containment Labs, Z12 Specimen Storage, S2 Ice Grotto.
- **13D Reactor & global pass:** Z13 Lazarus Reactor Chamber (core, rings, cables, arcs, heartbeat sync, power/relay/EE visual states), global lighting consistency, color grading per zone, reverb zones, ambience layering, occlusion/LOD/HLOD pass, performance validation.

**Scope (each area):**
1. Replace greybox meshes with final kit pieces and props; dress environmental-storytelling vignettes (VESPER_PEAK §6.2).
2. Lighting per the palette rules; ≤ 8 shadow-casting lights visible anywhere; light flicker and power-state variants.
3. VFX: fog volumes, dust motes, steam, sparks, drips, embers, energy leaks, snow drift through openings.
4. Audio: ambience beds and spot emitters per zone, reverb buses, occlusion.
5. Decals: grime, blood, frost, stencils, signage (original Group Vesper and sanatorium branding).
6. Navigation re-bake and nav validation after art (art collision must not break pathing).
7. Optional: LightmapGI bake for interiors **[HUMAN-run]** if it improves quality within budget.
8. Screenshot set per zone (`docs/screenshots/step13/`).

**Acceptance criteria:**
- AC-13.1 Every zone's gameplay markers are unchanged (automated diff of marker transforms against the Step 8 manifest, tolerance 0.01 m; intentional changes logged).
- AC-13.2 `nav_validate` passes after art for every zone.
- AC-13.3 Performance: full map, 32 zombies, 4 players, Medium preset ≥ 60 FPS on the minimum spec and High ≥ 90 FPS on the reference spec in the 5 heaviest viewpoints **[HUMAN]**; automated draw-call and light-count checks per viewpoint.
- AC-13.4 Every zone has ambience, reverb, and at least one environmental storytelling vignette; the 10 vignettes in VESPER_PEAK §6.2 exist.
- AC-13.5 Landmark sightlines verified (radar tower visible from the listed positions; reactor glimpse from Z12) via screenshot set.
- AC-13.6 **[HUMAN]** Visual review per checkpoint: cohesive, atmospheric, "a real indie horror shooter", no primitive-looking areas.
- **Milestone M5** reached.

**Risks (high):** the largest art workload. Mitigations: prop reuse via a shared prop library, kit-based construction, lighting/fog doing heavy lifting, and checkpoint-level scheduling so quality isn't rushed. If an area falls short, log it and schedule a dedicated follow-up session rather than lowering the bar silently.

---

## Step 14 — Easter egg, lore & secrets

**Objective:** The complete optional storyline: lore documents and reels with the Journal, secret rooms, minor secrets, and the main quest "Requiem for Lazarus" (VESPER_PEAK §7) including the Warden finale and rewards.

**Dependencies:** Steps 11, 12 (mechanics reused), 13 recommended (final spaces).

**Checkpoints:** **14A** quest engine (`core/quest`), lore/journal, secrets (S1, S2, music boxes, ravens, mirror, departures board), EE stages 0–3; **14B** stages 4–6 (escort carry item, nodes, finale with pylons and Warden), rewards, ending sequence, persistent badges, rare Warden spawn rule enabled.

**Scope:**
1. **Quest engine** per ARCHITECTURE §10: graph resources, event-driven objectives, host authority, snapshot integration, debug jump/skip, HUD-less design (diegetic cues only; optional subtle "quest step complete" sound).
2. Lore: 14 documents (written now, final text in `maps/vesper_peak/lore/`), 9 reels (R01–R08 in-world, R09 unlocked by the finale) with transcripts and VO (placeholder TTS or human-recorded; subtitles), a document reader UI, and a Journal in the main menu (persistent local unlocks).
3. Secrets: S1 bookcase sequence + free tonic crate; S2 waterfall break + grotto; music box song (original track; placeholder if music isn't ready); ravens; mirror; departures board messages.
4. EE stages 0–6 exactly per VESPER_PEAK §7, with the co-op scaling rules and failure/retry rules.
5. **Carry item** mechanic (generic `CarryItem` in core: movement restrictions, drop/pass, auto-drop on down, zombie prioritization).
6. Finale: pylons (repairable objectives), Warden integration with arena, phase choreography, music, ending sequence (in-engine camera moment + VO), storm subsiding state for one round, reactor color change, rewards (Lazarus Blessing perks persistence on revive, Free Upgrade tokens), persistent badge on map card.
7. **Writing:** final Varga/Haemmer/character VO scripts for the quest (in `docs/` or `maps/vesper_peak/lore/script.md`).
8. Automated test: a headless "quest runner" that completes each stage via scripted events/bots, plus a full-quest run using debug skips + one end-to-end attempt with bots where feasible.

**Acceptance criteria:**
- AC-14.1 Each stage can be completed solo and with 4 players; scaling values correct (automated per-stage tests with 1 and 4 bot players using scripted actions).
- AC-14.2 No stage can be permanently locked by failure (tests force failures: Galvanic escapes, escort timer expiry, pylons destroyed, wrong frequency, wrong drawer order).
- AC-14.3 Late join and reconnect during each stage preserve correct quest state.
- AC-14.4 Finale and rewards work: all perks granted ignoring cap and restored after each revive; Free Upgrade tokens; badge persisted.
- AC-14.5 All 14 documents, 9 reels and secrets exist and are readable/playable; Journal unlocks persist across launches.
- AC-14.6 **[HUMAN]** A full Easter egg run by the human (solo or with friends) without debug commands, in ≤ 2 hours, with notes on clarity and fun.

**Risks:** quest clarity — players may get stuck. Mitigation: every step has in-world clues (VO from Varga, visual changes), and the design rule of "no pixel-hunting". A post-1.0 option: an optional hint mode.

---

## Step 15 — Presentation & audio finalization → **M6 Content complete**

**Objective:** Final, cohesive UI and audio: main menu, map select, lobby, settings, pause, HUD, game over and Journal in the Cold War horror style; the final audio mix with music, jingles, announcer and character VO.

**Dependencies:** All gameplay steps (6–14).

**Checkpoints:** **15A** UI/menus/HUD/settings/accessibility; **15B** audio: final SFX pass, music, jingles, announcer, character quips, mix and dynamic music.

**Scope:**
1. **UI theme:** a typography pairing (a stencil/typewriter display face + a readable sans for body text; open-license fonts), a paper/dossier texture language, red ink accents, animated transitions; consistent widgets (buttons, sliders, tabs, key-rebind rows).
2. **Main menu:** an animated 3D background (Vesper Peak gondola station in the storm, from the final map assets), Solo / Multiplayer / Journal / Settings / Credits / Quit; map select with the map card (preview art, best round, EE badge; designed for future maps); lobby restyle.
3. **HUD final** per GAME_DESIGN §15: round tallies/numerals with transition animations, points, ammo, perks, power-ups, prompts, teammate panel, hit markers, damage effects, HUD scale, colorblind palettes.
4. **Settings:** everything in GAME_DESIGN §18, with full key/gamepad rebinding UI and apply/revert.
5. **Pause menu** (solo pause, co-op non-pausing), **game over** (slow-mo, stats table, best-round highlight, "Play Again" returning host and clients to the lobby).
6. **Audio:** final weapon audio polish, zombie VO sets, machine jingles (original), Relic Box melody, Forge sounds, round start/end stings, special round music, dynamic music layers by intensity, EE song "Snowblind", announcer ("Voice of the Mountain"), character quips (box results, perks, low ammo, downed, revive, kills) with cooldowns and priority, subtitles.
7. **Mix:** bus levels, ducking (VO ducks music/ambience), limiter on master, distance attenuation curves, occlusion tuning, loudness target (≈ −16 LUFS integrated for gameplay capture).
8. Credits screen with all asset licenses (generated from `ASSET_LICENSES.md`).

**Acceptance criteria:**
- AC-15.1 Every screen is reachable and navigable with mouse, keyboard and gamepad; no dead ends; rebinding works and persists.
- AC-15.2 HUD readable at 1280×720 through 3840×2160 and HUD scale 75–150% (screenshot matrix).
- AC-15.3 All audio events in the game have final or explicitly accepted assets (automated audit: no references to `placeholder_` assets remain unless whitelisted with a reason).
- AC-15.4 Mix: no clipping on the master during a 32-zombie Ray Pistol fight (peak meter log); VO intelligible over combat (human check).
- AC-15.5 Credits list every third-party asset.
- AC-15.6 **[HUMAN]** Presentation review: "feels like a finished game".
- **Milestone M6** reached.

**Risks:** music and VO need human creative input or licensed sources. Mitigation: a clear asset request list delivered at the start of Step 15 (or earlier in PROGRESS.md "Human tasks"), with placeholders that don't block gameplay.

---

## Step 16 — Balance, optimization, QA & release candidate → **M7 Vesper Peak 1.0**

**Objective:** Make the game consistently fun, fair, stable and smooth from round 1 to round 50+, in solo and 4-player co-op, and produce release builds.

**Dependencies:** Steps 1–15.

**Checkpoints:** **16A** balance + QA bug bash; **16B** performance optimization, network soak, release builds.

**Scope:**
1. **Balance:** economy pacing vs. targets (GAME_DESIGN §6.3) using simulated runs and human runs; weapon tiering (box weapons worth the gamble, wall-buys viable to mid rounds, upgrades meaningful); perk value; zombie speed/health curve at rounds 20/30/40/50; special round frequency; trap value; EE difficulty; co-op scaling for 2/3/4 players. All changes recorded in the tuning log.
2. **QA pass:** a structured test plan (`docs/QA_TEST_PLAN.md`) covering every feature in GAME_DESIGN and VESPER_PEAK, executed with results; a bug list triaged by severity; fix all S1/S2 bugs.
3. **Performance:** profiling sessions (CPU, GPU, memory) at the heaviest viewpoints; fix hotspots (GDExtension escape hatch only if necessary); shader compile stutter mitigation (pipeline precompilation / warm-up at load); load-time optimization; memory leak checks over a 2-hour soak.
4. **Network soak:** a 4-player 2-hour session (bots + humans) with NetSim profiles; desync checks; bandwidth; reconnect stress (repeated disconnects).
5. **High-round stability:** bot soak to round 60 with godmode-off upgraded bots (or a time-accelerated simulation) to catch numeric overflow, pool exhaustion, nav issues.
6. **Release builds:** export presets for Windows and Linux, versioning, a crash log capture (`user://logs`), a README "How to play with friends" guide, and an optional Steam build pipeline if a Steamworks App ID is acquired.
7. **Final docs:** all docs updated to reflect the shipped state; a post-1.0 backlog (future maps, hint mode, voice chat, etc.).

**Acceptance criteria:**
- AC-16.1 Zero known S1 (crash/progress-blocking) and S2 (major feature broken) bugs.
- AC-16.2 Two-hour solo and 4-player sessions without crashes, desyncs (state hash checks) or memory growth > 10%.
- AC-16.3 Performance targets from ARCHITECTURE §2.4 met on the min and reference specs **[HUMAN]**; no hitch > 50 ms during gameplay after the warm-up.
- AC-16.4 Bot soak to round 60 completes without errors; round 50 remains beatable by competent humans with upgraded weapons (designer judgment) **[HUMAN]**.
- AC-16.5 Economy pacing within ±2 rounds of the targets in GAME_DESIGN §6.3 across 5 human solo runs **[HUMAN]**.
- AC-16.6 Exported Windows and Linux builds launch on clean machines and connect to each other **[HUMAN]**.
- AC-16.7 QA test plan executed with ≥ 95% pass and all failures triaged.
- **Milestone M7** reached: **Vesper Peak 1.0**.

---

## 17. Milestones — what the game looks like at each

| Milestone | After step | What you can do / see |
|---|---|---|
| **M0 "Feels good"** | 3 | Run, slide, mantle and shoot 4 weapons at dummies in a grey gun range with a friend on LAN. Simple models, but movement and shooting already feel tight and punchy. |
| **M1 First Playable** | 6 | Survive endless rounds in a greybox Arrival Station with two doors to buy. Real zombies shamble, then sprint, tear barricades and swarm you. Points, wall-buys, downs, revives and game over all work, solo or LAN co-op. Basic HUD. |
| **M2 Play with friends** | 7 | Host or join over the internet, pick one of four characters, see teammates fully animated with name tags and pings. Late join and reconnect work. |
| **M3 Whole map playable** | 8 | All of Vesper Peak in greybox with real lighting, fog and snow: 13 zones, 14 doors, the gondola, the freight lift, power-on. Map flow and training loops can be tested for real. |
| **M4 Gameplay complete** | 12 | A full classic run in greybox: perks, the Relic Box, every weapon, power, relays, the Forge, traps, the Ray Pistol and Conduit, Galvanic rounds. This is the point to judge whether the game is fun. |
| **M5 Visually complete map** | 13 | Vesper Peak looks like the final game: a stormy summit, a decaying sanatorium, industrial tunnels, clinical labs and the spectacular reactor chamber. |
| **M6 Content complete** | 15 | Easter egg and lore done; final menus, HUD, music, jingles and VO. It looks and sounds like a finished game. |
| **M7 Vesper Peak 1.0** | 16 | Balanced, optimized, stable releases for Windows and Linux, ready for long sessions with friends. |

---

## 18. Risk register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | **Art quality ceiling** (agents can't sculpt hero assets well) | High | High | Stylized low-poly target; lighting/fog/color carry the look; scripted kits; CC0 libraries; human-supplied or commissioned hero assets through a documented drop-in path; dedicated art steps with human visual sign-off. |
| R2 | **Animation quality** (weapons, zombies, characters) | High | High | CC0/Mixamo libraries + retargeting; strong procedural layers for viewmodels; shared class rigs; human review at Steps 3, 5, 9. |
| R3 | **Crowd AI navigation/performance** | Medium | High | Budgets, test maps for worst cases, nav validation tool, stuck re-queue, a GDExtension escape hatch. |
| R4 | **Internet co-op connectivity** (NAT, Steam integration) | Medium | High | Transport abstraction; direct IP + VPN fallback; Steam via GodotSteam; tested early in Step 7. |
| R5 | **Desync / co-op state bugs** | Medium | High | Host authority, full-state snapshots, automated state-hash tests every step from 6 on. |
| R6 | **Context loss between sessions** | High | Medium | PROGRESS.md, session reports, canonical ids, the AGENT_GUIDE protocol; small, focused steps with checkpoints. |
| R7 | **Cloud container can't render/bake/test on GPU** | High | Medium | Headless tests for logic; software-rendered screenshots; [HUMAN] criteria for GPU/perf/feel; LightmapGI optional. |
| R8 | **Audio/music/VO need creative input** | High | Medium | Placeholders never block; asset request list; CC0/royalty-free libraries; TTS option for VO (with license review). |
| R9 | **Repository size / Git LFS quotas** | Medium | Medium | Asset budgets, `.ogg` over `.wav`, compress textures, keep `.blend` sources out of LFS unless needed; consider an LFS data pack or external asset storage. |
| R10 | **Scope creep** (extra maps, features) | Medium | Medium | Out-of-scope list (§19); changes go through PROGRESS.md "Proposed changes". |
| R11 | **Godot/addon version churn** | Low | Medium | Pinned versions; upgrade only between milestones with a full test run. |
| R12 | **Easter egg clarity** | Medium | Low | In-world clues, VO guidance, human playtest in Step 14. |
| R13 | **IP similarity** | Low | High | Original names, art, audio, characters and story (GAME_DESIGN §1.3); no ripped assets. |

---

## 19. Explicitly out of scope for 1.0 (backlog)

Additional maps; host migration; dedicated servers; matchmaking with strangers; built-in voice chat (stretch: Steam voice); controller aim assist beyond light slowdown; split-screen; mod support; console ports; leaderboards (online); hint mode for the Easter egg; additional game modes (e.g., Grief).

---

## 20. Roadmap self-review (planning session)

I reviewed this plan against the brief and checked missing features, dependencies, workloads and architecture:

| Check | Finding | Resolution |
|---|---|---|
| Brief coverage | Every section of the brief (1–20) maps to steps: movement (2), weapons (3, 9), zombies (5, 12), rounds (6, 12), economy (6), box (9), wonder weapons (12), Forge (11), perks (10), power-ups (10), environment (8, 11), Easter egg (14), co-op (1, 6, 7 + every step), HUD/menus (6, 15), audio (every step + 15), replayability/balance (16), expandability (1, 6 `MapDefinition`, ARCHITECTURE §9). | — |
| Missing: teammate character models | Not explicit in the brief, but needed for "clear player identification". | Added to Step 7. |
| Missing: crawlers, gibs, ragdolls | In the brief ("crawlers where practical"). | Step 5 (AC-5.4). |
| Missing: map-specific traversal | In the brief. | Gondola, freight lift, chute, bridge (Step 8). |
| Dependency issue: the box's Fire Sale needs the box before power-ups | Ordering. | Step 9 (box) before Step 10 (power-ups). |
| Dependency issue: the Easter egg needs the Conduit, upgraded weapons, Galvanics, traps and the Warden | Ordering. | Steps 11, 12 before 14; Warden archetype built in 12B, integrated in 14B. |
| Dependency issue: art could break navigation | Risk. | AC-13.1/13.2 (marker diff + nav re-validation). |
| Workload: Steps 8, 9, 13, 14 too big for one session | Yes. | Checkpoints; 13 has 4 sub-sessions. |
| Workload: Step 5 (AI + animation + net) | Large. | Split into 5A (headless sim) and 5B (visuals/net polish). |
| Architecture: solo vs. co-op divergence | Risk of "co-op afterthought". | One code path (D-003); 2-peer test required in every DoD. |
| Architecture: late join with quest state | Risk. | Full-state snapshot designed in Step 7 and extended in each step; AC-14.3. |
| Architecture: map/core coupling | Risk for future maps. | Enforced boundary check in `tools/check.sh`. |
| Unrealistic: 120 FPS targets in a software-rendered container | Can't be measured by agents. | Marked [HUMAN]; automated proxies (draw calls, light counts, CPU ms). |
| Unrealistic: full VO for 4 characters | High effort. | Planned with a TTS/human recording fallback; text subtitles mandatory; quips are optional polish in 15B. |
