"""Builds the New World map: a fixed pixel-art coastline in the style of the
1994 Colonization overland map.

Outputs
  assets/sprites/map.png        terrain, 8 px per tile (displayed at 3x)
  assets/sprites/map_water.png  white where water is, for the wave shader
  data/map.json                 grid, colony sites and precomputed route paths

The layout is generated from a fixed seed so it is identical on every build;
it is not generated at runtime. Re-run after editing: python tools/gen_map.py
"""
import heapq
import json
import math
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H, T = 30, 60, 8
SEED = 1492

rng = random.Random(SEED)


def smooth_noise(seed, scale):
    r = random.Random(seed)
    pts = {}

    def val(ix, iy):
        key = (ix, iy)
        if key not in pts:
            pts[key] = r.random()
        return pts[key]

    def f(x, y):
        x /= scale
        y /= scale
        x0, y0 = math.floor(x), math.floor(y)
        tx, ty = x - x0, y - y0
        tx = tx * tx * (3 - 2 * tx)
        ty = ty * ty * (3 - 2 * ty)
        a = val(x0, y0) * (1 - tx) + val(x0 + 1, y0) * tx
        b = val(x0, y0 + 1) * (1 - tx) + val(x0 + 1, y0 + 1) * tx
        return a * (1 - ty) + b * ty

    return f


n1 = smooth_noise(SEED, 5.0)
n2 = smooth_noise(SEED + 1, 2.5)
n3 = smooth_noise(SEED + 2, 4.0)
n4 = smooth_noise(SEED + 3, 3.0)

# ---------------------------------------------------------------- land shape
land = [[False] * W for _ in range(H)]
nc = smooth_noise(SEED + 7, 3.0)
# (row, amount, spread): positive pushes the coast east (a cape), negative
# carves a bay.
FEATURES = [(3, 2.5, 2.0), (9, -2.5, 1.6), (15, 3.5, 2.2), (22, -7.5, 2.2), (28, 2.0, 1.8),
            (35, 3.0, 2.0), (40, -4.0, 1.4), (44, 1.5, 1.5)]
coast = []
for y in range(H):
    c = 16.0 + 1.8 * math.sin(y / 7.0) + (nc(0, y) - 0.5) * 5.0
    for fy, amt, spread in FEATURES:
        c += amt * math.exp(-((y - fy) / spread) ** 2)
    if y > 46:
        c -= (y - 46) * 0.6
    coast.append(c)
for y in range(H):
    for x in range(W):
        edge = coast[y] + (n2(x, y) - 0.5) * 3.0
        land[y][x] = x < edge

islands = [(23, 53, 3.4), (27, 46, 1.4), (19, 60, 1.9), (25, 30, 1.2)]
for cx, cy, r in islands:
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - cx) * 1.0, (y - cy) * 1.2) + (n2(x, y) - 0.5) * 1.6
            if d < r:
                land[y][x] = True

# Keep an open ocean strip on the east so ships always have a lane to Europe.
for y in range(H):
    for x in range(W - 3, W):
        land[y][x] = False

# Remove single-tile specks and pinholes.
for _ in range(2):
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            nb = sum(land[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if land[y][x] and nb == 0:
                land[y][x] = False
            if not land[y][x] and nb == 4:
                land[y][x] = True

# ---------------------------------------------------------------- terrain
# t: tundra, c: conifer, f: forest, p: plains, g: grassland, h: hills,
# m: mountains, s: marsh, v: savannah, ~: ocean
grid = [["~"] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        if not land[y][x]:
            continue
        lat = y / H
        rough = n3(x, y)
        wet = n4(x, y)
        ridge = abs(x - (4.5 + 1.5 * math.sin(y / 6.0)))
        if ridge < 1.3 and 6 < y < 42 and rough > 0.35:
            t = "m"
        elif ridge < 2.6 and rough > 0.45 and y < 46:
            t = "h"
        elif lat < 0.12:
            t = "t" if rough < 0.5 else "c"
        elif lat < 0.3:
            t = "c" if rough > 0.45 else ("f" if wet > 0.5 else "p")
        elif lat < 0.62:
            t = "f" if rough > 0.55 else ("g" if wet > 0.45 else "p")
        else:
            t = "s" if wet > 0.6 else ("v" if rough < 0.5 else "g")
        grid[y][x] = t


def is_land(x, y):
    return 0 <= x < W and 0 <= y < H and grid[y][x] != "~"


def coastal(x, y):
    return is_land(x, y) and any(
        0 <= x + dx < W and 0 <= y + dy < H and grid[y + dy][x + dx] == "~"
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


# ---------------------------------------------------------------- sites
def nearest(pred, tx, ty):
    best, bd = None, 1e9
    for y in range(H):
        for x in range(W):
            if pred(x, y) and 2 <= y < H - 2:
                d = math.hypot(x - tx, (y - ty) * 1.0)
                if d < bd:
                    best, bd = (x, y), d
    return best


def inland(x, y):
    return is_land(x, y) and not coastal(x, y) and grid[y][x] not in "m"


def sea_ok(x, y):
    # Coastal land with water to the east, so the harbour faces the ocean.
    return coastal(x, y) and grid[y][x] != "m"


capital = nearest(lambda x, y: sea_ok(x, y) and grid[y][x] not in "hm", 16, 13)
grid[capital[1]][capital[0]] = "p"

targets = {
    "capital": [],
    "fishery": [(15, 19, "sea"), (12, 17, "land")],
    "plantation": [(14, 28, "sea"), (8, 25, "land")],
    "cotton_fields": [(16, 34, "sea"), (9, 32, "land")],
    "ironworks": [(12, 39, "sea"), (5, 37, "land")],
    "indigo_reach": [(12, 46, "sea"), (6, 45, "land")],
    "sugar_isle": [(22, 52, "sea"), (25, 55, "sea")],
    "fur_post": [(14, 3, "sea"), (6, 5, "land")],
}
taken = {capital}
sites = {"capital": [{"x": capital[0], "y": capital[1], "route": "sea"}]}
for cid, cands in targets.items():
    if cid == "capital":
        continue
    out = []
    for tx, ty, route in cands:
        pred = sea_ok if route == "sea" else inland
        spot = nearest(lambda x, y: pred(x, y) and all(math.hypot(x - a, y - b) >= 2.5 for a, b in taken), tx, ty)
        taken.add(spot)
        if grid[spot[1]][spot[0]] in "hm" and cid != "ironworks":
            grid[spot[1]][spot[0]] = "p"
        out.append({"x": spot[0], "y": spot[1], "route": route})
    sites[cid] = out


# ---------------------------------------------------------------- paths
def astar(start, goal, passable, cost):
    openq = [(0, start)]
    came = {start: None}
    g = {start: 0}
    while openq:
        _, cur = heapq.heappop(openq)
        if cur == goal:
            break
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            nx, ny = cur[0] + dx, cur[1] + dy
            if not (0 <= nx < W and 0 <= ny < H) or not passable(nx, ny, goal):
                continue
            if dx and dy and not (passable(cur[0] + dx, cur[1], goal) and passable(cur[0], cur[1] + dy, goal)):
                continue
            ng = g[cur] + cost(nx, ny) * (1.414 if dx and dy else 1.0)
            if ng < g.get((nx, ny), 1e9):
                g[(nx, ny)] = ng
                came[(nx, ny)] = cur
                heapq.heappush(openq, (ng + math.hypot(goal[0] - nx, goal[1] - ny), (nx, ny)))
    if goal not in came:
        raise SystemExit("no path %s -> %s" % (start, goal))
    path, cur = [], goal
    while cur:
        path.append(cur)
        cur = came[cur]
    return path[::-1]


LAND_COST = {"p": 1, "g": 1, "v": 1.2, "t": 1.5, "c": 1.5, "f": 1.5, "s": 2.5, "h": 2.5, "m": 6}


def land_pass(x, y, goal):
    return is_land(x, y)


def sea_pass(x, y, goal):
    return grid[y][x] == "~" or (x, y) == goal


def water_neighbor(x, y, prefer_east=True):
    opts = [(x + dx, y + dy) for dx, dy in ((1, 0), (0, 1), (0, -1), (-1, 0), (1, 1), (1, -1))
            if 0 <= x + dx < W and 0 <= y + dy < H and grid[y + dy][x + dx] == "~"]
    return opts[0]


def simplify(path):
    if len(path) < 3:
        return path
    out = [path[0]]
    for i in range(1, len(path) - 1):
        a, b, c = out[-1], path[i], path[i + 1]
        if (b[0] - a[0]) * (c[1] - b[1]) != (b[1] - a[1]) * (c[0] - b[0]):
            out.append(b)
    out.append(path[-1])
    return out


cap_port = water_neighbor(*capital)
paths = {}
for cid, lst in sites.items():
    if cid == "capital":
        continue
    plist = []
    for s in lst:
        start = (s["x"], s["y"])
        if s["route"] == "land":
            p = astar(start, capital, land_pass, lambda x, y: LAND_COST.get(grid[y][x], 1))
        else:
            port = water_neighbor(*start)
            p = [start] + astar(port, cap_port, lambda x, y, goal: grid[y][x] == "~", lambda x, y: 1) + [capital]
        plist.append([[x, y] for x, y in simplify(p)])
    paths[cid] = plist

europe_lane = [list(capital), list(cap_port), [W - 1, cap_port[1]], [W + 2, cap_port[1]]]

# ---------------------------------------------------------------- render
PAL = {
    "deep": (22, 52, 110), "deep2": (26, 60, 122), "mid": (33, 75, 142), "shallow": (52, 104, 168),
    "foam": (170, 205, 230), "sand": (214, 190, 130), "sand2": (190, 164, 104),
    "p": [(118, 150, 62), (110, 142, 56), (126, 158, 70)],
    "g": [(92, 146, 60), (84, 136, 54), (100, 154, 66)],
    "v": [(170, 160, 78), (158, 150, 70), (178, 168, 86)],
    "t": [(152, 150, 118), (142, 140, 110), (162, 160, 128)],
    "s": [(88, 116, 70), (78, 104, 64), (70, 100, 84)],
    "f": [(92, 146, 60), (84, 136, 54)],
    "c": [(118, 150, 62), (110, 142, 56)],
    "h": [(142, 140, 72), (132, 128, 66)],
    "m": [(128, 120, 100), (118, 110, 92)],
    "leaf": (40, 98, 40), "leaf2": (58, 122, 48), "leafhi": (92, 150, 62), "trunk": (84, 58, 34),
    "pine": (26, 78, 52), "pine2": (40, 98, 62),
    "hill": (112, 108, 58), "hillhi": (170, 164, 92), "hillsh": (86, 82, 46),
    "rock": (104, 96, 84), "rockhi": (170, 162, 150), "rocksh": (70, 64, 58), "snow": (236, 240, 244),
    "reed": (60, 92, 58), "water_s": (70, 110, 120),
}

img = Image.new("RGB", (W * T, H * T))
mask = Image.new("L", (W * T, H * T), 0)
px = img.load()
mk = mask.load()
prng = random.Random(SEED + 9)


def land_at_px(X, Y):
    return is_land(X // T, Y // T)


# distance (in pixels) to nearest land / water for shoreline shading
dist_land = {}
for Y in range(H * T):
    for X in range(W * T):
        if land_at_px(X, Y):
            continue
        best = 99
        for dy in range(-12, 13, 2):
            for dx in range(-12, 13, 2):
                if land_at_px(X + dx, Y + dy) if 0 <= X + dx < W * T and 0 <= Y + dy < H * T else False:
                    best = min(best, math.hypot(dx, dy))
        dist_land[(X, Y)] = best

for Y in range(H * T):
    for X in range(W * T):
        tx, ty = X // T, Y // T
        t = grid[ty][tx]
        if t == "~":
            d = dist_land[(X, Y)]
            if d <= 2.1:
                c = PAL["foam"] if (X + Y) % 3 else PAL["shallow"]
            elif d <= 6:
                c = PAL["shallow"]
            elif d <= 12:
                c = PAL["mid"]
            else:
                c = PAL["deep"] if ((X // 4 + Y // 3) % 7) else PAL["deep2"]
            px[X, Y] = c
            mk[X, Y] = 255
        else:
            # beach where a land pixel touches water within 1-2 px
            near_water = False
            for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                xx, yy = X + dx, Y + dy
                if 0 <= xx < W * T and 0 <= yy < H * T and not land_at_px(xx, yy):
                    near_water = True
                    break
            if near_water and t not in "m":
                px[X, Y] = PAL["sand"] if prng.random() > 0.15 else PAL["sand2"]
            else:
                base = PAL[t]
                px[X, Y] = base[prng.randrange(len(base))] if prng.random() < 0.35 else base[0]


def put(X, Y, c):
    if 0 <= X < W * T and 0 <= Y < H * T and land_at_px(X, Y):
        px[X, Y] = c


def deciduous(X, Y):
    for dx, dy in ((0, -3), (-1, -2), (0, -2), (1, -2), (-2, -1), (-1, -1), (0, -1), (1, -1), (2, -1), (-1, 0), (0, 0), (1, 0)):
        put(X + dx, Y + dy, PAL["leaf"])
    put(X - 1, Y - 2, PAL["leafhi"]); put(X, Y - 3, PAL["leafhi"]); put(X - 1, Y - 1, PAL["leaf2"])
    put(X, Y + 1, PAL["trunk"])


def pine(X, Y):
    for dx, dy in ((0, -4), (0, -3), (-1, -2), (0, -2), (1, -2), (-1, -1), (0, -1), (1, -1), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0)):
        put(X + dx, Y + dy, PAL["pine"])
    put(X, Y - 3, PAL["pine2"]); put(X - 1, Y - 1, PAL["pine2"])
    put(X, Y + 1, PAL["trunk"])


def hill(X, Y):
    rows = [(-1, 1), (-3, 3), (-4, 4)]
    for i, (a, b) in enumerate(rows):
        for dx in range(a, b + 1):
            put(X + dx, Y - 2 + i, PAL["hill"])
    put(X - 1, Y - 2, PAL["hillhi"]); put(X - 2, Y - 1, PAL["hillhi"]); put(X - 3, Y, PAL["hillhi"])
    put(X + 3, Y, PAL["hillsh"]); put(X + 2, Y - 1, PAL["hillsh"]); put(X + 4, Y, PAL["hillsh"])


def mountain(X, Y):
    for i in range(6):
        for dx in range(-i, i + 1):
            put(X + dx, Y - 5 + i, PAL["rock"])
        put(X - i, Y - 5 + i, PAL["rockhi"])
        put(X + i, Y - 5 + i, PAL["rocksh"])
    put(X, Y - 5, PAL["snow"]); put(X - 1, Y - 4, PAL["snow"]); put(X, Y - 4, PAL["snow"])


def reeds(X, Y):
    for dx in (-2, 0, 2):
        put(X + dx, Y, PAL["reed"]); put(X + dx, Y - 1, PAL["reed"])
    put(X - 1, Y + 1, PAL["water_s"]); put(X + 1, Y + 1, PAL["water_s"])


site_cells = {(s["x"], s["y"]) for lst in sites.values() for s in lst}
for ty in range(H):
    for tx in range(W):
        t = grid[ty][tx]
        if t == "~" or (tx, ty) in site_cells:
            continue
        X0, Y0 = tx * T, ty * T
        if t == "f":
            deciduous(X0 + 2 + prng.randrange(2), Y0 + 4)
            deciduous(X0 + 5 + prng.randrange(2), Y0 + 7)
        elif t == "c":
            pine(X0 + 2 + prng.randrange(2), Y0 + 5)
            pine(X0 + 5 + prng.randrange(2), Y0 + 8)
        elif t == "t" and prng.random() < 0.4:
            pine(X0 + 4, Y0 + 6)
        elif t == "h":
            hill(X0 + 4, Y0 + 6)
        elif t == "m":
            mountain(X0 + 4, Y0 + 7)
        elif t == "s":
            reeds(X0 + 4, Y0 + 5)
        elif t in "gpv" and prng.random() < 0.12:
            deciduous(X0 + 4, Y0 + 5)

RIVERS = [[(5.5, 13), (8, 16), (10, 19.5), (12.5, 21.5)],
          [(4, 27), (6, 31), (8.5, 35), (11, 38.5)],
          [(3, 44), (5, 48), (8, 50), (10, 51.5)]]
rr = random.Random(SEED + 11)
for river in RIVERS:
    pts = []
    for (ax, ay), (bx, by) in zip(river, river[1:]):
        steps = int(math.hypot(bx - ax, by - ay) * T * 1.5)
        for i in range(steps):
            f = i / steps
            pts.append((ax + (bx - ax) * f, ay + (by - ay) * f))
    wob = 0.0
    for fx, fy in pts:
        wob = max(-1.5, min(1.5, wob + rr.uniform(-0.35, 0.35)))
        X, Y = int(fx * T + wob), int(fy * T)
        for dx in (0, 1):
            if 0 <= X + dx < W * T and 0 <= Y < H * T and land_at_px(X + dx, Y):
                px[X + dx, Y] = PAL["shallow"] if dx == 0 else PAL["mid"]
                mk[X + dx, Y] = 255

os.makedirs(os.path.join(ROOT, "assets", "sprites"), exist_ok=True)
img.save(os.path.join(ROOT, "assets", "sprites", "map.png"))
mask.save(os.path.join(ROOT, "assets", "sprites", "map_water.png"))

out = {
    "width": W, "height": H, "tile": T,
    "grid": ["".join(r) for r in grid],
    "sites": sites,
    "paths": paths,
    "europe_lane": europe_lane,
}
with open(os.path.join(ROOT, "data", "map.json"), "w") as f:
    json.dump(out, f, indent=1)
print("capital", capital, "port", cap_port)
for k, v in sites.items():
    print(k, v)
