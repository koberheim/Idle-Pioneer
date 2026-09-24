"""High-density icons for collectible relics (Franklin, Revolution and
Scholars sets) in the style of lib.py.

Run: python tools/hd/relics_a.py [sheet.png]
Writes assets/sprites/icons/relic_<id>.png for every relic below and, only
when a path is given, a contact sheet for review.
"""
import math
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: E402,F401,F403
from lib import SS  # noqa: E402

# extra colours for the relic set: museum materials
BRONZE = (196, 142, 70)
BRONZE_D = (120, 78, 40)
BRONZE_L = (232, 186, 110)
BRASS_L = (238, 206, 118)
BRASS_D = (140, 104, 40)
MAHOG = (120, 56, 36)
MAHOG_D = (78, 34, 24)
MAHOG_L = (164, 86, 54)
CAST = (60, 60, 66)
CAST_L = (104, 104, 114)
FLAME = (252, 206, 84)
FLAME_O = (236, 124, 40)
GLOW = (255, 236, 150)
GLASS = (206, 230, 232)
GLASS_D = (150, 186, 196)
OLDPAPER = (226, 202, 150)
OLDPAPER_D = (180, 150, 100)
TEA = (70, 84, 44)
TEA_L = (112, 124, 62)
SNOW = (240, 244, 248)
ENAMEL = (244, 238, 222)
BLUED = (44, 56, 110)
PETAL = (250, 248, 238)
PETAL_D = (208, 204, 196)
SPARK = (230, 240, 255)
SPARK_B = (140, 190, 250)
LEATHER_B = (58, 62, 104)     # dark blue calf binding
LEATHER_BD = (34, 36, 70)


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


def ell_pts(cx, cy, rx, ry, a0, a1, n=24):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def thick_line(ic, pts, color, width, **kw):
    """A shaded stroke (lib.line is flat)."""
    def d(dr):
        w = int(round(width * SS))
        dr.line(P(pts), fill=255, width=w, joint="curve")
        r = w / 2
        for x, y in P(pts):
            dr.ellipse([x - r, y - r, x + r, y + r], fill=255)
    shape(ic, color, d, True, **kw)


def pie(ic, box, a0, a1, color, **kw):
    shape(ic, color, lambda dr: dr.pieslice([v * SS for v in box], a0, a1, fill=255), True, **kw)


def glint(ic, x, y, s=2.5, color=CREAM):
    """Four-point museum sparkle."""
    ic.poly([(x - s, y), (x - 0.5, y - 0.5), (x, y - s), (x + 0.5, y - 0.5),
             (x + s, y), (x + 0.5, y + 0.5), (x, y + s), (x - 0.5, y + 0.5)], color, shade=False)
    ic.dot(x, y, WHITE, 0.6)


def squiggle(ic, x0, x1, y, color, width=0.8, amp=0.6, step=1.6):
    """A line of 'text': a wavering stroke that never spells anything."""
    pts = []
    x = x0
    i = 0
    while x <= x1:
        pts.append((x, y + (amp if i % 2 else -amp)))
        x += step
        i += 1
    ic.line(pts, color, width)


# -- relics ----------------------------------------------------------------
def kite_key():
    ic = Icon(seed=101)
    silk = (240, 232, 208)
    # silk string trailing up to the kite, off canvas top-right
    ic.line([(36, 8), (39, 5), (42, 3), (47, 0)], silk, 0.9)
    # the key, diagonal: bow up-right, bit down-left
    cx, cy = 32, 14
    s1 = (7, 40)
    # shaft
    thick_line(ic, [(cx - 5, cy + 5), s1], BRASS, 4.2, light=0.35, dark=0.4)
    ic.line([(cx - 6.5, cy + 4.6), (s1[0] + 0.2, s1[1] - 2.2)], BRASS_L, 0.8)
    # bit: toothed flag hanging off the shaft near the tip, on the lower-right side
    d = (math.sqrt(0.5), -math.sqrt(0.5))   # up the shaft
    n = (math.sqrt(0.5), math.sqrt(0.5))    # perpendicular, down-right

    def at(t, o):
        return (s1[0] + d[0] * t + n[0] * o, s1[1] + d[1] * t + n[1] * o)
    ic.poly([at(1, 0), at(10, 0), at(10, 7), at(8, 7), at(8, 5), at(5.5, 5), at(5.5, 7.5), at(3, 7.5), at(3, 5.5), at(1, 5.5)],
            BRASS, light=0.35, dark=0.45)
    ic.line([at(1.5, 1.2), at(9.5, 1.2)], BRASS_D, 0.6)
    # collars
    for t in (27, 30):
        ic.poly([at(t - 0.9, -3), at(t + 0.9, -3), at(t + 0.9, 3), at(t - 0.9, 3)], BRASS_L, light=0.35, dark=0.45)
    # bow: a heavy ring
    ring(ic, (cx - 9, cy - 9, cx + 9, cy + 9), (cx - 4.5, cy - 4.5, cx + 4.5, cy + 4.5), BRASS, light=0.4, dark=0.45)
    ring(ic, (cx - 5.6, cy - 5.6, cx + 5.6, cy + 5.6), (cx - 4.5, cy - 4.5, cx + 4.5, cy + 4.5), BRASS_D, shade=False)
    ic.arc((cx - 8, cy - 8, cx + 8, cy + 8), 195, 255, BRASS_L, 1.1)
    # silk knotted through the bow
    ic.line([(cx + 1.5, cy - 4), (cx + 3.5, cy - 7.5), (36, 8)], silk, 1.0)
    ic.dot(cx + 3.4, cy - 7.4, (214, 200, 160), 1.1)
    # electric spark leaping from the key toward a knuckle off-canvas
    bolt = [(15, 22), (10, 19.5), (12.5, 17.5), (6, 13), (4, 8)]
    ic.line(bolt, SPARK_B, 2.4)
    ic.line(bolt, SPARK, 0.9)
    glint(ic, 4, 7, 3.2, SPARK)
    ic.dot(9, 25, SPARK_B, 0.8)
    ic.dot(3, 17, SPARK_B, 0.7)
    ic.dot(16, 11, SPARK_B, 0.6)
    glint(ic, 40, 23, 2.3)
    ic.save("relic_kite_key")


def franklin_stove():
    ic = Icon(seed=102)
    ic.shadow(24, 44, 20, 2.5)
    # flue pipe behind
    ic.rect((20, 1, 28, 10), CAST, light=0.3, dark=0.3)
    ic.rect((19, 4, 29, 5.5), CAST_L, shade=False)
    # ornamental crest plate with a brass sunburst
    ic.poly([(9, 16), (10, 11), (15, 8), (24, 6), (33, 8), (38, 11), (39, 16)], CAST, light=0.3, dark=0.3)
    ic.circle(24, 12, 3.6, BRASS, light=0.4, dark=0.3)
    for i in range(10):
        ang = math.radians(180 + i * 20)
        ic.line([(24 + 4.3 * math.cos(ang), 12 + 4.3 * math.sin(ang)), (24 + 6.6 * math.cos(ang), 12 + 6.6 * math.sin(ang))], BRASS, 0.8)
    ic.dot(23, 11, BRASS_L, 0.9)
    # cornice
    ic.rect((5, 15, 43, 19), CAST_L, light=0.35, dark=0.3)
    ic.line([(6, 15.6), (42, 15.6)], (150, 150, 160), 0.7)
    # body
    ic.rect((7, 19, 41, 39), CAST, light=0.3, dark=0.35)
    # arched hearth opening with a fire
    arch = [(12, 38)] + ell_pts(24, 26, 12, 6, 180, 360, 16) + [(36, 38)]
    ic.poly(arch, (26, 20, 20), shade=False)
    inner = [(14, 38)] + ell_pts(24, 27, 10, 5, 180, 360, 16) + [(34, 38)]
    ic.poly(inner, (70, 32, 22), shade=False)
    ic.poly([(15, 38), (17, 31), (19, 34), (21, 26), (24, 32), (27, 25), (29, 33), (31, 29), (33, 38)], FLAME_O, shade=False)
    ic.poly([(18, 38), (20, 33), (22, 35), (24, 29), (26, 34), (28, 31), (30, 38)], FLAME, shade=False)
    ic.poly([(21, 38), (24, 33), (27, 38)], GLOW, shade=False)
    ic.rect((14, 36.5, 34, 38.5), MOLASSES, shade=False)
    ic.line([(16, 37), (31, 37.5)], (150, 60, 30), 0.7)
    # panel mouldings and brass knobs
    ic.line(ell_pts(24, 26, 12, 6, 180, 360, 16), CAST_L, 0.8)
    ic.line([(9, 21), (9, 37)], CAST_L, 0.7)
    for x in (9, 39):
        ic.circle(x, 17, 1.6, BRASS, light=0.4, dark=0.3)
    # hearth plate and feet
    ic.rect((4, 39, 44, 42), CAST_L, light=0.3, dark=0.35)
    for x in (6, 38):
        ic.poly([(x, 41), (x + 4, 41), (x + 3.5, 45), (x + 0.5, 45)], CAST, light=0.3, dark=0.3)
    ic.line([(8, 20.5), (40, 20.5)], (130, 130, 140), 0.6)
    glint(ic, 36, 23, 2.2)
    ic.save("relic_franklin_stove")


def armonica():
    ic = Icon(seed=103)
    ic.shadow(24, 44, 21, 2.5)
    # legs
    for x in (7, 39):
        ic.rect((x, 36, x + 3, 45), MAHOG_D, light=0.2, dark=0.2)
    # case: open-top mahogany box, back wall visible
    ic.poly([(2, 27), (5, 22), (46, 22), (46, 27)], MAHOG_D, shade=False)
    # spindle
    ic.line([(2, 20), (46, 20)], SILVER_D, 1.2)
    # the nest of glass bowls reads as a horizontal glass bell tapering to
    # the right, banded by the painted rims of each bowl
    x0, x1 = 5.0, 40.0
    h0, h1 = 11.5, 4.0

    def half(x):
        t = (x - x0) / (x1 - x0)
        return h0 + (h1 - h0) * t

    top = [(x, 20 - half(x)) for x in (x0, 12, 20, 28, 36, x1)]
    bot = [(x, 20 + half(x)) for x in (x1, 36, 28, 20, 12, x0)]
    ic.poly(top + [(x1 + 1.5, 20)] + bot, GLASS, light=0.3, dark=0.35)
    # inner shadow along the lower half: glass looking through glass
    ic.poly([(x0 + 1, 20)] + [(x, 20 + half(x) - 1.2) for x in (x0 + 1, 12, 20, 28, 36, x1 - 1)] + [(x1 - 1, 20)],
            mix(GLASS, GLASS_D, 0.7), shade=False)
    rims = [GOLD, RED, GOLD, NAVY, GOLD, RED, GOLD, NAVY]
    for k, rim in enumerate(rims):
        x = x0 + 0.6 + k * 4.5
        h = half(x)
        ic.arc((x - 1.8, 20 - h, x + 1.8, 20 + h), 270, 450, rim, 1.2)
        ic.arc((x - 1.8, 20 - h, x + 1.8, 20 + h), 90, 270, mix(GLASS, WHITE, 0.5), 0.5)
    ic.line([(6, 10.2), (38, 17.2)], WHITE, 0.8)
    ic.circle(x1 + 2, 20, 1.5, SILVER, light=0.4, dark=0.3)
    # flywheel at the left end of the spindle
    ring(ic, (0.5, 11, 6.5, 29), (2.3, 15, 4.7, 25), BRASS, light=0.35, dark=0.35)
    # front of case
    ic.rect((2, 27, 46, 37), MAHOG, light=0.3, dark=0.35)
    ic.line([(2, 27.6), (46, 27.6)], MAHOG_L, 0.9)
    ic.rect((5, 30, 43, 34.5), mul(MAHOG, 0.86), light=0.1, dark=0.2)
    ic.line([(5, 30.3), (43, 30.3)], MAHOG_D, 0.6)
    for x in (13, 24, 35):
        ic.ellipse((x - 2.2, 31, x + 2.2, 33.5), BRASS, light=0.4, dark=0.3)
    ic.rect((2, 36, 46, 38), MAHOG_D, shade=False)
    glint(ic, 43, 9, 2.6)
    ic.save("relic_armonica")


def bifocals():
    ic = Icon(seed=104)
    ic.shadow(24, 40, 20, 2.5)
    frame = BRASS
    for cx in (13, 35):
        cy = 25
        # upper (distance) half and lower (reading) half, cut across the middle
        pie(ic, (cx - 9, cy - 9, cx + 9, cy + 9), 180, 360, (176, 212, 226), light=0.35, dark=0.1)
        pie(ic, (cx - 9, cy - 9, cx + 9, cy + 9), 0, 180, (126, 170, 198), light=0.2, dark=0.25)
        ic.line([(cx - 9, cy + 0.2), (cx + 9, cy + 0.2)], SILVER_D, 1.0)
    # temples folded behind, seen through the glass
    see = (104, 120, 110)
    ic.line([(5, 22), (29, 21)], see, 1.0)
    ic.line([(43, 22), (19, 21)], see, 1.0)
    ic.line([(28.5, 21), (30, 22.5)], see, 1.0)
    ic.line([(19.5, 21), (18, 22.5)], see, 1.0)
    for cx in (13, 35):
        cy = 25
        ring(ic, (cx - 10.5, cy - 10.5, cx + 10.5, cy + 10.5), (cx - 8.6, cy - 8.6, cx + 8.6, cy + 8.6), frame, light=0.4, dark=0.4)
        ic.arc((cx - 9.8, cy - 9.8, cx + 9.8, cy + 9.8), 190, 250, BRASS_L, 0.8)
        ic.line([(cx - 5.5, cy - 4), (cx - 3, cy - 6.5)], WHITE, 1.0)
        ic.dot(cx + 4, cy + 4.5, (190, 220, 232), 0.7)
    # bridge
    ic.line([(22.5, 22), (24, 19.5), (25.5, 22)], frame, 1.6)
    ic.line([(23.3, 20.6), (24, 19.6)], BRASS_L, 0.5)
    # hinges
    ic.rect((1.5, 21, 4.5, 25), BRASS, light=0.3, dark=0.3)
    ic.rect((43.5, 21, 46.5, 25), BRASS, light=0.3, dark=0.3)
    glint(ic, 30, 12, 2.4)
    ic.save("relic_bifocals")


def poor_richard():
    ic = Icon(seed=105)
    ic.shadow(24, 45, 17, 2.5)
    # page block visible along right and bottom edges
    ic.poly([(11, 5), (38, 5), (41, 7), (41, 45), (13, 45), (11, 43)], OLDPAPER_D, light=0.1, dark=0.2)
    for y in (43.4, 44.3):
        ic.line([(13, y), (40.5, y)], OLDPAPER, 0.4)
    # cover sheet
    ic.poly([(8, 3), (38, 3), (38, 42), (8, 42)], OLDPAPER, light=0.18, dark=0.3)
    # stitched spine
    ic.line([(10, 4), (10, 41)], OLDPAPER_D, 0.8)
    for y in (8, 16, 24, 32, 39):
        ic.line([(9.3, y), (10.7, y + 1.2)], RED_D, 0.6)
    # double ruled border
    for m, w in ((13, 0.8), (14.6, 0.5)):
        ic.line([(m, 6), (m, 39.5), (38 - (m - 8) + 5, 39.5)], INK_SOFT, w)
        ic.line([(m, 6), (38 - (m - 8) + 5, 6), (38 - (m - 8) + 5, 39.5)], INK_SOFT, w)
    # title in red, then black lines of text
    squiggle(ic, 17, 30, 9.5, RED, 1.2, 0.7, 1.4)
    squiggle(ic, 18.5, 29, 12.6, INK, 0.9, 0.5, 1.3)
    ic.line([(17, 15), (30, 15)], INK_SOFT, 0.5)
    # woodcut: sun over a crescent moon
    ic.circle(21, 21.5, 3, INK_SOFT, shade=False)
    ic.circle(21, 21.5, 2, STRAW_D, shade=False)
    for i in range(8):
        ang = math.radians(i * 45)
        ic.line([(21 + 3.4 * math.cos(ang), 21.5 + 3.4 * math.sin(ang)), (21 + 4.6 * math.cos(ang), 21.5 + 4.6 * math.sin(ang))], INK_SOFT, 0.5)
    ic.circle(28.5, 21.5, 3, INK_SOFT, shade=False)
    ic.circle(29.8, 20.8, 2.6, OLDPAPER, shade=False)
    ic.line([(17, 27), (30, 27)], INK_SOFT, 0.5)
    squiggle(ic, 17, 30, 30, INK_SOFT, 0.6, 0.4, 1.1)
    squiggle(ic, 17, 30, 32.5, INK_SOFT, 0.6, 0.4, 1.1)
    squiggle(ic, 19, 28, 35, RED_D, 0.7, 0.4, 1.1)
    ic.line([(21, 37.6), (26, 37.6)], INK_SOFT, 0.5)
    # age: foxing and a worn corner
    ic.speckle((12, 5, 37, 41), (200, 168, 110), 10, 0.5)
    ic.poly([(38, 36), (38, 42), (32, 42)], OLDPAPER_D, shade=False)
    ic.line([(32, 42), (38, 36)], mul(OLDPAPER_D, 0.8), 0.5)
    glint(ic, 36, 5, 2.2)
    ic.save("relic_poor_richard")


def revere_lantern():
    ic = Icon(seed=106)
    ic.shadow(24, 45, 13, 2.5)
    # warm rays behind
    for ang in (200, 235, 270, 305, 340, 20, 160):
        a = math.radians(ang)
        ic.line([(24 + 15 * math.cos(a), 27 + 15 * math.sin(a)), (24 + 19 * math.cos(a), 27 + 19 * math.sin(a))], STRAW, 1.3)
    tin = (176, 180, 186)
    # ring handle
    ring(ic, (19, 0, 29, 9), (21, 2, 27, 7), tin, light=0.4, dark=0.4)
    # conical top pierced with a row of holes
    ic.poly([(12, 18), (21, 8), (27, 8), (36, 18)], tin, light=0.35, dark=0.4)
    ic.rect((20, 6, 28, 9), mul(tin, 0.9), light=0.2, dark=0.3)
    for x, y in ((18, 15), (21.5, 14.5), (26.5, 14.5), (30, 15), (24, 11.5)):
        ic.dot(x, y, GLOW, 0.6)
    ic.rect((11, 17, 37, 20), mul(tin, 1.02), light=0.3, dark=0.3)
    # cylinder body
    ic.rect((13, 20, 35, 41), tin, light=0.35, dark=0.45)
    # pierced patterns: arches and diamonds glowing from the candle inside
    def holes(pts):
        for x, y in pts:
            ic.dot(x, y, FLAME, 0.75)
            ic.dot(x - 0.2, y - 0.2, GLOW, 0.35)
    holes([(24 + 7 * math.cos(math.radians(a)), 30 + 6 * math.sin(math.radians(a))) for a in range(180, 361, 30)])
    holes([(24, 25), (21, 30), (27, 30), (24, 35), (24, 30), (22.5, 27.5), (25.5, 27.5), (22.5, 32.5), (25.5, 32.5)])
    holes([(16, 23), (16, 27), (16, 31), (16, 35), (32, 23), (32, 27), (32, 31), (32, 35)])
    holes([(18.5, 38), (21.5, 38), (24.5, 38), (27.5, 38), (30.5, 38)])
    # seams, door hinge and base band
    ic.line([(14, 21), (14, 40)], (220, 224, 230), 0.7)
    ic.rect((33, 24, 35.5, 26.5), mul(tin, 0.7), shade=False)
    ic.rect((33, 34, 35.5, 36.5), mul(tin, 0.7), shade=False)
    ic.rect((11, 40, 37, 44), mul(tin, 0.95), light=0.3, dark=0.4)
    ic.line([(12, 40.7), (36, 40.7)], (224, 226, 232), 0.6)
    glint(ic, 15, 18, 2.2)
    ic.save("relic_revere_lantern")


def tea_chest():
    ic = Icon(seed=107)
    ic.shadow(24, 44, 22, 2.5)
    wood = (184, 132, 80)
    # top
    ic.poly([(4, 17), (13, 10), (44, 10), (35, 17)], mul(wood, 1.15), light=0.15, dark=0.15)
    # side
    ic.poly([(35, 17), (44, 10), (44, 34), (35, 42)], mul(wood, 0.68), light=0.1, dark=0.2)
    # front
    ic.rect((4, 17, 35, 42), wood, light=0.2, dark=0.3)
    # board seams
    for y in (25.5, 33.8):
        ic.line([(4, y), (35, y)], mul(wood, 0.7), 0.6)
    ic.line([(35, 25), (44, 18)], mul(wood, 0.5), 0.5)
    ic.line([(35, 33.5), (44, 26)], mul(wood, 0.5), 0.5)
    # edge battens
    for poly in ([(4, 17), (6, 17), (6, 42), (4, 42)], [(33, 17), (35, 17), (35, 42), (33, 42)]):
        ic.poly(poly, mul(wood, 0.82), shade=False)
    ic.line([(4.5, 17.3), (34.5, 17.3)], mul(wood, 1.3), 0.7)
    # stencilled export marks: a chop seal and characters in red and black
    ic.circle(13, 24, 4.2, RED_D, shade=False)
    ic.circle(13, 24, 3.2, wood, shade=False)
    ic.line([(11, 22.5), (15, 22.5)], RED_D, 0.8)
    ic.line([(13, 21.5), (13, 26.8)], RED_D, 0.8)
    ic.line([(11.2, 25.5), (14.8, 25.5)], RED_D, 0.7)
    for cx, cy in ((22, 21.5), (28.5, 21.5)):
        ic.line([(cx - 2, cy), (cx + 2, cy)], INK, 0.9)
        ic.line([(cx, cy - 1.8), (cx, cy + 3)], INK, 0.9)
        ic.line([(cx - 2, cy + 2.8), (cx - 0.5, cy + 1.2)], INK, 0.8)
        ic.line([(cx + 2, cy + 2.8), (cx + 0.5, cy + 1.2)], INK, 0.8)
    for cx in (12, 19, 26):
        ic.line([(cx - 1.8, 29), (cx + 1.8, 29)], INK, 0.8)
        ic.line([(cx - 1.2, 31.2), (cx + 1.2, 28)], INK, 0.8)
        ic.line([(cx, 28), (cx + 0.8, 32)], INK, 0.8)
    ic.line([(9, 37.5), (29, 37.5)], RED_D, 1.1)
    # lid ajar a touch, leaves spilling out and on the ground
    ic.line([(13, 10.3), (44, 10.3)], mul(wood, 1.35), 0.7)
    for x, y, a in ((39, 43.5, 20), (44, 40, -30), (5, 44.5, 60), (42, 45, 100), (31, 45, -10)):
        leaf = rot([(-2.2, 0), (0, -1), (2.2, 0), (0, 1)], x, y, math.radians(a))
        ic.poly(leaf, TEA, light=0.3, dark=0.2)
    ic.dot(39.5, 43, TEA_L, 0.4)
    # corner irons
    for x, y in ((4, 17), (4, 40), (33, 17), (33, 40)):
        ic.rect((x, y, x + 2, y + 2), IRON, shade=False)
    ic.speckle((6, 18, 33, 41), mul(wood, 0.85), 14, 0.4)
    glint(ic, 13, 11, 2.2)
    ic.save("relic_tea_chest")


def syng_inkstand():
    ic = Icon(seed=108)
    SIL = (184, 184, 186)   # old silver, a little warm with age
    ic.shadow(24, 44, 22, 2.5)
    # a barred goose quill, drawn first so it sits in the left pot
    ic.line([(14, 26), (8, 8), (5, 1)], (240, 236, 224), 1.0)
    vane = [(13, 22), (8.5, 14), (5, 7), (2.5, 0.5), (7, 3), (11, 9), (14, 17)]
    ic.poly(vane, (232, 222, 198), light=0.15, dark=0.25)
    for y in (4.5, 8.5, 12.5, 16.5):
        ic.line([(4.6 + (y - 1) * 0.36, y), (7.4 + (y - 1) * 0.36, y - 1.6)], (150, 110, 70), 0.9)
    ic.line([(13, 23), (4, 1)], (170, 150, 120), 0.5)
    # tray on four scroll feet
    for x in (6, 16, 31, 41):
        ic.circle(x, 42, 2.2, SIL, light=0.4, dark=0.35)
    ic.rect((3, 35, 45, 42), SIL, radius=3, light=0.35, dark=0.4)
    ic.rect((5, 36, 43, 38.5), mul(SIL, 1.06), radius=1.5, shade=False)
    ic.line(ell_pts(24, 40, 18, 1.4, 20, 160, 10), SILVER_D, 0.6)
    # three vessels: inkwell, bell-topped caster, sander

    def pot(cx, top):
        ic.rect((cx - 5.5, top + 4, cx + 5.5, 37), SIL, light=0.4, dark=0.45)
        ic.ellipse((cx - 6.5, 34, cx + 6.5, 38), SIL, light=0.3, dark=0.4)
        ic.ellipse((cx - 6, top + 1.5, cx + 6, top + 6), SIL, light=0.4, dark=0.4)
        ic.line(ell_pts(cx, top + 10, 5.5, 1.2, 10, 170, 8), SILVER_D, 0.6)
        ic.line([(cx - 3.5, top + 6), (cx - 3.5, 35)], WHITE, 0.8)
    pot(13, 22)
    ic.ellipse((9.5, 23, 16.5, 26), (30, 30, 44), shade=False)   # open ink
    pot(35, 22)
    ic.poly(ell_pts(35, 24, 5.5, 5, 180, 360, 12), SIL, light=0.4, dark=0.35)
    for x, y in ((33, 22), (35, 21), (37, 22), (34, 20)):
        ic.dot(x, y, SILVER_D, 0.4)
    ic.circle(35, 18.5, 1.6, SIL, light=0.4, dark=0.3)
    # central caster with a domed lid and finial
    ic.rect((21, 22, 27, 37), SIL, light=0.4, dark=0.4)
    ic.ellipse((19.5, 17, 28.5, 25), SIL, light=0.45, dark=0.35)
    ic.rect((23, 12.5, 25, 18), SIL, shade=False)
    ic.circle(24, 12, 2, SIL, light=0.4, dark=0.3)
    ic.line([(22.5, 23), (22.5, 35)], WHITE, 0.7)
    ic.dot(22, 19.5, WHITE, 0.7)
    # warm reflection of candlelight
    ic.line([(40, 26), (40, 34)], (250, 226, 170), 0.6)
    glint(ic, 29, 8, 2.6)
    ic.save("relic_syng_inkstand", colors=36)


def common_sense():
    ic = Icon(seed=109)
    ic.shadow(25, 44, 18, 2.5)
    ang = math.radians(-7)
    cx, cy = 24, 24

    def R(pts):
        return rot([(x - cx, y - cy) for x, y in pts], cx, cy, ang)
    # stitched pamphlet: back pages then cover
    ic.poly(R([(11, 5), (39, 5), (39, 45), (11, 45)]), OLDPAPER_D, light=0.1, dark=0.2)
    ic.poly(R([(9, 3), (37, 3), (37, 43), (9, 43)]), CREAM, light=0.12, dark=0.3)
    # dog-eared corner
    ic.poly(R([(31, 43), (37, 37), (37, 43)]), OLDPAPER_D, shade=False)
    ic.poly(R([(31, 43), (37, 37), (32.5, 38.5)]), OLDPAPER, shade=False)
    # heading lines
    for y, a, b, w in ((7, 15, 31, 0.6), (9.5, 17, 29, 0.6)):
        ic.line(R([(a, y), (b, y)]), INK_SOFT, w)
    # bold title block in a double-ruled box
    ic.poly(R([(11.5, 12), (34.5, 12), (34.5, 26), (11.5, 26)]), INK, shade=False)
    ic.poly(R([(12.5, 13), (33.5, 13), (33.5, 25), (12.5, 25)]), CREAM, shade=False)
    ic.poly(R([(13.5, 14), (32.5, 14), (32.5, 24), (13.5, 24)]), INK, shade=False)
    for y, a, b in ((16.8, 16, 30), (21.2, 17, 29)):
        pts = R([(a + i * 1.4, y + (0.6 if i % 2 else -0.6)) for i in range(int((b - a) / 1.4) + 1)])
        ic.line(pts, CREAM, 1.3)
    # body text beneath
    for y, a, b in ((29, 13, 33), (31.5, 15, 31), (34, 13, 33)):
        pts = R([(a + i * 1.2, y + (0.4 if i % 2 else -0.4)) for i in range(int((b - a) / 1.2) + 1)])
        ic.line(pts, INK_SOFT, 0.6)
    ic.line(R([(18, 38), (28, 38)]), INK_SOFT, 0.5)
    ic.line(R([(21, 40), (25, 40)]), INK_SOFT, 0.8)
    ic.speckle((10, 4, 37, 43), OLDPAPER, 12, 0.5)
    glint(ic, 38, 7, 2.3)
    ic.save("relic_common_sense")


def knox_cannon():
    ic = Icon(seed=110)
    ic.shadow(24, 44, 22, 2.5)
    # ox sled: two runners curling up at the front, crossbars
    for dy, col in ((0, WOOD_D), (3, WOOD)):
        ic.line([(3, 38 + dy), (34, 38 + dy), (40, 37 + dy), (44, 33 + dy), (45, 30 + dy)], col, 2.4)
    ic.line([(4, 38.2), (33, 38.2)], WOOD_L, 0.6)
    for x in (8, 18, 28, 37):
        ic.rect((x, 32, x + 3, 38), WOOD, light=0.3, dark=0.3)
    # wooden cradle / carriage cheek
    ic.poly([(7, 33), (10, 27), (31, 27), (36, 31), (36, 34), (7, 34)], WOOD, light=0.25, dark=0.35)
    ic.line([(10, 28), (31, 28)], WOOD_L, 0.6)
    ic.circle(15, 31, 1.1, IRON_D, shade=False)
    ic.circle(29, 31, 1.1, IRON_D, shade=False)
    # bronze barrel, slightly raised to the right
    a = math.radians(-8)
    cx, cy = 22, 22

    def R(pts):
        return rot(pts, cx, cy, a)
    body = R([(-16, -5), (-6, -5.2), (8, -4.2), (19, -3.4), (19, 3.4), (8, 4.2), (-6, 5.2), (-16, 5)])
    ic.poly(body, BRONZE, light=0.35, dark=0.4)
    # reinforcing rings and muzzle swell
    for x, h in ((-13, 5.6), (-6, 5.6), (6, 4.8), (16, 3.9)):
        ic.poly(R([(x - 0.9, -h), (x + 0.9, -h), (x + 0.9, h), (x - 0.9, h)]), BRONZE_L, light=0.3, dark=0.45)
    ic.poly(R([(18, -4.6), (22, -4.6), (22, 4.6), (18, 4.6)]), BRONZE, light=0.4, dark=0.4)
    mx, my = R([(22, 0)])[0]
    ic.ellipse((mx - 1.4, my - 4.6, mx + 1.4, my + 4.6), BRONZE_D, shade=False)
    ic.ellipse((mx - 0.6, my - 2.6, mx + 1.0, my + 2.6), (40, 26, 16), shade=False)
    # cascabel knob
    kx, ky = R([(-18.5, 0)])[0]
    ic.circle(kx, ky, 2.4, BRONZE, light=0.4, dark=0.4)
    ic.line([R([(-16, 0)])[0], (kx, ky)], BRONZE_D, 1.4)
    # trunnion
    tx, ty = R([(0, 1.5)])[0]
    ic.circle(tx, ty, 2.2, BRONZE_D, light=0.3, dark=0.3)
    # highlight along the top and a verdigris touch
    ic.line(R([(-14, -3.4), (17, -2.2)]), BRONZE_L, 0.9)
    ic.line(R([(-12, -2.4), (-2, -2.6)]), (250, 220, 150), 0.6)
    ic.dot(*R([(3, 3)])[0], (110, 150, 120), 0.6)
    # winter: snow along the sled and on the barrel
    ic.line([(3, 36.8), (9, 36.6)], SNOW, 1.0)
    ic.line([(34, 36.5), (40, 35.8)], SNOW, 1.0)
    ic.line(R([(-9, -5.4), (-3, -5.6)]), SNOW, 1.0)
    for x, y in ((6, 8), (14, 4), (38, 7), (44, 14), (30, 3)):
        ic.dot(x, y, SNOW, 0.7)
    glint(ic, 36, 12, 2.4)
    ic.save("relic_knox_cannon")


def mason_dixon():
    ic = Icon(seed=111)
    ic.shadow(24, 45, 20, 2.5)
    # tripod legs
    for foot in ((5, 46), (43, 46)):
        thick_line(ic, [(24, 30), foot], WOOD, 2.6, light=0.3, dark=0.3)
    thick_line(ic, [(24, 30), (26, 46)], WOOD_D, 2.2, light=0.2, dark=0.3)
    for foot in ((5, 46), (43, 46), (26, 46)):
        ic.circle(foot[0], foot[1] - 1, 1.1, BRASS_D, shade=False)
    # tripod head and levelling plate
    ic.ellipse((15, 27, 33, 32), BRASS_D, light=0.2, dark=0.2)
    ic.ellipse((15, 25.5, 33, 30.5), BRASS, light=0.4, dark=0.35)
    ic.line(ell_pts(24, 28, 8.4, 2.1, 190, 350, 12), BRASS_L, 0.5)
    # standards (A-frame yoke)
    ic.poly([(17, 27), (19.5, 15), (22, 15), (21, 27)], BRASS, light=0.35, dark=0.35)
    ic.poly([(27, 27), (26, 15), (28.5, 15), (31, 27)], BRASS, light=0.35, dark=0.35)
    # vertical graduated arc
    ic.arc((13, 6, 35, 28), 200, 340, BRASS_D, 1.6)
    ic.arc((13, 6, 35, 28), 200, 340, BRASS_L, 0.5)
    for i in range(8):
        t = math.radians(205 + i * 18)
        ic.dot(24 + 11 * math.cos(t), 17 + 11 * math.sin(t), INK_SOFT, 0.35)
    # telescope tube tilted toward the sky
    a = math.radians(-14)
    cx, cy = 24, 15

    def R(pts):
        return rot(pts, cx, cy, a)
    ic.poly(R([(-21, -1.6), (-12, -1.9), (-12, 1.9), (-21, 1.6)]), BRASS_D, light=0.3, dark=0.3)  # eyepiece
    ic.poly(R([(-13, -2.8), (16, -3.4), (16, 3.4), (-13, 2.8)]), BRASS, light=0.4, dark=0.45)
    ic.poly(R([(15, -4.2), (21, -4.2), (21, 4.2), (15, 4.2)]), BRASS, light=0.4, dark=0.4)  # dew cap
    for x in (-8, 0, 9):
        ic.line(R([(x, -3), (x, 3)]), BRASS_D, 0.6)
    ic.line(R([(-12, -1.8), (15, -2.3)]), BRASS_L, 0.8)
    ox, oy = R([(21, 0)])[0]
    ic.ellipse((ox - 1.2, oy - 4, ox + 1.2, oy + 4), (60, 90, 120), shade=False)
    ic.dot(ox, oy - 1.5, SKY, 0.5)
    # spirit level on top
    ic.poly(R([(-6, -5.6), (6, -5.8), (6, -3.2), (-6, -3.2)]), BRASS_D, shade=False)
    ic.poly(R([(-4.8, -5.1), (4.8, -5.2), (4.8, -3.7), (-4.8, -3.7)]), (160, 210, 180), shade=False)
    ic.dot(*R([(1, -4.4)])[0], WHITE, 0.5)
    ic.circle(24, 15, 1.8, BRASS_D, light=0.3, dark=0.3)
    # a star sighted
    glint(ic, 43, 3, 2.8, (240, 240, 200))
    glint(ic, 9, 25, 2.0)
    ic.save("relic_mason_dixon")


def orrery():
    ic = Icon(seed=112)
    ic.shadow(24, 45, 14, 2.5)
    # turned wooden foot and brass column
    ic.ellipse((13, 39, 35, 45), MAHOG, light=0.3, dark=0.35)
    ic.rect((15, 37, 33, 42), MAHOG, light=0.3, dark=0.35)
    ic.ellipse((15, 35, 33, 39.5), MAHOG_L, light=0.2, dark=0.3)
    ic.rect((22, 29, 26, 37), BRASS, light=0.4, dark=0.4)
    ic.ellipse((20, 33, 28, 36.5), BRASS, light=0.35, dark=0.35)
    cy0 = 29
    # zodiac ring: slim flat ellipse of brass with engraved ticks
    ring(ic, (2, 23, 46, 35), (4.3, 24.8, 43.7, 33.2), BRASS, light=0.35, dark=0.45)
    for i in range(24):
        t = math.radians(i * 15)
        ic.dot(24 + 21 * math.cos(t), cy0 + 5.5 * math.sin(t), BRASS_D, 0.3)
    # planets on crank arms, raised on posts above the ring plane
    planets = [
        (290, 7, 6, (200, 196, 186), 1.8),    # mercury
        (335, 12, 7, (246, 222, 150), 2.4),   # venus
        (150, 14, 6, (64, 128, 206), 2.8),    # earth
        (30, 17, 5, (214, 84, 52), 2.4),      # mars
        (200, 19, 9, (226, 176, 116), 3.4),   # jupiter
    ]
    pos = []
    for ang, rr, h, col, pr in planets:
        t = math.radians(ang)
        px, py = 24 + rr * math.cos(t), cy0 + rr * 0.27 * math.sin(t)
        pos.append((px, py - h))
        ic.line([(24, cy0 - 1), (px, py)], BRASS_D, 0.8)
        ic.line([(px, py), (px, py - h)], BRASS_D, 0.7)
    back = [i for i in range(len(planets)) if math.sin(math.radians(planets[i][0])) < 0]
    front = [i for i in range(len(planets)) if i not in back]

    def planet(i):
        px, py = pos[i]
        pr, col = planets[i][4], planets[i][3]
        ic.circle(px, py, pr, col, light=0.45, dark=0.45)
        ic.dot(px - pr * 0.35, py - pr * 0.35, WHITE, 0.5)
    for i in back:
        planet(i)
    # sun on its post
    ic.rect((23.2, 14, 24.8, cy0), BRASS_D, shade=False)
    ic.circle(24, 12, 5.2, GOLD, light=0.4, dark=0.35)
    for i in range(12):
        t = math.radians(i * 30)
        ic.line([(24 + 6 * math.cos(t), 12 + 6 * math.sin(t)), (24 + 7.8 * math.cos(t), 12 + 7.8 * math.sin(t))], GOLD, 0.9)
    ic.dot(22.2, 10.2, (255, 246, 190), 1.3)
    for i in front:
        planet(i)
    # earth's moon and jupiter's bands
    ex, ey = pos[2]
    ic.circle(ex - 3.8, ey - 2.4, 1.0, SILVER, shade=False)
    jx, jy = pos[4]
    ic.line([(jx - 3, jy + 0.6), (jx + 3, jy + 0.6)], (160, 108, 70), 0.6)
    ic.line([(jx - 2.6, jy - 1), (jx + 2.6, jy - 1)], (190, 140, 96), 0.5)
    glint(ic, 41, 8, 2.4)
    ic.save("relic_orrery")


def chronometer():
    ic = Icon(seed=113)
    ic.shadow(24, 45, 16, 2.5)
    cx, cy, r = 24, 27, 18
    # bow and pendant crown
    ring(ic, (18, 0, 30, 9), (20.5, 2.2, 27.5, 7), SILVER, light=0.4, dark=0.4)
    ic.rect((21.5, 6, 26.5, 10.5), SILVER, light=0.4, dark=0.4)
    for x in (22.5, 24, 25.5):
        ic.line([(x, 6.5), (x, 10)], SILVER_D, 0.4)
    ic.rect((22.5, 9.5, 25.5, 11), SILVER_D, shade=False)
    # case: thick silver rim
    ic.circle(cx, cy, r, SILVER, light=0.4, dark=0.45)
    ic.circle(cx, cy, r - 2.2, SILVER_D, shade=False)
    ic.arc((cx - r + 0.8, cy - r + 0.8, cx + r - 0.8, cy + r - 0.8), 190, 250, WHITE, 0.8)
    # white enamel dial
    ic.circle(cx, cy, r - 3.2, ENAMEL, light=0.12, dark=0.2)
    # chapter ring and hour marks
    ic.arc((cx - 12.6, cy - 12.6, cx + 12.6, cy + 12.6), 0, 360, INK_SOFT, 0.4)
    for i in range(12):
        t = math.radians(i * 30 - 90)
        x0, y0 = cx + 11 * math.cos(t), cy + 11 * math.sin(t)
        x1, y1 = cx + 13.6 * math.cos(t), cy + 13.6 * math.sin(t)
        ic.line([(x0, y0), (x1, y1)], INK, 1.0 if i % 3 == 0 else 0.6)
    # engraved floral centre, as on H4's dial
    for i in range(6):
        t = math.radians(i * 60 + 15)
        ic.ellipse((cx + 4 * math.cos(t) - 1.6, cy + 4 * math.sin(t) - 1.6, cx + 4 * math.cos(t) + 1.6, cy + 4 * math.sin(t) + 1.6),
                   (216, 200, 150), shade=False)
    ic.circle(cx, cy, 2, (200, 170, 100), shade=False)
    # small seconds dial
    ic.arc((cx - 3.5, cy + 4.5, cx + 3.5, cy + 11.5), 0, 360, INK_SOFT, 0.5)
    ic.line([(cx, cy + 8), (cx + 1.5, cy + 6)], BLUED, 0.5)
    # blued steel hands (10:10)
    ic.line([(cx, cy), (cx - 6.5, cy - 4)], BLUED, 1.4)
    ic.line([(cx, cy), (cx + 8, cy - 8.5)], BLUED, 1.0)
    ic.dot(cx - 6, cy - 3.7, BLUED, 1.1)
    ic.circle(cx, cy, 1.4, BLUED, shade=False)
    ic.dot(cx - 0.4, cy - 0.4, SKY, 0.4)
    # glass reflection
    ic.arc((cx - 13.5, cy - 13.5, cx + 13.5, cy + 13.5), 200, 240, WHITE, 1.0)
    glint(ic, 38, 13, 2.6)
    ic.save("relic_chronometer", colors=36)


def franklinia():
    ic = Icon(seed=114)
    ic.shadow(24, 45, 16, 2.5)
    # branch
    thick_line(ic, [(8, 46), (14, 38), (21, 30), (27, 22)], BARK, 2.2, light=0.3, dark=0.3)
    ic.line([(16, 36), (9, 32)], BARK, 1.3)
    # glossy leaves
    def leaf(base, tip, wdt, col):
        bx, by = base
        tx, ty = tip
        dx, dy = tx - bx, ty - by
        ln = math.hypot(dx, dy)
        nx, ny = -dy / ln, dx / ln
        pts = []
        for i in range(9):
            t = i / 8
            w = math.sin(math.pi * t) * wdt * (1 - 0.3 * t)
            pts.append((bx + dx * t + nx * w, by + dy * t + ny * w))
        for i in range(8, -1, -1):
            t = i / 8
            w = math.sin(math.pi * t) * wdt * (1 - 0.3 * t)
            pts.append((bx + dx * t - nx * w, by + dy * t - ny * w))
        ic.poly(pts, col, light=0.35, dark=0.35)
        ic.line([(bx, by), (bx + dx * 0.9, by + dy * 0.9)], mul(col, 1.35), 0.5)
    leaf((15, 37), (2, 24), 4.2, LEAF_D)
    leaf((20, 31), (38, 36), 4.0, LEAF)
    leaf((22, 28), (9, 12), 3.6, LEAF)
    # woody seed capsules at the base
    for x, y in ((6, 34.5), (11, 31.5)):
        ic.circle(x, y, 2.6, (132, 92, 56), light=0.35, dark=0.4)
        ic.line([(x - 1.6, y), (x + 1.6, y)], (84, 56, 34), 0.5)
        ic.line([(x, y - 1.6), (x, y + 1.6)], (84, 56, 34), 0.5)
    # white cup-shaped bloom, five crinkled petals
    fx, fy = 31, 15
    for i in range(5):
        t = math.radians(i * 72 - 90 + 10)
        px, py = fx + 7.2 * math.cos(t), fy + 7.2 * math.sin(t)
        ic.circle(px, py, 6.2, PETAL, light=0.1, dark=0.28)
        ic.line([(fx + 3 * math.cos(t), fy + 3 * math.sin(t)), (fx + 10 * math.cos(t), fy + 10 * math.sin(t))], PETAL_D, 0.4)
    for i in range(5):
        t = math.radians(i * 72 - 90 + 46)
        ic.line([(fx + 4 * math.cos(t), fy + 4 * math.sin(t)), (fx + 7.5 * math.cos(t), fy + 7.5 * math.sin(t))], PETAL_D, 0.6)
    # golden boss of stamens
    ic.circle(fx, fy, 4.4, STRAW, light=0.35, dark=0.3)
    ic.speckle((fx - 4, fy - 4, fx + 4, fy + 4), GOLD, 10, 0.45)
    ic.speckle((fx - 4, fy - 4, fx + 4, fy + 4), STRAW_D, 6, 0.4)
    ic.dot(fx - 1.4, fy - 1.4, (255, 240, 170), 0.8)
    # a bud
    ic.ellipse((34, 29, 40, 35), (230, 232, 212), light=0.2, dark=0.3)
    ic.poly([(34.5, 33), (37, 36.5), (39.5, 33), (37, 34.5)], LEAF_D, shade=False)
    ic.line([(26, 25), (35, 34)], BARK, 0.9)
    glint(ic, 44, 5, 2.3)
    ic.save("relic_franklinia")


def banneker_almanac():
    ic = Icon(seed=115)
    ic.shadow(24, 45, 20, 2.5)
    # book lying at a slight 3/4: page block along the bottom and right
    ic.poly([(8, 7), (41, 4), (44, 7), (44, 41), (12, 45), (8, 42)], PARCH, light=0.1, dark=0.2)
    for y in (42, 43.4):
        ic.line([(12, y + 0.3), (43.5, y - 3.5)], PARCH_D, 0.5)
    ic.line([(42, 6), (42, 39)], PARCH_D, 0.5)
    # cover
    cover = [(4, 6), (39, 3), (40, 38), (6, 42)]
    ic.poly(cover, LEATHER_B, light=0.3, dark=0.35)
    # spine band
    ic.poly([(4, 6), (8, 5.6), (10, 41.5), (6, 42)], LEATHER_BD, light=0.2, dark=0.2)
    for y in (11, 20, 29, 37):
        ic.line([(4.6, y - 0.3), (9, y - 0.6)], GOLD_D, 0.6)
    # gilt border
    ic.line([(12, 7.2), (36, 5.2), (36.8, 35.6), (13, 38.6), (12, 7.2)], GOLD_D, 0.7)
    # star chart: ecliptic ring with a sun at the centre
    cx, cy = 24.5, 21.5
    ic.arc((cx - 10, cy - 10, cx + 10, cy + 10), 0, 360, GOLD, 1.1)
    ic.arc((cx - 7.6, cy - 7.6, cx + 7.6, cy + 7.6), 0, 360, GOLD_D, 0.5)
    for i in range(12):
        t = math.radians(i * 30)
        ic.line([(cx + 7.8 * math.cos(t), cy + 7.8 * math.sin(t)), (cx + 9.6 * math.cos(t), cy + 9.6 * math.sin(t))], GOLD_D, 0.5)
    ic.circle(cx, cy, 2.8, GOLD, light=0.4, dark=0.3)
    for i in range(8):
        t = math.radians(i * 45 + 22)
        ic.line([(cx + 3.4 * math.cos(t), cy + 3.4 * math.sin(t)), (cx + 5.4 * math.cos(t), cy + 5.4 * math.sin(t))], GOLD, 0.6)
    # crescent moon and stars on the ring
    ic.circle(cx + 10 * math.cos(math.radians(-40)), cy + 10 * math.sin(math.radians(-40)), 1.8, SILVER, shade=False)
    ic.circle(cx + 10 * math.cos(math.radians(-40)) + 0.9, cy + 10 * math.sin(math.radians(-40)) - 0.6, 1.5, LEATHER_B, shade=False)
    for t, s in ((150, 1.6), (215, 1.3), (95, 1.2)):
        a = math.radians(t)
        glint(ic, cx + 10 * math.cos(a), cy + 10 * math.sin(a), s + 0.6, GOLD)
    # constellation dots
    for x, y in ((15, 10), (17, 12.5), (33, 10), (31.5, 9), (15, 33), (33, 32)):
        ic.dot(x, y, (220, 200, 140), 0.45)
    # title plate
    ic.poly([(16.5, 33.6), (32.5, 32.2), (32.5, 35.4), (16.6, 36.8)], GOLD_D, shade=False)
    ic.line([(18, 35), (31, 33.8)], LEATHER_BD, 0.5)
    glint(ic, 38, 6, 2.4)
    ic.save("relic_banneker_almanac")


ALL = [kite_key, franklin_stove, armonica, bifocals, poor_richard,
       revere_lantern, tea_chest, syng_inkstand, common_sense, knox_cannon,
       mason_dixon, orrery, chronometer, franklinia, banneker_almanac]
NAMES = ["relic_" + f.__name__ for f in ALL]


if __name__ == "__main__":
    for f in ALL:
        f()
    if len(sys.argv) > 1:
        sheet(NAMES, sys.argv[1], scale=4, cols=5)
