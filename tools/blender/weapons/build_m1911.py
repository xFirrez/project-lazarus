"""M1911 hero model v1: first-person viewmodel (arms + pistol) and the third-person/world model.
Run via tools/blender/build_weapons.sh. Proves the weapon art path (STYLE_GUIDE §4, ART_PIPELINE §5).

Coordinates are authored in Godot weapon space (x right, y up, -z forward; pivot near the grip)
and converted to Blender (x, -z, y). Animation sockets match the greybox contract
(core/weapons/greybox_gun.gd): ``Mag`` and ``Action`` are animated parents, ``Sight`` (front-sight
fibre insert, on the sight line at y = sight_height = 0.062), ``Muzzle`` and ``Eject`` are markers.
The fibre insert uses ``M_sight_fibre`` (unshaded magenta, also found by the ADS alignment test).
Real dimensions: overall length ~0.216 m, slide width 0.024 m, height ~0.137 m.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lazarus_bpy as L  # noqa: E402
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

OUT_DIR = os.path.join(L.GAME_ROOT, "content", "weapons", "m1911")
SIGHT_H = 0.062


def g(x, y, z):
    """Godot weapon space -> Blender."""
    return (x, -z, y)


def gs(x, y, z):
    return (x, z, y)


def gbox(name, size, center, mat, parent=None, rot_x=0.0, bevel=0.0015):
    return L.box(name, gs(*size), g(*center), mat, parent, rot=(-L.rad(rot_x), 0, 0), bevel=bevel, grime="uniform")


def gcyl_z(name, r, length, center, mat, parent=None, seg=16):
    """Cylinder along the Godot Z axis (the bore)."""
    return L.cylinder(name, r, length, g(*center), mat, parent, rot=(L.rad(90), 0, 0), segments=seg, grime="uniform")


def build_pistol(root):
    # --- Action (slide) -----------------------------------------------------------------------
    act = L.empty("Action", g(0, 0.03, -0.06), root)
    rel = Vector((0, 0.03, -0.06))

    def a(x, y, z):  # Action-local centre
        return (x - rel.x, y - rel.y, z - rel.z)

    gbox("Slide", (0.024, 0.03, 0.212), a(0, 0.033, -0.053), "gun_steel", act, bevel=0.002)
    gbox("SlideTopFlat", (0.016, 0.004, 0.2), a(0, 0.0495, -0.055), "gun_steel", act)
    for k in range(9):  # rear cocking serrations, both sides
        for sx in (-1, 1):
            gbox(f"Serration_{sx}_{k}", (0.0015, 0.022, 0.0018), a(sx * 0.0122, 0.032, 0.022 + k * 0.0035),
                 "metal_dark", act, bevel=0.0)
    gcyl_z("Bushing", 0.0095, 0.008, a(0, 0.031, -0.158), "gun_steel", act)
    gcyl_z("Bore", 0.0058, 0.004, a(0, 0.031, -0.1605), "metal_dark", act, seg=12)
    gbox("EjectionPort", (0.002, 0.012, 0.036), a(0.0122, 0.038, -0.035), "metal_dark", act, bevel=0.0)
    # front sight post (kept below the sight line) + fibre insert; rear sight with a notch
    gbox("FrontPost", (0.0035, 0.0085, 0.006), a(0, 0.0535, -0.14), "gun_steel", act, bevel=0.0005)
    gbox("RearSightL", (0.007, 0.0095, 0.006), a(-0.0065, 0.054, 0.045), "gun_steel", act, bevel=0.0005)
    gbox("RearSightR", (0.007, 0.0095, 0.006), a(0.0065, 0.054, 0.045), "gun_steel", act, bevel=0.0005)
    gbox("RearSightBase", (0.02, 0.004, 0.008), a(0, 0.0505, 0.045), "gun_steel", act, bevel=0.0005)
    L.empty("Sight", g(0, SIGHT_H, -0.14), root)
    dot = L.box("SightDot", gs(0.0035, 0.0035, 0.0035), g(0, SIGHT_H, -0.14), "sight_fibre", root, grime="none")
    dot["cast_shadow"] = False
    # --- Frame ---------------------------------------------------------------------------------
    gbox("DustCover", (0.022, 0.016, 0.115), (0, 0.01, -0.095), "gun_steel", root)
    gbox("FrameRail", (0.023, 0.012, 0.13), (0, 0.012, -0.02), "gun_steel", root)
    gbox("Beavertail", (0.022, 0.008, 0.03), (0, 0.012, 0.06), "gun_steel", root, rot_x=-20)
    gbox("Hammer", (0.008, 0.016, 0.01), (0, 0.042, 0.066), "metal_dark", root, rot_x=15)
    gbox("SlideStop", (0.004, 0.006, 0.02), (-0.0125, 0.018, -0.04), "metal_dark", root)
    gbox("Safety", (0.004, 0.005, 0.014), (-0.0125, 0.025, 0.04), "metal_dark", root)
    # trigger guard (open loop of four bars) + trigger
    gbox("GuardFront", (0.008, 0.026, 0.005), (0, -0.007, -0.052), "gun_steel", root, rot_x=10)
    gbox("GuardBottom", (0.008, 0.004, 0.05), (0, -0.02, -0.027), "gun_steel", root)
    gbox("Trigger", (0.006, 0.016, 0.006), (0, -0.004, -0.018), "metal_dark", root, rot_x=-8)
    # grip frame, wooden panels with checkering studs, mainspring housing
    gbox("GripFrame", (0.026, 0.1, 0.05), (0, -0.04, 0.034), "gun_steel", root, rot_x=12)
    for sx in (-1, 1):
        gbox(f"GripPanel_{sx}", (0.004, 0.082, 0.042), (sx * 0.0145, -0.036, 0.033), "gun_grip_wood", root,
             rot_x=12, bevel=0.0015)
        for k in range(2):
            L.cylinder(f"GripScrew_{sx}_{k}", 0.0035, 0.002, g(sx * 0.0168, -0.01 - k * 0.05, 0.028 + k * 0.011),
                       "brass", root, rot=(0, L.rad(90), 0), segments=8, grime="none")
    gbox("Mainspring", (0.02, 0.07, 0.01), (0, -0.05, 0.057), "metal_dark", root, rot_x=12)
    # --- Mag (drops in reloads) -----------------------------------------------------------------
    mag = L.empty("Mag", g(0, -0.07, 0.01), root)
    mrel = Vector((0, -0.07, 0.01))
    gbox("MagBase", (0.024, 0.008, 0.042), (0.0 - mrel.x, -0.096 - mrel.y, 0.045 - mrel.z), "metal_dark", mag,
         rot_x=12)
    gbox("MagBody", (0.021, 0.085, 0.034), (0.0 - mrel.x, -0.05 - mrel.y, 0.035 - mrel.z), "gun_steel", mag,
         rot_x=12)
    # --- markers ---------------------------------------------------------------------------------
    L.empty("Muzzle", g(0, 0.031, -0.165), root)
    L.empty("Eject", g(0.016, 0.04, -0.035), root)


def _limb(name, a, b, r0, r1, mat, parent, seg=14):
    a, b = Vector(g(*a)), Vector(g(*b))
    axis = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r0, radius2=r1, depth=axis.length)
    rot = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
    from mathutils import Matrix

    bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) * 0.5) @ rot, verts=bm.verts)
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=2, use_grid_fill=True, smooth=0.5)
    return L._finish_mesh(name, bm, mat, parent, "uniform")


def build_arms(root):
    # Right hand wraps the grip; left hand cups under it (two-handed hold). Forearms run back to
    # just past the viewmodel camera's near edge.
    L.sphere("RightPalm", 0.03, g(0.006, -0.045, 0.045), "skin_hand", root, scale=(1.0, 1.25, 1.5), segments=24,
             rings=16, grime="uniform")
    for k in range(3):  # fingers curled around the front strap
        _limb(f"RightFinger_{k}", (0.014, -0.025 - k * 0.019, 0.01), (-0.016, -0.03 - k * 0.019, 0.0),
              0.0085, 0.0075, "skin_hand", root, seg=10)
    _limb("RightIndex", (0.014, -0.006, -0.004), (0.004, -0.008, -0.026), 0.008, 0.007, "skin_hand", root, seg=10)
    _limb("RightThumb", (-0.012, 0.0, 0.035), (-0.017, 0.012, -0.02), 0.009, 0.008, "skin_hand", root, seg=10)
    _limb("RightWrist", (0.004, -0.06, 0.07), (0.03, -0.11, 0.15), 0.028, 0.032, "skin_hand", root)
    _limb("RightSleeve", (0.03, -0.108, 0.145), (0.09, -0.2, 0.36), 0.045, 0.055, "sleeve_olive", root)
    _limb("RightCuff", (0.026, -0.103, 0.138), (0.034, -0.116, 0.16), 0.048, 0.048, "sleeve_olive", root)
    L.sphere("LeftPalm", 0.03, g(-0.02, -0.07, 0.03), "skin_hand", root, scale=(1.4, 1.0, 1.5), segments=24,
             rings=16, grime="uniform")
    for k in range(4):
        _limb(f"LeftFinger_{k}", (-0.03, -0.062, 0.005 + k * 0.016), (0.012, -0.04, 0.008 + k * 0.016), 0.0075,
              0.0068, "skin_hand", root, seg=10)
    _limb("LeftThumb", (-0.02, -0.045, 0.02), (-0.016, -0.012, -0.012), 0.009, 0.008, "skin_hand", root, seg=10)
    _limb("LeftWrist", (-0.03, -0.085, 0.06), (-0.07, -0.13, 0.15), 0.028, 0.031, "skin_hand", root)
    _limb("LeftSleeve", (-0.068, -0.128, 0.145), (-0.16, -0.22, 0.34), 0.045, 0.055, "sleeve_olive", root)


def _join_children(parent, name):
    pool = parent.children if parent is not None else [o for o in bpy.context.scene.objects if o.parent is None]
    kids = [o for o in pool if o.type == "MESH" and o.name != "SightDot"]
    if kids:
        L.join(kids, name)


def main() -> None:
    for variant in ("viewmodel", "world"):
        L.reset()
        build_pistol(None)  # top-level parts: Mag / Action / markers must be direct scene children
        if variant == "viewmodel":
            arms = L.empty("Arms", (0, 0, 0))
            build_arms(arms)
            _join_children(arms, "ArmsMesh")
        for e in [o for o in bpy.context.scene.objects if o.type == "EMPTY" and o.parent is None]:
            _join_children(e, e.name + "Mesh")
        _join_children(None, "Frame")
        print("[blender] m1911", variant, "tris", L.tri_count())
        L.export_glb(os.path.join(OUT_DIR, f"m1911_{variant}.glb"))


main()
