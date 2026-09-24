"""High-density icons for the crafted goods (tier 2-4 production chain).

Run: python tools/hd/goods_crafted.py [sheet.png]
Writes assets/sprites/icons/<name>.png for every good below and, if a path is
given, a contact sheet for review.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: E402,F401,F403

# extra colours used only by this set
STONE = (206, 180, 130)       # salt-glaze stoneware
STONE_D = (150, 118, 76)
GLAZE = (92, 56, 34)          # brown slip glaze on the jug neck
GLASS = (44, 86, 56)          # dark green bottle glass
GLASS_L = (96, 150, 104)
RUM = (196, 120, 40)
TAR = (30, 26, 28)
TAR_L = (92, 88, 100)
FLAME = (252, 200, 80)
FLAME_O = (236, 120, 40)
TALLOW = (240, 226, 186)
FISH = (228, 212, 172)
FISH_SKIN = (150, 138, 118)
HEMP = (206, 170, 104)
HEMP_D = (150, 114, 60)
CANVAS = (232, 222, 196)
CANVAS_D = (190, 176, 144)
BUFF = (226, 196, 130)
BLANKET = (150, 40, 36)
IRON_L = (150, 156, 168)
HORSE = (120, 74, 44)
HORSE_D = (78, 46, 28)
DENIM = (58, 70, 150)
BREAD = (206, 142, 70)


def ell_pts(cx, cy, rx, ry, a0, a1, n=24):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def rot_ell(cx, cy, rx, ry, ang, n=28):
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    return pts


def barrel_shape(ic, x0, y0, x1, y1, wood=WOOD, hoop=IRON, top=None, bulge=2.5):
    """Standing barrel: bulged staves, iron hoops, elliptical head on top."""
    cx = (x0 + x1) / 2
    w = x1 - x0
    ry = w * 0.16
    h = y1 - y0
    # body silhouette with bulge
    left = [(x0 - bulge * math.sin(math.pi * t / 10), y0 + ry + (h - 2 * ry) * t / 10) for t in range(11)]
    right = [(x1 + bulge * math.sin(math.pi * t / 10), y0 + ry + (h - 2 * ry) * t / 10) for t in range(11)]
    body = left + [(cx - (w / 2) * math.cos(math.radians(a)), y1 - ry + ry * math.sin(math.radians(a))) for a in range(0, 181, 15)] + right[::-1]
    ic.poly(body, wood, light=0.22, dark=0.32, angle=-160)
    # stave lines
    for k in (-0.62, -0.3, 0.02, 0.34, 0.66):
        x = cx + k * w / 2
        pts = [(x + k * bulge * math.sin(math.pi * t / 8), y0 + ry * 1.6 + (h - 2.6 * ry) * t / 8 + ry * (1 - k * k) ** 0.5 * 0.9 * (t / 8)) for t in range(9)]
        ic.line(pts, mul(wood, 0.72), 0.6)
    # hoops
    for t in (0.14, 0.3, 0.7, 0.86):
        yy = y0 + ry + (h - 2 * ry) * t
        bx = bulge * math.sin(math.pi * t)
        pts = [(cx - (w / 2 + bx) * math.cos(math.radians(a)), yy + ry * 0.9 * math.sin(math.radians(a))) for a in range(0, 181, 15)]
        ic.line(pts, hoop, 1.7)
        ic.line(pts[:5], mul(hoop, 1.35), 0.6)
    # head
    ic.ellipse((x0, y0, x1, y0 + 2 * ry), mul(wood, 0.82), light=0.1, dark=0.1)
    ic.ellipse((x0 + 1.4, y0 + 0.9, x1 - 1.4, y0 + 2 * ry - 0.6), top or mul(wood, 1.12), light=0.15, dark=0.2)
    return cx, ry


# ---------------------------------------------------------------------------
def lumber():
    ic = Icon(seed=3)
    ic.shadow(24, 42, 21, 3)
    # stack of sawn boards in 3/4 view: long face, top, and square sawn end
    boards = [(3, 36, 35), (7, 29, 39), (3, 22, 35), (7, 15, 39)]
    d = 6
    for i, (x0, y, x1) in enumerate(boards):
        face = PINE if i % 2 == 0 else mix(PINE, WOOD_L, 0.45)
        ic.poly([(x0, y), (x0 + d, y - 4), (x1 + d, y - 4), (x1, y)], mul(face, 1.12), shade=False)
        ic.rect((x0, y, x1, y + 6), face, light=0.12, dark=0.16)
        # square sawn end, darker, with growth rings
        ic.poly([(x1, y), (x1 + d, y - 4), (x1 + d, y + 2), (x1, y + 6)], mul(face, 0.72), shade=False)
        ic.line([(x1 + 1.5, y + 4.5), (x1 + 2.5, y + 1.5), (x1 + 4.5, y - 1.5)], mul(face, 0.52), 0.9)
        # grain along the face and on the top
        for gy, a, b in ((y + 2.5, 3, 17), (y + 4.5, 12, 27)):
            sx = x0 + a + ic.rnd.uniform(-2, 3)
            ic.line([(sx, gy), (x0 + b + ic.rnd.uniform(-2, 3), gy)], mul(face, 0.78), 1.0)
        ic.line([(x0 + 10, y - 1.5), (x0 + 24, y - 1.5)], mul(face, 0.92), 1.0)
        kx = x0 + 20 + ic.rnd.uniform(-8, 6)
        ic.ellipse((kx, y + 2, kx + 2.4, y + 4.4), WOOD, shade=False)
        ic.line([(x0 + 0.5, y + 0.5), (x1 - 1, y + 0.5)], mul(face, 1.22), 1.0)
        ic.line([(x0, y + 5.5), (x1, y + 5.5)], mul(face, 0.58), 1.0)
    ic.save("lumber")


def charcoal():
    ic = Icon(seed=5)
    ic.shadow(24, 41, 20, 4)
    lumps = [
        [(4, 40), (7, 33), (13, 31), (17, 35), (16, 41)],
        [(14, 41), (15, 34), (21, 30), (27, 32), (28, 41)],
        [(26, 41), (27, 33), (33, 30), (40, 32), (43, 40)],
        [(9, 33), (11, 25), (18, 22), (22, 27), (19, 33)],
        [(19, 31), (22, 22), (29, 20), (33, 25), (30, 32)],
        [(30, 32), (32, 25), (38, 24), (41, 30), (38, 34)],
        [(14, 24), (17, 16), (24, 13), (28, 18), (25, 24)],
        [(24, 21), (27, 14), (33, 14), (35, 20), (31, 24)],
    ]
    for i, pts in enumerate(lumps):
        ic.poly(pts, CHARCOAL if i % 2 else mul(CHARCOAL, 0.9), light=0.35, dark=0.2)
        # facet highlight along the upper-left edge
        ic.line(pts[1:3], CHARCOAL_L, 0.8)
        ic.dot(pts[2][0] - 0.5, pts[2][1] + 1.2, (150, 150, 160), 0.6)
    # split cracks of the burnt wood grain
    for x, y in ((20, 36), (33, 36), (15, 28), (26, 26), (23, 18), (36, 29)):
        ic.line([(x - 2, y), (x + 2, y + 0.6)], (26, 24, 26), 0.6)
    # a last ember
    ic.dot(29.5, 31.5, FLAME_O, 0.9)
    ic.dot(29.5, 31.3, FLAME, 0.4)
    ic.save("charcoal")


def tar():
    ic = Icon(seed=7)
    ic.shadow(24, 43, 18, 3)
    cx, ry = barrel_shape(ic, 10, 9, 38, 43, wood=mul(WOOD, 0.9), top=TAR)
    # glossy tar pooled in the head, spilling over the rim
    ic.ellipse((12, 10.5, 36, 17), TAR, light=0.25, dark=0.1)
    ic.poly([(12, 13), (18, 14), (17.5, 22), (16.5, 25), (15, 22), (14, 17)], TAR, shade=False)
    ic.poly([(26, 16), (31, 15), (30.5, 20), (29.5, 21.5), (28.5, 19)], TAR, shade=False)
    ic.circle(16, 25, 1.4, TAR, shade=False)
    ic.circle(29.5, 21.5, 1.2, TAR, shade=False)
    ic.line([(16, 12.5), (22, 11.8)], TAR_L, 0.7)
    ic.dot(15.5, 18, TAR_L, 0.5)
    # a dipping paddle
    ic.line([(28, 13), (37, 2)], WOOD_L, 1.6)
    ic.line([(28.3, 12), (36.5, 2.5)], mul(WOOD_L, 1.2), 0.5)
    ic.poly([(25, 14), (29, 11), (31, 14), (27, 16)], TAR, shade=False)
    # puddle at the foot
    ic.ellipse((33, 40, 44, 44), TAR, light=0.2, dark=0.1)
    ic.save("tar")


def flour():
    ic = Icon(seed=9)
    ic.shadow(24, 43, 18, 3)
    # spilled flour
    ic.ellipse((30, 38, 45, 44), WHITE, light=0.05, dark=0.12)
    # sack body
    ic.poly([(12, 16), (36, 16), (40, 26), (40, 38), (35, 43), (13, 43), (8, 38), (8, 26)], LINEN, light=0.2, dark=0.28)
    # gathered neck and tied top
    ic.poly([(17, 17), (19, 10), (29, 10), (31, 17)], mul(LINEN, 0.96), light=0.1, dark=0.25)
    ic.poly([(16, 11), (19, 5), (24, 7), (29, 5), (32, 11), (24, 10)], LINEN, light=0.2, dark=0.2)
    ic.rect((18, 12, 30, 14.5), HEMP, light=0.2, dark=0.2)
    ic.line([(28, 13.5), (32, 17), (31, 20)], HEMP, 0.9)
    # folds
    ic.line([(19, 15.5), (17, 22)], mul(LINEN, 0.8), 0.6)
    ic.line([(29, 15.5), (32, 22)], mul(LINEN, 0.8), 0.6)
    ic.line([(10, 36), (14, 41)], mul(LINEN, 0.82), 0.6)
    # stamped wheat sheaf mark
    ic.line([(24, 24), (24, 38)], STRAW_D, 0.8)
    ic.line([(24, 32), (20, 26)], STRAW_D, 0.7)
    ic.line([(24, 32), (28, 26)], STRAW_D, 0.7)
    for yy in (24, 27, 30):
        ic.ellipse((22, yy, 24, yy + 3), STRAW_D, shade=False)
        ic.ellipse((24, yy, 26, yy + 3), STRAW_D, shade=False)
    ic.dot(13, 21, WHITE, 1.1)
    ic.speckle((30, 38, 45, 44), CREAM, 5)
    ic.save("flour")


def salt_cod():
    ic = Icon(seed=11)
    ic.shadow(24, 42, 20, 3)

    def fish(ox, oy, s=1.0, back=False):
        P = lambda x, y: (ox + x * s, oy + y * s)
        # headless split cod, opened flat: square-cut shoulder tapering to the tail
        body = [P(0, 1), P(9, 0), P(20, 2.5), P(27, 5.5), P(29, 7), P(27, 8.5), P(20, 11.5), P(9, 14), P(0, 13)]
        ic.poly(body, FISH_SKIN, light=0.15, dark=0.25)
        inner = [P(1.2, 2.4), P(9, 1.6), P(19.5, 4), P(26, 6.3), P(27, 7), P(26, 7.7), P(19.5, 10), P(9, 12.4), P(1.2, 11.6)]
        ic.poly(inner, mul(FISH, 0.94) if back else FISH, light=0.22, dark=0.2)
        # tail
        ic.poly([P(27.5, 7), P(36, 0.5), P(34.5, 7), P(36, 13.5)], FISH_SKIN, light=0.15, dark=0.2)
        for k in (-1, 0, 1):
            ic.line([P(29.5, 7), P(35, 7 + k * 4)], mul(FISH_SKIN, 0.78), 0.45)
        # backbone groove and flake lines
        ic.line([P(1.5, 7), P(26, 7)], mul(FISH, 0.78), 0.8)
        for x in (5, 9, 13, 17, 21):
            ic.line([P(x, 3.2), P(x + 2, 6.2)], mul(FISH, 0.86), 0.45)
            ic.line([P(x, 10.8), P(x + 2, 7.8)], mul(FISH, 0.86), 0.45)
        ic.speckle((ox, oy, ox + 27 * s, oy + 14 * s), WHITE, 28, 0.45)

    fish(9, 7, 0.95, back=True)
    fish(3, 22, 1.1)
    ic.save("salt_cod")


def rope():
    ic = Icon(seed=13)
    ic.shadow(24, 40, 20, 5)
    cx, cy = 24, 26
    # coil seen from slightly above: outer rings first, inner last
    for i, (rx, ry) in enumerate(((19, 13), (15.5, 10.3), (12, 7.8), (8.6, 5.4))):
        yy = cy - i * 0.8
        pts = ell_pts(cx, yy, rx, ry, 0, 360, 48)
        ic.line(pts, HEMP_D, 4.2)
        ic.line(pts, HEMP, 3.0)
        # twist lay: short diagonal strokes around the ring
        for k in range(0, 48, 2):
            x, y = pts[k]
            ic.line([(x - 0.8, y - 0.9), (x + 0.8, y + 0.9)], HEMP_D, 0.5)
        hl = [p for p in ell_pts(cx, yy, rx, ry, 190, 280, 10)]
        ic.line([(x - 0.6, y - 0.8) for x, y in hl], mul(HEMP, 1.18), 0.6)
    ic.ellipse((cx - 5.5, cy - 6.4, cx + 5.5, cy + 0.4), mul(HEMP_D, 0.55), shade=False)
    # loose end trailing out, whipped with twine
    tail = [(38, 34), (41, 38), (43, 43)]
    ic.line(tail, HEMP_D, 4.0)
    ic.line(tail, HEMP, 2.8)
    ic.line([(41.5, 41), (44.5, 40)], (170, 60, 44), 1.2)
    ic.save("rope")


def leather():
    ic = Icon(seed=15)
    ic.shadow(24, 43, 20, 3)
    # a tanned hide, stretched shape
    hide = [(6, 15), (11, 12), (14, 16), (20, 14), (28, 14), (34, 16), (37, 12), (42, 15), (40, 22), (42, 30),
            (40, 38), (43, 42), (36, 43), (32, 39), (24, 41), (16, 39), (12, 43), (5, 42), (8, 38), (6, 30), (8, 22)]
    ic.poly(hide, LEATHER, light=0.22, dark=0.28)
    # stitched border / lacing marks
    inner = [(9, 19), (15, 18), (24, 17), (33, 18), (38, 19), (37, 29), (37, 37), (24, 38), (11, 37), (10, 29), (9, 19)]
    for a, b in zip(inner, inner[1:]):
        n = int(math.dist(a, b) / 2.6)
        for k in range(n):
            t = (k + 0.3) / n
            ic.dot(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, LEATHER_D, 0.45)
    ic.speckle((10, 20, 38, 38), mul(LEATHER, 1.12), 18, 0.5)
    ic.speckle((10, 20, 38, 38), mul(LEATHER, 0.86), 14, 0.5)
    # roll along the top, tied with thong
    ic.rect((5, 5, 43, 14), LEATHER_D, radius=4.5, light=0.25, dark=0.25)
    ic.ellipse((38, 5, 45, 14), mul(LEATHER_D, 0.9), light=0.1, dark=0.1)
    ic.arc((39.5, 6.5, 43.5, 12.5), 0, 360, mul(LEATHER, 1.05), 0.7)
    ic.line([(7, 7), (37, 7)], mul(LEATHER, 1.1), 0.7)
    for x in (14, 30):
        ic.rect((x, 4.5, x + 2, 14.5), mul(LEATHER_D, 0.62), shade=False)
    ic.save("leather")


def molasses():
    ic = Icon(seed=17)
    ic.shadow(22, 43, 17, 3)
    # stoneware jug: pale salt-glazed belly, dark slip on the shoulder
    ic.ellipse((6, 13, 38, 44), STONE, light=0.22, dark=0.3)
    ic.pie((6, 13, 38, 44), 180, 360, GLAZE)
    ic.poly([(8, 28), (36, 28), (36, 26), (8, 26)], GLAZE, shade=False)
    ic.ellipse((6, 23, 38, 31), GLAZE, light=0.1, dark=0.1)
    ic.ellipse((6.4, 24.5, 37.6, 32.5), STONE, light=0.22, dark=0.22)
    ic.poly([(15, 14), (16, 8), (28, 8), (29, 14)], GLAZE, light=0.25, dark=0.2)
    ic.rect((14.5, 6, 29.5, 9), mul(GLAZE, 1.15), radius=1)
    # cork
    ic.rect((17, 2, 27, 7), WOOD_L, radius=1.2)
    ic.speckle((17, 2, 27, 7), WOOD, 5, 0.4)
    # handle
    ic.arc((26, 7, 42, 25), 270, 90, GLAZE, 2.4)
    ic.arc((26.8, 7.8, 41.2, 24.2), 280, 330, mul(GLAZE, 1.5), 0.6)
    # incised band and "M" mark
    ic.line(ell_pts(22, 34, 15, 2.2, 10, 170, 12), STONE_D, 0.6)
    ic.line([(17, 40), (18.5, 35.5), (22, 39), (25.5, 35.5), (27, 40)], (60, 80, 140), 0.9)
    # dark treacle running from the lip
    ic.poly([(14.5, 8), (17, 8), (16.5, 14), (16.8, 20), (15.7, 23), (14.6, 20), (15, 14)], MOLASSES, shade=False)
    ic.circle(15.7, 22.4, 1.3, MOLASSES, shade=False)
    ic.dot(15.3, 16, (170, 100, 50), 0.4)
    ic.ellipse((2, 40, 13, 44), MOLASSES, light=0.3, dark=0.1)
    ic.dot(11, 17, CREAM, 1.2)
    ic.dot(9.5, 20, CREAM, 0.6)
    ic.save("molasses")


def cured_tobacco():
    ic = Icon(seed=19)
    # a curing stick with two "hands" of tobacco hung leaf-down
    ic.line([(2, 6), (46, 5)], WOOD, 2.4)
    ic.line([(2, 5.3), (46, 4.3)], WOOD_L, 0.6)

    def leaf(x, y, ang, ln, wmax, col):
        a = math.radians(90 + ang)
        ux, uy = math.cos(a), math.sin(a)
        nx, ny = -uy, ux
        prof = [0.15, 0.55, 0.85, 1.0, 0.95, 0.75, 0.45, 0.0]
        left, right = [], []
        for i, p in enumerate(prof):
            t = i / (len(prof) - 1)
            # slight droop/curl toward the tip
            cx, cy = x + ux * ln * t, y + uy * ln * t
            left.append((cx + nx * wmax * p, cy + ny * wmax * p))
            right.append((cx - nx * wmax * p * 0.8, cy - ny * wmax * p * 0.8))
        ic.poly(left + right[::-1], col, light=0.22, dark=0.28)
        tip = (x + ux * ln, y + uy * ln)
        ic.line([(x, y), tip], mul(col, 0.66), 0.5)
        for t in (0.3, 0.5, 0.7):
            cx, cy = x + ux * ln * t, y + uy * ln * t
            ic.line([(cx, cy), (cx + nx * wmax * 0.7 - ux * 2, cy + ny * wmax * 0.7 - uy * 2)], mul(col, 0.78), 0.4)
        # crinkled edge highlight
        ic.line(left[1:5], mul(col, 1.18), 0.4)

    def hand(x, y, flip):
        spec = [(-26, 26), (-13, 32), (13, 31), (26, 25), (0, 36)]
        cols = [TOBACCO_D, mix(TOBACCO, TOBACCO_D, 0.4), mix(TOBACCO, TOBACCO_D, 0.2), mix(TOBACCO, TOBACCO_D, 0.5), TOBACCO]
        for (ang, ln), col in zip(spec, cols):
            leaf(x, y + 3, -ang if flip else ang, ln, 4.2, col)
        ic.rect((x - 2.6, y - 1, x + 2.6, y + 6), TOBACCO_D, radius=1)
        ic.line([(x - 2.6, y + 1.4), (x + 2.6, y + 1)], STRAW, 0.7)
        ic.line([(x - 2.6, y + 3.4), (x + 2.6, y + 3)], STRAW, 0.7)

    hand(14, 5, False)
    hand(34, 5, True)
    ic.save("cured_tobacco")


def _bolt(ic, base, dark, edge=None):
    """A roll of fabric lying diagonally, its free end spread out in soft folds."""
    ang = -38
    u = (math.cos(math.radians(ang)), math.sin(math.radians(ang)))
    nrm = (-u[1], u[0])          # points down-right, toward the viewer's floor
    R = 9.5
    c0 = (13, 28)
    c1 = (c0[0] + u[0] * 25, c0[1] + u[1] * 25)
    off = lambda c, k, s=0: (c[0] + nrm[0] * k + u[0] * s, c[1] + nrm[1] * k + u[1] * s)
    # the unrolled length, spreading down and to the right under the roll
    sheet = [off(c0, R - 1), off(c1, R - 1), (45, 25), (43.5, 32), (45, 38), (39, 41), (32, 44.5), (25, 42.5), (18, 45), (13, 42), off(c0, R - 1, -1)]
    ic.poly(sheet, base, light=0.18, dark=0.3, angle=-120)
    lo = mul(base, 0.76)
    for a, b in (((26, 37), (32, 44)), ((33, 31), (39, 40.5)), ((39, 26), (43.5, 32))):
        ic.line([a, b], lo, 0.7)
        ic.line([(a[0] + 1.3, a[1] - 0.6), (b[0] + 1.3, b[1] - 0.6)], mul(base, 1.12), 0.5)
    if edge:
        ic.line([(13.5, 41.4), (18, 44.2), (25, 41.7), (32, 43.7), (39, 40.2), (44.5, 37.4)], edge, 0.9)
    # roll body
    body = [off(c0, -R), off(c1, -R), off(c1, R), off(c0, R)]
    ic.poly(body, base, shade=False)
    ic.poly(rot_ell(c1[0], c1[1], 3.2, R, ang), base, shade=False)
    # cylinder shading: lit band on the upper side, dark band underneath
    ic.poly([off(c0, -R + 1), off(c1, -R + 1), off(c1, -R + 3.5), off(c0, -R + 3.5)], mul(base, 1.16), shade=False)
    ic.poly([off(c0, R - 3), off(c1, R - 3), off(c1, R), off(c0, R)], mul(base, 0.8), shade=False)
    ic.line([off(c0, -R + 2), off(c1, -R + 2)], mul(base, 1.28), 0.5)
    # the outer lap of cloth running round the roll
    ic.line([off(c0, -R, 9), off(c0, R, 11)], lo, 0.6)
    # near end: the wound layers
    ic.poly(rot_ell(c0[0], c0[1], 3.6, R, ang), mul(base, 1.08), light=0.12, dark=0.2)
    for r in (7.2, 4.4):
        e = rot_ell(c0[0], c0[1], r * 0.38, r, ang)
        ic.line(e + [e[0]], dark, 1.0)
    ic.poly(rot_ell(c0[0], c0[1], 0.9, 1.6, ang), mul(WOOD, 0.8), shade=False)


def cloth():
    ic = Icon(seed=21)
    ic.shadow(27, 42, 20, 3)
    _bolt(ic, LINEN, mul(LINEN, 0.66), edge=(170, 60, 50))
    ic.speckle((6, 6, 46, 44), mul(LINEN, 0.9), 40, 0.4)
    ic.speckle((6, 6, 46, 44), mul(LINEN, 1.05), 20, 0.4)
    # paper tally ticket on a string
    ic.line([(30, 14), (34, 5)], INK_SOFT, 0.5)
    ic.poly([(33, 2), (39, 2.5), (38.5, 8), (32.5, 7.5)], WHITE, light=0.05, dark=0.12)
    ic.line([(34, 4.5), (37.5, 4.7)], INK_SOFT, 0.4)
    ic.line([(34, 6), (37, 6.1)], INK_SOFT, 0.4)
    ic.save("cloth")


def dyed_cloth():
    ic = Icon(seed=23)
    ic.shadow(27, 42, 20, 3)
    light = (150, 140, 226)
    _bolt(ic, INDIGO, light, edge=light)
    ic.speckle((6, 6, 46, 44), mul(INDIGO, 0.86), 30, 0.4)
    # indigo dye dripping from a wooden dipper
    ic.circle(38, 5.5, 3.4, WOOD_L)
    ic.circle(38, 5.5, 2.3, INDIGO_D, shade=False)
    ic.line([(40.5, 3.5), (46, 0.5)], WOOD_L, 1.3)
    ic.circle(35.5, 12, 1.2, INDIGO_D, shade=False)
    ic.poly([(34.5, 11.6), (35.5, 8.8), (36.5, 11.6)], INDIGO_D, shade=False)
    ic.dot(37.2, 4.6, light, 0.6)
    ic.save("dyed_cloth")


def sailcloth():
    ic = Icon(seed=25)
    ic.shadow(24, 45, 18, 1.5)
    can = (224, 208, 170)
    can_d = (168, 146, 104)
    # a square sail bent to its yard: narrow head, wide curved foot
    top_y, foot_y = 7, 40
    left = [(11 - 7 * t / 8, top_y + (foot_y - top_y) * t / 8) for t in range(9)]
    right = [(37 + 7 * t / 8, top_y + (foot_y - top_y) * t / 8) for t in range(9)]
    foot = [(4 + 40 * t / 8, foot_y - 2.5 * math.sin(math.pi * t / 8)) for t in range(9)]
    edge = left + foot + right[::-1]
    ic.poly(edge, can, light=0.25, dark=0.3, angle=-150)
    # belly shading down the lee side
    ic.poly([(33, 8), (37, 7), (44, 40), (38, 38)], mul(can, 0.86), shade=False)
    # sewn cloths: seams fanning with the sail's cut, bowed by the wind
    for k in range(1, 7):
        t = k / 7
        xt = 11 + 26 * t
        xb = 4 + 40 * t
        yb = foot_y - 2.5 * math.sin(math.pi * t)
        ic.line([(xt, top_y + 1), ((xt + xb) / 2 + 1.2, (top_y + yb) / 2), (xb, yb)], can_d, 0.9)
    # reef band with reef points
    ic.line([(10, 13.5), (24, 14.8), (38.5, 13.5)], can_d, 1.4)
    for k in range(7):
        x = 12.5 + k * 3.9
        ic.line([(x, 14), (x - 0.3, 16.8)], HEMP_D, 0.7)
    ic.line(edge, HEMP_D, 1.0)
    ic.speckle((5, 8, 43, 39), mul(can, 0.92), 34, 0.4)
    # a patch sewn over a mended tear
    ic.rect((15, 25, 20, 30), mul(can, 0.9), light=0.1, dark=0.15)
    ic.line([(15, 25), (20, 25), (20, 30), (15, 30), (15, 25)], can_d, 0.5)
    # brass clew rings at the lower corners
    for cx, cy in ((4.4, 39.6), (43.6, 39.6)):
        ic.circle(cx, cy, 1.8, BRASS)
        ic.dot(cx, cy, mul(BRASS, 0.55), 0.6)
    # the yard, with its tie
    ic.line([(3, 6.5), (45, 6.5)], WOOD, 2.6)
    ic.line([(3, 5.7), (45, 5.7)], WOOD_L, 0.7)
    ic.line([(24, 1), (24, 6)], HEMP_D, 1.2)
    ic.save("sailcloth")


def candles():
    ic = Icon(seed=27)
    ic.shadow(24, 43, 18, 3)
    # warm glow
    for cx, cy in ((15, 11), (24, 5), (33, 13)):
        ic.circle(cx, cy, 4.2, mix(PARCH, FLAME, 0.55), shade=False)
    # three tallow candles of different heights
    for x0, y0 in ((11, 15), (20, 9), (29, 17)):
        ic.rect((x0, y0, x0 + 8, 38), TALLOW, light=0.2, dark=0.3)
        ic.ellipse((x0, y0 - 1.2, x0 + 8, y0 + 1.6), mul(TALLOW, 1.04), light=0.1, dark=0.1)
        # drips
        ic.rect((x0 + 0.6, y0, x0 + 2.2, y0 + 5), mul(TALLOW, 1.05), radius=0.8, shade=False)
        ic.rect((x0 + 5.2, y0, x0 + 6.6, y0 + 3), mul(TALLOW, 0.93), radius=0.7, shade=False)
        ic.line([(x0 + 4, y0), (x0 + 4, y0 - 2.4)], INK, 0.6)
        fx = x0 + 4
        ic.poly([(fx - 1.9, y0 - 3), (fx, y0 - 8.5), (fx + 1.9, y0 - 3), (fx, y0 - 1.6)], FLAME_O, shade=False)
        ic.poly([(fx - 0.9, y0 - 3), (fx, y0 - 6.2), (fx + 0.9, y0 - 3), (fx, y0 - 2.2)], FLAME, shade=False)
        ic.dot(fx, y0 - 3.3, CREAM, 0.5)
    # brass tray holder
    ic.ellipse((5, 36, 43, 44), BRASS, light=0.25, dark=0.3)
    ic.ellipse((8, 36.5, 40, 41), mul(BRASS, 0.82), light=0.1, dark=0.1)
    for x0 in (11, 20, 29):
        ic.rect((x0 - 0.6, 36, x0 + 8.6, 39), BRASS, radius=1)
    ic.arc((39, 34, 47, 42), 270, 90, BRASS, 1.5)
    ic.dot(9, 38.5, CREAM, 0.7)
    ic.save("candles")


def pig_iron():
    ic = Icon(seed=29)
    ic.shadow(24, 42, 21, 3)
    top_c = mix(IRON_L, WHITE, 0.25)
    front_c = mul(IRON, 0.9)

    def ingot(x, y, w=16):
        # trapezoid cast bar seen from front-top: bright top, dark sloped front
        ic.poly([(x, y + 5), (x + w, y + 5), (x + w - 1.5, y + 11), (x + 1.5, y + 11)], front_c, light=0.15, dark=0.25)
        ic.poly([(x + 2.5, y), (x + w - 2.5, y), (x + w, y + 5), (x, y + 5)], top_c, light=0.1, dark=0.15)
        ic.line([(x + 3, y + 1), (x + w - 3, y + 1)], mul(top_c, 1.12), 1.0)
        ic.line([(x + 1, y + 5.5), (x + w - 1, y + 5.5)], IRON_D, 1.0)
        # cast pits and a bit of rust bloom
        ic.speckle((x + 2, y + 6.5, x + w - 2, y + 10), IRON_D, 4, 0.5)
        ic.dot(x + w * 0.65, y + 8.5, RUST, 0.8)

    for x in (2, 16, 30):
        ingot(x, 31)
    for x in (9, 23):
        ingot(x, 21)
    ingot(16, 11)
    ic.dot(20, 12, WHITE, 0.6)
    ic.save("pig_iron", colors=44)


def provisions():
    ic = Icon(seed=31)
    ic.shadow(24, 43, 21, 3)
    # barrel behind, right
    barrel_shape(ic, 24, 7, 42, 38, wood=WOOD, bulge=1.8)
    ic.ellipse((29, 9, 37, 12), mul(WOOD, 0.9), shade=False)
    # sack, left, with a stencil
    ic.poly([(5, 20), (9, 14), (21, 14), (25, 21), (26, 37), (22, 43), (8, 43), (4, 37)], LINEN, light=0.2, dark=0.28)
    ic.poly([(9, 15), (11, 8), (19, 8), (21, 15)], mul(LINEN, 0.95), light=0.1, dark=0.2)
    ic.poly([(9, 9), (12, 5), (15, 7), (18, 5), (21, 9), (15, 8)], LINEN, light=0.15, dark=0.2)
    ic.rect((10, 10, 20, 12), HEMP, light=0.1, dark=0.2)
    ic.line([(11, 26), (19, 34)], RED_D, 1.0)
    ic.line([(19, 26), (11, 34)], RED_D, 1.0)
    # hard tack / bread loaf in front
    ic.ellipse((15, 33, 37, 44), BREAD, light=0.3, dark=0.3)
    for x in (20, 25, 30):
        ic.line([(x, 35.5), (x + 2.5, 38)], mul(BREAD, 0.7), 0.7)
    ic.dot(19, 35.5, (240, 200, 130), 0.8)
    # a cheese wedge at front right
    ic.poly([(34, 44), (44, 44), (44, 37), ], STRAW, light=0.25, dark=0.2)
    ic.poly([(34, 44), (44, 37), (41, 36)], mul(STRAW, 1.08), shade=False)
    ic.dot(41, 41.5, STRAW_D, 0.6)
    ic.save("provisions")


def tools():
    ic = Icon(seed=33)
    ic.shadow(24, 44, 18, 2.5)

    def handle(a, b, col):
        ic.line([a, b], mul(col, 0.8), 2.8)
        ic.line([a, b], col, 1.8)
        ic.line([(a[0] - 0.5, a[1] - 0.4), (b[0] - 0.5, b[1] - 0.4)], mul(col, 1.25), 0.6)

    # felling axe: handle bottom-left to top-right, bit facing out to the right
    a0, a1 = (8, 43), (35, 10)
    handle(a0, a1, WOOD_L)
    L = math.dist(a0, a1)
    u = ((a1[0] - a0[0]) / L, (a1[1] - a0[1]) / L)
    n = (-u[1], u[0])
    n = (-n[0], -n[1]) if n[0] < 0 else n       # perpendicular pointing right
    p = (a1[0] - u[0] * 2.5, a1[1] - u[1] * 2.5)
    q = lambda s, t: (p[0] + n[0] * s + u[0] * t, p[1] + n[1] * s + u[1] * t)
    ic.poly([q(-3.5, -2.3), q(-3.5, 2.3), q(3, 2.3), q(10, 5.5), q(11, 0), q(10, -5.5), q(3, -2.3)], IRON, light=0.3, dark=0.25)
    ic.line([q(9.6, 5), q(10.6, 0), q(9.6, -5)], IRON_L, 1.0)          # honed edge
    ic.poly([q(-3.5, -2.3), q(-3.5, 2.3), q(-2, 2.3), q(-2, -2.3)], IRON_D, shade=False)
    # claw hammer: handle bottom-right to top-left
    h0, h1 = (41, 43), (13, 12)
    handle(h0, h1, WOOD)
    L = math.dist(h0, h1)
    v = ((h1[0] - h0[0]) / L, (h1[1] - h0[1]) / L)
    m = (-v[1], v[0])
    p = (h1[0] - v[0] * 1.5, h1[1] - v[1] * 1.5)
    r = lambda s, t: (p[0] + m[0] * s + v[0] * t, p[1] + m[1] * s + v[1] * t)
    ic.poly([r(-4, -2.2), r(-4, 2.2), r(5, 2.2), r(5, -2.2)], IRON_D, light=0.3, dark=0.2)
    ic.poly([r(5, -3), r(5, 3), r(8, 3), r(8, -3)], IRON, light=0.3, dark=0.2)      # striking face
    ic.poly([r(-4, -2.2), r(-10, -1), r(-9, 0.8), r(-4, 1)], IRON_D, shade=False)     # claw
    ic.line([r(-2, -1.4), r(7.5, -1.4)], IRON_L, 0.6)
    # hand saw lying across the middle
    blade = [(8, 27), (35, 20), (36, 26.5), (10, 34)]
    ic.poly(blade, SILVER, light=0.3, dark=0.25)
    for k in range(10):
        t = k / 10
        x = 10 + 26 * t
        y = 34 - 7.5 * t
        ic.poly([(x, y), (x + 1.3, y + 1.5), (x + 2.6, y - 0.4)], SILVER_D, shade=False)
    ic.line([(9, 27.6), (35, 20.8)], WHITE, 0.6)
    ic.dot(29, 24, SILVER_D, 0.5)
    # open pistol-grip saw handle with brass screws
    ic.poly([(33, 19), (41, 16.5), (44.5, 19), (45, 26), (41, 28.5), (35, 28)], WOOD_L, light=0.25, dark=0.3)
    ic.poly([(38, 20.5), (42, 19.5), (42.5, 24.5), (39, 25.5)], mul(WOOD_L, 0.42), shade=False)
    ic.dot(35.3, 22, BRASS, 0.7)
    ic.dot(35.8, 25.8, BRASS, 0.7)
    ic.save("tools")


def barrels():
    ic = Icon(seed=35)
    ic.shadow(24, 44, 18, 3)
    cx, ry = barrel_shape(ic, 9, 4, 39, 44, wood=WOOD, bulge=3)
    # lid boards and bung
    ic.line([(16, 5.8), (16, 12.6)], mul(WOOD, 0.85), 0.5)
    ic.line([(24, 5.4), (24, 13.2)], mul(WOOD, 0.85), 0.5)
    ic.line([(32, 5.8), (32, 12.6)], mul(WOOD, 0.85), 0.5)
    ic.circle(24, 27, 1.5, WOOD_D, shade=False)
    ic.dot(23.5, 26.5, WOOD, 0.5)
    ic.dot(11, 20, WOOD_L, 0.8)
    ic.save("barrels")


def saddles():
    ic = Icon(seed=37)
    ic.shadow(24, 44, 20, 2.5)
    # red saddle cloth with yellow trim
    ic.poly([(5, 20), (43, 20), (41, 36), (7, 36)], BLANKET, light=0.2, dark=0.3)
    ic.line([(6.6, 34), (40.6, 34)], GOLD, 1.0)
    ic.line([(5.5, 22), (42.5, 22)], GOLD, 0.8)
    # seat: high cantle at back (left), pommel at front (right)
    seat = [(4, 10), (8, 8), (11, 14), (20, 18), (30, 17), (37, 12), (40, 9), (44, 12), (41, 20), (36, 26), (12, 26), (6, 20)]
    ic.poly(seat, LEATHER, light=0.25, dark=0.3)
    ic.line([(9, 12), (14, 16.5), (22, 19), (31, 18), (38, 12.5)], mul(LEATHER, 1.25), 0.7)
    ic.line([(8, 22), (38, 22)], LEATHER_D, 0.5)
    # fender flap
    ic.poly([(15, 22), (29, 22), (28, 37), (16, 37)], LEATHER_D, light=0.25, dark=0.25)
    for y in range(24, 37, 2):
        ic.dot(16.8, y, mul(LEATHER, 1.1), 0.35)
        ic.dot(27.2, y, mul(LEATHER, 1.1), 0.35)
    # stirrup leather and iron
    ic.line([(22, 30), (22, 38)], LEATHER_D, 1.4)
    ic.line([(18.5, 38.5), (25.5, 38.5), (26.5, 44), (17.5, 44), (18.5, 38.5)], IRON, 1.5)
    ic.line([(19, 38.2), (25, 38.2)], IRON_L, 0.5)
    ic.dot(9, 11, (220, 170, 120), 0.8)
    ic.save("saddles")


def cigars():
    ic = Icon(seed=39)
    ic.shadow(24, 42, 20, 3)
    ang = -24
    u = (math.cos(math.radians(ang)), math.sin(math.radians(ang)))
    nv = (-u[1], u[0])
    r = 2.9
    ln = 33

    def cigar(ox, oy, col, lit=False):
        a = (ox, oy)
        b = (ox + u[0] * ln, oy + u[1] * ln)
        at = lambda s, k=0: (ox + u[0] * s + nv[0] * k, oy + u[1] * s + nv[1] * k)
        ic.line([a, b], mul(col, 0.55), r * 2 + 0.8)          # dark rim keeps cigars apart
        ic.line([a, b], col, r * 2 - 0.4)
        ic.line([at(1, -r * 0.45), at(ln - 1, -r * 0.45)], mul(col, 1.22), 0.8)
        ic.line([at(1, r * 0.6), at(ln - 1, r * 0.6)], mul(col, 0.8), 0.6)
        for s in range(5, ln - 9, 5):
            ic.line([at(s, -r + 0.5), at(s + 2, r - 0.5)], mul(col, 0.8), 0.4)
        ic.poly([at(ln - 8, -r + 0.2), at(ln - 5, -r + 0.2), at(ln - 5, r - 0.2), at(ln - 8, r - 0.2)], GOLD, light=0.3, dark=0.3)
        ic.line([at(ln - 6.5, -0.6), at(ln - 6.5, 0.8)], RED, 1.0)
        if lit:
            ic.line([at(-0.5), at(2.5)], (180, 174, 166), r * 2 - 0.4)
            ic.dot(*at(-1.4), FLAME_O, 1.4)
            ic.dot(*at(-1.4), FLAME, 0.6)

    cols = [TOBACCO_D, mix(TOBACCO, TOBACCO_D, 0.35), TOBACCO, mix(TOBACCO, TOBACCO_D, 0.6)]
    for i, col in enumerate(cols):
        k = i * (r * 2 + 0.4)
        cigar(7 + nv[0] * k, 25 + nv[1] * k, col)
    # silk ribbon round the bundle
    mid = 11
    p0 = (7 + u[0] * mid - nv[0] * 3.5, 25 + u[1] * mid - nv[1] * 3.5)
    p1 = (p0[0] + nv[0] * 26, p0[1] + nv[1] * 26)
    ic.line([p0, p1], RED, 3.4)
    ic.line([(p0[0] - 1, p0[1] + 0.4), (p1[0] - 1, p1[1] + 0.4)], mul(RED, 1.3), 0.6)
    ic.poly([(p1[0], p1[1]), (p1[0] - 5, p1[1] + 4), (p1[0] - 2, p1[1] + 4.5)], RED_D, shade=False)
    ic.poly([(p1[0], p1[1]), (p1[0] + 3, p1[1] + 5), (p1[0] + 5, p1[1] + 2.5)], RED_D, shade=False)
    # a loose lit cigar laid on top
    cigar(9, 17.5, TOBACCO, lit=True)
    ic.save("cigars")


def fur_coats():
    ic = Icon(seed=41)
    ic.shadow(24, 45, 16, 2)
    coat = (112, 44, 40)
    # sleeves
    ic.poly([(13, 11), (5, 20), (4, 36), (10, 37), (12, 22)], mul(coat, 0.9), light=0.2, dark=0.3)
    ic.poly([(35, 11), (43, 20), (44, 36), (38, 37), (36, 22)], mul(coat, 0.9), light=0.2, dark=0.3)
    # body flaring to the hem
    ic.poly([(13, 9), (35, 9), (37, 24), (41, 42), (7, 42), (11, 24)], coat, light=0.22, dark=0.3)
    # dark lining showing at the open neck
    ic.poly([(17, 7), (31, 7), (24, 26)], (54, 30, 28), shade=False)
    ic.line([(24, 29), (24, 41)], mul(coat, 0.62), 0.9)
    # toggle frogs
    for y in (31, 35.5):
        ic.line([(20.5, y), (27.5, y)], (200, 170, 110), 0.9)
        ic.rect((22.8, y - 1, 25.2, y + 1), (228, 208, 160), radius=0.8, shade=False)
    ic.line([(16, 16), (13, 38)], mul(coat, 1.22), 0.8)
    ic.line([(35, 22), (37.5, 38)], mul(coat, 0.72), 0.8)

    base, hi = mul(FUR, 0.9), FUR_L

    def fur(pts, width, density=1.0):
        ic.line(pts, base, width)
        ic.line([(x - 0.3, y - 0.4) for x, y in pts], hi, width * 0.55)
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            L = math.dist((x0, y0), (x1, y1))
            cnt = int(L * 1.3 * density)
            for k in range(cnt):
                t = k / max(1, cnt)
                x = x0 + (x1 - x0) * t + ic.rnd.uniform(-width / 2.2, width / 2.2)
                y = y0 + (y1 - y0) * t + ic.rnd.uniform(-width / 2.2, width / 2.2)
                c = ic.rnd.choice((mul(FUR, 0.7), CREAM, mul(FUR_L, 1.15), FUR))
                ic.line([(x, y), (x + ic.rnd.uniform(-0.8, 0.8), y + 1.2)], c, 0.5)

    # hem, cuffs, and a big shawl collar of beaver
    fur([(8, 41.5), (40, 41.5)], 4.4)
    fur([(3.8, 35.5), (10.8, 36)], 4.4)
    fur([(37.2, 36), (44.2, 35.5)], 4.4)
    fur([(24, 28), (20, 19), (15.5, 10), (19, 5), (24, 5.5)], 5.2)
    fur([(24, 28), (28, 19), (32.5, 10), (29, 5), (24, 5.5)], 5.2)
    ic.save("fur_coats")


def silverware():
    ic = Icon(seed=43)
    ic.shadow(24, 44, 20, 2.5)
    # candlestick behind, right
    ic.rect((35, 14, 39, 38), SILVER, light=0.35, dark=0.3)
    ic.ellipse((33, 11.5, 41, 15.5), SILVER, light=0.3, dark=0.3)
    ic.ellipse((34, 24, 40, 27), SILVER_D)
    ic.ellipse((31, 38, 43, 44), SILVER, light=0.3, dark=0.35)
    ic.rect((35.5, 4, 38.5, 12.5), TALLOW, light=0.1, dark=0.2)
    ic.poly([(35.8, 3.5), (37, -0.5), (38.2, 3.5)], FLAME, shade=False)
    # teapot
    ic.arc((22, 18, 34, 34), 270, 90, SILVER_D, 2.2)    # handle
    ic.poly([(8, 32), (4, 22), (2, 19), (4, 18.5), (8, 23), (12, 27)], SILVER, light=0.3, dark=0.25)  # spout
    ic.ellipse((7, 18, 31, 42), SILVER, light=0.35, dark=0.35)
    ic.ellipse((13, 40, 25, 44), SILVER_D, light=0.2, dark=0.2)
    ic.ellipse((10, 15, 28, 21), SILVER, light=0.3, dark=0.3)
    ic.poly([(12, 18), (14, 12), (24, 12), (26, 18)], SILVER, light=0.35, dark=0.25)
    ic.circle(19, 10.5, 2.2, SILVER, light=0.3, dark=0.3)
    # engraved band and reflections
    ic.line(ell_pts(19, 30, 11.5, 2.6, 15, 165, 14), SILVER_D, 0.6)
    ic.line(ell_pts(19, 23, 11, 2, 15, 165, 14), SILVER_D, 0.5)
    ic.line([(11, 26), (11.4, 33)], WHITE, 1.1)
    ic.dot(13, 24, WHITE, 0.8)
    ic.dot(16, 13.5, WHITE, 0.6)
    ic.dot(36, 17, WHITE, 0.6)
    ic.save("silverware", colors=36)


def rum():
    ic = Icon(seed=45)
    ic.shadow(22, 44, 16, 2.5)
    # squat colonial "onion" bottle, dark green glass showing amber rum
    ic.ellipse((6, 18, 38, 45), GLASS, light=0.35, dark=0.35)
    ic.poly([(16, 21), (18, 8), (26, 8), (28, 21)], GLASS, light=0.3, dark=0.3)
    ic.rect((16.5, 6, 27.5, 9), mul(GLASS, 1.2), radius=1)
    ic.rect((18, 1, 26, 7), WOOD_L, radius=1)
    ic.line([(18, 4), (26, 4)], (160, 40, 36), 1.0)          # wax seal band
    # liquid inside, a warm amber through the glass
    ic.pie((8, 20, 36, 43), 10, 170, mix(GLASS, RUM, 0.45), shade=False)
    ic.line(ell_pts(22, 31.6, 13.5, 1.2, 190, 350, 10), mix(GLASS, RUM, 0.7), 0.5)
    # parchment label with a red band
    ic.rect((12, 28, 32, 38), CREAM, radius=1, light=0.1, dark=0.2)
    ic.rect((12, 31, 32, 34), RED, shade=False)
    ic.line([(15, 36), (29, 36)], INK_SOFT, 0.5)
    ic.line([(16, 29.8), (28, 29.8)], INK_SOFT, 0.4)
    # glints
    ic.line([(10, 25), (9.5, 30)], GLASS_L, 1.3)
    ic.dot(19.5, 11, GLASS_L, 0.7)
    ic.dot(11, 22.5, WHITE, 0.6)
    ic.save("rum")


def muskets():
    ic = Icon(seed=47)
    ic.shadow(24, 44, 18, 2)
    # Brown Bess style musket lying diagonal, butt bottom-left, bayonet top-right
    d = (0.707, -0.707)
    n = (0.707, 0.707)
    P = lambda s, o=0: (4 + d[0] * s + n[0] * o, 42 + d[1] * s + n[1] * o)
    # sling
    ic.line([P(10, 2.5), P(15, 9), P(24, 11), P(32, 7), P(34, 2)], LEATHER, 1.0)
    # stock: fat butt narrowing to fore-end
    stock = [P(0, -3.4), P(9, -2.6), P(14, -1.4), P(33, -1.2), P(33, 1.2), P(16, 1.6), P(12, 3.8), P(7, 5.0), P(0, 4.2)]
    ic.poly(stock, WOOD, light=0.25, dark=0.3)
    ic.line([P(1, -2.4), P(12, -1.4), P(32, -0.6)], WOOD_L, 0.6)
    ic.poly([P(0, -3.4), P(1.4, -3.4), P(1.4, 4.2), P(0, 4.2)], BRASS, shade=False)   # butt plate
    # barrel over the fore-end with bands
    ic.line([P(13, -1.2), P(49, -1.2)], IRON, 1.9)
    ic.line([P(13, -1.8), P(49, -1.8)], IRON_L, 0.5)
    for s in (22, 28, 33):
        ic.line([P(s, -2.4), P(s, 1.2)], BRASS, 0.9)
    # ramrod
    ic.line([P(16, 1.4), P(44, 0.4)], IRON_D, 0.6)
    # lock: plate, hammer (cock) with flint, frizzen
    ic.poly([P(11, -2.2), P(17, -2.2), P(17, 0.8), P(11, 0.8)], IRON, light=0.3, dark=0.2)
    ic.line([P(12, -2.2), P(11.5, -4.8), P(13.2, -5.4)], IRON_D, 1.0)
    ic.line([P(15.5, -2), P(15.5, -4.2)], IRON_L, 0.9)
    # trigger guard
    ic.arc((13.5, 28.5, 18.5, 33.5), 20, 200, BRASS, 0.9)
    ic.line([P(12.5, 1.5), P(13, 3.4)], IRON_D, 0.6)
    # bayonet
    ic.line([P(47, 0.4), P(48.5, 1.8)], IRON, 0.8)
    ic.poly([P(48.5, 1.8), P(49.5, 2.4), P(58, 0.8), P(49, 0.6)], SILVER, shade=False)
    ic.line([P(49, 1.4), P(57, 0.9)], WHITE, 0.4)
    ic.save("muskets")


def uniforms():
    ic = Icon(seed=49)
    ic.shadow(24, 45, 17, 2)
    blue = (44, 60, 128)
    # tails behind, buff turnbacks
    ic.poly([(12, 30), (7, 44), (15, 44), (18, 32)], blue, light=0.15, dark=0.3)
    ic.poly([(36, 30), (41, 44), (33, 44), (30, 32)], blue, light=0.15, dark=0.3)
    ic.poly([(10, 40), (8, 44), (15, 44), (15, 38)], BUFF, shade=False)
    ic.poly([(38, 40), (40, 44), (33, 44), (33, 38)], BUFF, shade=False)
    # sleeves
    ic.poly([(12, 8), (4, 14), (3, 33), (9, 34), (12, 18)], mul(blue, 0.92), light=0.2, dark=0.3)
    ic.poly([(36, 8), (44, 14), (45, 33), (39, 34), (36, 18)], mul(blue, 0.92), light=0.2, dark=0.3)
    ic.rect((2.6, 29, 9.6, 34.5), BUFF, radius=0.8, light=0.15, dark=0.2)
    ic.rect((38.4, 29, 45.4, 34.5), BUFF, radius=0.8, light=0.15, dark=0.2)
    for x in (4.5, 7):
        ic.dot(x, 31.5, GOLD, 0.55)
    for x in (41, 43.5):
        ic.dot(x, 31.5, GOLD, 0.55)
    # body
    ic.poly([(12, 7), (36, 7), (37, 32), (11, 32)], blue, light=0.22, dark=0.3)
    # white waistcoat and cravat
    ic.poly([(19, 8), (29, 8), (28, 34), (20, 34)], WHITE, light=0.1, dark=0.2)
    for y in (18, 22, 26, 30):
        ic.dot(24, y, BRASS, 0.5)
    ic.poly([(20, 6), (28, 6), (26, 12), (22, 12)], WHITE, light=0.15, dark=0.1)
    # buff lapels with buttons
    ic.poly([(15, 7), (20, 8), (20.5, 28), (16, 26)], BUFF, light=0.2, dark=0.25)
    ic.poly([(33, 7), (28, 8), (27.5, 28), (32, 26)], BUFF, light=0.2, dark=0.25)
    for y in (11, 15, 19, 23):
        ic.circle(17.4, y, 0.9, GOLD, shade=False)
        ic.circle(30.6, y, 0.9, GOLD, shade=False)
    # high collar and gold epaulette
    ic.poly([(14, 7), (19, 3), (22, 6), (17, 9)], BUFF, light=0.2, dark=0.2)
    ic.poly([(34, 7), (29, 3), (26, 6), (31, 9)], BUFF, light=0.2, dark=0.2)
    ic.ellipse((34, 6, 43, 11), GOLD, light=0.3, dark=0.3)
    for x in (35, 37, 39, 41):
        ic.line([(x, 10.5), (x + 0.3, 13.5)], GOLD_D, 0.8)
    ic.line([(14, 12), (13, 30)], mul(blue, 1.3), 0.6)
    ic.save("uniforms")


def merchant_ship():
    ic = Icon(seed=51)
    # sea
    ic.ellipse((1, 38, 47, 47), SEA, light=0.2, dark=0.3)
    # hull: sheer rising toward the high stern (left) and the bow (right)
    hull = [(4, 28), (9, 29), (40, 30), (46, 26), (42, 37), (36, 41), (12, 41), (6, 37)]
    ic.poly(hull, WOOD, light=0.25, dark=0.35)
    ic.poly([(3, 25), (10, 25), (10, 30), (4, 29)], WOOD_D, light=0.15, dark=0.2)   # stern castle
    ic.line([(6, 32.5), (42.5, 32.5)], STRAW_D, 1.2)             # painted wale
    ic.line([(8, 35.5), (40, 35.5)], WOOD_D, 0.7)
    for x in (13, 19, 25, 31, 37):
        ic.rect((x, 31.8, x + 2, 33.4), INK, shade=False)       # gunports
    ic.line([(40, 29), (47, 23)], WOOD_D, 1.0)                   # bowsprit
    ic.line([(4, 28.4), (40, 30)], WOOD_L, 0.6)

    def mast(x, top, sails):
        ic.line([(x, 30), (x, top)], WOOD_D, 1.1)
        for (y0, y1, hw) in sails:
            s = [(x - hw, y0), (x + hw, y0), (x + hw + 1, y1), (x - hw - 1, y1)]
            ic.poly(s, CANVAS, light=0.25, dark=0.3, angle=-160)
            ic.line([(x - hw, y0 + 0.3), (x + hw, y0 + 0.3)], WOOD_D, 0.8)   # yard
            ic.line([(x - hw + 1, (y0 + y1) / 2 + 0.5), (x + hw, (y0 + y1) / 2 + 0.5)], CANVAS_D, 0.4)

    mast(13, 9, [(10, 17, 5), (18, 27, 6.5)])
    mast(24, 3, [(4, 11, 5.5), (12, 19, 7), (20, 28, 8)])
    mast(35, 7, [(8, 15, 5), (16, 26, 6.5)])
    # jib
    ic.poly([(37.5, 9), (46, 23.5), (39, 23)], CANVAS, light=0.2, dark=0.25)
    # ensign
    ic.poly([(24, 3), (29, 1.5), (28, 3.3), (29, 5), (24, 4.4)], RED, shade=False)
    ic.poly([(3, 25), (0.5, 21), (3, 21)], RED, shade=False)
    # bow wave and foam
    ic.line([(3, 41), (8, 40), (14, 42)], WHITE, 0.8)
    ic.line([(36, 42), (42, 38.5), (46, 40)], WHITE, 0.9)
    ic.line([(18, 45), (26, 44.5)], SKY, 0.6)
    ic.save("merchant_ship")


def dragoons():
    ic = Icon(seed=53)
    ic.shadow(24, 45, 18, 2)
    # horse head and neck in profile, right
    head = [(25, 45), (28, 30), (31, 19), (34, 11), (38, 8.5), (41, 11), (45, 19), (47.5, 25), (47, 28.5),
            (43.5, 29.5), (40, 27.5), (37.5, 26), (38, 45)]
    ic.poly(head, HORSE, light=0.24, dark=0.3)
    ic.poly([(44, 21), (47.5, 25), (47, 28.5), (43.5, 29.5), (42, 26)], mul(HORSE, 0.7), light=0.1, dark=0.1)  # muzzle
    ic.poly([(34, 11.5), (34.5, 4.5), (38, 9)], HORSE_D, shade=False)            # ear
    ic.line([(34, 10), (31, 16), (28, 26), (26.5, 36)], INK_SOFT, 2.2)           # mane
    ic.line([(33.5, 12), (30.5, 18), (28, 28)], (100, 80, 64), 0.6)
    ic.dot(40, 15.5, INK, 0.8)
    ic.dot(39.6, 15.1, WHITE, 0.3)
    ic.dot(45.6, 25.6, INK, 0.5)
    ic.line([(40.5, 27.5), (44.5, 25)], mul(HORSE, 0.55), 0.5)                  # mouth
    ic.line([(36.5, 11), (38.5, 20), (43, 23.5)], LEATHER_D, 0.8)               # bridle
    ic.line([(38.5, 20), (45, 19.5)], LEATHER_D, 0.8)
    ic.line([(38.5, 20), (40, 26.5)], LEATHER_D, 0.8)
    ic.dot(38.5, 20, BRASS, 0.7)
    ic.line([(40, 26.5), (32, 34)], LEATHER_D, 0.7)                              # rein
    ic.line([(34.5, 21), (39, 18)], mul(HORSE, 1.22), 0.6)
    # sabre raised behind, curved
    ic.line([(8, 30), (6, 18), (7, 8), (10, 1)], SILVER, 1.8)
    ic.line([(7.2, 29), (5.4, 18), (6.4, 8), (9.3, 1.5)], WHITE, 0.4)
    ic.line([(4.5, 31), (11.5, 30.5)], BRASS, 1.3)
    # rider: green coat of a light dragoon, white crossbelt
    coat = (40, 90, 60)
    ic.poly([(8, 44), (10, 30), (15, 26), (29, 26), (33, 31), (34, 44)], coat, light=0.22, dark=0.3)
    ic.poly([(18, 26), (26, 26), (25, 33), (19, 33)], WHITE, light=0.1, dark=0.2)
    ic.line([(13, 28), (31, 43)], WHITE, 1.6)
    ic.poly([(10, 31), (8, 36), (8.5, 33), (6, 31.5)], coat, shade=False)
    ic.circle(8, 31, 2, SKIN)
    for y in (35, 38, 41):
        ic.dot(21, y, GOLD, 0.5)
    ic.ellipse((25, 25, 34, 29), BUFF, light=0.2, dark=0.2)
    # head
    ic.ellipse((15, 12, 27, 26), SKIN, light=0.2, dark=0.25)
    ic.dot(18.5, 19, INK, 0.6)
    ic.dot(23.5, 19, INK, 0.6)
    ic.line([(19.5, 22.8), (22.5, 22.8)], SKIN_D, 0.6)
    # crested leather dragoon helmet, bearskin crest, brass fittings
    ic.poly([(13.5, 16), (14, 9), (19, 5), (25, 5), (29, 9), (28.5, 16), (21, 14)], (40, 36, 34), light=0.25, dark=0.25)
    ic.line([(13.5, 15.5), (21, 13.6), (28.5, 15.5)], BRASS, 1.1)
    ic.poly([(15, 9), (17, 2), (22, 0), (29, 3), (31, 10), (27, 8), (22, 6)], INK_SOFT, light=0.25, dark=0.2)
    ic.speckle((15, 0, 31, 10), (110, 84, 64), 10, 0.45)
    ic.poly([(19, 9), (21, 6), (23, 9), (21, 12)], BRASS, light=0.3, dark=0.2)
    ic.poly([(26, 6), (28, 3.5), (29.5, 6.5), (27.5, 8)], RED, shade=False)
    ic.save("dragoons")


ALL = [lumber, charcoal, tar, flour, salt_cod, rope, leather, molasses, cured_tobacco, cloth, candles,
       pig_iron, provisions, sailcloth, tools, barrels, dyed_cloth, saddles, cigars, fur_coats, silverware,
       rum, muskets, uniforms, merchant_ship, dragoons]
NAMES = [f.__name__ for f in ALL]


if __name__ == "__main__":
    for f in ALL:
        f()
    if len(sys.argv) > 1:
        sheet(NAMES, sys.argv[1], scale=4, cols=6)
