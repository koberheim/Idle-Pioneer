"""Store and launcher icons plus the Play Store feature graphic, drawn in the
high-density pixel style of tools/hd/lib.py and scaled up with NEAREST.

Run: python tools/gen_app_icons.py [review_dir]

Writes
    assets/icons/app_icon_1024.png              1024 opaque RGB (App Store)
    assets/icons/app_icon_512.png               512 opaque RGB (Play listing)
    assets/icons/android_adaptive_foreground.png   432 RGBA, subject in the safe circle
    assets/icons/android_adaptive_background.png   432 opaque RGB
    assets/icons/android_adaptive_monochrome.png   432 RGBA, white silhouette
    assets/icons/feature_graphic_1024x500.png   1024x500 opaque RGB
    assets/sprites/app_icon.png                 256 RGBA (Godot project icon)

The icon is designed on a 128 px grid: a bastioned star fort on a green
headland, a gold crowned coin rising as the sun behind it, and a three-masted
ship on the sea. Background (sky, sea) and foreground (land, fort, ship, coin)
are rendered separately so the foreground gets the tinted outline and the
two can double as the Android adaptive layers.
"""
import math
import os
import random
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "hd"))
from lib import *  # noqa: E402,F401,F403
from lib import SS, add_outline  # noqa: E402

ROOT = os.path.dirname(HERE)
ICONS = os.path.join(ROOT, "assets", "icons")
SPRITES = os.path.join(ROOT, "assets", "sprites")

SKY_TOP = (78, 128, 196)
SKY_MID = (132, 178, 220)
SKY_LOW = (240, 216, 168)
SEA_TOP = (70, 132, 170)
SEA_BOT = (30, 70, 118)
FOAM = (236, 244, 240)
STONE = (176, 164, 140)
STONE_D = (116, 104, 88)
ROCK = (132, 112, 90)
SAND = (228, 204, 146)
GRASS = (98, 164, 70)
GRASS_D = (60, 118, 54)
ROOF = (170, 70, 48)
HILL_FAR = (112, 150, 150)
PINE_D = (38, 84, 56)
PINE_M = (56, 110, 64)


class Canvas(Icon):
    """An Icon of any width and height."""

    def __init__(self, w, h, seed=1):
        self.n = w
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
        self.rnd = random.Random(seed)

    def render(self, colors=64, outline=INK):
        w, h = self.w, self.h
        small = self.img.resize((w, h), Image.BOX)
        a = small.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
        rgb = small.convert("RGB")
        q = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
        out = q.convert("RGBA")
        out.putalpha(a)
        if outline is not None:
            out = add_outline(out, outline)
        return out


class X:
    """Draw on a canvas through an offset and scale (design coordinates)."""

    def __init__(self, ic, ox=0.0, oy=0.0, k=1.0):
        self.ic, self.ox, self.oy, self.k = ic, ox, oy, k

    def p(self, x, y):
        return (self.ox + x * self.k, self.oy + y * self.k)

    def poly(self, pts, c, shade=True, **kw):
        self.ic.poly([self.p(*q) for q in pts], c, shade, **kw)

    def rect(self, box, c, shade=True, radius=0, **kw):
        x0, y0 = self.p(box[0], box[1])
        x1, y1 = self.p(box[2], box[3])
        self.ic.rect((x0, y0, x1, y1), c, shade, radius * self.k, **kw)

    def ellipse(self, box, c, shade=True, **kw):
        x0, y0 = self.p(box[0], box[1])
        x1, y1 = self.p(box[2], box[3])
        self.ic.ellipse((x0, y0, x1, y1), c, shade, **kw)

    def circle(self, cx, cy, r, c, shade=True, **kw):
        self.ellipse((cx - r, cy - r, cx + r, cy + r), c, shade, **kw)

    def line(self, pts, c, width=1.0):
        self.ic.line([self.p(*q) for q in pts], c, width * self.k)

    def dot(self, x, y, c, r=0.5):
        self.circle(x, y, r, c, shade=False)

    def erase_poly(self, pts):
        from PIL import ImageDraw
        ImageDraw.Draw(self.ic.img).polygon([(x * SS, y * SS) for x, y in (self.p(*q) for q in pts)], fill=(0, 0, 0, 0))

    def erase_circle(self, cx, cy, r):
        from PIL import ImageDraw
        x0, y0 = self.p(cx - r, cy - r)
        x1, y1 = self.p(cx + r, cy + r)
        ImageDraw.Draw(self.ic.img).ellipse([x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1], fill=(0, 0, 0, 0))


def star_pts(cx, cy, ro, ri, n=5, ys=0.55, a0=90.0):
    pts = []
    for i in range(n * 2):
        a = math.radians(a0 + i * 180.0 / n)
        r = ro if i % 2 == 0 else ri
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r * ys))
    return pts


# -- shared elements (design coordinates) ----------------------------------
def sky(d, x0, x1, y0, y1, bands=10):
    for i in range(bands):
        t = i / (bands - 1)
        c = mix(SKY_TOP, SKY_MID, t / 0.55) if t < 0.55 else mix(SKY_MID, SKY_LOW, (t - 0.55) / 0.45)
        ya = y0 + (y1 - y0) * i / bands
        d.rect((x0, ya, x1, ya + (y1 - y0) / bands + 0.6), c, shade=False)


def sea(d, x0, x1, y0, y1, rnd, bands=6, glints=40):
    for i in range(bands):
        t = i / (bands - 1)
        ya = y0 + (y1 - y0) * i / bands
        d.rect((x0, ya, x1, ya + (y1 - y0) / bands + 0.6), mix(SEA_TOP, SEA_BOT, t), shade=False)
    d.rect((x0, y0, x1, y0 + 1.2), mix(SEA_TOP, SKY_LOW, 0.45), shade=False)
    for _ in range(glints):
        x = rnd.uniform(x0, x1)
        y = rnd.uniform(y0 + 3, y1)
        t = (y - y0) / (y1 - y0)
        L = 2 + 5 * t
        d.line([(x, y), (x + L, y)], mix(SEA_TOP, FOAM, 0.55 - 0.25 * t), 0.7 + 0.5 * t)


def cloud(d, x, y, s=1.0):
    for dx, dy, r in ((0, 0, 5), (6, -2.5, 6), (13, 0, 5), (6, 2, 5.5), (-5, 2, 3.5), (18, 2, 3.5)):
        d.circle(x + dx * s, y + dy * s, r * s, mix(CREAM, WHITE, 0.4), light=0.1, dark=0.18)


def gold_coin(d, cx, cy, r):
    """Big crowned coin."""
    d.circle(cx, cy, r, GOLD, light=0.3, dark=0.4)
    d.circle(cx, cy, r * 0.84, GOLD_D, shade=False)
    d.circle(cx, cy, r * 0.78, GOLD, light=0.22, dark=0.3, angle=45)
    # beaded rim
    for i in range(24):
        a = math.radians(i * 15)
        d.dot(cx + math.cos(a) * r * 0.92, cy + math.sin(a) * r * 0.92, mix(GOLD, CREAM, 0.4), r * 0.035)
    # crown emblem
    s = r / 22.0
    cr = [(-9, 5), (-10.5, -6), (-5, -1), (0, -9), (5, -1), (10.5, -6), (9, 5)]
    d.poly([(cx + x * s, cy + y * s + 1.5 * s) for x, y in cr], GOLD_D, light=0.2, dark=0.2)
    d.rect((cx - 9.5 * s, cy + 5 * s, cx + 9.5 * s, cy + 9 * s), GOLD_D, shade=False)
    for x, y in ((-10.5, -6), (0, -9), (10.5, -6)):
        d.circle(cx + x * s, cy + y * s + 0.5 * s, 1.8 * s, mix(GOLD, CREAM, 0.3), shade=False)
    for x in (-5, 0, 5):
        d.dot(cx + x * s, cy + 7 * s, RED, 1.0 * s)
    d.dot(cx - r * 0.5, cy - r * 0.5, CREAM, r * 0.08)


def headland(d):
    shape = [(2, 88), (8, 72), (22, 60), (46, 53), (72, 53), (92, 60), (104, 72), (102, 86), (88, 98), (56, 104), (22, 101)]
    d.poly([(x, y + 5.5) for x, y in shape], FOAM, shade=False)
    d.poly([(x, y + 4) for x, y in shape], SAND, light=0.15, dark=0.25)
    d.poly([(x, y + 1.5) for x, y in shape], ROCK, light=0.2, dark=0.35)
    top = [(5, 83), (10, 70), (23, 59), (46, 52), (72, 52), (91, 59), (101, 70), (99, 82), (86, 93), (56, 98), (24, 96)]
    d.poly(top, GRASS, light=0.25, dark=0.3)
    for x, y in ((10, 80), (16, 88), (94, 80), (97, 72), (84, 90), (26, 64)):
        d.circle(x, y, 2.8, GRASS_D, light=0.3, dark=0.3)


def fort(d, cx=53, cy=76):
    ro, ri, ys, h = 37, 23, 0.52, 7
    wall = (222, 208, 176)
    # dark ditch around the works
    d.poly(star_pts(cx, cy + h, ro + 6, ri + 6, ys=ys), mix(GRASS_D, INK, 0.45), shade=False)
    d.poly(star_pts(cx, cy + h, ro + 4.5, ri + 4.5, ys=ys), mix(GRASS_D, INK, 0.2), shade=False)
    for k in range(h, 0, -1):
        d.poly(star_pts(cx, cy + k, ro, ri, ys=ys), STONE_D, light=0.2, dark=0.35)
    d.poly(star_pts(cx, cy, ro, ri, ys=ys), wall, light=0.3, dark=0.25)
    # inner face of the rampart, then the green parade ground
    d.poly(star_pts(cx, cy + 0.4, ro * 0.74, ri * 0.74, ys=ys), STONE_D, shade=False)
    d.poly(star_pts(cx, cy + 1.6, ro * 0.72, ri * 0.72, ys=ys), LEAF_L, light=0.15, dark=0.3)
    # masonry courses on the outer wall faces
    for k in (3, 6):
        pts = star_pts(cx, cy + k, ro, ri, ys=ys)
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            if a[1] > cy - 2 and b[1] > cy - 2:
                d.line([(a[0], a[1] + 0.5), (b[0], b[1] + 0.5)], mix(STONE_D, INK, 0.2), 0.5)
    # cannon on the bastion points
    for px, py in star_pts(cx, cy, ro * 0.86, ri, ys=ys)[0::2]:
        d.dot(px, py - 0.3, IRON_D, 1.2)
    # buildings in the court
    d.rect((cx - 17, cy - 8, cx - 5, cy - 1), LINEN, light=0.2, dark=0.3)
    d.poly([(cx - 18.5, cy - 8), (cx - 15, cy - 12.5), (cx - 7, cy - 12.5), (cx - 3.5, cy - 8)], ROOF, light=0.3, dark=0.3)
    d.rect((cx + 6, cy - 7, cx + 16, cy), mix(LINEN, PARCH_D, 0.3), light=0.2, dark=0.3)
    d.poly([(cx + 4.5, cy - 7), (cx + 11, cy - 11.5), (cx + 17.5, cy - 7)], ROOF, light=0.3, dark=0.3)
    d.rect((cx - 14, cy - 6, cx - 12, cy - 3.5), INK_SOFT, shade=False)
    d.rect((cx - 10, cy - 6, cx - 8, cy - 3.5), INK_SOFT, shade=False)
    d.rect((cx + 10, cy - 4, cx + 12, cy), WOOD_D, shade=False)
    # flagpole and flag
    d.line([(cx, cy + 2), (cx, cy - 40)], WOOD_D, 1.5)
    d.dot(cx, cy - 41, GOLD, 1.2)
    fl = [(cx + 0.7, cy - 40), (cx + 9, cy - 42), (cx + 19, cy - 39), (cx + 18, cy - 34), (cx + 20, cy - 29), (cx + 9, cy - 32), (cx + 0.7, cy - 30)]
    d.poly(fl, RED, light=0.3, dark=0.3)
    d.poly([(cx + 0.7, cy - 40), (cx + 8, cy - 41.7), (cx + 8, cy - 35.5), (cx + 0.7, cy - 35)], NAVY, shade=False)
    d.dot(cx + 4.2, cy - 38.2, WHITE, 0.8)


def ship(d, x, wl, s=1.0, sails=WHITE):
    """Three-masted ship facing right; x = hull centre, wl = waterline."""
    def P(px, py):
        return (x + px * s, wl + py * s)
    # sails behind rigging
    d.line([P(18, -7), P(28, -16)], WOOD_D, 1.0 * s)              # bowsprit
    d.poly([P(19, -8), P(10, -34), P(27, -15)], sails, light=0.2, dark=0.3)   # jib
    for mx, top, w in ((-11, -36, 5.8), (0, -43, 6.8), (10, -35, 5.4)):
        d.line([P(mx, -5), P(mx, top)], WOOD_D, 1.1 * s)
        # course and topsail, bellied forward
        for y0, y1, ww in ((top + 15, top + 29, w), (top + 3, top + 14, w * 0.8)):
            d.poly([P(mx - ww, y0), P(mx + ww, y0), P(mx + ww + 1.5, (y0 + y1) / 2), P(mx + ww, y1), P(mx - ww, y1), P(mx - ww + 1.5, (y0 + y1) / 2)],
                   sails, light=0.25, dark=0.3)
            d.line([P(mx - ww - 0.5, y0), P(mx + ww + 0.5, y0)], WOOD_D, 0.7 * s)
        d.poly([P(mx + 0.4, top), P(mx + 6, top + 1), P(mx + 0.4, top + 2.2)], RED, shade=False)
    # hull
    d.poly([P(-22, -10), P(-17, -9), P(-15, -6), P(16, -6), P(23, -9), P(18, 0), P(-17, 0)], WOOD, light=0.3, dark=0.35)
    d.poly([P(-22, -10), P(-23, -13), P(-15, -12), P(-15, -9)], WOOD_D, light=0.2, dark=0.3)
    d.line([P(-16, -4.3), P(17, -4.3)], GOLD_D, 1.0 * s)
    for gx in range(-12, 15, 5):
        d.rect((x + (gx - 0.8) * s, wl - 3.3 * s, x + (gx + 0.8) * s, wl - 1.9 * s), INK, shade=False)
    d.line([P(-17, -0.4), P(18, -0.4)], WOOD_D, 1.0 * s)
    # bow wave
    d.poly([P(15, -0.5), P(24, 0.5), P(18, 2.2), P(-18, 2.2), P(-20, 0.5)], FOAM, shade=False)


def draw_bg(d, rnd, x0, x1, y0, y1, horizon):
    sky(d, x0, x1, y0, horizon)
    sea(d, x0, x1, horizon, y1, rnd, glints=int((x1 - x0) * (y1 - horizon) / 90))


def draw_fg(d):
    gold_coin(d, 101, 27, 17)
    headland(d)
    fort(d)
    ship(d, 100, 110, 0.9)


def draw_mono(d):
    """Flat silhouette of the same subject for Android themed icons: a
    crowned coin ring, the star fort as a rampart ring with its flag, the
    ship, and a band of waves."""
    W_ = WHITE
    # coin: ring plus crown
    cx, cy, r = 101, 27, 17
    d.circle(cx, cy, r, W_, shade=False)
    d.erase_circle(cx, cy, r * 0.8)
    sc = r / 22.0
    cr = [(-9, 5), (-10.5, -6), (-5, -1), (0, -9), (5, -1), (10.5, -6), (9, 5)]
    d.poly([(cx + x * sc, cy + y * sc + 1.5 * sc) for x, y in cr], W_, shade=False)
    d.rect((cx - 9.5 * sc, cy + 5 * sc, cx + 9.5 * sc, cy + 9 * sc), W_, shade=False)
    # fort: solid rampart, hollow parade ground, flag
    fx, fy, ro, ri, ys, h = 53, 76, 37, 23, 0.52, 7
    for k in range(h, -1, -1):
        d.poly(star_pts(fx, fy + k, ro, ri, ys=ys), W_, shade=False)
    d.erase_poly(star_pts(fx, fy + 1.6, ro * 0.72, ri * 0.72, ys=ys))
    d.erase_poly([(fx - ro - 2, fy + 4.2), (fx + ro + 2, fy + 4.2), (fx + ro + 2, fy + 5.4), (fx - ro - 2, fy + 5.4)])
    d.line([(fx, fy + 2), (fx, fy - 40)], W_, 2.0)
    d.poly([(fx + 0.7, fy - 40), (fx + 9, fy - 42), (fx + 19, fy - 39), (fx + 18, fy - 34), (fx + 20, fy - 29), (fx + 9, fy - 32), (fx + 0.7, fy - 30)], W_, shade=False)
    # ship, cut out of whatever is behind it, with gaps between the sails
    x, wl, sc = 100, 110, 0.9

    def P(px, py):
        return (x + px * sc, wl + py * sc)
    hull = [(-22, -10), (-23, -13), (-15, -12), (-15, -6), (16, -6), (23, -9), (18, 0), (-17, 0)]
    sails = []
    for mx, top, w in ((-11, -36, 5.8), (0, -43, 6.8), (10, -35, 5.4)):
        sails.append((mx, top, w))
    pad = 2.2
    d.erase_poly([P(px + (1 if px > 0 else -1) * pad, py + (1 if py > -5 else -1) * pad) for px, py in hull])
    for mx, top, w in sails:
        d.erase_poly([P(mx - w - pad, top - pad), P(mx + w + 1.5 + pad, top - pad), P(mx + w + 1.5 + pad, -5), P(mx - w - pad, -5)])
    d.erase_poly([P(19 + pad, -8 + pad), P(10, -34 - pad), P(27 + pad, -15)])
    d.poly([P(px, py) for px, py in hull], W_, shade=False)
    d.poly([P(19, -8), P(11, -32), P(26, -15)], W_, shade=False)
    for mx, top, w in sails:
        d.line([P(mx, -5), P(mx, top)], W_, 1.3 * sc)
        for y0, y1, ww in ((top + 15, top + 29, w), (top + 3, top + 13.5, w * 0.8)):
            d.poly([P(mx - ww, y0), P(mx + ww, y0), P(mx + ww + 1.5, (y0 + y1) / 2), P(mx + ww, y1), P(mx - ww, y1), P(mx - ww + 1.5, (y0 + y1) / 2)], W_, shade=False)
        d.poly([P(mx + 0.4, top), P(mx + 6, top + 1), P(mx + 0.4, top + 2.4)], W_, shade=False)
    d.erase_poly([P(-16, -4.8), P(17, -4.8), P(17, -3.4), P(-16, -3.4)])
    # waves under the fort
    for y0 in (100, 106):
        pts = [(xx, y0 + 1.6 * math.sin(xx / 3.0)) for xx in range(8, 78, 2)]
        d.line(pts, W_, 1.8)


# -- outputs ---------------------------------------------------------------
def flatten(bg, fg):
    out = bg.copy()
    out.alpha_composite(fg)
    return out.convert("RGB")


def make_icon():
    n = 128
    bg = Canvas(n, n, seed=3)
    d = X(bg)
    draw_bg(d, bg.rnd, 0, n, 0, n, 60)
    cloud(d, 16, 18, 1.0)
    cloud(d, 52, 9, 0.7)
    fg = Canvas(n, n)
    draw_fg(X(fg))
    return flatten(bg.render(40, None), fg.render(80))


def make_adaptive():
    n = 216                      # 432 / 2
    k = 0.88                     # keeps the subject inside the 66% safe circle
    ox, oy = 108 - 64 * k, 108 - 64 * k  # design point (64, 64) at the centre
    bg = Canvas(n, n, seed=5)
    d = X(bg, ox, oy, k)
    draw_bg(d, bg.rnd, -ox / k, (n - ox) / k, -oy / k, (n - oy) / k, 60)
    cloud(d, 4, 18, 1.1)
    cloud(d, 128, 8, 0.8)
    cloud(d, -30, 2, 0.8)
    fg = Canvas(n, n)
    draw_fg(X(fg, ox, oy, k))
    fgi = fg.render(80)
    bgi = bg.render(40, None).convert("RGB")
    mc = Canvas(n, n)
    draw_mono(X(mc, ox, oy, k))
    ma = mc.render(2, None).getchannel("A")
    mono = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    mono.putalpha(ma)
    return bgi, fgi, mono


def pine(d, x, base, h, col):
    w = h * 0.42
    d.line([(x, base), (x, base - h * 0.2)], BARK, max(0.8, h * 0.06))
    for k, f in enumerate((0.0, 0.3, 0.55)):
        y = base - h * 0.15 - h * f
        ww = w * (1 - f * 0.8)
        d.poly([(x - ww, y), (x, y - h * 0.45), (x + ww, y)], mul(col, 1 + 0.06 * k), light=0.2, dark=0.3)


def make_feature():
    W, H = 512, 250
    horizon = 142
    rnd = random.Random(11)
    bg = Canvas(W, H, seed=7)
    d = X(bg)
    sky(d, 0, W, 0, horizon, bands=14)
    sea(d, 0, W, horizon, H, rnd, bands=8, glints=260)
    for x, y, s in ((40, 30, 1.3), (180, 18, 1.0), (430, 34, 1.4), (330, 60, 0.8)):
        cloud(d, x, y, s)
    # far blue hills
    pts = [(0, horizon)] + [(x, horizon - 18 - 14 * math.sin(x / 60.0) - 6 * math.sin(x / 23.0)) for x in range(0, 200, 4)] + [(200, horizon)]
    d.poly(pts, HILL_FAR, light=0.1, dark=0.1)
    pts = [(420, horizon)] + [(x, horizon - 10 - 12 * math.sin((x - 400) / 50.0) ** 2) for x in range(420, 516, 4)] + [(516, horizon)]
    d.poly(pts, HILL_FAR, light=0.1, dark=0.1)
    for _ in range(70):
        x = rnd.uniform(0, 196)
        top = horizon - 18 - 14 * math.sin(x / 60.0) - 6 * math.sin(x / 23.0)
        pine(d, x, rnd.uniform(top + 6, horizon + 2), rnd.uniform(7, 11), mix(HILL_FAR, PINE_D, 0.45))
    bgi = bg.render(80, None)

    fg = Canvas(W, H, seed=9)
    d = X(fg)
    # coin sun over the sea
    gold_coin(d, 300, 62, 28)
    # the forested shore on the left with the fort, and a point on the right
    shore = [(0, 132), (40, 128), (90, 136), (150, 140), (210, 146), (262, 160), (282, 176), (262, 190), (200, 198), (120, 206), (60, 216), (0, 222)]
    d.poly([(x, y + 4) for x, y in shore], FOAM, shade=False)
    d.poly([(x, y + 2.5) for x, y in shore], SAND, light=0.15, dark=0.25)
    d.poly(shore, GRASS, light=0.2, dark=0.3)
    point = [(512, 150), (470, 152), (440, 160), (430, 168), (452, 172), (512, 174)]
    d.poly([(x, y + 3) for x, y in point], SAND, light=0.15, dark=0.25)
    d.poly(point, GRASS, light=0.2, dark=0.3)
    for x in range(446, 512, 7):
        pine(d, x + rnd.uniform(-2, 2), 162 + rnd.uniform(0, 6), rnd.uniform(14, 20), PINE_M)
    # forest behind the fort
    trees = sorted(((rnd.uniform(0, 250), rnd.uniform(128, 150)) for _ in range(46)), key=lambda t: t[1])
    for x, y in trees:
        if 60 < x < 210 and y > 136:
            continue
        pine(d, x, y + 6, rnd.uniform(16, 24), PINE_D if rnd.random() < 0.5 else PINE_M)
    # palisade fort: back wall, side walls, buildings, front wall
    fx0, fx1, fyb, fyf = 62, 206, 148, 184

    def logs(xa, ya, xb, yb, hgt, step=3.2):
        n = int(math.hypot(xb - xa, yb - ya) / step)
        for i in range(n + 1):
            t = i / max(1, n)
            x = xa + (xb - xa) * t
            y = ya + (yb - ya) * t
            col = WOOD if i % 2 else mul(WOOD, 0.9)
            d.poly([(x - 1.7, y), (x - 1.7, y - hgt), (x, y - hgt - 2.4), (x + 1.7, y - hgt), (x + 1.7, y)], col, light=0.3, dark=0.35)
    d.poly([(fx0, fyb), (fx1, fyb), (fx1 + 10, fyf), (fx0 - 10, fyf)], mix(GRASS, PARCH_D, 0.35), light=0.15, dark=0.25)
    logs(fx0, fyb, fx1, fyb, 10)
    logs(fx0, fyb, fx0 - 10, fyf, 10, 2.6)
    logs(fx1, fyb, fx1 + 10, fyf, 10, 2.6)

    def blockhouse(x, y, w, h):
        d.rect((x - w / 2, y - h, x + w / 2, y), WOOD, light=0.3, dark=0.35)
        for yy in range(int(y - h) + 2, int(y), 3):
            d.line([(x - w / 2 + 0.5, yy), (x + w / 2 - 0.5, yy)], WOOD_D, 0.5)
        d.rect((x - w / 2 - 2.5, y - h - 6, x + w / 2 + 2.5, y - h + 1), WOOD_L, light=0.3, dark=0.35)
        d.poly([(x - w / 2 - 4, y - h - 6), (x, y - h - 14), (x + w / 2 + 4, y - h - 6)], ROOF, light=0.3, dark=0.35)
        d.rect((x - 1.5, y - h - 4, x + 1.5, y - h - 1.5), INK, shade=False)

    # buildings inside
    for bx, bw, bh in ((96, 26, 12), (168, 22, 10)):
        d.rect((bx - bw / 2, fyb + 6 - bh, bx + bw / 2, fyb + 6), LINEN, light=0.2, dark=0.3)
        d.poly([(bx - bw / 2 - 2, fyb + 6 - bh), (bx - bw / 2 + 4, fyb - bh - 2), (bx + bw / 2 - 4, fyb - bh - 2), (bx + bw / 2 + 2, fyb + 6 - bh)], ROOF, light=0.3, dark=0.35)
        for wx in range(int(bx - bw / 2) + 4, int(bx + bw / 2) - 2, 6):
            d.rect((wx, fyb + 6 - bh + 3, wx + 2.2, fyb + 6 - bh + 6), INK_SOFT, shade=False)
    # church with steeple
    cx = 134
    d.rect((cx - 9, fyb - 6, cx + 9, fyb + 8), WHITE, light=0.2, dark=0.3)
    d.poly([(cx - 11, fyb - 6), (cx, fyb - 15), (cx + 11, fyb - 6)], mix(ROOF, INK_SOFT, 0.3), light=0.3, dark=0.35)
    d.rect((cx - 3, fyb - 26, cx + 3, fyb - 12), WHITE, light=0.2, dark=0.3)
    d.poly([(cx - 4, fyb - 26), (cx, fyb - 38), (cx + 4, fyb - 26)], mix(ROOF, INK_SOFT, 0.3), light=0.3, dark=0.35)
    d.rect((cx - 2, fyb + 1, cx + 2, fyb + 8), WOOD_D, shade=False)
    # flag
    d.line([(104, fyb + 4), (104, fyb - 40)], WOOD_D, 1.2)
    fl = [(104.6, fyb - 40), (113, fyb - 42), (122, fyb - 39), (121, fyb - 34), (122.5, fyb - 30), (113, fyb - 32.5), (104.6, fyb - 31)]
    d.poly(fl, RED, light=0.3, dark=0.3)
    # canton in cream: a small navy patch gets merged into the pines by the palette snap
    d.poly([(104.6, fyb - 40), (111, fyb - 41.3), (111, fyb - 35.6), (104.6, fyb - 35.3)], CREAM, shade=False)
    d.line([(105, fyb - 37.8), (110.6, fyb - 38.2)], RED, 0.7)
    # corner blockhouses and the front wall with gate
    blockhouse(fx0 - 4, fyb + 2, 14, 12)
    blockhouse(fx1 + 4, fyb + 2, 14, 12)
    logs(fx0 - 10, fyf, fx1 + 10, fyf, 13)
    d.rect((126, fyf - 12, 142, fyf), WOOD_D, light=0.15, dark=0.3)
    d.rect((127.5, fyf - 10.5, 134.5, fyf), WOOD, light=0.25, dark=0.35)
    d.rect((134.5, fyf - 10.5, 140.5, fyf), mul(WOOD, 0.92), light=0.25, dark=0.35)
    blockhouse(fx0 - 12, fyf + 3, 16, 14)
    blockhouse(fx1 + 12, fyf + 3, 16, 14)
    # cleared path and a pier into the harbour
    d.poly([(128, fyf + 1), (140, fyf + 1), (190, 199), (176, 201)], mix(PARCH_D, WOOD_L, 0.35), light=0.15, dark=0.2)
    d.rect((184, 196, 250, 200), WOOD_L, light=0.3, dark=0.35)
    for px in range(188, 250, 8):
        d.line([(px, 200), (px, 206)], WOOD_D, 1.2)
    # barrels and crates on the pier
    for bx in (232, 238):
        d.ellipse((bx - 2.6, 190.5, bx + 2.6, 197), WOOD, light=0.3, dark=0.35)
    d.rect((222, 191, 229, 197), PINE, light=0.3, dark=0.35)
    # ships
    ship(d, 360, 214, 1.55)
    ship(d, 468, 188, 0.9, sails=mix(WHITE, PARCH, 0.4))
    # small longboat by the pier
    d.poly([(254, 208), (272, 208), (276, 204), (250, 204)], WOOD_D, light=0.2, dark=0.3)
    d.line([(262, 204), (262, 194)], WOOD_D, 0.8)
    d.poly([(262.5, 194.5), (270, 202.5), (262.5, 202.5)], LINEN, light=0.2, dark=0.3)
    fgi = fg.render(128)
    return flatten(bgi, fgi)


def main():
    os.makedirs(ICONS, exist_ok=True)
    icon = make_icon()                                          # 128 RGB
    icon.resize((1024, 1024), Image.NEAREST).save(os.path.join(ICONS, "app_icon_1024.png"))
    icon.resize((512, 512), Image.NEAREST).save(os.path.join(ICONS, "app_icon_512.png"))
    icon.resize((256, 256), Image.NEAREST).convert("RGBA").save(os.path.join(SPRITES, "app_icon.png"))
    bg, fg, mono = make_adaptive()                              # 216 each
    bg.resize((432, 432), Image.NEAREST).save(os.path.join(ICONS, "android_adaptive_background.png"))
    fg.resize((432, 432), Image.NEAREST).save(os.path.join(ICONS, "android_adaptive_foreground.png"))
    mono.resize((432, 432), Image.NEAREST).save(os.path.join(ICONS, "android_adaptive_monochrome.png"))
    feat = make_feature()
    feat.resize((1024, 500), Image.NEAREST).save(os.path.join(ICONS, "feature_graphic_1024x500.png"))

    if len(sys.argv) > 1:
        rev = sys.argv[1]
        os.makedirs(rev, exist_ok=True)
        big = Image.open(os.path.join(ICONS, "app_icon_1024.png"))
        prev = Image.new("RGB", (512 + 16 + 3 * 120, 512), (60, 44, 32))
        prev.paste(big.resize((512, 512), Image.NEAREST), (0, 0))
        x = 528
        for s in (96, 48, 32):
            sm = big.resize((s, s), Image.LANCZOS)
            prev.paste(sm, (x, 10))
            prev.paste(sm.resize((s * (96 // s) if s < 96 else 96,) * 2, Image.NEAREST), (x, 140))
            x += 120
        prev.save(os.path.join(rev, "app_icon_preview.png"))
        # adaptive composite through a circle mask and a squircle, plus the monochrome
        comp = Image.open(os.path.join(ICONS, "android_adaptive_background.png")).convert("RGBA")
        comp.alpha_composite(Image.open(os.path.join(ICONS, "android_adaptive_foreground.png")))
        mask = Image.new("L", (432, 432), 0)
        from PIL import ImageDraw
        ImageDraw.Draw(mask).ellipse((72, 72, 360, 360), fill=255)   # 72dp visible of 108dp
        circ = Image.new("RGBA", (432, 432), (60, 44, 32, 255))
        circ.paste(comp, (0, 0), mask)
        safe = comp.copy()
        ImageDraw.Draw(safe).ellipse((74, 74, 358, 358), outline=(255, 0, 255, 255), width=2)
        mono_im = Image.open(os.path.join(ICONS, "android_adaptive_monochrome.png"))
        mono_v = Image.new("RGBA", (432, 432), (40, 60, 90, 255))
        mono_v.alpha_composite(mono_im)
        sheet_im = Image.new("RGBA", (432 * 4, 432), (0, 0, 0, 255))
        for i, im in enumerate((safe, circ, Image.open(os.path.join(ICONS, "android_adaptive_foreground.png")), mono_v)):
            bgc = Image.new("RGBA", (432, 432), (120, 120, 120, 255))
            bgc.alpha_composite(im.convert("RGBA"))
            sheet_im.paste(bgc, (i * 432, 0))
        sheet_im.save(os.path.join(rev, "adaptive_preview.png"))


if __name__ == "__main__":
    main()
