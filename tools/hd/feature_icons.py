"""Feature icons (Ledger tab, almanac, milestones, relics, stats, colony
specializations) in the high-density style of lib.py.

Run: python tools/hd/feature_icons.py [sheet.png]
Writes assets/sprites/icons/<name>.png for every icon in ICONS and, when a
path is given, a contact sheet for review.
"""
import math
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: E402,F401,F403
from lib import SS  # noqa: E402

BRONZE = (196, 142, 70)
BRONZE_D = (118, 76, 40)
OXBLOOD = (152, 60, 44)
OXBLOOD_D = (84, 32, 28)
SMOKE = (196, 190, 184)
ROOF = (126, 70, 52)
STONE = (150, 142, 128)


# -- helpers (from ui_icons.py) --------------------------------------------
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


def punch(ic, box):
    ImageDraw.Draw(ic.img).ellipse(B(box), fill=(0, 0, 0, 0))


def rot(pts, cx, cy, a):
    c, s = math.cos(a), math.sin(a)
    return [(cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]


def thick_line(ic, pts, color, width, **kw):
    def d(dr):
        w = int(round(width * SS))
        dr.line(P(pts), fill=255, width=w, joint="curve")
        r = w / 2
        for x, y in P(pts):
            dr.ellipse([x - r, y - r, x + r, y + r], fill=255)
    shape(ic, color, d, True, **kw)


def coin(ic, cx, cy, r):
    ic.circle(cx, cy, r, GOLD, light=0.35, dark=0.4)
    ic.circle(cx, cy, r * 0.68, mul(GOLD, 0.86), shade=False)
    ic.circle(cx, cy, r * 0.6, GOLD, light=0.25, dark=0.3, angle=45)
    ic.dot(cx - r * 0.45, cy - r * 0.45, CREAM, max(0.6, r * 0.14))


def barrel(ic, x0, y0, x1, y1):
    w = x1 - x0
    ic.ellipse((x0, y0, x1, y1), WOOD, light=0.3, dark=0.4)
    ic.rect((x0 + w * 0.08, y0 + 2, x1 - w * 0.08, y1 - 2), WOOD, light=0.3, dark=0.4)
    for f in (0.3, 0.55, 0.78):
        x = x0 + w * f
        ic.line([(x, y0 + 2.5), (x, y1 - 2.5)], WOOD_D, 0.6)
    for y in (y0 + 3.5, y1 - 3.5):
        ic.rect((x0 + w * 0.02, y - 1, x1 - w * 0.02, y + 1), IRON, light=0.3, dark=0.3)
    ic.line([(x0 + w * 0.2, y0 + 5), (x0 + w * 0.2, y1 - 5)], WOOD_L, 0.8)


# -- icons -----------------------------------------------------------------
def ledger():
    """Thick leather ledger: Ledger tab."""
    ic = Icon()
    # page block visible on the right and bottom
    ic.poly([(35, 7), (41, 4), (41, 40), (35, 44)], LINEN, light=0.1, dark=0.25)
    for y in (10, 15, 20, 25, 30, 35, 40):
        ic.line([(35.8, y + 0.2), (40.3, y - 2.6)], PARCH_D, 0.5)
    ic.poly([(33, 4), (39, 1.5), (43, 2.5), (43, 39), (37, 43), (35, 42)], OXBLOOD_D, shade=False)
    ic.poly([(35, 6), (40.5, 3.5), (40.5, 39.5), (35, 42.5)], mix(LINEN, CREAM, 0.4), light=0.1, dark=0.3)
    for k in range(1, 7):
        t = k / 7
        ic.line([(35.4 + 5 * t, 6 - 2.4 * t + 0.4), (35.4 + 5 * t, 42.5 - 3 * t - 0.4)], PARCH_D, 0.45)
    # front cover
    ic.rect((5, 5, 36, 45), OXBLOOD, radius=2, light=0.28, dark=0.4)
    # spine strip with raised bands
    ic.rect((5, 5, 11, 45), OXBLOOD_D, radius=2, light=0.3, dark=0.3)
    for y in (10, 18, 26, 34, 40):
        ic.rect((5, y, 11, y + 2.2), mix(OXBLOOD, LEATHER, 0.5), light=0.35, dark=0.35)
    ic.line([(11.5, 6), (11.5, 44)], mix(OXBLOOD_D, INK, 0.4), 0.8)
    # blind-tooled border
    ic.rect((14, 8.5, 33, 41.5), mix(OXBLOOD, OXBLOOD_D, 0.5), shade=False)
    ic.rect((15, 9.5, 32, 40.5), OXBLOOD, light=0.2, dark=0.3)
    # title label
    ic.rect((16.5, 15, 30.5, 24), PARCH, light=0.15, dark=0.3)
    ic.line([(18.5, 18), (28.5, 18)], INK_SOFT, 0.9)
    ic.line([(19.5, 21), (27.5, 21)], mix(INK_SOFT, PARCH, 0.35), 0.8)
    # brass corners
    for (ax, ay), (bx, by), (cx, cy) in (((36, 5), (29, 5), (36, 12)), ((36, 45), (29, 45), (36, 38)),
                                         ((12, 5), (18, 5), (12, 11)), ((12, 45), (18, 45), (12, 39))):
        ic.poly([(ax, ay), (bx, by), (cx, cy)], BRASS, light=0.35, dark=0.35)
    ic.dot(33.8, 7.2, CREAM, 0.6)
    # ribbon bookmark hanging out of the bottom
    ic.poly([(24, 42), (28, 42), (28, 47.5), (26, 46), (24, 47.5)], RED, light=0.25, dark=0.3)
    ic.line([(24.8, 43), (24.8, 46)], mix(RED, CREAM, 0.35), 0.6)
    # sheen on the leather
    ic.line([(14, 27), (14, 38)], mix(OXBLOOD, CREAM, 0.25), 0.8)
    ic.save("ledger")


def almanac():
    """Stitched almanac booklet with a sun-and-moon disc and fast-forward mark."""
    ic = Icon()
    # back pages peeking
    ic.rect((10, 5, 41, 44), mix(PARCH_D, LINEN, 0.3), radius=1, light=0.1, dark=0.3)
    # cover
    ic.rect((7, 3, 38, 43), PARCH, radius=1, light=0.18, dark=0.3)
    ic.rect((7, 3, 11, 43), PARCH_D, light=0.2, dark=0.3)
    for y in (8, 15, 22, 29, 36):
        ic.line([(8.2, y), (10, y + 2.5)], RED_D, 0.7)
    # engraved frame
    ic.rect((13, 6, 35.5, 40), mix(PARCH, PARCH_D, 0.55), shade=False)
    ic.rect((14, 7, 34.5, 39), PARCH, light=0.1, dark=0.18)
    # title lines
    ic.line([(17, 10), (31.5, 10)], INK_SOFT, 1.0)
    ic.line([(19, 12.8), (29.5, 12.8)], mix(INK_SOFT, PARCH, 0.4), 0.7)
    # sun and moon disc: day on the left, night on the right
    cx, cy, r = 24.2, 24, 8.2
    for i in range(12):
        a = math.radians(90 + i * 15)
        ic.poly(rot([(r + 0.5, -1.2), (r + 3.6, 0), (r + 0.5, 1.2)], cx, cy, a), GOLD_D, shade=False)
    ic.circle(cx, cy, r + 1, INK_SOFT, shade=False)
    ic.pie((cx - r, cy - r, cx + r, cy + r), 90, 270, GOLD, shade=True)
    ic.pie((cx - r, cy - r, cx + r, cy + r), 270, 90, NAVY, shade=True)
    # crescent moon on the night side, stars
    ic.circle(cx + 3.6, cy + 0.2, 3.6, CREAM, shade=False)
    ic.circle(cx + 5.2, cy - 1.0, 3.2, NAVY, shade=False)
    ic.dot(cx + 3.2, cy - 5, CREAM, 0.55)
    ic.dot(cx + 6.2, cy + 4.6, CREAM, 0.5)
    # sun face hint
    ic.dot(cx - 4.2, cy - 1.5, GOLD_D, 0.6)
    ic.arc((cx - 6, cy - 1, cx - 2, cy + 3.5), 30, 150, GOLD_D, 0.6)
    ic.dot(cx - 5.5, cy - 4.5, CREAM, 0.8)
    # fast-forward chevrons: skip ahead
    for x in (15.5, 23):
        ic.poly([(x, 31.5), (x + 6.5, 35), (x, 38.5), (x + 1.5, 35)], RED, light=0.25, dark=0.3)
    ic.line([(31, 31.8), (31, 38.2)], RED, 1.6)
    ic.save("almanac")


def milestone():
    """Gold medal on a red rosette with a x2 stamp: upgrade milestone."""
    ic = Icon()
    cx, cy = 24, 19
    # ribbon tails
    ic.poly([(17, 24), (23, 26), (19, 46), (15.5, 42.5), (11.5, 45)], RED_D, light=0.25, dark=0.3)
    ic.poly([(31, 24), (25, 26), (29, 46), (32.5, 42.5), (36.5, 45)], RED, light=0.25, dark=0.35)
    ic.line([(17, 27), (14, 41)], mix(RED, CREAM, 0.3), 0.6)
    # pleated rosette
    petals = [(cx + math.cos(math.radians(i * 20)) * 17, cy + math.sin(math.radians(i * 20)) * 17) for i in range(18)]
    for i in range(18):
        a0, a1 = math.radians(i * 20 - 10), math.radians(i * 20 + 10)
        p = [(cx, cy), (cx + math.cos(a0) * 15, cy + math.sin(a0) * 15), petals[i], (cx + math.cos(a1) * 15, cy + math.sin(a1) * 15)]
        ic.poly(p, RED if i % 2 else mul(RED, 0.82), light=0.2, dark=0.3)
    ring(ic, (cx - 13.2, cy - 13.2, cx + 13.2, cy + 13.2), (cx - 11.5, cy - 11.5, cx + 11.5, cy + 11.5), RED_D, shade=False)
    # gold medal
    ic.circle(cx, cy, 11.2, GOLD, light=0.35, dark=0.45)
    ring(ic, (cx - 9, cy - 9, cx + 9, cy + 9), (cx - 8, cy - 8, cx + 8, cy + 8), GOLD_D, shade=False)
    # x2
    ink = mix(GOLD_D, INK, 0.35)
    ic.line([(16.8, 17.5), (21, 23.5)], ink, 1.4)
    ic.line([(21, 17.5), (16.8, 23.5)], ink, 1.4)
    ic.line([(23.2, 15.2), (25, 13.4), (28, 13.4), (29.4, 15.2), (29, 17.4), (23.4, 23.4), (30, 23.4)], ink, 1.5)
    ic.dot(17.5, 12.5, CREAM, 1.0)
    ic.dot(15.5, 15, CREAM, 0.6)
    ic.save("milestone")


def relic_locked():
    """Dim plinth with a question mark: relic not yet found."""
    ic = Icon()
    base = (72, 62, 56)
    hi = (98, 86, 76)
    ic.shadow(24, 44, 18, 2.5, 60)
    # vague draped relic silhouette on top
    ic.poly([(18, 17), (19.5, 14.5), (16.5, 11), (17.5, 7.5), (20.5, 5.5), (20, 3), (28, 3), (27.5, 5.5), (30.5, 7.5), (31.5, 11), (28.5, 14.5), (30, 17)],
            mul(base, 0.9), light=0.12, dark=0.15)
    ic.line([(19, 3.2), (29, 3.2)], mul(base, 0.9), 1.4)
    # capital slab
    ic.rect((11, 16, 37, 21), base, light=0.14, dark=0.2)
    ic.line([(12, 17.2), (36, 17.2)], hi, 0.7)
    # column shaft with fluting
    ic.rect((15, 21, 33, 38), base, light=0.12, dark=0.2)
    for x in (19, 24, 29):
        ic.line([(x, 22), (x, 37)], mul(base, 0.8), 0.7)
    # base steps
    ic.rect((12, 37, 36, 41), base, light=0.14, dark=0.2)
    ic.rect((9, 40.5, 39, 45), base, light=0.14, dark=0.2)
    ic.line([(10, 41.7), (38, 41.7)], hi, 0.6)
    # question mark
    q = (132, 118, 102)
    ic.line([(20.3, 25.5), (21, 23.4), (24, 22.4), (27, 23.4), (27.6, 25.8), (24.2, 28.5), (24, 31)], q, 1.9)
    ic.dot(24, 34.2, q, 1.2)
    ic.save("relic_locked", outline=(34, 28, 26))


def stats():
    """Quill over a parchment of tallies and a bar chart: statistics."""
    ic = Icon()
    # sheet with a folded corner
    ic.poly([(6, 6), (33, 6), (40, 13), (40, 43), (6, 43)], PARCH, light=0.14, dark=0.24)
    ic.poly([(33, 6), (33, 13), (40, 13)], PARCH_D, light=0.2, dark=0.2)
    # axes
    ic.line([(10, 17), (10, 39), (36, 39)], INK_SOFT, 1.0)
    # bars rising
    for x, top, col in ((12.5, 32, NAVY), (18, 27, GREEN), (23.5, 22, STRAW_D)):
        ic.rect((x, top, x + 4.2, 38.5), col, light=0.3, dark=0.35)
    ic.line([(14.6, 29.5), (20.1, 24.5), (25.6, 19.5)], RED_D, 0.8)
    # tally marks at the top
    for x in (10, 12, 14, 16):
        ic.line([(x, 9), (x - 0.4, 14)], INK_SOFT, 0.8)
    ic.line([(8.8, 13), (17.8, 9.8)], RED_D, 0.8)
    ic.line([(21, 9.5), (21, 13.5)], INK_SOFT, 0.8)
    ic.line([(23, 9.5), (23, 13.5)], INK_SOFT, 0.8)
    # ink blot at the nib
    ic.dot(30.6, 38.8, INK, 0.9)
    # quill lying across the top-right
    x0, y0, x1, y1 = 31, 38, 47, 3
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux

    def at(t, off):
        return (x0 + dx * t + nx * off, y0 + dy * t + ny * off)

    vane = [at(0.28, 0)] + [at(t, 5.2 * math.sin(math.pi * (t - 0.28) / 0.74) ** 0.8) for t in (0.38, 0.5, 0.62, 0.74, 0.86, 0.95)] + \
        [at(1.0, 0)] + [at(t, -3.6 * math.sin(math.pi * (t - 0.34) / 0.68) ** 0.8) for t in (0.92, 0.8, 0.68, 0.56, 0.44)] + [at(0.34, 0)]
    ic.poly(vane, WHITE, light=0.1, dark=0.28)
    for t in (0.5, 0.64, 0.78):
        ic.line([at(t, 0), at(t + 0.08, 4.2 * math.sin(math.pi * (t - 0.28) / 0.74))], mix(LINEN, PARCH_D, 0.5), 0.6)
    ic.line([at(0.03, 0), at(0.98, 0)], mix(CREAM, PARCH_D, 0.45), 1.1)
    ic.line([at(0.0, 0), at(0.1, 0)], INK, 1.3)
    ic.save("stats")


# -- colony specializations ------------------------------------------------
def house(ic, x0, y0, w, h, wall, roof, chimney=None):
    """Front-gabled cottage; bottom-left at (x0, y0 + h)."""
    ic.rect((x0, y0 + h * 0.4, x0 + w, y0 + h), wall, light=0.25, dark=0.35)
    ic.poly([(x0 - 1.2, y0 + h * 0.42), (x0 + w / 2, y0), (x0 + w + 1.2, y0 + h * 0.42)], roof, light=0.3, dark=0.35)
    if chimney is not None:
        ic.rect((chimney, y0 - 1, chimney + 2.6, y0 + h * 0.3), BARK, light=0.2, dark=0.3)
    dw = w * 0.26
    ic.rect((x0 + w / 2 - dw / 2, y0 + h - h * 0.34, x0 + w / 2 + dw / 2, y0 + h), WOOD_D, shade=False)
    return


def spec_boomtown():
    """Bustling town with smoking chimneys and a coin: production x2."""
    ic = Icon()
    # smoke rising
    for x, y, r in ((13, 10, 2.4), (15.5, 6, 3), (19.5, 3.5, 2.6), (31.5, 12, 2.2), (33.5, 8, 2.8), (37.5, 5, 2.3)):
        ic.circle(x, y, r, SMOKE, light=0.25, dark=0.3)
    # back house
    house(ic, 23, 14, 18, 20, LINEN, ROOF, chimney=31)
    ic.rect((34, 25, 37.5, 28.5), STRAW, shade=False)
    # front house
    house(ic, 5, 16, 18, 24, WOOD_L, mul(ROOF, 1.1), chimney=11)
    ic.rect((7.2, 27, 10.4, 30.5), STRAW, shade=False)
    ic.rect((17.4, 27, 20.6, 30.5), STRAW, shade=False)
    for y in (29, 32.5, 36):
        ic.line([(5.5, y), (22.5, y)], WOOD, 0.5)
    # ground
    ic.rect((2, 39.5, 46, 43), mix(LEAF_D, BARK, 0.35), radius=1.5, light=0.2, dark=0.3)
    # stacked coins in front
    for k in range(4):
        y = 43 - k * 2.2
        ic.ellipse((31, y - 2.2, 44, y + 2.2), GOLD if k % 2 else GOLD_D, light=0.3, dark=0.35)
    ic.ellipse((31, 33.4, 44, 37.8), GOLD, light=0.35, dark=0.3)
    ic.ellipse((34, 34.4, 41, 36.8), mul(GOLD, 0.86), shade=False)
    ic.dot(33.5, 34.8, CREAM, 0.6)
    ic.save("spec_boomtown")


def spec_market_town():
    """Merchant's balance scales."""
    ic = Icon()
    # base and post
    ic.rect((13, 40, 35, 45), WOOD, radius=1.5, light=0.3, dark=0.35)
    ic.rect((17, 37, 31, 41), WOOD_L, radius=1, light=0.3, dark=0.35)
    ic.rect((22.2, 8, 25.8, 38), BRASS, light=0.35, dark=0.35)
    ic.circle(24, 6, 3, BRASS, light=0.35, dark=0.35)
    # tilted beam (left side heavier)
    tilt = math.radians(-8)
    beam = rot([(-19, -1.3), (19, -1.3), (19, 1.3), (-19, 1.3)], 24, 10.5, -tilt)
    ic.poly(beam, BRONZE, light=0.35, dark=0.35)
    lx, ly = rot([(-18, 0)], 24, 10.5, -tilt)[0]
    rx, ry = rot([(18, 0)], 24, 10.5, -tilt)[0]
    ic.circle(24, 10.5, 2, BRONZE_D, shade=False)
    # chains and pans
    for px, py, drop in ((lx, ly, 18), (rx, ry, 14)):
        py2 = py + drop
        ic.line([(px, py), (px - 5.5, py2)], IRON_D, 0.6)
        ic.line([(px, py), (px + 5.5, py2)], IRON_D, 0.6)
        ic.pie((px - 7.5, py2 - 4, px + 7.5, py2 + 4.5), 0, 180, BRASS, shade=True)
        ic.rect((px - 7.5, py2 - 0.2, px + 7.5, py2 + 1), mix(BRASS, CREAM, 0.3), shade=False)
    # coins in the heavy pan, a small sack in the light one
    for dx, dy in ((-3, -1.2), (2.4, -1.2), (-0.3, -3.2)):
        ic.ellipse((lx + dx - 2.4, ly + 18 + dy - 1.3, lx + dx + 2.4, ly + 18 + dy + 1.3), GOLD, light=0.35, dark=0.35)
    ic.poly([(rx - 3.5, ry + 14), (rx - 3, ry + 10), (rx - 1.5, ry + 8), (rx + 1.5, ry + 8), (rx + 3, ry + 10), (rx + 3.5, ry + 14)], LINEN, light=0.2, dark=0.35)
    ic.line([(rx - 1.6, ry + 8.8), (rx + 1.6, ry + 8.8)], LEATHER_D, 0.8)
    ic.dot(22.5, 5, CREAM, 0.8)
    ic.save("spec_market_town")


def spec_frontier_fort():
    """Log palisade gate with a small flag."""
    ic = Icon()
    # flag on the gatehouse
    ic.line([(24, 2.5), (24, 14)], WOOD_D, 1.1)
    ic.poly([(24.5, 2.5), (34, 4), (32, 6), (34, 8), (24.5, 8.5)], RED, light=0.25, dark=0.3)
    ic.rect((25, 3, 28.5, 5.8), NAVY, shade=False)
    # palisade logs with sharpened tops
    xs = [4 + i * 4.3 for i in range(10)]
    for i, x in enumerate(xs):
        top = 15 if 3 <= i <= 6 else 19 + (i % 2) * 1.5
        col = WOOD if i % 2 else mul(WOOD, 0.92)
        ic.poly([(x, top + 3.5), (x + 2.15, top), (x + 4.3, top + 3.5), (x + 4.3, 44), (x, 44)], col, light=0.3, dark=0.35)
        ic.line([(x + 1.1, top + 3.5), (x + 1.1, 43)], WOOD_L, 0.6)
    # cross rail
    ic.rect((3, 23.5, 45, 25.8), WOOD_D, light=0.2, dark=0.3)
    # gate opening with doors
    ic.rect((15, 27, 33, 44), WOOD_D, radius=0, light=0.15, dark=0.3)
    ic.pie((15, 20, 33, 34), 180, 360, WOOD_D, shade=False)
    ic.rect((16.5, 28, 23.6, 44), WOOD, light=0.25, dark=0.35)
    ic.rect((24.4, 28, 31.5, 44), WOOD, light=0.25, dark=0.35)
    ic.pie((16.5, 22, 31.5, 34), 180, 270, WOOD, shade=False)
    ic.pie((16.5, 22, 31.5, 34), 270, 360, mul(WOOD, 0.94), shade=False)
    for x in (18.8, 21.2, 26.6, 29):
        ic.line([(x, 25), (x, 43.5)], WOOD_D, 0.5)
    for y in (31, 39):
        ic.rect((16.5, y, 31.5, y + 1.6), IRON, light=0.3, dark=0.3)
    ic.dot(23, 35, IRON_D, 0.7)
    ic.dot(25, 35, IRON_D, 0.7)
    ic.save("spec_frontier_fort")


def spec_post_road():
    """Wooden milepost signpost beside a road."""
    ic = Icon()
    # grass and the road winding off
    ic.poly([(2, 34), (46, 32), (46, 46), (2, 46)], mix(LEAF, PARCH_D, 0.3), light=0.15, dark=0.25)
    ic.poly([(8, 46), (22, 46), (30, 38), (38, 33), (34.5, 33), (24, 37)], mix(PARCH_D, WOOD_L, 0.35), light=0.2, dark=0.2)
    ic.line([(14, 44), (24, 39.5)], mix(PARCH_D, WOOD, 0.5), 0.6)
    for x, y in ((6, 37), (40, 38), (43, 42)):
        ic.poly([(x - 1.8, y + 1.5), (x - 0.6, y - 1.5), (x, y + 0.5), (x + 0.8, y - 2), (x + 1.8, y + 1.5)], LEAF_D, shade=False)
    # post
    ic.rect((11, 5, 15.5, 41), WOOD, light=0.3, dark=0.35)
    ic.poly([(10.8, 5), (13.25, 2), (15.7, 5)], WOOD_D, shade=False)
    ic.line([(12, 6), (12, 40)], WOOD_L, 0.7)
    # sign boards: one pointing right, one left
    ic.poly([(9, 8), (35, 8), (40, 12.5), (35, 17), (9, 17)], PINE, light=0.25, dark=0.35)
    ic.poly([(17.5, 20.5), (4, 20.5), (0.8, 24.5), (4, 28.5), (17.5, 28.5)], mul(PINE, 0.94), light=0.25, dark=0.35)
    # carved lettering
    for x0, x1, y in ((18, 31, 11), (18, 27, 14), (5, 14.5, 23.2), (6, 12, 26)):
        ic.line([(x0, y), (x1, y)], WOOD_D, 0.8)
    ic.dot(13.25, 12.5, IRON_D, 0.7)
    ic.dot(13.25, 24.5, IRON_D, 0.7)
    # mile stone at the post's foot
    ic.poly([(15.5, 42), (16, 36), (19, 34), (22, 36), (22.5, 42)], STONE, light=0.3, dark=0.35)
    ic.line([(18, 38.5), (20, 38.5)], mul(STONE, 0.6), 0.7)
    ic.save("spec_post_road")


def spec_depot():
    """A stack of crates and barrels."""
    ic = Icon()
    ic.shadow(24, 44.5, 21, 2.2, 60)
    # big crate bottom right (front-on)
    ic.rect((21, 23, 44, 45), WOOD, light=0.25, dark=0.35)
    ic.rect((23.5, 25.5, 41.5, 42.5), WOOD_L, light=0.2, dark=0.3)
    ic.poly([(23.5, 40), (38.5, 25.5), (41.5, 25.5), (41.5, 28), (26.5, 42.5), (23.5, 42.5)], WOOD, light=0.2, dark=0.3)
    for x, y in ((22.3, 24.3), (42.7, 24.3), (22.3, 43.7), (42.7, 43.7)):
        ic.dot(x, y, IRON_D, 0.6)
    # small crate on top, pale pine
    ic.rect((26, 9, 41, 23.5), PINE, light=0.25, dark=0.35)
    ic.rect((26, 9, 41, 11.2), WOOD, shade=False)
    ic.rect((26, 21.3, 41, 23.5), WOOD, shade=False)
    for x in (31, 36):
        ic.line([(x, 11.5), (x, 21)], WOOD, 0.6)
    ic.line([(29, 14.5), (32, 18)], RED_D, 1.0)
    ic.line([(32, 14.5), (29, 18)], RED_D, 1.0)
    # two standing barrels on the left, the rear one raised on the crate's shadow
    barrel(ic, 3, 6, 18, 26)
    ic.ellipse((4, 4.5, 17, 9), mul(WOOD, 0.8), light=0.2, dark=0.2)
    ic.ellipse((6, 5.5, 15, 8.3), WOOD_D, shade=False)
    barrel(ic, 6, 23, 23, 46)
    ic.ellipse((7, 21.5, 22, 26.5), mul(WOOD, 0.82), light=0.2, dark=0.2)
    ic.ellipse((9, 22.6, 20, 25.6), WOOD_D, shade=False)
    ic.dot(14.5, 24, INK_SOFT, 0.7)
    ic.save("spec_depot")


def spec_harbor():
    """Iron anchor with a length of rope."""
    ic = Icon()
    cx = 24
    # ring
    ring(ic, (cx - 5, 1.5, cx + 5, 11.5), (cx - 2.4, 4.1, cx + 2.4, 8.9), IRON, light=0.35, dark=0.35)
    # wooden stock
    ic.rect((9, 11, 39, 15.5), WOOD, radius=1.5, light=0.3, dark=0.4)
    ic.line([(10.5, 12.2), (37.5, 12.2)], WOOD_L, 0.7)
    for x in (10, 38):
        ic.rect((x - 1.2, 10.5, x + 1.2, 16), IRON_D, shade=False)
    # shank
    ic.rect((cx - 2.6, 9, cx + 2.6, 40), IRON, light=0.35, dark=0.35)
    ic.line([(cx - 1.4, 17), (cx - 1.4, 38)], SILVER_D, 0.8)
    # arms: a thick arc across the bottom
    def arms(dr):
        dr.ellipse(B((6, 14, 42, 44.5)), fill=255)
        dr.ellipse(B((10.5, 14, 37.5, 39.5)), fill=0)
        dr.rectangle(B((0, 0, 48, 30)), fill=0)
    shape(ic, IRON, arms, light=0.35, dark=0.4)
    # flukes (arrowhead tips)
    ic.poly([(3, 25.5), (11.5, 29), (10, 33.5), (6.5, 34)], IRON, light=0.35, dark=0.35)
    ic.poly([(45, 25.5), (36.5, 29), (38, 33.5), (41.5, 34)], IRON, light=0.3, dark=0.4)
    ic.poly([(cx - 3.5, 41), (cx, 46), (cx + 3.5, 41)], IRON_D, light=0.2, dark=0.3)
    ic.dot(cx - 3.3, 3.8, SILVER, 0.8)
    ic.save("spec_harbor")


def spec_entrepot():
    """Tall warehouse with a hoist beam lifting a bale."""
    ic = Icon()
    # side wall
    ic.poly([(26, 13), (42, 18), (42, 44), (26, 44)], mix(WOOD_D, BARK, 0.3), light=0.12, dark=0.3)
    for y in (22, 28, 34, 40):
        ic.line([(26.5, y), (41.5, y + 1.5)], WOOD_D, 0.5)
    # front gable
    ic.poly([(4, 18), (15, 4), (26, 18), (26, 44), (4, 44)], mix(RED, WOOD, 0.45), light=0.25, dark=0.35)
    for y in (22, 27, 32, 37):
        ic.line([(4.5, y), (25.5, y)], mul(mix(RED, WOOD, 0.45), 0.78), 0.5)
    ic.poly([(2.5, 19), (15, 3), (27.5, 19), (25.5, 19), (15, 5.8), (4.5, 19)], WOOD_D, light=0.2, dark=0.3)
    ic.poly([(26, 13), (15, 3), (27.5, 2.5), (43.5, 17.5), (42, 19)], ROOF, light=0.3, dark=0.35)
    # loft door and ground doors
    ic.rect((11, 12, 19, 20), INK_SOFT, shade=False)
    ic.rect((11.8, 12.8, 13.5, 19.5), WOOD, shade=False)
    ic.rect((10, 30, 20, 44), WOOD, light=0.25, dark=0.35)
    ic.line([(15, 30.5), (15, 43.5)], WOOD_D, 0.7)
    ic.line([(10.5, 30.5), (19.5, 43.5)], WOOD_D, 0.6)
    ic.line([(19.5, 30.5), (10.5, 43.5)], WOOD_D, 0.6)
    ic.rect((8.5, 29, 21.5, 30.5), WOOD_D, shade=False)
    # hoist beam jutting out from the gable peak, with a pulley and hanging bale
    ic.rect((12, 6, 36, 9), WOOD_L, light=0.3, dark=0.35)
    ic.rect((34, 6, 36, 9), WOOD_D, shade=False)
    ic.poly([(26, 9), (30, 9), (26, 14)], WOOD_D, shade=False)
    ic.circle(33.5, 10.6, 1.7, IRON, light=0.35, dark=0.3)
    ic.line([(33.5, 11), (33.5, 23.5)], STRAW, 0.8)
    ic.line([(33.5, 23.5), (29.8, 26.5)], STRAW, 0.6)
    ic.line([(33.5, 23.5), (37.2, 26.5)], STRAW, 0.6)
    ic.rect((29, 26, 38.5, 34), LINEN, radius=1.5, light=0.25, dark=0.35)
    ic.line([(33.7, 26.3), (33.7, 33.7)], LEATHER_D, 0.8)
    ic.line([(29.3, 30), (38.2, 30)], LEATHER_D, 0.8)
    ic.save("spec_entrepot")


ICONS = {
    "ledger": ledger, "almanac": almanac, "milestone": milestone, "relic_locked": relic_locked, "stats": stats,
    "spec_boomtown": spec_boomtown, "spec_market_town": spec_market_town, "spec_frontier_fort": spec_frontier_fort,
    "spec_post_road": spec_post_road, "spec_depot": spec_depot, "spec_harbor": spec_harbor, "spec_entrepot": spec_entrepot,
}


if __name__ == "__main__":
    for fn in ICONS.values():
        fn()
    if len(sys.argv) > 1:
        sheet(list(ICONS), sys.argv[1], scale=4, cols=6)
