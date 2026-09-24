"""Raw-goods icons (48 px, high density).

Run: python tools/hd/goods_raw.py [sheet.png]
Draws grain, cod, hemp, sugar_cane, hides, tobacco, cotton, iron_ore, indigo,
furs, whale_oil, horses and silver into assets/sprites/icons/.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: E402,F401,F403

# -- extra colours -----------------------------------------------------------
COD_BACK = (122, 116, 76)
COD_SPOT = (86, 80, 50)
COD_BELLY = (234, 224, 194)
HEMP = (104, 150, 70)
HEMP_D = (58, 104, 50)
HEMP_STALK = (196, 184, 120)
CANE = (176, 190, 84)
CANE_D = (112, 128, 46)
CANE_NODE = (126, 96, 58)
CANE_PITH = (240, 232, 190)
HIDE = (196, 150, 104)
HIDE_L = (222, 184, 140)
HIDE_SPOT = (110, 70, 44)
TOB_GREEN = (116, 160, 60)
TOB_GOLD = (212, 164, 64)
TOB_BROWN = (170, 104, 46)
COTTON = (248, 244, 234)
COTTON_S = (206, 200, 196)
BRACT = (120, 78, 46)
ORE = (116, 84, 72)
ORE_D = (74, 52, 46)
ORE_RUST = (182, 88, 50)
ORE_RED = (150, 58, 40)
INDIGO_L = (110, 104, 196)
BEAVER = (118, 74, 42)
BEAVER_L = (164, 112, 66)
BEAVER_D = (78, 46, 26)
OIL = (232, 184, 60)
OIL_D = (176, 118, 30)
GLASS = (200, 222, 214)
GLASS_D = (130, 156, 150)
CORK = (176, 128, 80)
CHESTNUT = (148, 82, 44)
CHESTNUT_D = (96, 50, 28)
MANE = (58, 36, 26)
SILVER_L = (240, 244, 248)


# -- helpers -------------------------------------------------------------------
def oval(ic, cx, cy, rx, ry, ang, color, steps=28, **kw):
    """Ellipse rotated by `ang` degrees."""
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    ic.poly(pts, color, **kw)


def leaf(ic, base, tip, width, color, rib=None, veins=0, bend=0.0, shape=0.8, **kw):
    """Pointed leaf from base to tip; `bend` curves it sideways."""
    bx, by = base
    tx, ty = tip
    dx, dy = tx - bx, ty - by
    ln = math.hypot(dx, dy) or 1
    nx, ny = -dy / ln, dx / ln
    left, right, mid = [], [], []
    n = 20
    for i in range(n + 1):
        s = i / n
        off = bend * math.sin(math.pi * s) * ln * 0.25
        cx = bx + dx * s + nx * off
        cy = by + dy * s + ny * off
        w = width * 0.5 * (math.sin(math.pi * min(1, s * 1.08)) ** shape)
        left.append((cx + nx * w, cy + ny * w))
        right.append((cx - nx * w, cy - ny * w))
        mid.append((cx, cy))
    ic.poly(left + right[::-1], color, **kw)
    if rib:
        ic.line(mid[1:-2], rib, 0.7)
        for k in range(veins):
            s = (k + 1) / (veins + 1)
            i = int(s * n)
            px, py = mid[i]
            w = width * 0.42 * math.sin(math.pi * s)
            fx, fy = dx / ln * w * 0.8, dy / ln * w * 0.8
            ic.line([(px, py), (px + nx * w + fx, py + ny * w + fy)], rib, 0.5)
            ic.line([(px, py), (px - nx * w + fx, py - ny * w + fy)], rib, 0.5)
    return mid


def lerp(p, q, t):
    return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)


# -- icons ---------------------------------------------------------------------
def grain():
    ic = Icon(seed=3)
    tie = (24, 27)
    # stalks fanning out below the tie
    for fx in (13, 17, 21, 25, 29, 33, 36):
        ic.line([(tie[0] + (fx - 24) * 0.25, tie[1]), (fx, 45)], STRAW_D, 1.6)
    for fx in (15, 19, 23, 27, 31, 35):
        ic.line([(tie[0] + (fx - 24) * 0.25, tie[1]), (fx, 44.5)], STRAW, 1.0)
    # stalks rising to the ears
    ears = [((22, 25), (8, 7)), ((23, 24), (15, 3)), ((24, 24), (24, 2)),
            ((25, 24), (33, 3)), ((26, 25), (40, 7))]
    for b, t in ears:
        ic.line([b, lerp(b, t, 0.55)], STRAW_D, 1.4)
    for b, t in ears:
        s0 = lerp(b, t, 0.45)
        ang = math.degrees(math.atan2(t[1] - s0[1], t[0] - s0[0]))
        dx, dy = t[0] - s0[0], t[1] - s0[1]
        ln = math.hypot(dx, dy)
        nx, ny = -dy / ln, dx / ln
        # awns
        for i in range(6):
            s = 0.25 + i * 0.14
            px, py = lerp(s0, t, s)
            for side in (-1, 1):
                ex = px + dx / ln * 6 + nx * side * 2.5
                ey = py + dy / ln * 6 + ny * side * 2.5
                ic.line([(px, py), (ex, ey)], mul(STRAW_D, 1.05), 0.45)
        # kernels
        n = 7
        for i in range(n):
            s = i / (n - 1)
            px, py = lerp(s0, t, s * 0.92)
            side = 1 if i % 2 else -1
            k = 1.0 - s * 0.3
            oval(ic, px + nx * side * 1.1, py + ny * side * 1.1, 1.9 * k, 1.25 * k,
                 ang + side * 25, STRAW, light=0.3, dark=0.3)
        ic.dot(*lerp(s0, t, 0.3), CREAM, 0.5)
    # twine band
    ic.poly([(18, 25), (30, 25), (29.5, 29.5), (18.5, 29.5)], LEATHER)
    ic.line([(18.5, 27.2), (29.5, 27.2)], LEATHER_D, 0.6)
    ic.line([(22, 29), (20, 34)], LEATHER, 1.0)
    ic.line([(25, 29), (27, 33.5)], LEATHER, 1.0)
    ic.save("grain")


def cod():
    ic = Icon(seed=5)
    # tail
    ic.poly([(9, 24), (2, 15), (5.5, 14), (11, 21.5), (11, 27), (5.5, 34), (2, 33)], COD_BACK)
    for y in (17, 20, 28, 31):
        ic.line([(4.5, y), (10, 24.5 + (y - 24) * 0.2)], COD_SPOT, 0.45)
    # three dorsal fins, two anal fins
    ic.poly([(12.5, 21), (14, 17), (18, 17), (19, 19.5)], COD_SPOT)
    ic.poly([(19, 18.5), (21, 13.5), (25.5, 13), (27, 17)], COD_SPOT)
    ic.poly([(27.5, 16.5), (30, 11.5), (34, 11.5), (35, 15.5)], COD_SPOT)
    ic.poly([(14, 28.5), (15, 33), (19, 33), (20, 30)], mul(COD_BACK, 0.85))
    ic.poly([(21, 30.5), (23, 35.5), (27.5, 35), (28, 31)], mul(COD_BACK, 0.85))
    # body: long and tapering to the tail
    body = [(9.5, 24.5), (14, 20.5), (22, 17), (32, 15), (39, 16), (44, 19.5), (46.5, 23.5),
            (45.5, 26.5), (42, 29.5), (34, 31.5), (24, 31.5), (15, 28.5)]
    ic.poly(body, COD_BACK, light=0.22, dark=0.2, angle=-90)
    belly = [(12, 26), (20, 26.5), (30, 26.5), (38, 26), (45.5, 25), (45.5, 26.5), (42, 29.5),
             (34, 31.5), (24, 31.5), (15, 28.5)]
    ic.poly(belly, COD_BELLY, light=0.1, dark=0.18, angle=-90)
    ic.speckle((13, 17, 41, 25), COD_SPOT, 55, r=0.55)
    # pale lateral line, the cod's tell
    ic.line([(11, 24.5), (20, 23), (30, 21), (36, 20.5)], CREAM, 0.7)
    # gill cover, mouth and eye
    ic.arc((30, 16.5, 40, 31), 95, 245, mul(COD_BACK, 0.65), 0.8)
    ic.poly([(41, 29), (40.5, 32), (39.5, 29.5)], mul(COD_BELLY, 0.8), shade=False)
    ic.line([(42.5, 25.2), (46.5, 24.8)], INK_SOFT, 0.6)
    ic.circle(40.5, 20.5, 2.2, CREAM, shade=False)
    ic.circle(40.8, 20.5, 1.3, INK, shade=False)
    ic.dot(40.2, 19.9, WHITE, 0.4)
    ic.line([(43, 28), (44, 31.5)], COD_SPOT, 0.7)
    ic.line([(24, 18), (31, 16.5)], mul(COD_BACK, 1.25), 0.6)
    ic.save("cod")


def hemp():
    ic = Icon(seed=7)
    # bundle of retted stalks, tied
    stalks = [(-8, -3), (-5, -1.8), (-2, -0.6), (1, 0.4), (4, 1.4), (7, 2.6), (9, 3.2)]
    for i, (bot, top) in enumerate(stalks):
        ic.line([(24 + top, 30), (24 + bot * 1.2, 45)], HEMP_STALK if i % 2 else mul(HEMP_STALK, 0.8), 1.6)
    for bot, top in stalks[1:-1]:
        ic.line([(24 + top * 0.6, 30), (24 + top * 0.3, 18)], HEMP_D, 1.2)

    def palm(cx, cy, size, rot, col, spread=26):
        ic.circle(cx, cy, 1.2, mul(col, 0.7), shade=False)
        for k, a in enumerate((-3, -2, -1, 0, 1, 2, 3)):
            aa = a * spread
            ln = size * (1.0 - abs(a) * 0.14)
            ang = math.radians(rot + aa - 90)
            tip = (cx + math.cos(ang) * ln, cy + math.sin(ang) * ln)
            leaf(ic, (cx, cy), tip, size * 0.2, col if k % 2 else mul(col, 0.88),
                 rib=mul(col, 0.62), shape=0.6, light=0.22, dark=0.22)

    # petioles to the side leaves
    ic.line([(22, 25), (12, 22)], HEMP_D, 0.9)
    ic.line([(26, 25), (36, 22)], HEMP_D, 0.9)
    palm(11, 22, 11, -70, mul(HEMP, 0.92), spread=24)
    palm(37, 22, 11, 70, mul(HEMP, 0.92), spread=24)
    palm(24, 20, 18, 0, mul(HEMP, 1.08), spread=27)
    # twine
    ic.poly([(18, 32), (30, 32), (29.5, 36), (18.5, 36)], LEATHER)
    ic.line([(18.5, 34), (29.5, 34)], LEATHER_D, 0.6)
    ic.save("hemp")


def sugar_cane():
    ic = Icon(seed=9)
    # leaves behind
    leaf(ic, (17, 16), (4, 4), 3.5, LEAF, rib=LEAF_D, bend=-0.4)
    leaf(ic, (31, 14), (45, 6), 3.5, LEAF, rib=LEAF_D, bend=0.4)
    leaf(ic, (24, 12), (19, 1), 3.0, LEAF_L, rib=LEAF, bend=0.3)
    # three stalks, cut diagonally at the top
    canes = [(9, 45, 16, 12), (19, 45, 25, 8), (30, 45, 34, 13)]
    for x0, y0, x1, y1 in canes:
        pass
    for i, (bx, by, tx, ty) in enumerate(canes):
        w = 3.4
        col = CANE if i != 1 else mul(CANE, 1.06)
        ic.poly([(bx - w, by), (bx + w, by), (tx + w, ty + 2.5), (tx - w, ty - 1.5)], col,
                light=0.25, dark=0.3, angle=180)
        # nodes
        for s in (0.22, 0.47, 0.72):
            px, py = lerp((bx, by), (tx, ty), s)
            ic.poly([(px - w - 0.3, py - 0.2), (px + w + 0.3, py + 0.4),
                     (px + w + 0.3, py + 1.6), (px - w - 0.3, py + 1.0)], CANE_NODE, shade=False)
            ic.line([(px - w + 0.5, py - 1.0), (px + w - 0.5, py - 0.6)], CANE_D, 0.5)
            ic.dot(px - w + 1.2, py + 2.5, mul(CANE, 1.2), 0.5)
        # highlight stripe
        ic.line([lerp((bx - 1.6, by), (tx - 1.6, ty), 0.05), lerp((bx - 1.6, by), (tx - 1.6, ty), 0.9)],
                mul(col, 1.18), 0.6)
        # cut face
        oval(ic, tx, ty + 0.5, w, 1.7, 30, CANE_PITH, shade=False)
        ic.dot(tx, ty + 0.5, mul(CANE_PITH, 0.85), 0.6)
    # a leaf in front
    leaf(ic, (26, 30), (44, 22), 3.2, LEAF_L, rib=LEAF, bend=0.35)
    ic.save("sugar_cane")


def hides():
    ic = Icon(seed=11)
    # a stretching frame of four lashed poles
    for a, b in (((2, 5), (46, 5)), ((2, 43), (46, 43))):
        ic.line([a, b], WOOD, 2.4, shade=True)
    for a, b in (((5, 2), (5, 46)), ((43, 2), (43, 46))):
        ic.line([a, b], WOOD, 2.4, shade=True)
    for x, y in ((5, 5), (43, 5), (5, 43), (43, 43)):
        ic.line([(x - 1.8, y - 1.8), (x + 1.8, y + 1.8)], LEATHER_D, 0.9)
        ic.line([(x - 1.8, y + 1.8), (x + 1.8, y - 1.8)], LEATHER_D, 0.9)
    # the hide: legs to the corners, neck at the top, tail below
    pts = [(9, 9), (14, 12), (19, 11), (21, 8), (27, 8), (29, 11), (34, 12), (39, 9),
           (36, 15), (34.5, 20), (35.5, 26), (34.5, 32), (36, 35), (39, 39), (33, 37.5),
           (28, 38.5), (25.5, 41), (22.5, 41), (20, 38.5), (15, 37.5), (9, 39), (12, 35),
           (13.5, 32), (12.5, 26), (13.5, 20), (12, 15)]
    ic.poly(pts, HIDE, light=0.22, dark=0.28)
    inner = [((x - 24) * 0.8 + 24, (y - 24.5) * 0.82 + 24.5) for x, y in pts]
    ic.poly(inner, HIDE_L, light=0.15, dark=0.2)
    # cow patches on the hair side
    ic.poly([(16, 14), (21, 13), (23, 17), (20, 21), (16, 19)], HIDE_SPOT, light=0.15, dark=0.1)
    ic.poly([(26, 24), (31, 22.5), (32.5, 28), (29.5, 32), (25.5, 29.5)], HIDE_SPOT, light=0.15, dark=0.1)
    ic.poly([(16.5, 30), (20, 29), (20.5, 33.5), (17, 34.5)], HIDE_SPOT, light=0.15, dark=0.1)
    ic.speckle((13, 11, 35, 38), mul(HIDE, 0.85), 26, r=0.45)
    # rawhide lacing out to the frame
    for x, y in pts:
        if x < 16:
            tgt = (5, y)
        elif x > 32:
            tgt = (43, y)
        elif y < 20:
            tgt = (x, 5)
        else:
            tgt = (x, 43)
        ic.line([(x, y), tgt], WOOD_L, 0.6)
    ic.save("hides")


def tobacco():
    ic = Icon(seed=13)
    base = (24, 42)
    # three leaves fanned, green behind to cured gold in front
    leaf(ic, (23, 40), (5, 8), 13, TOB_GREEN, rib=mul(TOB_GREEN, 0.7), veins=5, bend=-0.25, shape=0.7)
    leaf(ic, (25, 40), (43, 8), 13, TOB_BROWN, rib=mul(TOB_BROWN, 0.7), veins=5, bend=0.25, shape=0.7)
    leaf(ic, (24, 42), (24, 2), 16, TOB_GOLD, rib=mul(TOB_GOLD, 0.72), veins=6, shape=0.65,
         light=0.25, dark=0.25)
    ic.speckle((16, 8, 32, 36), mul(TOB_GOLD, 0.82), 12, r=0.5)
    # twine tying the hand of leaves
    ic.poly([(20, 38), (28, 38), (27.5, 42), (20.5, 42)], LINEN)
    ic.line([(21, 40), (27, 40)], PARCH_D, 0.5)
    ic.line([(23, 42), (22.5, 46)], TOBACCO_D, 1.4)
    ic.line([(25, 42), (25.5, 46)], TOBACCO_D, 1.4)
    ic.save("tobacco")


def cotton():
    ic = Icon(seed=15)
    # stem and twigs
    ic.line([(24, 46), (24, 36), (24, 26)], BARK, 1.8)
    ic.line([(24, 39), (11, 31)], BARK, 1.3)
    ic.line([(24, 37), (37, 29)], BARK, 1.3)
    # small leaves
    leaf(ic, (24, 42), (34, 40), 4, LEAF, rib=LEAF_D, bend=0.3)
    leaf(ic, (24, 44), (14, 42), 4, LEAF_D, rib=mul(LEAF_D, 0.7), bend=-0.3)

    def boll(cx, cy, r, bracts):
        # dried brown bracts poking out between the locks
        for a in bracts:
            ang = math.radians(a)
            tip = (cx + math.cos(ang) * r * 1.45, cy + math.sin(ang) * r * 1.45)
            leaf(ic, (cx, cy), tip, r * 0.6, BRACT, shape=0.9, light=0.2, dark=0.3)
        # five soft locks of fluff
        locks = [(-0.42, -0.3), (0.4, -0.36), (-0.36, 0.4), (0.42, 0.34), (0.0, -0.05)]
        for i, (ox, oy) in enumerate(locks):
            rr = r * (0.62 if i < 4 else 0.5)
            ic.circle(cx + ox * r, cy + oy * r, rr, COTTON, light=0.08, dark=0.32)
        for ox, oy in locks[:4]:
            ic.line([(cx + ox * r * 0.25, cy + oy * r * 0.25), (cx + ox * r * 0.75, cy + oy * r * 0.75)],
                    COTTON_S, 0.6)
        ic.dot(cx - r * 0.55, cy - r * 0.5, WHITE, 0.9)

    boll(9.5, 29, 7, (200, 250, 110, 330))
    boll(38.5, 27, 7, (340, 290, 70, 210))
    boll(24, 15, 10, (230, 310, 20, 160, 90))
    ic.save("cotton")


def iron_ore():
    ic = Icon(seed=17)
    ic.shadow(24, 42, 20, 3.5)
    base = (112, 92, 92)
    lit = (170, 126, 108)
    dark = (70, 54, 58)

    def rock(front, top, side):
        """Faceted rock: three flat faces lit from the top-left."""
        ic.poly(front, base, light=0.08, dark=0.12)
        ic.poly(top, lit, light=0.12, dark=0.08)
        ic.poly(side, dark, light=0.05, dark=0.1)

    # back rock
    rock([(12, 22), (22, 20), (29, 23), (30, 31), (13, 31)],
         [(9, 16), (17, 9), (28, 8), (35, 13), (29, 23), (22, 20), (12, 22)],
         [(35, 13), (39, 22), (35, 31), (30, 31), (29, 23)])
    # front left
    rock([(4, 32), (12, 30), (19, 33), (19, 42), (6, 42)],
         [(3, 28), (8, 23), (17, 22), (23, 26), (19, 33), (12, 30), (4, 32)],
         [(23, 26), (25, 35), (19, 42), (19, 33)])
    # front right
    rock([(24, 32), (33, 30), (40, 33), (39, 42), (25, 42)],
         [(24, 27), (30, 21), (40, 21), (45, 26), (40, 33), (33, 30), (24, 32)],
         [(45, 26), (46, 36), (39, 42), (40, 33)])
    # rust blooms and red haematite veins
    for box, n in (((10, 10, 34, 22), 14), ((4, 23, 22, 32), 10), ((25, 22, 44, 32), 10)):
        ic.speckle(box, ORE_RUST, n, r=0.8)
    ic.speckle((4, 22, 46, 42), ORE_RED, 16, r=0.8)
    ic.line([(15, 26), (19, 28), (24, 27)], ORE_RED, 0.9)
    ic.line([(28, 36), (31, 38), (35, 37)], ORE_RUST, 0.9)
    ic.line([(8, 36), (11, 38), (14, 37)], ORE_RUST, 0.9)
    ic.line([(19, 11), (25, 14)], ORE_RUST, 1.0)
    # metallic glints on the lit edges
    for x, y in ((17, 10), (9, 24), (31, 22), (21, 8.8)):
        ic.dot(x, y, SILVER, 0.6)
    ic.dot(28, 9, SILVER_L, 0.6)
    ic.save("iron_ore")


def indigo():
    ic = Icon(seed=19)
    ic.shadow(24, 42, 20, 3.5)
    # leaf sprig behind
    stem0, stem1 = (29, 24), (41, 2)
    ic.line([stem0, stem1], LEAF_D, 1.1)
    for i, s in enumerate((0.25, 0.45, 0.65, 0.85)):
        px, py = lerp(stem0, stem1, s)
        leaf(ic, (px, py), (px - 6.5, py - 1.5), 3.8, LEAF if i % 2 else LEAF_L, rib=LEAF_D)
        leaf(ic, (px, py), (px + 6, py + 2.5), 3.8, LEAF_L if i % 2 else LEAF, rib=LEAF_D)
    leaf(ic, (41, 2.5), (42.5, -1.5), 3.2, LEAF_L)

    def cake(x, y, w, h, d):
        """A cube of dye: front, top and right faces."""
        ic.rect((x, y, x + w, y + h), INDIGO, light=0.1, dark=0.2)
        ic.poly([(x, y), (x + d, y - d * 0.8), (x + w + d, y - d * 0.8), (x + w, y)], INDIGO_L,
                light=0.2, dark=0.05)
        ic.poly([(x + w, y), (x + w + d, y - d * 0.8), (x + w + d, y + h - d * 0.8), (x + w, y + h)],
                INDIGO_D, light=0.05, dark=0.1)
        ic.speckle((x, y, x + w, y + h), mul(INDIGO, 0.78), 10, r=0.55)
        ic.speckle((x, y - d, x + w + d, y), mul(INDIGO_L, 1.12), 5, r=0.5)
        ic.line([(x + 0.8, y + 0.8), (x + 0.8, y + h - 1)], mul(INDIGO, 1.25), 0.5)

    cake(12, 21, 13, 11, 5)
    cake(3, 31, 14, 11, 5)
    cake(20, 31, 14, 11, 5)
    # broken lump and powder
    ic.poly([(36, 42), (37, 36), (41, 33), (45, 36), (45.5, 42)], INDIGO, light=0.25, dark=0.3)
    ic.dot(39.5, 35.5, INDIGO_L, 0.8)
    for x, y in ((2.5, 43), (35, 43), (46, 42.5), (19, 43.2)):
        ic.dot(x, y, INDIGO_D, 0.6)
    ic.save("indigo")


def furs():
    ic = Icon(seed=21)
    # flat scaly beaver tail below
    ic.ellipse((16.5, 32.5, 31.5, 47.5), (86, 72, 66), light=0.2, dark=0.2)
    for y in (36, 39, 42, 45):
        ic.line([(18.5, y), (29.5, y)], (122, 104, 94), 0.5)
    for x in (20.5, 24, 27.5):
        ic.line([(x, 34.5), (x, 45.5)], (122, 104, 94), 0.5)
    # four leg flaps
    for (x0, y0, x1, y1) in ((14, 15, 6.5, 11), (34, 15, 41.5, 11), (13, 30, 6, 35.5), (35, 30, 42, 35.5)):
        leaf(ic, (x0, y0), (x1, y1), 6, BEAVER_D, shape=0.45, light=0.2, dark=0.2)
        ic.dot(x1 + (0.8 if x1 < 24 else -0.8), y1, LEATHER, 0.6)
    # head
    ic.circle(15.5, 5, 2, BEAVER_D)
    ic.circle(32.5, 5, 2, BEAVER_D)
    ic.ellipse((15, 2, 33, 16), BEAVER, light=0.25, dark=0.3)
    # body, shaggy edge
    rnd = ic.rnd
    cx, cy, rx, ry = 24, 23, 14, 13.5
    pts = []
    for i in range(44):
        a = 2 * math.pi * i / 44
        k = 1.0 + (0.07 if i % 2 else 0.0)
        pts.append((cx + math.cos(a) * rx * k, cy + math.sin(a) * ry * k))
    ic.poly(pts, BEAVER, light=0.3, dark=0.32)
    ic.ellipse((cx - 9, cy - 10, cx + 7, cy + 7), mix(BEAVER, BEAVER_L, 0.6), light=0.2, dark=0.25)
    ic.ellipse((cx - 6, cy - 8, cx + 2, cy - 1), BEAVER_L, light=0.2, dark=0.15)
    # fur strokes
    for _ in range(65):
        a = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0.05, 0.95) ** 0.8
        x = cx + math.cos(a) * rx * rr
        y = cy + math.sin(a) * ry * rr
        if rr > 0.72:
            c = BEAVER_D
        elif rr > 0.4:
            c = mul(BEAVER, 0.82)
        else:
            c = mix(BEAVER_L, CREAM, 0.35) if rnd.random() < 0.5 else mul(BEAVER, 0.9)
        ic.line([(x, y), (x + 0.3, y + 1.5)], c, 0.5)
    for _ in range(14):
        x, y = rnd.uniform(18, 30), rnd.uniform(4, 13)
        ic.line([(x, y), (x + 0.3, y + 1.3)], mul(BEAVER, 0.8), 0.5)
    # eye holes of the skin
    ic.dot(20.5, 9, INK, 1.0)
    ic.dot(27.5, 9, INK, 1.0)
    ic.dot(cx - 5, cy - 7, CREAM, 0.6)
    ic.save("furs")


def whale_oil():
    ic = Icon(seed=23)
    ic.shadow(24, 43, 15, 3)
    # round-bellied flask
    ic.circle(24, 30, 14, GLASS, light=0.25, dark=0.3)
    ic.rect((19, 9, 29, 19), GLASS, light=0.2, dark=0.3)
    # oil inside: the bowl filled up to a level line
    def seg(cx, cy, r, ytop):
        h = ytop - cy
        a0 = math.asin(max(-1, min(1, h / r)))
        pts = []
        for i in range(25):
            a = a0 + (math.pi - 2 * a0) * i / 24
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        return pts
    ic.poly(seg(24, 30, 12.5, 25), OIL_D, shade=False)
    ic.poly(seg(24, 30, 11.5, 26), OIL, light=0.3, dark=0.2)
    ic.ellipse((13, 24.5, 35, 27.5), mix(OIL, CREAM, 0.45), shade=False)
    # whale tail stamped on the oil
    ic.poly([(24, 36), (23, 33), (19.5, 31), (22, 31), (24, 32), (26, 31), (28.5, 31), (25, 33)],
            OIL_D, shade=False)
    # neck, lip and cork
    ic.rect((18, 8, 30, 11), GLASS_D, radius=1)
    ic.rect((19.5, 2, 28.5, 9), CORK, radius=1)
    ic.line([(20, 4.5), (28, 4.5)], mul(CORK, 0.75), 0.5)
    ic.line([(18.5, 13), (29.5, 13)], LEATHER_D, 1.0)
    ic.line([(29, 13), (31, 18)], LEATHER_D, 0.8)
    # glass shine
    ic.arc((13, 19, 35, 41), 190, 250, WHITE, 1.3)
    ic.line([(21, 10.5), (21, 17)], WHITE, 0.8)
    ic.dot(17, 22, WHITE, 0.7)
    # a drip running down
    ic.poly([(39, 33), (41, 37), (40.5, 39.5), (39, 40), (37.5, 39.5), (37, 37)], OIL, light=0.3, dark=0.25)
    ic.dot(38.5, 37, CREAM, 0.5)
    ic.save("whale_oil")


def horses():
    ic = Icon(seed=25)
    # mane behind the neck
    ic.poly([(26, 7), (31, 8), (36, 13), (39, 20), (41, 28), (43, 36), (44, 45), (35, 45),
             (33, 34), (30, 22)], MANE, light=0.15, dark=0.2)
    # ears
    ic.poly([(24, 10), (25, 2), (29, 9)], CHESTNUT_D)
    ic.poly([(21, 11), (20, 4), (24.5, 9)], CHESTNUT)
    ic.poly([(21.5, 9.5), (21, 6), (23, 9)], mul(CHESTNUT, 0.7), shade=False)
    # head and neck
    head = [(28, 9), (32, 14), (35, 22), (38, 32), (39, 45), (17, 45), (19, 38), (21, 33),
            (18, 32), (14, 33), (10, 33.5), (6.5, 31.5), (6, 28), (8, 24), (13, 17), (19, 11), (23, 9)]
    ic.poly(head, CHESTNUT, light=0.25, dark=0.3)
    # cheek / jaw roundness
    ic.circle(24, 24, 6.5, mul(CHESTNUT, 1.02), light=0.28, dark=0.25)
    ic.arc((17, 17, 31, 31), 20, 150, CHESTNUT_D, 0.8)
    # neck muscle shading
    ic.poly([(30, 28), (34, 25), (37, 34), (38, 45), (33, 45)], mul(CHESTNUT, 0.85), shade=False)
    # mane strands falling over the neck edge and forelock
    for x0, y0, x1, y1 in ((31, 11, 34, 19), (34, 17, 36, 26), (36, 24, 37, 33), (37.5, 32, 38.5, 42)):
        ic.line([(x0, y0), (x1, y1)], MANE, 1.2)
    ic.poly([(21, 9), (26, 8), (24, 14), (21, 16), (22, 12)], MANE)
    # white blaze down the face
    ic.poly([(19.5, 14), (21, 14.5), (16, 22), (11, 29), (9, 29.5), (13, 22)], CREAM, light=0.1, dark=0.15)
    # muzzle, nostril and mouth
    ic.ellipse((5.5, 26, 14, 34), mul(CHESTNUT, 0.8), light=0.2, dark=0.2)
    ic.dot(8.5, 28.8, INK, 0.8)
    ic.line([(7.5, 32.2), (12, 32.6)], INK_SOFT, 0.6)
    # eye
    ic.circle(21, 17.5, 1.5, INK, shade=False)
    ic.dot(20.6, 17, WHITE, 0.45)
    ic.line([(19.5, 15.8), (22.5, 15.8)], CHESTNUT_D, 0.5)
    # bridle
    ic.line([(26, 11), (25, 18), (22, 27), (15, 31)], LEATHER_D, 1.0)
    ic.line([(13.5, 23.5), (26, 18.5)], LEATHER_D, 1.0)
    ic.line([(12, 29), (14, 25.5)], LEATHER_D, 0.9)
    ic.circle(14, 30.5, 1.3, BRASS, shade=False)
    ic.dot(25.4, 18.6, BRASS, 0.8)
    # sheen
    ic.line([(15, 18), (19, 13.5)], mul(CHESTNUT, 1.3), 0.6)
    ic.line([(28, 30), (30, 40)], mul(CHESTNUT, 1.18), 0.6)
    ic.save("horses")


def silver():
    ic = Icon(seed=27)
    ic.shadow(24, 43, 21, 3.5)

    def ingot(x, y, w, h, d, ox, oy):
        # front face (trapezoid), top face, right end
        front = [(x, y + h), (x + w, y + h), (x + w - d, y), (x + d, y)]
        top = [(x + d, y), (x + w - d, y), (x + w - d + ox, y - oy), (x + d + ox, y - oy)]
        end = [(x + w, y + h), (x + w + ox, y + h - oy), (x + w - d + ox, y - oy), (x + w - d, y)]
        ic.poly(end, SILVER_D, light=0.0, dark=0.2)
        ic.poly(front, SILVER, light=0.1, dark=0.36, angle=180)
        ic.poly(top, SILVER_L, light=0.1, dark=0.12)
        ic.line([(x + d + 1, y + 1.2), (x + w - d - 1, y + 1.2)], WHITE, 0.6)
        # stamped mark
        c = x + w / 2
        ic.rect((c - 3, y + h / 2 - 1.5, c + 3, y + h / 2 + 2), mul(SILVER, 0.8), shade=False)
        ic.rect((c - 3, y + h / 2 + 1.2, c + 3, y + h / 2 + 2), mul(SILVER, 1.1), shade=False)

    ingot(1, 32, 21, 10, 2.5, 4, 3.5)
    ingot(21, 32, 21, 10, 2.5, 4, 3.5)
    ingot(11, 19, 21, 10, 2.5, 4, 3.5)
    # sparkles
    for (x, y, s) in ((7, 19, 3.6), (40, 16, 2.6), (19, 11, 1.8)):
        ic.line([(x - s, y), (x + s, y)], WHITE, 0.6)
        ic.line([(x, y - s), (x, y + s)], WHITE, 0.6)
        ic.dot(x, y, WHITE, 0.8)
    ic.save("silver")


NAMES = ["grain", "cod", "hemp", "sugar_cane", "hides", "tobacco", "cotton",
         "iron_ore", "indigo", "furs", "whale_oil", "horses", "silver"]

if __name__ == "__main__":
    for n in NAMES:
        globals()[n]()
    if len(sys.argv) > 1:
        sheet(NAMES, sys.argv[1], scale=4, cols=5)
