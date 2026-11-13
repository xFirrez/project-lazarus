#!/usr/bin/env python3
"""Writes content/perks/<id>.tres from the Vigor Tonic table (GAME_DESIGN §8).

Run from the repository root: python3 tools/gen_perks.py
Numbers here must match GAME_DESIGN §8; the jingles are original placeholder melodies
(semitone offsets from the root, beat lengths) written for Project Lazarus (Step 15 replaces them).
"""
import os

SET, MUL, ADD = 0, 1, 2

PERKS = [
    dict(id="ironhide", name="Ironhide Stout", tag="Max HP 100 -> 250", cost=2000 + 500, power=True,
         marker="Perk_Ironhide", order=0, color=(0.95, 0.12, 0.08), accent=(0.28, 0.12, 0.1), sil=0, letter="I",
         mods=[("max_health", SET, 250.0)],
         root=110.0, wave=1, beat=0.24, notes=[0, 0, 7, 5, 3, 0, -2, 0], beats=[1, 1, 2, 1, 1, 1, 1, 3]),
    dict(id="quickdraw", name="Quickdraw Fizz", tag="Reload x0.5, swap x0.5, equipment faster", cost=3000,
         power=True, marker="Perk_Quickdraw", order=1, color=(0.2, 0.95, 0.3), accent=(0.1, 0.25, 0.14), sil=1,
         letter="Q", mods=[("reload_speed", MUL, 2.0), ("equipment_speed", MUL, 1.5)],
         root=330.0, wave=0, beat=0.16, notes=[0, 4, 7, 12, 7, 4, 7, 12, 16], beats=[1, 1, 1, 2, 1, 1, 1, 1, 3]),
    dict(id="twin_fire", name="Twin-Fire Root Beer", tag="Fire rate x1.33, hitscan bullets fire twice",
         cost=2000, power=True, marker="Perk_TwinFire", order=2, color=(1.0, 0.6, 0.08), accent=(0.3, 0.17, 0.06),
         sil=2, letter="T", mods=[("fire_rate", MUL, 1.33), ("double_tap", ADD, 1.0)],
         root=196.0, wave=1, beat=0.18, notes=[0, 0, 3, 0, 0, 5, 3, 7], beats=[1, 1, 1, 1, 1, 1, 1, 3]),
    dict(id="marathon", name="Marathon Malt", tag="Move +7%, sprint 10 s, faster recharge", cost=2000,
         power=True, marker="Perk_MarathonMalt", order=3, color=(1.0, 0.72, 0.15), accent=(0.32, 0.22, 0.08),
         sil=3, letter="M", mods=[("move_speed", MUL, 1.07), ("sprint_duration", SET, 10.0),
                                   ("sprint_recharge", MUL, 2.0)],
         root=262.0, wave=3, beat=0.14, notes=[0, 2, 4, 5, 7, 9, 11, 12, 7, 12], beats=[1, 1, 1, 1, 1, 1, 1, 2, 1, 3]),
    dict(id="second_wind", name="Second Wind Seltzer",
         tag="Solo: self-revive (3 per match). Co-op: revive in 2 s", cost=500, cost_coop=1500, power=False,
         marker="Perk_SecondWind", order=4, color=(0.45, 0.8, 1.0), accent=(0.82, 0.86, 0.9), sil=4, letter="S",
         mods=[("revive_time", SET, 2.0), ("self_revive", ADD, 1.0)],
         root=392.0, wave=2, beat=0.26, notes=[0, 7, 4, 12, 11, 7, 9, 7], beats=[1, 1, 1, 2, 1, 1, 1, 3]),
    dict(id="bullseye", name="Bullseye Bitters", tag="Hip spread -40%, ADS head snap, headshots +25%",
         cost=1500, power=True, marker="Perk_Bullseye", order=5, color=(0.1, 0.85, 0.78), accent=(0.08, 0.24, 0.24),
         sil=5, letter="B", mods=[("hip_spread", MUL, 0.6), ("aim_snap", SET, 0.15), ("headshot_bonus", MUL, 1.25)],
         root=294.0, wave=0, beat=0.2, notes=[0, 3, 7, 10, 7, 3, 2, 0], beats=[1, 1, 1, 2, 1, 1, 1, 3]),
    dict(id="pack_mule", name="Pack Mule Cream Soda", tag="Third weapon slot", cost=4000, power=True,
         marker="Perk_PackMule", order=6, color=(0.75, 0.95, 0.45), accent=(0.86, 0.8, 0.62), sil=6, letter="P",
         mods=[("weapon_slots", ADD, 1.0)],
         root=147.0, wave=3, beat=0.22, notes=[0, 5, 0, 5, 7, 5, 4, 2, 0], beats=[1, 1, 1, 1, 2, 1, 1, 1, 3]),
]


def col(c):
    return "Color(%g, %g, %g, 1)" % c


def write(p, out_dir):
    mods = p["mods"]
    lines = [
        '[gd_resource type="Resource" script_class="PerkDefinition" load_steps=%d format=3]' % (3 + len(mods)),
        "",
        '[ext_resource type="Script" path="res://core/perks/perk_definition.gd" id="1"]',
        '[ext_resource type="Script" path="res://core/perks/stat_modifier.gd" id="2"]',
        "",
    ]
    for i, (stat, op, value) in enumerate(mods):
        lines += ['[sub_resource type="Resource" id="mod_%d"]' % i, 'script = ExtResource("2")',
                  'stat = &"%s"' % stat, "op = %d" % op, "value = %s" % repr(float(value)), ""]
    refs = ", ".join('SubResource("mod_%d")' % i for i in range(len(mods)))
    lines += [
        "[resource]",
        'script = ExtResource("1")',
        'id = &"%s"' % p["id"],
        'display_name = "%s"' % p["name"],
        'tagline = "%s"' % p["tag"],
        "cost = %d" % p["cost"],
        "cost_coop = %d" % p.get("cost_coop", -1),
        "requires_power = %s" % ("true" if p["power"] else "false"),
        'marker_id = &"%s"' % p["marker"],
        'modifiers = Array[ExtResource("2")]([%s])' % refs,
        "sort_order = %d" % p["order"],
        "color = %s" % col(p["color"]),
        "accent = %s" % col(p["accent"]),
        "silhouette = %d" % p["sil"],
        'cap_letter = "%s"' % p["letter"],
        "jingle_root_hz = %s" % repr(float(p["root"])),
        "jingle_notes = PackedInt32Array(%s)" % ", ".join(str(n) for n in p["notes"]),
        "jingle_beats = PackedFloat32Array(%s)" % ", ".join(repr(float(b)) for b in p["beats"]),
        "jingle_beat_seconds = %s" % repr(float(p["beat"])),
        "jingle_wave = %d" % p["wave"],
        "",
    ]
    with open(os.path.join(out_dir, p["id"] + ".tres"), "w") as f:
        f.write("\n".join(lines))


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "game", "content", "perks")
    os.makedirs(out_dir, exist_ok=True)
    for p in PERKS:
        write(p, out_dir)
    print("wrote %d perks to %s" % (len(PERKS), out_dir))


if __name__ == "__main__":
    main()
