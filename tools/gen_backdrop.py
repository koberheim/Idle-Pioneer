"""Draws the portrait backdrop behind the nation select / Liberty Reforms
screen (assets/sprites/backdrop.png) from scratch.

"The Fleet Sails at Dusk": the harbour banner's golden-hour palette opened up
into a phone-shaped scene. A tall dusk sky (deep violet at the top, where the
title sits) falls to a low sun over a hazy European waterfront; a large
three-master runs out under topsails in the middle distance with a consort
and a far sail beyond; the lower half is open water with a broken sun column,
reflections and a couple of rowboats heading out.

It reuses the drawing helpers of tools/gen_banner.py (sky ramp, town, Ship,
water, ripples, reflections) on a 360x640 canvas - one art pixel = 2 screen
pixels, the banner's density - then scales x2 with NEAREST to 720x1280. The
screen covers it (keep aspect, centred), so the important parts stay in the
middle columns. No source image is used.

Run: python tools/gen_backdrop.py [preview_path]
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_banner as gb  # noqa: E402

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "sprites", "backdrop.png")
W, H = 360, 640
SCALE = 2
HORIZON = 300
SUN = (246, 272)

# gen_banner draws through its module globals; point them at this canvas.
gb.W, gb.H, gb.HORIZON, gb.SUN, gb.SUN_R = W, H, HORIZON, SUN, 15
mix, mul, clamp = gb.mix, gb.mul, gb.clamp


def draw_sky(img):
    """The banner's banded dusk ramp, stretched over the taller sky, with a
    wider sun glow so the light still reaches the middle of the screen."""
    px = img.load()
    for y in range(HORIZON + 1):
        for x in range(W):
            t = (y / HORIZON) ** 1.15 * 0.84
            d = math.hypot((x - SUN[0]) * 0.6, (y - SUN[1]) * 1.1)
            t += 0.40 * clamp(1 - d / 150) ** 1.5
            px[x, y] = gb.ramp(gb.SKY, t, x, y) + (255,)


def draw_clouds(img):
    """Long flat streaks: dusky violet up high, lit orange undersides low."""
    streaks = [  # cx, cy, half width, thickness
        (70, 34, 70, 3), (250, 22, 90, 3), (190, 60, 40, 2), (40, 92, 44, 2),
        (300, 104, 56, 3), (140, 128, 60, 2), (40, 170, 40, 2), (230, 160, 34, 1),
        (330, 196, 40, 2), (110, 206, 46, 2), (190, 232, 30, 1), (290, 244, 50, 1),
        (60, 252, 34, 1), (170, 262, 22, 1),
    ]
    rnd = random.Random(21)
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
    for y in range(HORIZON):
        for x in range(W):
            if not m[x, y]:
                continue
            d = math.hypot(x - SUN[0], (y - SUN[1]) * 1.4)
            near = clamp(1 - d / 230)
            body = mix((84, 46, 82), (214, 118, 86), clamp((y / HORIZON) ** 1.3 + near * 0.5))
            below = y + 1 < H and not m[x, y + 1]
            above = y > 0 and not m[x, y - 1]
            if below:
                c = mix(mix((150, 76, 98), (236, 140, 90), clamp(y / HORIZON + 0.2)), (255, 222, 150), near)
            elif above:
                c = mul(body, 0.92)
            else:
                c = body
            px[x, y] = c + (255,)


def draw_stars(img):
    """A few early stars in the violet top of the sky."""
    rnd = random.Random(4)
    px = img.load()
    for _ in range(46):
        x = rnd.randint(2, W - 3)
        y = rnd.randint(2, 120)
        if px[x, y][0] > 120:
            continue
        k = clamp(1 - y / 130)
        px[x, y] = mix(px[x, y][:3], (255, 236, 200), 0.35 + 0.5 * k * rnd.random()) + (255,)


def draw_gulls(img):
    d = ImageDraw.Draw(img)
    for x, y, up in ((150, 196, 1), (160, 202, 0), (141, 206, 0), (300, 168, 1), (308, 175, 0)):
        c = (70, 40, 56)
        d.point((x, y), fill=c)
        d.point((x - 1, y - 1), fill=c)
        d.point((x + 1, y - 1), fill=c)
        d.point((x - 2, y - 1 - up), fill=c)
        d.point((x + 2, y - 1 - up), fill=c)


def draw_far_shore():
    """A low headland with a lighthouse on the right of the horizon."""
    lay = gb.layer()
    d = ImageDraw.Draw(lay)
    c = (150, 84, 92)
    pts = [(286, HORIZON + 1)] + [(x, HORIZON - 4 - 6 * math.sin((x - 286) / 74 * math.pi) ** 0.7) for x in range(288, W + 1, 2)] + [(W, HORIZON + 1)]
    d.polygon(pts, fill=c)
    d.rectangle([336, HORIZON - 22, 339, HORIZON - 8], fill=(132, 70, 82))
    d.rectangle([335, HORIZON - 25, 340, HORIZON - 22], fill=(132, 70, 82))
    d.point((337, HORIZON - 24), fill=(255, 226, 150))
    d.point((338, HORIZON - 24), fill=(255, 226, 150))
    return lay


def glow_ring(img, lx, ly, r=5):
    px = img.load()
    for y in range(ly - r, ly + r + 1):
        for x in range(lx - r, lx + r + 1):
            if 0 <= x < W and 0 <= y < H and r - 2 < math.hypot(x - lx, y - ly) <= r and (x + y) % 2 == 0:
                px[x, y] = mix(px[x, y][:3], (255, 214, 130), 0.35) + (255,)


def vignette(img):
    """Darken the edges and the very top a little (ordered dither, in steps),
    so the title and the card edges sit on calmer ground."""
    px = img.load()
    for y in range(H):
        for x in range(W):
            ex = abs(x - W / 2) / (W / 2)
            t = 0.22 * ex ** 3 + 0.26 * clamp(1 - y / 150) ** 2 + 0.18 * clamp((y - 560) / 80) ** 1.5
            q = math.floor(t * 10 + (gb.BAYER[y % 4][x % 4] + 0.5) / 16) / 10
            if q > 0:
                px[x, y] = mix(px[x, y][:3], (20, 12, 26), q) + (255,)


def build():
    rnd = random.Random(7)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    draw_sky(img)
    draw_stars(img)
    draw_clouds(img)
    gb.draw_sun(img)
    draw_gulls(img)

    far, near = gb.draw_town()
    gb.haze(far, (230, 140, 100), 0.3)
    gb.haze(near, (200, 110, 100), 0.12)
    near = gb.rim(near, amt=0.3, top=True)
    shore = gb.haze(draw_far_shore(), (220, 130, 104), 0.2)

    dist = gb.Ship(214, HORIZON + 4, 0.17, flip=True)
    dist.draw(big=False)
    dist_l = gb.haze(dist.finish(outlined=False, rim_amt=0), (150, 78, 80), 0.7)

    mid = gb.Ship(318, 352, 0.62, flip=True, jib=False)
    mid.draw(big=False)
    mid_l = gb.haze(mid.finish(outlined=False, rim_amt=0.5), (190, 104, 92), 0.25)

    big = gb.Ship(66, 446, 1.55)
    big.draw(big=True)
    big_l = big.finish(outlined=True)

    gb.draw_water(img)
    gb.ripples(img, rnd)
    gb.reflect(img, near, HORIZON, 0.4)
    gb.reflect(img, shore, HORIZON, 0.35)
    gb.reflect(img, dist_l, HORIZON + 4, 0.4)
    gb.reflect(img, mid_l, 352, 0.45)
    gb.reflect(img, big_l, 446, 0.55, gap=5)

    gb.paste(img, far)
    gb.paste(img, near)
    gb.paste(img, shore)
    gb.paste(img, dist_l)
    gb.paste(img, mid_l)
    gb.paste(img, big_l)

    boats = gb.layer()
    bd = ImageDraw.Draw(boats)
    gb.rowboat(bd, 40, 548, 30, [((64, 72, 110), "tricorn"), ((150, 60, 50), "bonnet"),
                                ((96, 110, 70), "hat"), ((180, 150, 110), "bonnet")], rnd)
    gb.rowboat(bd, 262, 520, 24, [((80, 56, 44), "cap"), ((56, 70, 108), "tricorn"), ((160, 64, 54), "bonnet")], rnd)
    gb.rowboat(bd, 300, 596, 26, [((70, 60, 90), "cap"), ((120, 90, 60), "hat"), ((200, 190, 170), "bonnet")], rnd)
    boats = gb.outline(gb.rim(boats, amt=0.35))
    gb.reflect(img, boats, 552, 0.35, gap=2)
    gb.paste(img, boats)

    for lx, ly in ((73 * 1, HORIZON - 4), (337, HORIZON - 24), (66 + 130 * 1.55, 446 - 37 * 1.55)):
        glow_ring(img, int(lx), int(ly))
    vignette(img)
    return img.convert("RGB")


def main():
    img = build()
    big = img.resize((W * SCALE, H * SCALE), Image.NEAREST)
    big.save(OUT)
    print("backdrop", big.size, "->", OUT)
    if len(sys.argv) > 1:
        img.resize((W * 2, H * 2), Image.NEAREST).save(sys.argv[1])


if __name__ == "__main__":
    main()
