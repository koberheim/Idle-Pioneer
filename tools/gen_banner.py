"""Builds the Europe page banner (assets/sprites/harbor.png) from the harbor
painting in assets/art/backgrounds/harbor.png.

The banner is shown about 680x250 on the 720-wide screen, so it is made at
that size (one pixel per screen pixel, the density of the 48 px icons), then
snapped to a limited palette so it reads as pixel art rather than a photo.

Run: python tools/gen_banner.py
"""
import os

from PIL import Image, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "art", "backgrounds", "harbor.png")
OUT = os.path.join(ROOT, "assets", "sprites", "harbor.png")
W, H = 680, 250

src = Image.open(SRC).convert("RGB")
# The band with the ships, the setting sun and the quay.
top = 250
crop = src.crop((0, top, src.width, top + int(src.width * H / W)))
img = crop.resize((W, H), Image.LANCZOS)
img = img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
img = ImageEnhance.Contrast(img).enhance(1.06)
img = img.quantize(colors=72, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
img.save(OUT)
print("banner", img.size, "->", OUT)
