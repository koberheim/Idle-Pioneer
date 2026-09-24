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
TP = 12  # art pixels per tile in the rendered map (displayed at 2x)
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
    "whaling": [(9, 55, "sea"), (19, 57, "sea")],
    "silver_mine": [(2, 23, "land"), (13, 8, "sea")],
    "horse_ranch": [(3, 50, "land"), (25, 30, "sea")],
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

exec(open(os.path.join(ROOT, 'tools', 'map_render.py')).read())

out = {
    "width": W, "height": H, "tile": TP,
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
