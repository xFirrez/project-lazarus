#!/usr/bin/env python3
# Generates game/maps/vesper_peak/art/zone_atmosphere.tres (Step 13): Vesper Peak's per-zone
# AtmosphereProfiles (VESPER_PEAK §8.1 palette & contrast rule). Edit the table, re-run:
#   python3 tools/art/gen_atmosphere.py
import os
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "game", "maps", "vesper_peak", "art", "zone_atmosphere.tres")
# zone: fog colour, fog density, ambient colour, ambient energy, brightness, contrast, saturation,
#       vol density, vol albedo, vol emission, moon share, snow, exposure, note
Z = {
 "Z01": ((0.12,0.15,0.2),0.008,(0.25,0.28,0.36),0.55,1.0,1.10,0.85,0.030,(0.6,0.7,0.85),(0.006,0.01,0.018),1.0,0.25,1.25,"cold moon shafts through frosted panes; warm swinging tungsten accent"),
 "Z03": ((0.22,0.17,0.12),0.009,(0.42,0.32,0.24),0.5,1.0,1.06,0.92,0.020,(0.9,0.8,0.65),(0.012,0.008,0.004),0.55,0.0,1.25,"warm dusty amber lobby; blue moon shafts from the terrace windows"),
 "Z04": ((0.15,0.17,0.15),0.010,(0.28,0.32,0.3),0.45,0.98,1.10,0.78,0.020,(0.75,0.8,0.75),(0.004,0.006,0.004),0.4,0.05,1.2,"military fluorescents over Victorian fittings: sickly cold-green"),
 "Z05": ((0.16,0.2,0.24),0.009,(0.3,0.36,0.42),0.5,1.0,1.10,0.82,0.025,(0.75,0.85,0.95),(0.006,0.008,0.012),0.9,0.2,1.25,"cold surgical light under the dome; green arcs"),
 "Z06": ((0.16,0.22,0.3),0.007,(0.22,0.3,0.42),0.75,1.0,1.08,0.88,0.018,(0.55,0.65,0.8),(0.012,0.02,0.035),1.0,0.85,1.25,"the storm at its strongest; warm sanatorium windows as the accent"),
 "Z07": ((0.15,0.22,0.27),0.008,(0.22,0.32,0.4),0.75,1.0,1.08,0.85,0.02,(0.55,0.7,0.8),(0.01,0.024,0.03),1.0,0.8,1.25,"ridge-top storm, aurora-green cloud glow, red aircraft lights"),
 "Z08": ((0.2,0.12,0.07),0.015,(0.32,0.2,0.12),0.45,1.0,1.12,0.95,0.035,(0.8,0.6,0.45),(0.02,0.008,0.002),0.0,0.0,1.2,"furnace orange and soot; cold steam as the accent"),
 "Z09": ((0.12,0.11,0.09),0.011,(0.22,0.2,0.16),0.4,1.0,1.12,0.85,0.025,(0.75,0.7,0.6),(0.006,0.004,0.002),0.0,0.0,1.2,"sodium lamps over the generators; green reactor light through the grates"),
 "Z10": ((0.08,0.13,0.1),0.012,(0.16,0.24,0.18),0.4,0.98,1.10,0.75,0.030,(0.6,0.75,0.62),(0.002,0.008,0.004),0.0,0.0,1.2,"green emergency bulbs, damp, breath fog"),
 "Z11": ((0.14,0.19,0.19),0.010,(0.3,0.38,0.38),0.45,1.0,1.08,0.8,0.022,(0.75,0.85,0.85),(0.004,0.008,0.008),0.0,0.0,1.2,"sterile teal tile; red alarm strobes and a green vesperite leak"),
 "Z12": ((0.12,0.18,0.2),0.012,(0.24,0.32,0.36),0.45,1.0,1.08,0.8,0.030,(0.7,0.85,0.9),(0.004,0.01,0.012),0.0,0.0,1.2,"freezing cold storage; green reactor glow through the gallery glass"),
 "Z13": ((0.06,0.14,0.09),0.006,(0.14,0.22,0.17),0.55,1.0,1.12,0.9,0.014,(0.4,0.8,0.5),(0.0,0.02,0.008),0.0,0.0,1.25,"black stone and brass; vesperite-green haze around the core"),
}
FALLBACK = "Z06"


def col(c):
    return "Color(%g, %g, %g, 1)" % c


def sub(i, z, v):
    return "\n".join([
        f'[sub_resource type="Resource" id="{i}"]',
        'script = ExtResource("1")',
        f"fog_color = {col(v[0])}", f"fog_density = {v[1]}", f"ambient_color = {col(v[2])}",
        f"ambient_energy = {v[3]}", f"brightness = {v[4]}", f"contrast = {v[5]}", f"saturation = {v[6]}",
        f"vol_fog_density = {v[7]}", f"vol_fog_albedo = {col(v[8])}", f"vol_fog_emission = {col(v[9])}",
        f"moon_energy = {v[10]}", f"snow = {v[11]}", f"exposure = {v[12]}", f'note = "{z}: {v[13]}"', ""])


lines = [f'[gd_resource type="Resource" script_class="AtmosphereSet" load_steps={len(Z) + 3} format=3]', "",
         '[ext_resource type="Script" path="res://core/render/atmosphere_profile.gd" id="1"]',
         '[ext_resource type="Script" path="res://core/render/atmosphere_set.gd" id="2"]', ""]
for z, v in Z.items():
    lines.append(sub("p_" + z, z, v))
lines += ["[resource]", 'script = ExtResource("2")', f'fallback = SubResource("p_{FALLBACK}")',
          "profiles = {" + ", ".join(f'&"{z}": SubResource("p_{z}")' for z in Z) + "}", ""]
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w").write("\n".join(lines))
print("wrote", os.path.abspath(OUT))
