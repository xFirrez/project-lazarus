# Vesper Peak — Map Design Document

> Map id: `vesper_peak` · Folder: `game/maps/vesper_peak/` · Gameplay rules referenced here are defined in [GAME_DESIGN.md](GAME_DESIGN.md).
> Zone ids, door ids and object ids in this document are **canonical** — use them in scene node names, `MapDefinition` data, quest scripts and tests.

---

## 1. Premise

**1964. The Vesper Peak Sanatorium**, a luxury tuberculosis retreat built in 1908 high in a remote, unnamed range of the European Alps, was quietly purchased in 1951 by **Group Vesper** — a secret scientific directorate funded *by both* Western and Eastern bloc intelligence services, each believing it controlled the project.

In 1938, miners boring a rail tunnel had broken into a cavern of pale green crystal: **vesperite**. It is warm to the touch, hums at a frequency that makes animals flee, and — as **Dr. Elise Varga** proved in 1952 — restores electrical activity to dead tissue.

**Project LAZARUS** began as medicine and became a weapon under the military director **Colonel Aldric Haemmer**. Reanimated subjects reported hearing *"the Choir"* — something beneath the mountain, vast and patient, singing through the crystal. Varga realized vesperite is not a fuel but a **nervous system**, and the reactor built to harness it was slowly *waking* what lies below.

On **24 December 1963**, Haemmer ordered the **Requiem Test**: the reactor at full output to reanimate two hundred bodies in the morgue simultaneously. The cascade killed every living soul in the facility — and raised them. In the last seconds, Varga bound her own consciousness to the reactor's containment field, holding back the Choir. Haemmer, killed and reanimated at the core, became **the Warden**: the Choir's servant, working to open the reactor completely.

Weeks later, the four player characters arrive by the last functioning cable car, each for their own reasons. The machines still run. The dead still walk. And someone on the radio keeps asking for help.

---

## 2. Map overview

- **Footprint:** ~230 m × 190 m; vertical span ~75 m (summit station at +28 m, radar tower top at +80 m, reactor floor at −30 m).
- **Zones:** 13 playable zones + 2 secret rooms.
- **Purchasable doors:** 14 (total 17,000 points to open everything).
- **Traversal:** Gondola (Arrival Station ↔ Communications Array), Freight Lift (Courtyard Motor Pool ↔ Specimen Storage), Laundry Chute (one-way, Operating Theater → Specimen Storage), Reactor Bridge (unlocked by the Forge task).
- **Travel time target:** Arrival Station to Reactor Chamber in ≤ 75 s of sprinting via the shortest unlocked route; no zone more than ~35 s from a perk machine.
- **Training spaces:** Frozen Courtyard (primary), Reactor Lower Ring (late-game premium), Comms Array Plaza (secondary).
- **Power:** single main switch in the Generator Hall (Z09).

### 2.1 Zone list

| Id | Zone | Elevation | Type | Size (approx.) | Gameplay purpose |
|---|---|---|---|---|---|
| Z01 | `arrival_station` | +28 m | Start, indoor | 26 × 16 m + gondola dock | Tight starting room, 4 windows + 1 vent, 2 exits |
| Z03 | `sanatorium_lobby` | +20–24 m | Indoor hub, 2 levels | 30 × 22 m | Central interior hub, mezzanine, box start location |
| Z04 | `east_wing` | +26 m (2F) | Indoor corridors | 50 × 12 m | Patient rooms, tight corridors, dangerous chokepoints |
| Z05 | `operating_theater` | +32 m (3F) | Indoor arena | 20 × 20 m, tiered gallery | Relay #2, trap, Sky Bridge access |
| Z06 | `frozen_courtyard` | +20 m | Exterior, open | 70 × 55 m | Primary training loop, many approaches |
| Z07 | `comms_array` | +45 m | Exterior + interior | 40 × 35 m plaza + radar tower | Landmark, Relay #1, Marathon Malt, EE radio |
| Z08 | `boiler_house` | +15 m | Industrial indoor | 24 × 18 m | Maintenance North entry, wall-buy |
| Z09 | `generator_hall` | +10 m | Industrial indoor | 34 × 20 m | **Power switch**, Twin-Fire, camping spot with weaknesses |
| Z10 | `morgue_tunnels` | +12 m | Basement + tunnels | Morgue 18 × 12 m + 60 m tunnels | Maintenance South, steam trap, EE morgue drawers |
| Z11 | `containment_labs` | +0–5 m | Lab complex | 36 × 24 m | Relay #3, workbench, EE pod |
| Z12 | `specimen_storage` | +0 m | Lab, cramped | 28 × 16 m + observation gallery | Bullseye Bitters, lift/chute arrival, box location |
| Z13 | `reactor_chamber` | −30 to 0 m | Vast cavern-hall | ⌀ 55 m, 40 m tall | Forge, Lower Ring training, coolant trap, finale |
| S1 | `directors_office` | +24 m | Secret | 8 × 6 m | Lore + free tonic crate |
| S2 | `ice_grotto` | +18 m | Secret | 12 × 10 m | Lore + music box (hidden behind frozen waterfall) |

*(Z02 is intentionally unused — reserved; the Gondola Dock is part of Z01.)*

### 2.2 Connectivity

| Door id | Connects | Cost | Visual | Notes |
|---|---|---|---|---|
| D01 | Z01 → Z03 | 750 | Collapsed ticket booths & luggage carts across the covered walkway | Most common first buy |
| D02 | Z01 → Z06 | 1000 | Cargo ramp shutter, chained | Alternate first buy |
| D03 | Z03 → Z04 | 1000 | Grand staircase blocked by fallen chandelier | |
| D04 | Z03 ↔ Z06 | 1250 | Iced-over terrace doors | Closes the first loop |
| D05 | Z04 → Z05 | 1250 | Surgical ward double doors, chained and padlocked | |
| D06 | Z06 → Z07 | 1250 | Military checkpoint gate + barbed wire | |
| D07 | Z06 → Z08 | 1000 | Boiler house steel door, frozen | |
| D08 | Z03 → Z10 | 1250 | Service stairwell to the basement (morgue) | |
| D09 | Z08 → Z09 | 1000 | Maintenance bulkhead | |
| D10 | Z10 → Z09 | 1000 | Tunnel blast curtain | Either D09 or D10 reaches power |
| D11 | Z10 → Z11 | 1500 | Lab security blast door ("AUTHORISED PERSONNEL ONLY") | |
| D12 | Z11 ↔ Z12 | 1250 | Decontamination airlock | |
| D14 | Z09 → Z13 | 2000 | Reactor service catwalk hatch | Access to the Lower Ring before the Forge is unlocked |
| D15 | Z05 ↔ Z07 | 1500 | Sky Bridge (covered walkway across the ravine, snow-blasted) | Creates the upper loop |
| — | Z01 ↔ Z07 | 500/ride, power | **Gondola** | 8 s ride, 30 s cooldown |
| — | Z06 ↔ Z12 | Free, power | **Freight Lift** | 6 s ride, 20 s cooldown, zombies can ride it too |
| — | Z05 → Z12 | Free | **Laundry Chute** (one-way) | Opened by shooting the chute grate (secret-ish shortcut) |
| — | Z11 → Z13 | Free | **Reactor Bridge** | Extends when all 3 Resonance Relays are active |

**Loops created as the map opens:**
- **Loop A (early):** Z01 → Z03 → Z06 → Z01 (D01 + D04 + D02).
- **Loop B (maintenance):** Z06 → Z08 → Z09 → Z10 → Z03 → Z06 (D07, D09, D10, D08).
- **Loop C (upper):** Z03 → Z04 → Z05 → Z07 → Z06 → Z03 (D03, D05, D15, D06, D04).
- **Shortcuts:** Gondola (Z01↔Z07), Freight Lift (Z06↔Z12), Laundry Chute (Z05→Z12).

### 2.3 Schematic (not to scale; vertical position ≈ elevation)

```
 +45m          [Z07 COMMS ARRAY]════D15 Sky Bridge════[Z05 OPERATING THEATER] +32m
                 ║gondola      │D06                          │D05         ╲ laundry chute
 +28m  [Z01 ARRIVAL STATION]   │                     [Z04 EAST WING] +26m  ╲ (one-way)
              │D02   │D01      │                             │D03           ╲
 +20m  [Z06 FROZEN COURTYARD]──┴──────D04──────────[Z03 SANATORIUM LOBBY]    ╲
              │D07    ║freight lift(power)                   │D08            ╲
 +15m  [Z08 BOILER HOUSE]     ║                      [Z10 MORGUE & TUNNELS] +12m
              │D09            ║                          │D10        │D11      ╲
 +10m  [Z09 GENERATOR HALL]───╫──────────────────────────┘           │          ╲
              │D14            ║                          [Z11 CONTAINMENT LABS]─D12─[Z12 SPECIMEN STORAGE]
  0m          │               ╚═══════════════════════════════════════════════════╝
 −30m  [Z13 LAZARUS REACTOR CHAMBER] ◀════ Reactor Bridge (after relays) ════ Z11
```

(D01 joins Z01 directly to Z03 through the covered walkway; the schematic shows it meeting the Courtyard line only for readability.)

### 2.4 Progression pacing (target, solo)

| Rounds | Expected state |
|---|---|
| 1–3 | Hold Arrival Station; buy M14 / Coachgun; open D01 or D02 |
| 4–6 | Loop A open; first box spins in the Lobby; Second Wind bought |
| 6–9 | Push toward power via Courtyard→Boiler (D07, D09) or Lobby→Morgue (D08, D10); **power on** |
| 9–14 | Perks (Ironhide first); Gondola/Comms Array; relays; Conduit parts; **Forge unlocked** |
| 14–20 | First Forge upgrades; training in Courtyard or Reactor Lower Ring |
| 20+ | High-round strategy; Easter egg attempt possible from ~round 15 |

---

## 3. Zone details

Each zone section lists: **layout**, **landmarks**, **entrances (spawners)**, **interactables**, **combat character**, **atmosphere**.

### Z01 — Arrival Station (start)

- **Layout:** The upper cable-car terminal. A ticket hall (ground) with a raised waiting gallery (+2.5 m, two staircases) overlooking the **gondola dock**, where a cabin hangs dead in its bay. Ticket booths, toppled benches, a luggage carousel, a dead departures board with flipping letters (flickers to show the round number on round change — a cute touch).
- **Exits:** D01 (east, covered walkway down to the Lobby), D02 (south, cargo ramp to the Courtyard). Gondola (north, power).
- **Spawners:** 4 barricaded windows (2 ground, 2 gallery), 1 ceiling vent above the luggage carousel (from round 3).
- **Interactables:** M14 wall-buy (500), Coachgun wall-buy (500), **Second Wind Seltzer** (works without power), gondola call console, music box #1 (in the luggage pile), lore document L01.
- **Combat:** deliberately cramped: no single window is safe — the gallery windows flank ground positions. Players learn to rotate between windows and repair. Running a small loop around the carousel is possible but tight.
- **Atmosphere:** Moonlight through tall frosted windows (blue shafts in volumetric fog), a single swinging tungsten lamp, snow blowing through broken panes, the gondola cable creaking in the wind. A flare left burning in the dock casts red flicker.

### Z03 — Sanatorium Lobby (hub)

- **Layout:** Belle Époque grand lobby: chequered marble floor cracked by frost, reception desk, a collapsed chandelier blocking the grand staircase (D03), a **mezzanine** ring (+4 m) reached by two side stairs. Terrace doors to the courtyard (D04). Service door to the basement (D08).
- **Spawners:** 3 windows (ground), 1 mezzanine window, 1 door-burst spawner (reception back office), risers none.
- **Interactables:** **Quickdraw Fizz**, MP40 wall-buy (1000), **Relic Box start location** (beside the reception desk), the guestbook (Director's Office clue), mezzanine bookcase (S1 secret door), lore L02, L03.
- **Combat:** central hub with multiple paths; the mezzanine is a tempting perch with two staircases (a "defensible location with a weakness": zombies come up both sides).
- **Atmosphere:** warm, dusty, elegant decay — portraits of the founder, a 1950s Group Vesper banner hastily hung over the original crest, an exploded reception switchboard sparking. Grandfather clock stopped at 23:51.

### Z04 — East Wing (patient rooms, 2F)

- **Layout:** One long main corridor with 12 patient rooms (6 accessible, numbered 1–12; rooms 3, 7, 9, 12 accessible), a nurse station hub, and a sunroom balcony overlooking the courtyard (can jump down to the courtyard — a one-way escape route, 4 m drop, no damage).
- **Spawners:** 3 windows (patient rooms), 2 ceiling vents, 1 door-burst (linen closet).
- **Interactables:** **Pack Mule Cream Soda** (nurse station), Model 37 wall-buy (1500), box location, **Electro-Therapy Corridor trap** console (T1, see §5), Conduit part spawn (Lens, option B), room 7 mirror switch (S1 secret), music box #2 (room 12, under the bed), lore L04.
- **Combat:** tight and dangerous; the corridor is a kill-lane for penetrating weapons but trapping yourself is easy. The balcony drop is the "escape hatch".
- **Atmosphere:** flickering fluorescents (added by the military over Victorian fittings), wheelchairs, restraint straps on beds, scratch marks counting days on the walls. Room 7 has a mirror that does not reflect zombies.

### Z05 — Operating Theater (3F)

- **Layout:** A circular tiered surgical amphitheater with a glass-domed roof (moonlight and snow above). The central operating table is now an **electroconvulsive apparatus** wired to vesperite cells — this is **Resonance Relay #2**. Upper gallery ring, a scrub room, and the roof door to the Sky Bridge (D15). The laundry chute grate in the scrub room.
- **Spawners:** 2 dome skylight drops (zombies drop from the dome edge), 2 windows in the gallery, 1 vent.
- **Interactables:** Relay #2, laundry chute grate (shoot to open), lore L05, audio reel R03.
- **Combat:** arena with a central obstacle (the apparatus) for small loops; gallery stairs are chokepoints. Defending the relay here is a memorable early fight.
- **Atmosphere:** cold surgical light from a single huge lamp, green arcs crackling across the apparatus, snow drifting through a broken dome pane in a single column.

### Z06 — Frozen Courtyard (primary training area)

- **Layout:** The snow-covered formal garden between station, sanatorium and the mountain wall. Features: a large **frozen tiered fountain** (centre), an abandoned **motor pool** (2 trucks, a half-track, an overturned jeep, fuel drums) along the west side, a collapsed greenhouse (partly walkable), a sandbag/barricade line, a **freight lift** shed (Z12 link), a frozen waterfall against the cliff (S2 secret behind it), icicle-hung archways.
- **Spawners:** 6 risers spread across flowerbeds (from round 2), 2 wall-climb points (zombies vault the outer wall), the D02 ramp, 1 window into the greenhouse shed.
- **Interactables:** **Ironhide Stout** (in the motor pool garage), M16 wall-buy (1200), Tripmines wall-buy (1000), box location (motor pool), freight lift controls, explosive fuel drums (H1), shootable icicle clusters (H2) above the D04 terrace and archways, Conduit part spawn (Stock, option B), lore L06.
- **Combat:** the main **training loop** circles the fountain (≈ 70 m circuit), with alternative wider loops around the vehicles. Several directions of approach mean you can be pinched if you lose track. Snow slows *nothing* (avoid frustration) but deep snow banks visually guide the loop.
- **Atmosphere:** the storm at its strongest: blowing snow particles, gusting audio, swinging searchlights from the comms ridge sweeping the yard, cold blue moon through racing clouds, red emergency beacons on the trucks. The radar tower looms above, always visible.

### Z07 — Communications Array

- **Layout:** A fortified military station on the ridge: a plaza with antenna masts and guy-wires, a two-storey radio building (radio room + observation deck with lockers), the **gondola upper station**, and the **radar tower** (a 35 m lattice tower topped with a rotating dish — the map's landmark, visible from the courtyard, the station and the Sky Bridge; its red aircraft lights blink through the storm). The tower's lower platform (+8 m via stairs) holds **Resonance Relay #1**.
- **Spawners:** 4 risers on the plaza, 2 cliff-climb points, 1 door-burst (generator shed), 1 window in the radio building.
- **Interactables:** **Marathon Malt**, Kar98k wall-buy (1500), **Ice Axe** (3000, mounted on the climbing club plaque), box location (plaza, beside the antenna base), Relay #1, the **radio console** (EE stage 1), music box #3 (observation deck locker), Conduit part spawn (Coil, option A), lore L07, reel R01.
- **Combat:** secondary training plaza; the tower stairs are a death-trap if you climb under pressure; the gondola is the escape route.
- **Atmosphere:** howling wind, the rhythmic sweep of the rotating dish, static-laced voices from radios that should be dead, aurora-like green glow on the clouds above the peak when energy pulses happen.

### Z08 — Boiler House (Maintenance North)

- **Layout:** Coal-fired boiler room built into the hillside with catwalks, a coal chute, pipe galleries, a foreman's office. Leads down via an inclined tunnel to the Generator Hall (D09).
- **Spawners:** 2 vents, 1 coal-chute drop, 1 window (foreman's office).
- **Interactables:** M3 Grease Gun wall-buy (1000), box location, Conduit part spawn (Stock, option A), lore L08.
- **Combat:** medium room with a catwalk loop; good for short trains early.
- **Atmosphere:** orange furnace glow (boilers still burning — who stokes them?), steam bursts, rhythmic hammering pipes.

### Z09 — Generator Hall (power)

- **Layout:** Long industrial hall with three huge diesel-electric generators and a raised control booth holding the **main power switch** (a big 3-throw lever bank). Exits: D09 (north), D10 (south tunnels), D14 (reactor catwalk hatch, east).
- **Spawners:** 2 vents, 2 floor grates (zombies climb up from the pipe trench), 1 door-burst.
- **Interactables:** **Main Power Switch**, **Twin-Fire Root Beer**, lore L09, reel R04.
- **Combat:** "camping spot with weaknesses": the control booth has one stair entrance (strong) but floor grates spawn behind defenders when the hall is active, and Galvanics leap onto the booth.
- **Atmosphere:** dark until power on — then a dramatic sequence: generators spin up one by one, lights cascade across the map zone by zone, an alarm klaxon, the reactor's deep pulse begins audible map-wide, perk machines light up and play their jingles.

### Z10 — Morgue & South Tunnels (Maintenance South)

- **Layout:** The sanatorium's basement morgue (wall of 24 body drawers, autopsy tables), a records room, then long utility tunnels (3 m wide, pipes, junctions, a flooded section ankle-deep) running to the Generator Hall (D10) and the lab blast door (D11).
- **Spawners:** 2 morgue drawers (door-burst style), 3 tunnel vents, 1 floor grate.
- **Interactables:** .357 "Widow" Revolver wall-buy (1000), **Steam Purge trap** (T2) covering a 20 m tunnel section, morgue drawers (EE stage 2b), 4 painted symbols (EE clue), lore L10, reel R05.
- **Combat:** dangerous chokepoints and long sightlines; the trap tunnel is the strongest early-game trap location.
- **Atmosphere:** green-tinted emergency bulbs, dripping water, the drawers occasionally thump from inside, breath fog.

### Z11 — Containment Labs

- **Layout:** Clinical white-tile laboratories turned abattoir: six glass **containment chambers** (2 shattered), an observation control room, the **Lab Workbench**, a decontamination airlock (D12 to Z12), and the reactor-side gantry where the **Reactor Bridge** extends.
- **Spawners:** 2 broken containment chambers (subjects climb out), 2 vents, 1 airlock door-burst.
- **Interactables:** **Resonance Relay #3** (in the central chamber), **Lab Workbench** (Conduit build), **Soul Containment Pod** (EE stage 3), box location, electrified water puddles hazard (H3) via a breaker box, lore L11, reel R06.
- **Combat:** medium-tight rooms around a central chamber ring (small loop). Relay #3 defense is the hardest of the three (arrives later, more spawners).
- **Atmosphere:** sterile flicker, red alarm strobes, vesperite glow bleeding from cracks, observation glass smeared with handprints from the inside, a tape machine looping a countdown.

### Z12 — Specimen Storage

- **Layout:** Cold-storage hall of shelving and specimen jars (organs, a two-headed goat, something with too many teeth), the observation gallery overlooking the reactor chamber through thick glass, the freight lift bottom station, the laundry chute exit (a pile of linen).
- **Spawners:** 2 vents, 1 freight-lift shaft drop, 1 window to the gallery.
- **Interactables:** **Bullseye Bitters**, box location, freight lift controls, lore L12, reel R07.
- **Combat:** cramped; good for quick perk/box runs, bad for holding.
- **Atmosphere:** freezing (frost on everything, breath fog VFX), humming refrigeration, green light from the reactor through the gallery glass — the first glimpse of the centerpiece, framed deliberately.

### Z13 — Lazarus Reactor Chamber (centerpiece)

- **Layout:** A colossal cylindrical cavern-hall carved into the mountain. At its center floats the **reactor core**: a sphere of vesperite crystal held within three massive rotating containment rings, connected to the walls by cable bundles thick as tree trunks. Levels:
  - **Lower Ring (−20 m):** a circular walkway around the pit, ≈ 140 m circumference with 4 radial spokes — the late-game **training ring**. Reached via D14 from the Generator Hall.
  - **Observation platforms (−10 m):** two balconies with control desks.
  - **Forge Platform (−10 m):** the **Lazarus Forge** sits on a cantilevered platform reached only by the **Reactor Bridge** from Z11 once the three relays are active.
  - **Core pit (−30 m):** not walkable; railings everywhere players can stand (no accidental falls). Used for the finale's spectacle and as the climb-out point for pit spawners.
- **Spawners:** 6 "rift" climb points along the Lower Ring (zombies climb out of the pit), 2 vents in the spokes, special-round energy rifts.
- **Interactables:** **Lazarus Forge**, **Coolant Purge trap** (T3: liquid-nitrogen jets freezing a quarter of the ring, zombies shatter), 4 EE vesperite nodes (stage 5), the core socket (finale), lore reel R08.
- **Combat:** the Lower Ring rewards skilled training (constant curve, spokes as escape routes, coolant trap control). Galvanics climbing from the pit keep it from being trivial.
- **Atmosphere:** the most spectacular space: enormous scale, green core light pulsing with the reactor heartbeat (synchronized to audio), electrical arcs between rings, floating dust motes, heat shimmer, choir-like drones. When power is off it is dark and rumbling; after power on the rings begin turning; after relays the core blazes.

### S1 — Director's Office (secret)

- Haemmer's office behind a rotating bookcase on the Lobby mezzanine. Map table with Vesper Peak survey, Haemmer's service pistol display case, files. **Free Tonic Crate:** each player may take one random perk they don't have (respects cap), once per match. Lore L13 (Haemmer's orders for the Requiem Test).
- **Unlock:** read the Lobby guestbook (mentions "the Director's favourite room, number seven") → interact the cracked mirror in East Wing room 7 → bookcase opens with a grinding sound audible on the mezzanine.

### S2 — Ice Grotto (secret)

- A cave behind the courtyard's frozen waterfall where Anneliese's missing brother died. **Unlock:** after power is on, boiler steam vents warm the cliff and the waterfall visibly cracks; an explosive or Ray Pistol hit shatters it. Contains lore L14 (the brother's diary), and a hidden fourth music box variant that triggers a character-specific VO conversation for Anneliese if present.

---

## 4. Spawner and fairness design

- Each zone defines spawners with **type**, **nav entry link**, and **activation zones** (the zones in which a player must be for this spawner to be active; normally the spawner's own zone + immediately adjacent unlocked zones).
- Spawners placed so that from any standing spot at least one active spawner is **out of sight**, avoiding forced in-view spawns.
- Windows/barricades are the main early-game entrances (Z01, Z03, Z04); exterior zones rely on risers and climb points; underground on vents/grates; Reactor on pit climbs.
- **Validation (automated, Step 8):** from every spawner, a path exists to every reachable player position in its activation zones; every walkable nav polygon is reachable from at least one spawner.

---

## 5. Interactive systems on the map

| Id | Object | Zone | Cost | Requirements | Behavior |
|---|---|---|---|---|---|
| PWR | Main Power Switch | Z09 | Free | — | Map-wide power-on sequence (§3 Z09) |
| R1/R2/R3 | Resonance Relays | Z07 / Z05 / Z11 | Free | Power | Hold 3 s, defend 20 s (pauses if no player in zone). All three → Reactor Bridge extends, Forge reachable |
| FRG | Lazarus Forge | Z13 platform | 5000 | Relays | GAME_DESIGN §9 |
| T1 | Electro-Therapy Corridor | Z04 | 1000 | Power | Electrified floor plates along 15 m of corridor, 25 s, cooldown 60 s |
| T2 | Steam Purge | Z10 | 1000 | Power | Scalding steam jets along 20 m tunnel |
| T3 | Coolant Purge | Z13 | 1000 | Power | Freezes a ring quadrant; frozen zombies shatter when touched/shot |
| H1 | Fuel drums | Z06, Z08 | — | — | Shoot to explode (r = 4 m, 2000 dmg, damages players lightly), respawn every 3 rounds |
| H2 | Icicle clusters | Z06 | — | — | Shoot to drop: kills zombies below (r = 1.5 m), regrow after 2 rounds |
| H3 | Lab breaker / water | Z11 | Free | Power | Flip breaker: puddles electrified 10 s (stun + damage), recharge 90 s |
| GND | Gondola | Z01 ↔ Z07 | 500 | Power | 8 s ride; zombies can't board; arriving cabin is a safe 8 s; 30 s cooldown |
| LFT | Freight Lift | Z06 ↔ Z12 | Free | Power | 6 s ride; zombies may ride along (danger); 20 s cooldown |
| CHT | Laundry Chute | Z05 → Z12 | Free | Shoot grate once | One-way drop 30 m (soft landing in linen); 5 s travel |
| WB | Lab Workbench | Z11 | Free | Power + 3 parts | Build Lazarus Conduit (first player to interact after build takes it; afterwards box pool) |
| Parts | Coil / Lens / Stock | Z07 or Z12 / Z04 or Z05 / Z08 or Z06 | — | — | Each part spawns at one of two locations (random per match); shared team inventory; HUD shows collected parts |

### 5.1 Wall-buys

| Weapon | Zone | Cost |
|---|---|---|
| M14 | Z01 | 500 |
| Coachgun | Z01 | 500 |
| MP40 | Z03 | 1000 |
| Model 37 | Z04 | 1500 |
| M16 | Z06 | 1200 |
| Tripmines | Z06 | 1000 |
| Kar98k | Z07 | 1500 |
| Ice Axe | Z07 | 3000 |
| M3 Grease Gun | Z08 | 1000 |
| .357 Revolver | Z10 | 1000 |

Wall-buys are drawn on the wall as **stenciled military silhouettes on canvas tarp** (our visual language, instead of chalk), with a crate below; the weapon appears physically on the rack once bought.

### 5.2 Perk machines

| Tonic | Zone |
|---|---|
| Second Wind Seltzer | Z01 Arrival Station (no power needed) |
| Quickdraw Fizz | Z03 Lobby |
| Pack Mule Cream Soda | Z04 East Wing |
| Ironhide Stout | Z06 Courtyard (motor pool garage) |
| Marathon Malt | Z07 Comms Array |
| Twin-Fire Root Beer | Z09 Generator Hall |
| Bullseye Bitters | Z12 Specimen Storage |

### 5.3 Relic Box locations

Z03 Lobby (**start**), Z04 East Wing (nurse station), Z06 Motor Pool, Z07 Comms Plaza, Z08 Boiler House, Z11 Containment Labs, Z12 Specimen Storage. Never in Z01 or Z13. During a Fire Sale, all 7 activate.

---

## 6. Lore & environmental storytelling

### 6.1 Collectibles

**Documents (14):** interact to read (paper UI with typed/handwritten text); collected entries persist locally in a **Journal** (main menu).

| Id | Zone | Title / content summary |
|---|---|---|
| L01 | Z01 | Cable car timetable with "LAST CABIN: 23 DEC — DO NOT RETURN" scrawled |
| L02 | Z03 | 1908 sanatorium brochure ("Breathe the light of Vesper") |
| L03 | Z03 | Group Vesper acquisition memo, 1951 — redacted funders (both CIA and KGB letterheads) |
| L04 | Z04 | Nurse's log: patients "hearing singing in the walls" |
| L05 | Z05 | Varga surgical note: Subject 31 regains speech after 4 days dead |
| L06 | Z06 | Motor pool requisition: "Coffins — 200. Urgent." |
| L07 | Z07 | Radio transcript fragment: Haemmer to unknown command — "the Choir is cooperative" |
| L08 | Z08 | Boiler foreman's letter home, increasingly paranoid |
| L09 | Z09 | Engineering report: reactor output "rising without input" |
| L10 | Z10 | Morgue intake ledger, 24 Dec 1963, page ends mid-entry |
| L11 | Z11 | Varga: "Vesperite is not a fuel. It is a nerve." |
| L12 | Z12 | Specimen catalogue including "Item 0: sample from the deep cavern — IT MOVED" |
| L13 | S1 | Haemmer's Requiem Test order |
| L14 | S2 | Anneliese's brother's diary (Tomas Brandt, guide hired by Group Vesper) |

Three documents (randomly chosen each match from L04, L06, L08, L09, L10, L12) carry the **frequency digits** used in EE stage 1; they show a red-ink annotation only after the EE has begun (stage 0 complete).

**Audio reels (8):** reel-to-reel tapes on desks (R01–R08), played back in-world with radio filtering + subtitles. They form the main narrative arc: Varga's research diary (R01, R03, R05), Haemmer's briefings (R04, R06), the night of the Requiem Test (R07), and Varga's last recording at the core (R08). VO approach: human-recorded or licensed TTS; subtitles mandatory.

### 6.2 Environmental vignettes (must be built in Step 13)

1. Arrival Station: a family's luggage, a child's toy sled, and a stopped wristwatch on the platform (23:51).
2. Lobby: the founder's portrait slashed; Group Vesper banner over the crest.
3. East Wing room 3: walls covered in the same musical notation, drawn in charcoal — the Choir's melody (the same melody as the EE song's motif).
4. Operating Theater: an observation gallery seat with a notebook and fogged glasses — Varga's seat.
5. Courtyard: 200 coffins stacked under tarps in the motor pool, most empty and broken open from inside.
6. Comms Array: a radio operator still seated, frozen solid, headphones on.
7. Generator Hall: a chalk tally of days on the control booth wall — someone survived for weeks.
8. Morgue: one drawer chained shut with a cross scratched on it (stage 2b reward drawer).
9. Labs: containment chamber 6 with claw marks *on the outside*.
10. Reactor: Haemmer's officer cap on the Forge platform rail.

---

## 7. Main Easter egg — **"Requiem for Lazarus"**

Optional. Playable solo and with 2–4 players (some steps scale requirements by player count). Expected duration for a prepared team: **60–90 minutes** (rounds ~15–25). Every step reuses core systems (kills, interactables, hold actions, special rounds, escort, boss) so it integrates with normal play rather than bolted-on puzzles.

### Prerequisites ("Stage 0: The Mountain Stirs")
- Power on, all 3 Resonance Relays active (Forge unlocked).
- Trigger: on the next round start after the relays complete, the radio in the Comms Array begins broadcasting static with a woman's voice (map-wide faint radio VO). This is the hook; the radio console becomes interactable.

### Stage 1 — "The Frequency"
- The three frequency documents (see §6.1) now show red annotations: a dial symbol (I, II, III) and a two-digit number each.
- At the Comms Array radio console, players tune three dials (interact cycles values; hold to scroll). Correct combination → **Dr. Varga makes contact** (scripted VO): she explains she is trapped in the containment field and needs her "anchor" — three shards of her own vesperite heart-crystal, scattered by the Requiem cascade.
- Wrong combination: piercing static and 3 zombies burst from the radio building door.
- *Design purpose:* exploration + reading the environment.

### Stage 2 — "Fragments" (three parallel sub-steps, any order)
- **2a — Frozen Heart (Courtyard):** a shard is visible encased in the frozen fountain's top tier. Break the ice with explosive damage ≥ 2000 in one hit (LAW, Ray Pistol direct hit, China Lake, frag) → shard falls into the basin; pick up.
- **2b — The Chained Drawer (Morgue):** four symbols painted in luminous paint in the morgue/tunnels (only visible when the lab breaker H3 is flipped — lights dim and UV-like glow appears; ties the labs to the morgue). The symbols' order maps to four drawers; pull them in order (each pull: a zombie corpse falls out and may rise). Correct → the chained drawer opens, shard inside. Wrong → 4 drawer-zombies burst out, sequence resets.
- **2c — The Marked One:** during the next special round, one Galvanic is "marked" (brighter, white-cored arcs, unique sound). It flees to a rift after 40 s if not killed. Killing it drops the shard. If it escapes, the next special round has another marked one.
- Shards are shared team items; the HUD shows a three-shard indicator.

### Stage 3 — "Charging the Heart"
- Place the shards in the **Soul Containment Pod** in the Containment Labs. The pod must absorb **souls**: zombies killed within 10 m of the pod **by the Lazarus Conduit (either form)**. Required: 30 + 10×(players−1) souls.
- Twice during charging, a vesperite surge knocks loose one of the pod's two cables (sparks, alarm) — a player must hold-interact 2 s to reseat it, or charging pauses. Solo-friendly but makes teams coordinate (one charges, one guards cables).
- *Requires* the Conduit, which naturally sends players through the build quest (parts across the map) — integration.

### Stage 4 — "The Descent" (escort)
- Pick up the charged **Heart** (carried item: carrier moves at walk speed, cannot sprint, holds a pistol only, glows — zombies prioritise the carrier). It can be dropped/passed (drop key) and is auto-dropped if the carrier is downed.
- Carry it from the Labs to the Reactor Lower Ring **through the Maintenance Network** (the Reactor Bridge locks during this step: Varga says the Choir is "watching the bridge"), via D10/D09/D14, within **4 minutes**. During the escort, spawn rate is ×1.5 and vents in Z09/Z10/Z13 are all active.
- Failure (timer expires): the Heart returns to the pod (souls retained), retry next round.

### Stage 5 — "Calibration"
- Place the Heart in the core socket on the Lower Ring. Four **vesperite nodes** emerge one at a time on the containment rings (rotating with them). Each must be shot with a **Forge-upgraded weapon** to break (nodes immune otherwise). Between nodes, zombie waves continue. Tests aim, positioning and having invested in the Forge.

### Stage 6 — "Requiem" (finale)
- The reactor opens; the round counter is replaced by a flickering "∞" for the event; normal spawns stop and **the Warden** rises from the core pit onto the Lower Ring.
- **Arena:** Lower Ring + Forge platform (bridge re-extends). Three **stabilizer pylons** around the ring are attacked by zombies; each pylon must stay above 0 HP — players repair by hold-interacting (like barricades). If all three fall, the event fails (the Warden retreats; retry from Stage 5 next round — the Heart stays socketed).
- **Warden phases:** (1) armored — break 3 plates (weak to explosives & upgraded weapons); (2) core exposed — Conduit/Requiem deals ×3 to the core; Warden summons Galvanics; (3) enraged at 25% — faster charges, coolant trap (T3) freezes him for 4 s (rewarding trap use).
- **Victory:** Haemmer collapses; Varga's voice delivers a farewell; the core flares white; the camera (in-engine, players keep control except a 10 s slow-motion moment) shows the containment rings closing. All zombies on the map die. The storm subsides for one round (clear starry sky, quiet) before resuming.
- **Rewards ("Lazarus Blessing"):**
  1. Every player receives **all seven tonics**, ignoring the perk cap, and the set is **restored automatically every time they are revived** for the rest of the match.
  2. Each player receives one **Free Upgrade** power-up token (next Forge use free).
  3. The reactor core changes from green to a calm white-blue for the rest of the match (visible reward state).
  4. **Persistent:** a completion badge on Vesper Peak's map card (per player count), the "Requiem" entry in the Journal, and the final reel R09 ("Varga's farewell") unlocked in the Journal.
  5. **Narrative hook:** the final VO notes that the Choir's signal was transmitted *elsewhere* before containment — setting up future maps.
- Play continues after the finale.

### 7.1 Easter egg integration rules

- Every step must be completable with 1 player (solo) and scale for 2–4 (counts, not mechanics).
- No step may require precise frame-perfect actions or hidden pixel-hunting without in-world clues.
- All quest state is host-authoritative and part of the full match snapshot (late joiners see correct world state; reconnecting players don't break it).
- Each stage has a debug skip command and an automated integration test that executes the stage's logic headless (Step 14).
- Failure states never permanently lock the quest.

### 7.2 Minor secrets

- **"Snowblind" song:** interact with 3 hidden music boxes (Z01 luggage pile, Z04 room 12, Z07 observation locker) → original song plays map-wide (once per match).
- **Director's Office (S1)** and **Ice Grotto (S2)** — §3.
- **Room 7 mirror** shows the player's character as a zombie for a split second (pure atmosphere).
- **Departures board** in Z01 occasionally spells messages ("SHE IS STILL HERE") after power.
- **Five frozen ravens** perched around the exterior (Z01 roofline, Z06 fountain, Z06 greenhouse, Z07 antenna, Z07 gondola station): shooting all five in one match spawns a **Double Points + Max Ammo** pair in the Courtyard. (Low-cost secret, rewards observation.)

---

## 8. Art direction for Vesper Peak

### 8.1 Palette & lighting language

| Context | Key colors | Light sources |
|---|---|---|
| Exterior night storm | Deep navy, desaturated teal, moon-white snow | Directional moonlight (soft shadows, low angle), searchlights, red beacons |
| Sanatorium interiors | Warm amber, faded rose wallpaper, dark wood | Tungsten sconces (many non-shadowed, few shadowed), candles, moon shafts |
| Military additions | Olive drab, stencil white, hazard yellow | Caged bulbs, fluorescent tubes (flicker) |
| Maintenance | Rust, soot black, furnace orange | Furnace glow, sodium lamps, emergency red |
| Labs | Clinical white/teal tiles, red alarm | Fluorescents, red strobes, green vesperite leak |
| Reactor | Black stone, brass/copper machinery, vesperite green (later white-blue) | Core emissive + glow, arc flashes, rim lights |

**Contrast rule:** every area has a dominant temperature and an accent of the "other" temperature (e.g., warm lobby with blue moon shafts; cold courtyard with warm windows of the sanatorium glowing in the distance).

### 8.2 Landmarks & sightlines

- **Radar tower** (Z07) visible from Z01 windows, Z06 everywhere, Z05 dome, Sky Bridge.
- **Sanatorium façade** with lit windows visible from the Courtyard and Gondola.
- **Gondola cable** stretched across the courtyard sky — players see the cabin move when someone rides.
- **Reactor glow** visible through the Specimen gallery glass (Z12) and through floor grates in Z09 (green light from below).
- **Relic Box light pillar** visible across exterior zones and through skylights.

### 8.3 Weather & effects

- Camera-attached snow (GPU particles, intensity per zone; none deep underground; light snow through broken skylights).
- Wind gust system: periodic gusts increase snow density, sway lamps/cables/tarps (shader wind), audio swell.
- Volumetric fog: exterior dense and blue; interiors light with dust; reactor green-tinted haze.
- Energy pulses: every round start, a pulse ripples outward from the reactor (light flicker map-wide, audio thump, aurora flash outside).

---

## 9. Map-specific implementation notes

- Map rules script: `maps/vesper_peak/scripts/vesper_peak_rules.gd` (extends `MapRules`): power sequence, relays, bridge, gondola/lift/chute, conduit build, special round enemy = Galvanic, quest graph registration.
- Each zone is its own scene (`zones/Z03_sanatorium_lobby.tscn`, etc.) with: geometry, `NavigationRegion3D`, zone `Area3D` volume(s), spawners, interactables, lights, audio emitters, reverb area, occluders. Doors live on zone boundaries in the *lower-numbered* zone's scene.
- Greybox first (Step 8) using kit pieces with gameplay-accurate dimensions; final art (Step 13) replaces meshes without moving gameplay markers (markers are separate nodes under `Gameplay/` in each zone scene).

### 9.1 Step 8 greybox — layout as built (and changes from §2–5)

Datum: **y 0 = the Arrival Station floor (+28 m real)**; +X east, +Z north. All zone scenes are in `game/maps/vesper_peak/zones/`; the full id list is `markers_manifest.json` (checked by `tests/integration/test_vesper_markers.gd`). Validation: `tools/run_sim.sh nav_validate` (AC-8.2) and `tools/run_sim.sh flow` (AC-8.3).

| Zone | Footprint (x, z) | Floor y (real) | Notes |
|---|---|---|---|
| Z01 | −13..13, −8..8 + dock −7..−2, −13..−8 | 0 (+28) | Unchanged Step 6 ticket hall; W_G2 moved to x −10 for the dock |
| Z03 | walkway 13..38 (ramp 0 → −8); lobby 38..68, −14..8 | −8 (+20); mezz −4; landing −2 | Grand staircase → landing → D03 east |
| Z04 | 70..82, −62..−8 | −2 (+26) | Runs north–south along the Courtyard's east side |
| Z05 | 64..84, −98..−78 (+ scrub 84..90) | +4 (+32); gallery +7 | Stairwell from D05 |
| Z06 | −10..66, −78..−20 | −8 (+20) | Fountain loop centre (28, −49) |
| Z07 | −20..20, −138..−100; road x −30..−26 | +17 (+45) | Road from D06: south, west, 50 m ramp |
| Z08 | −46..−22, −28..−10 | −13 (+15) | |
| Z09 | −34..−6, −64..−41 | −18 (+10) | Booth +3 m with the power switch |
| Z10 | morgue 4..22, −22..−10; tunnels W/S/E | −16 (+12) | East tunnel = Steam Purge section |
| Z11 | 56..92, −72..−48 | −28 (0) | Gantry x 50..56 at −28 |
| Z12 | 63..91, −46..−29 | −28 (0) | Lift shaft in the NW corner |
| Z13 | cavern centre (28, −50), wall r 25.4 | ring −48 (−20) | Shaft x −6..0 from D14 (3 flights) |

**Layout changes (Step 8, with reasons):**
1. **Gondola dock on Z01's south-west side** (doc: north). The cable runs straight south over the Courtyard to the Comms Array station — matching §8.2 ("gondola cable stretched across the courtyard sky") with Z07 placed on the south ridge where the Sky Bridge from Z05 can reach it.
2. **Z04 runs along the Courtyard's east side** so the sunroom balcony drop lands in the Courtyard (snowbank, 4.6 m); Z05 sits at its south end; the Sky Bridge (≈ 49 m, 11°) spans the ravine south of the Courtyard to Z07.
3. **Z07 is reached from D06 by a mountain road** (25 m climb: 6 m + 22 m flat + 50 m ramp at 26.6°).
4. **Forge platform at −34 (real −6)** instead of −10: keeps the Reactor Bridge from the Z11 gantry at 26.6°. The **west observation balcony (−38)** opens off the D14 shaft's middle landing; the second "observation platform" is the Z12 observation glass (art Step 13).
5. **Z12's reactor-view gallery** is a marker (`EE_ObservationGlass`) — the D11 ramp runs between Z12 and the cavern; Step 13 frames the view.
6. **Z04 ceiling vents** are high-wall ducts into the sealed west strip (navmesh needs 1.8 m headroom on spawner ledges); the Z05 skylight drops and Z08 coal chute are real drops.
7. **Climb points** (Courtyard wall, Comms cliff, Generator Hall floor grates, Morgue grate, reactor pit rifts) use the new `ZombieSpawner.Kind.CLIMB` + JUMP links; door bursts are player-clipped closets.
8. Secret rooms S1 / S2 exist as entrance + content markers only (rooms are Step 13/14).
9. Travel times (flow sim, sprint along the navmesh): Z01 → Z13 Lower Ring **35.7 s** (target ≤ 75 s); worst perk-to-nearest-perk **25.6 s** (Marathon Malt; target ≤ 35 s); worst zone-to-perk **15.6 s** (Z13).

**Step 9 additions:** all 10 wall-buys are live `WallBuy` nodes at the Step 8 marker positions (`WallBuy_MP40` Z03 facing +Z, `WallBuy_Model37` Z04 +X, `WallBuy_M16` Z06 +X, `WallBuy_Tripmines` Z06 −Z, `WallBuy_Kar98k` Z07 −X (outside the radio room's west wall), `WallBuy_IceAxe` Z07 +X, `WallBuy_GreaseGun` Z08 +X, `WallBuy_Revolver` Z10 +X; M14 / Coachgun unchanged) drawn as stencil-on-canvas tarps with a crate. The Relic Box stands at each `Box_*` marker (start `Box_Z03`, `map_definition.tres` `box_start`); the markers' posts are hidden.

**Step 11 additions:** Resonance Relays stand on `R1_Relay` (Z07 tower platform), `R2_Relay` (Z05 apparatus) and `R3_Relay` (Z11 central chamber) — defend zone = the marker's zone; all three extend `BRG_ReactorBridge` and wake the Lazarus Forge on `FRG_LazarusForge` (the Z13 `ForgeAnvil` block keeps only its collision; `ReactorState` drives the core: dark → turning → blazing). Traps use `maps/vesper_peak/traps/t1-t3.tres`: T1 = 4 × 15 m box along the Z04 corridor, T2 = 20 × 3 m box in the east tunnel, T3 = the 90° Lower Ring sector centred on `T3_CoolantPurge` (r 18.5–25.5). **Layout change:** `T3_Console` moved from 10° to **52°** on the ring (r 24.6) so the lever is outside its own freeze sector (−45°…45°). Hazards: 3 drums at each `H1_FuelDrums_*`, one icicle cluster per `H2_Icicles_*`, the breaker on `H3_Breaker` (faces its 4 puddles around `H3_Puddles`).
