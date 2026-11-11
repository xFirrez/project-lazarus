# Project Lazarus — Style Guide (v1, Step 4)

> The visual identity for Vesper Peak and every later map. Each art task (Steps 5, 8–13, 15) checks its output against this page. The reference implementation is the look-dev scene `game/maps/_test/lookdev.tscn` (`--map=lookdev`); its five reference shots are in `docs/screenshots/step4/`.
> How assets are built and imported: [ART_PIPELINE.md](ART_PIPELINE.md). Map palette source: VESPER_PEAK §8.

## 1. Pillars

1. **Light and fog carry the look.** Stylized-realistic surfaces in flat palette colours. The mood comes from temperature contrast, volumetric fog and glow, not from texture detail.
2. **Readable silhouettes first.** Zombies, interactables and routes must read at 30 m in fog. Detail goes inside the silhouette.
3. **Every area has a dominant temperature and an accent of the other one** (VESPER_PEAK §8.1 contrast rule): cold courtyard with warm sanatorium windows; warm lobby with blue moon shafts.
4. **Original identity.** Generic period design (1950s Cold War research site in a Belle Époque sanatorium). No logos, insignia or silhouettes copied from other games or real units.

## 2. Palette

Albedo values are linear-ish sRGB swatches used by the shared materials (`game/content/materials/*.tres`). Keep albedo between 0.04 and 0.85; nothing is pure black or white.

| Area | Dominant | Accent | Light sources | Materials (ids) |
|---|---|---|---|---|
| Exterior night storm (Z01, Z06, Z07) | Navy `#0b1426`, desaturated teal `#2f4a55`, moon-white snow `#dbe5f7` | Warm windows `#ffad5c`, red beacons `#ff1a0a` | Moon (directional, cold `#9ebdff`, low angle), lamp posts (warm omni), searchlights (cold spot), red beacons | `stone_facade`, `cobble_snow`, `cobble_icy`, `metal_olive`, `canvas_olive`, `sandbag`, `ice`, `glass_lit` |
| Sanatorium interiors (Z03–Z05) | Amber `#c9874a`, faded rose wallpaper `#8c615e`, dark wood `#331f13` | Blue moon shafts `#8cb3ff` | Tungsten sconces (few shadowed), candles, moon shafts | `plaster_rose`, `wood_dark`, `marble_floor(_wet)`, `brass`, `glass_frosted` |
| Military additions | Olive drab `#40452a`, stencil white `#b3b3a1` | Hazard yellow `#d9b31a` | Caged bulbs, fluorescent tubes (flicker) | `metal_olive`, `canvas_olive`, `sandbag`, `metal_dark` |
| Maintenance (Z08–Z10) | Rust `#6b3a22`, soot `#1c1a18` | Furnace orange `#ff7a26`, emergency red | Furnace glow, sodium lamps, emergency red | `metal_dark`, `stone_grey`, `emissive_red` (+ Step 13 rust/soot variants) |
| Labs (Z11–Z12) | Clinical white / teal tile `#c7d9d4` | Red alarm, green vesperite leak | Fluorescents, red strobes | `marble_floor` variants, `glass_frosted`, `vesperite` (+ Step 13 tile set) |
| Reactor (Z13) | Black stone `#141414`, brass/copper | Vesperite green `#59ff73` (later white-blue) | Core emissive + glow, arc flashes, rim lights | `stone_grey`, `brass`, `vesperite` |

Zombie skin variants: `zombie_skin` (grey-green, base), `zombie_skin_pallid` (waxy, more wounds), `zombie_skin_frostbitten` (blue-violet cold rot). Eyes glow faint vesperite green, the series' signature.

## 3. Shapes, silhouettes and density

- **Silhouette rules:** zombies are hunched (spine pitched forward 15–25°), arms forward or hanging. Never a straight T or A pose in play. Players stand upright. Interactables (machines, wall-buys, the box) are the only objects with emissive panels at chest height. Nothing else in the world may use that read.
- **Proportions:** human scale 1.75–1.9 m. Doors 1.4 × 2.6 m, windows 1.2 × 1.4 m with a 0.9 m sill (barricades sit in the opening), storey height 4 m, railing 1.0 m.
- **Grid:** 2 m cells, 0.5 m sub-grid (kit, ART_PIPELINE §3). Gameplay space snaps to the grid. Organic dressing (snow drifts, debris) breaks it up on top.
- **Detail density:** high detail at eye level (0.5–2.2 m), simple above 4 m. Every 10 m of walkable space gets one focal prop (fountain, truck, machine).

## 4. Texel density, bevels and edges

- **Texel density target:** 256 px/m for environment trims and hero props. Most kit surfaces use **world-space triplanar detail** (`lazarus_surface` shader, `detail_scale` cycles/m), so density is constant by construction and pieces tile without seams or UVs. Unique textured assets (Step 13 hero props) use 256 px/m (512 px/m for the viewmodel: one 1024² atlas, ARCHITECTURE §11.2).
- **Bevels:** hard-surface props get a real geometric bevel (1–3 cm on props, 1.5–2 mm on weapons, 1 segment) so edges catch light. No bevels on kit walls (they meet flush).
- **Edge highlight / grime:** done with vertex colour, not textures. `Col.R` = grime (dirt collects low and in seams; `paint_grime()` in `tools/blender/lazarus_bpy.py`), multiplied with the world noise in the shader. Edges stay brighter because grime is low and in crevices.

## 5. Materials and shaders (`game/content/shaders/`, `game/content/materials/`)

| Shader | Use | Key parameters |
|---|---|---|
| `lazarus_surface` | Stylized PBR for everything solid: flat palette albedo × triplanar detail noise, vertex-colour grime, **triplanar snow accumulation** on up-facing faces, **wet / icy** floors (puddles from the noise), **wind sway** (`Col.G` weight) | `albedo`, `roughness`, `metallic`, `detail_scale/strength`, `grime_strength`, `snow_amount/threshold`, `wetness`, `ice`, `sway_strength` |
| `frosted_glass` | Windows: frost from the noise, transparent where clear; optional warm `glow_energy` for lit rooms seen from outside (then opaque) | `tint`, `frost_amount`, `glow_color`, `glow_energy` |
| `vesperite_energy` | The "energy" VFX language: green, additive, unshaded, scrolling noise + fresnel rim + pulse | `energy_color`, `core_color`, `energy`, `scroll`, `fresnel_power` |
| `zombie_skin` | Wrap diffuse + cold subsurface tint (flesh never goes black), object-space rot blotches, bruises and wet wounds (they ride with the animation), `Col.R` dirt, `flash` for hits | `skin_tint`, `rot_amount`, `wound_amount`, `pattern_seed`, `wrap`, `subsurface_strength` |

Rules: a new material is a new `.tres` on one of these shaders. Write a new shader only for a new *kind* of surface, and log it here. Every material carries `metadata/surface` (impact and footstep tag).

## 6. Lighting rules

- **Directional:** one per area (moon outside, none deep underground). Soft shadows, max distance 60 m.
- **Shadow-casting omni/spot lights:** at most **8 visible** on High (budget enforced by the `Graphics` autoload: lights in group `shadow_light`, highest `shadow_priority` meta wins; Low 2, Medium 4, High 8, Ultra 12). Everything else is a non-shadowed fill (window spill, beacons, candles).
- **Energies (AgX):** moon 0.9–1.0; tungsten sconce 2–2.5 (range 8 m); lamp post 2.6 (11 m); window spill 1.6 (7 m, no shadow); searchlight 9 (spot 7°); emissive panels 4–5 with glow.
- **Every lit window is a promise.** A warm window means a reachable, lit interior (or one later in the game).
- **Tonemap:** AgX on every environment preset; glow additive above threshold 1.0 (only emissives and hot lights bloom).
- **Environment presets** (`game/content/environments/`): `exterior_storm`, `interior_warm`, `underground`, `reactor`. Each sets AgX, glow, SSAO, depth/height fog, volumetric fog and a 1D colour-grading LUT. Zones override with these. Interiors inside an exterior scene carve the storm fog out with a negative-density `FogVolume` and get a `ReflectionProbe` (see the lobby corner).

## 7. VFX language

| Kind | Look | Colour |
|---|---|---|
| **Energy** (vesperite, wonder weapons, machines) | Additive, noise-scrolled, fresnel rim, pulsing | Green `#59ff73` → white core |
| **Fire / explosions** | Orange-to-black smoke, short bright flash | Orange `#ff7a26` |
| **Electricity** (Galvanics, traps, Conduit) | Thin jagged arcs, very short life, blue-white flash light | Blue-white `#cfe6ff` |
| **Cold / weather** | Camera-attached snow (`CameraSnow`), gust bursts, breath fog | White-blue |
| **Blood / flesh** | Dark red, matte (wet only in wounds), never neon | `#590808` |

Particles are GPU only and scale with the preset's particle density (group `density_scaled`).

## 8. UI typography direction (for Step 15)

- **Display face:** a condensed 1950s stencil / typewriter-military feel for titles and round numbers (open-licensed, e.g. OFL fonts; logged in ASSET_LICENSES).
- **Body face:** a clean humanist sans for prompts and menus (readability over theme).
- HUD colours: off-white `#e8e2d0` text, amber `#ffb347` for points and highlights, vesperite green for wonder-weapon and power states, red only for damage and danger. Colour-blind modes swap the palette (GAME_DESIGN §18).
- Diegetic touches: period stencils and lab labels in the world, not in the HUD.

## 9. Quality presets (summary; data in `game/content/quality/*.tres`)

| Preset | Render scale | AA | Shadows (dir/pos atlas, max lights) | SSAO | Vol. fog | Particles | Far plane |
|---|---|---|---|---|---|---|---|
| Low | 0.75 FSR 1 | FXAA | 1024 / 1024, 2 | off | off | 35% | 120 m |
| Medium | 1.0 | FXAA | 2048 / 2048, 4 | low | 48³ | 60% | 180 m |
| High | 1.0 | MSAA 2× | 4096 / 4096, 8 | high | 64³ | 100% | 250 m |
| Ultra | 1.0 | MSAA 4× | 8192 / 8192, 12 | ultra | 128×96 | 100% | 400 m |

All switch at runtime (`quality <id>` console command or the `video/quality_preset` setting). Only the renderer itself (Forward+ vs Compatibility) needs a restart.
