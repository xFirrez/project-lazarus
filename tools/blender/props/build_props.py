"""Look-dev props v1 (Step 4 look-dev scene; reused by Step 8/13): frozen tiered fountain,
military cargo truck, sandbag wall, courtyard lamp post, fuel drum, supply crate and a
perk-machine-sized placeholder. Run via tools/blender/build_props.sh.
Each prop: origin at its ground contact point, convex collision boxes with surface tags, one
joined visual mesh (plus moving/swaying parts kept separate where needed).
Writes game/content/props/<id>/<id>.glb.
"""

from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lazarus_bpy as L  # noqa: E402
import bpy  # noqa: E402

OUT = os.path.join(L.GAME_ROOT, "content", "props")


def fountain():
    # three tiers of basins on a stepped plinth, frozen water sheets and icicles
    L.cylinder("plinth", 3.2, 0.3, (0, 0, 0.15), "stone_facade", segments=32)
    L.cylinder("basin_wall", 3.0, 0.7, (0, 0, 0.65), "stone_facade", segments=32)
    L.cylinder("basin_ice", 2.8, 0.05, (0, 0, 0.92), "ice", segments=32, grime="none")
    L.cylinder("column", 0.35, 1.6, (0, 0, 1.6), "stone_grey", segments=16)
    L.cylinder("bowl2", 1.5, 0.25, (0, 0, 2.3), "stone_facade", segments=24, radius2=1.7)
    L.cylinder("bowl2_ice", 1.55, 0.04, (0, 0, 2.44), "ice", segments=24, grime="none")
    L.cylinder("column2", 0.2, 0.9, (0, 0, 2.85), "stone_grey", segments=12)
    L.cylinder("bowl3", 0.7, 0.18, (0, 0, 3.35), "stone_facade", segments=20, radius2=0.85)
    L.sphere("finial", 0.22, (0, 0, 3.7), "stone_facade", scale=(1, 1, 1.4), segments=12, rings=8)
    # frozen curtains of water falling from the upper bowls + icicles around the rims
    for k in range(10):
        a = k / 10 * math.tau
        L.cylinder(f"sheet2_{k}", 0.16, 1.2, (1.55 * math.cos(a), 1.55 * math.sin(a), 1.75), "ice", segments=6,
                   radius2=0.05, grime="none")
    for k in range(16):
        a = (k + 0.5) / 16 * math.tau
        r = 1.68
        L.cylinder(f"icicle2_{k}", 0.05, 0.35 + 0.15 * (k % 3), (r * math.cos(a), r * math.sin(a), 2.0),
                   "ice", segments=5, radius2=0.002, grime="none")
    for k in range(8):
        a = k / 8 * math.tau
        L.cylinder(f"sheet3_{k}", 0.09, 0.7, (0.8 * math.cos(a), 0.8 * math.sin(a), 2.95), "ice", segments=6,
                   radius2=0.03, grime="none")
    L.join_visuals("fountain")
    for k in range(8):  # octagonal approximation of the round basin for collision
        a = k / 8 * math.tau
        L.collision_box(f"basin_{k}", (2.6, 0.5, 1.0), (2.9 * math.cos(a), 2.9 * math.sin(a), 0.5), surface="concrete",
                        rot=(0, 0, a + math.pi * 0.5))
    L.collision_box("center", (5.0, 5.0, 0.95), (0, 0, 0.475), surface="snow")
    L.collision_box("col", (0.8, 0.8, 3.0), (0, 0, 2.0), surface="concrete")
    return 3.3


def truck():
    # 1940s-style 2.5 t cargo truck (generic, original design): cab, hood, bed with canvas tarp
    L.box("chassis", (1.1, 6.0, 0.25), (0, 0, 0.75), "metal_dark")
    L.box("hood", (1.4, 1.5, 0.75), (0, -2.35, 1.3), "metal_olive", bevel=0.06)
    L.box("grille", (1.2, 0.08, 0.7), (0, -3.12, 1.22), "metal_dark")
    L.box("bumper", (2.2, 0.18, 0.18), (0, -3.2, 0.72), "metal_dark")
    for sx in (-1, 1):
        L.box(f"fender_{sx}", (0.45, 1.3, 0.12), (sx * 0.95, -2.4, 1.08), "metal_olive", rot=(math.radians(8), 0, 0),
              bevel=0.03)
        L.cylinder(f"headlamp_{sx}", 0.13, 0.12, (sx * 0.62, -3.1, 1.55), "emissive_warm", rot=(math.radians(90), 0, 0),
                   segments=12, grime="none")
        L.cylinder(f"beacon_{sx}", 0.07, 0.12, (sx * 0.95, 2.95, 1.0), "emissive_red",
                   rot=(math.radians(90), 0, 0), segments=10, grime="none")
    L.box("cab", (2.0, 1.4, 1.35), (0, -1.0, 1.75), "metal_olive", bevel=0.05)
    L.box("cab_roof", (2.05, 1.45, 0.08), (0, -1.0, 2.46), "metal_olive", bevel=0.02)
    L.box("windscreen", (1.7, 0.05, 0.55), (0, -1.71, 2.05), "glass_frosted", grime="none")
    L.box("bed", (2.3, 3.6, 0.5), (0, 1.25, 1.15), "metal_olive", bevel=0.03)
    L.box("star", (0.6, 0.02, 0.6), (-1.16, 1.0, 1.15), "cloth_orderly", rot=(0, 0, math.radians(90)), grime="none")
    for k in range(4):  # tarp hoops
        L.box(f"hoop_{k}", (2.3, 0.05, 0.05), (0, -0.4 + k * 1.15, 2.85), "metal_dark")
    for sx in (-1, 1):
        for y in (-2.3, 0.6, 1.9):
            L.cylinder(f"wheel_{sx}_{y}", 0.48, 0.32, (sx * 1.0, y, 0.48), "rubber", rot=(0, math.radians(90), 0),
                       segments=20)
            L.cylinder(f"hub_{sx}_{y}", 0.2, 0.34, (sx * 1.0, y, 0.48), "metal_dark", rot=(0, math.radians(90), 0),
                       segments=10)
    L.join_visuals("truck_body")
    # canvas tarp kept separate: wind-sway weights (G) increase toward its free bottom edge
    tarp = L.box("tarp", (2.36, 3.62, 1.5), (0, 1.25, 2.15), "canvas_olive", bevel=0.25, grime="none")
    L.paint_grime(tarp, "uniform", sway_axis="-z")
    L.collision_box("hood_col", (2.2, 2.0, 1.6), (0, -2.3, 0.9), surface="metal")
    L.collision_box("cab_col", (2.1, 1.5, 2.5), (0, -1.0, 1.25), surface="metal")
    L.collision_box("bed_col", (2.4, 3.7, 2.9), (0, 1.25, 1.45), surface="metal")
    return 6.4


def sandbags():
    # 4 m curved wall, 3 courses, staggered bags
    import random

    rnd = random.Random(7)
    for row in range(3):
        n = 9 if row % 2 == 0 else 8
        for k in range(n):
            x = -1.8 + k * 0.45 + (0.225 if row % 2 else 0.0)
            y = 0.06 * (x * x) * 0.3
            L.box(f"bag_{row}_{k}", (0.46, 0.3, 0.17), (x, y, 0.09 + row * 0.16), "sandbag", bevel=0.06,
                       rot=(0, 0, rnd.uniform(-0.12, 0.12)))
    L.join_visuals("sandbags")
    L.collision_box("wall_col", (4.2, 0.45, 0.5), (0, 0.06, 0.25), surface="gravel")
    return 0.5


def lamp_post():
    L.cylinder("base", 0.22, 0.4, (0, 0, 0.2), "metal_dark", segments=12, radius2=0.12)
    L.cylinder("pole", 0.06, 3.6, (0, 0, 2.2), "metal_dark", segments=10, radius2=0.045)
    L.box("arm", (0.04, 0.6, 0.04), (0, -0.28, 3.95), "metal_dark")
    L.cylinder("collar", 0.09, 0.12, (0, 0, 3.95), "brass", segments=10)
    L.join_visuals("lamp_post")
    # lantern hangs from the arm; separate so the scene can sway it and parent the light to it
    lantern = L.empty("Lantern", (0, -0.55, 3.9))
    L.cylinder("cap", 0.16, 0.12, (0, 0, -0.06), "metal_dark", lantern, segments=8, radius2=0.04)
    L.cylinder("glass", 0.12, 0.3, (0, 0, -0.27), "emissive_warm", lantern, segments=8, radius2=0.14, grime="none")
    L.cylinder("bottom", 0.15, 0.06, (0, 0, -0.45), "metal_dark", lantern, segments=8)
    lm = [o for o in lantern.children]
    L.join(lm, "LanternMesh")
    L.empty("Socket_Light", (0, -0.55, 3.6))
    L.collision_box("pole_col", (0.3, 0.3, 4.0), (0, 0, 2.0), surface="metal")
    return 4.1


def fuel_drum():
    L.cylinder("drum", 0.29, 0.88, (0, 0, 0.44), "metal_olive", segments=18)
    for z in (0.3, 0.6):
        L.cylinder(f"rib_{z}", 0.3, 0.03, (0, 0, z), "metal_olive", segments=18)
    L.box("stencil", (0.25, 0.02, 0.12), (0, -0.29, 0.55), "cloth_orderly", grime="none")
    L.join_visuals("fuel_drum")
    L.collision_box("drum_col", (0.58, 0.58, 0.88), (0, 0, 0.44), surface="metal")
    return 0.9


def crate():
    L.box("crate", (1.0, 0.7, 0.6), (0, 0, 0.3), "wood_dark", bevel=0.02)
    for x in (-0.45, 0.45):
        L.box(f"band_{x}", (0.05, 0.72, 0.62), (x, 0, 0.3), "metal_dark")
    L.join_visuals("crate")
    L.collision_box("crate_col", (1.0, 0.7, 0.6), (0, 0, 0.3), surface="wood")
    return 0.6


def machine_placeholder():
    """Perk-machine-sized block (1.0 x 0.8 x 2.2 m): brass trim, glowing panel, vesperite tube.
    Step 10 replaces it with the real Vigor Tonic machines (same footprint)."""
    L.box("body", (1.0, 0.8, 2.0), (0, 0, 1.0), "metal_olive", bevel=0.03)
    L.box("plinth", (1.1, 0.9, 0.12), (0, 0, 0.06), "metal_dark")
    L.box("crown", (1.08, 0.88, 0.2), (0, 0, 2.1), "brass", bevel=0.02)
    L.box("panel", (0.7, 0.04, 0.9), (0, -0.41, 1.3), "emissive_warm", grime="none")
    L.box("slot", (0.3, 0.05, 0.1), (0, -0.42, 0.6), "brass")
    L.join_visuals("machine_placeholder")
    tube = L.cylinder("EnergyTube", 0.07, 1.6, (0.42, -0.42, 1.1), "vesperite", segments=10, grime="none")
    tube.name = "EnergyTube"
    L.empty("Socket_Interact", (0, -0.6, 1.1))
    L.collision_box("body_col", (1.1, 0.9, 2.2), (0, 0, 1.1), surface="metal")
    return 2.2


PROPS = {
    "fountain_frozen": fountain,
    "truck_cargo": truck,
    "sandbag_wall": sandbags,
    "lamp_post": lamp_post,
    "fuel_drum": fuel_drum,
    "supply_crate": crate,
    "machine_placeholder": machine_placeholder,
}


def main() -> None:
    only = L.argv_after_dashes()
    for name, fn in PROPS.items():
        if only and name not in only:
            continue
        L.reset()
        fn()
        print("[blender] prop", name, "tris", L.tri_count())
        L.export_glb(os.path.join(OUT, name, name + ".glb"))


main()
