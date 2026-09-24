"""Research icons (American Philosophical Society entry point, the six research
branches and the node state badges) in the high-density style of lib.py.

Run: python tools/hd/research_icons.py [sheet.png]
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
STONE = (150, 142, 128)
MARBLE = (228, 222, 206)
FLAME = (250, 150, 50)
SEAL_G = (70, 140, 70)
SEAL_GD = (36, 88, 44)
MUTED = (150, 138, 120)
MUTED_D = (104, 94, 82)


# -- helpers (from feature_icons.py) ---------------------------------------
def P(pts):
    return [(x * SS, y * SS) for x, y in pts]


def B(box):
    return [box[0] * SS, box[1] * SS, box[2] * SS - 1, box[3] * SS - 1]


def shape(ic, color, draw, shade=True, **kw):
    m = ic._layer()
    draw(ImageDraw.Draw(m))
    ic._paint(m, color, shade, **kw)


def ring(ic, outer, inner, color, shade=True, **kw):
    def d(dr):
        dr.ellipse(B(outer), fill=255)
        dr.ellipse(B(inner), fill=0)
    shape(ic, color, d, shade, **kw)


def rot(pts, cx, cy, a):
    c, s = math.cos(a), math.sin(a)
    return [(cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]


def coin(ic, cx, cy, r):
    ic.circle(cx, cy, r, GOLD, light=0.35, dark=0.4)
    ic.circle(cx, cy, r * 0.68, mul(GOLD, 0.86), shade=False)
    ic.circle(cx, cy, r * 0.6, GOLD, light=0.25, dark=0.3, angle=45)
    ic.dot(cx - r * 0.45, cy - r * 0.45, CREAM, max(0.6, r * 0.14))


def gear(ic, cx, cy, r, teeth, color, hole=None, tooth=2.6, phase=0.0):
    for i in range(teeth):
        a = phase + i * 2 * math.pi / teeth
        ic.poly(rot([(r - 1, -1.6), (r + tooth, -1.1), (r + tooth, 1.1), (r - 1, 1.6)], cx, cy, a), color, light=0.3, dark=0.35)
    ic.circle(cx, cy, r, color, light=0.3, dark=0.4)
    if hole:
        ic.circle(cx, cy, hole, mul(color, 0.55), shade=False)


def open_book(ic, x0, x1, y_top, y_bot, sag=3.0, cover=OXBLOOD):
    """Open book seen from the front: two fanned pages on a leather cover."""
    cx = (x0 + x1) / 2
    ic.poly([(x0 - 1.5, y_top + 2.5), (cx, y_top + sag + 2.5), (x1 + 1.5, y_top + 2.5), (x1 + 1.5, y_bot + 1.5),
             (cx, y_bot + sag + 1.8), (x0 - 1.5, y_bot + 1.5)], cover, light=0.2, dark=0.35)
    ic.poly([(x0, y_top), (cx - 4, y_top - 1.2), (cx, y_top + sag), (cx, y_bot + sag), (cx - 4, y_bot - 0.8), (x0, y_bot)],
            CREAM, light=0.12, dark=0.18)
    ic.poly([(cx, y_top + sag), (cx + 4, y_top - 1.2), (x1, y_top), (x1, y_bot), (cx + 4, y_bot - 0.8), (cx, y_bot + sag)],
            LINEN, light=0.1, dark=0.25)
    ic.line([(cx, y_top + sag), (cx, y_bot + sag)], PARCH_D, 0.7)
    return cx


# -- entry point -----------------------------------------------------------
def society():
    """Oil lamp of learning burning over an open book, rays around the flame."""
    ic = Icon()
    fx, fy = 31, 12
    # halo and rays around the flame
    for i in range(10):
        a = math.radians(i * 36 + 18)
        ic.poly(rot([(7.5, -1.3), (12.5, 0), (7.5, 1.3)], fx, fy, a), GOLD, light=0.2, dark=0.2)
    ic.circle(fx, fy, 7.5, mix(GOLD, CREAM, 0.6), shade=False)
    # book
    cx = open_book(ic, 5, 43, 31, 41, sag=2.5)
    for y in (33.5, 36, 38.5):
        ic.line([(8.5, y), (cx - 3, y + 1.2)], PARCH_D, 0.6)
        ic.line([(cx + 3, y + 1.2), (39.5, y)], PARCH_D, 0.6)
    # brass oil lamp resting on the book, spout to the right
    ic.arc((4, 21, 13, 29.5), 90, 270, BRONZE_D, 1.4)                                # handle
    ic.ellipse((8, 21, 27, 31), BRASS, light=0.4, dark=0.4)
    ic.poly([(23, 23), (31.5, 18.5), (33, 20.5), (26, 28)], BRASS, light=0.35, dark=0.35)  # spout
    ic.ellipse((13, 19, 22, 22.5), BRONZE, light=0.3, dark=0.3)                      # lid
    ic.circle(17.5, 18.6, 1.2, BRONZE_D, shade=False)
    ic.rect((12.5, 29.5, 22.5, 32), BRONZE, light=0.3, dark=0.35)                    # foot
    ic.dot(12, 23.5, CREAM, 0.9)
    # flame at the spout
    ic.poly([(fx + 0.8, 19.5), (fx - 2.8, 15), (fx - 1.2, 9.5), (fx + 1.5, 3.5), (fx + 3.2, 9.5), (fx + 3.8, 15), (fx + 2.6, 19.5)],
            FLAME, light=0.35, dark=0.2)
    ic.poly([(fx + 1.2, 18.5), (fx - 0.4, 15), (fx + 1.3, 9.5), (fx + 2.4, 15), (fx + 2.2, 18.5)], mix(GOLD, CREAM, 0.55), shade=False)
    ic.save("society")


def branch_husbandry():
    """Wooden plough before a bound wheat sheaf."""
    ic = Icon()
    # ground
    ic.poly([(1, 42), (47, 40), (47, 46.5), (1, 46.5)], mix(LEAF_D, BARK, 0.45), light=0.15, dark=0.25)
    for x in (4, 12, 20, 28, 36):
        ic.line([(x, 46), (x + 6, 41.5)], mul(mix(LEAF_D, BARK, 0.45), 0.7), 0.6)
    # wheat sheaf on the right
    sx = 37
    for dx in (-8, -5, -2, 1, 4, 7, 9.5):
        top = (sx + dx, 9 + abs(dx + 0.5) * 0.45)
        ic.line([(sx + dx * 0.25, 28), top], STRAW_D, 0.8)
        ang = math.atan2(top[1] - 28, top[0] - (sx + dx * 0.25))
        ear = rot([(-6, -1.7), (1, 0), (-6, 1.7), (-7.5, 0)], top[0], top[1], ang)
        ic.poly(ear, STRAW, light=0.35, dark=0.35)
        for k in (2, 4.5):
            px, py = rot([(-k, 0)], top[0], top[1], ang)[0]
            ic.dot(px, py, STRAW_D, 0.4)
    ic.poly([(sx - 3, 28), (sx + 3, 28), (sx + 6, 43), (sx - 6, 43)], STRAW, light=0.3, dark=0.4)
    for dx in (-3, 0, 3):
        ic.line([(sx + dx * 0.6, 29), (sx + dx * 1.4, 42.5)], STRAW_D, 0.5)
    ic.rect((sx - 4, 26.5, sx + 4, 30), mix(STRAW_D, BARK, 0.5), light=0.2, dark=0.3)
    # plough travelling left: beam forward, share low, handles back and up
    ic.line([(3, 30), (23, 38)], WOOD, 2.4, shade=False)
    ic.line([(3.2, 29.1), (22, 36.8)], WOOD_L, 0.6)
    ic.line([(22, 40), (30, 13)], WOOD_D, 2.0)
    ic.line([(17, 40), (24, 14)], WOOD, 2.0)
    ic.line([(21.5, 24), (27.5, 24.5)], WOOD_D, 1.1)
    ic.poly([(6, 43), (13, 36.5), (24, 37), (25, 43.5)], IRON, light=0.4, dark=0.4)   # share and mouldboard
    ic.line([(9, 42), (14, 38)], SILVER, 0.8)
    ic.save("branch_husbandry")


def branch_forestry():
    """Tree stump with an axe bitten in and a pickaxe leaning against it."""
    ic = Icon()
    # pickaxe leaning from the lower right up to the upper left
    ic.line([(42, 40), (12, 8)], WOOD_D, 2.2)
    ic.line([(41.2, 39.6), (12.2, 8.8)], WOOD, 0.6)
    pa = math.atan2(8 - 40, 12 - 42)
    head = rot([(-1.4, -14), (1.2, -10.5), (2.8, 0), (1.2, 10.5), (-1.4, 14), (-0.4, 0)], 12, 8, pa)
    ic.poly(head, IRON_D, light=0.45, dark=0.35)
    # stump
    ic.shadow(24, 44, 18, 2.5, 60)
    ic.poly([(7, 43.5), (10.5, 39), (10.5, 27), (37.5, 27), (37.5, 39), (41, 43.5)], BARK, light=0.25, dark=0.4)
    for x in (15, 20.5, 27, 32.5):
        ic.line([(x, 30), (x + 0.5, 42)], mul(BARK, 0.7), 0.6)
    ic.ellipse((10, 22, 38, 32), PINE, light=0.3, dark=0.3)
    ring(ic, (14, 24, 34, 30), (15.5, 24.8, 32.5, 29.2), WOOD, shade=False)
    ring(ic, (18, 25.3, 30, 28.7), (19.5, 25.9, 28.5, 28.1), WOOD, shade=False)
    # axe: handle up to the right, head buried in the stump top
    ic.line([(21, 25), (35, 4)], WOOD_L, 2.2)
    ic.line([(21.6, 24), (34.6, 4.6)], mix(WOOD_L, CREAM, 0.4), 0.5)
    ic.poly([(11, 28), (12, 19.5), (16, 17.5), (21, 18.5), (26, 21), (26, 28)], SILVER_D, light=0.55, dark=0.25)
    ic.line([(11.8, 27.4), (25.4, 27.4)], SILVER, 0.9)
    ic.line([(12.6, 20.5), (12.2, 26.5)], SILVER, 0.7)
    ic.rect((20, 17.5, 26, 23.5), IRON_D, light=0.25, dark=0.3)
    ic.line([(10, 28.5), (27, 28.5)], WOOD_D, 0.8)   # the cleft
    # wood chips
    for x, y in ((5, 38), (44, 36), (43, 42)):
        ic.poly([(x - 1.4, y), (x, y - 1.1), (x + 1.6, y + 0.3), (x, y + 1.1)], PINE, shade=False)
    ic.save("branch_forestry")


def branch_navigation():
    """Ship's wheel over rolling waves."""
    ic = Icon()
    cx, cy = 24, 20
    # spokes with handles
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        x0, y0 = cx + math.cos(a) * 4, cy + math.sin(a) * 4
        x1, y1 = cx + math.cos(a) * 18.5, cy + math.sin(a) * 18.5
        ic.line([(x0, y0), (x1, y1)], WOOD, 1.5, shade=False)
        hx, hy = cx + math.cos(a) * 17, cy + math.sin(a) * 17
        ic.circle(hx, hy, 2.1, WOOD_L, light=0.3, dark=0.35)
    ring(ic, (cx - 13, cy - 13, cx + 13, cy + 13), (cx - 9.8, cy - 9.8, cx + 9.8, cy + 9.8), WOOD, light=0.3, dark=0.4)
    ring(ic, (cx - 12, cy - 12, cx + 12, cy + 12), (cx - 11.3, cy - 11.3, cx + 11.3, cy + 11.3), WOOD_L, shade=False)
    ic.circle(cx, cy, 4.8, BRASS, light=0.4, dark=0.4)
    ic.circle(cx, cy, 1.8, BRONZE_D, shade=False)
    ic.dot(cx - 1.8, cy - 1.8, CREAM, 0.7)
    # waves in front
    for y0, col in ((33, SEA), (38.5, mix(SEA, NAVY, 0.5))):
        pts = [(0.5, y0 + 2)]
        for k in range(0, 49, 2):
            pts.append((k, y0 + math.sin(k / 3.2 + y0) * 1.6))
        pts += [(48, 47), (0, 47)]
        ic.poly(pts, col, light=0.25, dark=0.3)
    for x, y in ((6, 33.5), (19, 34), (33, 33.5), (12, 39.5), (28, 39.8), (41, 39.3)):
        ic.arc((x - 3, y - 1.4, x + 3, y + 2), 200, 340, mix(SKY, WHITE, 0.5), 0.7)
    ic.save("branch_navigation")


def branch_roads():
    """A road running off to the horizon with a wagon wheel in front."""
    ic = Icon()
    # sky band and hills
    ic.rect((3, 4, 45, 26), mix(SKY, CREAM, 0.35), radius=3, light=0.1, dark=0.15)
    ic.poly([(3, 22), (12, 15), (20, 19), (30, 13), (45, 20), (45, 27), (3, 27)], mix(LEAF, LEAF_D, 0.4), light=0.2, dark=0.3)
    # field
    ic.rect((3, 24, 45, 44), LEAF, radius=3, light=0.2, dark=0.3)
    # road receding
    ic.poly([(5, 44), (22.5, 24), (25.5, 24), (43, 44)], mix(PARCH_D, WOOD_L, 0.35), light=0.25, dark=0.25)
    for t in (0.2, 0.45, 0.72):
        y = 24 + 20 * t
        ic.line([(24, y - 1.5 * t), (24, y + 2.5 * t)], PARCH, 0.4 + 0.9 * t)
    ic.line([(8, 44), (23, 24.5)], mix(PARCH_D, WOOD, 0.5), 0.5)
    ic.line([(40, 44), (25, 24.5)], mix(PARCH_D, WOOD, 0.5), 0.5)
    # milepost
    ic.rect((36, 20, 39, 33), WOOD, light=0.3, dark=0.35)
    ic.poly([(33, 21), (43, 21), (45.5, 23.5), (43, 26), (33, 26)], PINE, light=0.3, dark=0.35)
    ic.line([(35, 23.5), (41.5, 23.5)], WOOD_D, 0.7)
    # wagon wheel, bottom-left, overlapping
    cx, cy, r = 14, 33, 11
    for i in range(10):
        a = math.radians(i * 36)
        ic.line([(cx, cy), (cx + math.cos(a) * (r - 1), cy + math.sin(a) * (r - 1))], WOOD_L, 1.3, shade=False)
    ring(ic, (cx - r, cy - r, cx + r, cy + r), (cx - r + 2.6, cy - r + 2.6, cx + r - 2.6, cy + r - 2.6), WOOD, light=0.3, dark=0.4)
    ring(ic, (cx - r, cy - r, cx + r, cy + r), (cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1), IRON, light=0.35, dark=0.35)
    ic.circle(cx, cy, 3, WOOD_D, light=0.3, dark=0.3)
    ic.circle(cx, cy, 1.2, IRON_D, shade=False)
    ic.save("branch_roads")


def branch_manufacture():
    """Blacksmith's anvil in front of a large gear."""
    ic = Icon()
    gear(ic, 31, 15, 12, 10, BRASS, hole=None, tooth=3.2, phase=0.15)
    ic.circle(31, 15, 7.2, mul(BRASS, 0.72), shade=False)
    ic.circle(31, 15, 5.8, BRASS, light=0.3, dark=0.3, angle=45)
    ic.circle(31, 15, 2.4, BRONZE_D, shade=False)
    ic.shadow(24, 44.5, 18, 2.2, 60)
    # anvil
    ic.poly([(3, 23), (13, 23), (13, 21), (40, 21), (40, 28), (31, 29.5), (29, 31), (18, 31), (16, 29.5), (11, 27.5)],
            IRON, light=0.35, dark=0.4)
    ic.line([(13.5, 21.8), (39.5, 21.8)], SILVER, 0.8)
    ic.rect((19, 31, 28, 38), IRON_D, light=0.3, dark=0.35)
    ic.poly([(12, 44.5), (17, 37), (30, 37), (35, 44.5)], IRON, light=0.3, dark=0.4)
    # hammer resting on top
    # glowing bar on the anvil face
    ic.rect((15, 17, 30, 21.2), (226, 72, 36), radius=1, light=0.3, dark=0.25)
    ic.line([(16.5, 18.3), (28, 18.3)], mix(GOLD, CREAM, 0.4), 0.9)
    # sparks
    for x, y in ((9, 16), (6, 19), (12, 12.5)):
        ic.dot(x, y, GOLD, 0.8)
    ic.save("branch_manufacture")


def branch_commerce():
    """Open ledger with a quill and a stack of coins."""
    ic = Icon()
    cx = open_book(ic, 4, 36, 17, 38, sag=2.5, cover=OXBLOOD)
    # columns of figures
    for y in (21, 24.5, 28, 31.5):
        ic.line([(7, y), (cx - 3, y + 1.3)], INK_SOFT, 0.6)
        ic.line([(cx + 3, y + 1.3), (32, y)], INK_SOFT, 0.6)
    # coins stacked at the bottom right
    for k in range(4):
        y = 44 - k * 2.3
        ic.ellipse((30, y - 2.3, 44, y + 2.3), GOLD if k % 2 else GOLD_D, light=0.3, dark=0.35)
    ic.ellipse((30, 34.6, 44, 39.2), GOLD, light=0.35, dark=0.3)
    ic.ellipse((33.5, 35.7, 40.5, 38.1), mul(GOLD, 0.86), shade=False)
    ic.dot(32.5, 36, CREAM, 0.6)
    coin(ic, 8, 42, 4)
    # quill standing up from the top right
    x0, y0, x1, y1 = 27, 30, 45, 2
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L

    def at(t, off):
        return (x0 + dx * t + nx * off, y0 + dy * t + ny * off)
    vane = [at(0.28, 0)] + [at(t, 4.8 * math.sin(math.pi * (t - 0.28) / 0.74) ** 0.8) for t in (0.4, 0.55, 0.7, 0.85, 0.95)] + \
        [at(1.0, 0)] + [at(t, -3.4 * math.sin(math.pi * (t - 0.34) / 0.68) ** 0.8) for t in (0.9, 0.75, 0.6, 0.45)] + [at(0.34, 0)]
    ic.poly(vane, WHITE, light=0.1, dark=0.28)
    ic.line([at(0.03, 0), at(0.98, 0)], mix(CREAM, PARCH_D, 0.45), 1.0)
    ic.line([at(0.0, 0), at(0.1, 0)], INK, 1.2)
    ic.save("branch_commerce")


# -- state badges ----------------------------------------------------------
def wax_seal(ic, cx, cy, r, col, col_d):
    """Scalloped wax seal."""
    pts = []
    for i in range(36):
        a = math.radians(i * 10)
        rr = r + (1.0 if i % 2 else -0.2)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    ic.poly(pts, col, light=0.3, dark=0.4)
    ring(ic, (cx - r * 0.78, cy - r * 0.78, cx + r * 0.78, cy + r * 0.78),
         (cx - r * 0.66, cy - r * 0.66, cx + r * 0.66, cy + r * 0.66), col_d, shade=False)


def research_done():
    ic = Icon()
    # ribbon tails
    ic.poly([(15, 30), (21, 33), (17, 46), (14, 43), (10.5, 45.5)], SEAL_GD, light=0.25, dark=0.3)
    ic.poly([(33, 30), (27, 33), (31, 46), (34, 43), (37.5, 45.5)], SEAL_G, light=0.25, dark=0.3)
    wax_seal(ic, 24, 21, 17, SEAL_G, SEAL_GD)
    ic.line([(15, 21.5), (21.5, 28), (33.5, 13)], CREAM, 3.6)
    ic.dot(14, 11, mix(SEAL_G, CREAM, 0.6), 1.2)
    ic.save("research_done", outline=mix(INK, SEAL_GD, 0.4))


def research_locked():
    ic = Icon()
    # parchment scrap
    ic.poly([(5, 8), (41, 5), (43, 41), (7, 44)], mix(PARCH_D, MUTED, 0.45), light=0.12, dark=0.25)
    for y in (12, 16):
        ic.line([(9, y), (22, y - 0.6)], MUTED_D, 0.6)
    # padlock
    ring(ic, (15, 9, 33, 29), (19, 13, 29, 26), MUTED_D, light=0.3, dark=0.35)
    ic.rect((12, 20, 36, 40), MUTED, radius=2.5, light=0.28, dark=0.35)
    ic.line([(13.5, 22.5), (13.5, 37.5)], mix(MUTED, CREAM, 0.35), 0.8)
    ic.circle(24, 27.5, 2.6, mul(MUTED_D, 0.6), shade=False)
    ic.poly([(22.8, 28), (25.2, 28), (26, 34), (22, 34)], mul(MUTED_D, 0.6), shade=False)
    ic.save("research_locked", outline=(52, 44, 38))


def research_excluded():
    ic = Icon()
    col, col_d = (156, 84, 72), (104, 52, 46)
    wax_seal(ic, 24, 24, 18, col, col_d)
    ic.line([(16, 16), (32, 32)], mix(col_d, INK, 0.3), 3.2)
    ic.line([(32, 16), (16, 32)], mix(col_d, INK, 0.3), 3.2)
    ic.dot(13, 13, mix(col, CREAM, 0.45), 1.1)
    ic.save("research_excluded", outline=(60, 34, 30))


ICONS = {
    "society": society,
    "branch_husbandry": branch_husbandry, "branch_forestry": branch_forestry, "branch_navigation": branch_navigation,
    "branch_roads": branch_roads, "branch_manufacture": branch_manufacture, "branch_commerce": branch_commerce,
    "research_done": research_done, "research_locked": research_locked, "research_excluded": research_excluded,
}


if __name__ == "__main__":
    for fn in ICONS.values():
        fn()
    if len(sys.argv) > 1:
        sheet(list(ICONS), sys.argv[1], scale=4, cols=5)
