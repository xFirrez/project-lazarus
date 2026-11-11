# Project Lazarus — Art & Asset Pipeline (v1, Step 4)

> How 3D assets get from script (or an artist's Blender file) into the game. Visual rules live in [STYLE_GUIDE.md](STYLE_GUIDE.md). Every third-party file goes in [ASSET_LICENSES.md](ASSET_LICENSES.md).

## 1. Toolchain

| Tool | Version | Where |
|---|---|---|
| Blender | 4.2+ (container: **Blender 5.3 as the `bpy` Python module**, `pip install bpy`) | `tools/blender/` |
| Godot | 4.7.2 (pinned) | `game/` |
| glTF 2.0 binary (`.glb`) | the only interchange format | `game/content/**` |

`tools/blender/check_install.sh` prints the Blender the scripts will use. `tools/blender/_run.sh` runs a generator with `$BLENDER` / `blender` on the PATH (`blender -b --python …`) or, failing that, `python3` with the `bpy` module. Both give the same output.

## 2. Generators (all scripted, deterministic)

| Script | Output | Wrapper |
|---|---|---|
| `kits/build_kit.py` | `game/content/kits/vesper/*.glb` + `kit_manifest.json` (16 pieces) | `build_kit.sh [piece…]` |
| `props/build_props.py` | `game/content/props/<id>/<id>.glb` (fountain, truck, sandbags, lamp post, drum, crate, machine placeholder) | `build_props.sh [prop…]` |
| `characters/build_zombie.py` | `game/content/characters/animations/zombie_anims.glb` (12 clips), `game/content/enemies/zombie/zombie_orderly.glb` | `build_characters.sh` |
| `weapons/build_m1911.py` | `game/content/weapons/m1911/m1911_{viewmodel,world}.glb` | `build_weapons.sh` |
| everything | — | `build_all.sh` |
| `tools/lookdev/build_lookdev.gd` (Godot) | `game/maps/_test/lookdev.tscn` | `tools/lookdev/build_lookdev.sh` |

Shared helpers: `tools/blender/lazarus_bpy.py` (scene reset, palette preview materials, box / cylinder / sphere / prism builders, collision helpers, vertex-colour grime and sway weights, join, deterministic export).

**Determinism.** No unseeded randomness. Grime noise is seeded per object name (CRC32), `PYTHONHASHSEED=0` is set by `_run.sh`, colours are per-vertex, and meshes are triangulated before export. Re-running a generator reproduces the same geometry, colours and triangles. Pieces with several materials joined into one mesh can still come out with their triangles in a different *order* (a glTF exporter detail), so compare content, not bytes. Generated GLBs are committed as **normal git blobs, not LFS** (`.gitattributes` exemptions: the cloud sessions' git proxy rejects LFS uploads), so CI and other sessions never need Blender. Hand-authored binaries still go to LFS; a cloud session cannot push those (owner task).

## 3. Modular kit conventions (Vesper kit v1)

- **Grid:** 2 m cells, 0.5 m sub-grid, storey height 4 m. Pieces snap at 2 m spacing with no gaps (`tests/integration/test_kit_grid.gd`).
- **Origins:** walls at the bottom centre of the wall line, spanning x ∈ [−1, 1], 0.25 m thick, centred on the line. Their outside (stone details, sills) faces Godot +Z. Floors have their top at y = 0 and span x, z ∈ [−1, 1]. Stairs rise 2 m over a 4 m run toward −Z (two flights + a 2 m landing = one storey).
- **Pieces:** `wall_2m`, `wall_2m_exterior`, `wall_window_2m(_exterior)` (1.2 × 1.4 m opening, sill 0.9 m), `window_glass_2m(_frosted)` (glazing insert), `wall_door_2m` (1.4 × 2.6 m), `floor_2m(_exterior)`, `stairs_2m`, `pillar_corner`, `railing_2m`, `pipe_2m`, `pipe_elbow`, `trim_baseboard_2m`, `trim_crown_2m`.
- **Sockets:** empties named `Socket_<what>[_n]` survive as `Node3D`s: `Socket_Barricade_0..5` (plank transforms on the outside face) and `Socket_WindowClimb` in window walls, `Socket_Door` in door walls, `Socket_Light` / `Socket_Interact` on props.
- **Collision:** invisible boxes / hulls named with Godot import hints: `-convcolonly` (convex, preferred) or `-colonly` (trimesh). Wall colliders overlap the neighbouring piece by 5 mm at the piece edges so seams are never zero-width cracks. Stairs use one smooth convex ramp (nav- and player-friendly), and floors are flat slabs.
- **Surface tags:** a `surface` custom property on a collider (exported as a glTF extra) becomes the `StaticBody3D`'s `surface` meta → `SurfaceTags` → impacts and footsteps. Tags: concrete, metal, wood, snow, gravel, tile, flesh.
- **Budgets:** 50–800 triangles per kit piece (ARCHITECTURE §11.2). Every piece is one joined mesh, so a piece costs one draw call per material.

## 4. Godot import (automatic)

- **Defaults** (`[importer_defaults]` in `project.godot`): every scene import runs `res://core/art/post_import.gd`, generates LODs, shadow meshes and tangents, and imports animations at 30 fps. Textures default to VRAM-compressed with mipmaps.
- **Material remap:** a material named `M_<id>` in Blender is replaced on import by `res://content/materials/<id>.tres` (missing ids are reported as import warnings). In Blender, only name and preview colour matter. The look is defined once in Godot.
- **Extras:** `surface` → collider meta, `cast_shadow: false` → shadows off for that mesh.
- **Naming:** files and ids are `snake_case` (`truck_cargo.glb`). Nodes are `PascalCase` (`Socket_Barricade_0`, `ArmsMesh`). Do not rename imported nodes that code looks up (`Mag`, `Action`, `Sight`, `Muzzle`, `Eject`, `Lantern`, `Socket_*`).
- **LODs:** generated by the importer (`meshes/generate_lods`). Distant set dressing also uses `visibility_range_*` in scenes. The quality preset's `mesh_lod_threshold` controls how early LODs switch.

## 5. Characters and animation (retargeting)

- **Skeleton:** bones use **Godot's `SkeletonProfileHumanoid` names** (`Hips`, `Spine`, `Chest`, `UpperChest`, `Neck`, `Head`, `Left/RightShoulder`, `UpperArm`, `LowerArm`, `Hand`, `UpperLeg`, `LowerLeg`, `Foot`, `Toes`). Rest pose is a T-pose facing Blender −Y (Godot +Z).
- **BoneMap:** `game/content/characters/humanoid_bone_map.tres` (profile `SkeletonProfileHumanoid`, identity mapping). Both the model and the animation library import through it (`_subresources → nodes → PATH:<Armature>/Skeleton3D → retarget/bone_map`). Godot then renames the skeleton to the unique `%GeneralSkeleton`, fixes rests to the profile and rewrites tracks to `%GeneralSkeleton:<Bone>`, so **any** library plays on **any** mapped model.
- **Animation library:** `zombie_anims.glb` is imported **as an AnimationLibrary** (`importer="animation_library"` in its `.import`), from a reference mannequin (1.75 m) whose proportions differ from the orderly (1.86 m, longer arms). That difference is what proves the retargeting. Loops are set per clip in the `.import` (`animations → <clip> → settings/loop_mode`).
- **Clips (in place, no root motion, D-007):** `idle`, `walk`, `run`, `attack_swipe` (0.45 s wind-up), `hit_react_head/left/right/stomach`, `death_back`, `crawl`, `barricade_tear`, `window_climb`. They are procedurally keyed in `build_zombie.py` (poses in armature axes, converted per bone).
- **Adding animations:**
  1. **Scripted:** add a pose function and a row in `anim_set()` in `build_zombie.py`, then run `build_characters.sh`.
  2. **Authored or downloaded** (Blender / CC0 / Mixamo): export a GLB of the armature + actions, import it in Godot as *Animation Library*, and in the Advanced Import dialog set *Skeleton3D → Retarget → Bone Map* to a BoneMap with profile `SkeletonProfileHumanoid` (Mixamo names auto-map). Set loop modes. Add it to the `ZombieModel.animations` library or a second library.
  3. Log the source in ASSET_LICENSES.md.
- **Model scene:** `content/enemies/zombie/zombie_<variant>.tscn` = `ZombieModel` (`core/enemies/zombie_model.gd`) with `model_scene` (GLB), `animations` (library), `hitboxes` (`HitboxProfile`) and `skin_material` (variant). Variants: `orderly`, `orderly_pallid`, `orderly_frostbitten`.
- **Hitboxes:** `content/enemies/zombie/zombie_hitboxes.tres` maps bones to hitzones (head, neck, 4 torso, 8 limb capsules). `ZombieModel` builds a `BoneAttachment3D` + `Hurtbox` (physics layer 3) per entry, so hitboxes follow the animated pose on every peer (test: `test_zombie_model.gd`).

## 6. Weapons (hero model path)

- A viewmodel GLB must have **top-level** nodes `Mag`, `Action` (animated parents), `Sight` (the point that lands on screen centre in ADS, at `WeaponDefinition.sight_height`), `Muzzle` and `Eject` (markers), authored in weapon space (x right, y up, −z forward; pivot near the grip). Arms are part of the viewmodel GLB (`Arms/ArmsMesh`).
- Set `WeaponDefinition.viewmodel_scene` (first person; the viewmodel moves it to render layer 2) and `world_scene` (third person; needs `Muzzle`). Animation clips are still generated from the definition's timings (`ViewmodelAnimations`). Authored clips can replace them in Step 9.
- Budget: viewmodel 6–12k triangles (M1911: 6.8k), world model 1.5–3k (M1911: 1.4k).
- The front sight carries a tiny `M_sight_fibre` insert (unshaded magenta) that the ADS alignment visual test detects.

## 7. Human / artist drop-in process

1. Model in Blender following §3–§6 (grid, origins, names, `M_<id>` materials, sockets, collision suffixes).
2. Export GLB to the matching `game/content/...` folder (or run the generator).
3. Open the Godot project once (or `godot --headless --path game --import`). The post-import script remaps materials and tags surfaces.
4. Run `tools/check.sh` and `tools/run_tests.sh integration` (the kit test catches bounds, collision and gaps).
5. Add the ASSET_LICENSES row for anything not made in-house.
