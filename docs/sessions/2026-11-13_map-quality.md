# Session report — 2026-11-13 — Vesper Peak map quality pass (owner request)

**Request (project owner):** "Make significant improvements to the map, both in design and environment.
Many of the rooms are dead empty, the quality is poor, and at spots you can see outside of the map."
Out-of-plan work after Step 16; recorded under *Proposed design changes* and the session history.

## What was wrong (measured)
- **Seeing outside the map.** A new survey test (`tests/visual/vesper_survey.gd`) samples player-reachable
  navmesh points in every zone and casts 1,600 rays from eye height; rays that escape to the void are
  clustered by where they leave the zone. Before: thousands of leak rays in Z03 (walkway roof wedge),
  Z09–Z13 (reactor-cavern wall openings wider than the vents/alcove behind them, the open gantry to the
  cavern, a 10 m void between the Z12 observation glass and the cavern, unwalled lift pit, a tunnel/ramp
  roof wedge in Z10, the space under the Lower Ring).
- **The map floated in fog.** Past the Courtyard's low walls, the Comms Array parapets and the station
  dock there was nothing; the distant "mountain ring" was a curtain of flat triangle teeth, fogged into
  a pale wall with a cloud layer slicing its peaks.
- **Empty, dark rooms.** 3–17 props per zone; ambient 0.4–0.55; the 54 m East Wing had 14 dim lights.

## What changed
- **Seals (geometry, nav-checked):** corridor walls/roofs lap 0.25 m past their ends and get joint
  pieces where two passages meet at an angle (`VesperZone.corridor`); Z13 rock pockets behind the N/S/E
  openings, feet below the ring at openings, a rock pit shaft + floor under the ring, WSW-spoke and
  shaft-balcony plugs; Z11 gantry tunnel; Z12 observation duct (dropped under the D11 ramp) and lift-pit
  walls; Z10 ramp header.
- **No sky underground:** `AtmosphereProfile.sky` (0 for Z09–Z13). `ZoneAtmosphere` switches the
  background to a dark rock colour and emits `sky_visibility_changed`; `VesperArt` hides the backdrop,
  terrain, cloud sea and searchlights, so any hairline crack reads as darkness.
- **Terrain massif (`scripts/vesper_terrain.gd`):** visual-only heightfield (2 m near, 10 m far):
  plateau under the complex, the summit under the Comms Array, west massif, east ridge, north valley,
  noise. Constraints are rasterised from the zones' own colliders: rock stays under every surface
  structure (with a 1.25 slope skirt), rises over buried passages, supports floors and climb pads, a
  snow berm behind the Courtyard's low walls, the gondola line kept clear. ~200 ms at load.
- **Mountain range:** the ring of triangle teeth is replaced by a ridged-noise polar heightfield
  290–720 m out, snow on gentle faces, aerial-perspective vertex colours, fog-free. The +62 m cloud
  layer moved to +240 m.
- **Furnishing (`VesperZoneArt._auto_furnish`):** walks every straight wall face and stands kit props
  where there is floor, the slot is inside a zone volume, nothing gameplay or already-authored is
  within ~2 m, the prop hits no collider and 1.4 m in front stays clear. Kits: sanatorium, ward (Z04),
  military, industrial, lab, cavern, exterior. 15 new procedural props (radiator, locker, barrel(s),
  rocks, rubble, papers, pipe stack, crate, pallet, trolley, sink, notice board, extinguisher, mop
  bucket, stalactites, rock pillar, scaffold, wall pipes, cluttered desk). ~240 props added map-wide.
- **Lighting:** `_auto_light` adds powered, unshadowed ceiling fixtures (one per ~55 m² per roofed room,
  counting existing lights; 57 added); indoor ambient ×1.6; Z04 patient-room bulbs, Z13 shaft lamps.
- **Z13 cavern:** rock outcrops on the wall, 26 stalactite clusters, pipe risers / crates / barrels /
  rubble between gameplay spots, vesperite crystals in the pit, 4 work lamps.

## Verification
- `tools/check.sh` green (226 unit tests). `test_vesper_*` integration 12 / 12 (gameplay marker
  baseline unchanged, art layer collision-free, landmark sightlines incl. the Z12 glass).
- `run_sim.sh nav_validate` PASS (0 uncovered, 70 spawners, 2,338 polygons); `run_sim.sh flow` PASS.
- `visual_tests.sh vesper_art` PASS on Vulkan/lavapipe: worst scenery view 1,291 draw calls (≤ 1,500;
  Step 13 was 1,103), crowd views ≤ 1,688 (≤ 2,000). Frames + `before_after.png` in
  `docs/screenshots/map_quality/`.
- Leak survey (`--survey-render=0`): underground zones from thousands of escaping rays to ≤ 30 per zone
  (residuals show dark rock). Remaining escapes are intentional exterior openings (Z01 dock, Z04
  balcony, Z07 parapets, Z08 stair to the Courtyard).

## Notes / follow-ups
- Furnishing is visual only (D-076): players and zombies pass through it, like the Step 13 props.
  Giving the larger pieces player-clip collision is a possible follow-up.
- The Z13 service shaft is still dim (dark stone + metal); readable but moody.
- Screenshots in this container now use lavapipe (Forward+); the OpenGL fallback caps 8 lights per
  mesh and makes batched zones look far darker than in game.
- Human: visual review of the new frames and a walk-through of every zone (AC-13.6-style).
