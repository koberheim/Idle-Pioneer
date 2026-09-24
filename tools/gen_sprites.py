"""Generates every pixel-art sprite in assets/sprites/ from the ASCII art below.

Each art pixel is one image pixel; Godot draws them with nearest filtering at
2-3x. UI frames are pre-scaled 3x so 9-slice borders stay crisp.

Re-run after editing: python tools/gen_sprites.py
"""
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")
os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)
os.makedirs(os.path.join(OUT, "ui"), exist_ok=True)
os.makedirs(os.path.join(OUT, "map"), exist_ok=True)

PAL = {
    ".": None,
    "k": (44, 28, 20), "K": (18, 14, 12),
    "w": (244, 238, 222), "W": (196, 192, 182), "g": (138, 134, 128), "G": (84, 82, 80),
    "b": (140, 88, 46), "B": (92, 56, 30), "l": (192, 138, 80), "L": (228, 194, 134),
    "y": (246, 204, 64), "Y": (186, 134, 30), "o": (222, 124, 42), "O": (160, 80, 24),
    "r": (196, 54, 42), "R": (122, 30, 28), "p": (236, 180, 142), "P": (196, 130, 96),
    "u": (64, 110, 196), "U": (32, 54, 122), "c": (150, 196, 234),
    "n": (74, 152, 62), "N": (40, 98, 42), "v": (132, 196, 86),
    "s": (206, 212, 220), "S": (110, 118, 134),
    "i": (80, 64, 170), "I": (42, 30, 100), "j": (130, 118, 214),
    "f": (156, 104, 62), "F": (102, 66, 38), "h": (196, 150, 104),
    "e": (46, 110, 76), "E": (24, 64, 44), "t": (104, 168, 120),
    "x": (160, 60, 50), "z": (228, 222, 206),
}


def art(rows, name, folder="icons", scale=1):
    h = len(rows)
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        if len(row) != w:
            print("warning: %s row %d is %d wide (expected %d)" % (name, y, len(row), w))
        for x, ch in enumerate(row):
            c = PAL.get(ch)
            if c is None:
                if ch != ".":
                    print("warning: %s unknown colour %r" % (name, ch))
                continue
            img.putpixel((x, y), c + (255,))
    img = soften(img, rows)
    if scale != 1:
        img = img.resize((w * scale, h * scale), Image.NEAREST)
    img.save(os.path.join(OUT, folder, name + ".png"))
    return img


def soften(img, rows):
    """Graveyard Keeper-style finish: outlines take a dark tint of the colour
    they enclose, and each shape gets a light top-left rim and a shaded
    bottom-right edge."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()

    def is_outline(x, y):
        return 0 <= x < w and 0 <= y < h and rows[y][x] in "kK"

    def solid(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] > 0 and rows[y][x] not in "kK"

    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                continue
            if is_outline(x, y):
                acc = [0, 0, 0]
                n = 0
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if solid(x + dx, y + dy):
                        c = src[x + dx, y + dy]
                        acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2]; n += 1
                if n:
                    dst[x, y] = (int(acc[0] / n * 0.38), int(acc[1] / n * 0.34), int(acc[2] / n * 0.34), 255)
                else:
                    dst[x, y] = (40, 26, 22, 255)
                continue
            r, g, b, a = src[x, y]
            lit = not solid(x - 1, y) or not solid(x, y - 1)
            dark = not solid(x + 1, y) or not solid(x, y + 1)
            if lit and not dark:
                dst[x, y] = (min(255, int(r * 1.16 + 10)), min(255, int(g * 1.16 + 10)), min(255, int(b * 1.12 + 8)), a)
            elif dark and not lit:
                dst[x, y] = (int(r * 0.8), int(g * 0.78), int(b * 0.82), a)
    return out


# ------------------------------------------------------------------ goods
art([
    "................",
    "......kkkkk.....",
    ".....kLlhlLk....",
    ".....klBBBlk....",
    "...kkkLlhlLkkk..",
    "..kLlhkkkkkLlhk.",
    "..klBBlkkkklBBk.",
    "..kLlhlLkkLlhlk.",
    "kkkkkkkkkkkkkkkk",
    "kLlhlLkLlhlLkLlk",
    "klBBBlkklBBlkklk",
    "klBkBlkklBkBlklk",
    "klBBBlkklBBlkklk",
    "kLlhlLkLlhlLkLlk",
    "kkkkkkkkkkkkkkkk",
    "................",
], "timber")

art([
    "................",
    "................",
    "................",
    "........kkkk....",
    "......kkWWWWkk..",
    ".kk..kWWggggWWk.",
    ".kWkkWggSggggKWk",
    ".kWWWgggSgggggWk",
    ".kWWgggggSgggggk",
    ".kWkkWwwwwwwwwWk",
    ".kk..kWwwwwwwWk.",
    "......kkWWWWkk..",
    "........kkkk....",
    "................",
    "................",
    "................",
], "cod")

art([
    "................",
    ".......k........",
    "......kok.......",
    ".....koyok......",
    "....koyOyok.....",
    "...koyyOyyok....",
    "...koyyOyyok....",
    "..koyyyOyyyok...",
    "..kOoyyOyyoOk...",
    "..koyOyOyOyok...",
    "...koyOOOyok....",
    "...kooyOyook....",
    "....kooOook.....",
    ".....kkOkk......",
    ".......Bk.......",
    ".......k........",
], "tobacco")

art([
    "................",
    "....kkk..kkk....",
    "...kwwwkkwwwk...",
    "..kwwWwwwwWwwk..",
    "..kwwwwkkwwwwk..",
    "...kwwkwwkwwk...",
    "..kkwkwwwWkwkk..",
    ".kwwwkwwwwkwwwk.",
    ".kwWwwkkkkwwWwk.",
    ".kwwwBkBBkBwwwk.",
    "..kkBBnBBnBBkk..",
    "....kBnkknBk....",
    ".....kkBBkk.....",
    ".......Bk.......",
    ".......Bk.......",
    "......kkkk......",
], "cotton")

art([
    "................",
    "................",
    "......kkkkk.....",
    "....kkgWWggkk...",
    "...kgWWgggSggk..",
    "..kgWgxggSSgggk.",
    "..kWgxxgggggxgk.",
    ".kgWggxgSggxxSk.",
    ".kgggggSSggggSk.",
    ".kgxgggggxgggSk.",
    ".kSxxggSggxxSSk.",
    "..kSggggggSSSk..",
    "...kkSSSSSSkk...",
    ".....kkkkkk.....",
    "................",
    "................",
], "iron_ore")

art([
    "................",
    "................",
    ".....kkkkkk.....",
    "....kjjjjjjk....",
    "...kjjiiiiijk...",
    "..kkkkkkkkkkkk..",
    "..kjjjjkkjjjjk..",
    "..kjiiikkjiiik..",
    "..kiiiIkkiiiIk..",
    "..kiiiIkkiiiIk..",
    "..kiIIIkkiIIIk..",
    "..kkkkkkkkkkkk..",
    "....kIIIIIIk....",
    ".....kkkkkk.....",
    "................",
    "................",
], "indigo")

art([
    ".....k....k.....",
    "....knk..knk....",
    "...kvnk.kvNk.k..",
    "..kvNk..kvk.knk.",
    "...knk..kvk.kvk.",
    "...kNk..kNk.kvk.",
    "...kvk..kvk.kNk.",
    "...knk..kvk.kvk.",
    "..kvNk..kNk.kvk.",
    "...kvk..kvk.kNk.",
    "...kNk.kvnk.kvk.",
    "...kvk..kvk.kvk.",
    "...knk..kNk.kNk.",
    "...kvk..kvk.kvk.",
    "..kkkkkkkkkkkkk.",
    "................",
], "sugar_cane")

art([
    "................",
    ".....kk..kk.....",
    "....kfFkkFfk....",
    "...kfffffffk....",
    "..kfffhhhfffk...",
    "..kffhhhhhffk...",
    ".kfffhhhhhfffk..",
    ".kFffhhhhhffFk..",
    ".kfffhhhhhfffk..",
    "..kffhhhhhffk...",
    "..kfffhhhfffk...",
    "...kfffffffk....",
    "...kFfkkkfFk....",
    "....kk...kk.....",
    "................",
    "................",
], "furs")

art([
    "................",
    "................",
    "................",
    "..kkkkkkkkkkkk..",
    ".kLLLLLLLLLLLLk.",
    ".klllllllllllhk.",
    ".kkkkkkkkkkkkkk.",
    ".kLLLLLLLLLLLLk.",
    ".kllllllblllllk.",
    ".kkkkkkkkkkkkkk.",
    ".kLLLLLLLLLLLLk.",
    ".klllblllllllhk.",
    ".kkkkkkkkkkkkkk.",
    "................",
    "................",
    "................",
], "lumber")

art([
    "................",
    "................",
    ".kk.............",
    ".kWk..kkkkkk....",
    ".kWWkkLLLLLLkk..",
    "..kWLLwLLwLLLLk.",
    "..kLLLLLLLLwLLKk",
    "..kLwLLLwLLLLLLk",
    "..kLLLLLLLLLwLLk",
    "..kWLLwLLLLLLLk.",
    ".kWWkkLLLwLLkk..",
    ".kWk..kkkkkk....",
    ".kk.............",
    "..kkkkkkkkkkkk..",
    "..kBBBBBBBBBBk..",
    "..kkkkkkkkkkkk..",
], "salt_cod")

art([
    "................",
    "............kk..",
    "..........kkbBk.",
    "........kkbbBk..",
    "......kkbbrBk...",
    "....kkbbyrk.kk..",
    "...kbbbrrk.kbBk.",
    "..kbbbBk.kkbbBk.",
    "..kbBBk.kbbyrk..",
    "...kkk.kbbrrk...",
    ".....kkbbBk.....",
    "....kbbbBk......",
    "...kbbBBk.......",
    "...kkBBk........",
    ".....kk.........",
    "................",
], "cigars")

art([
    "................",
    "................",
    "....kkkkkkkkk...",
    "...kzzzzzzzzzk..",
    "..kzwwwwwwwwWzk.",
    "..kzWWWWWWWWWzk.",
    "..kzwwwwwwwwWzk.",
    "..kzWWWWWWWWWzk.",
    "..kzwwwwwwwwWzk.",
    "..kzWWWWWWWWWzk.",
    "..kzwwwwwwwwWkWk",
    "..kzWWWWWWWWkzWk",
    "...kzzzzzzzkwWk.",
    "....kkkkkkkkkk..",
    "................",
    "................",
], "cloth")

art([
    "................",
    "................",
    "................",
    "................",
    "....kkkkkkkk....",
    "...kWSSSSSSGk...",
    "..kSSSSSSSSSGk..",
    "..kkkkkkkkkkkk..",
    "kkkkkkkkkkkkkkkk",
    "kWSSSSSGkWSSSSGk",
    "kSSSSSSSGkSSSSSk",
    "kkkkkkkkkkkkkkkk",
    "................",
    "................",
    "................",
    "................",
], "pig_iron")

art([
    "................",
    "....kkkkkkkk....",
    "...kLlllllllk...",
    "..kLlllllllllk..",
    "..kSSSSSSSSSSk..",
    "..kblbllblblbk..",
    ".kblbllbllblblk.",
    ".kblbllbllblblk.",
    ".kSSSSSSSSSSSSk.",
    ".kblbllbllblblk.",
    ".kblbllbllblblk.",
    "..kblbllblblbk..",
    "..kSSSSSSSSSSk..",
    "..kBbbbbbbbbBk..",
    "...kkkkkkkkkk...",
    "................",
], "barrels")

art([
    "................",
    "................",
    "....kkkkkkkkk...",
    "...kjjjjjjjjjk..",
    "..kjuuuuuuuuijk.",
    "..kjUUUUUUUUUjk.",
    "..kjuuuuuuuuijk.",
    "..kjUUUUUUUUUjk.",
    "..kjuuuuuuuuijk.",
    "..kjUUUUUUUUUjk.",
    "..kjuuuuuuuuikuk",
    "..kjUUUUUUUUkjuk",
    "...kjjjjjjjkuUk.",
    "....kkkkkkkkkk..",
    "................",
    "................",
], "dyed_cloth")

art([
    "................",
    ".kkkk......kk...",
    "kSSSSk....kbbk..",
    "kSsSSk...kbbk...",
    ".kkSkk..kbbk....",
    "...kbk.kbbk.....",
    "....kbkbbk......",
    ".....kbbk.......",
    "....kbkbk.......",
    "...kbbk.kbk.....",
    "..kbbk...kbk....",
    ".kSSk.....kbk...",
    "kSsSk......kbk..",
    "kSSk........kbk.",
    ".kk..........kk.",
    "................",
], "tools")

art([
    "................",
    "......kkkk......",
    "......kBBk......",
    "......kbbk......",
    ".......kk.......",
    "......kEEk......",
    ".....kEEEEk.....",
    "....kEtEEEEk....",
    "....kEtEEEEk....",
    "....kLLLLLLk....",
    "....kLrrrrLk....",
    "....kLLLLLLk....",
    "....kEtEEEEk....",
    "....kEEEEEEk....",
    ".....kkkkkk.....",
    "................",
], "rum")

art([
    "..............kk",
    ".............kSk",
    "............kSk.",
    "...........kSk..",
    "..........kSk...",
    ".........kSk....",
    "........kSk.....",
    ".......kSkk.....",
    "......kbSkGk....",
    ".....kbbk.k.....",
    "....kbbbk.......",
    "...kbbbk........",
    "..kbbBk.........",
    ".kbbBBk.........",
    "kBBBkk..........",
    "kkkk............",
], "muskets")

art([
    "................",
    "......kkkk......",
    ".......kk.......",
    "......kWWk......",
    ".....kWwwWk.....",
    "....kWwYyyWk....",
    "...kWwyyyyyWk...",
    "...kWyyYyyyWk...",
    "...kWyyyyyyWk...",
    "...kWyyyyYyWk...",
    "...kWYyyyyYWk...",
    "....kWYYYYWk....",
    ".....kkkkkk.....",
    "................",
    "................",
    "................",
], "whale_oil")

art([
    "................",
    "................",
    "................",
    "....kkkkkkkk....",
    "...kwssssssSk...",
    "..kwswwsssssSk..",
    "..kkkkkkkkkkkk..",
    "kkkkkkkkkkkkkkkk",
    "kwssssSkwsssssSk",
    "kswwsssSkswsssSk",
    "kkkkkkkkkkkkkkkk",
    "................",
    "................",
    "................",
    "................",
    "................",
], "silver")

art([
    "................",
    ".......kk.k.....",
    "......kbBkbk....",
    ".....kbbbbbBk...",
    "....kbbkbbbbBk..",
    "...kbbbbbbbbBBk.",
    "..kbbbbbbbbkBBk.",
    ".kLbbbbbbbk.kBk.",
    ".kbbbkkbbbk.kBk.",
    "..kkk.kbbbk..kk.",
    "......kbbbbk....",
    "......kbbbbBk...",
    ".....kbbbbbBk...",
    ".....kbbbbbbBk..",
    "......kkkkkkk...",
    "................",
], "horses")

art([
    "................",
    ".....kkkkkk.....",
    "...kkhhhhhhkk...",
    "..khhhkffkhhhk..",
    "..kfffkffkfffk..",
    ".kffffkffkffffk.",
    ".kfffkffffkfffk.",
    ".kffkffyffkkffk.",
    ".kfk.kfffffk.kk.",
    ".kk..kffyffk....",
    ".....kfffffk....",
    ".....kffffFk....",
    ".....kfffffk....",
    ".....khhhhhk....",
    "......kkkkk.....",
    "................",
], "fur_coats")

art([
    "................",
    "....k......k....",
    "...kok....kok...",
    "...kyk....kyk...",
    "....k......k....",
    "...kwk....kwk...",
    "...kwk...kwWk...",
    "...kwWk..kwWk...",
    "...kwWk..kwWk...",
    "...kwWk..kwWk...",
    "...kwWk..kwWk...",
    "..kkkkkkkkkkkk..",
    "..kYyyyyyyyyYk..",
    "...kkkkkkkkkk...",
    "................",
    "................",
], "candles")

art([
    "................",
    "...kkkkkkkkkk...",
    "...kwssssssSk...",
    "...kswsssssSk...",
    "....kssssssk....",
    "....kSssssSk....",
    ".....kSssSk.....",
    "......kssk......",
    "......kSSk......",
    "......kssk......",
    ".....kSssSk.....",
    "....kwssssSk....",
    "....kkkkkkkk....",
    "................",
    "................",
    "................",
], "silverware")

art([
    "..............kk",
    "......kkkk...kwk",
    ".....kSSSSk.kwk.",
    "....kSk..kSkwk..",
    "...kSk....kwk...",
    "...kSk...kwSk...",
    "...kSk..kwkkSk..",
    "...kSk.kwk.kSk..",
    "....kSkwk.kSk...",
    ".....kbbk.......",
    "....kbybk.......",
    "...kbbk.........",
    "..kyyk..........",
    ".kbbk...........",
    "kkk.............",
    "................",
], "dragoons")

ICONS_EXTRA = {
    "grain": [
        "....k.k..k.k....",
        "...kyk.kykyk....",
        "...kYyk.kYk.k...",
        "..kyYkkyYkkyk...",
        "..kYk.kYyk.kYk..",
        "...kykkyYk.kyk..",
        "....kkyYyk.kk...",
        ".....kyyyyk.....",
        ".....kbbbbk.....",
        ".....kyyyyk.....",
        "....kyyYyyyk....",
        "...kyyYk.yyyk...",
        "..kyyk...kYyyk..",
        "..kkk.....kkkk..",
        "................",
        "................"],
    "hemp": [
        "................",
        ".......k........",
        "......knk.......",
        ".....knvnk......",
        ".kk..knvnk..kk..",
        "knvk.knvnk.kvnk.",
        ".knvkknvnkkvnk..",
        "..knvknvnkvnk...",
        "...kknvvvnkk....",
        "...knnvnvnnk....",
        "..knvk.n.kvnk...",
        ".knvk..n..kvnk..",
        ".kk....n....kk..",
        ".......N........",
        "......kNk.......",
        "................"],
    "hides": [
        "................",
        "..kk........kk..",
        "..klkkkkkkkklk..",
        "...kllhhhllllk..",
        "...klhhhhhlBlk..",
        "..kllhhlllBBlk..",
        "..klllllllBllk..",
        "..kllBBllllllk..",
        "..klBBBlllhhlk..",
        "..kllBllllhhlk..",
        "...klllllllk....",
        "...klllhhllk....",
        "..klkkkkkkkklk..",
        "..kk........kk..",
        "................",
        "................"],
    "charcoal": [
        "................",
        "................",
        "................",
        "................",
        "......kkkk......",
        ".....kGGSGk.....",
        "....kGKGGGGk....",
        "..kkkGGGSKGkkk..",
        ".kGGSkGKGGkGSGk.",
        ".kGKGGkGGkGGKGk.",
        "kGGGSGGkkGGSGGGk",
        "kGKGGGKGGGKGGKGk",
        ".kkkkkkkkkkkkkk.",
        "................",
        "................",
        "................"],
    "tar": [
        "................",
        "................",
        "....kkkkkkkk....",
        "...kKKKKKKKKk...",
        "...kKGKKKKGKk...",
        "...kkkkkkkkkk...",
        "...kbbKbbbbbk...",
        "...kbbKbbbbbk...",
        "...kSSKSSSSSk...",
        "...kbbbbbbbbk...",
        "...kbbbbbbbbk...",
        "...kSSSSSSSSk...",
        "...kbbbbbbbbk...",
        "....kkkkkkkk....",
        "................",
        "................"],
    "flour": [
        "................",
        "......kkkk......",
        ".....kwWWwk.....",
        "......kbbk......",
        ".....kwwwwk.....",
        "....kwwwwwwk....",
        "...kwwwwwwwwk...",
        "...kwwWwwwwwk...",
        "..kwwwkwkwwwWk..",
        "..kwwwkkkwwwWk..",
        "..kwwwkwkwwwWk..",
        "..kwwwwwwwwwWk..",
        "...kWwwwwwwWk...",
        "....kkkkkkkk....",
        "................",
        "................"],
    "rope": [
        "................",
        "................",
        ".....kkkkkk.....",
        "...kkLlLlLlkk...",
        "..kLlkkkkkkLlk..",
        ".kLlk.kkkk.kLlk.",
        ".klLkkLlLlkkLlk.",
        ".kLlkLkkkkLklLk.",
        ".klLkLk..kLkLlk.",
        ".kLlkLlkkLlkLlk.",
        "..kLlkLlLlkLlk..",
        "..kkLlkkkkLlkk..",
        "....kkLlLlkk....",
        "......kkkk.lk...",
        "...........kLk..",
        "............kk.."],
    "leather": [
        "................",
        "................",
        "...kkkkkkkkkk...",
        "..kbbbbbbbbbbk..",
        "..kblllllllllk..",
        "..kblklklklklk..",
        "..kbllllllllbk..",
        "..kblllllllllk..",
        "..kbbbbbbbbbbk..",
        "..kblllllllllk..",
        "..kblklklklklk..",
        "..kblllllllllk..",
        "..kbbbbbbbbbbk..",
        "...kkkkkkkkkk...",
        "................",
        "................"],
    "molasses": [
        "................",
        ".......kk.......",
        "......kbbk......",
        "......kkkk......",
        ".....kBBBBk.....",
        "....kBbBBBBk.kk.",
        "...kBbBBBBBBkBk.",
        "...kbBBBBBBBkBk.",
        "...kBBOOOOBBBk..",
        "...kBBOyyOBBk...",
        "...kBBOOOOBBk...",
        "...kBBBBBBBBk...",
        "....kBBBBBBk....",
        ".....kkkkkk.....",
        "................",
        "................"],
    "cured_tobacco": [
        "................",
        "......k..k......",
        ".....kOkkOk.....",
        "....kOOkOOOk....",
        "....kObOObOk....",
        ".....kOOOOk.....",
        "......kyyk......",
        "......kYYk......",
        ".....kOOOOk.....",
        "....kObOObOk....",
        "...kOObOObOOk...",
        "...kObOOOObOk...",
        "...kOOOkkOOOk...",
        "....kkk..kkk....",
        "................",
        "................"],
    "provisions": [
        "................",
        "........kkkk....",
        ".......kwWWwk...",
        "........kbbk....",
        ".......kwwwwk...",
        "..kkkkkkwwwwwk..",
        ".kLLLLLkwwwwwk..",
        ".kkkkkkkwwWwwk..",
        ".klLbllkkwwwk...",
        ".klbLllbkkkk....",
        ".kllbLblk.......",
        ".klLbllbk.......",
        ".kkkkkkkk.......",
        "................",
        "................",
        "................"],
    "sailcloth": [
        "................",
        "................",
        "....kkkkkkkkk...",
        "...kWWWWWWWWWk..",
        "..kWwwwwwwwwLWk.",
        "..kWLLLLLLLLLWk.",
        "..kWwwwwwwwwLWk.",
        "..kWbbbbbbbbbWk.",
        "..kWwwwwwwwwLWk.",
        "..kWLLLLLLLLLWk.",
        "..kWwwwwwwwwLkWk",
        "..kWLLLLLLLLkwWk",
        "...kWWWWWWWkwWk.",
        "....kkkkkkkkkk..",
        "................",
        "................"],
    "saddles": [
        "................",
        "................",
        "................",
        "...kk......kk...",
        "..kbbk....kbbk..",
        "..kbBbkkkkbBbk..",
        "...kbbbbbbbbk...",
        "...kbBBBBBBbk...",
        "....kbbbbbbk....",
        "....kbkSSkbk....",
        "....kbk..kbk....",
        "....kbkk.kbk....",
        "...kSSk..kSSk...",
        "...kkk...kkk....",
        "................",
        "................"],
    "uniforms": [
        "................",
        ".....kkkkkk.....",
        "...kkUUrrUUkk...",
        "..kUUUrwwrUUUk..",
        ".kUUUUrwwrUUUUk.",
        ".kUUkUrwwrUkUUk.",
        ".kUUkUUyyUUkUUk.",
        ".kUkkUUUUUUkkUk.",
        ".kyk.kUyyUk.kyk.",
        ".kk..kUUUUk..kk.",
        ".....kUyyUk.....",
        ".....kUUUUk.....",
        ".....kUUkUUk....",
        "....kUUk.kUUk...",
        "....kkk...kkk...",
        "................"],
}
for _name, _rows in ICONS_EXTRA.items():
    art(_rows, _name)

# ------------------------------------------------------------------ ui icons
art([
    "................",
    ".....kkkkkk.....",
    "...kkYyyyyYkk...",
    "..kYyyyyyyyyYk..",
    "..kyywwyyyyyyk..",
    ".kYywyyYYYyyyYk.",
    ".kyyyyYyyyYyyyk.",
    ".kyyyyYyyyyyyyk.",
    ".kyyyyyYYYyyyyk.",
    ".kyyyyyyyyYyyyk.",
    ".kYyyyYyyyYyyYk.",
    "..kyyyyYYYyyyk..",
    "..kYyyyyyyyyYk..",
    "...kkYyyyyYkk...",
    ".....kkkkkk.....",
    "................",
], "gold")

art([
    ".......kk.......",
    "......kYYk......",
    ".....kkkkkk.....",
    "....kyyyyyYk....",
    "...kywyyyyyYk...",
    "...kywyyyyyYk...",
    "...kyyyyyyyYk...",
    "..kywyyyyyyyYk..",
    "..kyyyyyyyyyYk..",
    "..kyyyyyykyyYk..",
    ".kyyyyyyyykyyYk.",
    ".kyyyyyyyyykyYk.",
    "kkkkkkkkkkkkkkkk",
    "kYYYYYYYYYYYYYYk",
    "kkkkkkkkkkkkkkkk",
    ".......kk.......",
], "liberty")

art([
    "................",
    ".....kkkkkk.....",
    "...kkKKKKKKkk...",
    "..kKKKKKKKKKKk..",
    ".....kppppk.....",
    ".....kpkpkk.....",
    ".....kppppk.....",
    "......kppk......",
    "....kkbbbbkk....",
    "...kbbbwwbbbk...",
    "...kbkbwwbkbk...",
    "...kpkbbbbkpk...",
    "....kkBBBBkk....",
    ".....kBkkBk.....",
    ".....kBk.kBk....",
    ".....kk...kk....",
], "colonist")

art([
    "................",
    "....kkkkkkk.....",
    "...kSSSSSSSk....",
    "...kSsssSSSkk...",
    "...kSSSSSSSkSk..",
    "....kkkkkkkkk...",
    ".......kbk......",
    ".......kbk......",
    ".......kbk......",
    ".......kbk......",
    ".......kbk......",
    ".......kbk......",
    ".......kBk......",
    ".......kBk......",
    ".......kkk......",
    "................",
], "hammer")

art([
    "................",
    "..kkkkkkkkkkkk..",
    ".kLLLLLLLLLLLLk.",
    "kLLkLLLuuLLLLLLk",
    "kLkLLLuuuuLLLLLk",
    "kLLLLnnuuuLLkLLk",
    "kLLLnnnnuuLLLkLk",
    "kLLLLnnnuuLLLLLk",
    "kLLLLLnnuuuLLLLk",
    "kLLkLLLnuuuLLLLk",
    "kLLLkLLLuuLLrrLk",
    "kLLLLLLLLuLLrrLk",
    "kLLLLLLLLLLLLLLk",
    ".kLLLLLLLLLLLLk.",
    "..kkkkkkkkkkkk..",
    "................",
], "map")

art([
    ".......k........",
    ".......k.kk.....",
    ".....kkkkrrk....",
    "....kwwwk.......",
    "...kwwwwwk......",
    "...kwwwWwkk.....",
    "..kwwwwWwwwk....",
    "..kwwwwWwwwwk...",
    "..kwwwwWwwwwk...",
    "...kkkkkkkkkk...",
    "kk..kbk..kbk..kk",
    "kbkkkkkkkkkkkkbk",
    ".kbbbbbbbbbbbbk.",
    "..kBBBBBBBBBBk..",
    "uu.kkkkkkkkkk.uu",
    ".uuuu.uuuu.uuuu.",
], "ship_icon")

art([
    "................",
    "..........kk....",
    ".........kwWk...",
    "........kwWk....",
    ".......kwWk.....",
    "......kwWk......",
    ".....kwWk.......",
    "....kwWk........",
    "...kwWk.........",
    "...kWk..kkkkk...",
    "..kkk..kGGGGGk..",
    "..k...kGSGGGGGk.",
    "......kGGGGGGGk.",
    "......kGGGGGGGk.",
    ".......kkkkkkk..",
    "................",
], "quill")

art([
    "................",
    "......kkkk......",
    "...kk.kSSk.kk...",
    "..kSSkkSSkkSSk..",
    "..kSSSSSSSSSSk..",
    "...kSSSkkSSSk...",
    ".kkkSSk..kSSkkk.",
    ".kSSSk....kSSSk.",
    ".kSSSk....kSSSk.",
    ".kkkSSk..kSSkkk.",
    "...kSSSkkSSSk...",
    "..kSSSSSSSSSSk..",
    "..kSSkkSSkkSSk..",
    "...kk.kSSk.kk...",
    "......kkkk......",
    "................",
], "gear")

art([
    "................",
    ".....kkkkkk.....",
    "....kSSSSSSk....",
    "...kSk....kSk...",
    "...kSk....kSk...",
    "...kSk....kSk...",
    "..kkkkkkkkkkkk..",
    "..kYyyyyyyyyYk..",
    "..kyyyykkyyyyk..",
    "..kyyyykkyyyyk..",
    "..kyyyyykyyyyk..",
    "..kyyyyykyyyyk..",
    "..kYyyyyyyyyYk..",
    "..kkkkkkkkkkkk..",
    "................",
    "................",
], "lock")

art([
    "................",
    "...kkkkkkkkkk...",
    "...kBBBBBBBBk...",
    "....kwwwwwwk....",
    "....kLLLLLLk....",
    ".....kLLLLk.....",
    "......kLLk......",
    ".......kk.......",
    "......kwLk......",
    ".....kwwLLk.....",
    "....kwwwLLLk....",
    "....kLLLLLLk....",
    "...kBBBBBBBBk...",
    "...kkkkkkkkkk...",
    "................",
    "................",
], "hourglass")

art([
    "................",
    "...kkkk.........",
    "..kSSSSk........",
    ".kSSssSSk.......",
    ".kSkkkSSk.......",
    "..k...kSSk......",
    "......kbSSk.....",
    ".......kbkSk....",
    "........kbkk....",
    ".........kbk....",
    "..........kbk...",
    "...........kbk..",
    "............kbk.",
    ".............kk.",
    "................",
    "................",
], "pick")

art([
    "................",
    "................",
    "..kkkkkkkkkkkk..",
    "..kLLLLLLLLLLk..",
    "..kkkkkkkkkkkk..",
    "..klLbllllbLlk..",
    "..klbLllllLblk..",
    "..kllbLllLbllk..",
    "..klllbLLblllk..",
    "..klllLbbLlllk..",
    "..kllLbllbLllk..",
    "..klLbllllbLlk..",
    "..kkkkkkkkkkkk..",
    "................",
    "................",
    "................",
], "crate")

art([
    "................",
    "................",
    "................",
    ".kk.....kk......",
    ".kwk....kwk.....",
    "..kwk....kwk....",
    "...kwk....kwk...",
    "....kwk....kwk..",
    "....kwk....kwk..",
    "...kwk....kwk...",
    "..kwk....kwk....",
    ".kwk....kwk.....",
    ".kk.....kk......",
    "................",
    "................",
    "................",
], "speed")

art([
    ".......kk.......",
    "......kyyk......",
    "......kyyk......",
    ".....kyyyyk.....",
    "kkkkkkyyyykkkkkk",
    "kyyyyyyyyyyyyyyk",
    ".kyyyyyyyyyyyyk.",
    "..kyyyyyyyyyyk..",
    "...kyyyyyyyyk...",
    "...kyyyyyyyyk...",
    "..kyyyykkyyyyk..",
    "..kyyyk..kyyyk..",
    ".kyyk......kyyk.",
    ".kyk........kyk.",
    ".kk..........kk.",
    "................",
], "star")

art([
    "................",
    "................",
    "..kkkkkkkkkkkk..",
    ".kpppppppppppPk.",
    ".kpkkkkkkkkkkPk.",
    ".kpkwwwwwwwwkPk.",
    ".kpkwkkkkwwwkPk.",
    ".kpkwwwwwwwwkPk.",
    ".kpkwkkkkkkwkPk.",
    ".kpkwwwwwwwwkPk.",
    ".kpkwkkkwwwwkPk.",
    ".kpkkkkkkkkkkPk.",
    ".kPPPPPPPPPPPPk.",
    "..kkkkkkkkkkkk..",
    "................",
    "................",
], "scroll")

# ------------------------------------------------------------------ map sprites
art([
    "................",
    ".kkkkkkkkkkkk...",
    "kLLwwwwwwwwwLk..",
    "kLwwwwwwwwwwwLk.",
    "kLwwwwwwwwwwwwLk",
    "kLwwwwwwwwwwwwLk",
    "kLLwwwwwwwwwwLLk",
    "kkLLLLLLLLLLLLkk",
    ".kbkkkkkkkkkBkk.",
    "kkkBk...kkkBkkk.",
    "kBkkBk.kBkkkBBk.",
    "kBkkBk.kBkkkBBk.",
    ".kBBk...kBBBBk..",
    "..kk.....kkkk...",
    "................",
], "wagon", folder="map")

art([
    "......k.........",
    "......k.........",
    "....kkwkk.......",
    "...kwwwwwk.k....",
    "...kwwwwwk.kk...",
    "..kwwwwwwwkkwk..",
    "..kwwwwwwwkwwwk.",
    "..kwwwwwwwkwwwk.",
    "...kwwwwwk.kwwk.",
    "......k....kkkk.",
    "kkkkkkkkkkkkkkkk",
    "kbbbbbbbbbbbbbbk",
    ".kbbkbbbbbbkbbk.",
    "..kBBBBBBBBBBk..",
    "...kkkkkkkkkk...",
    "................",
], "ship", folder="map")

art([
    "..........k.........",
    "....k.....k.....k...",
    "...kwk..kkwkk..kwk..",
    "..kwwwk.kwwwk.kwwwk.",
    "..kwwwk.kwwwk.kwwwk.",
    ".kwwwwwkwwwwwkwwwwwk",
    ".kwwwwwkwwwwwkwwwwwk",
    ".kwwwwwkwwwwwkwwwwwk",
    "..kwwwk.kwwwk.kwwwk.",
    "....k.....k.....k...",
    "rk..k.....k.....k.kk",
    "kkkkkkkkkkkkkkkkkkkk",
    "kbbbbbbbbbbbbbbbbbbk",
    "kbkbbkbbkbbkbbkbbbbk",
    ".kbbbbbbbbbbbbbbbbk.",
    "..kBBBBBBBBBBBBBBk..",
    "...kkkkkkkkkkkkkk...",
], "merchantman", folder="map")

art([
    "................",
    "........k.......",
    "........kkk.....",
    "........kwwk....",
    "........kwwwk...",
    "........kkkkk...",
    "........k.......",
    "...kkk..k.......",
    "..kLLLk.k.......",
    ".kLLLLLkk.......",
    "kLLLkLLLk.......",
    "kLLLkLLLk.......",
    "kkkkkkkkkk......",
    "........k.......",
    "................",
    "................",
], "site", folder="map")

art([
    "................",
    "....kkkkkkkk....",
    "...kbbbbbbbbk...",
    "..kbllllllllbk..",
    "..kbllllllllbk..",
    "..kkkkkkkkkkkk..",
    "..kYyyyyyyyyYk..",
    "..kbllkyykllbk..",
    "..kbllkYYkllbk..",
    "..kbllllllllbk..",
    "..kYyyyyyyyyYk..",
    "..kbBBBBBBBBbk..",
    "...kkkkkkkkkk...",
    "cc...cccc...cc..",
    ".cccc....cccc...",
    "................",
], "chest", folder="map").save(os.path.join(OUT, "icons", "chest.png"))

exec(open(os.path.join(ROOT, "tools", "colony_art.py")).read())

# ------------------------------------------------------------------ portrait
art([
    "....kkkkkkkk....",
    "...kwwwwwwwwk...",
    "..kwWwwwwwwWwk..",
    "..kwWkppppkWwk..",
    "..kwkppppppkwk..",
    "..kwkpkppkpkwk..",
    "..kwkppppppkwk..",
    "..kWkpppPppkWk..",
    "..kWWkpRRpkWWk..",
    "..kkWWkppkWWkk..",
    "...kkkkwwkkkk...",
    "..kUUUkwwkUUUk..",
    ".kUUUUUkkUUUUUk.",
    ".kUUyUUUUUUyUUk.",
    ".kUUUUUUUUUUUUk.",
    ".kkkkkkkkkkkkkk.",
], "portrait")

# One portrait per Founding Father: hair, skin and coat recoloured from the
# template above. (hair, hair shade, skin, skin shade, coat, trim)
PORTRAIT_ROWS = [
    "....kkkkkkkk....",
    "...kwwwwwwwwk...",
    "..kwWwwwwwwWwk..",
    "..kwWkppppkWwk..",
    "..kwkppppppkwk..",
    "..kwkpkppkpkwk..",
    "..kwkppppppkwk..",
    "..kWkpppPppkWk..",
    "..kWWkpRRpkWWk..",
    "..kkWWkppkWWkk..",
    "...kkkkwwkkkk...",
    "..kUUUkwwkUUUk..",
    ".kUUUUUkkUUUUUk.",
    ".kUUyUUUUUUyUUk.",
    ".kUUUUUUUUUUUUk.",
    ".kkkkkkkkkkkkkk.",
]
FAIR, FAIR_S = (236, 186, 150), (200, 140, 106)
OLIVE, OLIVE_S = (206, 156, 112), (168, 116, 80)
TAN, TAN_S = (172, 116, 78), (136, 86, 56)
DARK, DARK_S = (126, 82, 56), (96, 60, 40)
WIG, WIG_S = (236, 232, 222), (196, 192, 182)
GREY, GREY_S = (176, 172, 164), (132, 128, 120)
BROWN, BROWN_S = (110, 74, 46), (80, 52, 32)
BLACK, BLACK_S = (40, 30, 26), (24, 18, 16)
AUBURN, AUBURN_S = (160, 76, 44), (116, 52, 30)
COATS = [(40, 70, 140), (120, 36, 46), (46, 92, 58), (40, 38, 40), (110, 72, 44), (70, 86, 110), (30, 84, 86), (150, 92, 40)]
# Per figure: (hair, hair shade, skin, skin shade). Coat colours cycle.
LOOKS = {
    "attucks": (BLACK, BLACK_S, DARK, DARK_S), "wheatley": (BLACK, BLACK_S, DARK, DARK_S),
    "armistead": (BLACK, BLACK_S, DARK, DARK_S), "freeman": (GREY, GREY_S, DARK, DARK_S),
    "banneker": (GREY, GREY_S, DARK, DARK_S), "salem": (BLACK, BLACK_S, DARK, DARK_S),
    "galvez": (BLACK, BLACK_S, OLIVE, OLIVE_S), "salomon": (BROWN, BROWN_S, OLIVE, OLIVE_S),
    "abigail_adams": (BROWN, BROWN_S, FAIR, FAIR_S), "warren": (BROWN, BROWN_S, FAIR, FAIR_S),
    "ludington": (AUBURN, AUBURN_S, FAIR, FAIR_S), "goddard": (BROWN, BROWN_S, FAIR, FAIR_S),
    "sampson": (BROWN, BROWN_S, FAIR, FAIR_S), "hart": (AUBURN, AUBURN_S, FAIR, FAIR_S),
    "jefferson": (AUBURN, AUBURN_S, FAIR, FAIR_S), "franklin": (GREY, GREY_S, FAIR, FAIR_S),
    "revere": (BROWN, BROWN_S, FAIR, FAIR_S), "paine": (BROWN, BROWN_S, FAIR, FAIR_S),
    "henry": (BROWN, BROWN_S, FAIR, FAIR_S), "hamilton": (AUBURN, AUBURN_S, FAIR, FAIR_S),
    "kosciuszko": (BROWN, BROWN_S, FAIR, FAIR_S), "pulaski": (BLACK, BLACK_S, FAIR, FAIR_S),
}
import json as _json
_content = _json.load(open(os.path.join(ROOT, "data", "content.json"), encoding="utf-8"))
FATHERS = {}
for _i, _f in enumerate(_content["fathers"]):
    _hair, _hair_s, _skin, _skin_s = LOOKS.get(_f["id"], (WIG, WIG_S, FAIR, FAIR_S))
    _coat = COATS[_i % len(COATS)]
    FATHERS[_f["id"]] = (_hair, _hair_s, _skin, _skin_s, _coat, (220, 190, 90))
for fid, (hair, hair_s, skin, skin_s, coat, trim) in FATHERS.items():
    PAL.update({"1": hair, "2": hair_s, "3": skin, "4": skin_s, "5": coat, "6": trim})
    rows = []
    for y, row in enumerate(PORTRAIT_ROWS):
        if y <= 9:
            row = row.replace("w", "1").replace("W", "2")
        row = row.replace("p", "3").replace("P", "4")
        if y >= 11:
            row = row.replace("U", "5").replace("y", "6")
        rows.append(row)
    art(rows, "portrait_" + fid)


# ------------------------------------------------------------------ ui frames
def frame(name, fill, border, inner, hi=None, lo=None, size=16, noise=0, scale=2, corner_cut=True):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    r = random.Random(name)
    for y in range(size):
        for x in range(size):
            edge = min(x, y, size - 1 - x, size - 1 - y)
            if corner_cut and (x in (0, size - 1)) and (y in (0, size - 1)):
                continue
            if edge == 0:
                c = border
            elif edge == 1 and inner:
                c = inner
            else:
                c = fill
                if hi and (y == 2 or x == 2) and edge == 2:
                    c = hi
                if lo and (y == size - 3 or x == size - 3) and edge == 2:
                    c = lo
                if noise:
                    d = r.randint(-noise, noise)
                    c = tuple(max(0, min(255, v + d)) for v in c)
            px[x, y] = c + (255,)
    img = img.resize((size * scale, size * scale), Image.NEAREST)
    img.save(os.path.join(OUT, "ui", name + ".png"))


frame("panel", (236, 220, 180), (58, 38, 24), (170, 128, 60), noise=4)
frame("panel_dark", (60, 44, 32), (20, 14, 10), (120, 88, 48), noise=3)
frame("panel_navy", (30, 44, 78), (12, 16, 30), (170, 128, 60), noise=2)
frame("card", (244, 232, 200), (96, 70, 44), None, noise=3)
frame("button", (62, 92, 150), (16, 20, 36), None, hi=(112, 146, 204), lo=(38, 58, 104))
frame("button_hover", (74, 108, 170), (16, 20, 36), None, hi=(132, 166, 220), lo=(46, 70, 120))
frame("button_pressed", (40, 62, 110), (16, 20, 36), None, hi=(30, 46, 86), lo=(60, 88, 140))
frame("button_disabled", (150, 140, 124), (70, 62, 54), None, hi=(176, 168, 152), lo=(124, 116, 102))
frame("button_buy", (66, 128, 58), (16, 30, 14), None, hi=(118, 180, 96), lo=(40, 88, 36))
frame("button_buy_pressed", (46, 96, 42), (16, 30, 14), None, hi=(36, 76, 32), lo=(70, 130, 60))
frame("button_gold", (206, 156, 46), (60, 38, 10), None, hi=(246, 212, 110), lo=(150, 104, 24))
frame("button_gold_pressed", (170, 122, 30), (60, 38, 10), None, hi=(140, 96, 20), lo=(206, 156, 46))
frame("tab", (60, 44, 32), (20, 14, 10), None, hi=(86, 64, 46), lo=(44, 32, 22))
frame("tab_active", (236, 220, 180), (20, 14, 10), (170, 128, 60))
frame("bar_bg", (46, 36, 28), (20, 14, 10), None)
frame("bar_fill", (224, 176, 60), (20, 14, 10), None, hi=(250, 220, 120))
frame("bar_fill_blue", (90, 140, 210), (20, 14, 10), None, hi=(150, 190, 240))
frame("bar_fill_green", (96, 168, 72), (20, 14, 10), None, hi=(150, 210, 120))

# app icon: capital on a sea tile inside a gold frame
icon = Image.new("RGBA", (64, 64), (22, 52, 110, 255))
ip = icon.load()
for y in range(64):
    for x in range(64):
        if (x + y * 3) % 11 == 0 and y > 40:
            ip[x, y] = (52, 104, 168, 255)
cap = Image.open(os.path.join(OUT, "map", "capital.png")).resize((64, 64), Image.NEAREST)
icon.alpha_composite(cap, (0, 0))
for i in range(64):
    for t in range(3):
        c = (206, 156, 46, 255) if t == 1 else (60, 38, 10, 255)
        ip[i, t] = c; ip[i, 63 - t] = c; ip[t, i] = c; ip[63 - t, i] = c
icon.resize((192, 192), Image.NEAREST).save(os.path.join(OUT, "app_icon.png"))
# Merchantman icon from the map sprite.
Image.open(os.path.join(OUT, "map", "merchantman.png")).save(os.path.join(OUT, "icons", "merchant_ship.png"))


def epx(img):
    """Scale2x: doubles pixel art while smoothing diagonal edges."""
    w, h = img.size
    src = img.load()
    out = Image.new("RGBA", (w * 2, h * 2))
    dst = out.load()

    def at(x, y):
        return src[min(max(x, 0), w - 1), min(max(y, 0), h - 1)]

    for y in range(h):
        for x in range(w):
            p = src[x, y]
            a, b, c, d = at(x, y - 1), at(x + 1, y), at(x - 1, y), at(x, y + 1)
            dst[x * 2, y * 2] = a if (c == a and c != d and a != b) else p
            dst[x * 2 + 1, y * 2] = b if (a == b and a != c and b != d) else p
            dst[x * 2, y * 2 + 1] = c if (d == c and d != b and c != a) else p
            dst[x * 2 + 1, y * 2 + 1] = d if (b == d and b != a and d != c) else p
    return out


# Icons are shown at 32-56 px; doubling them with Scale2x keeps pixel-art
# edges clean at that size instead of chunky 3x blocks.
import glob
for path in glob.glob(os.path.join(OUT, "icons", "*.png")):
    im = Image.open(path).convert("RGBA")
    if im.width <= 20:
        epx(im).save(path)
print("sprites written to", OUT)
