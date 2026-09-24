"""High-density pixel-art icons.

Each icon is drawn with simple shapes on a 4x supersampled canvas, then
reduced to its native size (48 px by default), snapped to a small palette and
given a tinted outline. The result reads as hand-placed pixels at roughly one
art pixel per screen pixel, the density of Graveyard Keeper or Balatro,
rather than the chunky 16 px look of the first icons.

Coordinates are in output pixels (0..size), floats allowed. Light comes from
the top-left: every filled shape gets a soft highlight there and shade on the
opposite side unless shade=False.

    ic = Icon()
    ic.ellipse((8, 10, 40, 42), GOLD)
    ic.line([(14, 20), (34, 20)], INK, 2)
    ic.save("gold")
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "sprites", "icons")
SS = 4

# A warm, slightly desaturated palette in the Colonization spirit.
INK = (44, 28, 20)
INK_SOFT = (84, 58, 40)
WHITE = (246, 240, 224)
LINEN = (226, 214, 186)
PARCH = (232, 214, 170)
PARCH_D = (196, 170, 124)
WOOD = (150, 98, 54)
WOOD_D = (104, 64, 34)
WOOD_L = (196, 142, 86)
PINE = (212, 172, 112)
BARK = (110, 76, 48)
LEAF = (86, 150, 66)
LEAF_D = (46, 100, 48)
LEAF_L = (146, 196, 92)
STRAW = (232, 192, 86)
STRAW_D = (184, 136, 44)
GOLD = (240, 196, 72)
GOLD_D = (176, 120, 30)
BRASS = (200, 160, 70)
SILVER = (208, 214, 222)
SILVER_D = (128, 136, 150)
IRON = (104, 108, 116)
IRON_D = (62, 64, 72)
RUST = (150, 82, 48)
RED = (184, 54, 44)
RED_D = (118, 32, 30)
NAVY = (46, 66, 130)
NAVY_D = (28, 38, 82)
SKY = (140, 186, 226)
SEA = (54, 110, 150)
INDIGO = (74, 62, 160)
INDIGO_D = (40, 32, 98)
TOBACCO = (150, 96, 44)
TOBACCO_D = (100, 60, 28)
LEATHER = (156, 96, 52)
LEATHER_D = (106, 62, 34)
FUR = (132, 88, 56)
FUR_L = (180, 132, 90)
SKIN = (236, 190, 150)
SKIN_D = (196, 140, 104)
CHARCOAL = (58, 54, 54)
CHARCOAL_L = (96, 92, 92)
MOLASSES = (96, 50, 26)
CREAM = (250, 236, 200)
GREEN = (72, 132, 64)


def mul(c, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in c[:3])


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


class Icon:
    def __init__(self, size=48, seed=1):
        self.n = size
        self.img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
        self.rnd = random.Random(seed)

    # -- helpers -----------------------------------------------------------
    def _s(self, v):
        return v * SS

    def _pts(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def _layer(self):
        return Image.new("L", self.img.size, 0)

    def _paint(self, mask, color, shade=True, light=0.18, dark=0.24, angle=-135.0):
        """Fill `mask` with `color`, lit from the top-left across its bbox."""
        bbox = mask.getbbox()
        if bbox is None:
            return
        if not shade:
            fill = Image.new("RGBA", self.img.size, tuple(color[:3]) + (255,))
            self.img.paste(fill, (0, 0), mask)
            return
        x0, y0, x1, y1 = bbox
        w, h = max(1, x1 - x0), max(1, y1 - y0)
        grad = Image.new("RGBA", (w, h))
        gp = grad.load()
        a = math.radians(angle)
        dx, dy = math.cos(a), math.sin(a)
        # t = 1 at the lit corner, 0 at the far corner
        for y in range(0, h, 2):
            for x in range(0, w, 2):
                u = (x / w - 0.5) * dx + (y / h - 0.5) * dy
                t = max(0.0, min(1.0, u + 0.5))
                k = 1.0 - dark + (light + dark) * t
                c = mul(color, k) + (255,)
                gp[x, y] = c
                if x + 1 < w:
                    gp[x + 1, y] = c
                if y + 1 < h:
                    gp[x, y + 1] = c
                    if x + 1 < w:
                        gp[x + 1, y + 1] = c
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        layer.paste(grad, (x0, y0))
        self.img.paste(layer, (0, 0), mask)

    # -- shapes ------------------------------------------------------------
    def poly(self, pts, color, shade=True, **kw):
        m = self._layer()
        ImageDraw.Draw(m).polygon(self._pts(pts), fill=255)
        self._paint(m, color, shade, **kw)

    def rect(self, box, color, shade=True, radius=0, **kw):
        m = self._layer()
        b = [box[0] * SS, box[1] * SS, box[2] * SS - 1, box[3] * SS - 1]
        if radius:
            ImageDraw.Draw(m).rounded_rectangle(b, radius=radius * SS, fill=255)
        else:
            ImageDraw.Draw(m).rectangle(b, fill=255)
        self._paint(m, color, shade, **kw)

    def ellipse(self, box, color, shade=True, **kw):
        m = self._layer()
        ImageDraw.Draw(m).ellipse([box[0] * SS, box[1] * SS, box[2] * SS - 1, box[3] * SS - 1], fill=255)
        self._paint(m, color, shade, **kw)

    def circle(self, cx, cy, r, color, shade=True, **kw):
        self.ellipse((cx - r, cy - r, cx + r, cy + r), color, shade, **kw)

    def line(self, pts, color, width=1.0, shade=False):
        m = self._layer()
        d = ImageDraw.Draw(m)
        w = max(1, int(round(width * SS)))
        d.line(self._pts(pts), fill=255, width=w, joint="curve")
        r = w / 2
        for x, y in self._pts(pts):
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
        self._paint(m, color, shade)

    def arc(self, box, start, end, color, width=1.0):
        m = self._layer()
        ImageDraw.Draw(m).arc([box[0] * SS, box[1] * SS, box[2] * SS, box[3] * SS], start, end, fill=255, width=max(1, int(width * SS)))
        self._paint(m, color, False)

    def pie(self, box, start, end, color, shade=True):
        m = self._layer()
        ImageDraw.Draw(m).pieslice([box[0] * SS, box[1] * SS, box[2] * SS, box[3] * SS], start, end, fill=255)
        self._paint(m, color, shade)

    def dot(self, x, y, color, r=0.5):
        """A single highlight pixel (or small blob)."""
        self.ellipse((x - r, y - r, x + r, y + r), color, shade=False)

    def speckle(self, box, color, count, r=0.5, clip=True):
        """Random texture dots inside box, only over existing paint."""
        alpha = self.img.getchannel("A")
        for _ in range(count):
            x = self.rnd.uniform(box[0], box[2])
            y = self.rnd.uniform(box[1], box[3])
            if clip and alpha.getpixel((min(self.img.width - 1, int(x * SS)), min(self.img.height - 1, int(y * SS)))) < 128:
                continue
            self.dot(x, y, color, r)

    def shadow(self, cx, cy, rx, ry, alpha=70):
        """Soft ground shadow ellipse under an object (drawn first)."""
        m = self._layer()
        ImageDraw.Draw(m).ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=alpha)
        layer = Image.new("RGBA", self.img.size, (30, 20, 14, 255))
        base = self.img.copy()
        self.img = Image.composite(layer, base, m)
        # keep underlying alpha where it existed
        a = ImageChops.lighter(base.getchannel("A"), m)
        self.img.putalpha(a)

    # -- output ------------------------------------------------------------
    def render(self, colors=40, outline=INK):
        n = self.n
        big = self.img
        small = big.resize((n, n), Image.BOX)
        # Hard alpha: pixel art has no partial transparency (except shadows).
        px = small.load()
        for y in range(n):
            for x in range(n):
                r, g, b, a = px[x, y]
                if a < 96:
                    px[x, y] = (0, 0, 0, 0)
                elif a < 200 and (r + g + b) < 150:
                    px[x, y] = (r, g, b, a)  # soft shadow stays translucent
                else:
                    px[x, y] = (r, g, b, 255)
        # Snap to a small palette so gradients band like hand-placed pixels.
        rgb = small.convert("RGB")
        q = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
        out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        out.paste(q, (0, 0), small.getchannel("A"))
        out.putalpha(small.getchannel("A"))
        if outline is not None:
            out = add_outline(out, outline)
        return out

    def save(self, name, colors=40, outline=INK, folder=None):
        out = self.render(colors, outline)
        path = os.path.join(folder or OUT, name + ".png")
        out.save(path)
        return out


def add_outline(img, ink):
    """One-pixel outline around opaque pixels, tinted toward what it encloses
    (Graveyard Keeper style), plus a darkened inner edge along the bottom and
    right so shapes feel solid."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 255:
                continue
            best = None
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and src[xx, yy][3] == 255:
                    best = src[xx, yy]
                    break
            if best is not None:
                c = mix(ink, best[:3], 0.22)
                dst[x, y] = c + (255,)
    return out


def sheet(names, path, scale=2, cols=8, bg=(236, 220, 180)):
    """Contact sheet for review."""
    ims = [Image.open(os.path.join(OUT, n + ".png")).convert("RGBA") for n in names]
    n = max(i.width for i in ims)
    rows = (len(ims) + cols - 1) // cols
    pad = 6
    s = Image.new("RGBA", (cols * (n + pad) * scale, rows * (n + pad) * scale), bg + (255,))
    for i, im in enumerate(ims):
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        s.alpha_composite(big, ((i % cols) * (n + pad) * scale, (i // cols) * (n + pad) * scale))
    s.save(path)
