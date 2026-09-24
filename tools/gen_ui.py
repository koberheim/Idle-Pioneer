"""Generates the interface frames in assets/sprites/ui/: walnut planks, aged
parchment, and raised painted buttons with a lip underneath.

Frames are drawn at native size (one texture pixel per 720p screen pixel) so
they share the density of the 48 px icons. Panel textures are seamless so
their centres can tile. Margins must match UI.FRAME_MARGINS in ui.gd.

Run: python tools/gen_ui.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "ui")
os.makedirs(OUT, exist_ok=True)

INK = (44, 28, 20)


def clamp(v):
    return max(0, min(255, int(round(v))))


def mul(c, k):
    return tuple(clamp(v * k) for v in c[:3])


def mix(a, b, t):
    return tuple(clamp(a[i] + (b[i] - a[i]) * t) for i in range(3))


class Noise:
    """Tileable value noise on a period x period lattice."""

    def __init__(self, seed, period):
        r = random.Random(seed)
        self.p = period
        self.g = [[r.random() for _ in range(period)] for _ in range(period)]

    def at(self, x, y):
        p = self.p
        x0, y0 = int(math.floor(x)) % p, int(math.floor(y)) % p
        x1, y1 = (x0 + 1) % p, (y0 + 1) % p
        fx, fy = x - math.floor(x), y - math.floor(y)
        sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = self.g[y0][x0] + (self.g[y0][x1] - self.g[y0][x0]) * sx
        b = self.g[y1][x0] + (self.g[y1][x1] - self.g[y1][x0]) * sx
        return a + (b - a) * sy


def fbm(noises, x, y, size):
    """Seamless fractal noise over a size x size tile."""
    v, amp, tot = 0.0, 1.0, 0.0
    for n in noises:
        v += n.at(x / size * n.p, y / size * n.p) * amp
        tot += amp
        amp *= 0.5
    return v / tot


# ---------------------------------------------------------------- materials
def parchment(size, seed, base=(236, 220, 180), dark=(206, 180, 132), fibres=True):
    img = Image.new("RGBA", (size, size))
    px = img.load()
    ns = [Noise(seed + i, p) for i, p in enumerate((4, 8, 16, 32))]
    r = random.Random(seed)
    for y in range(size):
        for x in range(size):
            v = fbm(ns, x, y, size)
            c = mix(base, dark, max(0.0, min(1.0, (v - 0.35) * 1.4)))
            if r.random() < 0.06:
                c = mul(c, 0.97 if r.random() < 0.5 else 1.03)
            px[x, y] = c + (255,)
    if fibres:
        d = ImageDraw.Draw(img)
        for _ in range(size // 6):
            x, y = r.uniform(0, size), r.uniform(0, size)
            a = r.uniform(0, math.pi)
            ln = r.uniform(3, 8)
            col = mul(dark, 1.02) + (255,)
            for k in (-size, 0, size):
                for j in (-size, 0, size):
                    d.line([(x + k, y + j), (x + k + math.cos(a) * ln, y + j + math.sin(a) * ln)], fill=col, width=1)
    return img


def wood(size, seed, base=(92, 60, 38), plank=32, seams=True):
    """Horizontal walnut planks with running grain, seamless."""
    img = Image.new("RGBA", (size, size))
    px = img.load()
    r = random.Random(seed)
    ns = [Noise(seed + i, p) for i, p in enumerate((2, 4, 8))]
    rows = size // plank
    tints = [r.uniform(0.88, 1.08) for _ in range(rows)]
    offs = [r.uniform(0, 100) for _ in range(rows)]
    for y in range(size):
        row = y // plank
        yy = y % plank
        for x in range(size):
            # grain: stretched sine bands perturbed by noise
            w = fbm(ns, x, y * 6, size)
            g = math.sin((yy + offs[row]) * 0.75 + w * 14.0)
            k = tints[row] * (0.88 + 0.16 * g)
            if g > 0.9:
                k *= 0.78
            elif g < -0.95:
                k *= 1.1
            c = mul(base, k)
            if seams:
                if yy == 0:
                    c = mul(base, 1.28 * tints[row])
                elif yy == plank - 1:
                    c = mul(base, 0.45)
                elif yy == plank - 2:
                    c = mul(base, 0.72 * tints[row])
            px[x, y] = c + (255,)
    if seams:
        d = ImageDraw.Draw(img)
        for row in range(rows):
            # one butt joint per plank, staggered, plus two nails
            jx = int((row * 37 + 30) % (size - 40)) + 20
            y0, y1 = row * plank + 1, row * plank + plank - 2
            d.line([(jx, y0), (jx, y1)], fill=mul(base, 0.42) + (255,))
            d.line([(jx + 1, y0), (jx + 1, y1)], fill=mul(base, 1.2) + (255,))
            for nx in (jx - 4, jx + 5):
                ny = row * plank + plank // 2
                d.point((nx % size, ny - 1), fill=(150, 140, 120, 255))
                d.point((nx % size, ny), fill=(70, 62, 54, 255))
    return img


# ---------------------------------------------------------------- frames
def rounded_mask(size, radius, inset=0):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([inset, inset, size[0] - 1 - inset, size[1] - 1 - inset], radius=radius, fill=255)
    return m


def burn_edges(img, depth, color, strength=0.55):
    """Darken toward the border, like handled parchment."""
    w, h = img.size
    px = img.load()
    for y in range(h):
        for x in range(w):
            e = min(x, y, w - 1 - x, h - 1 - y)
            if e < depth:
                t = (1 - e / depth) ** 2 * strength
                c = px[x, y]
                px[x, y] = mix(c, color, t) + (c[3],)


def save(img, name):
    img.save(os.path.join(OUT, name + ".png"))


def panel_parchment(name, size=128, seed=3, base=(236, 220, 180), dark=(208, 182, 134), border=INK):
    img = parchment(size, seed, base, dark)
    burn_edges(img, 12, (150, 104, 56), 0.5)
    d = ImageDraw.Draw(img)
    # outer ink rule, then a thin brown inner rule
    d.rectangle([0, 0, size - 1, size - 1], outline=border + (255,), width=3)
    d.rectangle([3, 3, size - 4, size - 4], outline=(170, 128, 60, 255), width=1)
    d.rectangle([6, 6, size - 7, size - 7], outline=mul(dark, 0.78) + (255,), width=1)
    # clip the corners
    for cx, cy in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
        img.putpixel((cx, cy), (0, 0, 0, 0))
    save(img, name)


def card(name, size=96, seed=5, base=(246, 236, 208), dark=(222, 204, 164)):
    img = parchment(size, seed, base, dark)
    burn_edges(img, 8, (176, 136, 84), 0.35)
    mask = rounded_mask((size, size), 5)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=5, outline=(96, 70, 44, 255), width=2)
    d.line([(4, size - 3), (size - 5, size - 3)], fill=mul(dark, 0.8) + (255,))
    img.putalpha(mask)
    save(img, name)


def panel_wood(name, size=128, seed=11, base=(88, 58, 38)):
    img = wood(size, seed, base)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, size - 1, size - 1], outline=(20, 14, 10, 255), width=2)
    d.line([(2, 2), (size - 3, 2)], fill=mul(base, 1.5) + (255,))
    d.line([(2, 2), (2, size - 3)], fill=mul(base, 1.35) + (255,))
    d.line([(2, size - 3), (size - 3, size - 3)], fill=mul(base, 0.5) + (255,))
    d.line([(size - 3, 2), (size - 3, size - 3)], fill=mul(base, 0.55) + (255,))
    for cx, cy in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
        img.putpixel((cx, cy), (0, 0, 0, 0))
    save(img, name)


def panel_navy(name, size=128, seed=17):
    img = parchment(size, seed, (34, 50, 88), (24, 34, 64), fibres=False)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, size - 1, size - 1], outline=(12, 16, 30, 255), width=2)
    d.rectangle([3, 3, size - 4, size - 4], outline=(190, 146, 66, 255), width=1)
    save(img, name)


BTN_W, BTN_H = 64, 64
LIP = 5  # height of the raised button's side


def button(name, color, pressed=False, disabled=False, seed=21, text_dark=False):
    """A raised painted-wood button. Unpressed: face on top of a darker lip.
    Pressed: the face drops onto the lip."""
    w, h = BTN_W, BTN_H
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    r = random.Random(seed)
    ns = [Noise(seed + i, p) for i, p in enumerate((2, 4, 8))]
    drop = LIP - 1 if pressed else 0
    face_top, face_bot = 1 + drop, h - 2 - (1 if pressed else LIP)
    outline = mul(color, 0.28)
    lip = mul(color, 0.55)
    px = img.load()
    shape = rounded_mask((w, h), 6)
    face = Image.new("L", (w, h), 0)
    ImageDraw.Draw(face).rounded_rectangle([1, face_top, w - 2, face_bot], radius=5, fill=255)
    fp = face.load()
    sp = shape.load()
    for y in range(h):
        for x in range(w):
            if sp[x, y] == 0 or y < drop:
                continue
            if fp[x, y]:
                t = (y - face_top) / max(1, face_bot - face_top)
                k = 1.12 - 0.22 * t
                # painted-board streaks
                s = fbm(ns, x * 0.5, y * 5, w)
                k *= 0.95 + 0.09 * s
                if r.random() < 0.05:
                    k *= 0.96
                c = mul(color, k)
            else:
                c = lip if y > face_bot else outline
            px[x, y] = c + (255,)
    d = ImageDraw.Draw(img)
    # outline around everything, face highlight on top and left
    d.rounded_rectangle([0, drop, w - 1, h - 1], radius=6, outline=outline + (255,), width=1)
    hi = mul(color, 1.45)
    d.line([(4, face_top + 1), (w - 5, face_top + 1)], fill=hi + (255,))
    d.line([(2, face_top + 3), (2, face_bot - 3)], fill=mul(color, 1.25) + (255,))
    d.line([(4, face_bot), (w - 5, face_bot)], fill=mul(color, 0.7) + (255,))
    if not pressed:
        # the lip catches a little light at its lower edge
        d.line([(4, h - 2), (w - 5, h - 2)], fill=mul(color, 0.42) + (255,))
    # brass tacks in the corners
    if not disabled:
        for cx in (5, w - 6):
            for cy in (face_top + 4, face_bot - 4):
                d.point((cx, cy), fill=(236, 204, 120, 255))
                d.point((cx + 1, cy + 1), fill=(120, 84, 30, 255))
    save(img, name)


def bar(name, color, size=32):
    img = Image.new("RGBA", (size, size), mul(color, 1.0) + (255,))
    d = ImageDraw.Draw(img)
    for y in range(size):
        d.line([(0, y), (size, y)], fill=mul(color, 1.2 - 0.35 * y / size) + (255,))
    d.rectangle([0, 0, size - 1, size - 1], outline=(20, 14, 10, 255), width=2)
    save(img, name)


def tab(name, active):
    size = 96
    if active:
        img = parchment(size, 31, (238, 222, 182), (210, 184, 136))
        burn_edges(img, 10, (150, 104, 56), 0.45)
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, size - 1, size - 1], outline=(20, 14, 10, 255), width=2)
        d.rectangle([2, 2, size - 3, size - 3], outline=(212, 168, 70, 255), width=2)
    else:
        img = wood(size, 33, (74, 50, 34), plank=48)
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, size - 1, size - 1], outline=(20, 14, 10, 255), width=2)
        d.line([(2, 2), (size - 3, 2)], fill=(128, 92, 62, 255))
        d.line([(2, size - 3), (size - 3, size - 3)], fill=(40, 26, 18, 255))
    save(img, name)


if __name__ == "__main__":
    panel_parchment("panel")
    panel_wood("panel_dark")
    panel_navy("panel_navy")
    card("card")
    BLUE = (54, 84, 142)
    GREEN = (62, 122, 56)
    GOLD = (212, 162, 52)
    GREY = (150, 140, 124)
    button("button", BLUE)
    button("button_hover", mul(BLUE, 1.12))
    button("button_pressed", BLUE, pressed=True)
    button("button_disabled", GREY, disabled=True)
    button("button_buy", GREEN)
    button("button_buy_pressed", GREEN, pressed=True)
    button("button_gold", GOLD)
    button("button_gold_pressed", GOLD, pressed=True)
    tab("tab", False)
    tab("tab_active", True)
    bar("bar_bg", (46, 36, 28))
    bar("bar_fill", (224, 176, 60))
    bar("bar_fill_blue", (90, 140, 210))
    bar("bar_fill_green", (96, 168, 72))
    print("ui frames written to", OUT)
