"""Rebuilds the store marketing package in store/ from the real game.

  python tools/store/build_store.py            # everything (about 5 minutes)
  python tools/store/build_store.py --skip-render   # recompose from existing raw shots
  python tools/store/build_store.py --only 01_map,05_congress
  python tools/store/build_store.py --ipad     # also iPad 13" (the iOS preset is iPhone-only today)

For every shot and every target size it:
  1. renders the game itself at the exact pixel size (tools/shot.gd, scenario
     store_*, a scripted late-game expedition) -> store/raw/<target>/
  2. renders it again at the size of the framed inset, and composes the
     marketing version: a parchment caption banner on the game's dark wood,
     the screenshot in a frame below                     -> store/<target>/
Then it copies the 512 px icon and the 1024x500 feature graphic and checks
every output's size and mode.

Never touches the player's save: shot.gd writes only user://store_shot_*.json
and deletes it on exit. Needs Pillow and the Godot console exe below.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = os.environ.get(
    "GODOT",
    "E:/Godot/godot_mono/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe")
OUT = os.path.join(ROOT, "store")
FONT_TITLE = os.path.join(ROOT, "assets", "fonts", "Almendra-Regular.ttf")
FONT_BODY = os.path.join(ROOT, "assets", "fonts", "LibreBaskerville-Regular.ttf")
UI_DIR = os.path.join(ROOT, "assets", "sprites", "ui")

INK = (44, 30, 20)
INK_SOFT = (107, 84, 64)
GOLD = (245, 200, 80)
FRAME_DARK = (24, 15, 10)

TARGETS = {
    # name: (width, height, store slot)
    "google_play_phone": (1080, 1920, "Google Play phone screenshots (9:16)"),
    "iphone_6.9": (1290, 2796, "App Store iPhone 6.9\" / 6.7\" display"),
    "iphone_6.5": (1242, 2688, "App Store iPhone 6.5\" display"),
}
IPAD = {"ipad_13": (2064, 2752, "App Store iPad 13\" display")}

# id, scenario, extra args, headline, subline
SHOTS = [
    ("01_map", "store_map", [], "Found Colonies in the New World",
     "Settle a painted coastline and link every colony to your capital by road or sea."),
    ("02_colony", "store_sheet", ["colony=c1"], "Grow Every Settlement",
     "Upgrade production, wagons and ships. Post governors, grant charters."),
    ("03_workshops", "store_workshops", [], "Craft Finer Wares",
     "26 workshops turn timber, iron and cane into lumber, tools, rum and muskets."),
    ("04_europe", "store_europe", [], "Trade with the Old World",
     "Sell to the markets of Europe as demand rises and falls, or keep goods to craft."),
    ("05_congress", "store_congress", [], "Convene a Continental Congress",
     "Invite Franklin, Washington, Abigail Adams and dozens more, each with a bonus."),
    ("06_declaration", "store_declare", [], "Declare Independence!",
     "Start a new expedition and spend your Liberty on permanent Reforms."),
    ("07_society", "store_research", [], "Join the Philosophical Society",
     "102 studies across six branches, each rooted in real colonial history."),
    ("08_ledger", "store_ledger", [], "Collect Relics of History",
     "30 keepsakes, from Franklin's kite key to the Old North Church lantern."),
]


# --- rendering ------------------------------------------------------------------

def render(scenario, args, size, out_png):
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    if os.path.exists(out_png):
        os.remove(out_png)
    w, h = size
    cmd = [GODOT, "--path", ROOT, "--resolution", "720x1000", "res://tools/shot.tscn", "--",
           "scenario=" + scenario, "save=store_shot_%d" % os.getpid(),
           "winsize=%dx%d" % (w, h), "clipcheck=1", "out=" + out_png.replace("\\", "/")] + args
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    log = p.stdout + p.stderr
    issues = [ln for ln in log.splitlines()
              if ln.startswith(("CLIPPED", "OVERFLOW", "OFFSCREEN", "SCRIPT ERROR", "ERROR"))]
    if not os.path.exists(out_png):
        print(log)
        raise SystemExit("render failed: %s %s" % (scenario, size))
    im = Image.open(out_png)
    if im.size != (w, h):
        raise SystemExit("render %s came out %s, wanted %s" % (out_png, im.size, size))
    return issues


# --- composition ----------------------------------------------------------------

def nine_slice(src, w, h, margin, scale):
    """Scale a 9-slice frame (pixel art, nearest) to w x h; corners keep `scale`."""
    s = src.convert("RGBA")
    sw, sh = s.size
    m = margin
    out = Image.new("RGBA", (w, h))
    M = m * scale
    xs = [(0, m, 0, M), (m, sw - m, M, w - M), (sw - m, sw, w - M, w)]
    ys = [(0, m, 0, M), (m, sh - m, M, h - M), (sh - m, sh, h - M, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 <= dx0 or dy1 <= dy0:
                continue
            piece = s.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST)
            out.paste(piece, (dx0, dy0))
    return out


def wood(w, h, scale):
    tile = Image.open(os.path.join(UI_DIR, "panel_dark.png")).convert("RGB")
    tile = tile.crop((8, 8, tile.width - 8, tile.height - 8))
    tile = tile.resize((tile.width * scale, tile.height * scale), Image.NEAREST)
    out = Image.new("RGB", (w, h))
    for y in range(0, h, tile.height):
        for x in range(0, w, tile.width):
            out.paste(tile, (x, y))
    # a soft vignette so the banner and shot read first
    small = Image.new("L", (64, 64), 120)
    ImageDraw.Draw(small).rectangle((10, 10, 53, 53), fill=0)
    shade = small.filter(ImageFilter.GaussianBlur(7)).resize((w, h), Image.BICUBIC)
    out.paste((10, 6, 4), (0, 0, w, h), shade)
    return out


def wrap(draw, text, font, width):
    words, lines, cur = text.split(), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if draw.textlength(t, font=font) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = wd
    lines.append(cur)
    return lines


def fit_font(draw, path, text, size, width, min_size):
    while size > min_size:
        f = ImageFont.truetype(path, size)
        if draw.textlength(text, font=f) <= width:
            return f
        size -= 2
    return ImageFont.truetype(path, min_size)


def layout(W, H):
    """Inset (shot) size and placement for a W x H canvas; same aspect as the canvas."""
    band = round(H * 0.17)
    bottom = round(W * 0.055)
    ih = H - band - bottom
    iw = round(ih * W / H)
    return band, iw, ih, (W - iw) // 2, band


def compose(W, H, inset_png, headline, subline, out_png):
    band, iw, ih, ix, iy = layout(W, H)
    scale = max(2, round(W / 360))
    canvas = wood(W, H, scale)
    # caption banner: the game's parchment panel
    bx0, bx1 = round(W * 0.045), W - round(W * 0.045)
    by0, by1 = round(band * 0.11), band - round(band * 0.09)
    banner = nine_slice(Image.open(os.path.join(UI_DIR, "panel.png")), bx1 - bx0, by1 - by0, 14, scale)
    canvas.paste(banner, (bx0, by0), banner)
    d = ImageDraw.Draw(canvas)
    inner = (bx1 - bx0) - 2 * round(W * 0.05)
    hf = fit_font(d, FONT_TITLE, headline, round(W * 0.078), inner, round(W * 0.05))
    sf = ImageFont.truetype(FONT_BODY, round(W * 0.03))
    sub_lines = wrap(d, subline, sf, inner)
    hh = hf.getbbox("Ag")[3]
    lh = round(sf.size * 1.4)
    total = hh + round(W * 0.012) + lh * len(sub_lines)
    y = by0 + ((by1 - by0) - total) // 2 - round(W * 0.004)
    d.text((W // 2, y), headline, font=hf, fill=INK, anchor="ma")
    y += hh + round(W * 0.012)
    for ln in sub_lines:
        d.text((W // 2, y), ln, font=sf, fill=INK_SOFT, anchor="ma")
        y += lh
    # the screenshot in a dark frame with a gold rule
    b = max(4, round(W * 0.006))
    d.rectangle((ix - 3 * b, iy - 3 * b, ix + iw + 3 * b - 1, iy + ih + 3 * b - 1), fill=FRAME_DARK)
    d.rectangle((ix - 2 * b, iy - 2 * b, ix + iw + 2 * b - 1, iy + ih + 2 * b - 1), outline=GOLD, width=max(2, b // 2))
    shot = Image.open(inset_png).convert("RGB")
    if shot.size != (iw, ih):
        raise SystemExit("inset %s is %s, wanted %s" % (inset_png, shot.size, (iw, ih)))
    canvas.paste(shot, (ix, iy))
    canvas.convert("RGB").save(out_png, optimize=True)


# --- checks ---------------------------------------------------------------------

def verify(expect):
    bad = 0
    for path, (w, h) in expect.items():
        im = Image.open(path)
        ok = im.size == (w, h) and im.mode == "RGB"
        bad += not ok
        print("%s  %-60s %dx%d %s  %.1f MB" % ("ok " if ok else "BAD", os.path.relpath(path, ROOT),
              im.size[0], im.size[1], im.mode, os.path.getsize(path) / 1e6))
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-render", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--ipad", action="store_true")
    a = ap.parse_args()
    targets = dict(TARGETS)
    if a.ipad:
        targets.update(IPAD)
    only = set(filter(None, a.only.split(",")))
    shots = [s for s in SHOTS if not only or s[0] in only]
    os.makedirs(OUT, exist_ok=True)
    # Keep Godot from importing the package as game assets (before any render).
    open(os.path.join(OUT, ".gdignore"), "w").close()
    tmp = os.path.join(tempfile.gettempdir(), "idle_pioneer_store_inset")
    expect = {}
    all_issues = []
    for tname, (W, H, _slot) in targets.items():
        band, iw, ih, _, _ = layout(W, H)
        os.makedirs(os.path.join(OUT, tname), exist_ok=True)
        for sid, scen, args, head, sub in shots:
            raw = os.path.join(OUT, "raw", tname, sid + ".png")
            inset = os.path.join(tmp, "%s_%s.png" % (tname, sid))
            if not a.skip_render:
                print("render", tname, sid, flush=True)
                for iss in render(scen, args, (W, H), raw) + render(scen, args, (iw, ih), inset):
                    all_issues.append("%s %s: %s" % (tname, sid, iss))
                Image.open(raw).convert("RGB").save(raw, optimize=True)
            out = os.path.join(OUT, tname, sid + ".png")
            compose(W, H, inset, head, sub, out)
            expect[raw] = (W, H)
            expect[out] = (W, H)
    shutil.copyfile(os.path.join(ROOT, "assets", "icons", "app_icon_512.png"), os.path.join(OUT, "icon_512.png"))
    shutil.copyfile(os.path.join(ROOT, "assets", "icons", "app_icon_1024.png"), os.path.join(OUT, "icon_1024_app_store.png"))
    shutil.copyfile(os.path.join(ROOT, "assets", "icons", "feature_graphic_1024x500.png"),
                    os.path.join(OUT, "feature_graphic_1024x500.png"))
    expect[os.path.join(OUT, "icon_512.png")] = (512, 512)
    expect[os.path.join(OUT, "icon_1024_app_store.png")] = (1024, 1024)
    expect[os.path.join(OUT, "feature_graphic_1024x500.png")] = (1024, 500)
    print()
    bad = verify(expect)
    if all_issues:
        print("\nclipcheck notes (off-screen rows of long lists are expected):")
        for i in all_issues:
            print("  ", i)
    if bad:
        raise SystemExit("%d file(s) failed the size/mode check" % bad)


if __name__ == "__main__":
    sys.exit(main())
