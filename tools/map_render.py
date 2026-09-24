# Map renderer, executed inside gen_map.py (shares its globals: grid, W, H, TP,
# SEED, sites, paths, ROOT, Image, math, random).
#
# Aims for a soft, high-density pixel look: organic coastlines instead of tile
# edges, lit trees and hills with drop shadows, depth-graded water.
import numpy as np

PW, PH = W * TP, H * TP
R = np.random.default_rng(SEED)


def noise(cell, seed):
    rr = np.random.default_rng(seed)
    gw, gh = PW // cell + 3, PH // cell + 3
    small = Image.fromarray((rr.random((gh, gw)) * 255).astype(np.uint8), "L")
    big = small.resize((gw * cell, gh * cell), Image.BICUBIC)
    return np.asarray(big, dtype=np.float32)[:PH, :PW] / 255.0


def fbm(seed, cells=(48, 24, 12, 6), weights=(0.5, 0.25, 0.15, 0.1)):
    out = np.zeros((PH, PW), np.float32)
    for i, (c, w) in enumerate(zip(cells, weights)):
        out += noise(c, seed + i * 17) * w
    return out


# --- land field ---------------------------------------------------------------
tile_land = np.array([[0.0 if grid[y][x] == "~" else 1.0 for x in range(W)] for y in range(H)], np.float32)
lf = Image.fromarray((tile_land * 255).astype(np.uint8), "L").resize((PW, PH), Image.BILINEAR)
field = np.asarray(lf, np.float32) / 255.0
field += (fbm(SEED + 50, (16, 8, 4), (0.5, 0.3, 0.2)) - 0.5) * 0.55
land = field > 0.5
# Keep every site tile solidly land so colonies never sit in the surf.
for lst in sites.values():
    for st in lst:
        cx, cy = st["x"] * TP + TP // 2, st["y"] * TP + TP // 2
        land[cy - 4:cy + 5, cx - 4:cx + 5] = True


def distance_field(mask, maxd=24):
    """Approximate distance (px) from each False cell to the nearest True cell."""
    d = np.full(mask.shape, maxd, np.float32)
    d[mask] = 0
    frontier = mask.copy()
    for step in range(1, maxd):
        grown = frontier.copy()
        grown[1:, :] |= frontier[:-1, :]
        grown[:-1, :] |= frontier[1:, :]
        grown[:, 1:] |= frontier[:, :-1]
        grown[:, :-1] |= frontier[:, 1:]
        new = grown & ~frontier
        d[new] = step
        frontier = grown
    return d


d_to_land = distance_field(land, 40)
d_to_water = distance_field(~land, 12)

# --- biome per pixel, with jittered borders ------------------------------------
jx = (fbm(SEED + 60, (20, 10), (0.7, 0.3)) - 0.5) * TP * 1.6
jy = (fbm(SEED + 61, (20, 10), (0.7, 0.3)) - 0.5) * TP * 1.6
ys, xs = np.mgrid[0:PH, 0:PW]
tx = np.clip(((xs + jx) / TP).astype(int), 0, W - 1)
ty = np.clip(((ys + jy) / TP).astype(int), 0, H - 1)
gridarr = np.array([list(r) for r in grid])
biome = gridarr[ty, tx]
fallback = gridarr[np.clip(ys // TP, 0, H - 1), np.clip(xs // TP, 0, W - 1)]
biome = np.where(biome == "~", np.where(fallback == "~", "p", fallback), biome)

BASE = {
    "p": (122, 146, 70), "g": (98, 138, 64), "v": (170, 158, 86), "t": (138, 142, 104),
    "s": (86, 112, 72), "f": (84, 122, 56), "c": (92, 118, 70), "h": (132, 132, 74), "m": (120, 116, 96),
}
img = np.zeros((PH, PW, 3), np.float32)
tex = fbm(SEED + 70)
tex2 = noise(3, SEED + 71)
for key, col in BASE.items():
    m = biome == key
    img[m] = col
# Blend biome borders so no tile edges show.
from PIL import ImageFilter
_blur = Image.fromarray(img.astype(np.uint8), "RGB").filter(ImageFilter.GaussianBlur(4))
img = np.asarray(_blur, np.float32).copy()
# Soft painterly variation: broad light/dark patches plus fine grain.
img *= (0.86 + tex[..., None] * 0.28)
img *= (0.95 + tex2[..., None] * 0.1)
# Dry dirt patches on plains/savannah.
dirt = (fbm(SEED + 72, (14, 7), (0.6, 0.4)) > 0.62) & np.isin(biome, ["p", "v", "g"])
img[dirt] = img[dirt] * 0.55 + np.array([150, 120, 76]) * 0.45

# Beach: sand where land meets water, wet sand right at the edge.
sand = land & (d_to_water <= 3)
img[sand] = np.array([214, 192, 138]) * (0.92 + tex2[sand][..., None] * 0.1)
wet = land & (d_to_water <= 1)
img[wet] = np.array([176, 150, 104])

# --- water --------------------------------------------------------------------
water = ~land
_lb = Image.fromarray((land * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(14))
depth = 1.0 - np.clip(np.asarray(_lb, np.float32) / 255.0 * 2.2, 0, 1)
depth = np.where(d_to_land <= 3, np.minimum(depth, 0.05), depth)
shallow = np.array([78, 156, 170], np.float32)
mid = np.array([44, 104, 146], np.float32)
deep = np.array([26, 58, 102], np.float32)
t1 = np.clip(depth * 2.2, 0, 1)[..., None]
t2 = np.clip((depth - 0.45) * 1.8, 0, 1)[..., None]
wcol = shallow * (1 - t1) + mid * t1
wcol = wcol * (1 - t2) + deep * t2
wave = noise(6, SEED + 80)
wcol *= (0.94 + wave[..., None] * 0.12)
img[water] = wcol[water]
# Ripple highlights in open water.
rip = water & (noise(4, SEED + 81) > 0.82) & (d_to_land > 6) & ((ys + xs // 3) % 5 == 0)
img[rip] = img[rip] * 0.6 + np.array([140, 190, 210]) * 0.4
# Foam line along the shore.
foam = water & (d_to_land <= 1.5)
img[foam] = np.array([214, 232, 230])
foam2 = water & (d_to_land > 1.5) & (d_to_land <= 3) & (noise(3, SEED + 82) > 0.55)
img[foam2] = img[foam2] * 0.5 + np.array([200, 226, 228]) * 0.5

# --- rivers -------------------------------------------------------------------
RIVERS = [[(5.5, 13), (8, 16), (10, 19.5), (12.5, 21.5)],
          [(4, 27), (6, 31), (8.5, 35), (11, 38.5)],
          [(3, 44), (5, 48), (8, 50), (10, 51.5)]]
rr = random.Random(SEED + 11)
river_mask = np.zeros((PH, PW), bool)
for river in RIVERS:
    wob = 0.0
    for (ax, ay), (bx, by) in zip(river, river[1:]):
        steps = int(math.hypot(bx - ax, by - ay) * TP * 2)
        for i in range(steps):
            f = i / steps
            wob = max(-3.0, min(3.0, wob + rr.uniform(-0.4, 0.4)))
            X = int((ax + (bx - ax) * f) * TP + wob)
            Y = int((ay + (by - ay) * f) * TP)
            river_mask[max(Y - 1, 0):Y + 2, max(X - 1, 0):X + 2] = True
river_mask &= land
bank = np.zeros_like(river_mask)
bank[1:, :] |= river_mask[:-1, :]
bank[:, 1:] |= river_mask[:, :-1]
bank[:-1, :] |= river_mask[1:, :]
bank &= land & ~river_mask
img[bank] *= 0.78
img[river_mask] = np.array([70, 140, 164])

# --- lighting on land: low-frequency "sunlight" and edge shading ---------------
sun = fbm(SEED + 90, (60, 30), (0.7, 0.3))
img[land] *= (0.92 + sun[land][..., None] * 0.16)

canvas = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
cpx = canvas.load()

# --- objects: trees, hills, mountains, reeds -----------------------------------
clear = np.zeros((PH, PW), bool)
for lst in sites.values():
    for st in lst:
        cx, cy = st["x"] * TP + TP // 2, st["y"] * TP + TP // 2
        clear[max(cy - 14, 0):cy + 12, max(cx - 13, 0):cx + 14] = True


def blend(x, y, col, a=1.0):
    if 0 <= x < PW and 0 <= y < PH:
        r0, g0, b0, _ = cpx[x, y]
        cpx[x, y] = (int(r0 * (1 - a) + col[0] * a), int(g0 * (1 - a) + col[1] * a), int(b0 * (1 - a) + col[2] * a), 255)


def shadow(cx, cy, rx, ry, a=0.35):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d <= 1.0:
                blend(x, y, (20, 30, 20), a * (1.0 - d * 0.5))


def shade(base, lx, ly):
    """lx, ly in -1..1: position within the object; light comes from top-left."""
    k = 1.0 + (-lx - ly) * 0.22
    return tuple(max(0, min(255, int(c * k))) for c in base)


def blob(cx, cy, r, base, hi_boost=True):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            dx, dy = (x - cx) / r, (y - cy) / r
            if dx * dx + dy * dy <= 1.0:
                c = shade(base, dx, dy)
                if hi_boost and dx < -0.2 and dy < -0.3 and (x + y) % 2 == 0:
                    c = tuple(min(255, int(v * 1.12)) for v in c)
                blend(x, y, c)


def outline_dark(x0, y0, x1, y1, col):
    pass


def deciduous(x, y, s, tint):
    shadow(x + 2, y + 1, s * 0.95, s * 0.45)
    for ty_ in range(3):
        blend(x, y - ty_, (82, 58, 36))
    r = s * 0.75
    leaf = tuple(int(c * tint) for c in (64, 112, 48))
    blob(x - r * 0.45, y - r * 1.3, r * 0.75, leaf)
    blob(x + r * 0.45, y - r * 1.25, r * 0.7, tuple(int(c * 0.93) for c in leaf))
    blob(x, y - r * 1.85, r * 0.72, tuple(int(c * 1.06) for c in leaf))


def conifer(x, y, s, tint):
    shadow(x + 2, y + 1, s * 0.7, s * 0.35)
    blend(x, y, (78, 52, 32)); blend(x, y - 1, (78, 52, 32))
    base = tuple(int(c * tint) for c in (44, 88, 60))
    h = int(s * 2.2)
    for i in range(h):
        wdt = (i / h) * s * 0.75 + 0.5
        yy = y - 1 - (h - i)
        for dx in range(int(-wdt), int(wdt) + 1):
            lx = dx / max(wdt, 1)
            c = shade(base, lx, 0.0)
            if (i % 3 == 2) and abs(dx) > wdt * 0.5:
                c = tuple(int(v * 0.8) for v in c)
            blend(x + dx, yy, c)
    blend(x, y - 1 - h, tuple(min(255, int(v * 1.2)) for v in base))


def hill(x, y, s):
    shadow(x + 3, y + 1, s * 1.1, s * 0.3, 0.25)
    base = (136, 130, 76)
    for yy in range(int(-s * 0.7), 1):
        span = s * math.sqrt(max(0.0, 1 - (yy / (s * 0.7)) ** 2))
        for dx in range(int(-span), int(span) + 1):
            c = shade(base, dx / s * 1.3, yy / (s * 0.7) * 0.4)
            blend(x + dx, y + yy, c)


def mountain(x, y, s):
    shadow(x + 3, y + 1, s * 0.9, s * 0.3, 0.3)
    hgt = int(s * 1.3)
    peak_off = random.Random(x * 7 + y).randint(-2, 2)
    for i in range(hgt):
        wdt = (i / hgt) * s
        yy = y - hgt + i
        for dx in range(int(-wdt), int(wdt) + 1):
            left = dx < peak_off * (1 - i / hgt)
            base = (152, 144, 128) if left else (96, 90, 84)
            c = base
            if i < hgt * 0.28:
                c = (238, 240, 244) if left else (190, 196, 210)
            if (dx + i) % 5 == 0 and not left:
                c = tuple(int(v * 0.88) for v in c)
            blend(x + dx, yy, c)


def reeds(x, y):
    for dx in (-2, 0, 2):
        h = 3 + (x + dx) % 3
        for i in range(h):
            blend(x + dx, y - i, (70, 96, 56))
        blend(x + dx, y - h, (120, 90, 50))
    for dx in range(-3, 4):
        blend(x + dx, y + 1, (70, 120, 130), 0.6)


def bush(x, y):
    shadow(x + 1, y + 1, 3, 1.5, 0.25)
    blob(x, y - 1, 2.2, (74, 118, 52))


def flower(x, y):
    col = random.Random(x * 13 + y).choice([(236, 220, 120), (230, 150, 150), (240, 240, 230)])
    blend(x, y, col)


objs = []
pr = random.Random(SEED + 99)
step = 5
for gy in range(0, PH, step):
    for gx in range(0, PW, step):
        x = gx + pr.randint(0, step - 1)
        y = gy + pr.randint(0, step - 1)
        if not land[y, x] or clear[y, x] or river_mask[y, x] or d_to_water[y, x] <= 4:
            continue
        b = biome[y, x]
        roll = pr.random()
        if b == "f" and roll < 0.55:
            objs.append((y, "dec", x, pr.uniform(4.5, 6.5), pr.uniform(0.85, 1.12)))
        elif b == "c" and roll < 0.6:
            objs.append((y, "con", x, pr.uniform(3.5, 5.0), pr.uniform(0.85, 1.12)))
        elif b == "t" and roll < 0.12:
            objs.append((y, "con", x, pr.uniform(3.0, 4.0), 1.0))
        elif b in "pg" and roll < 0.04:
            objs.append((y, "dec", x, pr.uniform(4.0, 5.5), pr.uniform(0.9, 1.1)))
        elif b in "pg" and roll < 0.08:
            objs.append((y, "bush", x, 0, 0))
        elif b in "pgv" and roll < 0.12:
            objs.append((y, "flower", x, 0, 0))
        elif b == "v" and roll < 0.05:
            objs.append((y, "bush", x, 0, 0))
        elif b == "s" and roll < 0.3:
            objs.append((y, "reeds", x, 0, 0))
        elif b == "s" and roll < 0.36:
            objs.append((y, "dec", x, pr.uniform(3.5, 4.5), 0.8))
for ty_ in range(H):
    for tx_ in range(W):
        t = grid[ty_][tx_]
        cx, cy = tx_ * TP + TP // 2, ty_ * TP + TP // 2
        if clear[cy, cx]:
            continue
        if t == "m":
            for _ in range(pr.choice((1, 2, 2))):
                objs.append((cy + pr.randint(0, 6), "mtn", cx + pr.randint(-4, 4), pr.uniform(5.5, 10), 0))
        elif t == "h":
            for _ in range(pr.choice((1, 1, 2))):
                objs.append((cy + pr.randint(-2, 5), "hill", cx + pr.randint(-4, 4), pr.uniform(4.5, 7.5), 0))

objs.sort()
for y, kind, x, s, tint in objs:
    if kind == "dec":
        deciduous(x, y, s, tint)
    elif kind == "con":
        conifer(x, y, s, tint)
    elif kind == "mtn":
        mountain(x, y, s)
    elif kind == "hill":
        hill(x, y, s)
    elif kind == "reeds":
        reeds(x, y)
    elif kind == "bush":
        bush(x, y)
    elif kind == "flower":
        flower(x, y)

os.makedirs(os.path.join(ROOT, "assets", "sprites"), exist_ok=True)
canvas.convert("RGB").save(os.path.join(ROOT, "assets", "sprites", "map.png"))
Image.fromarray((water * 255).astype(np.uint8), "L").save(os.path.join(ROOT, "assets", "sprites", "map_water.png"))
