#!/usr/bin/env python3
# Generates the Lazarus Forge upgraded WeaponDefinitions (Step 11, GAME_DESIGN §9.3) from the table
# game/tests/data/upgrades_spec.json: each content/weapons/<base>/<base>_up.tres is a copy of the
# base .tres with damage x2 (splash x2), the table's mag / reserve, the upgraded name, the vesperite
# camo, `base_id` and the listed behavior-change fields. Attachments (the Skullcrusher's underbarrel
# launcher) are copies of another weapon with explicit fields and `attachment_of`.
# Wonder weapons (Step 12, GAME_DESIGN §7) come from the "wonder_upgrades" table with explicit
# values (Nova Mk.II, Lazarus Requiem): no x2 rule, everything else copied from the base.
# Always regenerates (the upgraded files are derived data; edit the table or the base weapon).
# Run from the repo root: python3 tools/gen_upgrades.py
import json
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
SPEC = json.load(open(os.path.join(ROOT, "tests/data/upgrades_spec.json")))


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, str):
        if v.startswith("&"):
            return '&"%s"' % v[1:]
        if v.startswith("Color("):
            return v
        return json.dumps(v)
    raise ValueError(v)


def load(base):
    path = os.path.join(ROOT, "content/weapons", base, base + ".tres")
    return open(path).read()


def split(text):
    head, body = text.split("[resource]\n", 1)
    head = re.sub(r' uid="[^"]*"', "", head, count=1)  # the header uid must stay unique
    props = []
    for line in body.splitlines():
        if " = " in line:
            k, v = line.split(" = ", 1)
            props.append([k, v])
    return head, props


def get(props, key, default=None):
    for k, v in props:
        if k == key:
            return v
    return default


def put(props, key, value):
    for p in props:
        if p[0] == key:
            p[1] = value
            return
    props.append([key, value])


def write(base_dir, out_id, head, props):
    path = os.path.join(ROOT, "content/weapons", base_dir, out_id + ".tres")
    with open(path, "w") as f:
        f.write(head + "[resource]\n" + "\n".join("%s = %s" % (k, v) for k, v in props) + "\n")
    return path


def main():
    n = 0
    for base, u in SPEC["upgrades"].items():
        head, props = split(load(base))
        up = base + "_up"
        put(props, "id", '&"%s"' % up)
        put(props, "display_name", json.dumps(u["name"]))
        for key in ("damage", "splash_damage_centre", "splash_damage_edge"):
            v = get(props, key)
            if v is not None:
                put(props, key, repr(float(v) * 2.0))
        put(props, "mag_size", str(u["mag"]))
        put(props, "reserve_max", str(u["reserve"]))
        put(props, "base_id", '&"%s"' % base)
        put(props, "camo", '&"vesperite"')
        for k, v in u["set"].items():
            put(props, k, fmt(v))
        write(base, up, head, props)
        n += 1
    for base, u in SPEC.get("wonder_upgrades", {}).items():
        if base == "doc":
            continue
        head, props = split(load(base))
        up = base + "_up"
        put(props, "id", '&"%s"' % up)
        put(props, "display_name", json.dumps(u["name"]))
        put(props, "mag_size", str(u["mag"]))
        put(props, "reserve_max", str(u["reserve"]))
        put(props, "base_id", '&"%s"' % base)
        put(props, "camo", '&"vesperite"')
        for k, v in u["set"].items():
            put(props, k, fmt(v))
        write(base, up, head, props)
        n += 1
    for aid, a in SPEC["attachments"].items():
        head, props = split(load(a["from"]))
        put(props, "id", '&"%s"' % aid)
        put(props, "display_name", json.dumps(a["name"]))
        put(props, "mag_size", str(a["mag"]))
        put(props, "reserve_max", str(a["reserve"]))
        put(props, "attachment_of", '&"%s"' % a["of"])
        put(props, "camo", '&"vesperite"')
        for k, v in a["set"].items():
            put(props, k, fmt(v))
        owner_base = a["of"][:-3]
        write(owner_base, aid, head, props)
        n += 1
    print("wrote %d upgraded definitions" % n)


if __name__ == "__main__":
    main()
