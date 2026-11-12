"""Playable survivors (DEVELOPMENT_PLAN Step 7 scope 6): four stylised character models and the
survivor animation library. Run via tools/blender/build_survivors.sh (bpy / Blender 4.2+).

Outputs
- game/content/characters/animations/survivor_anims.glb — reference mannequin (1.75 m) with
  in-place actions, imported in Godot as an AnimationLibrary through the humanoid BoneMap:
    full body : idle, walk, run, crouch_idle, crouch_walk, slide, jump, downed_crawl, revive, drink
    upper body: hold_pistol, hold_rifle, hold_shotgun, hold_lmg (looping weapon-holding poses),
                fire_pistol, fire_long, reload_pistol, reload_long (one-shots, layered in Godot)
- game/content/characters/<id>/<id>.glb — Calloway, Orlov, Brandt, Ashcombe, each on its own
  skeleton proportions (retargeted on import) with an armband in the character's colour.

Reuses the zombie generator's skeleton / mesh helpers (build_zombie.py). Poses are rotations in
armature axes (+X = character's left, -Y = forward, +Z = up), Euler order YXZ in degrees.
"""

from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(__file__))
import lazarus_bpy as L  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import build_zombie as Z  # noqa: E402

FPS = 30
ANIM_OUT = os.path.join(L.GAME_ROOT, "content", "characters", "animations", "survivor_anims.glb")

# Neutral standing pose: arms down at the sides, slight elbow bend.
STANCE = {
    "LeftUpperArm": (0, 74, 4), "RightUpperArm": (0, -74, -4),
    "LeftLowerArm": (0, 0, -8), "RightLowerArm": (0, 0, 8),
    "Neck": (-2, 0, 0),
}

UPPER = ("Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "RightShoulder", "LeftUpperArm",
         "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand")

L.PREVIEW_COLORS.update({
    "survivor_skin": (0.86, 0.68, 0.56),
    "coat_tan": (0.55, 0.45, 0.3),
    "coat_blue": (0.25, 0.3, 0.38),
    "parka_red": (0.6, 0.16, 0.12),
    "tweed_brown": (0.38, 0.27, 0.18),
    "hair_dark": (0.12, 0.09, 0.07),
    "hair_blond": (0.78, 0.62, 0.36),
    "fur_grey": (0.42, 0.4, 0.38),
    "scarf_green": (0.18, 0.42, 0.22),
    "band_white": (0.92, 0.92, 0.9),
    "band_blue": (0.25, 0.45, 0.9),
    "band_yellow": (0.95, 0.78, 0.2),
    "band_green": (0.3, 0.78, 0.35),
})


def s(u: float, k: float = 1.0, ph: float = 0.0) -> float:
    return Z.s(u, k, ph)


def make_action(arm, name, length, pose_fn, loop, hips_fn=None, step=1.0 / 15.0):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    n = max(2, int(round(length / step)))
    for i in range(n + 1):
        t = i / n * length
        u = (i % n) / n if loop else i / n
        frame = 1 + t * FPS
        pose = pose_fn(u)
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            e = Z._add(STANCE.get(pb.name, (0, 0, 0)), pose.get(pb.name, (0, 0, 0)))
            pb.rotation_quaternion = Z._q(pb.bone, e)
            pb.keyframe_insert("rotation_quaternion", frame=frame)
        hip = arm.pose.bones["Hips"]
        off = hips_fn(u) if hips_fn else (0, 0, 0)
        hip.location = hip.bone.matrix_local.to_3x3().inverted() @ Vector(off)
        hip.keyframe_insert("location", frame=frame)
    arm.animation_data.action = None


# Weapon-holding upper-body poses (STANCE is added; values are deltas from arms-down).
HOLD = {
    # two-handed pistol at chest height, elbows soft
    "pistol": {"RightUpperArm": (-78, 4, 18), "LeftUpperArm": (-74, -10, -26),
               "RightLowerArm": (0, 0, 14), "LeftLowerArm": (0, 0, -22), "Chest": (4, 0, 0),
               "RightHand": (0, 0, 0), "Head": (2, 0, 0)},
    # rifle across the body: right hand at the grip by the chest, left hand forward on the stock
    "rifle": {"RightUpperArm": (-38, 12, 34), "RightLowerArm": (0, 0, 70), "LeftUpperArm": (-62, -14, -20),
              "LeftLowerArm": (0, 0, -30), "Chest": (6, 0, -10), "UpperChest": (0, 0, -6), "Head": (0, 0, 10)},
    # shotgun: like the rifle, lower and with the support hand further out
    "shotgun": {"RightUpperArm": (-30, 16, 30), "RightLowerArm": (0, 0, 64), "LeftUpperArm": (-55, -6, -14),
                "LeftLowerArm": (0, 0, -18), "Chest": (8, 0, -8), "Head": (0, 0, 8)},
    # LMG at the hip: arms low, torso leaning back slightly for the weight
    "lmg": {"RightUpperArm": (-18, 6, 24), "RightLowerArm": (0, 0, 80), "LeftUpperArm": (-40, -4, -24),
            "LeftLowerArm": (0, 0, -50), "Spine": (-6, 0, 0), "Chest": (2, 0, -12), "Head": (6, 0, 12)},
}


def _merge(*dicts):
    out = {}
    for d in dicts:
        for k, v in d.items():
            out[k] = Z._add(out.get(k, (0, 0, 0)), v)
    return out


def anim_set(arm) -> list[str]:
    def breathe(u):
        return {"Chest": (1.5 * s(u), 0, 0), "UpperChest": (1.0 * s(u, 1, 0.1), 0, 0), "Head": (1.5 * s(u, 1, 0.3), 0, 0)}

    def idle(u):
        return _merge(breathe(u), {"LeftUpperArm": (2 * s(u, 1, 0.2), 0, 0), "RightUpperArm": (2 * s(u, 1, 0.7), 0, 0),
                                   "Hips": (0, 0, 2 * s(u, 1, 0.5))})

    def walk(u):
        g = 24 * s(u)
        return {"LeftUpperLeg": (-g, 0, 0), "RightUpperLeg": (g, 0, 0),
                "LeftLowerLeg": (14 + 18 * s(u, 1, 0.3), 0, 0), "RightLowerLeg": (14 + 18 * s(u, 1, 0.8), 0, 0),
                "LeftFoot": (-6 * s(u, 1, 0.1), 0, 0), "RightFoot": (6 * s(u, 1, 0.1), 0, 0),
                "Spine": (2, 4 * s(u), 3 * s(u)), "LeftUpperArm": (14 * s(u), 0, 0), "RightUpperArm": (-14 * s(u), 0, 0)}

    def walk_hips(u):
        return (0, 0, -0.01 + 0.02 * s(u, 2, 0.25))

    def run(u):
        g = 44 * s(u)
        return {"LeftUpperLeg": (-g - 10, 0, 0), "RightUpperLeg": (g - 10, 0, 0),
                "LeftLowerLeg": (50 + 40 * s(u, 1, 0.35), 0, 0), "RightLowerLeg": (50 + 40 * s(u, 1, 0.85), 0, 0),
                "Spine": (14, 6 * s(u), 0), "Chest": (4, 0, 0), "Head": (-10, 0, 0),
                "LeftUpperArm": (40 * s(u) - 10, -10, 0), "RightUpperArm": (-40 * s(u) - 10, 10, 0),
                "LeftLowerArm": (0, 0, -70), "RightLowerArm": (0, 0, 70)}

    def run_hips(u):
        return (0, 0, -0.05 + 0.04 * s(u, 2, 0.25))

    crouch_legs = {"LeftUpperLeg": (-75, 0, 6), "RightUpperLeg": (-60, 0, -6), "LeftLowerLeg": (105, 0, 0),
                   "RightLowerLeg": (95, 0, 0), "LeftFoot": (-30, 0, 0), "RightFoot": (-35, 0, 0), "Spine": (18, 0, 0),
                   "Head": (-14, 0, 0)}

    def crouch_idle(u):
        return _merge(crouch_legs, breathe(u))

    def crouch_hips(_u):
        return (0, 0.05, -0.36)

    def crouch_walk(u):
        g = 18 * s(u)
        return _merge(crouch_legs, {"LeftUpperLeg": (-g, 0, 0), "RightUpperLeg": (g, 0, 0),
                                    "LeftLowerLeg": (10 * s(u, 1, 0.3), 0, 0), "RightLowerLeg": (10 * s(u, 1, 0.8), 0, 0)})

    def crouch_walk_hips(u):
        return (0, 0.05, -0.36 + 0.015 * s(u, 2, 0.25))

    def slide(_u):
        return {"Hips": (-28, 0, 0), "Spine": (10, 0, 0), "Chest": (8, 0, 0), "Head": (12, 0, 0),
                "LeftUpperLeg": (-70, 0, 4), "LeftLowerLeg": (12, 0, 0), "RightUpperLeg": (-10, 0, -8),
                "RightLowerLeg": (95, 0, 0), "LeftFoot": (-20, 0, 0)}

    def slide_hips(_u):
        return (0, 0.15, -0.55)

    def jump(u):
        k = math.sin(min(1.0, u * 1.4) * math.pi * 0.5)
        return {"LeftUpperLeg": (-45 * k, 0, 0), "RightUpperLeg": (-20 * k, 0, 0), "LeftLowerLeg": (80 * k, 0, 0),
                "RightLowerLeg": (60 * k, 0, 0), "Spine": (6 * k, 0, 0), "LeftUpperArm": (-20 * k, -10 * k, 0),
                "RightUpperArm": (-20 * k, 10 * k, 0)}

    def downed(u):  # last stand: on the ground, propped on the left elbow, dragging with the legs
        g = 10 * s(u)
        return {"Hips": (-70, 0, 0), "Spine": (14, 0, 0), "Chest": (18, 0, 0), "Neck": (10, 0, 0), "Head": (16, 0, 0),
                "LeftUpperArm": (40, -10, 0), "LeftLowerArm": (0, 0, -70),
                "RightUpperArm": (-70, 4, 14), "RightLowerArm": (0, 0, 20),
                "LeftUpperLeg": (-30 + g, 0, 6), "RightUpperLeg": (-15 - g, 0, -6),
                "LeftLowerLeg": (40 - g, 0, 0), "RightLowerLeg": (20 + g, 0, 0)}

    def downed_hips(u):
        return (0, -0.15 + 0.03 * s(u), -0.8)

    def revive(u):  # kneeling over a teammate, both hands reaching down
        return {"LeftUpperLeg": (-90, 0, 4), "LeftLowerLeg": (90, 0, 0), "RightUpperLeg": (-5, 0, -4),
                "RightLowerLeg": (100, 0, 0), "RightFoot": (40, 0, 0), "Spine": (28, 0, 0), "Chest": (12, 0, 0),
                "Head": (10, 0, 0), "LeftUpperArm": (-40 + 6 * s(u, 2), -14, 0), "RightUpperArm": (-40 - 6 * s(u, 2), 14, 0),
                "LeftLowerArm": (0, 0, -20), "RightLowerArm": (0, 0, 20)}

    def revive_hips(_u):
        return (0, 0.1, -0.5)

    def drink(u):  # bottle to the mouth, head back, then down
        k = math.sin(min(1.0, u * 1.25) * math.pi)
        return {"RightUpperArm": (-60 * k, 10 * k, 10 * k), "RightLowerArm": (0, 0, 120 * k), "Head": (-24 * k, 0, 0),
                "Neck": (-10 * k, 0, 0), "Chest": (-4 * k, 0, 0)}

    def hold(kind):
        def fn(u):
            return _merge(HOLD[kind], breathe(u))
        return fn

    def fire(kind):
        def fn(u):
            k = math.exp(-u * 6.0) * min(1.0, u * 12.0)
            kick = {"RightUpperArm": (14 * k, 0, 0), "LeftUpperArm": (10 * k, 0, 0), "Chest": (-5 * k, 0, 0),
                    "Head": (-3 * k, 0, 0)}
            return _merge(HOLD[kind], kick)
        return fn

    def reload(kind):
        def fn(u):
            k = math.sin(u * math.pi)
            return _merge(HOLD[kind], {"LeftUpperArm": (50 * k, 20 * k, 10 * k), "LeftLowerArm": (0, 0, -40 * k),
                                       "Head": (8 * k, 0, -6 * k), "Chest": (4 * k, 0, 0)})
        return fn

    clips = [
        ("idle", 2.0, idle, True, None),
        ("walk", 1.0, walk, True, walk_hips),
        ("run", 0.65, run, True, run_hips),
        ("crouch_idle", 2.0, crouch_idle, True, crouch_hips),
        ("crouch_walk", 1.2, crouch_walk, True, crouch_walk_hips),
        ("slide", 0.6, slide, True, slide_hips),
        ("jump", 0.6, jump, False, None),
        ("downed_crawl", 1.6, downed, True, downed_hips),
        ("revive", 1.0, revive, True, revive_hips),
        ("drink", 1.6, drink, False, None),
        ("hold_pistol", 2.0, hold("pistol"), True, None),
        ("hold_rifle", 2.0, hold("rifle"), True, None),
        ("hold_shotgun", 2.0, hold("shotgun"), True, None),
        ("hold_lmg", 2.0, hold("lmg"), True, None),
        ("fire_pistol", 0.25, fire("pistol"), False, None),
        ("fire_long", 0.3, fire("rifle"), False, None),
        ("reload_pistol", 1.2, reload("pistol"), False, None),
        ("reload_long", 1.8, reload("rifle"), False, None),
    ]
    for name, length, fn, loop, hips in clips:
        make_action(arm, name, length, fn, loop, hips_fn=hips)
    return [c[0] for c in clips]


# ---------------------------------------------------------------------------------------------
# Models: one spec per character (proportions, palette, accessories).

SPECS = {
    "calloway": {"height": 1.70, "arm": 1.0, "coat": "coat_tan", "long_coat": True, "hair": "hair_dark",
                 "band": "band_white", "build": 0.95, "hat": "bun"},
    "orlov": {"height": 1.86, "arm": 1.05, "coat": "coat_blue", "long_coat": False, "hair": "hair_dark",
              "band": "band_blue", "build": 1.18, "hat": "ushanka"},
    "brandt": {"height": 1.73, "arm": 1.0, "coat": "parka_red", "long_coat": False, "hair": "hair_blond",
               "band": "band_yellow", "build": 1.0, "hat": "beanie", "pack": True},
    "ashcombe": {"height": 1.81, "arm": 1.04, "coat": "tweed_brown", "long_coat": True, "hair": "hair_blond",
                 "band": "band_green", "build": 0.9, "hat": "bowler", "scarf": True, "glasses": True},
}


def build_survivor(pts, spec) -> list:
    P = []
    b = spec["build"]
    coat = spec["coat"]
    hx = pts["Hips"][0]
    seg = Z._segment
    P.append(Z._blob("pelvis", "Hips", hx + Vector((0, 0, 0.03)), 0.16 * b, (1.0, 0.7, 0.7), "cloth_trousers"))
    P.append(seg("spine", "Spine", "Hips", 0.15 * b, 0.155 * b, coat, pts, 20, scale_xy=(1, 0.72), ext=(0.05, 0.02)))
    P.append(seg("chest", "Chest", "Spine", 0.155 * b, 0.175 * b, coat, pts, 20, scale_xy=(1, 0.7), ext=(0.02, 0.02)))
    P.append(seg("upperchest", "UpperChest", "Chest", 0.175 * b, 0.14 * b, coat, pts, 20, scale_xy=(1.05, 0.7),
                 ext=(0.02, 0.0)))
    P.append(seg("neck", "Neck", "UpperChest", 0.05, 0.048, "survivor_skin", pts, 12, ext=(0.03, 0.03)))
    hh = pts["Head"][0]
    P.append(Z._blob("skull", "Head", hh + Vector((0, -0.005, 0.11)), 0.1, (0.9, 1.0, 1.08), "survivor_skin", 20, 14))
    P.append(Z._boxpart("jaw", "Head", (0.1, 0.09, 0.05), hh + Vector((0, -0.05, 0.035)), "survivor_skin", 0.02))
    P.append(Z._blob("nose", "Head", hh + Vector((0, -0.1, 0.1)), 0.02, (0.8, 1.0, 1.2), "survivor_skin", 8, 6))
    P.append(Z._blob("hair", "Head", hh + Vector((0, 0.012, 0.15)), 0.104, (0.95, 1.0, 0.9), spec["hair"], 18, 10))
    hat = spec.get("hat")
    if hat == "bun":
        P.append(Z._blob("bun", "Head", hh + Vector((0, 0.09, 0.15)), 0.045, (1, 1, 1), spec["hair"], 12, 8))
    elif hat == "ushanka":
        P.append(Z._blob("hat", "Head", hh + Vector((0, 0.0, 0.2)), 0.125, (1.05, 1.05, 0.7), "fur_grey", 18, 10))
        for sx in (1, -1):
            P.append(Z._boxpart(f"flap_{sx}", "Head", (0.03, 0.09, 0.1), hh + Vector((sx * 0.11, 0.0, 0.1)), "fur_grey",
                                0.015))
    elif hat == "beanie":
        P.append(Z._blob("hat", "Head", hh + Vector((0, 0.005, 0.18)), 0.108, (1.0, 1.0, 0.75), spec["band"], 18, 10))
    elif hat == "bowler":
        P.append(Z._blob("hat", "Head", hh + Vector((0, 0.0, 0.22)), 0.095, (1.0, 1.0, 0.75), "hair_dark", 18, 10))
        P.append(L.cylinder("brim", 0.14, 0.012, tuple(hh + Vector((0, 0.0, 0.195))), "hair_dark", segments=18))
        Z._assign(P[-1], "Head", None, [1.0] * len(P[-1].data.vertices))
    for sx in (1, -1):
        eye = L.sphere(f"eye_{sx}", 0.011, hh + Vector((sx * 0.035, -0.088, 0.125)), "hair_dark", segments=8, rings=4)
        Z._assign(eye, "Head", None, [1.0] * len(eye.data.vertices))
        P.append(eye)
    if spec.get("glasses"):
        for sx in (1, -1):
            g = L.cylinder(f"lens_{sx}", 0.022, 0.006, tuple(hh + Vector((sx * 0.036, -0.098, 0.125))), "metal_dark",
                           rot=(math.pi / 2, 0, 0), segments=12)
            Z._assign(g, "Head", None, [1.0] * len(g.data.vertices))
            P.append(g)
    if spec.get("scarf"):
        P.append(seg("scarf", "Neck", "UpperChest", 0.075, 0.07, "scarf_green", pts, 14, ext=(0.02, -0.02)))
    for side in ("Left", "Right"):
        P.append(seg(f"{side}_shoulder", side + "Shoulder", "UpperChest", 0.065 * b, 0.07 * b, coat, pts, 12, blend=0.4))
        P.append(seg(f"{side}_uarm", side + "UpperArm", side + "Shoulder", 0.06 * b, 0.05 * b, coat, pts, 14,
                     ext=(0.02, 0.0)))
        P.append(seg(f"{side}_larm", side + "LowerArm", side + "UpperArm", 0.048 * b, 0.04, coat, pts, 14,
                     ext=(0.02, 0.0)))
        hand_c = (pts[side + "Hand"][0] + pts[side + "Hand"][1]) * 0.5
        P.append(Z._boxpart(f"{side}_hand", side + "Hand", (0.13, 0.045, 0.085), hand_c, "survivor_skin", 0.015))
        P.append(seg(f"{side}_uleg", side + "UpperLeg", "Hips", 0.08 * b, 0.06, "cloth_trousers", pts, 16,
                     ext=(0.04, 0.0)))
        P.append(seg(f"{side}_lleg", side + "LowerLeg", side + "UpperLeg", 0.056, 0.045, "cloth_trousers", pts, 16,
                     ext=(0.02, 0.0)))
        fh, ft, _ = pts[side + "Foot"]
        P.append(Z._boxpart(f"{side}_foot", side + "Foot", (0.1, 0.24, 0.1),
                            Vector((fh.x, (fh.y + ft.y) * 0.5 - 0.02, 0.05)), "leather_boot", 0.02))
        th, tt, _ = pts[side + "Toes"]
        P.append(Z._boxpart(f"{side}_toes", side + "Toes", (0.1, 0.08, 0.065),
                            Vector((th.x, (th.y + tt.y) * 0.5, 0.033)), "leather_boot", 0.015))
    # Identification armband on the left upper arm (character colour, GAME_DESIGN §13).
    lh, lt, _ = pts["LeftUpperArm"]
    P.append(seg("armband", "LeftUpperArm", None, 0.064 * b, 0.064 * b, spec["band"],
                 {"LeftUpperArm": (lh + (lt - lh) * 0.35, lh + (lt - lh) * 0.55, None)}, 14))
    if spec["long_coat"]:
        P.append(seg("coat_hem", "Hips", None, 0.2 * b, 0.23 * b, coat, {"Hips": (hx + Vector((0, 0, -0.42)),
                     hx + Vector((0, 0, 0.08)), None)}, 20, scale_xy=(1.0, 0.78)))
    else:
        P.append(seg("jacket_hem", "Hips", None, 0.18 * b, 0.17 * b, coat, {"Hips": (hx + Vector((0, 0, -0.08)),
                     hx + Vector((0, 0, 0.1)), None)}, 20, scale_xy=(1.0, 0.75)))
    if spec.get("pack"):
        ch = pts["Chest"][0]
        P.append(Z._boxpart("pack", "Chest", (0.3, 0.16, 0.42), ch + Vector((0, 0.17, 0.08)), "canvas_olive", 0.03))
        P.append(Z._boxpart("pack_roll", "UpperChest", (0.32, 0.1, 0.1), pts["UpperChest"][0] + Vector((0, 0.17, 0.12)),
                            "parka_red", 0.03))
    return P


def main() -> None:
    args = L.argv_after_dashes()
    only = [a for a in args if a in SPECS]
    if not only or "anims" in args:
        L.reset()
        bpy.context.scene.render.fps = FPS
        ref = Z.make_armature("Mannequin", Z.skeleton_points(1.75, 1.0))
        names = anim_set(ref)
        L.export_glb(ANIM_OUT, animations=True)
        print("[blender] survivor anims", ",".join(names))
    for cid in (only or list(SPECS)):
        spec = SPECS[cid]
        L.reset()
        pts = Z.skeleton_points(spec["height"], spec["arm"])
        arm = Z.make_armature("Skeleton", pts)
        parts = build_survivor(pts, spec)
        Z.subdivide_for_budget([p for p in parts if not p.name.startswith(("eye", "lens", "brim"))], 1)
        for p in parts:
            mod = p.modifiers.new("Armature", "ARMATURE")
            mod.object = arm
        body = L.join(parts, "Survivor_" + cid)
        body.parent = arm
        body.data.shade_smooth()
        out = os.path.join(L.GAME_ROOT, "content", "characters", cid, cid + ".glb")
        L.export_glb(out, animations=False)
        print("[blender]", cid, "tris", L.tri_count([body]))


main()
