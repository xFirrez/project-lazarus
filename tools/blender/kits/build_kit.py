"""Vesper Peak modular kit v1 generator (AC-4.1). Run via tools/blender/build_kit.sh.

Grid: 2 m cells, 0.5 m sub-grid. Storey height 4 m. Every piece's origin sits on a grid point:
- walls: origin at the bottom centre of the wall line; span x in [-1, 1], thickness 0.25 centred
  on the line (y in [-0.125, 0.125]), height 4 m. Corners are covered by ``pillar_corner``.
- floors: top surface at z = 0, span x, y in [-1, 1], 0.2 m thick.
- stairs: 2 m wide, rise 2 m over a 4 m run along +Y (8 steps of 0.25 x 0.5), so two flights and
  a 2 m landing make one storey. Collision is a smooth convex ramp (nav-friendly).
Writes game/content/kits/vesper/<piece>.glb and kit_manifest.json (expected bounds per piece,
used by tests/integration/test_kit_grid.gd).
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lazarus_bpy as L  # noqa: E402

OUT = os.path.join(L.GAME_ROOT, "content", "kits", "vesper")
H = 4.0  # storey height
T = 0.25  # wall thickness


def _wall_shell(prefix: str, upper: str, lower: str, openings: list[tuple[float, float, float, float]]):
    """Wall line from x=-1..1 with rectangular openings (x0, x1, z0, z1). Builds visual slabs and
    matching collision boxes around the openings."""
    xs = sorted({-1.0, 1.0, *[o[0] for o in openings], *[o[1] for o in openings]})
    for i in range(len(xs) - 1):
        x0, x1 = xs[i], xs[i + 1]
        cx, w = (x0 + x1) * 0.5, x1 - x0
        holes = [o for o in openings if o[0] <= x0 + 1e-6 and o[1] >= x1 - 1e-6]
        spans = [(0.0, H)]
        for o in holes:
            spans = [s for s in [(0.0, o[2]), (o[3], H)] if s[1] - s[0] > 1e-6]
        for z0, z1 in spans:
            # lower 1.1 m wainscot / plinth band in the lower material, the rest in the upper one
            band = 1.1
            if z0 < band:
                zb = min(z1, band)
                L.box(f"{prefix}_low_{i}_{z0:.1f}", (w, T, zb - z0), (cx, 0, (z0 + zb) * 0.5), lower)
            if z1 > band:
                za = max(z0, band)
                L.box(f"{prefix}_up_{i}_{za:.1f}", (w, T * 0.92, z1 - za), (cx, 0, (za + z1) * 0.5), upper)
            # colliders overlap the neighbouring piece by 5 mm at the piece edges so a seam is
            # never a zero-width crack for rays (float error at x = +-1)
            c0 = x0 - (0.005 if x0 <= -1.0 + 1e-6 else 0.0)
            c1 = x1 + (0.005 if x1 >= 1.0 - 1e-6 else 0.0)
            L.collision_box(f"{prefix}_col_{i}_{z0:.1f}", (c1 - c0, T, z1 - z0), ((c0 + c1) * 0.5, 0, (z0 + z1) * 0.5),
                            surface="concrete")
    # trims both faces: baseboard + crown (skipped across door openings at floor level)
    for side in (-1, 1):
        y = side * (T * 0.5 + 0.015)
        for i in range(len(xs) - 1):
            x0, x1 = xs[i], xs[i + 1]
            door = any(o[0] <= x0 + 1e-6 and o[1] >= x1 - 1e-6 and o[2] <= 0.01 for o in openings)
            if not door:
                L.box(f"{prefix}_base_{side}_{i}", (x1 - x0, 0.03, 0.14), ((x0 + x1) * 0.5, y, 0.07), "wood_dark")
            L.box(f"{prefix}_crown_{side}_{i}", (x1 - x0, 0.05, 0.12), ((x0 + x1) * 0.5, y, H - 0.06), "wood_dark")


def wall_2m():
    _wall_shell("wall", "plaster_rose", "wood_dark", [])
    return {"bounds": [[-1, -0.165, 0], [1, 0.165, H]], "collision": True}


def wall_2m_exterior():
    _wall_shell("wallx", "stone_facade", "stone_facade", [])
    # rusticated plinth courses on the outside (-Y face)
    for k in range(3):
        L.box(f"course_{k}", (2.0, 0.04, 0.05), (0, -T * 0.5 - 0.02, 0.4 + k * 0.4), "stone_facade")
    return {"bounds": [[-1, -0.165, 0], [1, 0.165, H]], "collision": True}


def wall_window_2m(upper="plaster_rose", lower="wood_dark"):
    x0, x1, z0, z1 = -0.6, 0.6, 0.9, 2.3
    _wall_shell("wallw", upper, lower, [(x0, x1, z0, z1)])
    # frame + sill
    fw = 0.08
    L.box("frame_l", (fw, T + 0.06, z1 - z0), (x0 + fw * 0.5, 0, (z0 + z1) * 0.5), "wood_dark")
    L.box("frame_r", (fw, T + 0.06, z1 - z0), (x1 - fw * 0.5, 0, (z0 + z1) * 0.5), "wood_dark")
    L.box("frame_top", (x1 - x0, T + 0.06, fw), (0, 0, z1 - fw * 0.5), "wood_dark")
    L.box("sill", (x1 - x0 + 0.16, T + 0.16, 0.06), (0, 0, z0 + 0.03), "wood_dark")
    # barricade sockets: 6 planks across the opening on the outside face, plus the climb point
    for k in range(6):
        z = z0 + 0.18 + k * (z1 - z0 - 0.3) / 5.0
        L.empty(f"Socket_Barricade_{k}", (0, -T * 0.5 - 0.05, z), rot=(0, L.rad((-1) ** k * 8.0), 0))
    L.empty("Socket_WindowClimb", (0, 0, z0))
    return {"bounds": [[-1, -0.205, 0], [1, 0.205, H]], "collision": True, "sockets": 7}


def wall_window_2m_exterior():
    info = wall_window_2m("stone_facade", "stone_facade")
    # stone sill + keystone lintel on the outside face
    L.box("ext_sill", (1.4, 0.12, 0.08), (0, -T * 0.5 - 0.05, 0.86), "stone_facade")
    L.box("ext_lintel", (1.5, 0.08, 0.2), (0, -T * 0.5 - 0.03, 2.42), "stone_facade")
    L.box("keystone", (0.22, 0.12, 0.3), (0, -T * 0.5 - 0.05, 2.42), "stone_facade")
    info["bounds"] = [[-1, -0.235, 0], [1, 0.205, H]]
    return info


def window_glass_2m(lit=True):
    """Glazing insert for the window opening (mullions + panes). Lit panes glow warm."""
    mat = "glass_lit" if lit else "glass_frosted"
    L.box("pane", (1.04, 0.02, 1.24), (0, 0, 1.6), mat, grime="none")
    L.box("mullion_v", (0.04, 0.05, 1.24), (0, 0, 1.6), "wood_dark")
    L.box("mullion_h", (1.04, 0.05, 0.04), (0, 0, 1.75), "wood_dark")
    return {"bounds": [[-0.52, -0.025, 0.98], [0.52, 0.025, 2.22]], "collision": False}


def window_glass_2m_frosted():
    return window_glass_2m(False)


def wall_door_2m():
    x0, x1, z1 = -0.7, 0.7, 2.6
    _wall_shell("walld", "plaster_rose", "wood_dark", [(x0, x1, 0.0, z1)])
    fw = 0.1
    L.box("jamb_l", (fw, T + 0.08, z1), (x0 + fw * 0.5, 0, z1 * 0.5), "wood_dark")
    L.box("jamb_r", (fw, T + 0.08, z1), (x1 - fw * 0.5, 0, z1 * 0.5), "wood_dark")
    L.box("lintel", (x1 - x0 + 0.2, T + 0.1, 0.16), (0, 0, z1 + 0.02), "wood_dark")
    L.empty("Socket_Door", (0, 0, 0))
    return {"bounds": [[-1, -0.175, 0], [1, 0.175, H]], "collision": True, "sockets": 1}


def floor_2m():
    L.box("slab", (2.0, 2.0, 0.2), (0, 0, -0.1), "marble_floor", grime="uniform")
    L.collision_box("slab_col", (2.0, 2.0, 0.2), (0, 0, -0.1), surface="tile")
    return {"bounds": [[-1, -1, -0.2], [1, 1, 0]], "collision": True}


def floor_2m_exterior():
    L.box("slab", (2.0, 2.0, 0.2), (0, 0, -0.1), "cobble_snow", grime="uniform")
    L.collision_box("slab_col", (2.0, 2.0, 0.2), (0, 0, -0.1), surface="snow")
    return {"bounds": [[-1, -1, -0.2], [1, 1, 0]], "collision": True}


def stairs_2m():
    steps, rise, run = 8, 0.25, 0.5
    for k in range(steps):
        L.box(f"step_{k}", (2.0, run, rise * (k + 1)), (0, run * (k + 0.5), rise * (k + 1) * 0.5), "wood_dark",
              bevel=0.01)
    # smooth ramp collider along the step nosings
    top = rise * steps
    pts = [(-1, 0, 0), (1, 0, 0), (-1, run * steps, 0), (1, run * steps, 0), (-1, run * steps, top),
           (1, run * steps, top), (-1, run * 0.5, rise * 0.5), (1, run * 0.5, rise * 0.5)]
    L.collision_hull("ramp_col", pts, surface="wood")
    return {"bounds": [[-1, 0, 0], [1, run * steps, top]], "collision": True}


def pillar_corner():
    L.box("pillar", (0.5, 0.5, H), (0, 0, H * 0.5), "stone_grey", bevel=0.02)
    L.box("cap", (0.6, 0.6, 0.15), (0, 0, H - 0.075), "stone_grey")
    L.box("base", (0.6, 0.6, 0.2), (0, 0, 0.1), "stone_grey")
    L.collision_box("pillar_col", (0.5, 0.5, H), (0, 0, H * 0.5))
    return {"bounds": [[-0.3, -0.3, 0], [0.3, 0.3, H]], "collision": True}


def railing_2m():
    for k in range(5):
        L.cylinder(f"baluster_{k}", 0.025, 0.95, (-0.8 + k * 0.4, 0, 0.475), "metal_dark", segments=8)
    L.box("handrail", (2.0, 0.08, 0.06), (0, 0, 0.98), "wood_dark", bevel=0.01)
    L.box("bottom_rail", (2.0, 0.05, 0.04), (0, 0, 0.1), "metal_dark")
    L.collision_box("rail_col", (2.0, 0.1, 1.0), (0, 0, 0.5), surface="metal")
    return {"bounds": [[-1, -0.04, 0], [1, 0.04, 1.01]], "collision": True}


def pipe_2m():
    L.cylinder("pipe", 0.08, 2.0, (0, 0, 0), "metal_dark", rot=(0, L.rad(90), 0), segments=12, grime="uniform")
    for x in (-0.9, 0.9):
        L.cylinder(f"flange_{x}", 0.11, 0.05, (x, 0, 0), "metal_dark", rot=(0, L.rad(90), 0), segments=12)
    L.collision_box("pipe_col", (2.0, 0.2, 0.2), (0, 0, 0), surface="metal")
    return {"bounds": [[-1, -0.11, -0.11], [1, 0.11, 0.11]], "collision": True}


def pipe_elbow():
    # quarter bend from +X to +Y, radius 0.5, built from 6 segments
    import math

    segs = 6
    for k in range(segs):
        a = (k + 0.5) / segs * math.pi * 0.5
        L.cylinder(f"seg_{k}", 0.08, 0.5 * math.pi * 0.5 / segs + 0.01,
                   (0.5 - 0.5 * math.cos(a) - 0.5, 0.5 * math.sin(a), 0), "metal_dark",
                   rot=(0, L.rad(90), a), segments=12, grime="uniform")
    L.collision_box("elbow_col", (0.6, 0.6, 0.2), (-0.2, 0.2, 0), surface="metal")
    return {"bounds": "measure", "collision": True}


def trim_baseboard_2m():
    L.box("board", (2.0, 0.03, 0.14), (0, 0, 0.07), "wood_dark")
    return {"bounds": [[-1, -0.015, 0], [1, 0.015, 0.14]], "collision": False}


def trim_crown_2m():
    L.box("crown", (2.0, 0.05, 0.12), (0, 0, -0.06), "wood_dark")
    L.box("crown_lip", (2.0, 0.08, 0.03), (0, 0, -0.015), "wood_dark")
    return {"bounds": [[-1, -0.04, -0.12], [1, 0.04, 0]], "collision": False}


PIECES = {
    "wall_2m": wall_2m,
    "wall_2m_exterior": wall_2m_exterior,
    "wall_window_2m": wall_window_2m,
    "wall_window_2m_exterior": wall_window_2m_exterior,
    "window_glass_2m": window_glass_2m,
    "window_glass_2m_frosted": window_glass_2m_frosted,
    "wall_door_2m": wall_door_2m,
    "floor_2m": floor_2m,
    "floor_2m_exterior": floor_2m_exterior,
    "stairs_2m": stairs_2m,
    "pillar_corner": pillar_corner,
    "railing_2m": railing_2m,
    "pipe_2m": pipe_2m,
    "pipe_elbow": pipe_elbow,
    "trim_baseboard_2m": trim_baseboard_2m,
    "trim_crown_2m": trim_crown_2m,
}


def measured_bounds():
    from mathutils import Vector

    pts = [o.matrix_world @ Vector(c) for o in L.bpy.context.scene.objects
           if o.type == "MESH" and "colonly" not in o.name for c in o.bound_box]
    lo = [round(min(p[i] for p in pts), 4) for i in range(3)]
    hi = [round(max(p[i] for p in pts), 4) for i in range(3)]
    return [lo, hi]


def blender_to_godot(b):
    """Blender (x, y, z) Z-up bounds -> Godot (x, z_up->y, -y) bounds."""
    (x0, y0, z0), (x1, y1, z1) = b
    return [[x0, z0, -y1], [x1, z1, -y0]]


def main() -> None:
    only = L.argv_after_dashes()
    manifest = {"grid": 2.0, "sub_grid": 0.5, "storey": H, "pieces": {}}
    for name, fn in PIECES.items():
        if only and name not in only:
            continue
        L.reset()
        info = fn()
        if info["bounds"] == "measure":  # free-form pieces (bends): record what was built
            info["bounds"] = measured_bounds()
        info["bounds"] = blender_to_godot(info["bounds"])
        info["tris"] = L.tri_count()
        L.join_visuals(name)
        L.export_glb(os.path.join(OUT, name + ".glb"))
        manifest["pieces"][name] = info
    if not only:
        with open(os.path.join(OUT, "kit_manifest.json"), "w") as f:
            json.dump(manifest, f, indent=1, sort_keys=True)
            f.write("\n")
        print("[blender] kit:", len(manifest["pieces"]), "pieces")


main()
