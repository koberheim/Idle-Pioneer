"""Builds the map decoration atlas: trees, palms, hills, mountains, reeds...

Outputs assets/sprites/decor.png and data/decor.json ({name: [x, y, w, h]}).
Sprites are drawn at one art pixel = 1/16 of a map tile, lit from the upper
left, with colour-tinted outlines. Re-run after editing: python tools/gen_decor.py
"""
import json
import math
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = random.Random(1776)


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


def outline(img, tint=0.35):
    """Adds a 1px outline around opaque pixels, tinted from the neighbour."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and src[xx, yy][3]:
                    dst[x, y] = shade(src[xx, yy], tint)
                    break
    return out


def blob(img, cx, cy, r, base, rng):
    px = img.load()
    w, h = img.size
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if not (0 <= x < w and 0 <= y < h):
                continue
            dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
            d = dx * dx + dy * dy
            if d <= 1.0 + rng.uniform(-0.12, 0.05):
                k = 1.0 + (-dx - dy) * 0.28
                if dx < -0.25 and dy < -0.25 and rng.random() < 0.5:
                    k += 0.12
                if rng.random() < 0.12:
                    k -= 0.1
                px[x, y] = shade(base, k)


def deciduous(seed, tone):
    rng = random.Random(seed)
    img = canvas(13, 15)
    px = img.load()
    trunk = (96, 66, 40)
    for y in range(10, 14):
        px[6, y] = trunk + (255,)
        if y > 11:
            px[7, y] = shade(trunk, 0.8)
    leaf = tuple(int(c * tone) for c in (70, 118, 52))
    blob(img, 4.2, 7.0, 3.2, leaf, rng)
    blob(img, 8.6, 7.2, 3.1, shade(leaf, 0.92), rng)
    blob(img, 6.4, 4.2, 3.6, shade(leaf, 1.06), rng)
    return outline(img)


def conifer(seed, tone, snow=False):
    rng = random.Random(seed)
    img = canvas(10, 16)
    px = img.load()
    base = tuple(int(c * tone) for c in (42, 88, 60))
    px[4, 14] = (86, 58, 36, 255)
    px[5, 14] = (70, 46, 28, 255)
    for i in range(13):
        wd = (i % 4) * 0.6 + i * 0.18 + 0.5
        y = 1 + i
        for x in range(int(4.5 - wd), int(4.5 + wd) + 1):
            if 0 <= x < 10:
                k = 1.18 if x < 4.5 else 0.82
                if i % 4 == 3:
                    k *= 0.85
                c = shade(base, k + rng.uniform(-0.05, 0.05))
                if snow and i % 4 == 0 and rng.random() < 0.7:
                    c = (226, 232, 236, 255)
                px[x, y] = c
    return outline(img)


def palm(seed):
    rng = random.Random(seed)
    img = canvas(13, 15)
    px = img.load()
    trunk = (140, 104, 62)
    for i in range(8):
        x = 6 + int(math.sin(i * 0.3) * 1.2)
        px[x, 14 - i] = shade(trunk, 1.1 if i % 2 else 0.85)
    leaf = (62, 128, 58)
    cx, cy = 6.5, 6
    for a in range(8):
        ang = a / 8 * math.tau + rng.uniform(-0.2, 0.2)
        for t in range(1, 6):
            x = int(cx + math.cos(ang) * t)
            y = int(cy + math.sin(ang) * t * 0.6 + (t * t) * 0.12)
            if 0 <= x < 13 and 0 <= y < 15:
                px[x, y] = shade(leaf, 1.15 if math.cos(ang) < 0 else 0.85)
    px[6, 6] = (120, 86, 40, 255)
    return outline(img)


def acacia(seed):
    rng = random.Random(seed)
    img = canvas(15, 10)
    px = img.load()
    for y in range(5, 10):
        px[7, y] = (96, 70, 42, 255)
    px[6, 5] = px[8, 5] = (96, 70, 42, 255)
    leaf = (104, 124, 56)
    for x in range(1, 14):
        for y in range(2, 5):
            if abs(x - 7) + (y - 2) * 2 < 8 and rng.random() < 0.95:
                px[x, y] = shade(leaf, 1.15 if y == 2 else (0.85 if y == 4 else 1.0))
    return outline(img)


def bush(seed):
    rng = random.Random(seed)
    img = canvas(8, 6)
    blob(img, 4, 3.3, 2.6, (72, 112, 52), rng)
    return outline(img)


def reeds(seed):
    rng = random.Random(seed)
    img = canvas(9, 8)
    px = img.load()
    for x in (1, 3, 5, 7):
        h = rng.randint(4, 7)
        for i in range(h):
            px[x, 7 - i] = (78, 108, 60, 255) if i < h - 1 else (138, 100, 56, 255)
    for x in range(0, 9):
        if rng.random() < 0.6:
            px[x, 7] = (90, 140, 150, 255)
    return img


def rock(seed):
    rng = random.Random(seed)
    img = canvas(7, 5)
    blob(img, 3.5, 3, 2.4, (132, 126, 116), rng)
    return outline(img, 0.45)


def hill(seed, base=(142, 134, 84)):
    rng = random.Random(seed)
    w, h = 24, 12
    img = canvas(w, h)
    px = img.load()
    peak = rng.uniform(9, 14)
    for x in range(w):
        top = h - 1 - (h - 2) * math.exp(-((x - peak) / 6.5) ** 2)
        for y in range(int(top), h):
            k = 1.18 if x < peak else 0.82
            k *= 1.0 - (y - top) * 0.015
            if rng.random() < 0.1:
                k *= 0.93
            px[x, y] = shade(base, k)
    # a few tufts
    for i in range(4):
        x = rng.randint(3, w - 4)
        y = rng.randint(h - 4, h - 2)
        if px[x, y][3]:
            px[x, y] = (96, 118, 58, 255)
    return outline(img, 0.45)


def mountain(seed, big=True):
    rng = random.Random(seed)
    w, h = (26, 20) if big else (18, 14)
    img = canvas(w, h)
    px = img.load()
    peak_x = w / 2 + rng.uniform(-2, 2)
    rock_l, rock_d = (170, 162, 146), (104, 98, 92)
    for y in range(h):
        half = (y + 1) / h * (w / 2)
        for x in range(w):
            if abs(x + 0.5 - peak_x) <= half + rng.uniform(-0.6, 0.3):
                left = x + 0.5 < peak_x - (y % 5) * 0.2
                c = rock_l if left else rock_d
                if y < h * 0.3:
                    c = (240, 242, 244) if left else (190, 198, 212)
                elif y < h * 0.38 and rng.random() < 0.5:
                    c = (220, 224, 228) if left else (170, 176, 188)
                if rng.random() < 0.12:
                    c = shade(c, 0.9)
                px[x, y] = c + (255,) if len(c) == 3 else c
    return outline(img, 0.42)


sprites = {}
for i in range(4):
    sprites["tree%d" % i] = deciduous(i, 0.9 + i * 0.07)
for i in range(4):
    sprites["pine%d" % i] = conifer(10 + i, 0.9 + i * 0.07)
for i in range(2):
    sprites["snowpine%d" % i] = conifer(20 + i, 0.95, snow=True)
for i in range(3):
    sprites["palm%d" % i] = palm(30 + i)
for i in range(2):
    sprites["acacia%d" % i] = acacia(40 + i)
for i in range(3):
    sprites["bush%d" % i] = bush(50 + i)
for i in range(2):
    sprites["reeds%d" % i] = reeds(60 + i)
for i in range(2):
    sprites["rock%d" % i] = rock(70 + i)
for i in range(3):
    sprites["hill%d" % i] = hill(80 + i)
for i in range(3):
    sprites["mtn%d" % i] = mountain(90 + i, True)
for i in range(2):
    sprites["peak%d" % i] = mountain(95 + i, False)

def serpent(seed):
    """A sea serpent in three humps, head raised: an engraver's flourish."""
    rng = random.Random(seed)
    img = canvas(30, 14)
    px = img.load()
    body = (86, 112, 104)
    for hump, (cx, r) in enumerate(((7, 3.4), (14, 3.8), (21, 3.2))):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            for y in range(4, 13):
                dx = (x + 0.5 - cx) / r
                top = 11 - (1 - dx * dx) * r * 1.6 if abs(dx) < 1 else 99
                if y >= top and y <= 11 and abs(dx) < 1:
                    k = 1.2 if dx < 0 else 0.8
                    if y > top + 1.5 and (x + y) % 2 == 0:
                        k *= 0.8
                    px[x, y] = shade(body, k)
    # neck and head
    for i in range(7):
        x, y = 25 + i * 0.5, 10 - i * 1.1
        for dx in range(-1, 2):
            xx = int(x + dx)
            if 0 <= xx < 30 and 0 <= int(y) < 14:
                px[xx, int(y)] = shade(body, 1.1 if dx < 0 else 0.85)
    for x in range(26, 30):
        px[x, 3] = shade(body, 1.1)
        px[x, 4] = shade(body, 0.9)
    px[28, 3] = (240, 230, 200, 255)
    # waterline ripples
    for x in range(1, 29):
        if x % 3 and rng.random() < 0.8:
            px[x, 12] = (190, 214, 206, 255)
    return outline(img, 0.3)


def whale(seed):
    img = canvas(26, 14)
    px = img.load()
    body = (72, 84, 92)
    for x in range(3, 24):
        t = (x - 3) / 21
        top = 8 - math.sin(t * math.pi) * 4.5
        for y in range(int(top), 12):
            k = 1.2 if y < top + 1.5 else (0.85 if (x + y) % 2 == 0 and y > 9 else 1.0)
            px[x, y] = shade(body, k)
    # tail flukes
    for y in range(3, 8):
        px[2, y] = shade(body, 1.0)
        px[1, y - 1] = shade(body, 1.1)
    px[19, 7] = (230, 226, 210, 255)
    # spout
    for i, (x, y) in enumerate(((17, 1), (18, 0), (16, 0), (17, 2), (17, 3), (19, 1), (15, 1))):
        px[x, y] = (214, 232, 236, 255)
    for x in range(0, 26):
        if x % 3:
            px[x, 12] = (190, 214, 206, 255)
    return outline(img, 0.3)


def ink(img, seed):
    """The engraved-chart variant of a sprite: sepia tones, ink outline, and
    hatched shadows, like the woodcut trees of an old map."""
    rng = random.Random(seed)
    w, h = img.size
    src = img.load()
    out = canvas(w, h)
    dst = out.load()
    ink_c = (58, 38, 24)
    paper = (232, 208, 160)
    lums = sorted(0.3 * p[0] + 0.55 * p[1] + 0.15 * p[2] for p in img.getdata() if p[3])
    mid = lums[len(lums) // 2] if lums else 100
    for y in range(h):
        for x in range(w):
            p = src[x, y]
            if not p[3]:
                continue
            lum = 0.3 * p[0] + 0.55 * p[1] + 0.15 * p[2]
            t = max(0.0, min(1.0, (lum - 30) / 170.0))
            base = tuple(int(ink_c[i] + (paper[i] - ink_c[i]) * t) for i in range(3))
            # keep a hint of the original hue
            c = tuple(int(base[i] * 0.8 + p[i] * 0.2) for i in range(3))
            if lum < mid * 0.92 and (x - y) % 2 == 0:
                c = tuple(int(v * 0.62) for v in c)
            dst[x, y] = c + (255,)
    return out


sprites["serpent0"] = serpent(100)
sprites["whale0"] = whale(101)

# Pack into rows. The engraved variant uses the same regions.
atlas_w = 256
x = y = row_h = 0
regions = {}
placed = []
for name, img in sprites.items():
    w, h = img.size
    if x + w + 1 > atlas_w:
        x = 0
        y += row_h + 1
        row_h = 0
    regions[name] = [x, y, w, h]
    placed.append((name, img, x, y))
    x += w + 1
    row_h = max(row_h, h)
atlas = canvas(atlas_w, y + row_h + 1)
inked = canvas(atlas_w, y + row_h + 1)
for i, (name, img, ax, ay) in enumerate(placed):
    atlas.alpha_composite(img, (ax, ay))
    inked.alpha_composite(img if name in ("serpent0", "whale0") else ink(img, i), (ax, ay))
atlas.save(os.path.join(ROOT, "assets", "sprites", "decor.png"))
inked.save(os.path.join(ROOT, "assets", "sprites", "decor_ink.png"))
with open(os.path.join(ROOT, "data", "decor.json"), "w") as f:
    json.dump(regions, f, indent=1)
print("decor atlas", atlas.size, len(regions), "sprites")
