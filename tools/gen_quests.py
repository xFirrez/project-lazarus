#!/usr/bin/env python3
"""Writes Vesper Peak's QuestGraph resources (maps/vesper_peak/quest/*.tres) from the tables below.

Usage: python3 tools/gen_quests.py   (repo root). The graphs are data; the objective scripts hold logic.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "game"
Q = "res://maps/vesper_peak/scripts/quest/%s.gd"
GRAPHS = {
    "requiem": {
        "title": "Requiem for Lazarus",
        "badge": "requiem",
        "unlocks": ["R09", "requiem"],
        "steps": [
            ("stage0", "The Mountain Stirs", [], "stage0_stirs", "Power on and all three relays; next round the radio wakes.", False),
            ("stage1", "The Frequency", ["stage0"], "stage1_frequency", "Red-ink digits on three documents; tune the Comms Array radio.", False),
            ("stage2a", "Frozen Heart", ["stage1"], "stage2a_frozen_heart", "A big explosion at the frozen fountain's top tier.", False),
            ("stage2b", "The Chained Drawer", ["stage1"], "stage2b_chained_drawer", "Flip the lab breaker; read the morgue's glowing symbols.", False),
            ("stage2c", "The Marked One", ["stage1"], "stage2c_marked_one", "Kill the bright Galvanic of a special round within 40 s.", False),
            ("stage3", "Charging the Heart", ["stage2a", "stage2b", "stage2c"], "stage3_charging", "Conduit kills near the Soul Pod; reseat loose cables.", False),
            ("stage4", "The Descent", ["stage3"], "stage4_descent", "Carry the Heart to the core socket via the tunnels in 4 minutes.", False),
            ("stage5", "Calibration", ["stage4"], "stage5_calibration", "Break four vesperite nodes with Forge-upgraded weapons.", False),
            ("stage6", "Requiem", ["stage5"], "stage6_requiem", "Next round: defend the pylons and defeat the Warden.", True),
            ("blessing", "Lazarus Blessing", ["stage6"], "stage_blessing", "All tonics restored on every revive.", False),
        ],
    },
    "vesper_secrets": {
        "title": "Vesper Peak secrets",
        "badge": "",
        "unlocks": [],
        "steps": [
            ("s1_office", "The Director's Office", [], "secret_office", "The guestbook names room seven; its mirror.", False),
            ("s2_grotto", "The Ice Grotto", [], "secret_grotto", "After power, the waterfall cracks: blast it.", False),
            ("snowblind", "Snowblind", [], "secret_snowblind", "Three hidden music boxes.", False),
            ("ravens", "Frozen Ravens", [], "secret_ravens", "Five frozen ravens around the exterior.", False),
        ],
    },
}


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


for gid, g in GRAPHS.items():
    scripts = sorted({s[3] for s in g["steps"]})
    ext = ['[ext_resource type="Script" path="res://core/quest/quest_graph.gd" id="graph"]',
           '[ext_resource type="Script" path="res://core/quest/quest_step.gd" id="step"]']
    ext += [f'[ext_resource type="Script" path="{Q % s}" id="{s}"]' for s in scripts]
    subs = []
    for sid, title, pre, script, hint, completes in g["steps"]:
        pres = ", ".join(f'&"{p}"' for p in pre)
        subs.append(
            f'[sub_resource type="Resource" id="{sid}"]\nscript = ExtResource("step")\nid = &"{sid}"\n'
            f'title = "{esc(title)}"\nprerequisites = Array[StringName]([{pres}])\nobjective = ExtResource("{script}")\n'
            f'hint = "{esc(hint)}"\ncompletes_graph = {"true" if completes else "false"}\n'
        )
    steps = ", ".join(f'SubResource("{s[0]}")' for s in g["steps"])
    unl = ", ".join(f'&"{u}"' for u in g["unlocks"])
    out = [f'[gd_resource type="Resource" script_class="QuestGraph" load_steps={len(ext) + len(subs) + 1} format=3]', ""]
    out += ext + [""] + subs + [
        "[resource]",
        'script = ExtResource("graph")',
        f'id = &"{gid}"',
        f'title = "{esc(g["title"])}"',
        f'steps = Array[QuestStep]([{steps}])',
        f'badge = &"{g["badge"]}"',
        f"journal_unlocks = Array[StringName]([{unl}])",
        "",
    ]
    p = ROOT / "maps" / "vesper_peak" / "quest" / f"{gid}.tres"
    p.write_text("\n".join(out))
    print("wrote", p)
