"""Humanoid character pipeline v1: the shared zombie animation library and the first zombie
model (the sanatorium orderly). Run via tools/blender/build_characters.sh.

Outputs
- game/content/characters/animations/zombie_anims.glb — a reference mannequin armature with
  in-place actions (no root motion). Imported in Godot as an AnimationLibrary through the
  SkeletonProfileHumanoid BoneMap (retargeting; docs/ART_PIPELINE.md §4).
- game/content/enemies/zombie/zombie_orderly.glb — the orderly mesh skinned to its own armature
  (different proportions from the mannequin: taller, longer arms), imported through the same
  BoneMap so the library plays on it.

Bones use Godot's SkeletonProfileHumanoid names directly (Hips, Spine, Chest, UpperChest, Neck,
Head, Left/Right Shoulder, UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot, Toes). Rest pose
is a T-pose facing Blender -Y (Godot +Z), as the profile expects.
"""

from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lazarus_bpy as L  # noqa: E402
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Euler, Matrix, Quaternion, Vector  # noqa: E402

FPS = 30
ANIM_OUT = os.path.join(L.GAME_ROOT, "content", "characters", "animations", "zombie_anims.glb")
MODEL_OUT = os.path.join(L.GAME_ROOT, "content", "enemies", "zombie", "zombie_orderly.glb")


def skeleton_points(height: float = 1.8, arm: float = 1.0):
    """Bone (head, tail, parent) in Blender space for a T-pose of ``height`` metres."""
    s = height / 1.8
    a = arm
    p = {
        "Hips": ((0, 0, 0.98), (0, 0, 1.08), None),
        "Spine": ((0, 0, 1.08), (0, 0, 1.22), "Hips"),
        "Chest": ((0, 0, 1.22), (0, 0, 1.35), "Spine"),
        "UpperChest": ((0, 0, 1.35), (0, 0, 1.48), "Chest"),
        "Neck": ((0, 0, 1.48), (0, 0, 1.58), "UpperChest"),
        "Head": ((0, 0, 1.58), (0, 0, 1.82), "Neck"),
    }
    for side, sx in (("Left", 1), ("Right", -1)):
        p[side + "Shoulder"] = ((sx * 0.04, 0, 1.45), (sx * 0.17, 0, 1.45), "UpperChest")
        p[side + "UpperArm"] = ((sx * 0.17, 0, 1.45), (sx * (0.17 + 0.28 * a), 0, 1.45), side + "Shoulder")
        p[side + "LowerArm"] = ((sx * (0.17 + 0.28 * a), 0, 1.45), (sx * (0.17 + 0.54 * a), 0, 1.45),
                                side + "UpperArm")
        p[side + "Hand"] = ((sx * (0.17 + 0.54 * a), 0, 1.45), (sx * (0.17 + 0.54 * a + 0.17), 0, 1.45),
                            side + "LowerArm")
        p[side + "UpperLeg"] = ((sx * 0.1, 0, 0.94), (sx * 0.1, 0, 0.52), "Hips")
        p[side + "LowerLeg"] = ((sx * 0.1, 0, 0.52), (sx * 0.1, 0.0, 0.09), side + "UpperLeg")
        p[side + "Foot"] = ((sx * 0.1, 0.0, 0.09), (sx * 0.1, -0.13, 0.03), side + "LowerLeg")
        p[side + "Toes"] = ((sx * 0.1, -0.13, 0.03), (sx * 0.1, -0.21, 0.03), side + "Foot")
    return {k: (Vector(h) * s, Vector(t) * s, par) for k, (h, t, par) in p.items()}


def make_armature(name: str, pts) -> bpy.types.Object:
    data = bpy.data.armatures.new(name)
    obj = L.link(bpy.data.objects.new(name, data))
    with bpy.context.temp_override(active_object=obj, object=obj, selected_objects=[obj]):
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        for bname, (h, t, _par) in pts.items():
            eb = data.edit_bones.new(bname)
            eb.head, eb.tail = h, t
            eb.roll = 0.0
        for bname, (_h, _t, par) in pts.items():
            if par:
                eb = data.edit_bones[bname]
                eb.parent = data.edit_bones[par]
                eb.use_connect = False
        bpy.ops.object.mode_set(mode="OBJECT")
    return obj


# ---------------------------------------------------------------------------------------------
# Animation: poses are rotations expressed in armature (rest) axes, converted to each bone's
# local frame. Axes: +X = character's left, -Y = forward, +Z = up.

def _q(bone: bpy.types.Bone, euler_deg) -> Quaternion:
    # YXZ: swing about Y first (e.g. lower a T-pose arm), then about X (raise it forward)
    r = Euler([math.radians(v) for v in euler_deg], "YXZ").to_matrix()
    m = bone.matrix_local.to_3x3()
    return (m.inverted() @ r @ m).to_quaternion()


STANCE = {  # hunched zombie base pose (degrees, armature axes)
    "Spine": (12, 0, 0), "Chest": (8, 0, 0), "UpperChest": (6, 0, 0), "Neck": (-8, 0, 0), "Head": (-6, 0, 4),
    "LeftUpperArm": (-55, 78, 0), "RightUpperArm": (-55, -78, 0),
    "LeftLowerArm": (0, 0, -18), "RightLowerArm": (0, 0, 18),
    "LeftHand": (0, 0, -10), "RightHand": (0, 0, 10),
    "LeftUpperLeg": (-4, 0, 0), "RightUpperLeg": (-4, 0, 0),
    "LeftLowerLeg": (8, 0, 0), "RightLowerLeg": (8, 0, 0),
    "LeftFoot": (-4, 0, 0), "RightFoot": (-4, 0, 0),
}


def _add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def make_action(arm: bpy.types.Object, name: str, length: float, pose_fn, loop: bool, step: float = 1.0 / 15.0,
                hips_fn=None) -> None:
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    n = max(2, int(round(length / step)))
    for i in range(n + 1):
        t = i / n * length
        u = (i % n) / n if loop else i / n  # loops end exactly on their first pose
        frame = 1 + t * FPS
        pose = pose_fn(u)
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            e = _add(STANCE.get(pb.name, (0, 0, 0)), pose.get(pb.name, (0, 0, 0)))
            pb.rotation_quaternion = _q(pb.bone, e)
            pb.keyframe_insert("rotation_quaternion", frame=frame)
        hip = arm.pose.bones["Hips"]
        off = hips_fn(u) if hips_fn else (0, 0, 0)
        # pose-bone location is in bone-local axes; Hips points up (+Y local = +Z armature)
        hip.location = hip.bone.matrix_local.to_3x3().inverted() @ Vector(off)
        hip.keyframe_insert("location", frame=frame)
    arm.animation_data.action = None


def s(u: float, k: float = 1.0, ph: float = 0.0) -> float:
    return math.sin((u * k + ph) * 2.0 * math.pi)


def anim_set(arm: bpy.types.Object) -> list[str]:
    def idle(u):
        return {"Spine": (2 * s(u), 0, 2 * s(u, 1, 0.25)), "Chest": (2 * s(u, 1, 0.1), 0, 0),
                "Head": (4 * s(u, 1, 0.3), 3 * s(u, 2), 8 * s(u, 1, 0.6)),
                "LeftUpperArm": (6 * s(u, 1, 0.2), 0, 0), "RightUpperArm": (6 * s(u, 1, 0.7), 0, 0)}

    def walk(u):
        g = 26 * s(u)
        return {"LeftUpperLeg": (-g, 0, 0), "RightUpperLeg": (g, 0, 0),
                "LeftLowerLeg": (20 + 18 * s(u, 1, 0.3), 0, 0), "RightLowerLeg": (20 + 18 * s(u, 1, 0.8), 0, 0),
                "Spine": (4, 7 * s(u), 6 * s(u)), "Head": (0, -6 * s(u), 10 * s(u, 1, 0.2)),
                "LeftUpperArm": (8 * s(u), 0, 0), "RightUpperArm": (-8 * s(u), 0, 0)}

    def walk_hips(u):
        return (0.03 * s(u, 1, 0.25), 0, -0.03 + 0.03 * s(u, 2, 0.25))

    def run(u):
        g = 42 * s(u)
        return {"LeftUpperLeg": (-g - 8, 0, 0), "RightUpperLeg": (g - 8, 0, 0),
                "LeftLowerLeg": (45 + 35 * s(u, 1, 0.35), 0, 0), "RightLowerLeg": (45 + 35 * s(u, 1, 0.85), 0, 0),
                "Spine": (18, 6 * s(u), 0), "Chest": (6, 0, 0), "Head": (-14, 0, 6 * s(u)),
                "LeftUpperArm": (30 * s(u) + 20, -20, 0), "RightUpperArm": (-30 * s(u) + 20, 20, 0),
                "LeftLowerArm": (0, 0, -40), "RightLowerArm": (0, 0, 40)}

    def run_hips(u):
        return (0, 0, -0.07 + 0.05 * s(u, 2, 0.25))

    def attack(u):  # wind-up 0.45 s of 1.1 s, swipe right arm across, recover
        t = u * 1.1
        if t < 0.45:
            k = t / 0.45
            arm_r, twist = (-60 * k, 25 * k, -30 * k), -18 * k
        elif t < 0.65:
            k = (t - 0.45) / 0.2
            arm_r, twist = (-60 + 50 * k, 25 - 75 * k, -30 + 70 * k), -18 + 40 * k
        else:
            k = (t - 0.65) / 0.45
            arm_r, twist = (-10 * (1 - k), -50 * (1 - k), 40 * (1 - k)), 22 * (1 - k)
        return {"RightUpperArm": arm_r, "Spine": (6, 0, twist), "Chest": (4, 0, twist * 0.6),
                "RightLowerArm": (0, 0, 30 * (1 - abs(2 * u - 1))), "Head": (-6, 0, twist * -0.5)}

    def react(part):
        def fn(u):
            k = math.sin(min(1.0, u * 3.0) * math.pi * 0.5) * (1 - u) ** 1.5
            if part == "head":
                return {"Neck": (-25 * k, 0, 10 * k), "Head": (-20 * k, 0, 8 * k), "Spine": (-6 * k, 0, 0)}
            if part == "left":
                return {"Chest": (0, 14 * k, 14 * k), "LeftUpperArm": (-20 * k, 0, 0), "Head": (0, -8 * k, 0)}
            if part == "right":
                return {"Chest": (0, -14 * k, -14 * k), "RightUpperArm": (-20 * k, 0, 0), "Head": (0, 8 * k, 0)}
            return {"Spine": (24 * k, 0, 0), "Chest": (12 * k, 0, 0), "Head": (10 * k, 0, 0),
                    "LeftUpperLeg": (-10 * k, 0, 0), "RightUpperLeg": (-10 * k, 0, 0)}
        return fn

    def death(u):
        k = min(1.0, u * 1.25) ** 1.6
        return {"Hips": (-80 * k, 0, 10 * k), "Spine": (-10 * k, 0, 0), "Head": (-20 * k, 0, 25 * k),
                "LeftUpperLeg": (60 * k, 0, 8 * k), "RightUpperLeg": (40 * k, 0, -6 * k),
                "LeftLowerLeg": (-10 * k, 0, 0), "RightLowerLeg": (30 * k, 0, 0),
                "LeftUpperArm": (40 * k, -30 * k, 0), "RightUpperArm": (40 * k, 30 * k, 0)}

    def death_hips(u):
        k = min(1.0, u * 1.25) ** 1.6
        return (0, 0.25 * k, -0.82 * k)

    def crawl(u):
        g = 30 * s(u)
        return {"Hips": (78, 0, 0), "Spine": (6, 0, 6 * s(u)), "Neck": (-35, 0, 0), "Head": (-35, 0, 0),
                "LeftUpperArm": (-95 + g, 30, 0), "RightUpperArm": (-95 - g, -30, 0),
                "LeftLowerArm": (0, 0, -30 - 20 * s(u, 1, 0.25)), "RightLowerArm": (0, 0, 30 + 20 * s(u, 1, 0.75)),
                "LeftUpperLeg": (-15 + 8 * s(u), 0, 10), "RightUpperLeg": (-15 - 8 * s(u), 0, -10),
                "LeftLowerLeg": (30, 0, 0), "RightLowerLeg": (30, 0, 0)}

    def crawl_hips(u):
        return (0, 0, -0.72 + 0.02 * s(u, 2))

    def tear(u):  # reach into the window, grab, rip back (1.0 s; plank comes off at 0.6)
        k = math.sin(u * math.pi)
        return {"LeftUpperArm": (-45 * k, -10, 0), "RightUpperArm": (-45 * k, 10, 0),
                "LeftLowerArm": (0, 0, -30 * (1 - k)), "RightLowerArm": (0, 0, 30 * (1 - k)),
                "Spine": (14 * k - 8 * (1 - k), 0, 0), "Head": (-10 * k, 0, 0)}

    def climb(u):  # over a 0.9 m sill: lean forward, lift legs (in place; movement is code-driven)
        k = math.sin(u * math.pi)
        return {"Spine": (35 * k, 0, 0), "LeftUpperLeg": (-70 * k, 0, 0), "RightUpperLeg": (-40 * math.sin(
            min(1, u * 1.3) * math.pi), 0, 0), "LeftLowerLeg": (80 * k, 0, 0), "RightLowerLeg": (60 * k, 0, 0),
            "LeftUpperArm": (-30 * k, 20, 0), "RightUpperArm": (-30 * k, -20, 0)}

    def climb_hips(u):
        return (0, 0, 0.35 * math.sin(u * math.pi))

    clips = [
        ("idle", 2.0, idle, True, None),
        ("walk", 1.2, walk, True, walk_hips),
        ("run", 0.7, run, True, run_hips),
        ("attack_swipe", 1.1, attack, False, None),
        ("hit_react_head", 0.5, react("head"), False, None),
        ("hit_react_left", 0.5, react("left"), False, None),
        ("hit_react_right", 0.5, react("right"), False, None),
        ("hit_react_stomach", 0.5, react("stomach"), False, None),
        ("death_back", 1.4, death, False, death_hips),
        ("crawl", 1.4, crawl, True, crawl_hips),
        ("barricade_tear", 1.0, tear, False, None),
        ("window_climb", 1.2, climb, False, climb_hips),
    ]
    for name, length, fn, loop, hips in clips:
        make_action(arm, name, length, fn, loop, hips_fn=hips)
    return [c[0] for c in clips]


# ---------------------------------------------------------------------------------------------
# Mesh: one part per bone, rigidly weighted with soft blends near joints.

def _segment(name, bone, parent_bone, r0, r1, mat_id, pts, segments=16, blend=0.22, scale_xy=(1.0, 1.0),
             ext=(0.0, 0.0)):
    h, t, _ = pts[bone]
    axis = t - h
    length = axis.length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=r0, radius2=r1,
                          depth=length + ext[0] + ext[1])
    bmesh.ops.scale(bm, vec=Vector((scale_xy[0], scale_xy[1], 1.0)), verts=bm.verts)
    # cone is centred on Z: move so z in [-ext0, length + ext1]
    bmesh.ops.translate(bm, vec=Vector((0, 0, (length + ext[0] + ext[1]) * 0.5 - ext[0])), verts=bm.verts)
    rot = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation(h) @ rot, verts=bm.verts)
    obj = L._finish_mesh(name, bm, mat_id, None, "height")
    weights = []
    for v in obj.data.vertices:
        f = (v.co - h).dot(axis) / (length * length)
        w = 1.0 if parent_bone is None else min(1.0, max(0.0, 0.5 + f / blend * 0.5))
        weights.append(w)
    obj["_w"] = 1
    _assign(obj, bone, parent_bone, weights)
    return obj


def _blob(name, bone, center, radius, scale, mat_id, segments=16, rings=10):
    obj = L.sphere(name, radius, center, mat_id, scale=scale, segments=segments, rings=rings)
    _assign(obj, bone, None, [1.0] * len(obj.data.vertices))
    return obj


def _boxpart(name, bone, size, center, mat_id, bevel=0.01):
    obj = L.box(name, size, center, mat_id, bevel=bevel)
    _assign(obj, bone, None, [1.0] * len(obj.data.vertices))
    return obj


def _assign(obj, bone, parent_bone, weights):
    g = obj.vertex_groups.new(name=bone)
    gp = obj.vertex_groups.new(name=parent_bone) if parent_bone else None
    for i, w in enumerate(weights):
        g.add([i], w, "REPLACE")
        if gp is not None and w < 1.0:
            gp.add([i], 1.0 - w, "REPLACE")


def build_orderly(pts) -> list[bpy.types.Object]:
    P = []
    hx = pts["Hips"][0]
    # torso: tunic (cloth) over chest/spine, trousers on the pelvis
    P.append(_blob("pelvis", "Hips", hx + Vector((0, 0, 0.03)), 0.17, (1.0, 0.68, 0.7), "cloth_trousers"))
    P.append(_segment("spine", "Spine", "Hips", 0.15, 0.16, "cloth_orderly", pts, 20, scale_xy=(1, 0.72),
                      ext=(0.05, 0.02)))
    P.append(_segment("chest", "Chest", "Spine", 0.16, 0.18, "cloth_orderly", pts, 20, scale_xy=(1, 0.7),
                      ext=(0.02, 0.02)))
    P.append(_segment("upperchest", "UpperChest", "Chest", 0.18, 0.15, "cloth_orderly", pts, 20,
                      scale_xy=(1.05, 0.68), ext=(0.02, 0.0)))
    P.append(_segment("neck", "Neck", "UpperChest", 0.055, 0.05, "zombie_skin", pts, 12, ext=(0.03, 0.03)))
    hh = pts["Head"][0]
    P.append(_blob("skull", "Head", hh + Vector((0, -0.01, 0.12)), 0.11, (0.88, 1.0, 1.08), "zombie_skin", 20, 14))
    P.append(_boxpart("jaw", "Head", (0.12, 0.1, 0.06), hh + Vector((0, -0.06, 0.03)), "zombie_skin", 0.02))
    P.append(_blob("brow", "Head", hh + Vector((0, -0.075, 0.15)), 0.05, (1.7, 0.6, 0.5), "zombie_skin", 12, 6))
    for sx in (1, -1):
        eye = L.sphere(f"eye_{sx}", 0.014, hh + Vector((sx * 0.038, -0.095, 0.125)), "vesperite", segments=8,
                       rings=4)
        _assign(eye, "Head", None, [1.0] * len(eye.data.vertices))
        P.append(eye)
    for side in ("Left", "Right"):
        P.append(_segment(f"{side}_shoulder", side + "Shoulder", "UpperChest", 0.07, 0.075, "cloth_orderly",
                          pts, 12, blend=0.4))
        P.append(_segment(f"{side}_uarm", side + "UpperArm", side + "Shoulder", 0.065, 0.05, "cloth_orderly",
                          pts, 14, ext=(0.02, 0.0)))
        P.append(_segment(f"{side}_larm", side + "LowerArm", side + "UpperArm", 0.048, 0.035, "zombie_skin",
                          pts, 14, ext=(0.02, 0.0)))
        hand_c = (pts[side + "Hand"][0] + pts[side + "Hand"][1]) * 0.5
        P.append(_boxpart(f"{side}_hand", side + "Hand", (0.15, 0.05, 0.09), hand_c, "zombie_skin", 0.015))
        P.append(_segment(f"{side}_uleg", side + "UpperLeg", "Hips", 0.085, 0.06, "cloth_trousers", pts, 16,
                          ext=(0.04, 0.0)))
        P.append(_segment(f"{side}_lleg", side + "LowerLeg", side + "UpperLeg", 0.058, 0.045, "cloth_trousers",
                          pts, 16, ext=(0.02, 0.0)))
        fh, ft, _ = pts[side + "Foot"]
        P.append(_boxpart(f"{side}_foot", side + "Foot", (0.1, 0.24, 0.09),
                          Vector((fh.x, (fh.y + ft.y) * 0.5 - 0.02, 0.045)), "leather_boot", 0.02))
        th, tt, _ = pts[side + "Toes"]
        P.append(_boxpart(f"{side}_toes", side + "Toes", (0.1, 0.08, 0.06),
                          Vector((th.x, (th.y + tt.y) * 0.5, 0.03)), "leather_boot", 0.015))
    # tunic hem + torn flap (cloth reads as an orderly's smock)
    P.append(_segment("hem", "Hips", None, 0.19, 0.17, "cloth_orderly", {"Hips": (hx + Vector((0, 0, -0.12)),
                      hx + Vector((0, 0, 0.1)), None)}, 20, scale_xy=(1.0, 0.75)))
    return P


def subdivide_for_budget(objs, cuts: int = 1) -> None:
    for o in objs:
        if o.name.startswith("eye"):
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=cuts, use_grid_fill=True, smooth=0.6)
        bm.to_mesh(o.data)
        bm.free()


def main() -> None:
    # 1) Animation library on the reference mannequin (1.75 m, standard arms).
    L.reset()
    bpy.context.scene.render.fps = FPS
    ref = make_armature("Mannequin", skeleton_points(1.75, 1.0))
    names = anim_set(ref)
    L.export_glb(ANIM_OUT, animations=True)
    # 2) The orderly: 1.86 m, long arms (a different skeleton, retargeted on import).
    L.reset()
    pts = skeleton_points(1.86, 1.12)
    arm = make_armature("Skeleton", pts)
    parts = build_orderly(pts)
    subdivide_for_budget(parts, 1)
    for p in parts:
        mod = p.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    body = L.join(parts, "ZombieOrderly")
    body.parent = arm
    body.data.shade_smooth()
    print("[blender] zombie tris", L.tri_count([body]), "anims", ",".join(names))
    L.export_glb(MODEL_OUT, animations=False)


main()
