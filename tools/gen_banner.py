"""Draws the Europe page banner (assets/sprites/harbor.png) from scratch.

"The Docks of Europe": a European harbour at golden hour. A low sun sits over
a hazy town (church spire, warehouses, a windmill, a treadwheel crane); a
large three-master lies at anchor on the right with topsails set, a smaller
ship and a distant sail beyond; the water carries a sun column of glints and
broken ship reflections; a stone quay fills the left foreground with
bollards, rope, crates and barrels, a merchant with a lantern, dockworkers
and colonists; rowboats ferry colonists out to the ships.

Everything is drawn procedurally with PIL at a native 340x125 (one art pixel
= 2 screen pixels, so the scene reads at phone size), with banded, ordered-
dithered gradients, tinted outlines and rim light from the sun, then scaled
x2 with NEAREST to exactly 680x250. No source image is used.

Run: python tools/gen_banner.py [preview_path]
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "harbor.png")
W, H = 340, 125          # native art resolution
SCALE = 2                # -> 680x250
HORIZON = 70
SUN = (168, 55)
SUN_R = 9

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
INK = (38, 22, 26)


# -- colour helpers -----------------------------------------------------------
def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def mul(c, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in c[:3])


def ramp(stops, t, x, y, soft=0.3):
    """Banded gradient: solid bands with a narrow ordered-dither seam."""
    f = clamp(t) * (len(stops) - 1)
    i = int(f)
    if i >= len(stops) - 1:
        return stops[-1]
    fr = f - i
    thr = 0.5 - soft / 2 + soft * (BAYER[y % 4][x % 4] + 0.5) / 16
    return stops[i + 1] if fr > thr else stops[i]


# -- layers ---------------------------------------------------------------------
def layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def outline(img, ink=INK, k=0.25, skip_below=None):
    """1 px outline around opaque pixels, tinted toward what it encloses."""
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(H):
        if skip_below is not None and y > skip_below:
            continue
        for x in range(W):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < W and 0 <= yy < H and src[xx, yy][3]:
                    dst[x, y] = mix(ink, src[xx, yy][:3], k) + (255,)
                    break
    return out


def rim(img, color=(255, 196, 120), amt=0.45, top=True):
    """Warm rim light on edges that face the sun (backlit scene)."""
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(H):
        for x in range(W):
            p = src[x, y]
            if not p[3]:
                continue
            dx = 1 if x < SUN[0] else -1
            lit = False
            xx = x + dx
            if 0 <= xx < W and not src[xx, y][3]:
                lit = True
            if top and y > 0 and not src[x, y - 1][3]:
                lit = True
            if lit:
                dst[x, y] = mix(p[:3], color, amt) + (255,)
    return out


def haze(img, color, t):
    px = img.load()
    for y in range(H):
        for x in range(W):
            p = px[x, y]
            if p[3]:
                px[x, y] = mix(p[:3], color, t) + (255,)
    return img


def paste(base, lay):
    base.alpha_composite(lay)


# -- sky ----------------------------------------------------------------------------
SKY = [(58, 36, 72), (82, 44, 80), (112, 54, 82), (146, 64, 78), (180, 82, 70), (206, 104, 62),
       (228, 130, 64), (240, 158, 76), (248, 184, 98), (252, 208, 128), (254, 228, 166)]


def draw_sky(img):
    px = img.load()
    for y in range(HORIZON + 1):
        for x in range(W):
            t = (y / HORIZON) ** 0.95 * 0.86
            d = math.hypot((x - SUN[0]) * 0.55, (y - SUN[1]) * 1.2)
            t += 0.42 * clamp(1 - d / 80) ** 1.6
            px[x, y] = ramp(SKY, t, x, y) + (255,)


def draw_clouds(img):
    """Long flat streaks: dusky bodies, bright undersides near the sun."""
    streaks = [  # cx, cy, half width, thickness
        (60, 12, 58, 3), (118, 8, 30, 2), (250, 16, 70, 3), (310, 30, 40, 2),
        (40, 32, 36, 2), (214, 38, 34, 2), (122, 44, 26, 1), (100, 52, 22, 1),
        (206, 50, 18, 1), (286, 46, 30, 1), (22, 50, 20, 1),
    ]
    rnd = random.Random(11)
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    for cx, cy, hw, th in streaks:
        md.ellipse([cx - hw, cy - th, cx + hw, cy + th], fill=255)
        for _ in range(3):
            ox = rnd.randint(-hw // 2, hw // 2)
            w2 = rnd.randint(hw // 4, hw // 2)
            md.ellipse([cx + ox - w2, cy - th - 1 - rnd.randint(0, 1), cx + ox + w2, cy + 1], fill=255)
    m = mask.load()
    px = img.load()
    for y in range(H):
        for x in range(W):
            if not m[x, y]:
                continue
            d = math.hypot(x - SUN[0], (y - SUN[1]) * 1.5)
            near = clamp(1 - d / 150)
            body = mix((120, 58, 84), (214, 118, 86), clamp(y / 60 + near * 0.6))
            below = y + 1 < H and not m[x, y + 1]
            above = y > 0 and not m[x, y - 1]
            if below:
                c = mix((236, 140, 90), (255, 222, 150), near)
            elif above:
                c = mul(body, 0.92)
            else:
                c = body
            px[x, y] = c + (255,)


def draw_gulls(img):
    d = ImageDraw.Draw(img)
    for x, y, up in ((112, 22, 1), (121, 27, 0), (104, 30, 0), (276, 42, 1)):
        c = (70, 40, 56)
        d.point((x, y), fill=c)
        d.point((x - 1, y - 1), fill=c)
        d.point((x + 1, y - 1), fill=c)
        d.point((x - 2, y - 1 - up), fill=c)
        d.point((x + 2, y - 1 - up), fill=c)


def draw_sun(img):
    d = ImageDraw.Draw(img)
    cx, cy = SUN
    d.ellipse([cx - SUN_R - 2, cy - SUN_R - 2, cx + SUN_R + 2, cy + SUN_R + 2], fill=(255, 222, 150))
    d.ellipse([cx - SUN_R, cy - SUN_R, cx + SUN_R, cy + SUN_R], fill=(255, 238, 180))
    d.ellipse([cx - SUN_R + 3, cy - SUN_R + 3, cx + SUN_R - 3, cy + SUN_R - 3], fill=(255, 248, 214))
    # thin cloud bars across the disc
    for yy, x0, x1 in ((cy + 2, cx - 14, cx + 8), (cy + 5, cx - 6, cx + 16)):
        d.line([(x0, yy), (x1, yy)], fill=(236, 150, 92))


# -- distant town ---------------------------------------------------------------------
def draw_town():
    far = layer()
    near = layer()
    fd = ImageDraw.Draw(far)
    nd = ImageDraw.Draw(near)
    rnd = random.Random(5)
    base = HORIZON
    # far row of roofs
    x = 0
    while x < 150:
        w = rnd.randint(5, 10)
        h = rnd.randint(4, 8)
        fd.rectangle([x, base - h, x + w - 1, base], fill=(170, 100, 96))
        fd.polygon([(x, base - h), (x + w / 2, base - h - w / 2), (x + w - 1, base - h)], fill=(170, 100, 96))
        x += w
    fd.rectangle([60, base - 16, 63, base], fill=(170, 100, 96))  # far tower
    fd.polygon([(60, base - 16), (61.5, base - 22), (63, base - 16)], fill=(170, 100, 96))
    # near row: warehouses with stepped gables
    wall = (126, 70, 78)
    x = 0
    while x < 140:
        w = rnd.randint(7, 12)
        h = rnd.randint(5, 10)
        nd.rectangle([x, base - h, x + w - 1, base], fill=wall)
        if rnd.random() < 0.5:
            nd.polygon([(x, base - h), (x + w / 2, base - h - w * 0.55), (x + w - 1, base - h)], fill=wall)
        else:  # stepped gable
            s = x + 1
            for k in range(3):
                nd.rectangle([s + k, base - h - k * 2 - 2, x + w - 2 - k, base - h], fill=wall)
        for _ in range(2):
            wx = rnd.randint(x + 1, x + w - 2)
            wy = rnd.randint(base - h + 2, base - 2)
            nd.point((wx, wy), fill=(252, 196, 104))
        x += w + rnd.randint(0, 2)
    # church
    c = (112, 60, 72)
    nd.rectangle([14, base - 11, 32, base], fill=c)
    nd.polygon([(14, base - 11), (23, base - 17), (32, base - 11)], fill=c)
    nd.rectangle([30, base - 22, 35, base], fill=c)
    nd.rectangle([29, base - 24, 36, base - 22], fill=c)
    nd.polygon([(30, base - 24), (32.5, base - 40), (35, base - 24)], fill=c)
    nd.line([(32, base - 43), (32, base - 40)], fill=c)
    nd.line([(31, base - 42), (33, base - 42)], fill=c)
    nd.point((32, base - 19), fill=(252, 196, 104))
    # windmill
    nd.polygon([(88, base), (90, base - 13), (94, base - 13), (96, base)], fill=c)
    nd.polygon([(89, base - 13), (92, base - 17), (95, base - 13)], fill=c)
    hub = (92, base - 15)
    for a in (35, 125, 215, 305):
        r = math.radians(a)
        nd.line([hub, (hub[0] + math.cos(r) * 10, hub[1] + math.sin(r) * 10)], fill=c)
        nd.line([(hub[0] + math.cos(r) * 4 + math.cos(r + 1.57) * 1.5, hub[1] + math.sin(r) * 4 + math.sin(r + 1.57) * 1.5),
                 (hub[0] + math.cos(r) * 10 + math.cos(r + 1.57) * 1.5, hub[1] + math.sin(r) * 10 + math.sin(r + 1.57) * 1.5)], fill=c)
    # treadwheel crane on the waterfront
    nd.rectangle([124, base - 10, 133, base], fill=c)
    nd.polygon([(123, base - 10), (128.5, base - 15), (134, base - 10)], fill=c)
    nd.line([(131, base - 13), (146, base - 24)], fill=c, width=1)
    nd.line([(130, base - 12), (146, base - 24)], fill=c, width=1)
    nd.line([(146, base - 24), (146, base - 12)], fill=(92, 50, 60))
    nd.rectangle([145, base - 12, 147, base - 10], fill=c)
    # low mole with a light
    nd.rectangle([134, base - 2, 196, base], fill=(118, 66, 76))
    nd.rectangle([190, base - 9, 193, base - 2], fill=c)
    nd.rectangle([189, base - 11, 194, base - 9], fill=c)
    nd.point((191, base - 10), fill=(255, 220, 140))
    # far right shore
    for x0, w, h in ((326, 8, 6), (333, 7, 9)):
        nd.rectangle([x0, base - h, x0 + w, base], fill=wall)
        nd.polygon([(x0, base - h), (x0 + w / 2, base - h - 4), (x0 + w, base - h)], fill=wall)
    return far, near


# -- ships ------------------------------------------------------------------------------
HULL = (78, 44, 36)
HULL_D = (54, 30, 28)
WALE = (150, 94, 56)
BAND = (184, 132, 66)
RAIL = (116, 72, 46)
MAST = (96, 60, 40)
MAST_L = (150, 100, 62)
ROPE = (58, 36, 36)
SAIL = [(254, 220, 166), (244, 196, 142), (224, 168, 122), (194, 134, 102)]
FURL = (236, 196, 146)
FURL_D = (176, 126, 100)
GLOW = (255, 214, 120)


class Ship:
    """A ship drawn in local units: bow at x=0, stern at x=130, waterline y=0,
    up is negative. `s` scales, `flip` mirrors (bow to the right)."""

    def __init__(self, ox, wl, s=1.0, flip=False, jib=True):
        self.ox, self.wl, self.s, self.flip, self.has_jib = ox, wl, s, flip, jib
        self.hull = layer()
        self.rig = layer()
        self.lines = layer()

    def T(self, x, y):
        x = -x if self.flip else x
        return (self.ox + x * self.s, self.wl + y * self.s)

    def P(self, pts):
        return [self.T(*p) for p in pts]

    def lw(self, w):
        return max(1, int(round(w * self.s)))

    def sail(self, top, bot, color_shift=0.0, jib=False):
        """Filled sail polygon with a column ramp and darker seams/edges."""
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).polygon(self.P(top + bot), fill=255)
        bb = m.getbbox()
        if not bb:
            return
        mp = m.load()
        px = self.rig.load()
        x0, y0, x1, y1 = bb
        for y in range(y0, y1):
            for x in range(x0, x1):
                if not mp[x, y]:
                    continue
                t = (x - x0) / max(1, x1 - x0 - 1)
                if self.flip:
                    t = 1 - t
                t = t * 0.7 + (y - y0) / max(1, y1 - y0) * 0.3 + color_shift
                c = ramp(SAIL, t, x, y, 0.4)
                edge = any(not (0 <= x + dx < W and 0 <= y + dy < H and mp[x + dx, y + dy])
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if edge:
                    c = mul(c, 0.8)
                elif not jib and (x - x0) % 4 == 3:
                    c = mul(c, 0.93)
                px[x, y] = c + (255,)

    def furl(self, x, y, half):
        d = ImageDraw.Draw(self.rig)
        a, b = self.T(x - half, y), self.T(x + half, y)
        d.line([a, b], fill=MAST, width=1)
        th = self.lw(1.8)
        d.rectangle([min(a[0], b[0]) + 1, a[1] - th, max(a[0], b[0]) - 1, a[1] - 1], fill=FURL)
        d.line([(min(a[0], b[0]) + 1, a[1] - th), (max(a[0], b[0]) - 1, a[1] - th)], fill=(252, 224, 176))
        d.line([(min(a[0], b[0]) + 2, a[1] + 1), (max(a[0], b[0]) - 2, a[1] + 1)], fill=FURL_D)

    def yard(self, x, y, half):
        d = ImageDraw.Draw(self.rig)
        d.line([self.T(x - half, y), self.T(x + half, y)], fill=MAST, width=1)

    def draw(self, big=True):
        hd = ImageDraw.Draw(self.hull)
        rd = ImageDraw.Draw(self.rig)
        ld = ImageDraw.Draw(self.lines)
        # ---- hull
        hull = [(3, -25), (14, -21), (40, -19), (88, -19), (98, -25), (126, -33), (131, -33),
                (129, -20), (125, -8), (117, -1), (100, 0), (24, 0), (10, -4), (4, -12)]
        hd.polygon(self.P(hull), fill=HULL)
        # quarterdeck and forecastle bulwarks
        hd.polygon(self.P([(96, -25), (126, -33), (126, -29), (98, -22)]), fill=RAIL)
        hd.polygon(self.P([(4, -25), (15, -21), (15, -19), (5, -22)]), fill=RAIL)
        # painted gunport band and wales
        hd.polygon(self.P([(8, -19), (40, -16), (90, -16), (126, -24), (127, -20), (90, -12), (40, -12), (9, -15)]), fill=BAND)
        hd.line(self.P([(8, -11), (40, -8), (92, -8), (124, -14)]), fill=WALE, width=self.lw(1.4))
        hd.line(self.P([(12, -5), (40, -3), (100, -3), (120, -6)]), fill=HULL_D, width=self.lw(1.2))
        # gunports
        if self.s > 0.5:
            for gx in range(22, 118, 9):
                yy = -15.5 if gx < 90 else -15.5 - (gx - 90) * 0.22
                hd.rectangle(self.P([(gx, yy - 1.5), (gx + 3, yy + 1.5)]) if not self.flip else
                             self.P([(gx + 3, yy - 1.5), (gx, yy + 1.5)]), fill=(40, 22, 22))
        else:
            for gx in range(20, 118, 12):
                hd.point(self.T(gx, -14), fill=(40, 22, 22))
        # stern gallery with lit windows
        hd.polygon(self.P([(118, -30), (130, -32), (129, -21), (119, -21)]), fill=(96, 56, 40))
        for wx in (120, 123.5, 127):
            p = self.T(wx, -27)
            hd.rectangle([p[0], p[1], p[0] + self.lw(1.5) - 1, p[1] + self.lw(3) - 1], fill=(255, 206, 110))
        # figurehead / beak
        hd.polygon(self.P([(3, -25), (-6, -22), (-4, -19), (5, -17)]), fill=HULL)
        # ---- masts
        masts = [  # x, top, platform
            (30, -92, -60),
            (68, -104, -68),
            (104, -80, -54),
        ]
        for mx, top, plat in masts:
            rd.line([self.T(mx, -20), self.T(mx, plat)], fill=MAST, width=self.lw(2.2))
            rd.line([self.T(mx + 0.8, plat), self.T(mx + 0.8, top)], fill=MAST, width=1)
            p = self.T(mx, plat)
            rd.rectangle([p[0] - self.lw(3), p[1], p[0] + self.lw(3), p[1] + self.lw(1)], fill=MAST)
        # bowsprit + jibboom
        rd.line([self.T(4, -24), self.T(-34, -42)], fill=MAST, width=self.lw(2))
        # ---- sails (fore: course furled, topsail set, t'gallant furled)
        self.furl(30, -34, 18)
        self.yard(30, -58, 15)
        self.sail([(30 - 15, -58), (30 + 15, -58)], [(30 + 18, -36), (30, -38), (30 - 18, -36)])
        self.furl(30, -76, 11)
        # main: course furled, topsail set, t'gallant set small
        self.furl(68, -38, 22)
        self.yard(68, -66, 18)
        self.sail([(68 - 18, -66), (68 + 18, -66)], [(68 + 22, -40), (68, -42.5), (68 - 22, -40)])
        self.yard(68, -86, 12)
        self.sail([(68 - 12, -86), (68 + 12, -86)], [(68 + 15, -68), (68, -70), (68 - 15, -68)], 0.1)
        self.furl(68, -98, 8)
        # mizzen: furled crossjack, spanker set on the gaff
        self.furl(104, -44, 14)
        self.furl(104, -64, 10)
        self.sail([(105, -50), (124, -60)], [(126, -30), (106, -30)], 0.15)
        rd.line([self.T(105, -50), self.T(126, -61)], fill=MAST, width=1)
        rd.line([self.T(105, -31), self.T(130, -32)], fill=MAST, width=1)
        # jib
        if self.has_jib:
            self.sail([(-30, -41)], [(8, -36), (2, -68)], 0.05, jib=True)
        # pennant
        p = self.T(68.8, -104)
        dirx = -1 if not self.flip else 1
        pen = [p, (p[0] + dirx * self.lw(10), p[1] + self.lw(1.5)), (p[0], p[1] + self.lw(3))]
        rd.polygon(pen, fill=(196, 52, 44))
        # stern lantern
        lp = self.T(130, -37)
        if self.s > 0.5:
            rd.line([self.T(129, -33), lp], fill=MAST)
            rd.rectangle([lp[0] - 1, lp[1] - 2, lp[0] + 1, lp[1]], fill=GLOW)
            rd.point((lp[0], lp[1] - 1), fill=(255, 248, 210))
        # ---- rigging lines (no outline)
        for mx, top, plat in masts:
            for off in (-9, -5, 3, 8):
                ld.line([self.T(mx, plat), self.T(mx + off, -21 if mx < 90 else -26)], fill=ROPE)
            ld.line([self.T(mx + 0.8, top + 4), self.T(mx + 4, plat)], fill=ROPE)
        ld.line([self.T(30.8, -90), self.T(-34, -42)], fill=ROPE)
        ld.line([self.T(68.8, -102), self.T(31, -74)], fill=ROPE)
        ld.line([self.T(68, -66), self.T(31, -58)], fill=ROPE)
        ld.line([self.T(104.8, -78), self.T(69, -84)], fill=ROPE)
        ld.line([self.T(104.8, -78), self.T(130, -33)], fill=ROPE)
        ld.line([self.T(-34, -42), self.T(-6, -20)], fill=ROPE)

    def finish(self, outlined=True, rim_amt=0.45):
        h = rim(self.hull, amt=rim_amt * 0.8, top=True)
        r = self.rig
        if outlined:
            h = outline(h)
            r = outline(r, k=0.4)
        comb = layer()
        comb.alpha_composite(h)
        comb.alpha_composite(r)
        comb.alpha_composite(self.lines)
        return comb


# -- water ------------------------------------------------------------------------------
WATER = [(238, 164, 104), (196, 124, 100), (120, 104, 110), (64, 100, 118), (46, 84, 108),
         (36, 66, 94), (28, 50, 80), (22, 38, 66)]


def draw_water(img):
    px = img.load()
    for y in range(HORIZON, H):
        t = ((y - HORIZON) / (H - HORIZON)) ** 0.75
        for x in range(W):
            px[x, y] = ramp(WATER, t, x, y, 0.5) + (255,)


def ripples(img, rnd):
    """Horizontal light dashes across the water, and the sun column."""
    px = img.load()
    for y in range(HORIZON + 1, H):
        depth = (y - HORIZON) / (H - HORIZON)
        # general sky-coloured ripples
        for _ in range(int(6 + depth * 10)):
            x = rnd.randint(0, W - 1)
            ln = rnd.randint(2, 4 + int(depth * 8))
            c = mix(px[x, y][:3], (236, 150, 104), 0.35 - depth * 0.1)
            for i in range(ln):
                if x + i < W:
                    px[x + i, y] = c + (255,)
        # sun column
        half = 5 + depth * 26
        n = int(3 + depth * 7)
        for _ in range(n):
            if y % 2 and rnd.random() < 0.5:
                continue
            cx = SUN[0] + rnd.gauss(0, half * 0.5)
            ln = rnd.randint(2, 3 + int(depth * 9))
            core = abs(cx - SUN[0]) < half * 0.35
            c = (255, 240, 190) if core and rnd.random() < 0.6 else (252, 206, 128)
            for i in range(ln):
                xx = int(cx) - ln // 2 + i
                if 0 <= xx < W:
                    px[xx, y] = c + (255,)


def reflect(img, lay, wl, amt=0.5, tint=(24, 36, 60), gap=4, y_from=None):
    """Mirror `lay` about the waterline wl onto the water, broken into rows."""
    src = lay.load()
    px = img.load()
    for y in range(wl + 1, H):
        dy = y - wl
        if dy % gap == gap - 1:
            continue
        sy = wl - int(dy * 1.05)
        if sy < 0:
            break
        off = int(round(math.sin(y * 1.7) * min(2.0, dy / 8)))
        for x in range(W):
            sx = x - off
            if not (0 <= sx < W):
                continue
            p = src[sx, sy]
            if p[3] < 128:
                continue
            c = mix(p[:3], tint, 0.45)
            px[x, y] = mix(px[x, y][:3], c, amt) + (255,)


# -- rowboats and figures ------------------------------------------------------------
def rowboat(d, x, y, length, seats, rnd, oars=True, flip=False):
    """Boat hull with seated colonists. (x, y) = left end of the gunwale."""
    L = length
    d.polygon([(x, y), (x + L, y), (x + L - 3, y + 4), (x + 3, y + 4)], fill=(112, 66, 40))
    d.line([(x, y), (x + L, y)], fill=(196, 134, 76))
    d.line([(x + 2, y + 2), (x + L - 2, y + 2)], fill=(90, 52, 34))
    d.line([(x + 3, y + 4), (x + L - 3, y + 4)], fill=(64, 36, 28))
    if oars:
        for ox in (x + L * 0.45,):
            d.line([(ox, y - 1), (ox - 7, y + 6)], fill=(170, 122, 72))
            d.line([(ox - 8, y + 6), (ox - 6, y + 6)], fill=(170, 122, 72))
    for i, (coat, hat) in enumerate(seats):
        sx = x + 4 + i * ((L - 8) / max(1, len(seats) - 1)) if len(seats) > 1 else x + L / 2
        sx = int(sx)
        d.rectangle([sx - 1, y - 4, sx + 1, y - 1], fill=coat)
        d.rectangle([sx - 1, y - 6, sx, y - 5], fill=(232, 176, 134))
        if hat == "tricorn":
            d.line([(sx - 2, y - 7), (sx + 1, y - 7)], fill=(40, 30, 32))
            d.point((sx - 1, y - 8), fill=(40, 30, 32))
        elif hat == "bonnet":
            d.rectangle([sx - 2, y - 7, sx, y - 5], fill=(236, 226, 206))
        else:
            d.line([(sx - 1, y - 7), (sx, y - 7)], fill=(84, 52, 38))


def figure(d, x, fy, coat, hat="tricorn", vest=(214, 190, 140), legs=(236, 226, 204), face=1,
           lantern=False, carry=None, dress=False, skin=(232, 176, 134)):
    """A standing person, 9 px wide and 20 px tall, feet on row fy-1,
    facing right (face=1) or left (face=-1)."""
    top = fy - 20
    hc = (40, 30, 34)
    f = face
    cx = x + 4                      # body centre column
    back = cx - 2 * f               # back edge column
    front = cx + 2 * f
    # hat
    if hat == "tricorn":
        d.rectangle([x + 2, top, x + 6, top], fill=hc)
        d.rectangle([x + 1, top + 1, x + 7, top + 1], fill=hc)
        d.point((front + f, top + 2), fill=hc)
        d.point((cx, top), fill=(112, 88, 74))
    elif hat == "cap":
        d.rectangle([x + 3, top + 1, x + 5, top + 1], fill=(160, 62, 50))
        d.point((back - f, top + 2), fill=(160, 62, 50))
    elif hat == "bonnet":
        d.rectangle([x + 2, top + 1, x + 6, top + 4], fill=(240, 232, 214))
        d.point((back - f, top + 3), fill=(240, 232, 214))
    elif hat == "broad":
        d.rectangle([x + 3, top, x + 5, top], fill=(84, 60, 44))
        d.rectangle([x + 1, top + 1, x + 7, top + 1], fill=(84, 60, 44))
    # head
    d.rectangle([x + 3, top + 2, x + 5, top + 5], fill=skin)
    d.point((front + f, top + 4), fill=skin)             # nose
    d.point((cx + f, top + 3), fill=(60, 40, 36))        # eye
    if hat != "bonnet":
        d.line([(back, top + 2), (back, top + 4)], fill=(96, 66, 46))  # hair / queue
        d.point((back - f, top + 5), fill=(96, 66, 46))
    if dress:
        d.rectangle([x + 2, top + 6, x + 6, top + 10], fill=coat)
        d.rectangle([x + 3, top + 6, x + 5, top + 7], fill=(236, 226, 206))   # kerchief
        d.polygon([(x + 2, top + 11), (x + 6, top + 11), (x + 8, top + 18), (x, top + 18)], fill=mul(coat, 0.86))
        d.polygon([(x + 3, top + 11), (x + 5, top + 11), (x + 6, top + 17), (x + 2, top + 17)], fill=(226, 214, 190))
        d.line([(x + 1, top + 18), (x + 7, top + 18)], fill=mul(coat, 0.6))
    else:
        d.rectangle([x + 2, top + 6, x + 6, top + 13], fill=coat)
        d.point((cx, top + 6), fill=(244, 238, 224))                       # cravat
        d.line([(cx + f, top + 7), (cx + f, top + 12)], fill=vest)         # waistcoat
        d.point((cx + f, top + 8), fill=(230, 196, 100))
        d.point((cx + f, top + 10), fill=(230, 196, 100))
        d.polygon([(x + 2, top + 13), (x + 6, top + 13), (x + 7, top + 15), (x + 1, top + 15)], fill=coat)
        d.line([(back, top + 13), (back - f, top + 15)], fill=mul(coat, 0.7))
        # breeches, stockings, legs apart
        d.rectangle([x + 3, top + 16, x + 5, top + 16], fill=mul(coat, 0.75))
        d.line([(x + 3, top + 17), (x + 3, top + 18)], fill=legs)
        d.line([(x + 5, top + 17), (x + 5, top + 18)], fill=legs)
    d.line([(x + 2, top + 19), (x + 3, top + 19)], fill=(30, 22, 22))
    d.line([(x + 5, top + 19), (x + 6, top + 19)], fill=(30, 22, 22))
    # arms
    arm = mul(coat, 0.8)
    d.line([(back, top + 7), (back, top + 12)], fill=arm)
    if lantern:
        lx = front + 2 * f
        d.line([(front, top + 7), (front, top + 10)], fill=arm)
        d.point((front + f, top + 11), fill=skin)
        d.line([(lx, top + 11), (lx, top + 12)], fill=(60, 44, 34))
        d.rectangle([lx - 1, top + 13, lx + 1, top + 16], fill=GLOW)
        d.line([(lx - 1, top + 12), (lx + 1, top + 12)], fill=(60, 44, 34))
        d.point((lx, top + 14), fill=(255, 250, 220))
    elif carry == "sack":
        d.ellipse([back - 3 * f - 3, top + 1, back - 3 * f + 3, top + 7], fill=(206, 176, 124))
        d.point((back - 3 * f - 1, top + 2), fill=(232, 208, 160))
        d.line([(front, top + 7), (front, top + 11)], fill=arm)
    elif carry == "crate":
        bx = front + f
        d.rectangle([min(bx, bx + 5 * f), top + 8, max(bx, bx + 5 * f), top + 13], fill=(168, 114, 66))
        d.line([(min(bx, bx + 5 * f), top + 10), (max(bx, bx + 5 * f), top + 10)], fill=(112, 70, 40))
        d.line([(front, top + 7), (front + f, top + 9)], fill=arm)
    elif carry == "bundle":
        d.line([(front, top + 7), (front, top + 11)], fill=arm)
        d.ellipse([front, top + 10, front + 4 * f if f > 0 else front, top + 14], fill=(170, 140, 100))
        if f < 0:
            d.ellipse([front - 4, top + 10, front, top + 14], fill=(170, 140, 100))
    else:
        d.line([(front, top + 7), (front, top + 12)], fill=arm)


# -- quay ------------------------------------------------------------------------------
QTOP = 104   # front edge of the quay's walking surface
QBACK = 88  # back edge
QX = 128     # right end


def draw_quay(rnd):
    q = layer()
    d = ImageDraw.Draw(q)
    # walking surface: flagstones lit by the low sun
    d.polygon([(0, QBACK), (QX - 6, QBACK), (QX, QTOP), (0, QTOP)], fill=(176, 124, 90))
    px = q.load()
    for y in range(QBACK, QTOP):
        for x in range(0, QX):
            if not px[x, y][3]:
                continue
            t = (y - QBACK) / (QTOP - QBACK)
            c = ramp([(206, 150, 102), (186, 132, 94), (162, 114, 84)], t, x, y)
            row = (y - QBACK) // 3
            if (y - QBACK) % 3 == 2 or (x + row * 5) % 13 == 0:
                c = mul(c, 0.8)
            px[x, y] = c + (255,)
    d.line([(0, QBACK), (QX - 6, QBACK)], fill=(226, 172, 118))
    # coping stone edge
    d.rectangle([0, QTOP, QX, QTOP + 1], fill=(150, 110, 86))
    d.line([(0, QTOP), (QX, QTOP)], fill=(214, 164, 116))
    # front face in shadow: stone courses
    for y in range(QTOP + 2, H):
        course = (y - QTOP - 2) // 5
        for x in range(0, QX + 1):
            t = (y - QTOP) / (H - QTOP)
            c = ramp([(112, 84, 80), (94, 70, 72), (76, 58, 64), (64, 54, 60)], t, x, y)
            if (y - QTOP - 2) % 5 == 4:
                c = (54, 40, 44)
            else:
                off = 7 if course % 2 else 0
                if (x + off) % 14 == 13:
                    c = (54, 40, 44)
                elif (x + off) % 14 == 0 or (y - QTOP - 2) % 5 == 0:
                    c = mix(c, (150, 112, 96), 0.35)
            px[x, y] = c + (255,)
    # algae / wet line near the bottom
    for x in range(0, QX + 1):
        for y in (H - 4, H - 3):
            if rnd.random() < 0.6:
                px[x, y] = (58, 70, 60, 255)
    # quay end face
    d.line([(QX, QTOP), (QX, H)], fill=(60, 44, 48))
    # timber fenders on the face
    for fx in (40, 86, 122):
        d.rectangle([fx, QTOP + 2, fx + 2, H - 1], fill=(96, 62, 42))
        d.line([(fx, QTOP + 2), (fx, H - 1)], fill=(134, 90, 58))
    # iron mooring ring
    d.ellipse([62, QTOP + 7, 66, QTOP + 11], outline=(40, 36, 40))
    return q


def draw_props(rnd):
    p = layer()
    d = ImageDraw.Draw(p)

    def crate(x, y, w=9, h=8, c=(168, 114, 66)):
        d.rectangle([x, y - h, x + w - 1, y - 1], fill=c)
        d.rectangle([x, y - h, x + w - 1, y - h], fill=mul(c, 1.2))
        d.line([(x, y - h), (x + w - 1, y - 1)], fill=mul(c, 0.72))
        d.line([(x, y - 1), (x + w - 1, y - h)], fill=mul(c, 0.72))
        d.rectangle([x + w - 2, y - h + 1, x + w - 1, y - 1], fill=mul(c, 0.78))

    def barrel(x, y, c=(146, 90, 50)):
        d.rectangle([x, y - 8, x + 5, y - 1], fill=c)
        d.line([(x + 1, y - 9), (x + 4, y - 9)], fill=mul(c, 1.1))
        d.line([(x + 1, y), (x + 4, y)], fill=mul(c, 0.7))
        for hy in (y - 7, y - 2):
            d.line([(x, hy), (x + 5, hy)], fill=(70, 58, 56))
        d.line([(x + 1, y - 8), (x + 1, y - 1)], fill=mul(c, 1.25))
        d.line([(x + 5, y - 8), (x + 5, y - 1)], fill=mul(c, 0.72))

    def bollard(x, y):
        d.rectangle([x, y - 5, x + 3, y - 1], fill=(56, 54, 60))
        d.rectangle([x - 1, y - 6, x + 4, y - 5], fill=(72, 70, 78))
        d.point((x, y - 6), fill=(196, 150, 110))
        d.line([(x, y - 4), (x, y - 2)], fill=(110, 96, 96))

    def coil(x, y):
        d.ellipse([x, y - 4, x + 8, y], fill=(170, 130, 82))
        d.ellipse([x + 2, y - 3, x + 6, y - 1], fill=(120, 88, 58))
        d.point((x + 4, y - 2), fill=(170, 130, 82))
        d.line([(x + 1, y - 3), (x + 7, y - 3)], fill=(206, 166, 110))

    # stacked cargo at the back-left
    crate(1, 95, 11, 10)
    crate(12, 95, 10, 9, (156, 104, 60))
    crate(5, 85, 10, 9, (176, 122, 70))
    barrel(24, 95)
    barrel(31, 96, (134, 84, 48))
    barrel(27, 86)
    # sacks
    d.ellipse([38, 89, 46, 96], fill=(206, 176, 124))
    d.ellipse([43, 91, 51, 97], fill=(190, 160, 110))
    d.point((40, 90), fill=(232, 208, 160))
    # bollards, rope and a coil
    bollard(56, 104)
    bollard(116, 103)
    coil(86, 104)
    d.line([(118, 99), (130, 104), (140, 110)], fill=(150, 116, 76))
    # a lamp post
    d.line([(70, 94), (70, 74)], fill=(44, 40, 46))
    d.line([(70, 74), (73, 74)], fill=(44, 40, 46))
    d.rectangle([72, 75, 74, 78], fill=GLOW)
    d.point((73, 76), fill=(255, 250, 220))
    d.line([(69, 94), (71, 94)], fill=(44, 40, 46))
    return p


def draw_gangplank(d):
    d.polygon([(114, 104), (119, 103), (144, 112), (140, 114)], fill=(170, 116, 66))
    d.line([(114, 104), (140, 114)], fill=(110, 70, 42))
    for t in (0.2, 0.45, 0.7):
        x = 117 + t * 25
        y = 103.5 + t * 9.5
        d.line([(x, y), (x + 2, y - 1)], fill=(206, 150, 90))


def draw_piles(d):
    for x, top, bot in ((166, 104, 118), (171, 106, 118), (318, 102, 120)):
        d.rectangle([x, top, x + 2, bot], fill=(84, 54, 38))
        d.line([(x, top), (x, bot)], fill=(150, 104, 66))
        d.line([(x, top), (x + 2, top)], fill=(196, 146, 96))


# -- compose -------------------------------------------------------------------------------
def build():
    rnd = random.Random(3)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    draw_sky(img)
    draw_clouds(img)
    draw_sun(img)
    draw_gulls(img)

    far, near = draw_town()
    haze(far, (230, 140, 100), 0.25)
    near = rim(near, amt=0.3, top=True)

    # ships
    dist = Ship(172, 73, 0.16, flip=True)
    dist.draw(big=False)
    dist_l = haze(dist.finish(outlined=False, rim_amt=0), (150, 78, 80), 0.75)

    mid = Ship(134, 82, 0.56, flip=True, jib=False)
    mid.draw(big=False)
    mid_l = haze(mid.finish(outlined=False, rim_amt=0.5), (190, 104, 92), 0.28)

    big = Ship(202, 94, 1.0)
    big.draw(big=True)
    big_l = big.finish(outlined=True)

    draw_water(img)
    ripples(img, rnd)
    reflect(img, near, HORIZON, 0.4)
    reflect(img, dist_l, 73, 0.4)
    reflect(img, mid_l, 82, 0.45)
    reflect(img, big_l, 94, 0.55, gap=4)

    paste(img, far)
    paste(img, near)
    paste(img, dist_l)
    paste(img, mid_l)
    paste(img, big_l)

    # rowboats
    boats = layer()
    bd = ImageDraw.Draw(boats)
    rowboat(bd, 136, 113, 28, [((64, 72, 110), "tricorn"), ((150, 60, 50), "bonnet"),
                               ((96, 110, 70), "hat"), ((180, 150, 110), "bonnet")], rnd, oars=False)
    rowboat(bd, 184, 104, 22, [((80, 56, 44), "cap"), ((56, 70, 108), "tricorn"), ((160, 64, 54), "bonnet")], rnd)
    rowboat(bd, 256, 112, 24, [((70, 60, 90), "cap"), ((120, 90, 60), "hat"), ((200, 190, 170), "bonnet")], rnd)
    draw_piles(bd)
    boats = outline(rim(boats, amt=0.35))
    reflect(img, boats, 112, 0.35, gap=2)
    paste(img, boats)

    # quay, props, figures
    paste(img, draw_quay(rnd))
    fg = draw_props(rnd)
    fd = ImageDraw.Draw(fg)
    draw_gangplank(fd)
    figure(fd, 8, 103, (72, 90, 72), hat="cap", carry="sack", face=1, vest=(170, 150, 110))
    figure(fd, 44, 100, (134, 72, 50), hat="tricorn", face=1, carry="crate")
    figure(fd, 60, 102, (150, 60, 50), hat="bonnet", dress=True, face=1)
    figure(fd, 72, 100, (70, 66, 100), hat="broad", face=1, carry="bundle", vest=(190, 170, 130))
    figure(fd, 98, 103, (46, 48, 76), hat="tricorn", face=-1, lantern=True, vest=(176, 60, 50))
    fg = outline(rim(fg, amt=0.4))
    paste(img, fg)

    # a soft glow ring around lanterns
    px = img.load()
    for lx, ly in ((73, 76), (96, 97), (332, 57)):
        for y in range(ly - 4, ly + 5):
            for x in range(lx - 4, lx + 5):
                if 0 <= x < W and 0 <= y < H and 2.5 < math.hypot(x - lx, y - ly) <= 4 and (x + y) % 2 == 0:
                    px[x, y] = mix(px[x, y][:3], (255, 214, 130), 0.35) + (255,)
    return img.convert("RGB")


def main():
    img = build()
    big = img.resize((W * SCALE, H * SCALE), Image.NEAREST)
    big.save(OUT)
    print("banner", big.size, "->", OUT)
    if len(sys.argv) > 1:
        img.resize((W * 4, H * 4), Image.NEAREST).save(sys.argv[1])


if __name__ == "__main__":
    main()
