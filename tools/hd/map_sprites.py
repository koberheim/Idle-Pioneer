"""World-map sprites at double density, in the engraved-chart style.

Settlements are small ink-outlined wooden forts in 3/4 top-down view that grow
from a staked clearing to a bastioned capital; ships, the wagon, the site
marker and the treasure chest are side-view props. Every piece is drawn with
lib.py's shapes on a 4x canvas, reduced, palette-snapped and ink-outlined so
it reads on both the painted green map and the engraved tan one.

Run:  python tools/hd/map_sprites.py [review_sheet.png]

Game-side anchors (scripts/ui/map_view.gd): chimney smoke rises from
(34%, 20%) of a settlement sprite and a flag pole is drawn upward from
(82%, 8%). Every settlement plants a pole stub that ends at that point.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: E402,F401,F403
from lib import ROOT, SS, Icon, add_outline, mix, mul  # noqa: E402

from PIL import Image, ImageDraw  # noqa: E402

MAP = os.path.join(ROOT, "assets", "sprites", "map")

# Engraved-chart palette: weathered wood, sepia ink, muted roofs.
EARTH = (156, 128, 86)
EARTH_L = (182, 154, 106)
EARTH_D = (128, 102, 68)
TUFT = (108, 118, 64)
TUFT_D = (78, 90, 48)
LOG = (164, 118, 72)
LOG_L = (196, 150, 96)
LOG_D = (112, 76, 46)
STAKE = (158, 114, 68)
PLANK = (170, 128, 80)
ROOF_G = (112, 100, 90)        # grey-brown shingles
ROOF_B = (136, 98, 62)         # bark / thatch brown
ROOF_R = (152, 72, 54)         # muted red tile
ROOF_S = (104, 110, 118)       # slate
WHITEWASH = (234, 226, 206)
BRICK = (178, 96, 70)
STONE = (172, 164, 148)
STONE_L = (206, 198, 178)
STONE_D = (120, 112, 100)
WINDOW = (236, 206, 120)       # lamplit
DOOR = (70, 46, 30)
SAIL = (244, 232, 200)
SAIL_D = (206, 188, 150)
HULL = (122, 78, 44)
HULL_D = (84, 52, 30)
HULL_L = (164, 114, 66)
FOAM = (236, 244, 240)
WATER = (86, 150, 160)
PENNANT = (214, 58, 44)
PENNANT_L = (246, 104, 72)


class Sprite(Icon):
    """Icon with a non-square canvas and ink-outlined drawing helpers."""

    def __init__(self, w, h, seed=1):
        super().__init__(max(w, h), seed)
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

    # ink-outlined shapes -------------------------------------------------
    def ipoly(self, pts, color, ink=INK, lw=0.75, **kw):
        self.poly(pts, color, **kw)
        self.line(list(pts) + [pts[0]], ink, lw)

    def irect(self, box, color, ink=INK, lw=0.75, **kw):
        x0, y0, x1, y1 = box
        self.ipoly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], color, ink, lw, **kw)

    def iellipse(self, box, color, ink=INK, lw=0.75, **kw):
        self.ellipse((box[0] - lw / 2, box[1] - lw / 2, box[2] + lw / 2, box[3] + lw / 2), ink, shade=False)
        self.ellipse(box, color, **kw)

    def hatch(self, x0, x1, y0, y1, step, color, lw=0.5, vertical=True):
        """Engraver's hatching: parallel strokes across a box."""
        if vertical:
            x = x0
            while x <= x1:
                self.line([(x, y0), (x, y1)], color, lw)
                x += step
        else:
            y = y0
            while y <= y1:
                self.line([(x0, y), (x1, y)], color, lw)
                y += step

    def fill_mask(self, mask, color):
        layer = Image.new("RGBA", self.img.size, tuple(color[:3]) + (255,))
        self.img.paste(layer, (0, 0), mask)

    # output --------------------------------------------------------------
    def render(self, colors=48, outline=INK):
        w, h = self.w, self.h
        small = self.img.resize((w, h), Image.BOX)
        px = small.load()
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                px[x, y] = (r, g, b, 0) if a < 110 else (r, g, b, 255)
        rgb = small.convert("RGB")
        q = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        out.paste(q, (0, 0), small.getchannel("A"))
        out.putalpha(small.getchannel("A"))
        if outline is not None:
            out = add_outline(out, outline)
        return out

    def save(self, name, colors=48, outline=INK, folder=None):
        out = self.render(colors, outline)
        assert out.size == (self.w, self.h)
        out.save(os.path.join(folder or MAP, name + ".png"))
        return out


# ---------------------------------------------------------------------------
# Settlement parts (64x64, 3/4 top-down, light from the top-left)
# ---------------------------------------------------------------------------
POLE = (52.5, 5.2)   # where map_view.gd starts drawing the flag pole
SMOKE = (21.8, 12.8)  # where it puffs chimney smoke
LINE = (70, 46, 30)   # interior engraving lines, softer than the silhouette ink


def clearing(s, cx, cy, rx, ry, tufts=True):
    """Ragged oval of trodden earth with grass tufts on its rim."""
    rnd = s.rnd
    pts = []
    n = 60
    for i in range(n):
        a = i / n * math.tau
        k = 1.0 - rnd.random() * 0.07 + 0.03 * math.sin(a * 5 + 1.3)
        pts.append((cx + rx * k * math.cos(a), cy + ry * k * math.sin(a)))
    s.poly(pts, EARTH, shade=False)
    s.ellipse((cx - rx * 0.8, cy - ry * 0.74, cx + rx * 0.8, cy + ry * 0.8), EARTH_L, shade=False)
    # engraved stipple, denser toward the rim
    for _ in range(int(rx * ry * 0.16)):
        a = rnd.random() * math.tau
        r = math.sqrt(rnd.random())
        x, y = cx + rx * 0.95 * r * math.cos(a), cy + ry * 0.95 * r * math.sin(a)
        s.dot(x, y, EARTH_D if r > 0.6 else mix(EARTH_D, EARTH_L, 0.45), 0.45)
    if tufts:
        for i in range(int(rx * 0.8)):
            a = rnd.random() * math.tau
            if math.sin(a) < -0.3:
                continue  # rim behind the fort is hidden anyway
            x, y = cx + rx * 0.9 * math.cos(a), cy + ry * 0.9 * math.sin(a)
            s.line([(x - 1, y + 0.6), (x - 0.3, y - 1.1)], TUFT_D, 0.6)
            s.line([(x, y + 0.6), (x + 0.2, y - 1.5)], TUFT, 0.6)
            s.line([(x + 1, y + 0.6), (x + 0.8, y - 1.0)], TUFT_D, 0.6)


def cast(s, x0, x1, base, depth=3.0):
    """Soft shadow falling right and down from a building footprint."""
    s.shadow((x0 + x1) / 2 + 1.5, base + 0.4, (x1 - x0) / 2 + 1.5, depth, alpha=85)


def stake(s, x, base, h, color=STAKE, w=2.1):
    top = base - h
    c = mul(color, 0.92 + s.rnd.random() * 0.16)
    s.ipoly([(x - w / 2, base), (x - w / 2, top), (x, top - 1.7), (x + w / 2, top), (x + w / 2, base)],
            c, lw=0.6, light=0.3, dark=0.25, angle=180)
    s.dot(x - 0.3, top - 0.2, mul(c, 1.3), 0.45)  # sunlit point


def palisade(s, cx, cy, rx, ry, h, part, gaps=(), step=2.0, arc=None):
    """Ring of pointed stakes. part='back' draws the far half, 'front' the
    near half (call after buildings so it overlaps them). gaps are angle
    ranges in degrees (90 = front centre) left open; arc limits the ring."""
    per = math.pi * (3 * (rx + ry) - math.sqrt((3 * rx + ry) * (rx + 3 * ry)))
    n = int(per / step)
    stakes = []
    for i in range(n):
        a = i / n * 360.0
        if any(g0 <= a <= g1 for g0, g1 in gaps):
            continue
        if arc and not (arc[0] <= a <= arc[1]):
            continue
        r = math.radians(a)
        x, y = cx + rx * math.cos(r), cy + ry * math.sin(r)
        if (part == "front") != (math.sin(r) > 0.05):
            continue
        stakes.append((y, x))
    stakes.sort()
    # rail tying the stakes together, visible behind the back half
    for y, x in stakes:
        stake(s, x, y, h + s.rnd.uniform(-0.4, 0.4))


def gate(s, x, base, h, w=6):
    """Heavy gate posts and a plank gate under a lintel."""
    s.irect((x - w / 2, base - h + 1.5, x + w / 2, base), DOOR, lw=0.6, shade=False)
    s.hatch(x - w / 2 + 1, x + w / 2 - 0.8, base - h + 2, base - 0.5, 1.4, mul(DOOR, 1.5), 0.45)
    for gx in (x - w / 2 - 1.1, x + w / 2 + 1.1):
        s.ipoly([(gx - 1.3, base + 0.4), (gx - 1.3, base - h - 1), (gx, base - h - 2.8), (gx + 1.3, base - h - 1),
                 (gx + 1.3, base + 0.4)], LOG, lw=0.6, light=0.3, dark=0.3)
    s.irect((x - w / 2 - 2, base - h - 0.6, x + w / 2 + 2, base - h + 0.8), LOG_D, lw=0.5, shade=False)


def _slope_front(x, x0, xc, yl, ya):
    """y of the gable's front edge at x (x0 -> yl rising to xc -> ya)."""
    t = max(0.0, min(1.0, (x - x0) / (xc - x0)))
    return yl + (ya - yl) * t


def house(s, xc, base, w=11, wall_h=5, depth=6, roof=ROOF_G, wall="log", chimney=None, door=True,
          windows=True, texture="shingle"):
    """Gable-front house: the pitched end faces us and the roof runs back up
    the screen, so the classic house silhouette reads at a glance."""
    x0, x1 = xc - w / 2, xc + w / 2
    wt = base - wall_h
    apex = wt - w * 0.42
    cast(s, x0, x1, base, 2.6)
    e0, e1 = x0 - 1.2, x1 + 1.2
    ye = wt + 0.8
    ya = apex - 0.9
    lit, shd = mul(roof, 1.2), mul(roof, 0.8)
    s.ipoly([(e0, ye), (xc, ya), (xc, ya - depth), (e0, ye - depth)], lit, light=0.15, dark=0.1)
    s.ipoly([(xc, ya), (e1, ye), (e1, ye - depth), (xc, ya - depth)], shd, light=0.05, dark=0.15)
    # courses run along the eaves, i.e. straight up the screen here
    step = {"shingle": 1.6, "thatch": 1.0, "tile": 1.4}[texture]
    for side, (a, b, col) in enumerate(((e0, xc, mul(roof, 0.9)), (xc, e1, mul(roof, 0.62)))):
        x = a + step
        while x < b - 0.5:
            yf = _slope_front(x, e0, xc, ye, ya) if side == 0 else _slope_front(e1 - (x - xc), e0, xc, ye, ya)
            if texture == "shingle":
                yy = yf - 0.8
                k = 0
                while yy > yf - depth + 0.8:
                    s.line([(x, yy), (x, max(yf - depth + 0.6, yy - 1.2))], col, 0.4)
                    yy -= 2.0
                    k += 1
            else:
                s.line([(x, yf - 0.6), (x, yf - depth + 0.6)], col, 0.45)
            x += step
    s.line([(xc, ya), (xc, ya - depth)], mul(roof, 1.45), 0.55)  # ridge catches the light
    # gable wall
    wc = {"log": LOG, "plank": PLANK, "white": WHITEWASH, "stone": STONE, "brick": BRICK}[wall]
    s.ipoly([(x0, base), (x0, wt), (xc, apex), (x1, wt), (x1, base)], wc, lw=0.6, light=0.2, dark=0.2)
    if wall == "log":
        y = wt - 1.6
        while y < base - 0.4:
            if y > wt:
                s.line([(x0 + 0.4, y), (x1 - 0.4, y)], LOG_D, 0.45)
            else:
                half = (y - apex) / (wt - apex) * (w / 2) - 0.5
                if half > 0.6:
                    s.line([(xc - half, y), (xc + half, y)], LOG_D, 0.45)
            y += 1.4
    elif wall == "plank":
        x = x0 + 1.5
        while x < x1 - 0.5:
            s.line([(x, _slope_front(x if x < xc else 2 * xc - x, x0, xc, wt, apex) + 0.6), (x, base - 0.4)],
                   mul(PLANK, 0.74), 0.45)
            x += 1.6
    elif wall in ("brick", "stone"):
        y = wt + 1.4
        while y < base - 0.3:
            s.line([(x0 + 0.4, y), (x1 - 0.4, y)], mul(wc, 0.72), 0.4)
            y += 1.5
    # eave boards over the gable
    s.line([(e0, ye), (xc, ya), (e1, ye)], INK, 0.9)
    if door:
        s.irect((xc - 1.1, base - min(3.6, wall_h - 0.6), xc + 1.1, base), DOOR, lw=0.45, shade=False)
    if windows:
        s.irect((xc - 0.8, apex + 1.6, xc + 0.8, apex + 3.0), WINDOW, lw=0.45, shade=False)
        if w >= 10 and wall_h >= 5:
            for wx in (x0 + 1.8, x1 - 1.8):
                s.irect((wx - 0.8, wt + 1.2, wx + 0.8, wt + 2.8), WINDOW, lw=0.45, shade=False)
    if chimney:
        cx, top = chimney
        if cx < xc:
            yf = _slope_front(cx, e0, xc, ye, ya)
        else:
            yf = _slope_front(2 * xc - cx, e0, xc, ye, ya)
        bottom = yf - depth * 0.45
        _chimney(s, cx, top, bottom)


def _chimney(s, cx, top, bottom):
    s.irect((cx - 1.3, top, cx + 1.3, bottom), STONE, lw=0.55, light=0.3, dark=0.3)
    s.line([(cx - 1.2, top + 1.8), (cx + 1.2, top + 1.8)], STONE_D, 0.4)
    s.line([(cx - 1.2, top + 3.4), (cx + 1.2, top + 3.4)], STONE_D, 0.4)
    s.rect((cx - 0.8, top + 0.2, cx + 0.8, top + 0.9), CHARCOAL, shade=False)


def longhouse(s, x0, x1, base, wall_h=5, roof_d=8, roof=ROOF_G, wall="plank", chimney=None, doors=(),
              windows=(), texture="shingle"):
    """Ridge parallel to the front: warehouses, halls, the governor's house.
    Both slopes show; the gable ends are cut as small triangles at the sides."""
    cast(s, x0, x1, base, 2.8)
    wt = base - wall_h
    wc = {"log": LOG, "plank": PLANK, "white": WHITEWASH, "stone": STONE, "brick": BRICK}[wall]
    s.irect((x0, wt, x1, base), wc, lw=0.6, light=0.2, dark=0.25)
    if wall == "plank":
        s.hatch(x0 + 1.5, x1 - 0.8, wt + 0.5, base - 0.5, 1.6, mul(PLANK, 0.74), 0.45)
    elif wall == "log":
        s.hatch(x0 + 0.5, x1 - 0.5, wt + 1.3, base - 0.5, 1.4, LOG_D, 0.45, vertical=False)
    elif wall in ("brick", "stone"):
        s.hatch(x0 + 0.5, x1 - 0.5, wt + 1.4, base - 0.5, 1.5, mul(wc, 0.72), 0.4, vertical=False)
    for wx in windows:
        s.irect((wx - 0.8, wt + 1.2, wx + 0.8, wt + 2.9), WINDOW, lw=0.45, shade=False)
    for dx in doors:
        s.irect((dx - 1.2, base - min(3.8, wall_h - 0.6), dx + 1.2, base), DOOR, lw=0.45, shade=False)
    eave = wt + 0.8
    ridge = eave - roof_d * 0.55
    back = eave - roof_d
    r0, r1 = x0 - 1.2, x1 + 1.2
    # hipped ends read better than flat boxes at this size
    s.ipoly([(r0, eave), (r1, eave), (r1 - 2.2, ridge), (r0 + 2.2, ridge)], mul(roof, 0.92), light=0.1, dark=0.2)
    s.ipoly([(r0 + 2.2, ridge), (r1 - 2.2, ridge), (r1 - 0.6, back), (r0 + 0.6, back)], mul(roof, 1.22), light=0.1, dark=0.1)
    s.ipoly([(r0, eave), (r0 + 2.2, ridge), (r0 + 0.6, back)], mul(roof, 1.08), lw=0.5, shade=False)
    s.ipoly([(r1, eave), (r1 - 2.2, ridge), (r1 - 0.6, back)], mul(roof, 0.66), lw=0.5, shade=False)
    dark = mul(roof, 0.66)
    step = {"shingle": 1.6, "thatch": 1.0, "tile": 1.6}[texture]
    y = ridge + step
    while y < eave - 0.5:
        t = (y - ridge) / (eave - ridge)
        a, b = r0 + 2.2 - 2.2 * t + 0.6, r1 - 2.2 + 2.2 * t - 0.6
        if texture == "thatch":
            s.hatch(a, b, y - step + 0.3, y, 1.1, dark, 0.35)
        else:
            s.line([(a, y), (b, y)], dark, 0.45)
            xx = a + 1 + (int(y * 3) % 2) * 1.1
            while xx < b - 0.4:
                s.line([(xx, y - 1.3), (xx, y)], dark, 0.35)
                xx += 2.2
        y += step
    s.line([(r0 + 2.2, ridge), (r1 - 2.2, ridge)], mul(roof, 1.5), 0.55)
    if chimney:
        cx, top = chimney
        _chimney(s, cx, top, back + 2.4)


def blockhouse(s, cx, base, w=8, h1=6, h2=5, roof=ROOF_G, stone=False, peak=None):
    """Two-storey blockhouse with an overhanging upper floor and a pyramid
    roof; the flag pole rises from its peak."""
    x0, x1 = cx - w / 2, cx + w / 2
    cast(s, x0, x1 + 1, base, 3)
    low = STONE if stone else LOG
    s.irect((x0, base - h1, x1, base), low, lw=0.6, light=0.25, dark=0.3)
    s.hatch(x0 + 0.5, x1 - 0.5, base - h1 + 1.4, base - 0.5, 1.5, mul(low, 0.7), 0.45, vertical=False)
    s.rect((cx - 0.45, base - h1 + 1.8, cx + 0.45, base - h1 + 4), INK, shade=False)  # loophole
    u0, u1 = x0 - 1.4, x1 + 1.4
    top = base - h1 - h2
    s.irect((u0, top, u1, base - h1 + 0.6), LOG_L, lw=0.6, light=0.25, dark=0.3)
    s.shadow(cx + 0.5, base - h1 + 1.2, w / 2 + 0.5, 0.7, alpha=120)
    s.hatch(u0 + 0.5, u1 - 0.5, top + 1.4, base - h1 - 0.2, 1.4, LOG_D, 0.45, vertical=False)
    for lx in (cx - 2.2, cx + 2.2):
        s.rect((lx - 0.45, top + 1.4, lx + 0.45, top + 3.4), INK, shade=False)
    pk = peak if peak is not None else top - 7
    e0, e1 = u0 - 1.2, u1 + 1.2
    s.ipoly([(e0, top + 0.7), (cx, pk), (cx, top + 2.0)], mul(roof, 1.2), light=0.15, dark=0.1)
    s.ipoly([(cx, top + 2.0), (cx, pk), (e1, top + 0.7)], mul(roof, 0.8), light=0.05, dark=0.2)
    for i in range(1, 5):
        t = i / 5
        y = pk + (top + 0.7 - pk) * t
        s.line([(cx - (cx - e0) * t + 0.5, y), (cx - 0.3, y + 1.3 * t)], mul(roof, 0.9), 0.4)
        s.line([(cx + 0.3, y + 1.3 * t), (cx + (e1 - cx) * t - 0.5, y)], mul(roof, 0.6), 0.4)
    s.line([(e0, top + 0.7), (cx, top + 2.0), (e1, top + 0.7)], INK, 0.8)


def church(s, x0, x1, base, tower_x, wall_h=6, roof=ROOF_S, spire_top=None):
    """Whitewashed meeting house with a steeple rising from its front."""
    longhouse(s, x0, x1, base, wall_h, 8, roof, "white", windows=(x0 + 2.4, x1 - 2.4), texture="tile")
    tw = 5.2
    t0, t1 = tower_x - tw / 2, tower_x + tw / 2
    ttop = base - wall_h - 6
    s.irect((t0, ttop, t1, base + 0.8), WHITEWASH, lw=0.6, light=0.3, dark=0.3)
    s.irect((tower_x - 1.1, base - 3.2, tower_x + 1.1, base + 0.8), DOOR, lw=0.45, shade=False)
    s.ipoly([(tower_x - 1, ttop + 4), (tower_x - 1, ttop + 2.4), (tower_x, ttop + 1.4), (tower_x + 1, ttop + 2.4),
             (tower_x + 1, ttop + 4)], INK, lw=0.4, shade=False)  # belfry
    s.irect((t0 - 0.6, ttop - 0.4, t1 + 0.6, ttop + 0.8), WHITEWASH, lw=0.5, shade=False)
    sp = spire_top if spire_top is not None else ttop - 9
    s.ipoly([(t0 - 0.2, ttop - 0.4), (tower_x, sp), (tower_x, ttop - 0.4)], mul(roof, 1.3), lw=0.6, light=0.1, dark=0.05)
    s.ipoly([(tower_x, ttop - 0.4), (tower_x, sp), (t1 + 0.2, ttop - 0.4)], mul(roof, 0.78), lw=0.6, light=0.05, dark=0.1)
    s.line([(tower_x, sp), (tower_x, sp - 2.6)], INK, 0.6)
    s.line([(tower_x - 1.1, sp - 1.7), (tower_x + 1.1, sp - 1.7)], INK, 0.55)


def extrude(s, pts, h, face, top, lw=0.7, courses=(), arris_below=None):
    """A raised platform: stone faces swept down by h under a lit top."""
    k = h
    while k >= 0:
        s.poly([(x, y + k) for x, y in pts], face if k > h * 0.45 else mul(face, 1.15), shade=False)
        k -= 0.5
    low = [(x, y + h) for x, y in pts]
    s.line(low + [low[0]], INK, lw)
    for f in courses:
        s.line([(x, y + h * f) for x, y in pts] + [(pts[0][0], pts[0][1] + h * f)], mix(face, INK, 0.3), 0.4)
    cy = sum(y for _, y in pts) / len(pts)
    for x, y in pts:
        if arris_below is None or y > cy + arris_below:
            s.line([(x, y), (x, y + h)], INK, 0.55)
    s.ipoly(pts, top, lw=lw, light=0.2, dark=0.15)


def flagpole(s, base_y, x=None):
    """Pole from its footing up to where the game draws the rest of it."""
    px, y = POLE
    x = px if x is None else x
    s.line([(x, y), (x, base_y)], INK, 1.2)
    s.line([(x - 0.15, y + 0.5), (x - 0.15, base_y - 0.5)], LOG_L, 0.4)


def barrel(s, x, base):
    s.iellipse((x - 1.6, base - 3.6, x + 1.6, base), WOOD, lw=0.6, light=0.3)
    s.line([(x - 1.5, base - 2.5), (x + 1.5, base - 2.5)], IRON_D, 0.45)
    s.line([(x - 1.5, base - 1.0), (x + 1.5, base - 1.0)], IRON_D, 0.45)


def logpile(s, x, base):
    for lx, ly in ((x, base - 1.3), (x + 2.6, base - 1.3), (x + 1.3, base - 3.6)):
        s.irect((lx - 5, ly - 1.2, lx + 1.2, ly + 1.2), BARK, lw=0.5, light=0.2, dark=0.2)
        s.iellipse((lx - 0.1, ly - 1.25, lx + 2.4, ly + 1.25), PINE, lw=0.5, shade=False)
        s.dot(lx + 1.15, ly, WOOD, 0.4)


def tent(s, x, base, w=5.5, h=7):
    """A-frame canvas tent, open flap toward us."""
    cast(s, x - w, x + w, base, 1.8)
    s.ipoly([(x - w, base), (x - 0.4, base - h), (x + 1.6, base - h - 1.6), (x + w + 1.8, base - 1.4), (x + w, base)],
            SAIL_D, lw=0.6, shade=False)  # side of the ridge going back
    s.ipoly([(x - w, base), (x, base - h), (x + w, base)], LINEN, lw=0.7, light=0.3, dark=0.3)
    s.ipoly([(x - 1.4, base), (x, base - h * 0.62), (x + 1.4, base)], DOOR, lw=0.4, shade=False)
    s.line([(x, base - h), (x, base - h - 1.6)], INK, 0.6)


def campfire(s, x, y):
    for a in range(0, 360, 60):
        r = math.radians(a)
        s.dot(x + 2.2 * math.cos(r), y + 1.1 * math.sin(r), STONE_D, 0.7)
    s.line([(x - 1.8, y + 0.6), (x + 1.8, y - 0.4)], BARK, 0.9)
    s.line([(x - 1.8, y - 0.4), (x + 1.8, y + 0.6)], BARK, 0.9)
    s.poly([(x - 1.7, y + 0.4), (x - 0.8, y - 2.6), (x - 0.1, y - 1.4), (x + 0.5, y - 3.8), (x + 1.7, y + 0.4)],
           (236, 120, 40), shade=False)
    s.poly([(x - 0.9, y + 0.2), (x, y - 2.2), (x + 0.9, y + 0.2)], (255, 222, 110), shade=False)


def bastion(s, x, y, r=4.5, h=4):
    """Arrowhead stone bastion jutting from a palisade."""
    pts = [(x - r, y - r * 0.2), (x, y - r * 0.55), (x + r, y - r * 0.2), (x, y + r * 0.62)]
    s.shadow(x + 1.5, y + h + 0.8, r + 1, 1.6, alpha=90)
    extrude(s, pts, h, STONE_D, STONE, courses=(0.5,))
    s.dot(x - r * 0.4, y - r * 0.25, STONE_D, 0.5)
    s.dot(x + r * 0.4, y - r * 0.25, STONE_D, 0.5)
    s.dot(x, y + r * 0.2, STONE_D, 0.5)


# ---------------------------------------------------------------------------
# Settlements
# ---------------------------------------------------------------------------
def colony_1():
    """A new outpost: palisade still going up, one cabin, a tent."""
    s = Sprite(64, 64, seed=11)
    clearing(s, 31, 42, 25, 16)
    cx, cy, rx, ry = 31, 41, 20, 11.5
    palisade(s, cx, cy, rx, ry, 5, "back", arc=(150, 318))
    flagpole(s, 36)
    s.ellipse((POLE[0] - 1.8, 35.2, POLE[0] + 1.8, 37), STONE_D, shade=False)  # footing
    house(s, 19, 34, w=12, wall_h=5, depth=8, roof=ROOF_B, wall="log", chimney=SMOKE, texture="thatch")
    tent(s, 38, 42)
    campfire(s, 29, 46)
    logpile(s, 44, 51)
    palisade(s, cx, cy, rx, ry, 5, "front", arc=(118, 180))
    # stakes waiting to be raised
    for x, y in ((21, 54.5), (24.5, 55.3)):
        s.line([(x - 3.5, y), (x + 3.5, y + 0.6)], STAKE, 1.4)
        s.line([(x - 3.5, y + 0.8), (x + 3.5, y + 1.4)], LINE, 0.4)
    return s.save("colony_1")


def colony_2():
    """A growing fort: full palisade and gate, a blockhouse, three cabins."""
    s = Sprite(64, 64, seed=12)
    clearing(s, 32, 41, 29, 19)
    cx, cy, rx, ry = 32, 40, 25, 14.5
    palisade(s, cx, cy, rx, ry, 5.5, "back")
    house(s, 19, 32, w=12, wall_h=5, depth=8, roof=ROOF_G, wall="log", chimney=SMOKE)
    blockhouse(s, POLE[0], 33, w=8, h1=5.5, h2=5, peak=12)
    flagpole(s, 12.5)
    house(s, 36, 38, w=10, wall_h=4.5, depth=5, roof=ROOF_B, wall="log", texture="thatch")
    house(s, 24, 45, w=10, wall_h=4.5, depth=5, roof=ROOF_R, wall="plank", texture="tile")
    barrel(s, 33, 47.5)
    barrel(s, 36, 48.5)
    logpile(s, 45, 48)
    palisade(s, cx, cy, rx, ry, 5.5, "front", gaps=((80, 100),))
    gate(s, cx, cy + ry + 0.5, 5.5, w=5)
    return s.save("colony_2")


def colony_3():
    """A thriving town: palisade with stone bastions, church, warehouse,
    several houses and a stone-footed blockhouse."""
    s = Sprite(64, 64, seed=13)
    clearing(s, 32, 41, 31, 21)
    cx, cy, rx, ry = 32, 40, 27, 15.5
    palisade(s, cx, cy, rx, ry, 5.5, "back")
    house(s, 18, 32, w=12, wall_h=5, depth=8, roof=ROOF_R, wall="plank", chimney=SMOKE, texture="tile")
    church(s, 29, 42, 33, tower_x=33, wall_h=5.5, spire_top=9)
    blockhouse(s, POLE[0], 32, w=8, h1=5.5, h2=5, stone=True, peak=12)
    flagpole(s, 12.5)
    longhouse(s, 20, 37, 46, wall_h=5, roof_d=7, roof=ROOF_G, wall="plank", doors=(28.5,), windows=(23, 34))
    house(s, 10, 44, w=9, wall_h=4.5, depth=5, roof=ROOF_B, wall="log", texture="thatch")
    house(s, 45, 45, w=10, wall_h=4.5, depth=5, roof=ROOF_R, wall="white", texture="tile")
    barrel(s, 39.5, 49)
    palisade(s, cx, cy, rx, ry, 5.5, "front", gaps=((82, 98), (124, 148), (32, 56)))
    gate(s, cx, cy + ry + 0.5, 5.5, w=4.5)
    bastion(s, cx + rx * math.cos(math.radians(136)), cy + ry * math.sin(math.radians(136)) - 1.5, 6, 5)
    bastion(s, cx + rx * math.cos(math.radians(44)), cy + ry * math.sin(math.radians(44)) - 1.5, 6, 5)
    return s.save("colony_3")


def star_fort(s, cx, cy, sx, sy, h):
    """Bastioned trace in 3/4 view: stone faces under a pale rampart walk."""
    unit = [(-0.6, -1), (-0.65, -1.22), (-1.4, -1.4), (-1.22, -0.65), (-1, -0.6),
            (-1, 0.6), (-1.22, 0.65), (-1.4, 1.4), (-0.65, 1.22), (-0.6, 1),
            (0.6, 1), (0.65, 1.22), (1.4, 1.4), (1.22, 0.65), (1, 0.6),
            (1, -0.6), (1.22, -0.65), (1.4, -1.4), (0.65, -1.22), (0.6, -1)]
    outer = [(cx + x * sx, cy + y * sy) for x, y in unit]
    s.shadow(cx + 2, cy + h + 2, sx * 1.45, sy * 1.35, alpha=60)
    extrude(s, outer, h, STONE, STONE_L, lw=0.8, courses=(0.4, 0.75), arris_below=-sy * 0.3)
    inner = [(cx + x * sx * 0.8, cy + y * sy * 0.74) for x, y in unit]
    s.ipoly(inner, mix(STONE_D, EARTH, 0.4), lw=0.6, shade=False)  # inner face in shadow
    court = [(x, y + 1.6) for x, y in inner]
    s.poly(court, EARTH_L, shade=False)
    s.line(court + [court[0]], LINE, 0.5)
    # embrasures along the parapet
    for i in range(len(outer)):
        x0, y0 = outer[i]
        x1, y1 = outer[(i + 1) % len(outer)]
        m = int(math.hypot(x1 - x0, y1 - y0) / 3.2)
        for j in range(1, m):
            t = j / m
            s.dot(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, STONE_D, 0.45)
    return outer


def capital():
    """The capital: stone star fort, governor's hall, church, townhouses,
    the flag flying from the north-east bastion."""
    s = Sprite(64, 64, seed=14)
    clearing(s, 32, 42, 31, 21)
    star_fort(s, 31, 38, 18, 11.5, 4.5)
    longhouse(s, 12, 30, 31, wall_h=6, roof_d=9, roof=ROOF_R, wall="brick", chimney=SMOKE, doors=(21,),
              windows=(14.5, 17.5, 24.5, 27.5), texture="tile")
    fx = POLE[0]
    s.irect((fx - 1.6, 21.5, fx + 1.6, 24), STONE_D, lw=0.5, shade=False)
    flagpole(s, 22.5)
    church(s, 35, 47, 34, tower_x=39, wall_h=6, spire_top=9)
    house(s, 18, 44, w=10, wall_h=4.5, depth=5, roof=ROOF_G, wall="white", texture="shingle")
    house(s, 43, 45, w=10, wall_h=4.5, depth=5, roof=ROOF_R, wall="brick", texture="tile")
    house(s, 30.5, 46, w=8, wall_h=4, depth=4, roof=ROOF_B, wall="plank", windows=False)
    # gate in the near curtain
    s.irect((28.6, 49.6, 32.4, 54.5), DOOR, lw=0.6, shade=False)
    s.line([(30.5, 49.8), (30.5, 54.3)], mul(DOOR, 1.6), 0.45)
    # guns on the near bastions
    for gx, gy in ((10.5, 52.5), (51.5, 52.5)):
        s.line([(gx - 1.6, gy + 0.6), (gx + 1.6, gy - 0.6)], IRON_D, 1.1)
    return s.save("capital", colors=56)


# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------
def site():
    """Surveyor's stake with a red pennant over a pegged-out plot."""
    s = Sprite(32, 32, seed=21)
    # a patch of cleared ground, pegged out and roped from the stake
    s.ellipse((3, 21, 29, 30.5), EARTH, shade=False)
    s.ellipse((5, 22, 27, 29.4), EARTH_L, shade=False)
    s.speckle((5, 22, 27, 29.5), EARTH_D, 26, 0.45)
    for x, y in ((6.5, 26.5), (27, 25.5), (11, 29)):
        s.line([(16.5, 25), (x, y - 2.6)], CREAM, 0.8)
    for x, y in ((6.5, 26.5), (27, 25.5), (11, 29)):
        s.ipoly([(x - 1, y), (x - 1, y - 3.6), (x, y - 4.6), (x + 1, y - 3.6), (x + 1, y)], WOOD_L, lw=0.6, shade=False)
        s.line([(x - 0.9, y - 3.4), (x + 0.9, y - 3.4)], PENNANT, 0.7)
    # main stake
    s.shadow(17.5, 25.3, 4.5, 1.4, alpha=100)
    s.ipoly([(14.8, 25.5), (14.8, 6), (16.5, 4.6), (18.2, 6), (18.2, 25.5)], WOOD_L, lw=0.7, light=0.3, dark=0.3, angle=180)
    s.line([(15.2, 12), (17.8, 12)], mul(WOOD, 0.8), 0.5)
    s.line([(15.2, 18), (17.8, 18)], mul(WOOD, 0.8), 0.5)
    # swallow-tailed pennant
    s.ipoly([(18.2, 5.4), (29.5, 7.2), (25.5, 9.8), (29.5, 12.6), (18.2, 13.4)], PENNANT, lw=0.7, light=0.35, dark=0.25)
    s.line([(19.5, 7.2), (25, 8)], PENNANT_L, 0.8)
    s.dot(21.5, 9.5, GOLD, 1.2)
    # a white blaze nailed to the stake
    s.irect((13.4, 14.2, 19.6, 16.8), CREAM, lw=0.55, shade=False)
    return s.save("site", colors=32)


def wheel(s, x, y, r):
    s.iellipse((x - r, y - r, x + r, y + r), WOOD_D, lw=0.7, shade=False)
    s.ellipse((x - r + 0.9, y - r + 0.9, x + r - 0.9, y + r - 0.9), (78, 56, 38), shade=False)
    for k in range(6):
        t = math.pi * k / 3 + 0.3
        s.line([(x, y), (x + (r - 0.8) * math.cos(t), y + (r - 0.8) * math.sin(t))], WOOD, 0.6)
    s.iellipse((x - 1, y - 1, x + 1, y + 1), IRON, lw=0.4, shade=False)


def wagon():
    """Covered wagon drawn by an ox, heading right."""
    s = Sprite(32, 30, seed=22)
    s.shadow(16, 27.5, 15, 1.6, alpha=90)
    # ox, in front (right)
    OX, OX_D = (150, 104, 66), (96, 64, 40)
    s.line([(19.5, 18.6), (24, 17.4)], WOOD_D, 1.0)  # tongue
    for lx, far in ((22.4, True), (26.8, True), (23.4, False), (27.8, False)):
        c = OX_D if far else mul(OX, 0.85)
        s.line([(lx, 18), (lx - (0.4 if far else 0), 25.4)], c, 1.2)
        s.line([(lx - 0.6, 25.8), (lx + 0.6, 25.8)], INK, 0.9)
    s.iellipse((20.6, 13.2, 29.4, 20.4), OX, lw=0.7, light=0.3, dark=0.3)
    s.line([(21.6, 14.6), (20.4, 18.8)], OX_D, 0.6)  # tail
    s.ipoly([(27.4, 14), (30, 14.2), (31.6, 17.6), (30.6, 19), (28.6, 18.4), (27.4, 16.4)], OX, lw=0.7, light=0.3, dark=0.2)
    s.ellipse((29.6, 17.2, 31.6, 19), (206, 174, 134), shade=False)  # pale muzzle
    s.dot(29.4, 15.4, INK, 0.5)
    s.line([(28.2, 14.2), (27.2, 12.4), (27.6, 10.8)], CREAM, 0.8)  # horns
    s.line([(29.6, 14.2), (30.8, 12.6), (30.6, 11.2)], CREAM, 0.8)
    s.line([(27.6, 13.2), (27.2, 17.2)], WOOD_D, 1.0)  # yoke
    # wagon box
    s.irect((2.5, 15.5, 20, 20.2), WOOD, lw=0.7, light=0.25, dark=0.3)
    s.hatch(3, 19.5, 17, 19.2, 1.5, WOOD_D, 0.45, vertical=False)
    # bonnet: canvas over hoops
    s.ipoly([(2.2, 15.8), (1.4, 8), (3.2, 4.4), (10.8, 3.2), (17.8, 4.4), (20, 8), (19.6, 15.8)], SAIL, lw=0.75, light=0.2, dark=0.35)
    for hx in (6.2, 11, 15.6):
        s.line([(hx, 4.2), (hx - 0.2, 15.6)], SAIL_D, 0.55)
    s.ipoly([(2.2, 15.8), (1.4, 8), (3.2, 4.4), (4.8, 8), (4.6, 15.8)], mix(SAIL_D, INK_SOFT, 0.2), lw=0.6, shade=False)
    wheel(s, 6, 22, 4.2)
    wheel(s, 16.5, 23, 3.3)
    return s.save("wagon", colors=36)


def hull_shape(s, pts, stripe=None, gunports=()):
    s.ipoly(pts, HULL, lw=0.8, light=0.25, dark=0.35)
    if stripe:
        s.line(stripe, HULL_L, 0.8)
    for x, y in gunports:
        s.rect((x - 0.6, y - 0.5, x + 0.6, y + 0.5), INK, shade=False)


def ship():
    """A small coastal sloop, one mast, gaff main and jib, heading right."""
    s = Sprite(32, 32, seed=23)
    # hull: low stern at left, sheer rising to the bow at right
    hull = [(2.6, 19.4), (8, 20.4), (24, 20.2), (30.6, 18.6), (28.4, 22.6), (24.6, 25.8), (8.6, 26), (4.6, 23.4)]
    s.line([(29, 19.4), (31.6, 17.2)], WOOD_D, 0.9)  # bowsprit
    # gaff mainsail aft of the mast
    s.ipoly([(15.2, 19.2), (15.2, 5.2), (5.5, 7.4), (5.2, 18.6)], SAIL, lw=0.7, light=0.25, dark=0.3, angle=-160)
    s.line([(10, 6.5), (10, 18.8)], SAIL_D, 0.45)
    s.line([(5.4, 13), (15, 12.6)], SAIL_D, 0.45)
    # jib forward
    s.ipoly([(16.4, 5.4), (30.6, 18.2), (16.4, 18.6)], SAIL, lw=0.7, light=0.3, dark=0.25, angle=-160)
    s.line([(18, 10), (24, 17)], SAIL_D, 0.45)
    # mast, gaff and boom
    s.line([(15.8, 3), (15.8, 21)], WOOD_D, 1.0)
    s.line([(4.6, 18.8), (16, 18.8)], WOOD_D, 0.7)
    s.line([(15.6, 5.2), (5, 7.4)], WOOD_D, 0.7)
    s.poly([(16.2, 1.6), (21.8, 2.6), (16.2, 3.8)], PENNANT, shade=False)
    hull_shape(s, hull, stripe=[(4.2, 21.6), (8, 22.2), (24, 22), (28.8, 20.6)], gunports=((12, 23.6), (17, 23.6), (22, 23.5)))
    # bow wave
    s.line([(21, 26.6), (27, 24.2), (30.5, 25.4)], FOAM, 0.7)
    s.line([(4, 26.6), (11, 27)], FOAM, 0.6)
    return s.save("ship", colors=32)


def merchantman():
    """Three-masted merchant ship with cream square sails, heading right."""
    s = Sprite(40, 34, seed=24)
    # hull with raised stern castle (left) and forecastle (right)
    hull = [(2, 17.6), (7.5, 17.6), (8, 20.8), (29, 20.8), (29.4, 19.6), (35, 19.4), (33.4, 24.6),
            (29, 28.4), (8, 28.4), (4, 25.6), (2.6, 21)]
    s.line([(33.6, 20.2), (39.4, 16.6)], WOOD_D, 1.0)  # bowsprit
    s.line([(39, 17), (29.8, 4.2)], INK_SOFT, 0.4)  # forestay
    masts = [(9.6, 5.6, 0.72), (20, 2.2, 1.0), (29.2, 5.0, 0.8)]
    for mx, top, k in masts:
        s.line([(mx, top), (mx, 21)], WOOD_D, 0.9)
    for mx, top, k in masts:
        # two tiers of square sails, bellied a touch forward
        w1, w2 = 5.2 * k + 0.6, 4.2 * k + 0.4
        y0 = top + 2.0
        y1 = y0 + 7.6 * k
        y2 = y1 + 1.0
        y3 = min(19.2, y2 + 7.8 * k)
        s.ipoly([(mx - w2, y0), (mx + w2, y0), (mx + w2 + 0.6, y1), (mx - w2 + 0.4, y1)], SAIL, lw=0.6, light=0.25, dark=0.3)
        s.ipoly([(mx - w1, y2), (mx + w1, y2), (mx + w1 + 0.8, y3), (mx - w1 + 0.4, y3)], SAIL, lw=0.6, light=0.25, dark=0.3)
        s.line([(mx + w2 - 0.8, y0 + 0.8), (mx + w2 - 0.4, y1 - 0.6)], SAIL_D, 0.5)
        s.line([(mx + w1 - 1.0, y2 + 0.8), (mx + w1 - 0.4, y3 - 0.6)], SAIL_D, 0.5)
        s.line([(mx - w2 - 0.3, y0), (mx + w2 + 0.3, y0)], WOOD_D, 0.55)
        s.line([(mx - w1 - 0.3, y2), (mx + w1 + 0.3, y2)], WOOD_D, 0.55)
        s.line([(mx, top - 0.4), (mx, y0)], WOOD_D, 0.7)
    s.poly([(20.4, 0.4), (25.6, 1.2), (20.4, 2.3)], PENNANT, shade=False)
    # spanker (fore-and-aft) on the mizzen
    s.ipoly([(9, 10), (3.2, 15.8), (9, 16.4)], SAIL_D, lw=0.5, shade=False)
    hull_shape(s, hull, stripe=[(8.2, 22.6), (33, 22.2)], gunports=((12, 24.4), (16.5, 24.4), (21, 24.4), (25.5, 24.3)))
    s.line([(2.4, 18.8), (7.4, 18.8)], HULL_L, 0.5)
    s.irect((2.6, 18.6, 5, 21.6), WINDOW, lw=0.4, shade=False)  # stern lights
    s.line([(8, 20.8), (8, 18), (2, 17.6)], INK, 0.5)
    s.line([(29.2, 21), (29.6, 19.6)], INK, 0.5)
    s.line([(28, 28.9), (34, 25.4), (37.5, 27)], FOAM, 0.75)
    s.line([(4, 29), (11, 29.2)], FOAM, 0.6)
    return s.save("merchantman", colors=36)


def chest():
    """Treasure chest washed up on a sandbar, lid open on gold."""
    s = Sprite(32, 32, seed=25)
    # little sandbar lapped by a foam ring so it reads on water and land
    s.ellipse((2, 20, 30, 30.5), FOAM, shade=False)
    s.ellipse((3.5, 20.6, 28.5, 29.4), (222, 196, 138), shade=False)
    s.speckle((5, 22, 27, 29), (196, 168, 112), 30, 0.4)
    s.shadow(17, 26, 10, 2.2, alpha=90)
    # open lid, tilted back
    s.ipoly([(6.5, 15), (8, 7.4), (24.4, 7.4), (25.8, 15)], LEATHER_D, lw=0.8, light=0.2, dark=0.3)
    s.ipoly([(8.2, 14.6), (9.4, 9), (23, 9), (24.2, 14.6)], mul(LEATHER_D, 0.6), lw=0.5, shade=False)
    # gold heap
    for x, y, r in ((10.5, 15, 2.2), (14, 14, 2.6), (18, 13.6, 2.6), (21.6, 14.8, 2.2), (16, 12.4, 2.1)):
        s.iellipse((x - r, y - r * 0.7, x + r, y + r * 0.7), GOLD, lw=0.5, light=0.3, dark=0.3)
    s.dot(12.8, 13.2, CREAM, 0.6)
    s.dot(17.2, 11.8, CREAM, 0.6)
    # chest body
    s.irect((6, 15.4, 26, 26), WOOD, lw=0.8, light=0.25, dark=0.3)
    s.hatch(6.6, 25.4, 18.4, 25, 2.2, WOOD_D, 0.45, vertical=False)
    for bx in (9, 23):
        s.irect((bx - 1.1, 15.4, bx + 1.1, 26), BRASS, lw=0.5, light=0.3, dark=0.3)
    s.irect((6, 15.4, 26, 17.2), BRASS, lw=0.5, light=0.3, dark=0.3)
    s.irect((14.4, 17.6, 17.6, 21.4), GOLD, lw=0.5, light=0.3, dark=0.2)
    s.dot(16, 19.8, INK, 0.5)
    # glints
    for gx, gy, r in ((26.5, 6.5, 3.2), (6.2, 9.8, 2.0)):
        s.line([(gx - r, gy), (gx + r, gy)], CREAM, 0.7)
        s.line([(gx, gy - r), (gx, gy + r)], CREAM, 0.7)
        s.dot(gx, gy, WHITE, 0.8)
    return s.save("chest", colors=36)


# ---------------------------------------------------------------------------
NAMES = ["colony_1", "colony_2", "colony_3", "capital", "site", "wagon", "ship", "merchantman", "chest"]


def review_sheet(path, scale=4):
    ims = [Image.open(os.path.join(MAP, n + ".png")).convert("RGBA") for n in NAMES]
    cell = 64 * scale + 16
    bgs = [(214, 190, 140), (90, 120, 60)]
    s = Image.new("RGBA", (cell * 5, cell * 2 * len(bgs)), (0, 0, 0, 255))
    for b, bg in enumerate(bgs):
        panel = Image.new("RGBA", (cell * 5, cell * 2), bg + (255,))
        for i, im in enumerate(ims):
            big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
            cx, cy = (i % 5) * cell + 8, (i // 5) * cell + 8
            panel.alpha_composite(big, (cx, cy))
        s.alpha_composite(panel, (0, b * cell * 2))
    s.save(path)


if __name__ == "__main__":
    colony_1()
    colony_2()
    colony_3()
    capital()
    site()
    wagon()
    ship()
    merchantman()
    chest()
    for n in NAMES:
        im = Image.open(os.path.join(MAP, n + ".png"))
        print(n, im.size)
    if len(sys.argv) > 1:
        review_sheet(sys.argv[1])
