# Project Lazarus — Game Design Reference

> The authoritative reference for gameplay rules and tuning. All numbers are **starting values** — tune them during playtests (Step 16) and record changes in the *Tuning Log* (§19).
> Values here must match the data files (`game/content/**/*.tres`, `MapDefinition`). If they diverge, the data file wins and this document gets updated.

---

## 1. Vision summary

### 1.1 Pillars

1. **Feel first.** Movement and shooting are fast, readable and satisfying. Every hit is confirmed by sight and sound.
2. **From nothing to god-tier.** A run starts with a pistol and a handful of points and ends with upgraded wonder weapons, four perks and a hard-won route through the map.
3. **The map is the puzzle.** Which doors to open, where to train, which perks first, when to hit the Forge — map knowledge is the real progression.
4. **Fair danger.** Deaths come from the player's decisions, never from broken pathing, invisible spawns or inconsistent hitboxes.
5. **Friends make it better.** Co-op is the primary way to play; solo is fully supported and balanced.
6. **Dark atmosphere, playful heart.** Cold War horror dread, punctuated by jingles, garish machines and absurd weapons.

### 1.2 What the game is not

No campaign, no battle pass, no XP levels, no loadout unlocks, no microtransactions. The only persistent data: settings, local statistics (best round per map/player count), and Easter-egg completion badges.

### 1.3 Naming and originality

Project Lazarus is *its own* game in the round-based zombie survival genre. The mechanics follow the genre faithfully, but branded names, jingles, characters and iconic props belong to their owners, so we use original equivalents with the same function:

| Genre element (familiar term) | Project Lazarus name |
|---|---|
| Mystery Box | **The Relic Box** (omen: a cracked porcelain doll) |
| Pack-a-Punch | **The Lazarus Forge** |
| Perk-a-Cola machines | **Vigor Tonics** (1950s soda brand "Vigor Bottling Co.") |
| Juggernog | **Ironhide Stout** |
| Speed Cola | **Quickdraw Fizz** |
| Double Tap | **Twin-Fire Root Beer** |
| Stamin-Up | **Marathon Malt** |
| Quick Revive | **Second Wind Seltzer** |
| Deadshot Daiquiri | **Bullseye Bitters** |
| Mule Kick | **Pack Mule Cream Soda** |
| Ray Gun | **Mk.I Ray Pistol** (original retro design) |
| Monkey Bomb | **Drummer Decoy** (wind-up tin soldier) |
| Element 115 | **Vesperite** |
| Power-ups | Max Ammo, Insta-Kill, Double Points, Nuke, Carpenter, Fire Sale (descriptive terms, original icons) |

Display names live in definition files, so renaming is a data change. Audio jingles, VO lines and announcer are original.

---

## 2. Match structure

1. **Main menu → Solo / Host / Join → Map select (Vesper Peak) → Lobby** (character select, ready-up; solo skips the lobby).
2. **Spawn** in the Arrival Station with the starting loadout (§4.1) and **500 points**.
3. **Round 1** starts after a 5 s intro sting (wind, distant reactor pulse, title card).
4. Rounds repeat until all players are dead (bled out). Then **Game Over** screen with statistics.
5. Optional: Easter egg completion triggers an ending sequence, after which the game **continues** (players may keep surviving).

---

## 3. Player

### 3.1 Movement (metres, seconds)

| Parameter | Value | Notes |
|---|---|---|
| Walk speed | 4.6 m/s | Ground acceleration 45 m/s², friction 9 (snappy start/stop) |
| Sprint speed | 6.6 m/s | Sprint duration **4.0 s**, recharge to full in 3.0 s after 0.8 s delay; sprint ends on fire/ADS |
| Marathon Malt | sprint 7.1 m/s, walk 4.9 m/s, sprint duration 10 s, recharge 1.5 s | |
| Crouch speed | 2.4 m/s | Capsule height 1.8 → 1.1 m; smooth camera transition 0.15 s |
| Slide | Crouch while sprinting: 0.7 s slide, starts at 7.5 m/s decaying; can shoot while sliding (hip spread ×1.3); cooldown 1.0 s | Enables BO3-style evasion; no infinite slide-hopping |
| Jump | Apex 1.0 m, small air control (8 m/s² accel); mantle onto ledges ≤ 1.2 m when holding forward | Mantle avoids frustrating sticking on crates/vehicles |
| ADS move speed | ×0.55 weapon-dependent | |
| Weapon move multiplier | pistol 1.0, SMG 1.0, AR 0.95, shotgun 0.95, sniper 0.9, LMG 0.85, launcher 0.9 | |
| Step height | 0.35 m | Stairs feel smooth (camera step smoothing) |
| Mouse | Raw input, no acceleration, separate ADS multiplier, FOV slider 70–110 (default 90 horizontal-equivalent) | Viewmodel FOV independent (default 68) |

### 3.2 Health and damage

| Parameter | Value |
|---|---|
| Base max health | 100 |
| Ironhide Stout | 250 |
| Zombie swipe | 50 (base zombies; specials differ) → no Ironhide: downed on 2nd hit within regen window; with Ironhide: 5 hits |
| Regen delay | 3.0 s without damage, then regen at 100 HP/s |
| Hit feedback | Red vignette scaling with missing HP, directional damage indicator, camera punch, muffled audio + heartbeat below 50% |
| Self-explosive damage | Own explosives deal up to 60 (no Ironhide) — can down you at low HP. Friendly fire: off. |
| Fall damage | None below 5 m; 5–10 m scales to 50; never lethal from map geometry the player can reach normally |

### 3.3 Downed (last stand), revive and bleedout

- At 0 HP the player is **downed**: prone, can crawl at 1.2 m/s, holds a **last-stand pistol** (best pistol owned, else M1911 with 2 extra mags), can't use machines.
- **Lose 5% of points** (rounded down to 10) when downed. Lose **all perks** when downed (classic risk), *except* Second Wind's solo self-revive which consumes the perk.
- **Co-op revive:** teammate holds interact for **4.0 s** (2.0 s with Second Wind Seltzer). Reviver is vulnerable (can't shoot). Revived player returns with 50% HP, keeps weapons and points.
- **Bleedout timer:** 45 s. Bled-out players spectate and **respawn at the start of the next round** in the zone of the nearest living teammate, with the starting loadout and their points minus 10%. They lose their weapons.
- **Game over:** all players downed/bled out simultaneously, or solo player downed without Second Wind.
- Zombies ignore downed players (retarget to others); in solo with Second Wind, zombies scatter briefly while self-revive runs (5 s).

### 3.4 Melee and inventory

- Knife melee: 0.45 s, lunge 1.5 m toward a target in a cone, **damage 150** (one-hit through round 1–2), headshots don't multiply. Melee kill = 130 points.
- **Ice Axe** (wall-buy 3000, Comms Array): damage 1000, faster (0.35 s), longer lunge.
- Inventory: **2 primary slots** (3 with Pack Mule), **lethal** (Frag ×2, refills +2 per round, max 4), **tactical** (Drummer Decoy ×3 if acquired from the box; max 3), **placeable** (Tripmines, wall-buy).
- Weapon switch 0.35–0.6 s by class (Quickdraw Fizz ×0.5). Picking up a new weapon with full slots replaces the currently held one.

---

## 4. Weapons and gunplay

### 4.1 Starting loadout

M1911 pistol (8 + 32 reserve), knife, 2 Frag grenades, 500 points.

### 4.2 Damage model

- **Hitzone multipliers (default):** head ×4.0 (pistols ×3.0, snipers ×5.0, shotguns ×1.5), neck ×2.0, torso ×1.0, limbs ×0.75. Points distinguish head/neck/body kills.
- **Falloff:** each weapon has `range_min` (full damage) and `range_max` (min damage %).
- **Penetration:** each weapon penetrates `n` zombies (pistols 1, SMG 1, AR 2, LMG 3, sniper 4, shotgun pellets 1) losing 25% per target. Penetration of thin props (wood, sheet metal) allowed; concrete/stone stops bullets.
- **Spread:** hip spread cone grows with movement and sustained fire; ADS spread near-zero except shotguns. Hip-fire must be *usable* (classic Zombies hip-fire), not punishing.
- **Recoil:** per-weapon visual kick + pattern (mostly vertical, small random horizontal), recovering when firing stops.
- **Reload:** partial vs empty timings with an `ammo_added_at` point (cancelling after it keeps the ammo). Quickdraw Fizz ×0.5 reload time.

### 4.3 Weapon roster (Vesper Peak launch set)

Damage = base per bullet/pellet. Costs are wall-buy prices; ammo refill = half price; *Box* = Relic Box only. Final names subject to art. Upgraded (Forge) names are in §9.3.

| Class | Weapon | Dmg | RPM | Mag/Reserve | Source | Personality |
|---|---|---|---|---|---|---|
| Pistol | **M1911** | 40 | 400 semi | 8/32 | Start | Reliable starter; Forge version becomes dual grenade pistols |
| Pistol | **"Widow" .357 Revolver** | 160 | 140 semi | 6/48 | Wall 1000 | Heavy hitter, slow reload, high headshot |
| Pistol | **Mauser C96** | 50 | 600 semi | 10/80 | Box | Fast tap-fire |
| SMG | **MP40** | 40 | 550 auto | 32/192 | Wall 1000 | Accurate, all-rounder |
| SMG | **M3 Grease Gun** | 50 | 450 auto | 30/180 | Wall 1000 | Slow, punchy, low recoil |
| SMG | **Skorpion** | 35 | 850 auto | 20/200 | Box | Bullet hose, dual-wield when upgraded |
| SMG | **PPSh-41** | 40 | 950 auto | 71/284 | Box | Drum mag melts crowds; hard to control |
| AR | **M14** | 105 | 320 semi | 8/92 | Wall 500 | Classic starter-room rifle |
| AR | **M16** | 100 | 750 burst-3 | 30/120 | Wall 1200 | Precision burst |
| AR | **AK-47** | 110 | 600 auto | 30/240 | Box | High damage, strong recoil |
| AR | **FAL** | 120 | 500 semi | 20/160 | Box | Hard-hitting semi |
| AR | **G3** | 115 | 550 auto | 20/180 | Box | Penetration king |
| Shotgun | **Double-Barrel "Coachgun"** | 160×8 | 2-shot | 2/60 | Wall 500 | Devastating close, terrible reload |
| Shotgun | **Model 37 Pump** | 130×8 | 70 pump | 6/54 | Wall 1500 | Classic reliable pump |
| Shotgun | **"Thunderer" Auto-12** | 110×8 | 250 semi | 8/64 | Box | Room clearer |
| LMG | **RPD** | 110 | 700 auto | 100/400 | Box | Train-killer |
| LMG | **M60** | 130 | 550 auto | 100/300 | Box | Heavy, high penetration |
| LMG | **MG42** | 100 | 1200 auto | 125/375 | Box | Buzzsaw; slow ADS |
| Precision | **Kar98k (scoped)** | 400 | 50 bolt | 5/50 | Wall 1500 | Pierce lines of zombies |
| Precision | **Dragunov SVD** | 350 | 200 semi | 10/60 | Box | Semi-auto marksman |
| Explosive | **M72 LAW** | 1500 + splash 600 (r=4 m) | single | 1/20 | Box | Rocket, falloff splash |
| Explosive | **China Lake** | 900 + splash 500 (r=3.5 m) | 40 pump | 2/20 | Box | Bouncing grenade |
| Explosive | **Crossbow** (explosive bolt) | 750 + splash 700 (r=3 m, 1.5 s fuse) | single | 1/15 | Box | Sticky; attracts zombies when upgraded |
| Wonder | **Mk.I Ray Pistol** | see §7 | — | 20/160 | Box (rare) | |
| Wonder | **Lazarus Conduit** | see §7 | — | 24/96 | Buildable / Box after built | |
| Lethal | Frag grenade | 250 + splash 1200 at centre (r=5 m) | — | 2 | Start, refills | Cookable (3.5 s fuse) |
| Tactical | **Drummer Decoy** | attracts zombies 8 s, then explodes 2000 (r=4 m) | — | 3 | Box | |
| Placeable | **Tripmines** | 2000 splash (r=4 m) | — | 2 per round (refills) | Wall 1000 | |
| Melee | Ice Axe | 1000 | — | — | Wall 3000 | |

**Gunplay feel targets (acceptance in Steps 3 and 9):** every weapon distinguishable blind by sound; time-to-kill on a round-1 zombie with M1911 ≤ 3 body shots or 1–2 headshots; PPSh/RPD can clear a round-15 train with ammo management; Kar98k one-shot headshots through round 12.

---

## 5. Zombies

### 5.1 Base zombie

- **Health by round:** `hp(1) = 150`; rounds 2–9: `+100` per round (950 at round 9); rounds ≥ 10: `hp(r) = hp(r-1) × 1.1`; from round 55: growth ×1.05 (soft cap to keep very high rounds playable with Forged weapons). Insta-Kill ignores health.
- **Hitzones:** as §4.2. Limbs can be shot off by explosive/high-damage hits (cosmetic) and **legs by explosives** → crawler (keeps health; crawl 1.0 m/s, low attack). Crawlers are the classic "hold the round" tool.
- **Attack:** swipe 50 dmg, wind-up 0.45 s (telegraphed), range 1.4 m, cooldown 1.1 s. Lunge variant on sprinters (range 2.0 m).
- **Locomotion tiers (base speeds, ±8% jitter per zombie):**

| Tier | Speed | Appears |
|---|---|---|
| Shamble | 1.1 m/s | Round 1–3 all; mixed through round 6 |
| Walk | 1.7 m/s | Rounds 2–8 |
| Jog | 3.0 m/s | From round 4 (25%), majority by 8 |
| Run | 4.3 m/s | From round 7 (20%), majority by 12 |
| Sprint | 5.4 m/s | From round 13 (10%), 50% by 20, 75% by 30 |

  Players sprint faster (6.6) than sprinters (5.4), but not walk-faster — escape requires sprint management and pathing choices. The last 2 zombies of a round are promoted to Run if slower (prevents boring waits), unless the player has left a crawler.

- **Spawn behaviors:** climb through barricaded window (tear planks one at a time, 1.0 s each, ~0.8 s at sprint tiers), rise from ground (riser spots in exterior/ crawlspaces), drop from ceiling vents (Maintenance, Labs), burst through doors (scripted, specific spawners).
- **Variation:** 6 base models (orderly, nurse, patient, soldier, scientist, mountain engineer) × 3 material variants × attachments (helmets, glasses, gas masks, lab coats) + body-damage masks. Clothing-specific death VFX (lab coat tears, helmet pops off on headshot).
- **Audio:** idle groans (randomized, per-zombie pitch), aggressive sprint screams, attack vocal, footsteps by surface, barricade tearing, death. Max 10 voiced zombies at a time (priority by distance) to keep the mix clean.

### 5.2 Round quantities and pacing

- **Zombies per round:** `N(r, p) = round(base_p × f(r))`, `base_p = 24 + 6·(p − 1)`.
  - `f(1..5) = 0.25, 0.33, 0.54, 0.75, 1.0` → solo: 6, 8, 13, 18, 24.
  - `f(r ≥ 6) = (r/5) × (1 + 0.05·max(0, r − 10))` → solo r10: 48, r15: 75, r20: 144, r30: 288.
  - Cap: `N ≤ 300 + 75·(p − 1)`.
- **Alive cap:** 24 (1p), 28 (2p), 32 (3–4p).
- **Spawn interval:** 2.0 s at round 1, ×0.95 per round, minimum 0.35 s (co-op min 0.3 s).
- **Intermission:** 10 s (round-end sting ~6 s + quiet). Special round intermission: 12 s with warning build-up.
- **Spawn fairness rules:** never spawn within 8 m of a player or in their direct line of sight (risers excluded when > 12 m); only from active zones; spawns are distributed across players in co-op.

### 5.3 Special enemy: **Galvanics**

Test subjects fused with vesperite electrodes. Fast, leaping, glowing.

- **Special rounds:** first on round **5–7** (random), then every **4–6 rounds** (random). Announced by 8 s build-up: storm intensifies, lights flicker green, an energy pulse rolls through the map, distinct music.
- Count: `6 × p` on the first special round, `+2 × p` each subsequent, cap 24×p (spawned max 12 alive at once).
- HP: 400 first special round, then ×1.35 per special round (soft cap equal to base zombie hp at that round ×0.6).
- Behavior: sprint 6.0 m/s, leap attack (3–6 m, 0.6 s telegraph with crackle), 40 dmg; on death they detonate a small electric burst (3 m, 30 dmg to players) and can disable a nearby barricade plank.
- Spawn: arrive through **energy rifts** that crackle 1.5 s before (telegraph), placed throughout the map near players.
- **Reward:** the last Galvanic of the round always drops **Max Ammo**.
- Galvanics also appear in small numbers (1–2) mixed into normal rounds from round 20.

### 5.4 Boss: **The Warden** (Easter egg finale, plus rare late-round appearance)

Colonel Aldric Haemmer, reanimated in armored reactor gear. 3 m tall brute.
- Health = 25 × base zombie health of the current round (co-op ×p), with armored plates (75% reduction) until the vesperite core on its back is exposed by breaking 3 plates.
- Attacks: ground slam (telegraphed shockwave), charge, summon pulse (spawns 4 zombies).
- Outside the Easter egg: can appear once per 10 rounds from round 25 (small chance), drops a guaranteed Forge-voucher power-up ("Free Upgrade") on death. This is a stretch feature — see DEVELOPMENT_PLAN Step 12 checkpoints.

---

## 6. Points economy

### 6.1 Earning

| Action | Points |
|---|---|
| Non-lethal hit (bullet) | 10 |
| Kill (torso/limb) | 60 |
| Kill (neck) | 70 |
| Kill (head) | 100 |
| Melee kill | 130 |
| Explosive/trap/wonder-weapon kill | 50 (traps give points only to the activator, 50 per kill) |
| Barricade plank repaired | 10 (max 500 per player per round) |
| Nuke | 400 per player |
| Carpenter | 200 per player |
| Galvanic kill | 100 (+ hit points) |
| Hidden lore item | 0 (story only) |

Double Points doubles everything except Nuke/Carpenter bonuses. Hit points from multi-pellet shots are counted once per shot per zombie.

### 6.2 Spending (Vesper Peak)

| Item | Cost |
|---|---|
| Doors/debris | 750 – 2000 (see VESPER_PEAK.md) |
| Wall weapons | 500 – 1500; ammo = ½ price; **upgraded ammo = 4500** |
| Relic Box | 950 (Fire Sale: 10) |
| Perks | 500 – 4000 (§8) |
| Lazarus Forge | 5000 (all weapons, including wonder weapons) |
| Traps | 1000 (power required) |
| Gondola ride | 500 |
| Ice Axe | 3000 |
| Tripmines | 1000 |

### 6.3 Economy targets (validated in Step 16 via simulated + human runs)

- Typical solo run with competent play: ~4,000 points by end of round 5 (enough to open 2–3 doors + 1 wall-buy), first perk round 6–8, power on round 7–10, Forge unlocked round 10–14, first upgrade ~round 12–15.
- In co-op, players should compete mildly for points but sharing doors means total map access arrives earlier.

---

## 7. Wonder weapons

### 7.1 Mk.I Ray Pistol

- Fires a green plasma bolt at 55 m/s (visible travel), RPM 180 semi, mag 20, reserve 160.
- Direct hit 1000 damage; splash 1200 at centre falling off to 300 at r = 3.0 m; self-splash 25 (no down at full HP, can down at low HP — respect it).
- Visuals: glowing projectile with trail, light flash, emissive splash decal, zombies hit disintegrate green on kill (mixed with gibs). Distinctive rising "pew-whoom" sound and reload hum.
- **Box weight:** rare (see §10.3). Only one per player.
- **Forge upgrade — "Nova Mk.II":** red-orange plasma, 40 mag/200 reserve, direct 1500, splash 1800, splash radius 3.5 m, bolts *bounce once* off walls.

### 7.2 Lazarus Conduit

An experimental crank-capacitor rifle with glass vesperite coils.

- **Primary fire:** charge-less arc beam; strikes first zombie within 25 m (aim-assisted cone 4°) then **chains to up to 5 more** zombies within 6 m of the previous, each jump dealing 75% of previous. Base 1200 on first target. RPM 120, 24 shots/96 reserve.
- **Electrocution:** chained zombies are **stunned 1.5 s** (spasm animation, sparks, crackle); kills char/burst.
- **Alt behavior:** holding fire 1.0 s releases a "pulse" (consumes 3 ammo) that stuns everything within 8 m for 3 s without damage — escape tool.
- **Acquisition:** build from 3 parts (VESPER_PEAK §8) at the Lab Workbench (first build only); after it has been built once, it joins the Relic Box pool. One per player.
- **Forge upgrade — "Lazarus Requiem":** chains to 10 targets, 8 m jumps, no falloff in damage for the first 4 jumps, stun 2.5 s, 36 mag/180 reserve, killed zombies emit a secondary small arc to 2 more targets. Required for an Easter egg stage (soul charging).

---

## 8. Vigor Tonics (perks)

- **Perk cap: 4.** (Easter egg reward removes the cap.) All machines need **power** except **Second Wind Seltzer**.
- Purchase: interact → 3.0 s drinking animation (weapon lowered, can't fire; Quickdraw speeds weapon raise only) → icon appears on HUD with a stinger. Each machine plays its own original jingle when interacted with idly (chance-based) and has a unique neon/light color.
- All perks are lost when downed (except Second Wind's solo self-revive charge consumed as described).

| Tonic | Cost | Effect | Machine identity |
|---|---|---|---|
| **Ironhide Stout** | 2500 | Max HP 100 → 250 | Red, riveted iron, stout keg tap |
| **Quickdraw Fizz** | 3000 | Reload ×0.5, weapon swap ×0.5, equipment use faster | Green, art deco lightning bolts |
| **Twin-Fire Root Beer** | 2000 | Fire rate ×1.33, and every hitscan bullet is fired twice (×2 effective damage; ammo consumed once). Projectile/wonder weapons get fire rate only | Amber, double barrel tap |
| **Marathon Malt** | 2000 | Movement +7%, sprint duration 10 s, faster recharge | Yellow-orange, runner silhouette |
| **Second Wind Seltzer** | 500 solo / 1500 co-op | Solo: auto self-revive (3 uses per match; machine vanishes after 3rd). Co-op: revive teammates in 2 s | Light blue, medical cross, works without power |
| **Bullseye Bitters** | 1500 | Hip spread −40%, aim snaps to head when ADS on zombies (mild, 0.15 s), headshot damage +25% | Teal, target dial |
| **Pack Mule Cream Soda** | 4000 | Third weapon slot (lost along with the third weapon when downed) | Cream/green, mule head mascot |

---

## 9. Lazarus Forge (upgrade machine)

### 9.1 Unlock (Vesper Peak)

Restore main power → activate three **Resonance Relays** (Communications Array, Operating Theater, Containment Labs) → the reactor stabilizes and the **Reactor Bridge** extends, giving access to the Forge platform. Each relay: hold interact 3 s, then defend it for 20 s while it spins up (zombies are drawn toward it; if all players leave its zone it pauses). See VESPER_PEAK §7.

### 9.2 Use

- Cost **5000**. Player inserts held weapon → 5 s sequence (reactor arc lightning, hammering/forging audio, green-to-gold flash) → weapon emerges and floats for 15 s; only the owner can take it. If not taken, it's lost (classic).
- Machine is single-use at a time; others see "In use".
- Upgraded weapons: damage ×2 (base), mag ×1.5–2, reserve ×2, unique name, **unique camo** (animated vesperite-gold pattern), upgraded firing sound layer, and where noted a **behavior change**.
- Fire Sale does not affect the Forge (box only).
- Ammo for upgraded wall weapons: buy at the wall for 4500.

### 9.3 Upgrade table (behavior highlights)

| Base | Upgraded name | Behavior change |
|---|---|---|
| M1911 | **"Gemini" Twin Grenadiers** | Dual-wield grenade-firing pistols (explosive, low splash) — last-stand lifesaver |
| .357 Revolver | **"Black Widow"** | Rounds pierce 4, headshot kills chain a small burst |
| Mauser C96 | **"Kaiser's Fury"** | Full-auto, 30 mag |
| MP40 | **"The Afterburner"** | 64 mag, incendiary-tinted tracers |
| M3 Grease Gun | **"Grease Fire"** | Burn damage over time (minor) |
| Skorpion | **"Black Scorpions"** | Dual-wield |
| PPSh-41 | **"Reaper's Choir"** | 115 drum, fire rate +15% |
| M14 | **"Mnemonic"** | 3-round burst, 20 mag |
| M16 | **"Skullcrusher"** | Underbarrel grenade launcher (alt-fire) |
| AK-47 | **"Iron Curtain"** | Bullets pierce +2 |
| FAL | **"Willful Destroyer"** | Full-auto |
| G3 | **"Glacier Breaker"** | Hits slow zombies 20% for 1 s |
| Coachgun | **"Two Graves"** | Explosive slugs |
| Model 37 | **"Pump Action Requiem"** | Pellets ×1.5, faster pump |
| Auto-12 | **"Storm of Thunder"** | 16 mag, dragon's-breath visuals |
| RPD | **"Red Purge Doctrine"** | 150 mag |
| M60 | **"Sixty Sins"** | 200 mag, +2 penetration |
| MG42 | **"Banshee"** | 200 mag, reduced recoil |
| Kar98k | **"Avalanche"** | Explosive headshots |
| Dragunov | **"Dread Novice"** | Thermal-tinted scope highlighting zombies |
| M72 LAW | **"L.A.W. of Averages"** | Micro-cluster rockets, 3 per mag |
| China Lake | **"China Doll"** | Impact detonation, 6 mag |
| Crossbow | **"Lure of the Lantern"** | Bolts attract zombies (like a Decoy) then explode |
| Ray Pistol | **"Nova Mk.II"** | §7.1 |
| Lazarus Conduit | **"Lazarus Requiem"** | §7.2 |
| Knife/Ice Axe | — | Not upgradable |

---

## 10. The Relic Box

### 10.1 Behavior

- An iron-banded steamer trunk stamped with occult and military markings; while active, a **green light pillar** rises from it, visible across the map through the storm.
- **950 points** → lid opens with a bell chime and music-box melody; weapon models **cycle** rapidly above it (decelerating), for 4.5 s, landing on the result. The weapon floats for **12 s**, then sinks back. Only the **spinner** may take it. Taking it replaces the held weapon (or fills an empty slot).
- Can't roll a weapon you already have; can't roll a wonder weapon you already have; can't roll an item blocked by conditions (e.g., Conduit before it's been built).

### 10.2 Relocation

- The box has a starting location (Sanatorium Lobby) and 6 other locations.
- After the 4th use at a location, each spin has a chance to show the **porcelain doll** instead of a weapon: 15%, +15% each subsequent spin (max 75%), reset on move. Never on the first 4 spins at a location; never during Fire Sale.
- Doll result: refund 950, doll laughs (creepy original sound), lid slams, the box rises into the green light and vanishes; 4 s later it appears at a random other location, the light pillar announcing it.

### 10.3 Weighted pool (Vesper Peak, defaults)

Weights relative; computed after removing ineligible entries.

| Tier | Items | Weight each |
|---|---|---|
| Common | MP40, M3, M14, M16, Coachgun, Model 37, Kar98k, Revolver | 8 |
| Standard | Mauser, Skorpion, PPSh, AK-47, FAL, G3, Auto-12, Dragunov, Crossbow, China Lake | 6 |
| Heavy | RPD, M60, MG42, M72 LAW | 4 |
| Tactical | Drummer Decoy | 5 |
| Wonder | Mk.I Ray Pistol | 1.5 |
| Wonder | Lazarus Conduit (after first build) | 1.0 |

Bad-luck protection for wonder weapons: each spin without one adds +0.1 weight to wonder entries (per player), reset when the player gets one. (Keeps the box exciting without guaranteeing.)

### 10.4 Fire Sale

All box locations become active for 30 s (each with its light pillar), box cost 10, no doll results.

---

## 11. Power-ups

- **Drop chance:** each zombie kill rolls for a drop; the system targets about **4 drops per round early, scaling with total kills**: implemented as an accumulating score: every kill adds the points it earned to a counter, and when the counter exceeds the current threshold a drop spawns at the kill location (if that spot is on the navmesh and reachable) and the counter resets. Threshold starts at 2000 and grows ×1.14 per drop this match, with growth stopping after round 20. Max 4 drops per round. Kills by traps don't drop.
- **Selection:** shuffled "bag" of the 6 types (each appears once before repeats); Fire Sale only after the box has moved at least once; Carpenter only when ≥ 5 planks are missing; Nuke not on the first 3 rounds.
- **Presentation:** glowing rotating icon (original designs, gold/green), bobbing 0.3 m, sparkle particles, ground light. Lifetime 26 s, blinking during the last 6 s. Pickup: VO announcer line (original), sting, HUD icon with circular timer (for timed ones).
- Effects are **global** (all players).

| Power-up | Effect | Duration |
|---|---|---|
| Max Ammo | Refill reserve + lethals for all players (magazines not refilled; downed players also) | — |
| Insta-Kill | Every zombie dies in one hit (bosses take 10× damage instead) | 30 s |
| Double Points | All points ×2 | 30 s |
| Nuke | Kills all zombies currently alive (they still count; staggered over 2 s with white flash), 400 points per player. Kills don't drop power-ups. | — |
| Carpenter | Rebuild all barricades, 200 points per player | — |
| Fire Sale | §10.4 | 30 s |
| *Free Upgrade* (special) | Next Forge use free — only from bosses/Easter-egg events | until used |

Stacking: picking the same timed power-up resets its timer.

---

## 12. Barricades, doors and traps

- **Barricades:** 6 planks; zombies tear 1 plank per action; players rebuild 1 plank per 0.5 s hold (continuous while holding). Points per §6.1. Zombies can attack through a partially broken window (swipe through bars at range 1.6 m).
- **Doors/debris:** purchase is shared world progress — whoever pays, everyone benefits. Cost displayed on prompt. Opening plays a distinct animation (debris collapses, door blows open with steam, cable-car gate retracts).
- **Traps (generic rules):** cost 1000, require power, active 25 s, cooldown 60 s, kill all zombies passing through (Galvanics take 50% max HP per second), and **damage players** (downs non-Ironhide players in ~1 s; Ironhide survives ~2 s). Activator gets 50 points per trap kill. Activation lever has a light that shows ready (green) / active (red) / cooling (amber).

---

## 13. Co-op rules

| Topic | Rule |
|---|---|
| Players | 1–4. Each has independent points, weapons, ammo, perks, equipment. |
| Shared progress | Doors, power, relays, Forge unlock, traps, buildables, box location, quest state, round. |
| Scaling | Zombie count (§5.2), alive cap, Galvanic count, Warden health. Health per zombie does **not** scale with players. |
| Box/Forge | Only the user may take their result. |
| Power-ups | Global effect; anyone may pick up. |
| Downed | §3.3. Teammate HUD shows a downed icon + bleedout ring + distance; a world-space marker visible through walls. |
| Revive | Hold 4 s (2 s with Second Wind); reviving player gets no points (prevents farming) but a "Revives" stat. |
| Late join | Host option (default **on** for friends): joiner spawns at next round start with 500 + 250×round points (max 5000), starting loadout. |
| Reconnect | A disconnected player's full state is retained for the rest of the match; on rejoin they respawn at next round start with it intact (perks retained only if they weren't downed). |
| Host leaves | Match ends for all with a summary screen (no host migration). |
| Player identification | Each character has a color (white, blue, yellow, green) used in HUD points list, name tags (fade with distance), outlines when occluded (subtle), and ping system. |
| Ping | Quick ping (middle mouse/D-pad): marks a location, item, or "Box is here" with contextual VO. |
| Friendly fire | Off. Explosives don't hurt teammates. |
| Communication | No built-in voice chat in the baseline (friends use Discord etc.); Steam voice is a stretch goal. |

---

## 14. Characters

Four original playable characters (cosmetic + personality). Each has a short bio, a color, and a set of contextual quips (box result, perk drink, low ammo, downed, revive, kill streak, Easter egg reactions). VO is a **scope risk** — baseline ships with text-subtitled radio-style lines using placeholder TTS or human-recorded lines; see DEVELOPMENT_PLAN Step 15.

| Character | Background | Color |
|---|---|---|
| **Major Ruth Calloway** (USA) | OSS veteran turned CIA cleaner, sent to erase evidence. Dry, sardonic. | White |
| **Pyotr "Petya" Orlov** (USSR) | Defected Soviet engineer who helped build the reactor. Guilty, superstitious. | Blue |
| **Anneliese Brandt** (Switzerland) | Mountain guide who knows every path on Vesper Peak; her brother vanished there. Fierce, practical. | Yellow |
| **Dr. Julian Ashcombe** (UK) | Disgraced psychologist who corresponded with the Lazarus team. Unnervingly cheerful. | Green |

---

## 15. HUD and UI rules

- **Round counter** (bottom-left): large stenciled red numerals with a chalky, hand-painted edge that bleed/flicker on round change; round 1–5 shown as tally strokes, then numerals (our own visual language: red ink-stamped tallies on paper texture). Round change: numerals pulse white→red with the transition sting.
- **Points** (bottom-right): own points large; teammates' points stacked above in their colors. Gains float up (+10, +100) and deductions in red.
- **Weapon / ammo** (bottom-right below points): weapon name, mag / reserve, lethal + tactical icons with counts, ammo color shifts red at < 20% mag.
- **Perks** (bottom-left above round): bottle-cap icons in acquisition order.
- **Power-ups** (bottom-centre): icon + countdown ring.
- **Prompts** (centre): "Hold [F] to buy M14 [500]" / "Hold [F] for Ammo [250]" / "Requires Power" / "Hold [F] to Revive Anneliese".
- **Hit markers** (centre): white tick for hit, red X for kill, distinct for headshot.
- **Damage:** red vignette + directional arcs.
- **Teammates:** names above heads, downed markers, out-of-sight icons on edge of screen when downed.
- **Compass/minimap:** none (classic). Map learning is part of mastery. The pause menu shows a stylized hand-drawn facility map with zones you've visited (QoL, helps new players).
- **Pause menu:** solo pauses the game; co-op shows menu without pausing.
- **Game over:** "YOU SURVIVED N ROUNDS", slow-motion fade, per-player table: kills, headshots, downs, revives, points earned, doors opened, perks drunk, box spins, Easter egg progress, time played. Local best round per player count saved.

---

## 16. Audio direction

- **Ambience layers per zone:** exterior wind/storm (gusts with stereo pans), interior creaks, electrical hum, distant machinery thumps, reactor heartbeat deep in the mountain (gets louder closer to the reactor and pulses at round transitions).
- **Weapons:** layered (mechanical + body + tail), with interior/exterior tails and distance variants. Reload sounds keyed to animation events. Headshot "tick", kill thud, Forge-upgraded shimmer layer.
- **Zombies:** §5.1. Spatial with occlusion low-pass.
- **Machines:** each tonic machine has an original jingle (30–45 s) + purchase burp/bottle sounds; Box has its music-box melody; Forge has industrial hammering + choir swell.
- **Round transitions:** round start = low brass/cello swell with distorted children's choir hum; round end = descending piano + bells. Special round = siren, radio static and a distorted announcement.
- **Music:** mostly silence/ambience during rounds (classic), dynamic low drone layer intensifying with zombie density; Easter egg song (hidden, original, rock/industrial) triggered by finding 3 music boxes.
- **Announcer:** an original "Voice of the Mountain" (layered, whispery) for power-up callouts and round 1 intro.
- Mix priorities: player's own weapon > nearby zombie attacks > hit/kill feedback > power-up VO > teammate weapons > ambience.

---

## 17. Difficulty and fairness checklist

1. Zombie wind-ups are always telegraphed by animation and sound.
2. No spawns in view or within 8 m.
3. Attack range never exceeds visual reach (hitbox ≤ 1.6 m).
4. Navigation must reach players anywhere they can stand; "safe spots" where zombies can't path are bugs (except intentional, limited ones: none).
5. Desync tolerance: in co-op, damage is resolved on the host using the host's position of the player plus a 0.25 m grace — no hits "from across the room" due to lag.
6. Late rounds stay hard via density/speed, not via unavoidable damage.

---

## 18. Settings and accessibility

Video presets (Low/Medium/High/Ultra + individual: resolution scale/FSR, shadows, volumetric fog quality, SSAO, glow, particle density, view distance), V-sync, FPS cap, FOV, viewmodel FOV, motion blur (off by default), camera bob scale, screen shake scale; audio sliders per bus; mouse sensitivity/ADS multiplier/invert; full key rebinding; gamepad sensitivity, aim slowdown toggle; toggle vs hold for ADS/crouch/sprint; colorblind modes for HUD colors; subtitles for VO; HUD scale.

---

## 19. Tuning log

| Date | Step | Parameter | Old → New | Reason |
|---|---|---|---|---|
| 2026-11-11 | 0 | (initial values) | — | Planning baseline |
| 2026-11-11 | 2 | Values not specified in §3.1 (new, in `content/player/player_tuning.tres`) | — → gravity 20 m/s², stop speed 1.5 m/s, coyote 0.1 s, jump buffer 0.12 s, slide end speed 3.0 m/s, slide steer 2 rad/s, mantle 0.32 s, eye height 1.62 / 0.95 (crouch) / 0.80 (slide) m, bob 1.8 Hz × 0.045 m, strafe tilt 1.2°, pitch limit 89°, shake max 3°, gamepad look 220°/s, deadzone 0.15, curve 2.0; host validation 10.5 m/s horizontal, 12 m/s up, 4 m teleport, 1.5 m slack | Step 2 controller needed concrete values; all live-tunable with `tune` and pending the AC-2.7 feel review |
| 2026-11-11 | 2 | Sprint restart rule | — → after exhausting stamina, sprint must be released and needs ≥ 10% stamina to restart | Prevents sprint stutter when holding Shift at 0 stamina |
| 2026-11-11 | 3 | Weapon values not given in §4 (new, in `content/weapons/<id>/<id>.tres`) | — → falloff full/min range (m) and min %: M1911 12/30/60%, MP40 15/35/60%, Model 37 6/18/30%, Kar98k 40/100/80%; reload partial/empty (ammo-in): M1911 1.6 (1.15) / 2.0 (1.35) s, MP40 2.2 (1.5) / 2.8 (1.9) s, Kar98k 2.6 (1.9) / 3.0 (2.3) s, Model 37 per shell 0.4 + 0.5/shell + 0.45 s; raise/lower: 0.35/0.25, 0.45/0.3, 0.5/0.35, 0.6/0.4 s; ADS 0.15 / 0.22 / 0.25 / 0.32 s (Kar98k scope zoom ×0.35 FOV); hip spread 1.6 / 2.2 / 1.5 (aim cone) / 4.0°, Model 37 pellet cone 4°; recoil ≈1.5° / 0.55° per shot / 4.5° / 5° vertical; neck ×2.0 (Model 37 ×1.25); knife reach 1.1 m + 1.5 m lunge in a 35° cone | Step 3 needed concrete values; all live-tunable with `wtune`, pending the AC-3.7 feel review |
| 2026-11-11 | 3 | Frag damage model | "250 + splash 1200 at centre" → linear splash 1200 (centre) to 250 (5 m edge); thrower takes up to 60 | See PROGRESS *Proposed design changes* |
| 2026-11-11 | 3 | Thin-prop penetration | — → −25% damage per wood / sheet-metal prop, max 2 props | §4.2 had no number |
| 2026-11-11 | 3 | Reload / fire rules | — → sprinting doesn't cancel a reload; a semi-auto click up to 0.1 s early is buffered | Feel decisions (Step 3 report) |
| 2026-11-12 | 6 | §5.2 worked example "solo r15: 75" | 75 → 90 (formula unchanged) | The stated formula gives 24 × 3 × 1.25 = 90; data follows the formula (`test_round_curve.gd`) |
| 2026-11-12 | 6 | Tier mix per round (new, `content/rounds/default_round_curve.tres`) | — → keyframes r1 100 % shamble; r2 80/20 shamble/walk; r4 35/40/25 (jog); r7 0/30/50/20 (run); r8 jog 55 %; r12 run 60 %; r13 sprint 10 %; r20 sprint 50 %; r30 sprint 75 %; linear between | §5.1 table gives only anchors |
| 2026-11-12 | 6 | Interaction holds (new) | — → doors / wall-buys 0.35 s hold; barricade rebuild 0.5 s per plank continuous; revive radius 2.0 m; window swipe range 1.6 m with the 0.45 s wind-up | §12 / §3.3 give no hold for purchases |
| 2026-11-12 | 6 | Bleedout timer while being revived | — → paused while a teammate holds revive | Classic behaviour; §3.3 silent |
| 2026-11-12 | 6 | Coachgun / M14 values not in §4.3 | — → Coachgun rpm 300 (two quick shots), reload 3.2 s, falloff 5/15 m; M14 falloff 25/60 m 70 %, penetration 2, reload 2.4/2.9 s | Wall-buys added in Step 6 |
