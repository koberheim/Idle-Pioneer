"""High-density icons for the collectible relics of the settlements, frontier
and maritime sets.

Run: python tools/hd/relics_b.py [sheet.png]
Writes assets/sprites/icons/relic_<id>.png for every relic below and, when a
path is given, a contact sheet for review.
"""
import math
import os
import sys

from PIL import ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: E402,F401,F403
from lib import SS  # noqa: E402

# extra colours used only by this set
IVORY = (242, 232, 204)
IVORY_D = (214, 190, 138)
EBONY = (74, 46, 34)
MAPLE = (218, 150, 74)
MAPLE_D = (150, 88, 40)
BROWNED = (84, 66, 56)
BRICK = (164, 84, 58)
MORTAR = (200, 176, 140)
COQ = (226, 208, 168)
WAX = (170, 42, 36)
FLAME = (252, 204, 84)
FLAME_O = (238, 122, 40)
OIL = (150, 96, 34)
PAPER = (240, 228, 198)
CALF = (138, 82, 44)
WOOL = (240, 230, 204)
SCRATCH = (40, 32, 34)


# -- helpers ---------------------------------------------------------------
def P(pts):
    return [(x * SS, y * SS) for x, y in pts]


def B(box):
    return [box[0] * SS, box[1] * SS, box[2] * SS - 1, box[3] * SS - 1]


def shape(ic, color, draw, shade=True, **kw):
    """Paint an arbitrary mask built by draw(ImageDraw) in supersampled coords."""
    m = ic._layer()
    draw(ImageDraw.Draw(m))
    ic._paint(m, color, shade, **kw)


def ring(ic, outer, inner, color, shade=True, **kw):
    def d(dr):
        dr.ellipse(B(outer), fill=255)
        dr.ellipse(B(inner), fill=0)
    shape(ic, color, d, shade, **kw)


def thick_line(ic, pts, color, width, **kw):
    """A shaded stroke (lib.line is flat)."""
    def d(dr):
        w = int(round(width * SS))
        dr.line(P(pts), fill=255, width=w, joint="curve")
        r = w / 2
        for x, y in P(pts):
            dr.ellipse([x - r, y - r, x + r, y + r], fill=255)
    shape(ic, color, d, True, **kw)


def rp(pts, deg, cx=24.0, cy=24.0):
    """Rotate absolute points about (cx, cy)."""
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


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


def clipped_poly(ic, clip, pts, color, shade=False, **kw):
    """Fill a polygon, but only inside the mask `clip`."""
    m = ic._layer()
    ImageDraw.Draw(m).polygon(P(pts), fill=255)
    ic._paint(ImageChops.multiply(m, clip), color, shade, **kw)


def clipped_line(ic, clip, pts, color, width):
    """A flat stroke kept inside the mask `clip`."""
    m = ic._layer()
    d = ImageDraw.Draw(m)
    w = max(1, int(round(width * SS)))
    d.line(P(pts), fill=255, width=w, joint="curve")
    r = w / 2
    for x, y in P(pts):
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    ic._paint(ImageChops.multiply(m, clip), color, False)


def poly_mask(ic, pts):
    m = ic._layer()
    ImageDraw.Draw(m).polygon(P(pts), fill=255)
    return m


def punch_poly(ic, pts):
    """Cut a transparent polygon out of everything drawn so far (chips)."""
    ImageDraw.Draw(ic.img).polygon(P(pts), fill=(0, 0, 0, 0))


def glint(ic, x, y, s=2.6, col=CREAM):
    """The small four-point sparkle every relic carries."""
    ic.poly([(x, y - s), (x + 0.6, y - 0.6), (x + s, y), (x + 0.6, y + 0.6),
             (x, y + s), (x - 0.6, y + 0.6), (x - s, y), (x - 0.6, y - 0.6)], col, shade=False)
    ic.dot(x, y, WHITE, 0.55)


def words(ic, x0, x1, y, col, w=0.8, rot=None, gap=1.3, lo=2.5, hi=6.0):
    """A line of handwriting: ink dashes broken into words."""
    x = x0 + ic.rnd.uniform(0, 1)
    while x < x1 - 1:
        e = min(x1, x + ic.rnd.uniform(lo, hi))
        pts = [(x, y), (e, y)]
        ic.line(rot(pts) if rot else pts, col, w)
        x = e + gap


def squiggle(ic, x0, x1, y, col, w=0.7, amp=1.0, rot=None):
    """A signature: a quick looping scrawl."""
    pts = []
    x = x0
    k = 0
    while x <= x1:
        pts.append((x, y + (amp if k % 2 else -amp) * ic.rnd.uniform(0.5, 1.0)))
        x += ic.rnd.uniform(0.9, 1.4)
        k += 1
    pts.append((x1 + 1.2, y + 0.8))
    ic.line(rot(pts) if rot else pts, col, w)


# -- settlements ------------------------------------------------------------
def mayflower_compact():
    """Folded-in-three parchment, tilted, lines of text over rows of signatures."""
    ic = Icon(seed=101)
    ic.shadow(25, 44.5, 18, 2.5)
    A = -8
    R = lambda pts: rp(pts, A)
    panels = [
        ([(9, 3), (39, 3), (39.8, 17), (8.2, 17)], 1.0, -120),
        ([(8.2, 17), (39.8, 17), (38.8, 30.5), (9.2, 30.5)], 0.8, -60),
        ([(9.2, 30.5), (38.8, 30.5), (39.4, 44), (8.6, 44)], 0.98, -120),
    ]
    aged = mix(PARCH, (206, 170, 110), 0.25)
    for pts, k, ang in panels:
        ic.poly(R(pts), mul(aged, k), light=0.14, dark=0.2, angle=ang)
    # browned, worn edges
    edge = mix(PARCH_D, TOBACCO, 0.35)
    for pts, k, _ in panels:
        ic.line(R([pts[0], pts[3]]), mul(edge, k), 1.0)
        ic.line(R([pts[1], pts[2]]), mul(edge, k * 0.9), 1.0)
    ic.line(R([(9, 3.4), (39, 3.4)]), edge, 0.9)
    ic.line(R([(8.6, 43.6), (39.4, 43.6)]), mul(edge, 0.9), 0.9)
    # fold creases
    for y in (17, 30.5):
        ic.line(R([(8.6, y), (39.4, y)]), mul(aged, 0.62), 0.8)
        ic.line(R([(9.4, y + 0.9), (38.6, y + 0.9)]), mix(aged, CREAM, 0.5), 0.5)
    # foxing
    ic.speckle((8, 3, 40, 45), mix(PARCH_D, TOBACCO, 0.2), 14, 0.55)
    # heading, then the text of the compact
    ink = mix(INK_SOFT, aged, 0.18)
    ic.line(R([(13, 7.2), (21, 7.2)]), INK, 1.3)
    ic.line(R([(22.5, 7.2), (35, 7.2)]), INK, 1.3)
    for y in (10.6, 13.6):
        words(ic, 12, 36, y, ink, 0.75, R)
    for y in (20.2, 23.2, 26.4):
        words(ic, 12, 36, y, ink, 0.75, R)
    # forty-one signatures in two columns
    for y in (34, 37.3, 40.6):
        squiggle(ic, 12, 21, y, INK, 0.7, 1.0, R)
        squiggle(ic, 26, 34.5, y + 0.3, INK, 0.7, 1.0, R)
    # small red wax seal at the side of the text
    sx, sy = R([(35, 27)])[0]
    ic.circle(sx, sy, 3.6, WAX, light=0.35, dark=0.4)
    ic.circle(sx + 0.2, sy + 0.2, 2.0, mul(WAX, 0.78), shade=False)
    ic.dot(sx - 1.4, sy - 1.5, mix(WAX, CREAM, 0.55), 0.6)
    ic.save("relic_mayflower_compact")


def bay_psalm():
    """Small calf-bound book, blind-tooled frames, worn corners, brass clasps."""
    ic = Icon(seed=102)
    ic.shadow(25, 45, 18, 2.2)
    # back board and page block give thickness up and to the right
    ic.rect((12, 3, 41, 40), mul(CALF, 0.66), radius=1.5, light=0.1, dark=0.2)
    ic.poly([(8.5, 7), (12.5, 4), (39.5, 4), (35.5, 7)], CREAM, light=0.1, dark=0.15)
    ic.poly([(35, 7), (39.5, 4), (39.5, 39), (35, 42.5)], mul(CREAM, 0.86), light=0.1, dark=0.2)
    for k in range(1, 6):
        x = 35 + 4.5 * k / 6
        ic.line([(x, 7.5 - 3 * k / 6), (x, 42 - 3 * k / 6)], mul(CREAM, 0.72), 0.4)
    # front cover
    ic.rect((6, 7, 36, 44), CALF, radius=1.2, light=0.25, dark=0.32)
    # rounded spine joint along the left
    ic.rect((6, 7, 9.5, 44), mul(CALF, 0.78), radius=1.2, light=0.3, dark=0.3, angle=180)
    for y in (12, 19, 26.5, 34, 40):
        ic.line([(6.5, y), (9, y)], mix(CALF, PINE, 0.45), 0.8)
    # blind-tooled double frame and a gilt centre lozenge
    tool = mul(CALF, 0.66)
    for m in (2.6, 5.0):
        x0, y0, x1, y1 = 9.5 + m, 7 + m, 36 - m, 44 - m
        ic.line([(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)], tool, 0.6)
    for x, y in ((12.1, 9.6), (33.4, 9.6), (12.1, 41.4), (33.4, 41.4)):
        ic.dot(x, y, mul(CALF, 0.6), 0.8)
    cx, cy = 23, 25.5
    ic.poly([(cx, cy - 6), (cx + 4, cy), (cx, cy + 6), (cx - 4, cy)], GOLD_D, light=0.35, dark=0.3)
    ic.poly([(cx, cy - 3.6), (cx + 2.2, cy), (cx, cy + 3.6), (cx - 2.2, cy)], CALF, shade=False)
    ic.dot(cx, cy, GOLD, 0.8)
    for dy in (-8, 8):
        ic.dot(cx, cy + dy, GOLD_D, 0.6)
    # scuffed, rubbed-through corners
    worn = mix(CALF, PINE, 0.5)
    ic.poly([(36, 7), (36, 11), (32.5, 7)], worn, shade=False)
    ic.poly([(36, 44), (36, 40), (32, 44)], worn, shade=False)
    ic.poly([(9.5, 44), (9.5, 41), (12.5, 44)], mul(worn, 0.9), shade=False)
    ic.speckle((10, 8, 36, 43), mix(CALF, PINE, 0.3), 16, 0.5)
    ic.line([(10, 8), (35, 8)], mix(CALF, PINE, 0.35), 0.6)
    # brass clasps across the fore-edge
    for y in (14, 36):
        ic.rect((31.5, y - 1.5, 39.5, y + 1.5), BRASS, radius=0.6, light=0.35, dark=0.35)
        ic.dot(33, y, GOLD_D, 0.55)
        ic.line([(32, y - 1), (38.5, y - 1)], GOLD, 0.4)
    glint(ic, 39.5, 8, 2.4)
    ic.save("relic_bay_psalm")


def pine_tree_shilling():
    """Hammered silver coin, slightly out of round, with the pine tree in relief."""
    ic = Icon(seed=103)
    ic.shadow(25, 44.2, 16, 2.5)
    cx, cy = 23.5, 22.8
    pts = []
    for i in range(40):
        a = 2 * math.pi * i / 40
        r = 20 + ic.rnd.uniform(-0.4, 0.3) + 0.45 * math.sin(3 * a + 0.5)
        pts.append((cx + r * math.cos(a), cy + r * 0.98 * math.sin(a)))
    ic.poly([(x + 1.1, y + 1.9) for x, y in pts], SILVER_D, light=0.1, dark=0.3)
    ic.poly(pts, mul(SILVER, 0.92), light=0.32, dark=0.45)
    # beaded inner circle and the legend band
    dark = mul(SILVER, 0.55)
    for i in range(34):
        a = 2 * math.pi * i / 34
        ic.dot(cx + 14.8 * math.cos(a), cy + 14.8 * math.sin(a), dark, 0.55)
    for i in range(46):
        if i % 12 in (0, 11):
            continue
        a = 2 * math.pi * i / 46 - 1.3
        ic.line([(cx + 16.4 * math.cos(a), cy + 16.4 * math.sin(a)),
                 (cx + 18.2 * math.cos(a), cy + 18.2 * math.sin(a))], mul(SILVER, 0.56), 0.7)
    # the pine tree in relief: a shadow copy, then the raised tree
    tiers = [(9.8, 2.6), (13.2, 4.2), (16.8, 5.8), (20.6, 7.2), (24.6, 8.4)]

    def tree(dx, dy, col, shade):
        ic.line([(cx + dx, cy + 11 + dy), (cx + dx, cy - 10 + dy)], col, 1.8, shade=shade)
        for y, hw in tiers:
            yy = cy - 13 + y + dy
            ic.poly([(cx + dx, yy - 3.8), (cx + hw + dx, yy + 1.8), (cx + dx, yy + 0.4), (cx - hw + dx, yy + 1.8)],
                    col, shade=shade, light=0.3, dark=0.3)
        ic.poly([(cx - 5 + dx, cy + 12.4 + dy), (cx + dx, cy + 10.4 + dy), (cx + 5 + dx, cy + 12.4 + dy)],
                col, shade=shade)
    tree(1.1, 1.1, mul(SILVER, 0.36), False)
    tree(0, 0, mix(SILVER, WHITE, 0.5), True)
    for y, hw in tiers[1:]:
        yy = cy - 13 + y
        ic.line([(cx - hw + 1.2, yy + 1.2), (cx, yy - 0.3)], WHITE, 0.45)
    # age toning at the rim
    ic.speckle((cx - 20, cy - 20, cx + 20, cy + 20), (176, 164, 140), 10, 0.55)
    ic.speckle((cx - 20, cy - 20, cx + 20, cy + 20), (150, 160, 190), 6, 0.55)
    ic.arc((cx - 18.5, cy - 18.5, cx + 18.5, cy + 18.5), 190, 250, WHITE, 0.8)
    glint(ic, 39.5, 7, 2.8)
    ic.save("relic_pine_tree_shilling", colors=36)


def new_england_primer():
    """Small open book: a black woodcut on the left page, letter rows on the right."""
    ic = Icon(seed=104)
    ic.shadow(24, 44.5, 21, 2.2)
    board = (104, 66, 40)
    ic.poly([(1, 15), (23.5, 18), (24.5, 18), (47, 15), (47, 40), (24.5, 44.5), (23.5, 44.5), (1, 40)],
            board, light=0.2, dark=0.3)
    left = [(3, 12.5), (8, 10.5), (14, 10.2), (19.5, 11.2), (23.5, 13.8), (23.5, 41.5), (19.5, 39), (14, 38.2), (8, 38.4), (3, 40)]
    right = [(48 - x, y) for x, y in left]
    # page-stack edges under each page
    for pg in (left, right):
        ic.poly([(x, y + 1.6) for x, y in pg], mul(CREAM, 0.78), shade=False)
    pc = mix(CREAM, PARCH, 0.35)
    ic.poly(left, pc, light=0.12, dark=0.14, angle=-160)
    ic.poly(right, pc, light=0.12, dark=0.18, angle=-100)
    # gutter shading
    ic.poly([(20.5, 12), (23.5, 13.8), (23.5, 41.5), (20.5, 39.4)], mul(pc, 0.86), shade=False)
    ic.poly([(24.5, 13.8), (27, 12.4), (27, 39.8), (24.5, 41.5)], mul(pc, 0.9), shade=False)
    ic.line([(24, 13.5), (24, 42)], mul(pc, 0.6), 0.7)
    # left page: bordered woodcut of Adam and Eve at the tree
    ic.rect((5.5, 14, 21, 28.5), INK, shade=False)
    ic.rect((6.6, 15.1, 19.9, 27.4), mix(pc, PARCH_D, 0.3), shade=False)
    ic.line([(13.2, 27), (13.2, 20)], INK, 1.4)
    ic.ellipse((9.5, 15.6, 17, 22), INK, shade=False)
    for x, y in ((11.8, 18), (15, 17.6), (13.4, 20.2)):
        ic.dot(x, y, mix(pc, PARCH_D, 0.3), 0.6)
    for x in (8.8, 17.8):
        ic.circle(x, 20.2, 1.3, INK, shade=False)
        ic.poly([(x - 0.9, 21.4), (x + 0.9, 21.4), (x + 1.5, 26.6), (x - 1.5, 26.6)], INK, shade=False)
    ic.line([(6.6, 26.6), (19.9, 26.6)], INK, 0.8)
    for y in (31.2, 34.2):
        words(ic, 6, 20.5, y, INK_SOFT, 0.7, lo=2, hi=4.5, gap=1.1)
    # right page: a red capital A, then rows of letters
    ic.line([(28.2, 20.5), (30.8, 13.8), (33.4, 20.5)], RED, 1.3)
    ic.line([(29.4, 18.2), (32.2, 18.2)], RED, 0.9)
    rows = [(35.5, 15.2), (35.5, 18.8), (28.2, 23.2), (28.2, 26.8), (28.2, 30.4), (28.2, 34)]
    for x0, y in rows:
        x = x0
        n = 0
        while x < 43.6:
            if n % 4 == 3:
                x += 1.2
            elif n % 3 == 1:
                ic.arc((x - 0.2, y - 0.9, x + 1.4, y + 0.9), 0, 360, INK_SOFT, 0.55)
                x += 2.1
            else:
                ic.line([(x, y - 1.0), (x, y + 0.9)], INK_SOFT, 0.6)
                x += 1.9
            n += 1
    # ribbon marker hanging from the spine
    ic.poly([(23.2, 42), (25.2, 42), (26, 47.5), (24.4, 46.4), (23, 47.5)], RED, light=0.2, dark=0.2)
    ic.save("relic_new_england_primer")


def coquina_stone():
    """A cut block of pale shell-stone with a cannonball sunk into its face."""
    ic = Icon(seed=105)
    ic.shadow(24, 43.5, 21, 3)
    top = [(3, 15), (25, 8), (45, 14), (23, 21.5)]
    left = [(3, 15), (23, 21.5), (23, 44), (3, 37.5)]
    right = [(23, 21.5), (45, 14), (45, 36.5), (23, 44)]
    ic.poly(left, mul(COQ, 0.94), light=0.15, dark=0.18, angle=-150)
    ic.poly(right, mul(COQ, 0.76), light=0.12, dark=0.2, angle=-150)
    ic.poly(top, mul(COQ, 1.07), light=0.1, dark=0.12)
    # porous shell texture: pits, pale shell grit, little fan shells
    ic.speckle((3, 8, 45, 44), mul(COQ, 0.6), 70, 0.5)
    ic.speckle((3, 8, 45, 44), mul(COQ, 0.74), 40, 0.7)
    ic.speckle((3, 8, 45, 44), CREAM, 45, 0.5)
    shells = [(18, 13.5, 20, 1.0), (33, 13, -10, 1.05), (29, 30, 30, 0.8), (38, 25, 0, 0.8), (35, 36, 20, 0.75),
              (6, 20, 10, 0.9), (19, 38, -20, 0.8), (10, 24.5, 0, 0.7)]
    for x, y, a, s in shells:
        base = CREAM if y < 21 else mix(CREAM, COQ, 0.35)
        ic.pie((x - 2.6 * s, y - 2.6 * s, x + 2.6 * s, y + 2.6 * s), 200 + a, 340 + a, base, shade=False)
        for k in (-1, 0, 1):
            aa = math.radians(270 + a + 45 * k)
            ic.line([(x, y), (x + 2.2 * s * math.cos(aa), y + 2.2 * s * math.sin(aa))], mul(COQ, 0.7), 0.4)
    for x, y in ((26, 26), (40, 31), (8, 33), (14, 17.5), (37, 16.5)):
        ic.arc((x - 1.6, y - 1.2, x + 1.6, y + 1.2), 180, 360, WHITE, 0.6)
    # crisp arrises
    ic.line([(3.4, 15), (23, 21.3), (44.6, 14.2)], mix(COQ, WHITE, 0.55), 0.7)
    ic.line([(23, 21.8), (23, 43.6)], mul(COQ, 0.62), 0.6)
    # the crater and the ball that stuck in it
    ic.ellipse((6.5, 23, 20.5, 37), mul(COQ, 0.52), light=0.0, dark=-0.3, angle=-135)
    ic.arc((6.5, 23, 20.5, 37), 330, 120, mix(COQ, WHITE, 0.3), 0.8)
    for a in (200, 250, 300):
        r = math.radians(a)
        ic.line([(13.5 + 7 * math.cos(r), 30 + 7 * math.sin(r)), (13.5 + 9 * math.cos(r), 30 + 9 * math.sin(r))], mul(COQ, 0.6), 0.5)
    ic.circle(14, 30.5, 5.2, IRON_D, light=0.5, dark=0.3)
    ic.dot(12.3, 28.6, IRON, 1.2)
    ic.dot(11.9, 28.2, (170, 176, 186), 0.55)
    ic.speckle((9, 26, 19, 35), RUST, 5, 0.5)
    # chipped corners
    punch_poly(ic, [(44, 13), (46, 13), (46, 18), (43.2, 16.2)])
    punch_poly(ic, [(2, 36), (5, 37.6), (3.5, 40), (2, 40)])
    punch_poly(ic, [(22, 45), (24, 43), (26.5, 45)])
    ic.save("relic_coquina_stone", colors=40)


# -- frontier ---------------------------------------------------------------
def long_rifle():
    """Kentucky rifle on a long diagonal: striped maple, brass patchbox and fittings."""
    ic = Icon(seed=106)
    ic.shadow(24, 44.5, 20, 1.8)
    ang = math.radians(40)
    d = (math.cos(ang), -math.sin(ang))
    n = (math.sin(ang), math.cos(ang))
    ox, oy = 3.9, 39.2
    K = 1.3   # cross-section scale

    def Pt(s, o=0.0):
        o *= K
        return (ox + d[0] * s + n[0] * o, oy + d[1] * s + n[1] * o)

    top = [(0, -3.2), (5, -2.8), (12, -1.8), (16, -1.3), (22, -1.3), (51, -0.9)]
    bot = [(0, 6.4), (4, 5.6), (9, 4.3), (14, 2.4), (18, 1.6), (22, 1.3), (51, 1.0)]

    def interp(prof, s):
        for (s0, o0), (s1, o1) in zip(prof, prof[1:]):
            if s0 <= s <= s1:
                return o0 + (o1 - o0) * (s - s0) / (s1 - s0)
        return prof[-1][1]
    stock = [Pt(s, o) for s, o in top] + [Pt(s, o) for s, o in bot[::-1]]
    ic.poly(stock, MAPLE, light=0.25, dark=0.3)
    # curly maple: dark tiger stripes across the grain
    s = 1.2
    while s < 50:
        ic.line([Pt(s, interp(top, s) + 0.3), Pt(s + 0.9, interp(bot, s + 0.9) - 0.3)], MAPLE_D, 0.55)
        s += ic.rnd.uniform(1.4, 2.1)
    ic.line([Pt(1, -2.6), Pt(12, -1.3)], mix(MAPLE, CREAM, 0.45), 0.6)
    # ramrod, then the long browned octagonal barrel
    ic.line([Pt(24, 0.55), Pt(52.5, 0.45)], mix(WOOD_D, INK, 0.2), 0.6)
    ic.line([Pt(17, -1.0), Pt(55, -0.7)], BROWNED, 2.2)
    ic.line([Pt(17.5, -1.7), Pt(55, -1.4)], mix(BROWNED, SILVER, 0.5), 0.5)
    ic.dot(*Pt(54.4, -2.2), SILVER, 0.5)
    ic.dot(*Pt(30, -2.1), IRON_D, 0.45)
    # brass: crescent butt plate, toe plate, patchbox, guard, thimbles, nose cap
    ic.line([Pt(0, -3.2), Pt(0.9, -0.4), Pt(1.0, 3.2), Pt(0.2, 6.4)], BRASS, 1.6)
    ic.line([Pt(0.4, 6.1), Pt(6, 5.1)], BRASS, 1.0)
    box = [Pt(2.4, 2.3), Pt(5, 0.5), Pt(10, 0.4), Pt(12.6, 1.5), Pt(10, 2.8), Pt(5, 4.2)]
    ic.poly(box, mix(BRASS, GOLD, 0.3), light=0.45, dark=0.3)
    ic.line([Pt(5, 2.3), Pt(10.5, 1.6)], GOLD_D, 0.45)
    ic.circle(*Pt(13.8, 1.5), 1.2, BRASS, shade=False)
    ic.dot(*Pt(5.2, 1.2), CREAM, 0.5)
    ic.line([Pt(14.5, 2.0), Pt(15.2, 3.7), Pt(18, 4.0), Pt(20, 2.7), Pt(20.8, 1.5)], BRASS, 1.0)
    ic.line([Pt(17, 1.6), Pt(17.3, 3.0)], IRON_D, 0.5)
    for sx in (31, 39.5, 47):
        ic.line([Pt(sx, 0.5), Pt(sx + 1.6, 0.5)], BRASS, 1.4)
    ic.line([Pt(51.2, -0.9), Pt(51.2, 1.0)], BRASS, 1.3)
    # the flintlock
    ic.poly([Pt(17.2, -0.9), Pt(23, -0.9), Pt(23.3, 0.9), Pt(17.2, 0.9)], IRON, light=0.35, dark=0.25)
    ic.line([Pt(18, -1.0), Pt(17.4, -3.4), Pt(19.2, -4.1)], IRON_D, 0.9)
    ic.line([Pt(21.6, -1.0), Pt(22.2, -3.0)], IRON, 0.8)
    ic.line([Pt(18.4, -3.8), Pt(19.4, -3.2)], (120, 130, 140), 0.6)
    glint(ic, 7.5, 29, 2.2)
    ic.save("relic_long_rifle", colors=40)


def conestoga_wheel():
    """Big dished spoked wheel in red-painted wood with an iron tire."""
    ic = Icon(seed=107)
    ic.shadow(25, 45.5, 18, 1.8)
    cx, cy = 23.6, 23.4
    RW = mix(WOOD, RED, 0.35)
    # rim thickness seen past the front face
    ring(ic, (cx - 21.6 + 1.3, cy - 21.6 + 1.1, cx + 21.6 + 1.3, cy + 21.6 + 1.1),
         (cx - 16.5 + 1.3, cy - 16.5 + 1.1, cx + 16.5 + 1.3, cy + 16.5 + 1.1), IRON_D, shade=False)
    # tapered spokes
    for i in range(14):
        a = 2 * math.pi * (i + 0.25) / 14
        c, s = math.cos(a), math.sin(a)
        nx, ny = -s, c
        r0, r1, w0, w1 = 5.0, 17.5, 1.45, 0.95
        ic.poly([(cx + c * r0 + nx * w0, cy + s * r0 + ny * w0), (cx + c * r1 + nx * w1, cy + s * r1 + ny * w1),
                 (cx + c * r1 - nx * w1, cy + s * r1 - ny * w1), (cx + c * r0 - nx * w0, cy + s * r0 - ny * w0)],
                RW, light=0.3, dark=0.35)
        ic.line([(cx + c * 7 + nx * 0.6, cy + s * 7 + ny * 0.6), (cx + c * 15 + nx * 0.4, cy + s * 15 + ny * 0.4)],
                mix(RW, WOOD_L, 0.6) if s < 0.3 and c < 0.3 else mul(RW, 0.85), 0.4)
    # felloes and the iron tire
    ring(ic, (cx - 19.8, cy - 19.8, cx + 19.8, cy + 19.8), (cx - 16.2, cy - 16.2, cx + 16.2, cy + 16.2), RW, light=0.3, dark=0.35)
    for i in range(6):
        a = 2 * math.pi * (i + 0.5) / 6
        ic.line([(cx + 16.3 * math.cos(a), cy + 16.3 * math.sin(a)), (cx + 19.7 * math.cos(a), cy + 19.7 * math.sin(a))], mul(RW, 0.55), 0.6)
    ic.speckle((cx - 20, cy - 20, cx + 20, cy + 20), mix(WOOD, PINE, 0.3), 14, 0.45)
    ring(ic, (cx - 21.6, cy - 21.6, cx + 21.6, cy + 21.6), (cx - 19.4, cy - 19.4, cx + 19.4, cy + 19.4), IRON, light=0.4, dark=0.4)
    ic.arc((cx - 21, cy - 21, cx + 21, cy + 21), 190, 260, (176, 182, 192), 0.6)
    for i in range(12):
        a = 2 * math.pi * i / 12
        ic.dot(cx + 20.5 * math.cos(a), cy + 20.5 * math.sin(a), IRON_D, 0.5)
    # hub with iron bands and the axle hole
    ic.circle(cx, cy, 6.4, RW, light=0.35, dark=0.35)
    ring(ic, (cx - 6.4, cy - 6.4, cx + 6.4, cy + 6.4), (cx - 5.0, cy - 5.0, cx + 5.0, cy + 5.0), IRON, light=0.4, dark=0.35)
    ic.circle(cx, cy, 3.4, mix(RW, WOOD_L, 0.3), light=0.3, dark=0.3)
    ic.circle(cx + 0.3, cy + 0.3, 1.9, IRON_D, light=0.3, dark=0.2)
    ic.dot(cx + 0.6, cy + 0.6, INK, 0.8)
    ic.dot(cx - 2.2, cy - 2.2, mix(RW, CREAM, 0.5), 0.5)
    glint(ic, 40.5, 6.5, 2.4)
    ic.save("relic_conestoga_wheel")


def point_blanket():
    """Folded cream wool blanket: green, red, yellow and indigo stripes, black points."""
    ic = Icon(seed=108)
    ic.shadow(24, 44.5, 21, 2.2)
    # top of the folded stack
    ic.poly([(7, 11), (41, 10), (45, 17.5), (3, 18)], mix(WOOL, WHITE, 0.3), light=0.1, dark=0.12)
    ic.line([(9, 13.5), (40, 12.6)], mul(WOOL, 0.9), 0.5)
    # three folded layers down the front, each a soft rounded roll
    layers = [(3, 17, 45, 26.5), (2.5, 25.5, 45.5, 35), (3.2, 34, 44.8, 43)]
    masks = []
    for box in layers:
        ic.rect(box, WOOL, radius=3.6, light=0.14, dark=0.3, angle=-90)
        m = ic._layer()
        ImageDraw.Draw(m).rounded_rectangle(B(box), radius=3.6 * SS, fill=255)
        masks.append(m)
    # stripes across the middle layer, green / red / yellow / indigo
    stripes = [((56, 124, 68), 26.3), (RED, 28.3), (STRAW, 30.3), (INDIGO, 32.3)]
    for col, y in stripes:
        clipped_poly(ic, masks[1], [(0, y), (48, y), (48, y + 2), (0, y + 2)], col, True, light=0.12, dark=0.28, angle=-45)
    # and the same end-stripes peeking at the bottom layer
    for col, y in ((56, 124, 68), 36.2), (RED, 38.2):
        clipped_poly(ic, masks[2], [(30, y), (48, y), (48, y + 2), (30, y + 2)], col, True, light=0.12, dark=0.28)
    # the black 'points' woven along the edge
    for x in (6.5, 9, 11.5, 14):
        ic.line([(x, 19.6), (x, 23.4)], INK, 1.0)
    # fold creases and wool nap
    for box in layers:
        ic.line([(box[0] + 3, box[3] - 1.0), (box[2] - 3, box[3] - 1.0)], mul(WOOL, 0.72), 0.6)
        ic.line([(box[0] + 3, box[1] + 1.0), (box[2] - 3, box[1] + 1.0)], mix(WOOL, WHITE, 0.6), 0.5)
    ic.speckle((3, 10, 45, 43), mul(WOOL, 0.86), 30, 0.45)
    ic.speckle((3, 10, 45, 43), WHITE, 18, 0.45)
    # blanket-stitched edge on the right of the top layer
    for y in (19.5, 22, 24.5):
        ic.line([(42.4, y), (44.2, y)], mul(WOOL, 0.6), 0.5)
    ic.save("relic_point_blanket", colors=40)


def grasshopper_vane():
    """Gilded grasshopper weathervane over N / E direction arms on an iron rod."""
    ic = Icon(seed=109)
    ic.shadow(24, 45.5, 8, 1.4)
    # rod and base collar
    ic.line([(24, 18), (24, 44.5)], IRON_D, 1.5)
    ic.line([(23.6, 22), (23.6, 43)], IRON, 0.45)
    ic.poly([(21, 45.5), (22.6, 41), (25.4, 41), (27, 45.5)], mix(GOLD_D, RUST, 0.3), light=0.3, dark=0.3)
    # direction arms: E-W across, N-S receding in perspective
    arm = GOLD_D
    ic.line([(8, 36), (40, 36)], arm, 1.1)
    ic.line([(13.5, 31.2), (34.5, 40.8)], arm, 1.1)
    ic.circle(7.5, 36, 1.1, GOLD, shade=False)
    ic.circle(35, 41, 1.1, GOLD, shade=False)
    # N at the back end, E at the right end
    ic.line([(9.3, 31.4), (9.3, 26.4), (13.0, 31.4), (13.0, 26.4)], GOLD, 1.0)
    ic.line([(44.4, 32.6), (40.6, 32.6), (40.6, 39.2), (44.4, 39.2)], GOLD, 1.0)
    ic.line([(40.6, 35.9), (43.6, 35.9)], GOLD, 1.0)
    ic.circle(24, 36, 2.0, GOLD, light=0.4, dark=0.35)
    ic.circle(24, 24.5, 2.4, GOLD, light=0.4, dark=0.35)
    # the grasshopper, head to the left
    G, GD = GOLD, mix(GOLD_D, INK_SOFT, 0.25)
    ic.line([(25, 15.5), (24, 19.5), (26.5, 20.5)], GD, 0.9)          # far hind leg
    body = [(11.5, 11.8), (15, 10.2), (24, 10), (33, 11), (40.5, 12.4), (44, 13.8), (40.5, 15.2), (32, 15.8),
            (22, 16.2), (14.5, 15.8), (11.5, 14.4)]
    ic.poly(body, G, light=0.35, dark=0.5)
    for x in (28, 31.5, 35, 38.5):
        ic.line([(x, 13), (x - 0.4, 15.6)], GOLD_D, 0.5)
    # folded wing along the back
    ic.poly([(16, 10.4), (26, 9), (38, 11), (42, 12.8), (30, 12.6), (18, 12.4)], mix(G, CREAM, 0.25), light=0.25, dark=0.35)
    ic.line([(19, 11.6), (39, 12.2)], GOLD_D, 0.45)
    # near hind leg: fat femur rising to the knee, thin tibia folded back under it
    ic.line([(33.4, 4.6), (26.6, 16.6), (29.4, 19.4)], GD, 1.1)
    ic.poly([(17.2, 12.8), (21.2, 16.0), (34.8, 5.6), (33.2, 3.2)], G, light=0.45, dark=0.5)
    ic.line([(20.6, 15.4), (34.4, 5.2)], GOLD_D, 0.6)
    ic.line([(18.4, 12.6), (32.8, 3.8)], mix(G, WHITE, 0.5), 0.45)
    ic.circle(34, 4.4, 1.2, G, shade=False)
    # head, eye, antenna, front and middle legs
    ic.ellipse((6, 9.6, 13.6, 16.2), G, light=0.4, dark=0.45)
    ic.dot(8.8, 11.8, INK, 0.9)
    ic.dot(8.4, 11.4, CREAM, 0.35)
    ic.line([(9.6, 10), (6.4, 5.4), (2.2, 3.6)], GD, 0.7)
    ic.line([(12.8, 16), (11.4, 20)], GD, 0.9)
    ic.line([(16.5, 16.2), (17.2, 20.2)], GD, 0.9)
    ic.line([(14, 11), (26, 10.4)], mix(G, WHITE, 0.55), 0.6)
    glint(ic, 26, 4.5, 2.6)
    ic.save("relic_grasshopper_vane", colors=36)


def revere_teapot():
    """Paul Revere's drum teapot: squat silver cylinder, tapered spout, ebonised handle."""
    ic = Icon(seed=110)
    ic.shadow(23.5, 44, 17, 2.4)
    x0, x1 = 9.5, 35.5
    cxb = (x0 + x1) / 2
    # foot band
    ic.ellipse((x0 - 0.8, 34.5, x1 + 0.8, 41.5), SILVER_D, light=0.3, dark=0.3, angle=180)
    # stout tapered spout
    ic.poly([(11, 25.5), (6.2, 20.4), (5.4, 17.2), (2.8, 16.8), (3.2, 20.4), (11, 35)], SILVER, light=0.4, dark=0.4, angle=180)
    ic.line([(9.4, 26.4), (5, 20.2)], WHITE, 0.6)
    ic.ellipse((2.6, 15.8, 5.8, 18.2), SILVER_D, shade=False)
    # handle: ebonised wood C-scroll in silver sockets
    thick_line(ic, [(35, 21.5), (40.5, 20.4), (44.6, 24), (44.8, 30), (42.2, 34.4), (35, 35.2)], EBONY, 2.6, light=0.4, dark=0.3)
    ic.line([(40.2, 21.2), (43.6, 24.4)], mix(EBONY, CREAM, 0.35), 0.5)
    for y in (21.5, 35):
        ic.rect((34.4, y - 1.7, 37.8, y + 1.7), SILVER, radius=0.6, light=0.35, dark=0.35)
    # the drum
    def drum(dr):
        dr.rectangle(B((x0, 19, x1, 37)), fill=255)
        dr.ellipse(B((x0, 34, x1, 40)), fill=255)
    shape(ic, SILVER, drum, light=0.4, dark=0.55, angle=180)
    # vertical reflections
    ic.line([(13.2, 22), (13.2, 38)], mix(SILVER, WHITE, 0.85), 1.4)
    ic.line([(15.6, 22), (15.6, 38.6)], mix(SILVER, WHITE, 0.35), 0.5)
    ic.line([(30, 22), (30, 38.8)], mul(SILVER, 0.58), 1.6)
    ic.line([(33.6, 22), (33.6, 38)], mix(SILVER, WHITE, 0.25), 0.6)
    # mouldings, bright-cut swags, an engraved cartouche
    ic.line(ell_pts(cxb, 22.2, (x1 - x0) / 2, 2.6, 5, 175, 16), SILVER_D, 0.6)
    ic.line(ell_pts(cxb, 34.6, (x1 - x0) / 2, 2.6, 5, 175, 16), SILVER_D, 0.6)
    ic.line(ell_pts(cxb, 35.8, (x1 - x0) / 2, 2.6, 10, 170, 16), WHITE, 0.4)
    for k in range(4):
        xa = x0 + 1.8 + k * 5.7
        ic.arc((xa, 21.6, xa + 5.7, 26.6), 20, 160, SILVER_D, 0.5)
        ic.dot(xa, 24, SILVER_D, 0.45)
    ic.arc((18, 26.4, 27.2, 33.4), 0, 360, SILVER_D, 0.6)
    ic.line([(20.2, 31.2), (21.3, 28.2), (22.6, 30.6), (23.9, 28.2), (25, 31.2)], SILVER_D, 0.45)
    # shoulder, low domed lid and urn finial
    ic.ellipse((x0, 16, x1, 22.4), mix(SILVER, WHITE, 0.2), light=0.3, dark=0.4)
    ic.ellipse((x0 + 3, 14.2, x1 - 3, 20.4), SILVER, light=0.35, dark=0.35)
    ic.arc((x0 + 3, 14.2, x1 - 3, 20.4), 180, 360, SILVER_D, 0.45)
    ic.rect((21.3, 10, 24.1, 16.4), SILVER_D, light=0.3, dark=0.3)
    ic.ellipse((19.8, 5, 25.6, 11.8), SILVER, light=0.4, dark=0.45)
    ic.ellipse((21.2, 3.2, 24.2, 6.2), SILVER, light=0.3, dark=0.3)
    ic.dot(21.4, 7.2, WHITE, 0.6)
    glint(ic, 12.5, 24.5, 2.3, WHITE)
    ic.save("relic_revere_teapot", colors=36)


# -- maritime ---------------------------------------------------------------
def octant():
    """Hadley's octant: ebony frame, ivory arc scale, brass index arm and mirrors."""
    ic = Icon(seed=111)
    ic.shadow(24, 45.2, 18, 1.8)
    ax, ay = 24, 4.5

    def pol(r, t):
        a = math.radians(t)
        return (ax + r * math.sin(a), ay + r * math.cos(a))
    # limb (arc) in wood, faced with an ivory scale
    limb = [pol(40, t) for t in range(-27, 28, 3)] + [pol(33, t) for t in range(27, -28, -3)]
    ic.poly(limb, EBONY, light=0.3, dark=0.3)
    scale = [pol(40, t) for t in range(-25, 26, 2)] + [pol(36.8, t) for t in range(25, -26, -2)]
    ic.poly(scale, IVORY, light=0.15, dark=0.2)
    for t in range(-24, 25, 4):
        ln = 39.6 if t % 12 == 0 else 38.6
        ic.line([pol(37, t), pol(ln, t)], INK_SOFT, 0.5)
    # frame arms and the arched brace
    thick_line(ic, [pol(1, -26), pol(35, -26)], EBONY, 3.2, light=0.35, dark=0.3)
    thick_line(ic, [pol(1, 26), pol(35, 26)], EBONY, 3.2, light=0.35, dark=0.3)
    thick_line(ic, [pol(19, t) for t in range(-25, 26, 5)], EBONY, 2.2, light=0.35, dark=0.3)
    ic.line([pol(3, -25), pol(33, -25)], mix(EBONY, CREAM, 0.3), 0.45)
    # brass index arm swung a little right, with the vernier at the limb
    thick_line(ic, [pol(0, 0), pol(36, 9)], BRASS, 2.0, light=0.4, dark=0.3)
    vern = [pol(35.2, 6), pol(40.4, 6), pol(40.4, 12.5), pol(35.2, 12.5)]
    ic.poly(vern, BRASS, light=0.35, dark=0.35)
    ic.dot(*pol(34, 9.2), GOLD_D, 0.9)
    # horizon mirror and coloured shades on the left arm, sight vane on the right
    hx, hy = pol(17, -26)
    ic.rect((hx - 2.6, hy - 3, hx + 1.8, hy + 2.8), BRASS, light=0.35, dark=0.35)
    ic.rect((hx - 1.6, hy - 2, hx + 0.9, hy + 1.8), SKY, light=0.4, dark=0.2)
    ic.rect((hx + 2.4, hy - 6.4, hx + 5.2, hy - 3.6), (70, 140, 100), light=0.3, dark=0.3)
    ic.rect((hx + 2.4, hy - 3.4, hx + 5.2, hy - 0.6), (180, 70, 56), light=0.3, dark=0.3)
    sx, sy = pol(16, 26)
    ic.rect((sx - 0.6, sy - 3.8, sx + 1.8, sy + 1.2), BRASS, light=0.35, dark=0.3)
    ic.dot(sx + 0.6, sy - 2.2, INK, 0.45)
    # index mirror at the apex
    ic.circle(ax, ay + 1.4, 2.6, BRASS, light=0.4, dark=0.3)
    ic.rect((ax - 3.4, 0.6, ax + 3.4, 5.4), BRASS, light=0.35, dark=0.35)
    ic.rect((ax - 2.4, 1.4, ax + 2.4, 4.6), SKY, light=0.4, dark=0.2)
    ic.line([(ax - 1.8, 2), (ax - 0.6, 2)], WHITE, 0.5)
    glint(ic, 30.6, 2.8, 2.4)
    ic.save("relic_octant", colors=40)


def bill_of_lading():
    """A printed bill of lading: woodcut ship at the head, printed lines with
    the merchant's handwritten entries, tilted slightly."""
    ic = Icon(seed=112)
    ic.shadow(25, 44, 19, 2.5)
    A = 6
    R = lambda pts: rp(pts, A)
    paper = mix(PARCH, (214, 184, 128), 0.2)
    ic.poly(R([(6, 7), (42, 7), (42, 41), (6, 41)]), paper, light=0.16, dark=0.22)
    edge = mix(PARCH_D, TOBACCO, 0.3)
    ic.line(R([(6, 7), (42, 7)]), edge, 0.9)
    ic.line(R([(6, 41), (42, 41)]), mul(edge, 0.9), 0.9)
    ic.line(R([(6, 7), (6, 41)]), edge, 0.9)
    ic.line(R([(42, 7), (42, 41)]), mul(edge, 0.85), 0.9)
    ic.speckle((6, 7, 42, 41), mix(PARCH_D, TOBACCO, 0.2), 10, 0.5)
    # woodcut ship in the corner of the printed form
    hull = R([(9, 17), (19, 17), (17.5, 19.5), (10.5, 19.5)])
    ic.poly(hull, INK_SOFT, shade=False)
    ic.line(R([(14, 17), (14, 10)]), INK_SOFT, 0.7)
    ic.poly(R([(14.4, 10.5), (18.5, 15.8), (14.4, 15.8)]), mix(paper, INK_SOFT, 0.35), shade=False)
    ic.poly(R([(13.6, 11.5), (10, 15.8), (13.6, 15.8)]), mix(paper, INK_SOFT, 0.35), shade=False)
    ic.line(R([(8.5, 20.8), (19.5, 20.8)]), mix(paper, INK_SOFT, 0.5), 0.6)
    # printed heading and the familiar opening words
    ic.line(R([(22, 11), (39, 11)]), INK, 1.4)
    words(ic, 22, 39, 14.6, INK_SOFT, 0.7, R)
    words(ic, 22, 39, 17.6, INK_SOFT, 0.7, R)
    # printed lines with brown handwritten entries
    brown = mix(TOBACCO_D, INK, 0.3)
    for y in (24, 28, 32):
        ic.line(R([(9, y + 1.2), (39, y + 1.2)]), mix(paper, INK_SOFT, 0.45), 0.5)
        squiggle(ic, 10, 26 + (y % 7), y, brown, 0.7, 0.9, R)
    # signature and a small red wax wafer
    squiggle(ic, 22, 37, 37, INK, 0.75, 1.1, R)
    sx, sy = R([(12, 36.5)])[0]
    ic.circle(sx, sy, 3.2, WAX, light=0.35, dark=0.4)
    ic.dot(sx - 1.2, sy - 1.2, mix(WAX, CREAM, 0.55), 0.55)
    glint(ic, 38.5, 9.5)
    ic.save("relic_bill_of_lading", colors=36)


def letter_of_marque():
    """Landscape commission: engraved border, navy anchor stamp, big seal on blue ribbons."""
    ic = Icon(seed=113)
    ic.shadow(24, 45.5, 18, 2)
    ic.rect((2.5, 5, 45.5, 35), PAPER, light=0.12, dark=0.22)
    ic.line([(3, 34.5), (45, 34.5)], mul(PAPER, 0.8), 0.6)
    # engraved double border with corner rosettes
    frame = mix(INK_SOFT, PAPER, 0.15)
    for m, w in ((1.6, 0.8), (3.0, 0.45)):
        x0, y0, x1, y1 = 2.5 + m, 5 + m, 45.5 - m, 35 - m
        ic.line([(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)], frame, w)
    for x, y in ((4.8, 7.3), (43.2, 7.3), (4.8, 32.7), (43.2, 32.7)):
        ic.dot(x, y, frame, 0.9)
    # heading in bold black letters
    x = 16
    while x < 38:
        if 21.2 < x < 22.8:
            x += 1.6
            continue
        ic.line([(x, 10.2), (x, 12.4)], INK, 0.9)
        x += 1.45
    ic.line([(16, 13.7), (37.6, 13.7)], mix(INK, PAPER, 0.5), 0.4)
    # navy anchor stamp inside a ring
    acx, acy = 10.8, 21
    ic.arc((acx - 5.6, acy - 6.2, acx + 5.6, acy + 6.2), 0, 360, NAVY, 0.7)
    ic.line([(acx, acy - 3.6), (acx, acy + 4.2)], NAVY, 1.1)
    ic.arc((acx - 1.1, acy - 5.4, acx + 1.1, acy - 3.2), 0, 360, NAVY, 0.6)
    ic.line([(acx - 2.8, acy - 2.2), (acx + 2.8, acy - 2.2)], NAVY, 0.9)
    ic.arc((acx - 3.6, acy - 0.8, acx + 3.6, acy + 4.6), 20, 160, NAVY, 1.0)
    ic.poly([(acx - 4.2, acy + 1.2), (acx - 2.2, acy + 1.8), (acx - 3.8, acy + 3.2)], NAVY, shade=False)
    ic.poly([(acx + 4.2, acy + 1.2), (acx + 2.2, acy + 1.8), (acx + 3.8, acy + 3.2)], NAVY, shade=False)
    # body text and a signature
    for y in (17.2, 20.2, 23.2, 26.2):
        words(ic, 18, 41.5, y, INK_SOFT, 0.7, lo=2.5, hi=5.5, gap=1.2)
    squiggle(ic, 33, 40.5, 30.2, INK, 0.7, 1.0)
    # ribbon threaded through the sheet, tails below, the big seal
    ic.poly([(19.5, 28), (28.5, 28), (28.5, 31), (19.5, 31)], NAVY, light=0.25, dark=0.3)
    ic.line([(19.8, 29.5), (28.2, 29.5)], mix(NAVY, WHITE, 0.45), 0.5)
    ic.poly([(21.5, 36), (24.2, 37.5), (21.2, 47), (19.2, 44.6), (16.8, 46)], NAVY, light=0.25, dark=0.3)
    ic.poly([(26.5, 36), (23.8, 37.5), (26.8, 47), (28.8, 44.6), (31.2, 46)], NAVY_D, light=0.25, dark=0.3)
    ic.line([(22.2, 38.2), (20, 44.6)], mix(NAVY, WHITE, 0.45), 0.5)
    seal = []
    for i in range(22):
        a = 2 * math.pi * i / 22
        r = 7.4 + (0.7 if i % 3 == 0 else 0) + ic.rnd.uniform(-0.3, 0.3)
        seal.append((24 + r * math.cos(a), 35.2 + r * 0.95 * math.sin(a)))
    ic.poly(seal, WAX, light=0.35, dark=0.4)
    ic.circle(24.2, 35.4, 5.0, mul(WAX, 0.8), light=0.1, dark=-0.2)
    # thirteen-star ring pressed in the wax
    for i in range(13):
        a = 2 * math.pi * i / 13 - math.pi / 2
        ic.dot(24.2 + 3.6 * math.cos(a), 35.4 + 3.6 * math.sin(a), mix(WAX, CREAM, 0.45), 0.4)
    ic.dot(24.2, 35.4, mix(WAX, CREAM, 0.5), 0.9)
    ic.arc((17.5, 28.5, 30.5, 41.5), 200, 250, mix(WAX, CREAM, 0.55), 0.7)
    glint(ic, 18.5, 30, 2.2)
    ic.save("relic_letter_of_marque")


def try_pot():
    """Iron try-pot of boiling oil set in a brick furnace with a fire in its arch."""
    ic = Icon(seed=114)
    ic.shadow(24, 45.8, 22, 1.6)
    # ladle handle leaning out of the pot
    thick_line(ic, [(31, 11), (44.5, 1.8)], WOOD, 1.5, light=0.3, dark=0.3)
    # pot belly (the lower part disappears into the bricks)
    ic.ellipse((5.5, 8, 42.5, 40), IRON_D, light=0.45, dark=0.35)
    ic.arc((7.5, 10, 40.5, 38), 160, 220, IRON, 1.0)
    # brick furnace
    ic.poly([(2.5, 26), (45.5, 26), (45.5, 29), (2.5, 29)], mix(BRICK, CREAM, 0.2), light=0.2, dark=0.2)
    ic.rect((2.5, 28.5, 45.5, 46), BRICK, light=0.2, dark=0.3)
    for i, y in enumerate((29, 33, 37, 41, 45)):
        ic.line([(2.5, y), (45.5, y)], MORTAR, 0.6)
        if y < 45:
            for x in range(4 + (i % 2) * 3, 46, 6):
                ic.line([(x, y), (x, y + 4)], MORTAR, 0.6)
    ic.line([(2.5, 26.2), (45.5, 26.2)], mix(BRICK, CREAM, 0.45), 0.6)
    # brick arch round the firebox, the fire itself
    ic.ellipse((14.5, 29.5, 33.5, 46), mix(BRICK, INK, 0.25), light=0.2, dark=0.3)
    def box(dr):
        dr.ellipse(B((17.5, 32.5, 30.5, 45)), fill=255)
        dr.rectangle(B((17.5, 38.5, 30.5, 46)), fill=255)
    shape(ic, (48, 26, 20), box, shade=False)
    ic.poly([(18, 46), (19.5, 40), (21, 42.5), (23, 36), (25, 41), (27, 38), (28.8, 43), (30, 46)], FLAME_O, shade=False)
    ic.poly([(20.5, 46), (22, 42.5), (23.4, 40), (25, 43.5), (26.6, 42), (27.5, 46)], FLAME, shade=False)
    ic.dot(24, 45, WHITE, 0.7)
    for x, y in ((16.5, 38), (31.5, 38), (17.5, 33.5), (30.5, 33.5)):
        ic.dot(x, y, FLAME_O, 0.5)
    # heavy rolled rim and the pot of oil
    ic.ellipse((7, 5.5, 41, 15.5), IRON, light=0.45, dark=0.4)
    ic.ellipse((9.6, 7, 38.4, 14), OIL, light=0.35, dark=0.3, angle=-45)
    ic.arc((7, 5.5, 41, 15.5), 180, 260, (176, 182, 192), 0.8)
    ic.line([(15, 10), (21, 9)], mix(OIL, STRAW, 0.7), 0.6)
    for x, y, r in ((27, 11, 0.9), (31.5, 9.8, 0.7), (24.5, 12.3, 0.6)):
        ic.circle(x, y, r, mix(OIL, STRAW, 0.45), shade=False)
    # steam
    for pts in ([(15.5, 7.5), (13.8, 4.5), (15.6, 2), (14.4, 0.4)], [(21, 7), (22.4, 3.8), (21, 1.4)]):
        ic.line(pts, (228, 224, 216), 1.2)
    # handle hardware on the belly
    ic.line([(6.6, 20), (4.2, 21.4), (4.6, 24.2)], IRON_D, 1.1)
    ic.line([(41.4, 20), (43.8, 21.4), (43.4, 24.2)], IRON_D, 1.1)
    glint(ic, 11, 6.5, 2.2)
    ic.save("relic_try_pot", colors=40)


def atlantic_neptune():
    """Des Barres' aquatint sea chart: hatched coast, soundings, rhumb lines, compass
    rose, a curled corner and brass dividers lying across it."""
    ic = Icon(seed=115)
    ic.shadow(25, 44.5, 20, 2.2)
    paper = mix(PAPER, CREAM, 0.4)
    sheet_pts = [(3, 6), (33, 3.6), (44.8, 13), (45, 38.2), (5.6, 41.6)]
    ic.poly(sheet_pts, paper, light=0.1, dark=0.2)
    clip = poly_mask(ic, [(4, 7), (32.6, 4.8), (43.8, 13.6), (44, 37.2), (6.4, 40.4)])
    # land in the upper left, buff and hachured
    land = [(0, 0), (23, 0), (22, 6.4), (18.4, 9.4), (19.8, 13.2), (15.6, 16.4), (16.2, 20.4), (12.6, 22.8),
            (11.4, 27.4), (7.6, 31), (6.4, 36), (0, 38)]
    coast = land[1:-1]
    wash = mix(paper, SEA, 0.45)
    clipped_line(ic, clip, coast, wash, 3.0)
    clipped_poly(ic, clip, land, mix(paper, (150, 158, 100), 0.55))
    for i in range(len(coast) - 1):
        (xa, ya), (xb, yb) = coast[i], coast[i + 1]
        for k in (0.25, 0.75):
            x, y = xa + (xb - xa) * k, ya + (yb - ya) * k
            clipped_line(ic, clip, [(x - 0.6, y - 0.4), (x - 2.6, y - 1.6)], mix(INK_SOFT, paper, 0.35), 0.45)
    ic.speckle((5, 7, 20, 30), mix(INK_SOFT, paper, 0.5), 10, 0.45)
    clipped_line(ic, clip, coast, INK_SOFT, 1.0)
    ic.circle(26, 12, 1.4, mix(paper, (150, 158, 100), 0.55), shade=False)
    ic.arc((24.6, 10.6, 27.4, 13.4), 0, 360, INK_SOFT, 0.5)
    # rhumb lines from the rose
    rx, ry = 30, 26.5
    for i in range(16):
        a = 2 * math.pi * i / 16
        e = (rx + 15 * math.cos(a), ry + 15 * math.sin(a))
        m = ic._layer()
        ImageDraw.Draw(m).line(P([(rx, ry), e]), fill=255, width=max(1, int(0.45 * SS)))
        ic._paint(ImageChops.multiply(m, clip), mix(INK_SOFT, paper, 0.55), False)
    # soundings
    for x, y in ((25, 18), (34, 16), (38, 20), (22, 33), (36, 34), (15, 36), (40, 29), (27, 37), (19, 26)):
        ic.dot(x, y, INK_SOFT, 0.45)
        ic.dot(x + 1.2, y, INK_SOFT, 0.45)
    # compass rose: long N-S-E-W points over short diagonals
    ic.circle(rx, ry, 5.2, mix(paper, CREAM, 0.5), shade=False)
    ic.arc((rx - 5.2, ry - 5.2, rx + 5.2, ry + 5.2), 0, 360, INK_SOFT, 0.6)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        c, s = math.cos(a), math.sin(a)
        ic.poly([(rx + 4.6 * c, ry + 4.6 * s), (rx - 1.1 * s, ry + 1.1 * c), (rx + 1.1 * s, ry - 1.1 * c)], mix(INK_SOFT, paper, 0.3), shade=False)
    for i, col in enumerate((RED, INK_SOFT, NAVY_D, INK_SOFT)):
        a = -math.pi / 2 + i * math.pi / 2
        c, s = math.cos(a), math.sin(a)
        ic.poly([(rx + 8 * c, ry + 8 * s), (rx - 1.6 * s, ry + 1.6 * c), (rx, ry), (rx + 1.6 * s, ry - 1.6 * c)], col, shade=False)
        ic.poly([(rx + 8 * c, ry + 8 * s), (rx + 1.6 * s, ry - 1.6 * c), (rx, ry)], mix(col, WHITE, 0.4), shade=False)
    ic.dot(rx, ry, GOLD, 0.7)
    # neat line
    ic.line([(4.4, 7.6), (32, 5.4)], INK_SOFT, 0.45)
    ic.line([(43.4, 14.6), (43.6, 36.8), (6.8, 39.8), (4.4, 7.6)], INK_SOFT, 0.45)
    # curled top-right corner showing the back of the sheet
    ic.poly([(33, 3.6), (44.8, 13), (35.2, 12.2)], mul(paper, 0.8), light=0.2, dark=0.2)
    ic.line([(33.4, 4.4), (35.4, 11.8), (44, 12.9)], mul(paper, 0.62), 0.6)
    # brass dividers lying across the lower left
    hx, hy = 13.2, 30.4
    ic.line([(hx, hy), (4.6, 46)], BRASS, 1.3)
    ic.line([(hx, hy), (20.6, 46.4)], mix(BRASS, GOLD_D, 0.4), 1.3)
    ic.line([(hx - 0.4, hy + 1), (6, 43)], GOLD, 0.4)
    ic.line([(5.4, 44.4), (4.4, 46.8)], SILVER, 0.8)
    ic.line([(19.9, 44.9), (20.8, 47)], SILVER, 0.8)
    ic.circle(hx, hy, 1.9, BRASS, light=0.4, dark=0.35)
    ic.dot(hx - 0.5, hy - 0.5, CREAM, 0.5)
    glint(ic, 40.5, 20.5, 2.0)
    ic.save("relic_atlantic_neptune")


ALL = [mayflower_compact, bay_psalm, pine_tree_shilling, new_england_primer, coquina_stone,
       long_rifle, conestoga_wheel, point_blanket, grasshopper_vane, revere_teapot,
       octant, bill_of_lading, letter_of_marque, try_pot, atlantic_neptune]
NAMES = ["relic_" + f.__name__ for f in ALL]


if __name__ == "__main__":
    for f in ALL:
        f()
    if len(sys.argv) > 1:
        sheet(NAMES, sys.argv[1], scale=4, cols=5)
