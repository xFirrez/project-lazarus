#!/usr/bin/env python3
# Generates the Step 9 WeaponDefinition resources (content/weapons/<id>/<id>.tres) from the spec
# table (game/tests/data/weapons_spec.json, = GAME_DESIGN §4.3) plus the per-weapon handling below.
# Hand-tuned Step 3/6 weapons (m1911, mp40, m14, coachgun, model37, kar98k) are never touched.
# Run from the repo root: python3 tools/gen_weapons.py [--force]
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
SPEC = json.load(open(os.path.join(ROOT, "tests/data/weapons_spec.json")))
HAND_TUNED = {"m1911", "mp40", "m14", "coachgun", "model37", "kar98k", "frag", "knife"}
CLASSES = ["PISTOL", "SMG", "AR", "SHOTGUN", "LMG", "PRECISION", "EXPLOSIVE", "WONDER", "MELEE", "LETHAL",
           "TACTICAL", "PLACEABLE"]
FIRE = {"semi": 0, "pump": 0, "bolt": 0, "single": 0, "auto": 1, "burst": 2}

# Class templates: handling, falloff, spread, reload, presentation.
BASE = {
    "PISTOL": dict(range_min=12, range_max=30, mdf=0.6, max_range=100, rp=1.5, re=1.9, ap=1.0, ae=1.3,
                   raise_t=0.35, lower=0.25, ads=0.18, sprint_out=0.15, fov=0.88, hip=1.6, adsp=0.12, mv=1.4,
                   pershot=0.4, smax=4.0, style="pistol", off=(0.16, -0.16, -0.32), sh=0.05, msm=1.0, tr=1),
    "SMG": dict(range_min=15, range_max=35, mdf=0.6, max_range=100, rp=2.2, re=2.8, ap=1.5, ae=1.9,
                raise_t=0.45, lower=0.3, ads=0.22, sprint_out=0.2, fov=0.85, hip=2.2, adsp=0.15, mv=1.5,
                pershot=0.25, smax=4.5, style="smg", off=(0.14, -0.17, -0.3), sh=0.068, msm=1.0, tr=3),
    "AR": dict(range_min=25, range_max=60, mdf=0.65, max_range=150, rp=2.4, re=3.0, ap=1.6, ae=2.1,
               raise_t=0.5, lower=0.35, ads=0.26, sprint_out=0.25, fov=0.8, hip=2.5, adsp=0.1, mv=1.8,
               pershot=0.3, smax=5.0, style="rifle", off=(0.14, -0.17, -0.3), sh=0.07, msm=1.15, tr=3),
    "SHOTGUN": dict(range_min=6, range_max=18, mdf=0.3, max_range=40, rp=2.6, re=3.2, ap=1.8, ae=2.4,
                    raise_t=0.5, lower=0.35, ads=0.25, sprint_out=0.25, fov=0.88, hip=1.5, adsp=0.8, mv=1.0,
                    pershot=0.6, smax=3.0, style="shotgun", off=(0.15, -0.18, -0.32), sh=0.06, msm=1.6, tr=1),
    "LMG": dict(range_min=25, range_max=60, mdf=0.65, max_range=150, rp=4.5, re=5.5, ap=3.4, ae=4.2,
                raise_t=0.75, lower=0.5, ads=0.4, sprint_out=0.35, fov=0.82, hip=3.0, adsp=0.25, mv=2.0,
                pershot=0.2, smax=6.0, style="lmg", off=(0.15, -0.2, -0.32), sh=0.075, msm=1.3, tr=3),
    "PRECISION": dict(range_min=40, range_max=100, mdf=0.8, max_range=200, rp=2.6, re=3.2, ap=1.9, ae=2.4,
                      raise_t=0.6, lower=0.4, ads=0.32, sprint_out=0.3, fov=0.35, hip=4.0, adsp=0.0, mv=2.5,
                      pershot=0.0, smax=6.0, style="rifle_scoped", off=(0.15, -0.18, -0.32), sh=0.075, msm=1.4,
                      tr=1),
    "EXPLOSIVE": dict(range_min=0, range_max=1, mdf=1.0, max_range=150, rp=3.0, re=3.0, ap=2.2, ae=2.2,
                      raise_t=0.6, lower=0.4, ads=0.3, sprint_out=0.3, fov=0.8, hip=1.8, adsp=0.1, mv=1.0,
                      pershot=0.0, smax=3.0, style="launcher", off=(0.16, -0.17, -0.3), sh=0.09, msm=1.6, tr=0),
}

# Per weapon: speed multiplier, recoil (vertical, horizontal wobble), view kick, colour, sound
# (body Hz, mech Hz, tail s, dB), plus any overrides of the class template.
WEAPON = {
    "revolver": dict(name='"Widow" .357 Revolver', speed=1.0, rv=1.6, rh=0.25, kick=1.6, color=(0.32, 0.32, 0.35),
                     snd=(120, 1800, 0.8, 0.0), rp=2.8, re=2.8, ap=2.3, ae=2.3, msm=1.3),
    "mauser": dict(name="Mauser C96", speed=1.0, rv=0.55, rh=0.2, kick=0.5, color=(0.18, 0.17, 0.16),
                   snd=(210, 3200, 0.45, -3.0), rp=2.0, re=2.4, ap=1.4, ae=1.7),
    "grease_gun": dict(name="M3 Grease Gun", speed=0.97, rv=0.38, rh=0.08, kick=0.3, color=(0.24, 0.25, 0.22),
                       snd=(125, 1500, 0.6, -3.0), pershot=0.18),
    "skorpion": dict(name="Skorpion", speed=1.0, rv=0.42, rh=0.3, kick=0.25, color=(0.15, 0.15, 0.16),
                     snd=(230, 3600, 0.4, -6.0), rp=1.8, re=2.3, ap=1.2, ae=1.6, hip=2.6, pershot=0.3, off=(0.15, -0.16, -0.3)),
    "ppsh": dict(name="PPSh-41", speed=0.95, rv=0.5, rh=0.35, kick=0.3, color=(0.27, 0.18, 0.1),
                 snd=(175, 2600, 0.55, -5.0), rp=2.6, re=3.4, ap=1.8, ae=2.4, pershot=0.22, smax=5.5),
    "m16": dict(name="M16", speed=0.95, rv=0.55, rh=0.12, kick=0.45, color=(0.13, 0.13, 0.13),
                snd=(165, 2900, 0.7, -2.0), burst=3),
    "ak47": dict(name="AK-47", speed=0.94, rv=0.85, rh=0.35, kick=0.6, color=(0.33, 0.2, 0.1),
                 snd=(135, 2200, 0.75, -1.0)),
    "fal": dict(name="FAL", speed=0.94, rv=1.1, rh=0.2, kick=0.9, color=(0.2, 0.2, 0.18),
                snd=(118, 1950, 0.85, -1.0), pershot=0.5),
    "g3": dict(name="G3", speed=0.93, rv=0.95, rh=0.3, kick=0.75, color=(0.22, 0.23, 0.2),
               snd=(128, 2450, 0.8, -1.5), penetration=3),
    "auto12": dict(name='"Thunderer" Auto-12', speed=0.92, rv=1.6, rh=0.4, kick=1.8, color=(0.19, 0.19, 0.2),
                   snd=(85, 1300, 0.9, 0.0), spread_pellet=4.2, rp=2.8, re=3.4, ap=2.0, ae=2.6, msm=1.7),
    "rpd": dict(name="RPD", speed=0.85, rv=0.5, rh=0.25, kick=0.45, color=(0.3, 0.2, 0.12),
                snd=(140, 2050, 0.9, -2.0)),
    "m60": dict(name="M60", speed=0.82, rv=0.65, rh=0.3, kick=0.55, color=(0.17, 0.18, 0.16),
                snd=(105, 1700, 1.0, -1.0), penetration=4, rp=5.0, re=6.0, ap=3.8, ae=4.6),
    "mg42": dict(name="MG42", speed=0.82, rv=0.45, rh=0.4, kick=0.35, color=(0.16, 0.16, 0.17),
                 snd=(190, 3400, 0.95, -3.0), ads=0.55, rp=4.8, re=5.8, ap=3.6, ae=4.4),
    "dragunov": dict(name="Dragunov SVD", speed=0.93, rv=1.8, rh=0.35, kick=1.6, color=(0.28, 0.19, 0.12),
                     snd=(115, 1600, 1.1, -0.5), rp=2.4, re=3.0, ap=1.7, ae=2.2, sway=0.3, pershot=0.0),
    "law": dict(name="M72 LAW", speed=0.9, rv=2.5, rh=0.2, kick=3.0, color=(0.3, 0.33, 0.2),
                snd=(70, 900, 1.4, 1.0), rpm=60, proj=dict(speed=45.0, gravity=1.5, bounce=0.0, radius=0.07,
                                                           arm=1.5)),
    "china_lake": dict(name="China Lake", speed=0.92, rv=2.0, rh=0.2, kick=2.2, color=(0.2, 0.21, 0.19),
                       snd=(95, 1100, 0.7, -1.0), fuse=2.5, reload_per_shell=True,
                       proj=dict(speed=24.0, gravity=9.8, bounce=0.45, radius=0.05, arm=0.0)),
    "crossbow": dict(name="Crossbow", speed=0.95, rv=0.8, rh=0.1, kick=0.7, color=(0.3, 0.22, 0.14),
                     snd=(240, 1000, 0.3, -6.0), rpm=60, style="crossbow", ads=0.28,
                     proj=dict(speed=60.0, gravity=2.0, bounce=0.0, radius=0.03, arm=0.0)),
}

EQUIP = {
    "decoy": dict(name="Drummer Decoy", body=(0.55, 0.12, 0.1)),
    "tripmines": dict(name="Tripmines", body=(0.25, 0.3, 0.22)),
    "ice_axe": dict(name="Ice Axe", body=(0.55, 0.6, 0.65)),
}


def f(v):
    return "%s" % (float(v) if isinstance(v, (int, float)) else v)


def color(c):
    return "Color(%s, %s, %s, 1)" % c


def recoil(rv, rh, burst):
    pts = []
    n = 8
    for i in range(n):
        x = rh * (0.6 if i % 2 == 0 else -0.6) * (1.0 + 0.15 * i)
        if i == 0:
            x = 0.0
        y = rv * (1.0 - 0.04 * i)
        pts.append("0, 0, 0, 0, %.3f, %.3f" % (x, y))
    return 'points": PackedVector2Array(%s)' % ", ".join(pts), n


def write(wid, lines, curve):
    d = os.path.join(ROOT, "content/weapons", wid)
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, wid + ".tres")
    if os.path.exists(path) and "--force" not in sys.argv:
        return
    head = ['[gd_resource type="Resource" script_class="WeaponDefinition" load_steps=%d format=3]' % (3 if curve else 2),
            "", '[ext_resource type="Script" path="res://core/weapons/weapon_definition.gd" id="1"]', ""]
    if curve:
        pts, n = curve
        head += ['[sub_resource type="Curve2D" id="recoil"]', "_data = {", '"' + pts, "}", "point_count = %d" % n, ""]
    body = ["[resource]", 'script = ExtResource("1")'] + lines
    if curve:
        body.append('recoil_pattern = SubResource("recoil")')
    open(path, "w").write("\n".join(head + body) + "\n")
    print("wrote", path)


def gun(wid, s):
    w = WEAPON[wid]
    cls = s["class"]
    b = dict(BASE[cls])
    b.update({k: v for k, v in w.items() if k in b})
    pellets = int(s.get("pellets", 1))
    head = SPEC["head_multiplier"].get(cls, SPEC["head_multiplier"]["default"])
    pen = w.get("penetration", SPEC["penetration"].get(cls, 1))
    rpm = s.get("rpm", w.get("rpm", 60))
    L = ['id = &"%s"' % wid, 'display_name = "%s"' % w["name"].replace('"', '\\"'),
         "weapon_class = %d" % CLASSES.index(cls), "cost = %d" % s.get("cost", 0),
         'behavior = &"%s"' % ("projectile" if "projectile" in s else ("pellet" if pellets > 1 else "hitscan")),
         "fire_mode = %d" % FIRE[s["fire"]], "rpm = %s" % f(rpm), "burst_count = %d" % s.get("burst", 3),
         "damage = %s" % f(s["damage"]), "pellets = %d" % pellets,
         "pellet_spread_deg = %s" % f(w.get("spread_pellet", 4.0 if pellets > 1 else 0.0)),
         "max_range = %s" % f(b["max_range"]), "head_multiplier = %s" % f(head),
         "neck_multiplier = %s" % f(1.25 if cls == "SHOTGUN" else 2.0), "torso_multiplier = 1.0",
         "limb_multiplier = 0.75", "range_min = %s" % f(b["range_min"]), "range_max = %s" % f(b["range_max"]),
         "min_damage_fraction = %s" % f(b["mdf"]), "penetration = %d" % pen, "penetration_loss = 0.25",
         "mag_size = %d" % s["mag"], "reserve_max = %d" % s["reserve"],
         "reload_partial_time = %s" % f(b["rp"]), "reload_empty_time = %s" % f(b["re"]),
         "ammo_in_partial = %s" % f(b["ap"]), "ammo_in_empty = %s" % f(b["ae"])]
    if w.get("reload_per_shell"):
        L += ["reload_per_shell = true", "reload_start_time = 0.4", "shell_insert_time = 0.6", "reload_end_time = 0.4"]
    L += ["raise_time = %s" % f(b["raise_t"]), "lower_time = %s" % f(b["lower"]), "ads_time = %s" % f(b["ads"]),
          "sprint_out_time = %s" % f(b["sprint_out"]), "ads_fov_multiplier = %s" % f(b["fov"]),
          "move_speed_multiplier = %s" % f(w["speed"]),
          "spread_hip = %s" % f(b["hip"]), "spread_ads = %s" % f(b["adsp"]), "spread_move = %s" % f(b["mv"]),
          "spread_per_shot = %s" % f(b["pershot"]), "spread_max = %s" % f(b["smax"]), "spread_recovery = 8.0",
          "recoil_random = %s" % f(w["rh"] * 0.6), "recoil_ads_multiplier = 0.65", "recoil_recovery = 0.6",
          "recoil_recovery_speed = 6.0", "view_kick = %s" % f(w["kick"]),
          "vm_kick_back = %s" % f(round(0.02 + 0.02 * w["kick"], 3)),
          "vm_kick_rot = %s" % f(round(1.5 + 2.0 * w["kick"], 2))]
    if "splash" in s:
        p = w["proj"]
        L += ["splash_radius = %s" % f(s["splash"][1]), "splash_damage_centre = %s" % f(s["splash"][0]),
              "splash_damage_edge = 0.0", "self_damage_max = 60.0", "fuse_time = %s" % f(s.get("fuse", w.get("fuse", 3.0))),
              'projectile_kind = &"%s"' % s["projectile"], "projectile_speed = %s" % f(p["speed"]),
              "projectile_gravity = %s" % f(p["gravity"]), "projectile_bounce = %s" % f(p["bounce"]),
              "projectile_radius = %s" % f(p["radius"]), "projectile_arm_distance = %s" % f(p["arm"])]
    off = b["off"]
    L += ['viewmodel_style = &"%s"' % w.get("style", b["style"]), "viewmodel_color = %s" % color(w["color"]),
          "viewmodel_offset = Vector3(%s, %s, %s)" % off, "sight_height = %s" % f(b["sh"]),
          "viewmodel_fov = 65.0", "scope_sway = %s" % f(w.get("sway", 0.0)), "tracer_every = %d" % b["tr"],
          "shell_size = %s" % f(0.013 if cls in ("AR", "LMG", "PRECISION") else 0.01),
          "muzzle_flash_scale = %s" % f(b["msm"]),
          "sound_body_hz = %s" % f(w["snd"][0]), "sound_mech_hz = %s" % f(w["snd"][1]),
          "sound_tail_s = %s" % f(w["snd"][2]), "sound_volume_db = %s" % f(w["snd"][3])]
    write(wid, L, recoil(w["rv"], w["rh"], s.get("burst", 0)))


def equipment(wid, s):
    e = EQUIP[wid]
    cls = s["class"]
    L = ['id = &"%s"' % wid, 'display_name = "%s"' % e["name"], "weapon_class = %d" % CLASSES.index(cls),
         "cost = %d" % s.get("cost", 0)]
    if cls == "MELEE":
        L += ['behavior = &"melee"', "fire_mode = 0", "rpm = 171.0", "damage = %s" % f(s["damage"]),
              "max_range = 4.0", "penetration = 1", "mag_size = 0", "reserve_max = 0",
              "melee_time = %s" % f(s["melee_time"]), "melee_reach = 1.3", "melee_lunge = 2.2",
              "melee_cone_deg = 38.0", "viewmodel_color = %s" % color(e["body"]),
              "sound_body_hz = 300.0", "sound_mech_hz = 900.0", "sound_tail_s = 0.25", "sound_volume_db = -4.0"]
    else:
        L += ['behavior = &"projectile"', "fire_mode = 0", "damage = 0.0", "mag_size = 0", "reserve_max = 0",
              "splash_radius = %s" % f(s["splash"][1]), "splash_damage_centre = %s" % f(s["splash"][0]),
              "splash_damage_edge = %s" % f(s.get("edge", 0)), "self_damage_max = 60.0",
              "carry_start = %d" % s["carry_start"], "carry_max = %d" % s["carry_max"],
              "viewmodel_color = %s" % color(e["body"])]
        if cls == "TACTICAL":
            L += ["fuse_time = %s" % f(s["attract_time"]), "throw_speed = 14.0",
                  "attract_radius = %s" % f(s["attract_radius"]), "attract_time = %s" % f(s["attract_time"]),
                  "sound_body_hz = 520.0", "sound_mech_hz = 1400.0", "sound_tail_s = 0.3", "sound_volume_db = -6.0"]
        else:
            L += ["trigger_radius = 2.0", "place_limit = %d" % s["place_limit"], "fuse_time = 0.25",
                  "sound_body_hz = 700.0", "sound_mech_hz = 2600.0", "sound_tail_s = 0.2", "sound_volume_db = -8.0"]
    write(wid, L, None)


for wid, s in SPEC["weapons"].items():
    if wid not in HAND_TUNED:
        gun(wid, s)
for wid, s in SPEC["equipment"].items():
    if wid not in HAND_TUNED:
        equipment(wid, s)
