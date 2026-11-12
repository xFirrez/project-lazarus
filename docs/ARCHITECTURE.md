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
│   ├── blender/               # bpy generator scripts for modular kits, props, characters, weapons (Step 4)
│   ├── lookdev/               # look-dev scene generator (Step 4)
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
    │   ├── vfx/               # pooled effects, decals, impact library, screen effects, camera snow
    │   ├── render/            # QualityPreset schema (applied by the Graphics autoload) (Step 4)
    │   ├── art/               # import-time scripts (post_import.gd material remap) (Step 4)
    │   ├── ui/                # HUD, menus, lobby, settings, game-over (theme + widgets)
    │   └── debug/             # console, overlays, perf HUD, cheats (dev builds only)
    ├── content/               # SHARED data & assets usable by any map
    │   ├── weapons/<id>/      # definition .tres, viewmodel/worldmodel scenes, audio, textures
    │   ├── perks/<id>/        # definition .tres, machine scene, jingle, icon
    │   ├── powerups/  enemies/  characters/  materials/  shaders/  audio/  ui/
    │   ├── kits/<kit>/        # scripted modular kit GLBs + kit_manifest.json (Step 4)
    │   ├── props/<id>/        # prop GLBs (Step 4)
    │   ├── environments/      # WorldEnvironment presets (exterior_storm, interior_warm, underground, reactor)
    │   ├── quality/           # QualityPreset .tres (low, medium, high, ultra)
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
| `Graphics` | (Step 4) Applies the video `QualityPreset` at runtime to the viewport, shadows, every `WorldEnvironment`, the shadow-light budget and particle density (D-029). |
| `Audio` | Bus management, pooled one-shots, music director, VO queue. |
| `Pools` | Object pools for VFX, decals, projectiles, ragdoll gibs, audio players. |
| `Debug` | Console, command registry, overlays (dev builds; stripped/disabled in release). |
| `Session` | (Step 7) Co-op session layer above `Net`: `LobbyState` roster for the whole session (slots, unique characters, ready, chat, host settings, countdown), join policy (`Net.join_filter`), return to lobby (D-046). |

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

| D-021 | 2026-11-11 | Weapon protocol (`WeaponSync`): owners send reliable shot claims batched per physics frame (`_wshots`: weapon, seq, sender host-clock time, origin, aim, spread, seed, hits as [target, zone, distance, penetration index, props]) — **no damage amounts**; the host validates (`HitValidator`), recomputes damage from the `WeaponDefinition` and applies it through `TargetRegistry`, then relays an unreliable fire burst (seed + aim) that observers replay cosmetically. The host's own shots skip validation (it is the authority) | Favor-the-shooter with nothing for a client to inflate; one code path for solo, host and clients |
| D-022 | 2026-11-11 | Rate validation = sender-stamped spacing ≥ 60/RPM − max(15%, 35 ms) plus an arrival-time credit bucket (0.6 s of shots, min 3); hits also check alive target, range ≤ max_range + 2.5 m from the shooter's last validated position, penetration index, rough world LOS (thin props pass). Ammo is mirrored on the host from shot claims and ammo-in reports (mag + reserve may never grow) | No false positives at 100 ms ±20 ms, 2% loss; forged rate/range/dead claims rejected (net test) |
| D-023 | 2026-11-11 | Map-placed `HitTarget`s get ids from a tree-order scan on every peer (`TargetRegistry.scan`), no messages; dynamic targets (zombies) will use host-assigned ids (Step 5 entity registry). Health changes broadcast reliably; late joiners get `_targets_full` | Deterministic map build on all peers |
| D-024 | 2026-11-11 | First-person weapons render in a transparent `SubViewport` (sharing the `World3D`) whose camera sees only render layer 2 "viewmodel", composited below the HUD; the world camera culls layer 2. ADS alignment puts the gun's `Sight` marker on the camera axis | Plan scope 4: own FOV, never clips into walls (visual test) |
| D-025 | 2026-11-11 | Shot feedback uses fixed-capacity recycling rings (`FxRing`: decals 128, impacts 32, shells 40, tracers 32, flashes 12) instead of grow-on-demand pools | Hard caps → flat memory under sustained fire (AC-3.6) |
| D-026 | 2026-11-11 | Frags are simulated on every peer from the throw (origin, velocity, fuse left); only the host's copy explodes, applies splash and broadcasts `_wexplode` | Physics-based bounce stays responsive locally; damage stays host-authoritative |

| D-027 | 2026-11-11 | Art assets are **generated by scripts** (`tools/blender/*.py`, Blender 5.3 via the `bpy` pip module in the container, or any Blender 4.2+ binary) and committed as `.glb`; Godot import defaults run `core/art/post_import.gd` (material remap `M_<id>` → `content/materials/<id>.tres`, `surface` glTF extras → collider meta). Kit pieces / props use world-space triplanar shading (no UVs) | Reproducible, license-clean assets without account-gated downloads; one material library defines the look |
| D-028 | 2026-11-11 | Humanoid skeletons use `SkeletonProfileHumanoid` bone names; every model and animation library imports through `content/characters/humanoid_bone_map.tres` (Godot retargeting, `%GeneralSkeleton`). Animation libraries import as `AnimationLibrary` resources and are shared by model scenes (`ZombieModel`) | Any library (scripted, CC0, Mixamo) plays on any humanoid model without per-model clip copies |
| D-029 | 2026-11-11 | Video quality = `QualityPreset` resources applied at runtime by the new **`Graphics` autoload** (viewport scaling/AA/LOD, shadow atlases, SSAO/glow/volumetric fog gated per WorldEnvironment, shadow-casting light budget via group `shadow_light` + `shadow_priority` meta, particle density via group `density_scaled`, camera far). Only the renderer needs a restart | AC-4.6; budgets enforced in one place (ARCHITECTURE §12: ≤ 8 shadow lights on High) |
| D-030 | 2026-11-11 | Container screenshots now use **Forward+ on lavapipe** (Mesa software Vulkan, `apt-get install mesa-vulkan-drivers`); opengl3 stays the fallback when no ICD exists. Supersedes D-013 for containers that have it | Real renderer path (volumetric fog, SSAO, glow) in visual tests; resolves the "Compatibility only" caveat of I-004 |
| D-031 | 2026-11-11 | The viewmodel viewport environment gets a neutral procedural sky used only for reflections (`REFLECTION_SOURCE_SKY`, background stays transparent) | Metallic authored weapons rendered black in Forward+ without anything to reflect (I-004) |
| D-032 | 2026-11-11 | `WeaponDefinition.world_scene` (third-person/world model, needs `Muzzle`) alongside `viewmodel_scene`; authored viewmodels are moved to render layer 2 on instancing | First hero model (M1911) for both views without per-weapon code |

| D-033 | 2026-11-11 | Zombies are **navmesh-constrained kinematic actors** on the host: `ZombieSim` (RefCounted brain) moves along `NavigationServer3D.query_path` corners and re-projects onto the navmesh (`map_get_closest_point`) every tick; no `CharacterBody3D`/`move_and_slide` per zombie. A kinematic capsule (`AnimatableBody3D`, layer 4) blocks players on every peer | Cheapest robust movement for 32+ zombies in GDScript (AI+nav 0.7–0.9 ms avg at 32); zombies can't fall through gaps or wedge on geometry; matches the in-place animation rule (D-007) |
| D-034 | 2026-11-11 | **CrowdDirector** owns every brain: path queries FIFO with a hard budget of 6 per physics frame (target selection draws from the same budget), staggered think at 0.1 / 0.25 / 0.5 s by distance LOD (20 / 40 m), surround slots (8 inner at 1.05 m + 12 outer at 1.9 m per target, nearest-bearing assignment at 5 Hz), separation from a 1 m spatial hash. Custom separation + slots replace `NavigationAgent3D` RVO avoidance | RVO agents are asynchronous (results a frame later) and cost per agent; separation + slot assignment produced the surround behaviour in tests (14 runners all within 2.4 m in rings) with deterministic per-frame cost. RVO can be added behind the same director if crowds conga in playtests |
| D-035 | 2026-11-11 | Navigation links are `TraversalLink` (`NavigationLink3D` subclass with an `action`: WINDOW / DROP / VENT / JUMP); the brain detects a link from the path metadata (owner id of the entry point) and runs the traversal. Windows reference a `Barricade` (one occupant tears, others WAIT 1.8 m away). Doors (`NavDoor`) toggle their collider and re-bake the owning `NavigationRegion3D` on a thread (host only) | Generic hooks maps can place without core changes; re-baking keeps one region per area and exact geometry (Step 8 splits Vesper Peak into per-zone regions so a door re-bakes only its zone) |
| D-036 | 2026-11-11 | Zombie replication (`ZombieSync`): u16 NetIds, reliable `_zspawn` / `_zdie` (gib mask + impulse direction) / `_zdespawn` / `_zfull` (late join), 20 Hz unreliable `ZombieSnapshot` stream 19 (15 B per zombie: 2 cm s16 position, u16 yaw, tier+action, u16 action start tick, health bucket, flags). Zombies register in `TargetRegistry` as `10000 + NetId`; dead zombies are unregistered (corpses aren't targets). Clients interpolate with the player `InterpolationBuffer` at the physics tick, so bone-attached hurtboxes match what the shooter sees | 9.4–9.5 KB/s for 32 zombies at 100 ms / 2% loss; 77/77 client hit claims on moving zombies accepted; corpse ids never collide with new spawns |
| D-037 | 2026-11-11 | `WorldSync` (per match) gives barricades and nav doors tree-order ids (like D-023) and replicates `_barricade` / `_door` events + `_world_full` on join | Same zero-message id scheme as map targets; later steps add traps, power and the box here |
| D-038 | 2026-11-11 | Zombie animation is an `AnimationTree` built in code per zombie (locomotion BlendSpace1D idle/walk/run with playback-rate matching → mode Transition loco/crawl/dead → action OneShot seeked to the replicated action start → hit-react OneShot filtered to the upper body). Hit reacts **blend** over the base pose instead of an additive layer; head look = `LookAtModifier3D` (≤ 15 m); gibs = a `GibModifier` (SkeletonModifier3D) collapsing bones; animation LOD advances the tree every 1 / 2 / 4 frames at < 25 / < 50 / ≥ 50 m | The scripted clips are full-body poses, not additive; a filtered blend reads correctly without authoring additive clips. Code-built trees stay in sync with the shared library |
| D-039 | 2026-11-11 | Ragdolls: `PhysicalBoneSimulator3D` + 11 `PhysicalBone3D` capsules built on death; `ZombieFx` allows **6 simulating**; a 7th freezes the oldest (zero velocity, no gravity, heavy damping → bodies sleep) and corpses sink and free after 5 + 1.5 s. Each peer decides ragdoll vs. death animation from its own pool | Physical bones need no authoring; freezing in place avoids the pose pop of stopping the simulator; local pools keep the host's budget independent of clients |
| D-040 | 2026-11-12 | **Survival systems per match** (Step 6): `ZoneManager` (zone graph from `MapDefinition.zones` + pure-math `ZoneVolume` boxes), `PointsLedger` (host balances + stats, earns from `TargetRegistry.target_damaged`), `InteractionSystem` (tree-order `Interactable` ids, local probe/hold → `_interact` → host validates distance/conditions/cost → executes → `_interact_r`), `DownedSystem`, `RoundDirector`, `SpawnDirector` (survival maps only), `MapRules` from `MapDefinition.rules_script` | Request→validate→execute with one host queue makes double-spending impossible; same zero-message id scheme as D-023/D-037 |
| D-041 | 2026-11-12 | Host **bot players** (`PlayerSync.add_bot`, ids ≥ 2^30, `PlayerCharacter.is_bot`) are host-simulated avatars driven by `SurvivalBot`; they are *not* replicated to clients and are test tooling only (soak sims, `bots` console command) | Lets one headless process run a 4-player soak; real 4-peer runs are covered by `run_coop_local.sh` |
| D-042 | 2026-11-12 | Last stand reuses the loadout: `WeaponSync.host_enter_last_stand` switches to the best owned pistol (+2 mags) or appends a temporary M1911, restored on revive; bleedout resets the loadout to `starting_weapons` | Keeps the other weapons' runtime ammo intact on the owner (`WeaponInventory.set_loadout` keeps runtimes) |
| D-043 | 2026-11-12 | Spawn fairness check = ray (world layer) from each non-spectating player's eye (1.6 m) to the spawner (+1.2 m) and ≥ 8 m distance; risers ignore LOS beyond 12 m. Window spawners hug the outer wall beside their window so they stay out of sight | Deterministic, cheap, and makes AC-6.3 assertable on every spawn |
| D-044 | 2026-11-12 | Player-only clip collision layer 9 (`player_clip`) in window openings: in the player's mask and the motor's `WORLD_MASK`, not in navmesh parsing or bullet masks | Players can't climb out through an open window, while bullets and zombie links still pass |
| D-045 | 2026-11-12 | **Transports (Step 7):** `EnetTransport` direct IP stays the always-available path, plus a best-effort threaded `UpnpMapper` (menu hosting) and a documented VPN (Tailscale) route (docs/NETWORKING.md). `SteamTransport` targets the **GodotSteam GDExtension** (App ID 480 in dev, friends-only lobby, overlay invites, lobby metadata map/players/round/version) but calls it only dynamically (`Engine.get_singleton("Steam")`, `ClassDB.instantiate("SteamMultiplayerPeer")`); the addon is **not vendored** | No Steam client / GodotSteam build for the pinned 4.7.2 can be verified in the cloud container; dynamic calls keep the project compiling without it, and the fallback plan of the step is fully implemented. Init state lives in Engine meta (a `static var` on the transport leaked its GDScript at import) |
| D-046 | 2026-11-12 | **Session autoload + LobbyState** own the roster for the whole session (lobby *and* match): `player_uid`, name, character (unique), ready; the host broadcasts `_lobby` on every change. `Net.join_filter` refuses joins (lobby full, late join off) before any system sees the peer (`_rejected` [reason] then kick). CLI `--host` stays a dev quick-start (match starts at once); the menu and `--host --lobby` use the lobby. A rejoin with a uid that is still connected **replaces the stale connection** (`Net.host_drop_peer`, which also notifies SceneMultiplayer) | Characters and identity are needed in the match (models, colours, reconnect), so the roster must outlive the lobby screen; filtering in the hello handler keeps refused peers out of every match system. A crashed client relaunches faster than ENet's 3 s timeout |
| D-047 | 2026-11-12 | **MatchSession** (per match, added first so its `peer_left` capture sees the player's state before other systems drop it): scene-ready gate (`RoundDirector.hold` until every peer sends `_scene_ready`, 30 s timeout), late join (DownedSystem state **WAITING** = spectate until the next round start; points via `PointsRules.late_join_points`; admission deferred until every system sent its join snapshot, ended by `_join_done`), reconnect (`retained[uid]` = points, stats, loadout + host-mirrored ammo, perks unless downed, character; restored with `PointsLedger.host_transfer` / `WeaponSync.host_import`; the character is reserved in `LobbyState.reserved`), generic match flags (`_flag`, `_flags_full`) for power / box / quest state | One place owns the §13 rules; existing per-system join snapshots stay as they are; WAITING reuses the bled-out spectate + round-start respawn path |
| D-048 | 2026-11-12 | **State-hash convergence:** `MatchSession.state_digest()` = sorted lines (round, unlocked zones, door + barricade states, flags, per-player points + sorted weapon ids/lethals (+ perks), alive zombies), hashed; each client reports `_hash_report` when it enters the intermission, the host compares with its own digest taken at the same event. Reliable messages share one ordered channel, so both digests describe the same event prefix | Built-in desync detection (console `session` / `state_hash`) and the AC-7.1 test oracle without extra replication |
| D-049 | 2026-11-12 | **Characters:** `CharacterDefinition` resources (`content/characters/<id>/`: names, bio, identification colour, sleeve / skin tint, model scene). Models + a survivor animation library are generated by `tools/blender/characters/build_survivors.py` (reusing the zombie rig helpers) and retargeted through the humanoid BoneMap. `SurvivorModel` builds an AnimationTree in code: locomotion Transition → upper-body Blend2 (spine-up filter) with the weapon-class hold → fire / action OneShots (relayed shots, new `_wrl` reload-start relay); the third-person weapon follows the right hand. First-person arms are re-tinted (authored `ArmsMesh`) or placeholder primitives (greybox guns) | Same pipeline and retargeting as the zombies; state is derived from what is already replicated, so no new per-frame traffic |
| D-050 | 2026-11-12 | **Pings:** the pinger classifies locally (ray: zombie hurtbox → zombie, interactable within 2.5 m → item / machine via `Interactable.ping_kind`, else location), the host validates (rate 1 / 0.6 s, ≤ 90 m) and relays `_ping`; one marker per player (Label3D through walls + ring, follows a pinged zombie) and an HUD edge indicator | Host relay keeps one authority for rate limiting; classification needs the pinger's view |
| D-051 | 2026-11-12 | **Tiled navigation (`NavTiles`):** large maps bake one `NavigationRegion3D` per tile AABB (Vesper Peak: 28 zone-area tiles) from ONE parse of the map's static colliders. Each tile's `filter_baking_aabb` is its box grown by `border_size` (≈ agent radius, x/z only) so Recast trims the border back and the tile's polygons end exactly on its AABB planes; neighbours join through map edge connections. Doors re-bake only the tiles their box touches (synchronous: ~10–60 ms on the host; threaded bakes never reached the map under `--fixed-fps` headless sims). `edge_max_length` 12 m keeps polygons small (Godot's polygon A* detoured through huge corridor polygons). Clients never bake | A whole-map re-bake per door would cost seconds; tiles keep door purchases cheap and the 0.3 s load bake bounded |
| D-052 | 2026-11-12 | **Traversal machines (`TraversalMachine`):** gondola / freight lift are `AnimatableBody3D`s on the player-clip layer whose position is a pure function of the replicated ride state (`MatchSession` flag `machine.<id>` = [from_station, depart_time]) and the shared host clock, so every peer moves an identical copy and owner-authoritative riders are carried by `CharacterBody3D` platform support. The host validator subtracts the machine's displacement over each state interval (`validate(..., carry)`); cabin gates are solid while moving, station gates unless docked. Zombies can't board (no navmesh on the clip layer) except via `TraversalLink.Action.LIFT` links (enabled only while docked at their station; `ZombieSim` boards, rides `position_at`, steps off, re-queues after 20 s waiting). Chute = host-side trigger + validator-authorised teleports through a sealed tube | Supersedes D-020 for map machines; deterministic motion needs no per-frame network traffic and keeps riders at 0 corrections at 100 ms |
| D-053 | 2026-11-12 | **Vesper Peak greybox is built in code** by one `VesperZone` script per zone scene (`maps/vesper_peak/zones/Zxx_*.tscn`) using box / wall-with-openings / ramp / corridor / stair helpers and the Step 4 **kit materials** (not kit meshes — gameplay dimensions aren't on the 2 m grid). Each zone owns `Geometry/ Gameplay/ Lighting/ Audio/` and reports its nav tile boxes; markers are typed `MapMarker`s listed in `markers_manifest.json`. Map datum: y 0 = Arrival Station floor (+28 m real) | Fast iteration on dimensions/flow (the Step 8 risk), deterministic tree order for id scans; Step 13 replaces meshes without moving `Gameplay/` |
| D-054 | 2026-11-12 | **Power** = `MatchSession` flag `power.<circuit>` (`Power` helper, `PowerSwitch` interactable, `Interactable.requires_power` checked by the host). `PoweredLight`s ramp up after a per-zone cascade delay on every peer; late joiners get the flag in the join snapshot and light instantly. `MatchSession.flag_changed` signal added; map nodes that need the session hook up via `_on_match_setup(match)` (`Match.setup` propagates it once the session exists) | Shared map state already rides the flags + state hash (Step 7); no new message types |
| D-055 | 2026-11-12 | **Map validation definitions (`nav_validate`):** player-standable = downward-ray floors on a 0.5 m grid with ≥ 1.1 m headroom and capsule support, flood-filled from the spawn with steps ≤ 0.35 m, mantles ≤ 1.2 m, clear falls, moves blocked by world + player-clip geometry, machines/chute as portals. AC-8.2 holds when every reachable cell has navigation within zombie reach (1.6 m horizontal / 1.4 m vertical) that paths to the spawn, every spawner paths to its own + adjacent zones, tiles don't overlap, and no unreachable nav island is player-reachable and out of reach (decor tops are reported, not failed) | Turns "no unreachable player-standable regions / no islands" into a checkable rule; caught 9 real layout bugs this step |
| D-056 | 2026-11-12 | **CrowdDirector on tiled maps:** `snap()` queries only the tiles around the zombie (`region_get_closest_point`) instead of the whole map, and `_serve_paths` stops after 0.4 ms (≥ 1 query) besides the 6-query budget; random spawner picks (`pick_spawner`) are limited to the active zones on zoned maps | The map-wide closest-point query scales with every polygon: 2.7 → ~1.35 ms avg AI on Vesper Peak |
| D-057 | 2026-11-12 | **Projectiles (`Projectile`, Step 9A):** deterministic kinematic flight (no rigid body) with a swept ray per physics tick against world (layer 1) + hurtboxes (layer 3); kinds `rocket` (explode on contact), `grenade` (bounce with `projectile_bounce`, explode on a zombie or at the fuse), `bolt` (stick to the first zombie / wall, follow the hurtbox, explode after `fuse_time`). The shooter spawns a predicted copy, the host spawns the authoritative one when it accepts the shot claim (direction = seeded spread of the claim) and relays `_wproj`; only the host's copy emits `struck` (direct `damage`) and `detonated` (splash, `_wpexplode`) | Same physics on every peer from the same (origin, velocity), no per-tick projectile replication; host authority over every hit |
| D-058 | 2026-11-12 | **One explosion path:** `WeaponSync.host_explode(def, owner, pos)` applies splash (centre → edge linear over `splash_radius`, line of sight from the blast) to every live HitTarget and own-explosive damage `DamageModel.self_damage` (≤ `self_damage_max` = 60, linear to 0 at the radius, GAME_DESIGN §3.2) to the owner only; used by frags, decoys, launchers, bolts and tripmines. Launcher splash edges are 0 ("falloff splash") | Consistent numbers, one place to tune / test (AC-9.3) |
| D-059 | 2026-11-12 | **Equipment in the host loadout:** `WeaponSync` loadouts carry `melee` (knife / Ice Axe), `tactical` + `tac_n` (Drummer Decoy ×3), `placeable` + `place_n` (tripmines, 2 per round refilled at round start, `place_limit` 4 placed); `_wloadout` = [peer, ids, current, lethal, melee, tactical, tac_n, placeable, place_n]; equipment goes through `host_give` (wall-buys, box) but never takes a primary slot. Decoys reuse the frag throw path (`_wtac`); tripmines are `Tripmine` nodes (`_wmine`, `_wmine_r`, `_wmines_full` late join) whose triggers are checked on the host | Keeps ownership, reconnect export and the state hash (melee is in the digest) in one place |
| D-060 | 2026-11-12 | **Zombie attractors:** `CrowdDirector.add_attractor(node, radius)`; `ZombieSim._select_target` prefers the closest live attractor within `radius` by PATH distance over every player and never attacks it; freed attractors are pruned and their chasers re-target. Decoys register on the host when thrown | Generic hook for Step 11 relays (weaker radius) and the upgraded crossbow |
| D-061 | 2026-11-12 | **Relic Box (`RelicBoxSystem` + `RelicBox`):** one `RelicBox` interactable per `MapMarker` of kind `box` (sorted by id, created before the interaction scan); location / arrival time / Fire Sale end are `MatchSession` flags (`box_location`, `box_arrive_at`, `fire_sale_until`) so late join + the state hash cover them; a spin is one reliable `_box_spin` [loc, spinner, result, seed, start]; every phase (SPINNING 4.5 s → OFFER 12 s / LEAVING for the doll) is a pure function of host time, and the carousel is a seeded decelerating sequence that lands on the result on every peer. Pure roll logic in `RelicBoxRoller` (weights, eligibility, doll ramp, relocation, wonder bad-luck); pool + rules in `content/box/relic_box_pool.tres` (`RelicBoxPool`) | Deterministic presentation without streaming state; statistics testable without a scene (AC-9.4, 9.5) |
| D-062 | 2026-11-12 | **Player stats as a modifier stack:** `PlayerStats` (on `PlayerCharacter.perk_holder`) folds `StatModifier`s (SET → MUL → ADD) from named sources (one per perk) over each component's base value; components read it at use time (motor speed / sprint, runtime reload / fire rate / hip spread, health max, revive time, weapon slots, host damage factors). Every peer holds the same stack for every player because perk lists replicate, so owner prediction and host validation agree; the validator keeps a lowered fire rate for a 1 s grace | One generic hook point for perks now and Forge / EE modifiers later; no per-perk branches in gameplay code |
| D-063 | 2026-11-12 | **PerkSystem:** perk machines are created on the `perk` markers before the interaction scan (tree-order ids, like D-061); purchase = validate (owned / drinking / cap / Second Wind uses) → pay → `_perk_drink` → host grants after 3 s (`_perks` [peer, ids]); down = `host_on_downed` before last stand (Pack Mule trim after the stat change); Second Wind solo uses are a MatchSession flag; perk lists ride `_perks_full` on join, the state digest (`perks:`) and the reconnect record (restored before the loadout) | Host authority, late join + hash for free |
| D-064 | 2026-11-12 | **PowerUpSystem:** the pure `PowerUpDropper` (score counter, growing threshold, round cap, bag + conditions) is fed by `PointsLedger.zombie_points` (base points, kind; TRAP / NUKE / DEBUG kinds never count); drops spawn only where the navmesh snap is close and a living player has a complete path; timed effects are MatchSession host-time flags (`pu.<type>`, Fire Sale uses `fire_sale_until`) so countdowns derive from the synced clock and ride late join / hash; Insta-Kill via `TargetRegistry.damage_modifier`, Double Points via `PointsLedger.earn_multiplier`, Nuke kills as `DamageInfo.Kind.NUKE` (count for the round, no points / drops); `pu.free_upgrade` flag is the Step 11 Forge hook | Deterministic presentation, testable drop statistics without a scene |
| D-065 | 2026-11-12 | **Background audio synthesis:** placeholder sets that take ~1 s of GDScript (perk jingles, announcer voices) are built on `WorkerThreadPool` and registered on the main thread when ready; `Audio.track_task` / `wait_for_synthesis` join them at shutdown | Synchronous synthesis at match setup stalled a joining client ~2 s and broke the box / perks net tests |
| D-066 | 2026-11-12 | **Forge upgrades are derived data:** every upgraded weapon is `content/weapons/<base>/<base>_up.tres` generated by `tools/gen_upgrades.py` from `tests/data/upgrades_spec.json` (= GAME_DESIGN §9.3: base copy, damage / splash ×2, table mag / reserve, name, `base_id`, `camo`, behavior fields); `WeaponCatalog.upgrade_of / base_of / can_upgrade` resolve them; the alt-fire launcher is a hidden attachment def (`attachment_of`). Behavior changes are generic `WeaponDefinition` fields (`dual_wield`, `alt_fire_id`, `impact_splash` hit / headshot / headshot_kill, `slow_*`, `burn_*`, `cluster_*`, `recoil_scale`, `thermal_scope`, `tracer_color`; Lure bolts reuse `attract_radius`) applied by the host in `WeaponSync` (`_host_upgrade_on_hit`, `host_splash` + `_wsplash`, `_host_cluster`, `Projectile.stuck_to`). Holding the upgrade counts as owning the base (box eligibility); the camo is a ShaderMaterial overlay (`WeaponCamo`) cleared on tree exit | One table drives data + tests (AC-11.2 / 11.3); no per-weapon code paths |
| D-067 | 2026-11-12 | **ForgeSystem:** `LazarusForge` interactables on `forge` markers (created before the interaction scan); one job per forge `[peer, base, up, start]` sent as `_forge_start` / `_forge_end` (+ `_forge_full` on join); phase FORGING 5 s → OFFER 15 s is a pure function of host time; insert = `WeaponSync.host_take_weapon` + optional `PowerUpSystem.host_consume_free_upgrade` (cost 0 while the token is pending, Fire Sale ignored), take = `host_give` (owner only). Dormant until the MatchSession flag `forge_unlocked`, which the map sets | Same deterministic pattern as the box (D-061); the map decides what unlocks it |
| D-068 | 2026-11-12 | **RelaySystem:** `ResonanceRelay` interactables on `relay` markers (the marker's `zone` is the defend zone); state / defended seconds (0.5 s steps) / paused are MatchSession flags `relay.<id>`, `.p`, `.paused` and `relays_done` (late join + hash). Progress runs only while a standing player is in the zone; the lure is a CrowdDirector attractor with meta `attract_weak` (ZombieSim: a weak lure loses to a player whose path is shorter than the lure's + 4 m) removed while paused. All done → `MapRules.on_relays_complete()` (new hook; Vesper extends the bridge NavDoors and sets `forge_unlocked`); `ReactorState` (map node) derives the reactor stage from the flags | Generic hold-and-defend objective in core; map-specific consequences stay in the map |
| D-069 | 2026-11-12 | **Traps:** `TrapDefinition` is map data (`maps/<map>/traps/<tn>.tres`: cost, power, active / cooldown, player DPS, box or ring-sector area, effect preset); `TrapSystem` pairs `<Tn>_Console` / `<Tn>_<Area>` markers into a `Trap` lever; phase = host-time flags `trap.<Tn>.until` / `.ready` / `.by`; the host ticks at 10 Hz: zombies inside die (`DamageInfo.Kind.TRAP`, 50 points to the activator via `PointsRules`, never drops), trap-resistant / boss archetypes lose 50 % max HP / s, standing players take `player_dps` | Generic rules from GAME_DESIGN §12 with per-map data |
| D-070 | 2026-11-12 | **StatusEffects + hazards:** a host node keeps per-zombie SLOW / BURN / FREEZE timers, scales `ZombieSim.speed_scale` / sets `frozen`, applies burn ticks through the TargetRegistry and drives the replicated `ZombieActor` flags BURNING / FROZEN (visual overlays everywhere); a frozen zombie shatters on any non-trap damage, a player touch or the freeze's end. `HazardSystem` builds drums (`ExplosiveDrum`) and icicles (`IcicleCluster`) as HitTargets BEFORE the target scan (tree-order ids → hits / deaths / `host_revive_target` replicate) and the `LabBreaker` interactable (flags `hazard.H3.*`); respawns on `RoundDirector.round_started` | Reuses target replication; no new entity sync |
| D-071 | 2026-11-12 | **ZombieBehavior:** an archetype's special brain (`behavior_script`) is a RefCounted created per zombie on the host; `think` / `move` hooks may take over a tick, `filter_damage` rewrites damage in `ZombieActor.host_apply` (Warden armor), `can_stagger` / `stun_time` / `on_frozen` tune reactions. The sim↔behavior cycle is broken in `ZombieSync._remove`. Presentation via `extra_visual` (a Node3D under the ZombieVisual) reading replicated flags / metadata; new actor flags ELECTROCUTED (64) / TELEGRAPH (128) | Special enemies without forking ZombieSim; zero new snapshot bytes |
| D-072 | 2026-11-12 | **Wonder weapons:** the Ray Pistol is a `projectile` kind `plasma` (bounces `projectile_bounces`); the Conduit's behaviors `chain` / `pulse` make no client hit claims — the host resolves the chain from the shot claim with pure `ChainLightning` rules and stuns via `ZombieSim.host_electrocute`; the pulse is a hidden attachment weapon (`pulse_id`) fired by holding the trigger and drawing `pulse_ammo` from the Conduit's mirrored magazine. Death presentation from `WeaponDefinition.death_fx` rides `_zdie` (8th field) | Host authority for multi-target damage; reuses shot validation |
| D-073 | 2026-11-12 | **WonderFx:** one pooled FxRing node per match for arcs / bursts / rings / rifts / sparks with fixed caps and `MAX_LIGHTS`; `WonderFx.play()` presents locally and relays `_wfx` from the host | AC-12.6 caps checked automatically |
| D-074 | 2026-11-12 | **Buildables:** generic `BuildableDef` (MapDefinition.buildables) + `BuildableSystem` with BuildablePart under every option marker and a Workbench, created before the interaction scan; all state in MatchSession flags `build.<id>.*` (late join / reconnect / hash for free); `unlock_flag` feeds the Relic Box condition | Core stays map-agnostic |
| D-075 | 2026-11-12 | **Special rounds:** RoundDirector asks `MapRules.get_special_round_enemy(r)` / `get_mixed_enemy(r)`; special enemies come from `special_left` (separate from the tier queue), counted through rifts as `special_pending`; numbers in RoundCurve; `_round` carries `special` / `next_special` so every peer's `SpecialRoundDirector` runs the warning atmosphere; it also owns Galvanic bursts, guaranteed drops, `_warden` replication and the gated late-round Warden (`MapRules.warden_late_rounds_enabled()`) | Map decides the schedule; core runs it |
| D-076 | 2026-11-12 | **Art pass is visual-only:** every zone builds its dressing in `dress()` under `Art/` (props, deco boxes, decals, signage, FX, fog volumes) plus `Lighting/` / `Audio/` (fixtures, reverb zones, ambience). Props are procedural (`VesperProps`: primitives merged per prop type into one ArrayMesh) or imported GLBs with their colliders stripped; `skin()` / `hide_greybox()` swap a greybox mesh for art and keep its collider. Gameplay nodes never move: `gameplay_baseline.json` (generated from the Step 12 greybox) is diffed by `test_vesper_art` | AC-13.1 / AC-13.2 hold by construction; navigation is still baked from the greybox colliders |
| D-077 | 2026-11-12 | **Per-zone static batching:** after dressing, `VesperZoneArt.batch_static()` merges the zone's visible greybox boxes, procedural props, deco and trims into one mesh per material (`MeshBatch`, core) plus a non-shadow-casting batch for small props; originals stay as hidden nodes (colliders, names, metadata). Excluded: NavDoors, TraversalMachines, Barricades, PoweredLight children, spinners, `no_batch` (reactor core / rings) | Draw calls per viewpoint fell ~60 % (Z01 hall + crowd 4050 → 1518) |
| D-078 | 2026-11-12 | **Viewer-local shadow budget:** `ShadowBudget` (core) ranks `shadow_light` lights each 0.5 s by reach to the camera, priority and distance and enables the preset's `max_shadow_lights` nearest; omni shadows use dual paraboloid (2 passes), the moon 2 splits / 70 m. Graphics.refresh_shadow_budget still applies on preset changes | "≤ 8 shadow-casting lights visible anywhere" holds per viewpoint, not just map-wide |
| D-079 | 2026-11-12 | **Render budgets (automated proxy for AC-13.3):** `visual_tests.sh vesper_art` checks draw calls ≤ 1500 per scenery viewpoint and ≤ 2000 on the six crowd viewpoints (+ 32 skinned zombies, 4 players), shadow lights ≤ preset budget; gameplay meshes (machines, wall-buys, relays, planks) get a 70 m visibility range at match setup; greybox MapMarker posts are hidden in play (`markers_visible 1`) | Real FPS stays a [HUMAN] check |
| D-080 | 2026-11-12 | **Atmosphere stack:** `ZoneAtmosphere` (core, local) blends the WorldEnvironment toward the camera zone's `AtmosphereProfile` (map data `art/zone_atmosphere.tres`) and owns the fog once it sets `atmosphere_presenter`; `SpecialRoundDirector` then only publishes `storm_u` (Environment meta) and skips `light_animated` lights. `StormSystem` derives gusts from the host clock (identical on every peer, no messages) and drives the `wind_strength` shader global. `PoweredLight` gained `pattern` (flicker / strobe / blink / buzz / swing / pulse) and `always_on` | One writer per environment property; no new replicated state |
| D-081 | 2026-11-12 | **Spatial audio zones:** `ReverbZone` areas on physics layer 10 `audio_zone` route 3D players (pool + ambience) through `Audio.REVERBS` send buses created on demand; zone beds are `AmbienceEmitter`s with synthesized placeholder loops (furnace, drips, machinery, refrigeration, reactor heartbeat at 48 BPM, radio static, fluorescent buzz, gust swell); headless runs skip the synthesis. `ReactorState` follows the drone's playback position for the heartbeat | Placeholder audio until Step 15; no gameplay query sees the audio layer |

*(Agents append new rows; never delete old ones — supersede them.)*
