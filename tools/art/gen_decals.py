#!/usr/bin/env python3
# Generates Vesper Peak's decal textures (Step 13): original, procedurally drawn with numpy + PIL —
# no third-party images. Output: game/content/decals/<name>.png (RGBA, alpha = coverage).
# Deterministic (fixed seeds). Run: python3 tools/art/gen_decals.py
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "game", "content", "decals")
S = 256


def fbm(seed, size=S, octaves=5, base=4):
    rng = np.random.default_rng(seed)
    acc = np.zeros((size, size), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = base * 2 ** o
        g = rng.random((n + 1, n + 1)).astype(np.float32)
        g[-1, :] = g[0, :]
        g[:, -1] = g[:, 0]
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        acc += np.asarray(img, np.float32) / 255.0 * amp
        tot += amp
        amp *= 0.5
    return acc / tot


def radial(size=S, power=1.6):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.sqrt((x - size / 2) ** 2 + (y - size / 2) ** 2) / (size / 2)
    return np.clip(1.0 - d, 0, 1) ** power


def save(name, rgb, alpha):
    a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    arr = np.zeros((S, S, 4), np.uint8)
    for i in range(3):
        arr[..., i] = np.clip(rgb[i], 0, 255)
    arr[..., 3] = a
    Image.fromarray(arr, "RGBA").save(os.path.join(OUT, name + ".png"), optimize=True)


def grime():
    n = fbm(11)
    a = np.clip((n - 0.42) * 2.6, 0, 1) * radial(power=0.8)
    save("grime", (np.full((S, S), 38.0), np.full((S, S), 33.0), np.full((S, S), 26.0)), a * 0.85)


def water_stain():
    n = fbm(23, base=3)
    ring = np.abs(radial(power=1.0) - 0.35)
    a = np.clip(0.25 - ring, 0, 1) * 3.0 * np.clip(n * 1.5, 0, 1) + np.clip(n - 0.55, 0, 1) * radial()
    save("water_stain", (np.full((S, S), 70.0), np.full((S, S), 58.0), np.full((S, S), 40.0)), a)


def blood():
    rng = np.random.default_rng(5)
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    d.ellipse((80, 80, 176, 176), fill=255)
    for _ in range(40):
        ang = rng.random() * math.tau
        r = 40 + rng.random() * 80
        x, y = 128 + math.cos(ang) * r, 128 + math.sin(ang) * r
        s = 2 + rng.random() * 9
        d.ellipse((x - s, y - s, x + s, y + s), fill=255)
        d.line((128, 128, x, y), fill=255, width=int(1 + rng.random() * 4))
    img = img.filter(ImageFilter.GaussianBlur(1.5))
    a = np.asarray(img, np.float32) / 255.0 * (0.75 + 0.25 * fbm(6))
    save("blood", (np.full((S, S), 72.0), np.full((S, S), 8.0), np.full((S, S), 6.0)), a)


def frost():
    n = fbm(31, base=6)
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    # crystalline streaks from the edges inward
    streak = np.abs(np.sin((x * 0.7 + y * 0.3) * 0.15 + n * 9.0))
    edge = 1.0 - radial(power=0.6)
    a = np.clip(edge * 1.3 + (streak - 0.7) * 0.6, 0, 1) * np.clip(n * 1.6 - 0.2, 0, 1)
    save("frost", (np.full((S, S), 215.0), np.full((S, S), 232.0), np.full((S, S), 245.0)), a * 0.9)


def scorch():
    n = fbm(41)
    a = np.clip(radial(power=0.9) * 1.4 * (0.6 + n * 0.6) - 0.1, 0, 1)
    save("scorch", (np.full((S, S), 14.0), np.full((S, S), 12.0), np.full((S, S), 11.0)), a)


def claws():
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    for set_x in (40, 150):
        for i in range(4):
            x0 = set_x + i * 16
            d.line((x0, 30, x0 + 18, 226), fill=255, width=6 - i % 2)
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    a = np.asarray(img, np.float32) / 255.0 * (0.7 + 0.3 * fbm(8))
    save("claws", (np.full((S, S), 30.0), np.full((S, S), 22.0), np.full((S, S), 20.0)), a)


def handprints():
    rng = np.random.default_rng(9)
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    for k in range(3):
        cx, cy = 60 + k * 70 + rng.integers(-10, 10), 110 + rng.integers(-40, 40)
        d.ellipse((cx - 18, cy - 10, cx + 18, cy + 28), fill=255)
        for f in range(5):
            ang = math.radians(-150 + f * 30 + (25 if f == 0 else 0))
            fx, fy = cx + math.cos(ang) * 34, cy + math.sin(ang) * 34
            d.line((cx + math.cos(ang) * 12, cy + math.sin(ang) * 12, fx, fy), fill=255, width=9)
        d.line((cx - 5, cy + 26, cx - 12, cy + 90), fill=200, width=5)  # smear
    img = img.filter(ImageFilter.GaussianBlur(1.6))
    a = np.asarray(img, np.float32) / 255.0 * 0.8
    save("handprints", (np.full((S, S), 90.0), np.full((S, S), 20.0), np.full((S, S), 18.0)), a)


def tally():
    rng = np.random.default_rng(13)
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    for row in range(6):
        for grp in range(5):
            x0, y0 = 14 + grp * 48, 18 + row * 40
            for i in range(4):
                xx = x0 + i * 8 + rng.integers(-1, 2)
                d.line((xx, y0, xx + rng.integers(-2, 3), y0 + 28), fill=255, width=3)
            d.line((x0 - 4, y0 + 22, x0 + 32, y0 + 6), fill=255, width=3)
    a = np.asarray(img.filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255.0 * 0.9
    save("tally", (np.full((S, S), 225.0), np.full((S, S), 222.0), np.full((S, S), 210.0)), a)


def notation():
    rng = np.random.default_rng(17)
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    for staff in range(4):
        y0 = 24 + staff * 58
        for l in range(5):
            d.line((8, y0 + l * 7, 248, y0 + l * 7 + rng.integers(-2, 3)), fill=170, width=1)
        # the Choir motif: the same six notes on every staff
        for i, step in enumerate([2, 4, 3, 6, 5, 1]):
            x = 30 + i * 36
            y = y0 + 28 - step * 3.5
            d.ellipse((x - 5, y - 4, x + 5, y + 4), fill=255)
            d.line((x + 5, y, x + 5, y - 22), fill=255, width=2)
    a = np.asarray(img.filter(ImageFilter.GaussianBlur(0.7)), np.float32) / 255.0 * 0.85
    save("notation", (np.full((S, S), 20.0), np.full((S, S), 18.0), np.full((S, S), 18.0)), a)


def cross_scratch():
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    d.line((128, 30, 126, 226), fill=255, width=7)
    d.line((60, 90, 196, 94), fill=255, width=7)
    img = img.filter(ImageFilter.GaussianBlur(1.0))
    a = np.asarray(img, np.float32) / 255.0 * (0.6 + 0.4 * fbm(3))
    save("cross_scratch", (np.full((S, S), 200.0), np.full((S, S), 196.0), np.full((S, S), 188.0)), a)


def hazard_stripes():
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    s = ((x + y) // 32) % 2
    wear = np.clip(fbm(51) * 1.6 - 0.15, 0, 1)
    r = np.where(s > 0, 225.0, 20.0)
    g = np.where(s > 0, 180.0, 18.0)
    b = np.where(s > 0, 30.0, 16.0)
    save("hazard_stripes", (r, g, b), wear)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in (grime, water_stain, blood, frost, scorch, claws, handprints, tally, notation, cross_scratch,
              hazard_stripes):
        f()
    print("decals ->", os.path.abspath(OUT))
