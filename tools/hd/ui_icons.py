"""Interface icons (tabs, rows, toasts) in the high-density style of lib.py.

Run: python tools/hd/ui_icons.py [sheet.png]
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
GLASS = (200, 224, 226)
INKPOT = (70, 78, 100)


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


def punch(ic, box):
    """Cut a transparent ellipse out of everything drawn so far."""
    ImageDraw.Draw(ic.img).ellipse(B(box), fill=(0, 0, 0, 0))


def rot(pts, cx, cy, a):
    c, s = math.cos(a), math.sin(a)
    return [(cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]


def thick_line(ic, pts, color, width, **kw):
    """A shaded stroke (lib.line is flat)."""
    def d(dr):
        w = int(round(width * SS))
        dr.line(P(pts), fill=255, width=w, joint="curve")
        r = w / 2
        for x, y in P(pts):
            dr.ellipse([x - r, y - r, x + r, y + r], fill=255)
    shape(ic, color, d, True, **kw)


# -- icons -----------------------------------------------------------------
def gear():
    ic = Icon()
    cx, cy = 24, 24
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        tooth = [(13, -5), (22, -3.4), (22, 3.4), (13, 5)]
        ic.poly(rot(tooth, cx, cy, a), BRASS, light=0.3, dark=0.35)
    ic.circle(cx, cy, 16, BRASS, light=0.28, dark=0.35)
    ic.circle(cx, cy, 12, mul(BRASS, 0.72), shade=False)
    ic.circle(cx, cy, 11, BRASS, light=0.1, dark=0.3, angle=45)
    # four spokes between rim and hub
    for i in range(4):
        a = math.radians(i * 90 + 45)
        ic.poly(rot([(4, -2), (11.5, -2.3), (11.5, 2.3), (4, 2)], cx, cy, a), mul(BRASS, 0.95), light=0.25, dark=0.2)
    ic.circle(cx, cy, 6.5, IRON, light=0.35, dark=0.3)
    ic.circle(cx, cy, 4, IRON_D, shade=False)
    punch(ic, (cx - 2.6, cy - 2.6, cx + 2.6, cy + 2.6))
    for i in range(4):
        a = math.radians(i * 90)
        ic.dot(cx + math.cos(a) * 14.2, cy + math.sin(a) * 14.2, GOLD_D, 0.9)
    ic.dot(15, 13, CREAM, 1.1)
    ic.dot(13, 16.5, CREAM, 0.6)
    ic.save("gear")


def hammer():
    ic = Icon()
    s = math.sqrt(0.5)
    V = (s, -s)   # along the handle, toward the head
    U = (s, s)    # along the head
    H = (30.5, 17.5)

    def at(u, v):
        u *= 1.0
        return (H[0] + u * U[0] + v * V[0], H[1] + u * U[1] + v * V[1])

    # handle
    ic.line([at(0, 0), at(0, -34)], WOOD, 5.0, shade=True)
    ic.line([at(-1.2, -2), at(-1.2, -31)], WOOD_L, 0.9)
    # leather grip
    ic.poly([at(-2.8, -24), at(2.8, -24), at(2.8, -34.5), at(-2.8, -34.5)], mix(LEATHER, INK_SOFT, 0.35), light=0.2, dark=0.3)
    for t in (-26.5, -29.5, -32.5):
        ic.line([at(-2.4, t), at(2.4, t + 1)], LEATHER_D, 0.8)
    # head: flat face (up-left) and tapered peen (down-right)
    head = [at(-13, -6.5), at(-7, -6.5), at(-3.5, -5.2), at(3.5, -5.2), at(10, -4.4), at(13.5, -2.4),
            at(14.5, 0), at(13.5, 2.4), at(10, 4.4), at(3.5, 5.2), at(-3.5, 5.2), at(-7, 6.5), at(-13, 6.5)]
    ic.poly(head, IRON, light=0.35, dark=0.35)
    ic.poly([at(-15, -6.5), at(-12, -6.5), at(-12, 6.5), at(-15, 6.5)], SILVER_D, light=0.4, dark=0.2)
    ic.poly([at(-3.5, -5.2), at(3.5, -5.2), at(3.5, 5.2), at(-3.5, 5.2)], IRON_D, light=0.3, dark=0.2)
    ic.line([at(-12, -5.2), at(-7, -5.2)], SILVER, 0.9)
    ic.line([at(4, -4), at(10, -3.3)], SILVER, 0.9)
    ic.dot(*at(0, 0), WOOD_L, 1.0)
    ic.save("hammer")


def hourglass():
    ic = Icon()
    # glass bulbs
    glass = [(15, 10), (14.5, 14), (16.5, 19), (21.5, 23), (22.8, 24.5), (21.5, 26), (16.5, 30), (14.5, 35), (15, 39),
             (33, 39), (33.5, 35), (31.5, 30), (26.5, 26), (25.2, 24.5), (26.5, 23), (31.5, 19), (33.5, 14), (33, 10)]
    ic.poly(glass, GLASS, light=0.15, dark=0.15)
    # sand: what's left above, the pile below, the falling stream
    ic.poly([(17, 17), (31, 17), (29, 20), (25, 23.4), (23, 23.4), (19, 20)], STRAW, light=0.2, dark=0.2)
    ic.poly([(15.2, 38.5), (32.8, 38.5), (31.5, 33.5), (27, 30.5), (24, 29.5), (21, 30.5), (16.5, 33.5)], STRAW, light=0.25, dark=0.3)
    ic.line([(24, 23.5), (24, 30)], STRAW_D, 0.9)
    ic.line([(17, 12), (16.8, 16)], WHITE, 1.0)
    ic.line([(17.4, 33), (16.6, 36)], WHITE, 0.8)
    # turned wooden posts
    for x in (11.5, 36.5):
        ic.rect((x - 1.6, 9, x + 1.6, 40), WOOD, light=0.3, dark=0.3)
        for y in (15, 24.5, 34):
            ic.ellipse((x - 2.6, y - 1.6, x + 2.6, y + 1.6), WOOD_L, light=0.3, dark=0.35)
    # caps
    for y0 in (4, 38):
        ic.rect((7, y0, 41, y0 + 6), WOOD, radius=2, light=0.3, dark=0.35)
        ic.line([(9, y0 + 1.5), (39, y0 + 1.5)], WOOD_L, 0.9)
        ic.line([(9, y0 + 4.8), (39, y0 + 4.8)], WOOD_D, 0.8)
    ic.save("hourglass")


def liberty():
    ic = Icon()
    # yoke
    ic.rect((7, 3, 41, 9), WOOD_D, radius=2, light=0.3, dark=0.35)
    ic.line([(9, 4.6), (39, 4.6)], WOOD, 0.9)
    ic.rect((19.5, 6, 28.5, 12), IRON, light=0.3, dark=0.3)
    # bell
    ic.ellipse((15.5, 9.5, 32.5, 21), BRONZE, light=0.3, dark=0.3)
    body = [(16, 15), (14.5, 21), (13, 27), (11.5, 33), (8, 37.5), (6, 40), (42, 40), (40, 37.5), (36.5, 33), (35, 27), (33.5, 21), (32, 15)]
    ic.poly(body, BRONZE, light=0.3, dark=0.4)
    ic.rect((5, 37.5, 43, 43), BRONZE, radius=2, light=0.3, dark=0.4)
    ic.line([(6.5, 39), (41.5, 39)], mul(BRONZE, 1.18), 0.8)
    # inscription bands
    ic.line([(15, 17.5), (33, 17.5)], BRONZE_D, 0.8)
    ic.line([(14.5, 21.5), (33.5, 21.5)], BRONZE_D, 0.8)
    for x in (17, 20, 23, 26, 29, 31.5):
        ic.dot(x, 19.5, BRONZE_D, 0.5)
    # the crack
    ic.line([(22.5, 43), (23.8, 38.5), (22.3, 35), (24, 31), (22.8, 27.5), (23.8, 24.5)], INK, 1.3)
    ic.line([(25, 38.5), (26.2, 35)], mix(BRONZE, CREAM, 0.4), 0.7)
    # shine
    ic.line([(17.8, 14), (16.8, 24), (15.5, 31)], mix(BRONZE, CREAM, 0.55), 1.2)
    ic.dot(19, 12.5, CREAM, 0.9)
    ic.save("liberty")


def lock():
    ic = Icon()
    # shackle
    def shackle(dr):
        w = int(4.8 * SS)
        dr.arc(P([(12.5, 3), (35.5, 26)])[0] + P([(35.5, 26)])[0], 180, 360, fill=255, width=w)
        dr.rectangle(B((12.5, 14, 12.5 + 4.8, 24)), fill=255)
        dr.rectangle(B((35.5 - 4.8, 14, 35.5, 24)), fill=255)
    shape(ic, IRON, shackle, light=0.35, dark=0.3)
    ic.arc((14, 4.5, 30, 22), 200, 260, SILVER, 0.9)
    # body
    ic.rect((8, 20, 40, 44), IRON, radius=3, light=0.3, dark=0.4)
    ic.rect((8, 20, 40, 23.5), IRON_D, radius=2, shade=False)
    ic.line([(10, 25), (10, 41)], SILVER_D, 0.9)
    for x, y in ((11.5, 27), (36.5, 27), (11.5, 40.5), (36.5, 40.5)):
        ic.dot(x, y, SILVER, 0.9)
    # brass escutcheon and keyhole
    ic.ellipse((18, 25.5, 30, 40.5), BRASS, light=0.3, dark=0.35)
    ic.circle(24, 30.5, 2.3, INK, shade=False)
    ic.poly([(23, 31), (25, 31), (26.2, 37), (21.8, 37)], INK, shade=False)
    ic.dot(20.5, 28, CREAM, 0.7)
    ic.save("lock")


def map_icon():
    ic = Icon()
    # the unrolled sheet
    ic.poly([(8, 9), (40, 11), (40, 40), (8, 38)], PARCH, light=0.12, dark=0.2)
    # sea wash and land
    ic.poly([(9, 10), (39.5, 12), (39.5, 39), (9, 37)], mix(PARCH, SKY, 0.35), light=0.1, dark=0.15)
    land = [(9, 10), (22, 10.8), (24, 14), (21.5, 18), (23.5, 22), (26, 24), (23, 28), (24.5, 33), (21, 37.6), (9, 37)]
    ic.poly(land, mix(PARCH, LEAF, 0.45), light=0.12, dark=0.15)
    ic.line(land[:-1], mix(INK_SOFT, LEAF_D, 0.3), 0.9)
    ic.poly([(12, 16), (17, 14), (19, 18), (15, 22), (12, 20)], mix(PARCH, LEAF_D, 0.55), light=0.1, dark=0.1)
    for x, y in ((13, 28), (17, 31), (14, 33.5)):
        ic.poly([(x - 1.8, y + 1.5), (x, y - 1.5), (x + 1.8, y + 1.5)], mix(INK_SOFT, LEAF_D, 0.2), shade=False)
    # dotted route and destination
    for x, y in ((27, 20), (29.5, 18), (32, 17), (34.5, 17.5)):
        ic.dot(x, y, RED, 0.7)
    ic.line([(34.5, 14.5), (37.5, 17.5)], RED_D, 1.0)
    ic.line([(37.5, 14.5), (34.5, 17.5)], RED_D, 1.0)
    # compass rose
    cx, cy = 32.5, 31
    ic.circle(cx, cy, 4.8, mix(PARCH, CREAM, 0.5), shade=False)
    ic.arc((cx - 4.8, cy - 4.8, cx + 4.8, cy + 4.8), 0, 360, INK_SOFT, 0.7)
    ic.poly([(cx, cy - 6.5), (cx + 1.3, cy), (cx - 1.3, cy)], RED, shade=False)
    ic.poly([(cx, cy + 6.5), (cx + 1.3, cy), (cx - 1.3, cy)], NAVY_D, shade=False)
    ic.poly([(cx - 5.5, cy), (cx, cy - 1.1), (cx, cy + 1.1)], INK_SOFT, shade=False)
    ic.poly([(cx + 5.5, cy), (cx, cy - 1.1), (cx, cy + 1.1)], INK_SOFT, shade=False)
    # rolled ends
    for x0, y0 in ((3, 7), (39, 9)):
        ic.rect((x0, y0, x0 + 6.5, y0 + 32), PARCH_D, radius=3, light=0.3, dark=0.35, angle=180)
        ic.line([(x0 + 1.8, y0 + 2), (x0 + 1.8, y0 + 30)], PARCH, 1.0)
        ic.ellipse((x0 + 1, y0 - 0.5, x0 + 5.5, y0 + 2.5), mul(PARCH_D, 0.75), shade=False)
    ic.save("map")


def pick():
    """Sickle over a sheaf of wheat: Production upgrades."""
    ic = Icon()
    # a small sheaf of wheat, gathered in the sickle's hook
    heads = ((8.5, 19), (14, 15.5), (19.5, 18.5))
    for x, y in heads:
        ic.line([(x, y + 3), (x * 0.3 + 10, 44)], STRAW_D, 1.2)
    for x, y in heads:
        a = (x - 14) / 26.0
        for k in range(4):
            yy = y - 4 + k * 2.4
            xx = x + a * (yy - y)
            ic.ellipse((xx - 2, yy - 1.5, xx + 2, yy + 1.5), STRAW, light=0.3, dark=0.35)
        ic.line([(x + a * -5, y - 5), (x + a * -9, y - 9)], STRAW_D, 0.6)
    ic.rect((11.5, 34, 16.5, 36.5), RED, light=0.2, dark=0.3)
    # sickle blade: a crescent opening down-left
    def blade(dr):
        dr.ellipse(B((9, 4, 37, 32)), fill=255)
        dr.ellipse(B((5.5, 9.5, 33, 37)), fill=0)
    shape(ic, SILVER, blade, light=0.3, dark=0.45)
    def edge(dr):
        dr.ellipse(B((9, 4, 37, 32)), fill=255)
        dr.ellipse(B((10.2, 5.2, 35.8, 30.8)), fill=0)
        dr.ellipse(B((5.5, 9.5, 33, 37)), fill=0)
    shape(ic, WHITE, edge, shade=False)
    # tang joining blade to handle
    ic.poly([(29.5, 23.5), (35.8, 25), (35.8, 31.5), (31.8, 31.5)], SILVER_D, light=0.3, dark=0.3)
    # handle
    ic.rect((31.5, 30.5, 36, 33.5), IRON, light=0.3, dark=0.3)
    ic.line([(34, 33), (34.5, 44)], WOOD, 4.4, shade=True)
    ic.line([(33.2, 35), (33.5, 43)], WOOD_L, 0.8)
    ic.save("pick")


def quill():
    ic = Icon()
    # inkwell
    ic.ellipse((20, 32, 44, 45), INKPOT, light=0.35, dark=0.35)
    ic.rect((22, 34, 42, 40), INKPOT, light=0.35, dark=0.35)
    ic.ellipse((20, 29, 44, 38), INKPOT, light=0.4, dark=0.3)
    ic.rect((26, 26, 38, 32), SILVER_D, light=0.4, dark=0.35)
    ic.ellipse((25, 24, 39, 29), SILVER, light=0.3, dark=0.3)
    ic.ellipse((27.5, 25, 36.5, 28), INK, shade=False)
    ic.line([(23, 34), (22.5, 39)], mix(INKPOT, SKY, 0.5), 1.0)
    # quill feather rising from the ink
    x0, y0, x1, y1 = 32, 26.5, 5, 1.5
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux

    def at(t, off):
        return (x0 + dx * t + nx * off, y0 + dy * t + ny * off)

    vane = [at(0.3, 0)] + [at(t, 6.5 * math.sin(math.pi * (t - 0.3) / 0.72) ** 0.8) for t in (0.4, 0.5, 0.6, 0.7, 0.8, 0.9)] + [at(1.02, 0)] + \
        [at(t, -4.2 * math.sin(math.pi * (t - 0.36) / 0.66) ** 0.8) for t in (0.9, 0.8, 0.7, 0.6, 0.5, 0.42)] + [at(0.36, 0)]
    ic.poly(vane, WHITE, light=0.1, dark=0.25)
    for t in (0.5, 0.62, 0.74, 0.86):
        ic.line([at(t, 0), at(t + 0.07, 5.2 * math.sin(math.pi * (t - 0.3) / 0.72))], mix(LINEN, PARCH_D, 0.5), 0.6)
    ic.line([at(0.93, -3.0), at(0.97, -2.2)], mix(LINEN, PARCH_D, 0.6), 0.6)
    ic.poly([at(0.6, -3.9), at(0.66, -4.4), at(0.63, -1.5)], (0, 0, 0, 0) if False else mix(LINEN, PARCH_D, 0.3), shade=False)
    ic.line([at(0.02, 0), at(1.0, 0)], mix(CREAM, PARCH_D, 0.4), 1.1)
    ic.line([at(0.0, 0), at(0.12, 0)], INK, 1.2)
    ic.save("quill")


def scroll():
    ic = Icon()
    ic.rect((11, 8, 37, 40), PARCH, light=0.12, dark=0.2)
    for y, x1 in ((15, 33), (19, 31), (23, 33), (27, 28)):
        ic.line([(15, y), (x1, y)], mix(INK_SOFT, PARCH, 0.25), 0.9)
    ic.line([(15, 33.5), (17, 31.5), (19, 33.5), (21.5, 31.5), (22.5, 33.5)], INK_SOFT, 0.8)
    # rolls
    for y0 in (4, 36):
        ic.rect((8, y0, 40, y0 + 7), PARCH_D, radius=3, light=0.35, dark=0.35, angle=-90)
        ic.line([(10, y0 + 1.8), (38, y0 + 1.8)], PARCH, 1.0)
        ic.ellipse((37, y0 + 0.8, 41.5, y0 + 6.2), mul(PARCH_D, 0.8), shade=False)
        ic.arc((38, y0 + 2, 40.5, y0 + 5), 0, 360, mul(PARCH_D, 0.6), 0.6)
    # ribbon and wax seal
    ic.poly([(29, 37), (32, 37), (29.5, 46), (27, 44.5)], RED_D, light=0.2, dark=0.2)
    ic.poly([(32, 37), (35, 37), (37.5, 44.5), (35, 46)], RED_D, light=0.2, dark=0.2)
    ic.circle(32, 35, 6, RED, light=0.3, dark=0.35)
    ic.circle(32, 35, 3.6, mul(RED, 0.8), shade=False)
    ic.poly([(30, 36.5), (30, 33.5), (31, 34.8), (32, 33), (33, 34.8), (34, 33.5), (34, 36.5)], mix(RED, CREAM, 0.35), shade=False)
    ic.dot(29, 31.5, mix(RED, CREAM, 0.6), 0.8)
    ic.save("scroll")


def ship_icon():
    ic = Icon()
    # masts and rigging behind the sails
    ic.line([(17, 33), (17, 9)], WOOD_D, 1.6)
    ic.line([(30, 33), (30, 5)], WOOD_D, 1.6)
    ic.line([(30, 7), (45, 27)], INK_SOFT, 0.6)
    # sails billowing to the right
    sails = [((10, 11), (24, 19)), ((9, 20.5), (25, 30)), ((23, 7.5), (37, 16)), ((22, 17.5), (38, 28.5))]
    for (xa, ya), (xb, yb) in sails:
        pts = [(xa, ya), (xb, ya), (xb + 1.5, (ya + yb) / 2), (xb, yb), ((xa + xb) / 2, yb + 1.5), (xa, yb), (xa + 1.2, (ya + yb) / 2)]
        ic.poly(pts, CREAM, light=0.12, dark=0.3)
        ic.line([(xa + 1, ya + 0.6), (xb - 1, ya + 0.6)], mul(CREAM, 0.72), 0.7)
        ic.line([((xa + xb) / 2 + 0.5, ya + 2), ((xa + xb) / 2 + 1.2, yb - 1)], mul(CREAM, 0.82), 0.7)
    ic.poly([(39.5, 14), (46, 29), (39.5, 29)], CREAM, light=0.15, dark=0.3)
    # pennant
    ic.poly([(30.5, 4), (37, 5.5), (30.5, 7)], RED, shade=False)
    # hull with a raised stern (left)
    hull = [(3, 27), (9, 28), (12, 31), (40, 31), (45, 28.5), (41, 38), (37, 40.5), (11, 40.5), (7, 37), (4, 32)]
    ic.poly(hull, WOOD, light=0.3, dark=0.4)
    ic.line([(5, 32.5), (12, 34), (41, 34)], STRAW_D, 1.0)
    for x in (16, 21, 26, 31, 36):
        ic.rect((x, 35.3, x + 2, 37.3), INK, shade=False)
    ic.line([(4, 28.5), (10, 29.5), (12.5, 32), (40, 32), (44, 30)], WOOD_L, 0.8)
    ic.line([(43, 30), (47, 26)], WOOD_D, 1.2)
    # sea
    ic.line([(2, 42), (7, 40.8), (12, 42), (17, 40.8), (22, 42), (27, 40.8), (32, 42), (37, 40.8), (42, 42), (46, 40.8)], SEA, 2.2)
    ic.line([(6, 45), (10, 44), (14, 45)], SKY, 1.1)
    ic.line([(30, 45), (34, 44), (38, 45)], SKY, 1.1)
    ic.save("ship_icon")


def speed():
    """Horseshoe with motion streaks: route speed (roads and ships)."""
    ic = Icon()
    # motion streaks trailing left
    for y, x0, x1 in ((14, 2, 12), (22, 1, 10), (30, 2, 11.5)):
        ic.line([(x0, y), (x1, y)], LINEN, 1.8)
    cx, cy = 28, 24
    tilt = math.radians(22)  # toes forward, heels up: mid-gallop

    def P_(t, rx, ry):
        # t = 0 at the toe (bottom), +-150 deg at the heels (top)
        return rot([(rx * math.sin(t), ry * math.cos(t))], cx, cy, tilt)[0]

    outer = [P_(math.radians(-148 + 296 * k / 48), 15, 18) for k in range(49)]
    inner = [P_(math.radians(148 - 296 * k / 48), 8.2, 11) for k in range(49)]
    ic.poly(outer + inner, SILVER_D, light=0.45, dark=0.35)
    # heel calkins
    for sgn in (-1, 1):
        t = math.radians(146 * sgn)
        x, y = P_(t, 11.8, 14.8)
        ic.poly(rot([(-3.8, -2.2), (3.8, -2.2), (3.8, 2.2), (-3.8, 2.2)], x, y, tilt + sgn * 0.5), IRON, light=0.3, dark=0.3)
    # nail groove and holes
    ic.line([P_(math.radians(-125 + 250 * k / 30), 11.7, 14.6) for k in range(31)], IRON_D, 0.8)
    for deg in (-105, -65, -25, 25, 65, 105):
        ic.dot(*P_(math.radians(deg), 11.7, 14.6), INK, 1.0)
    ic.line([P_(math.radians(-140 + k * 6), 13.6, 16.6) for k in range(10)], mix(SILVER, WHITE, 0.5), 0.9)
    ic.save("speed")


def star():
    ic = Icon()
    cx, cy, R, r = 24, 25.5, 22, 9
    verts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        rr = R if i % 2 == 0 else r
        verts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    ic.poly(verts, GOLD, shade=False)
    lx, ly = -0.6, -0.8
    for i in range(10):
        p, q = verts[i], verts[(i + 1) % 10]
        mx, my = (p[0] + q[0]) / 2 - cx, (p[1] + q[1]) / 2 - cy
        # facet normal ~ direction from center to the facet midpoint
        L = math.hypot(mx, my)
        d = (mx * lx + my * ly) / L
        if i % 2 == 0:
            d -= 0.2
        c = mix(GOLD, CREAM, 0.55 * d) if d > 0 else mix(GOLD, GOLD_D, -0.85 * d)
        ic.poly([(cx, cy), p, q], c, shade=False)
    ic.dot(cx, cy, mix(GOLD, CREAM, 0.4), 1.0)
    ic.dot(40, 6, CREAM, 1.0)
    ic.line([(40, 3.5), (40, 8.5)], CREAM, 0.6)
    ic.line([(37.5, 6), (42.5, 6)], CREAM, 0.6)
    ic.save("star", colors=24)


def chest():
    ic = Icon()
    # open lid tipped back, showing its dark inside
    ic.rect((7, 4, 41, 21), WOOD, radius=5, light=0.3, dark=0.35)
    ic.rect((9.5, 7, 38.5, 21), WOOD_D, radius=3, light=0.1, dark=0.3)
    for x in (11, 34):
        ic.rect((x, 4, x + 3, 21), IRON, light=0.3, dark=0.3)
    # heap of gold
    ic.poly([(8, 25), (10, 19), (16, 15.5), (24, 14), (32, 15.5), (38, 19), (40, 25)], GOLD, light=0.3, dark=0.3)
    for x, y in ((14, 19), (21, 16.5), (29, 17), (35, 20.5), (18, 21.5), (26, 21)):
        ic.ellipse((x - 3, y - 1.8, x + 3, y + 1.8), GOLD, light=0.35, dark=0.4)
        ic.dot(x - 1, y - 0.6, CREAM, 0.6)
    ic.circle(31, 21.5, 1.8, RED, light=0.4, dark=0.3)
    ic.circle(20, 17.5, 1.4, SKY, light=0.4, dark=0.3)
    # box
    ic.rect((5, 24, 43, 44), WOOD, radius=1, light=0.25, dark=0.4)
    for y in (31, 37.5):
        ic.line([(6, y), (42, y)], WOOD_D, 0.8)
    ic.rect((5, 23, 43, 27), IRON, light=0.3, dark=0.35)
    for x in (10, 35):
        ic.rect((x, 23, x + 3, 44), IRON, light=0.3, dark=0.35)
        ic.dot(x + 1.5, 30, SILVER, 0.6)
        ic.dot(x + 1.5, 40, SILVER, 0.6)
    ic.rect((20, 25, 28, 34), BRASS, radius=1, light=0.35, dark=0.35)
    ic.circle(24, 28.5, 1.2, INK, shade=False)
    ic.poly([(23.4, 29), (24.6, 29), (25, 31.5), (23, 31.5)], INK, shade=False)
    ic.save("chest")


def crate():
    ic = Icon()
    front = (6, 17, 34, 44)
    # top and side faces
    ic.poly([(6, 17), (34, 17), (43, 8), (15, 8)], PINE, light=0.2, dark=0.15)
    ic.poly([(34, 17), (43, 8), (43, 35), (34, 44)], WOOD, light=0.1, dark=0.3)
    for k in (1, 2):
        t = k / 3
        ic.line([(6 + 9 * t + 1, 17 - 9 * t), (34 + 9 * t - 1, 17 - 9 * t)], WOOD_L, 0.8)
    ic.line([(34.5, 17), (43, 8.5)], WOOD_D, 1.0)
    ic.line([(34, 17), (34, 44)], WOOD_D, 0.8)
    for y in (24, 31, 38):
        ic.line([(35, y), (42.5, y - 8.5)], WOOD_D, 0.7)
    # front face: frame, planks, diagonal brace
    ic.rect(front, WOOD, light=0.25, dark=0.3)
    ic.rect((9.5, 20.5, 30.5, 40.5), WOOD_L, light=0.2, dark=0.25)
    for y in (25.5, 30.5, 35.5):
        ic.line([(9.5, y), (30.5, y)], WOOD, 0.8)
    ic.poly([(9.5, 37), (27, 20.5), (30.5, 20.5), (30.5, 24), (13, 40.5), (9.5, 40.5)], WOOD, light=0.25, dark=0.3)
    ic.line([(7, 18.2), (33, 18.2)], WOOD_L, 0.8)
    for x, y in ((8, 19), (32, 19), (8, 42), (32, 42), (20, 19), (20, 42)):
        ic.dot(x, y, IRON_D, 0.6)
    # stencil mark on the side
    ic.line([(37, 22.5), (40.5, 19)], PINE, 1.0)
    ic.line([(37, 19.5), (40.5, 22)], PINE, 1.0)
    ic.save("crate")


def portrait():
    ic = Icon()
    ic.ellipse((11, 5, 37, 43), mix(CREAM, PARCH, 0.4), light=0.1, dark=0.2)
    sil = (54, 42, 40)
    # shoulders and coat collar
    ic.poly([(8, 46), (10.5, 35), (16, 31), (22, 30), (30, 30.5), (36.5, 34), (40, 46)], sil, shade=False)
    # neck and head in profile, facing left
    ic.rect((21, 25, 28, 32), sil, shade=False)
    ic.ellipse((19, 10.5, 32, 27), sil, shade=False)
    ic.poly([(20, 15), (19.2, 17.5), (16.6, 21.5), (19, 22.2), (18.4, 24), (19.8, 24.8), (19.4, 26.2), (21, 28.5), (24, 29)], sil, shade=False)
    # tied-back hair: a queue with a ribbon bow
    ic.ellipse((27, 13, 33.5, 23), sil, shade=False)
    ic.poly([(29.5, 21), (32.5, 21.5), (33.5, 29), (31.5, 29.5)], sil, shade=False)
    # jabot at the throat
    ic.poly([(20.5, 30.5), (24.5, 30.5), (23.5, 34.5), (21, 34)], LINEN, shade=False)
    # keep everything inside the oval, then the gilt frame over the edge
    m = ic._layer()
    ImageDraw.Draw(m).ellipse(B((7, 2, 41, 46)), fill=255)
    a = ic.img.getchannel("A")
    from PIL import ImageChops
    ic.img.putalpha(ImageChops.multiply(a, m))
    ring(ic, (7, 2, 41, 46), (12, 6.5, 36, 41.5), GOLD, light=0.35, dark=0.45)
    ring(ic, (9.2, 4.2, 38.8, 43.8), (10.8, 5.6, 37.2, 42.4), GOLD_D, shade=False)
    ic.circle(24, 3.2, 2.4, GOLD, light=0.4, dark=0.3)
    ic.dot(12, 12, CREAM, 0.9)
    ic.save("portrait")


ICONS = {
    "gear": gear, "hammer": hammer, "hourglass": hourglass, "liberty": liberty, "lock": lock,
    "map": map_icon, "pick": pick, "quill": quill, "scroll": scroll, "ship_icon": ship_icon,
    "speed": speed, "star": star, "chest": chest, "crate": crate, "portrait": portrait,
}


if __name__ == "__main__":
    for fn in ICONS.values():
        fn()
    if len(sys.argv) > 1:
        sheet(list(ICONS), sys.argv[1], scale=4, cols=5)
