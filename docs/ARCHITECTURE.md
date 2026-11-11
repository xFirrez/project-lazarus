# Project Lazarus — Technical Architecture

> Status: **Approved baseline (planning phase)**. Changing a decision in this document requires an entry in the *Decision Log* (§14) explaining why.
> Related: [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) · [GAME_DESIGN.md](GAME_DESIGN.md) · [VESPER_PEAK.md](VESPER_PEAK.md) · [PROGRESS.md](PROGRESS.md) · [AGENT_GUIDE.md](AGENT_GUIDE.md)

---

## 1. Requirements that drive the architecture

| Requirement (from the brief) | Architectural consequence |
|---|---|
| Fast, responsive FPS movement and gunplay | Custom kinematic character controller, fixed-rate physics, local-first input handling, procedural viewmodel animation. |
| Zombies that genuinely navigate a multi-floor map | Navigation meshes per zone, off-mesh links for windows/drops/stairs, a central crowd director with a path-query budget. |
| Up to 4-player co-op that is *not* bolted on | Host-authoritative simulation from Step 1. Solo play is "a host with zero remote clients" — same code path. |
| Stylized, atmospheric visuals at a smooth framerate | Modern real-time renderer with volumetric fog, glow, SSAO, good shadow control; strict performance budgets. |
| Large data-heavy rule set (weapons, perks, rounds, economy) | Data-driven definitions (Resources) separate from behavior code; balance changes require no code edits. |
| Future maps without a rewrite | A hard boundary between `core/` (generic Zombies systems) and `maps/<map>/` (layout, quest, map rules). |
| Work is performed by AI coding agents in separate sessions | Text-based, diffable project files; headless test runner; debug console; exhaustive persistent docs. |

---

## 2. Engine and tool decisions

### 2.1 Engine: **Godot 4 (latest stable 4.x, pinned in Step 1)**

**Why Godot 4:**

1. **Text-first project format.** Scenes (`.tscn`), resources (`.tres`), scripts and project settings are human-readable text. AI agents can create, read, review and diff every part of the game without a graphical editor. This is the single most important factor for an agent-driven project. Unreal (binary `.uasset`, Blueprints) and Unity (editor-centric workflow, large serialized YAML, GUIDs in `.meta` files) are far harder for an agent to manipulate correctly.
2. **Headless operation.** Godot runs `--headless` for imports, tests, scripted simulations and dedicated-host processes inside the cloud container. Agents can verify gameplay logic without a GPU.
3. **Everything this game needs is built in:** Forward+ renderer (volumetric fog, glow/bloom, SSAO/SSIL, SDFGI, decals, GPU particles), `NavigationServer3D` (navmesh baking, path queries, avoidance, navigation links), Jolt physics integration, `AnimationTree` with blend spaces and humanoid retargeting, a high-level multiplayer API (`SceneMultiplayer`, RPCs, `send_bytes`) over ENet, audio buses with effects.
4. **No licensing cost or royalties**, open source, small download, fast iteration.
5. **Stylized low-poly realism is Godot's sweet spot.** We are not chasing photorealism, so Unreal's main advantage (Nanite/Lumen fidelity) is irrelevant, while its costs (C++ build times, binary assets, heavy hardware) are severe.

**Tradeoffs accepted:**

| Weakness | Mitigation |
|---|---|
| Fewer ready-made FPS/Zombies templates than Unity/Unreal | We build our own controller and systems anyway — feel must be bespoke. |
| GDScript is slower than C++/C# for hot loops | Zombie cap is ≤32 alive; heavy work (pathing) is in the engine's C++ servers. A GDExtension (C++) escape hatch is reserved for any profiled hotspot (§12). |
| Lightmap baking requires the GPU editor | Lighting is designed to look good with real-time lights + fog; LightmapGI baking is an *optional* polish task run by the human on a desktop (see AGENT_GUIDE §8). |
| Steam integration is third-party (GodotSteam) | Direct-IP ENet co-op is the baseline; Steam lobbies are an additive transport (Step 7). |
| Agents sometimes write Godot 3 syntax | AGENT_GUIDE lists the Godot 4 idioms explicitly; static typing + linter catch most mistakes. |

### 2.2 Language: **Statically typed GDScript** (GDExtension/C++ only if profiling proves it necessary)

- Every variable, parameter and return value is typed (`var hp: int = 100`, `func f(x: float) -> void`). Untyped code is rejected in review.
- Reason for GDScript over C#: tighter editor/engine integration, no .NET runtime in exports, hot-reload, no version-mismatch issues with the engine's .NET build, and the agent can run it in the stock headless binary.

### 2.3 Supporting tools

| Purpose | Tool | Notes |
|---|---|---|
| Unit/integration tests | **GUT** (Godot Unit Test) addon, run headless | `tools/run_tests.sh` wraps it. |
| Lint / format | **gdtoolkit** (`gdlint`, `gdformat`) via pip | Enforced by `tools/check.sh` and CI. |
| CI | GitHub Actions: import, lint, unit tests, headless simulation tests, export smoke build | Uses a pinned Godot headless binary. |
| 3D asset creation | **Blender** (scripted via `bpy` for modular kits and props; manual edits welcome) → `.glb` export | Generator scripts live in `tools/blender/` so assets are reproducible from text. |
| Characters & animation | CC0 humanoid bases and animation libraries (e.g., Quaternius, Kenney), optionally Mixamo (human downloads), retargeted in Godot via `SkeletonProfileHumanoid` | All sources logged in `ASSET_LICENSES.md`. |
| Textures | CC0 libraries (e.g., Poly Haven, ambientCG) downscaled and stylized; hand-made trim sheets and palette textures | Stylized look relies on palette textures + vertex color + a few tiling materials. |
| Audio | CC0 / royalty-free libraries (Freesound CC0 filter, Sonniss GDC bundles), procedural synthesis (sfxr-style) for UI; music composed or licensed by the human | Every file logged in `ASSET_LICENSES.md`. |
| Large files | **Git LFS** for `.glb`, `.png`, `.ogg`, `.wav`, `.blend` | GitHub LFS quotas are limited; see §11 asset budget. |
| Visual verification in cloud | Godot under `xvfb-run` with Mesa software Vulkan (lavapipe) and `--write-movie`/viewport screenshots | Slow but lets agents capture reference screenshots; the human verifies on real hardware. |
| Network condition testing | Built-in `NetSim` wrapper (latency/jitter/loss injection in our transport layer) + optional Linux `tc netem` | Allows automated 4-client tests in one container. |

### 2.4 Target platforms and performance budget

- **Primary:** Windows 10/11 and Linux desktop, keyboard + mouse. **Secondary:** gamepad (full support, light aim slowdown).
- **Minimum target:** 60 FPS at 1080p on a GTX 1660 / RX 580-class GPU, 4-core CPU, "Medium" preset, with 32 zombies alive in the busiest area.
- **Recommended target:** 120+ FPS on RTX 3060-class at 1080p "High".
- **Frame budget (60 FPS = 16.6 ms):** game logic ≤ 3 ms on the host (zombie AI + nav ≤ 1.5 ms), rendering ≤ 11 ms, headroom 2 ms.
- **Memory:** ≤ 3 GB RAM, ≤ 2 GB VRAM on Medium.
- **Network:** ≤ 25 KB/s downstream per client during a 32-zombie fight; playable at 150 ms RTT with 2% packet loss.

---

## 3. Repository layout

```
project-lazarus/
├── CLAUDE.md                  # Pointer for agents → docs/AGENT_GUIDE.md
├── README.md
├── docs/                      # Persistent design + process documentation (this folder)
│   ├── ARCHITECTURE.md  DEVELOPMENT_PLAN.md  GAME_DESIGN.md
│   ├── VESPER_PEAK.md   PROGRESS.md          AGENT_GUIDE.md
│   ├── ASSET_LICENSES.md      # (Step 1+) every third-party asset, source, license
│   └── sessions/              # (Step 1+) one short report per coding session
├── tools/
│   ├── check.sh               # lint + format check + unit tests (fast; run before every commit)
│   ├── run_tests.sh           # GUT runner (unit | integration | all)
│   ├── run_sim.sh             # headless gameplay simulations / soak tests
│   ├── run_coop_local.sh      # host + N clients on localhost with optional NetSim
│   ├── screenshot.sh          # xvfb + lavapipe screenshot capture of named camera shots
│   ├── blender/               # bpy generator scripts for modular kits, props, weapons
│   └── godot_version.txt      # pinned engine version
├── .github/workflows/ci.yml
└── game/                      # Godot project root (project.godot lives here)
    ├── project.godot
    ├── addons/                # gut/, (later) godotsteam/
    ├── core/                  # MAP-AGNOSTIC game framework (never references a specific map)
    │   ├── autoload/          # Singletons (see §4.1)
    │   ├── net/               # transport, session, replication, entity registry, netsim
    │   ├── player/            # controller, camera, health, downed/revive, inventory
    │   ├── weapons/           # weapon runtime, behaviors, viewmodel, ballistics, definitions schema
    │   ├── enemies/           # zombie actor, AI brain, crowd director, archetypes schema
    │   ├── rounds/            # round director, spawn director, difficulty curves
    │   ├── economy/           # points ledger, purchase validation
    │   ├── interaction/       # Interactable component, prompts, hold-to-use
    │   ├── world/             # zones, doors, barricades, power grid, traps, hazards, traversal
    │   ├── machines/          # perk machine, mystery box, forge (pack-a-punch) – generic logic
    │   ├── powerups/          # drop logic, effects
    │   ├── quest/             # data-driven quest/step graph engine (Easter eggs, side quests)
    │   ├── audio/             # audio director, music director, occlusion, footsteps
    │   ├── vfx/               # pooled effects, decals, impact library, screen effects
    │   ├── ui/                # HUD, menus, lobby, settings, game-over (theme + widgets)
    │   └── debug/             # console, overlays, perf HUD, cheats (dev builds only)
    ├── content/               # SHARED data & assets usable by any map
    │   ├── weapons/<id>/      # definition .tres, viewmodel/worldmodel scenes, audio, textures
    │   ├── perks/<id>/        # definition .tres, machine scene, jingle, icon
    │   ├── powerups/  enemies/  characters/  materials/  shaders/  audio/  ui/
    ├── maps/
    │   ├── _test/             # test arenas: movement course, gun range, nav torture test, perf arena
    │   └── vesper_peak/
    │       ├── map_definition.tres      # zones, spawn tables, box locations, weapon pools, rules
    │       ├── vesper_peak.tscn         # root map scene (instancing zone scenes)
    │       ├── zones/<zone_id>.tscn     # one scene per zone: geometry, nav region, spawners, props
    │       ├── scripts/                 # map rules, quest steps, traversal, map-specific traps
    │       ├── quest/                   # Easter egg quest graph resources
    │       ├── lore/                    # documents, audio-log transcripts
    │       └── art/  audio/
    └── tests/
        ├── unit/              # pure logic: formulas, ledger, RNG tables, state machines
        ├── integration/       # scenes run headless: nav reachability, round flow, purchases
        └── net/               # multi-peer tests over loopback with NetSim
```

**Rule:** `core/` must never `preload`/reference anything under `maps/`. Maps plug into `core/` only through `MapDefinition` data and the `MapRules` script interface (§9). A CI check (`tools/check.sh`) greps for violations.

---

## 4. Runtime architecture overview

```
                    ┌──────────────────────── HOST (authoritative) ─────────────────────────┐
 Local input ─────▶ │ PlayerController(local) ──state──▶ PlayerRegistry                      │
                    │ RoundDirector ─▶ SpawnDirector ─▶ CrowdDirector ─▶ Zombie actors (sim)  │
                    │ Economy(PointsLedger)  ZoneManager  PowerGrid  Machines  QuestSystem   │
                    │ HitValidator ◀── hit claims from all peers                              │
                    │ ReplicationServer ──snapshots (20 Hz, unreliable)──┐                    │
                    │ EventBus/RPC ──────events (reliable)───────────────┤                    │
                    └────────────────────────────────────────────────────┼────────────────────┘
                                                                         ▼
                    ┌──────────────────────── CLIENT (presentation + own player) ────────────┐
 Local input ─────▶ │ PlayerController(local, predicted) ──own state 30 Hz──▶ host           │
                    │ WeaponRuntime: local fire, local raycast → hit claim ──▶ host          │
                    │ ReplicationClient: interpolated zombies/remote players (100 ms buffer) │
                    │ Presentation: animation, VFX, audio, HUD driven by replicated state     │
                    └─────────────────────────────────────────────────────────────────────────┘
```

**Golden rules**

1. **Gameplay state is mutated only on the host.** Clients *request* (purchase, interact, revive, hit claim); the host *decides* and broadcasts results.
2. **Solo = host with no clients.** There is no separate single-player code path. Solo uses `OfflineMultiplayerPeer` or a loopback ENet host; every system must work identically.
3. **Simulation and presentation are separated.** A zombie's brain/health/position live in a simulation component that runs only on the host; the visual node (skeleton, animation, audio, VFX) runs everywhere and is driven by state. This keeps clients cheap and makes headless tests possible.
4. **Data, not code, defines content.** Weapons, perks, power-ups, enemy archetypes, round curves and map layouts are `Resource` files.

### 4.1 Autoload singletons (`core/autoload/`)

| Autoload | Responsibility |
|---|---|
| `Log` | Leveled, categorized logging (`Log.info(&"net", "...")`); ring buffer viewable in console. |
| `Config` | Settings (video, audio, input, gameplay), persisted to `user://settings.cfg`. |
| `EventBus` | Typed global signals for *local* decoupling (UI ↔ systems). Never used for networking. |
| `Net` | Session lifecycle (host/join/leave), transport selection, peer list, NetSim, tick clock. |
| `Game` | Top-level state machine: `Boot → MainMenu → Lobby → Loading → InMatch → GameOver`. Owns the current `Match`. |
| `Content` | Registry that loads all definitions (`WeaponDefinition`, `PerkDefinition`…) by `StringName` id. |
| `Audio` | Bus management, pooled one-shots, music director, VO queue. |
| `Pools` | Object pools for VFX, decals, projectiles, ragdoll gibs, audio players. |
| `Debug` | Console, command registry, overlays (dev builds; stripped/disabled in release). |

Per-match objects (created by `Game` when a match starts, freed afterwards) are **not** autoloads: `Match`, `RoundDirector`, `SpawnDirector`, `CrowdDirector`, `ZoneManager`, `PowerGrid`, `Economy`, `MachineRegistry`, `PowerUpSystem`, `QuestSystem`, `ReplicationServer/Client`. They hang under the `Match` node and are reachable via `Match.current`.

---

## 5. Networking architecture

### 5.1 Model: **listen-server, host-authoritative, co-op trust model**

- One player hosts; up to 3 join. The host's machine runs the authoritative simulation and also renders for the host player.
- Because this is a private co-op game among friends, we adopt a **"favor the shooter" trust model**: clients perform their own hit detection against what they see, then send *hit claims*. The host performs cheap sanity validation (target alive, weapon owned, rate-of-fire budget, max range, rough line-of-sight) and applies damage. This removes the need for lag-compensation rewinding, which is the most complex part of competitive netcode, while keeping hits feeling instant for everyone.
- Players are **owner-authoritative for their own movement** (clients simulate their own character and send state at 30 Hz). The host validates against speed limits and collision (rejecting teleports) and clamps if needed. Zombies use the host's view of player positions.
- **No host migration.** If the host quits, the match ends for everyone (with a clear message). Host migration is extremely complex for a full-state simulation and would distort the whole architecture. Documented as a known limitation.

### 5.2 Layers (`core/net/`)

| Layer | Contents |
|---|---|
| **Transport** | `NetTransport` interface with implementations: `EnetTransport` (direct IP / LAN / VPN such as Tailscale), `OfflineTransport` (solo), `SteamTransport` (Step 7, via GodotSteam's multiplayer peer). All wrap a `MultiplayerPeer` so the rest of the code is transport-agnostic. |
| **NetSim** | Optional wrapper that delays/drops/reorders outgoing packets (latency, jitter, loss) for testing. Toggled by command-line flag or console. |
| **Session** | Lobby state, player slots (1–4), character selection, ready-up, join-in-progress policy, persistent player identity (`player_uid`: Steam ID or a generated UUID stored in `user://`), reconnect tokens. |
| **Entity registry** | Every replicated entity has a `NetId` (uint16) assigned by the host; spawn/despawn messages are reliable RPCs. |
| **Replication** | Compact binary snapshots via `multiplayer.send_bytes` on an unreliable channel at **20 Hz**: zombie positions (quantized), yaw, locomotion/action enum, health bucket, flags; remote player states. Clients keep a **100 ms interpolation buffer** (adaptive to jitter). |
| **Events** | Reliable RPCs for discrete events: purchases, door opens, power on, perk acquired, box result, power-up spawn/pickup, round change, downed/revived, quest steps. Each event carries the host's tick. |
| **Late join / reconnect** | On join, the host sends a full `MatchStateSnapshot` (doors, power, traps, box location, quest flags, round, all player states) before streaming deltas. Disconnected players' states are retained for the session, keyed by `player_uid`, and restored on rejoin. |

### 5.3 Tick model

- Physics: **60 Hz** fixed (`physics_ticks_per_second = 60`) everywhere; rendering is uncapped/interpolated (physics interpolation enabled).
- Host simulation tick for AI decisions: 60 Hz movement, staggered "think" at 10 Hz per zombie, path re-queries on a budget (§7).
- Player state send: 30 Hz. Snapshots: 20 Hz. Clock sync: ping/pong to estimate offset for timers (power-up durations, round countdowns) so all HUD timers agree.

### 5.4 What is replicated and how

| Data | Authority | Method |
|---|---|---|
| Player transform, stance, ADS, sprint | Owning peer | Unreliable 30 Hz state → host → relayed in snapshots |
| Player points, health, perks, weapons, ammo, downed state | Host | Reliable events + included in full snapshot |
| Weapon fire (for visuals/audio on other clients) | Owning peer | Unreliable "fire burst" events (seed + count), others replay cosmetically |
| Hits/damage | Claim by shooter → host decides | Reliable RPC (batched per frame) |
| Projectiles (Ray Pistol, launchers) | Host spawns authoritative; shooter shows predicted visual immediately and reconciles | Spawn event + deterministic trajectory |
| Zombies | Host | Spawn/despawn reliable; state via snapshots |
| World (doors, barricades, power, traps, box, forge) | Host | Reliable events + full-state on join |
| RNG (box rolls, drops, spawns) | Host only | Never computed on clients |

---

## 6. Player and weapon architecture

### 6.1 Player (`core/player/`)

- `PlayerCharacter` (`CharacterBody3D`) composed of child components: `MotorComponent` (custom acceleration/friction, sprint, crouch, slide, jump, ledge-step), `CameraRig` (pitch/yaw, FOV, procedural bob/tilt, screen shake via trauma model), `HealthComponent` (HP, regen, damage events), `DownedComponent` (last stand, bleedout, revive), `Inventory` (2–3 weapon slots + lethal + tactical + melee), `PerkHolder`, `InteractionProbe` (raycast + area for prompts), `PlayerNetSync`.
- Local player is the only one that reads input. Remote players are "puppets": interpolated transform + third-person animation driven by replicated state.
- Input is gathered once per frame into a `PlayerInputFrame` struct; the motor consumes it in `_physics_process`. This makes bots and replays trivial (feed synthetic frames).

### 6.2 Weapons (`core/weapons/`)

- `WeaponDefinition` (Resource): id, display name, class, fire mode, RPM, damage (body/head/limb multipliers), damage falloff curve, penetration, magazine/reserve, reload timings (partial/empty, with "ammo-in" time), ADS time, spread (hip/ADS/move), recoil pattern (Curve2D + randomness), sway, viewmodel scene, world model, audio set, cost, `upgraded` → reference to an upgraded `WeaponDefinition`, optional `behavior_script`.
- `WeaponRuntime`: per-instance state (ammo, cooldowns, reload state machine, upgrade level). Runs on the owning peer for feel; mirrored on the host for validation.
- **Behaviors (strategy pattern):** `HitscanBehavior` (bullets with penetration), `PelletBehavior` (shotguns), `ProjectileBehavior` (grenade launcher, LAW, crossbow, Ray Pistol), `ChainLightningBehavior` (Lazarus Conduit), `MeleeBehavior`. Future-map wonder weapons add new behavior scripts without touching the runtime.
- **Viewmodel:** rendered in a separate camera layer with its own FOV (prevents clipping into walls). Animation = authored `AnimationPlayer` clips (reload, inspect, draw/holster, sprint pose) **plus procedural layers** (spring-based recoil kick, sway, bob, ADS blend, landing dip, sprint tilt). Procedural layers give feel even when keyframed animation is simple.
- **Feedback stack per shot:** muzzle flash (pooled), shell eject, tracer (configurable), impact VFX by surface material (`PhysicsMaterial` tags → impact library), decals (pooled, capped), hit marker (body/head/kill variants), hit sound (distinct headshot "tick"), zombie flinch/gib response, camera kick.

---

## 7. Enemy architecture (`core/enemies/`)

### 7.1 Composition

- `ZombieActor` scene = `ZombieSim` (host only: brain, health, hitzones, navigation agent) + `ZombieVisual` (all peers: skeleton, `AnimationTree`, audio emitter, VFX attach points, ragdoll).
- **Hitboxes:** bone-attached `Area3D`/shape colliders per zone (`head`, `neck`, `torso`, `arm_l/r`, `leg_l/r`) on a dedicated physics layer, present on every peer (clients raycast against their interpolated copies).
- `ZombieArchetype` (Resource): base model variants, speed tiers, attack damage/rate, health multiplier, hitzone multipliers, audio set, special-behavior script (Galvanic, Brute boss).

### 7.2 Brain (host)

Hierarchical state machine: `Spawning (rise/climb/vent) → SeekBarricade → TearBarricade → EnterPlayable → Pursue → Attack → Stagger → Electrocuted/Stunned → Crawler → Dying`. Plus special states: `Decoy-attracted`, `Riser-recycle`.

- **Targeting:** nearest *reachable* non-downed player by **path distance**, re-evaluated at 2 Hz with hysteresis to avoid flip-flopping.
- **Pathing:** `NavigationServer3D` queries; each zombie re-paths at most every 0.5–1.0 s (sooner if the target moved > 3 m), with a global **path-query budget** (e.g., ≤ 6 queries per physics frame) managed by `CrowdDirector`. Local steering = path following + RVO avoidance (navigation agent avoidance) + separation, with "surround" offsets so groups fan out around a player instead of conga-lining.
- **Navigation links:** windows (barricade climb), drop-downs, vents, ladder-like climbs, stair corners. Doors/debris toggle navigation regions or obstacles when purchased (zones become connected).
- **Stuck & far-zombie handling:** if no progress for 4 s or path distance > 60 m from every player for 8 s, the zombie is despawned and **re-queued** (does not count as a kill) so it can respawn near the players — this keeps rounds moving without unfair teleports.
- **Level of detail:** zombies far from all players think at reduced rates and skip IK/foot placement; visuals use animation LOD and frustum-based update throttling on each peer.

### 7.3 Spawning (`core/rounds/`)

- `RoundDirector` owns the round state machine (`Intermission → Active → Ending`), totals, health/speed curves, special-round scheduling.
- `SpawnDirector` picks spawners from **active zones** only (zones a player is in + adjacent zones defined in `MapDefinition`), excludes spawners within line-of-sight and < 8 m of any player, weights by distance band, and respects the alive cap. Spawners have types: `window` (with barricade), `riser` (ground), `vent`, `door_burst`, `special` (Galvanic energy rift).

---

## 8. World systems (`core/world/`, `core/machines/`, `core/interaction/`)

- **Interactable** component: prompt text, cost, conditions (`requires_power`, `requires_flag`, `per_player`), hold duration, cooldown, `use()` routed as a request RPC to the host, which validates (distance, cost, conditions) and executes. Every buyable thing (doors, wall-buys, perks, box, forge, traps, buildables, quest objects) uses it.
- **Zones:** `ZoneManager` holds the zone graph from `MapDefinition`; tracks which zones are unlocked and which contain players (via `Area3D` volumes); drives spawner activation, ambient audio sets, and reverb buses.
- **Doors/Debris:** purchased → animation + nav connection + zone unlock + event broadcast.
- **Barricades:** N planks (default 6), each with state; zombies tear one at a time; players rebuild via hold-interact (points capped per round).
- **PowerGrid:** named circuits (`main`, plus map-specific). Machines subscribe to power state.
- **Traps / hazards / traversal:** generic `Trap` (cost, duration, cooldown, kill volume, activation console), `Hazard` (explosive barrel, electrified water), `Traversal` base (gondola, freight lift) with map-specific subclasses.
- **Machines:** `PerkMachine` (definition-driven), `MysteryBox` (locations from map data, weighted table with conditions, relocation logic, fire-sale mode), `Forge` (upgrade sequence state machine, ownership lock).

---

## 9. Map module interface (expandability)

A map is a folder under `game/maps/<id>/` containing:

- `map_definition.tres` (`MapDefinition`): display name, preview art, zone graph (ids, adjacency, unlock links), spawn tables, starting zone, starting loadout overrides, box locations + starting location, box weapon pool overrides, wall-buy list, perk list, power circuits, ambient/music sets, special-round enemy, quest graph references.
- Root scene that instances zone scenes.
- `scripts/map_rules.gd` extending `core/MapRules` with hooks: `on_match_start`, `on_round_start(r)`, `on_power_changed`, `on_zone_unlocked`, `get_special_round_enemy(r)`, `modify_box_pool(pool)`, etc.
- Quest graphs (`QuestGraph` resources) and map-specific behaviors (traversal, traps, buildables, boss).

The main menu's map select lists every `MapDefinition` found under `maps/` (excluding `_test` in release). A new map should require **zero changes in `core/`** unless it introduces a genuinely new *generic* mechanic — in which case that mechanic is added to `core/` in generic form.

---

## 10. Quest system (Easter eggs & side quests) (`core/quest/`)

- `QuestGraph` resource = ordered/parallel `QuestStep`s, each with: id, prerequisites (other steps, power, round ≥ N, player count), `objective_script` (watches events), host-side state, replication flags, optional hint text (for debug/accessibility "story mode" later), and completion effects.
- Steps listen to `EventBus`-style *host* events (zombie killed at location with weapon X, item picked up, interact used, round started), so quests are integrated with normal gameplay instead of polling.
- Quest state is part of the full match snapshot (joiners see correct world state).
- Debug console can jump to any step (`ee_stage <id>`), essential for testing a 2-hour quest.

---

## 11. Content pipeline and art architecture

### 11.1 Look development

- **Renderer:** Forward+. Tonemapper: AgX or Filmic, tuned per area via `WorldEnvironment` overrides in zones.
- **Lighting language:** cold blue moonlight (directional, soft shadows, low intensity) + warm tungsten interiors (omni/spot, few shadow casters) + red emergency lamps + sickly green vesperite energy (emissive + glow). Volumetric fog everywhere with per-zone density; height fog outside; snow GPU particles attached to the camera (cheap, always local).
- **Materials:** a small library of shared stylized materials (`content/materials/`) using palette textures, trim sheets, vertex color grime, and a triplanar "snow accumulation" shader for exterior assets. One custom `zombie_skin` shader (subsurface-ish wrap lighting, rot masks, wound decals). One `energy` shader (scrolling noise, fresnel) for machines and wonder weapons.
- **Modular kit:** walls, floors, doors, windows (with barricade slots), stairs, railings, pipes, and trims on a **2 m / 0.5 m grid**, generated or authored in Blender (`tools/blender/kits/`) so greybox geometry can be swapped for final art piece-by-piece without moving gameplay markers.

### 11.2 Asset budgets

| Asset | Triangles (LOD0) | Textures |
|---|---|---|
| Viewmodel weapon | 6–12k | 1× 1024² atlas (+ emissive for wonder weapons) |
| World weapon / wall-buy | 1.5–3k | shared atlas |
| Zombie | 8–12k, 3 LODs | 1024² per variant, shared palette |
| Perk machine / box / forge | 4–10k | 1024² |
| Modular kit piece | 50–800 | trim sheets |
| Repo LFS budget | Target ≤ 1.5 GB total; prefer `.ogg` (q5) over `.wav`; compress textures at import | Human may need a paid LFS data pack or alternative storage (see risks). |

### 11.3 Animation

- Zombies and third-person players use a shared humanoid skeleton profile; animations are in-place (no root motion) so network-driven positions and animation never fight. Locomotion speed is matched by playback-rate scaling of walk/jog/run/sprint clips.
- Minimum zombie set: 3 walks, 2 jogs, 2 runs, 1 sprint, 3 attacks (swipe L/R, lunge), barricade tear + climb-through, ground rise, vent drop, 4 hit reactions (head, L/R, stomach), 3 deaths + ragdoll blend, crawler locomotion/attack, electrocuted loop, taunt/idle. Variety via randomized clip choice and playback-rate jitter.

---

## 12. Performance strategy

- Measure, don't guess: `tools/run_sim.sh perf_arena` spawns 32 zombies + 4 bot players and logs frame times (`Performance` monitors) to CSV; committed baseline numbers live in PROGRESS.md.
- Techniques: object pooling (zombies, VFX, decals, audio), occlusion culling (`OccluderInstance3D` per zone), visibility ranges/HLOD for exterior, limited shadow-casting lights (≤ 8 visible), animation LOD, staggered AI thinking, nav query budget, physics layers kept minimal, GPU particles only, per-zone `WorldEnvironment` tuning, quality presets.
- **Escape hatch:** if profiling shows GDScript AI exceeding 1.5 ms with 32 zombies, move the hot loop (steering/separation) to a GDExtension in C++. This is planned as an *optional* checkpoint in Step 5 and Step 16, not a default.

---

## 13. Testing architecture

| Layer | What | When |
|---|---|---|
| Static | `gdlint`, `gdformat --check`, `core→maps` dependency check, typed-GDScript warnings as errors | Every commit (`tools/check.sh`) |
| Unit | Formulas (zombie count/health/speed), PointsLedger, box weighted tables, perk effects math, weapon damage falloff, quest step logic | Every commit |
| Integration (headless) | Load a scene, run N simulated seconds: nav reachability from every spawner to every zone, round progression with auto-kill, purchase flows, door → zone activation, box relocation | Every step completion + CI |
| Net (headless) | Host + 3 clients over loopback with NetSim (100 ms, 2% loss): join, buy, revive, round sync, late join, reconnect | Steps that touch networked state |
| Soak | Bot players with simple behaviors play to round 30/50 at accelerated time; asserts no errors, no leaked nodes, stable memory | Steps 6, 8, 12, 16 |
| Visual | Scripted camera "shots" captured to PNG for review (`tools/screenshot.sh`) | Art-related steps |
| Human playtest | Feel, fun, visuals on real GPU, real internet co-op with friends | Marked "HUMAN" in acceptance criteria |

---

## 14. Decision log

| # | Date | Decision | Reason |
|---|---|---|---|
| D-001 | 2026-11-11 | Godot 4 (pinned latest stable), typed GDScript | §2.1–2.2 |
| D-002 | 2026-11-11 | Listen-server host authority, owner-authoritative movement, favor-the-shooter hits | §5.1 — co-op among friends; maximizes feel, minimizes netcode risk |
| D-003 | 2026-11-11 | Solo runs through the same host code path | Prevents co-op from being an afterthought |
| D-004 | 2026-11-11 | No host migration | Complexity vs. benefit; documented limitation |
| D-005 | 2026-11-11 | Direct-IP ENet first, Steam lobbies as additive transport | Testable in container; no paid dependency |
| D-006 | 2026-11-11 | Original names for branded Zombies elements (see GAME_DESIGN §1.3) | Trademark safety and a distinct identity; mechanics unchanged |
| D-007 | 2026-11-11 | In-place animation, no root motion | Network determinism, simpler blending |
| D-008 | 2026-11-11 | `core/` ↔ `maps/` hard boundary | Future maps without rewrites |

| D-009 | 2026-11-11 | Pinned Godot **4.7.2-stable** (`tools/godot_version.txt`), GUT 9.7.1, gdtoolkit 4.5.0 (line length 120) | Step 1: latest stable at the time; one version everywhere (local, CI, agents) |
| D-010 | 2026-11-11 | All game traffic goes through `Net.send_reliable` (one `@rpc` message channel with registered handlers) and `Net.send_unreliable` (`send_bytes` streams with a 1-byte stream id). NetSim shapes these at the sender. | Lets NetSim delay/drop *everything* without wrapping the `MultiplayerPeer`; keeps transports swappable |
| D-011 | 2026-11-11 | Snapshot entries carry their own host-clock stamp; interpolation playback is `arrival offset − delay` (100 ms base, +2×jitter, capped +100 ms) | Relayed client positions are not mis-stamped; delay is independent of latency (Step 1 test: max error 0.011–0.016 m at 100±20 ms, 2% loss) |
| D-012 | 2026-11-11 | `core/autoload/input_defaults.gd` is the source of truth for the input map; `tools/gen_input_map.sh` writes it into `project.godot`; a unit test detects drift | Text-friendly bindings (`key:W`, `joy:0`, `axis:1:-1`) that Config persists for rebinding |
| D-013 | 2026-11-11 | Container screenshots use `--rendering-driver opengl3` under xvfb when no Vulkan ICD exists (no lavapipe in the image) | Plan's documented fallback; screenshots are for composition/regression only |
| D-014 | 2026-11-11 | Host-loss detection: ENet peer timeout 1–3 s plus a 4 s application-level host-silence timeout (pings every 0.5 s) | Client returns to the menu ~2 s after the host dies instead of ENet's ~30 s default |
| D-015 | 2026-11-11 | `--profile=<name>` selects separate `user://settings_<name>.cfg` and `identity_<name>.cfg` | Several local instances (co-op tests) need distinct `player_uid`s |

| D-016 | 2026-11-11 | Host movement validation is a **distance budget** (`MovementValidator`): horizontal travel ≤ 10.5 m/s × sender-time elapsed + 1.5 m slack (no banked credit), same for upward travel; single jumps > 4 m (+ free-fall allowance) are corrected immediately. Corrections are reliable `_player_correct` messages carrying a sequence number; owner states stamped with an older sequence are ignored until the owner adopts the correction. Host-initiated moves (respawn, `tp`) use the same path | Uses the sender's clock stamps, so latency, jitter and loss cause no false positives (0 corrections in the 100 ms client course run); 3× speed hack corrected within ~0.2 s |
| D-017 | 2026-11-11 | Player health is host-authoritative with event replication (`_player_health` on damage/heal/downed); every peer runs the same deterministic regen tick between events. Fall damage is an owner claim (`_player_fall`, height) that the host clamps and applies | No periodic health stream; HUDs agree without bandwidth |
| D-018 | 2026-11-11 | Look input is applied per **render** frame to a top-level camera placed from the body's interpolated transform; body yaw follows at the physics tick | Lowest look latency with physics interpolation enabled |
| D-019 | 2026-11-11 | Integration tests run headless with `--fixed-fps 60` (`tools/run_tests.sh integration`) | Deterministic 1/60 s frames, much faster than real time (10k-frame soak in ~3 s) |
| D-020 | 2026-11-11 | Moving platforms on test maps are local per peer (shared clock / local rider sensor); host-driven traversal machines (gondola, freight lift) come in Step 8 | Movement is owner-authoritative, so local platforms carry the owner correctly; validator budget includes platform speed headroom |

*(Agents append new rows; never delete old ones — supersede them.)*
