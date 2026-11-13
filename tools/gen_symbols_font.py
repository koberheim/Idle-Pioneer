"""Builds assets/fonts/IdlePioneerSymbols.ttf: the handful of symbols the UI
uses that Libre Baskerville and Almendra don't contain.

  python tools/gen_symbols_font.py

Without it each phone substitutes a symbol font of its own (Windows drew the
heavy check mark as a purple emoji), so marks, stars and arrows would look
different on every device, or show as empty boxes. scripts/ui/ui.gd adds this
font as the fallback of both game fonts.

The shapes are plain geometry drawn here, so the font is the project's own
and needs no license notice. Needs fontTools (pip install fonttools).
"""
import math
import os

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fonts", "IdlePioneerSymbols.ttf")
UPM = 1000
ASCENT, DESCENT = 800, -200


def area(poly):
    return sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1])) / 2


def clockwise(poly):
    """TrueType fills clockwise contours; keep every contour the same way round."""
    return poly if area(poly) < 0 else poly[::-1]


def disc(cx, cy, r, n=20):
    return [(cx + r * math.cos(2 * math.pi * k / n), cy + r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def stroke(points, width, closed=False):
    """A polyline with round caps and joins, as overlapping contours."""
    polys = []
    h = width / 2
    pts = points + points[:1] if closed else points
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        d = math.hypot(x1 - x0, y1 - y0)
        if d == 0:
            continue
        nx, ny = -(y1 - y0) / d * h, (x1 - x0) / d * h
        polys.append([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)])
    for x, y in points:
        polys.append(disc(x, y, h))
    return polys


def star(cx, cy, r_out, r_in):
    pts = []
    for k in range(10):
        r = r_out if k % 2 == 0 else r_in
        a = math.pi / 2 + k * math.pi / 5
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return [pts]


def lemniscate(cx, cy, a, n=48):
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        s = 1 + math.sin(t) ** 2
        pts.append((cx + a * math.cos(t) / s, cy + a * 1.25 * math.sin(t) * math.cos(t) / s))
    return pts


CHECK = [(130, 330), (350, 110), (800, 640)]
CROSS_A = [(170, 110), (690, 630)]
CROSS_B = [(170, 630), (690, 110)]

# codepoint: (glyph name, advance width, contours)
GLYPHS = {
    0x2713: ("checkmark", 930, stroke(CHECK, 100)),
    0x2714: ("heavycheckmark", 930, stroke(CHECK, 150)),
    0x2715: ("multiplicationx", 860, stroke(CROSS_A, 90) + stroke(CROSS_B, 90)),
    0x2718: ("heavyballotx", 860, stroke(CROSS_A, 140) + stroke(CROSS_B, 140)),
    0x2192: ("arrowright", 1000, stroke([(110, 340), (860, 340)], 76)
             + stroke([(640, 540), (870, 340), (640, 140)], 76)),
    0x2605: ("blackstar", 900, star(450, 345, 400, 158)),
    0x25B2: ("triangleup", 860, [[(110, 110), (430, 640), (750, 110)]]),
    0x25BC: ("triangledown", 860, [[(110, 600), (750, 600), (430, 70)]]),
    0x221E: ("infinity", 1040, stroke(lemniscate(520, 330, 400), 84, closed=True)),
}


def glyph(contours):
    pen = TTGlyphPen(None)
    for poly in contours:
        poly = clockwise([(round(x), round(y)) for x, y in poly])
        pen.moveTo(poly[0])
        for p in poly[1:]:
            pen.lineTo(p)
        pen.closePath()
    g = pen.glyph()
    if len(contours) > 1:
        g.flags[0] |= 0x40  # OVERLAP_SIMPLE: the contours overlap on purpose
    return g


def main():
    names = [".notdef"] + [n for n, _, _ in GLYPHS.values()]
    glyphs = {".notdef": TTGlyphPen(None).glyph()}
    metrics = {".notdef": (500, 0)}
    for name, adv, contours in GLYPHS.values():
        glyphs[name] = glyph(contours)
        metrics[name] = (adv, 0)
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(names)
    fb.setupCharacterMap({cp: n for cp, (n, _, _) in GLYPHS.items()})
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics({n: (adv, glyphs[n].xMin if glyphs[n].numberOfContours else 0)
                               for n, (adv, _) in metrics.items()})
    fb.setupHorizontalHeader(ascent=ASCENT, descent=DESCENT)
    fb.setupNameTable({"familyName": "Idle Pioneer Symbols", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=ASCENT, sTypoDescender=DESCENT, usWinAscent=ASCENT, usWinDescent=-DESCENT)
    fb.setupPost()
    fb.save(OUT)
    print("wrote %s (%d symbols, %d bytes)" % (os.path.relpath(OUT, ROOT), len(GLYPHS), os.path.getsize(OUT)))


if __name__ == "__main__":
    main()
