"""48x48 painted-miniature portraits of the Founding Fathers.

Run: python tools/hd/portraits.py [sheet.png]

Every portrait is built by one parameterised generator from a per-id dict of
traits (skin, hair style and colour, face shape, age, spectacles, hat, dress,
backdrop). Each writes assets/sprites/icons/portrait_<id>.png; a neutral
colonist writes portrait.png.
"""
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: E402,F401,F403
from lib import ROOT, SS  # noqa: E402

# ---------------------------------------------------------------- palette
SKINS = {
    "pale": (244, 208, 178),
    "fair": (238, 190, 152),
    "ruddy": (234, 176, 138),
    "olive": (206, 154, 106),
    "brown": (160, 104, 68),
    "dark": (128, 82, 56),
}
HAIR = {
    "powder": (232, 228, 220),
    "powder_warm": (228, 216, 196),
    "grey": (184, 180, 174),
    "white": (236, 234, 228),
    "ginger": (184, 96, 50),
    "red_grey": (190, 132, 96),
    "auburn": (140, 64, 36),
    "red_brown": (132, 70, 42),
    "brown": (104, 70, 44),
    "dark_brown": (72, 48, 32),
    "black": (40, 32, 30),
    "blond": (206, 164, 100),
    "grey_dark": (120, 116, 112),
}
BACKDROPS = {
    "green": (40, 64, 50),
    "oxblood": (92, 36, 34),
    "navy": (34, 44, 78),
    "umber": (80, 58, 40),
    "slate": (56, 62, 70),
    "plum": (70, 42, 60),
    "teal": (34, 66, 70),
}
BLUE_COAT = (44, 62, 118)
BUFF = (214, 184, 128)
BLACK_COAT = (44, 40, 42)
LACE = (240, 236, 226)


# ---------------------------------------------------------------- people
# Defaults: gentleman, fair, powdered wig, dark coat, facing right.
D = dict(skin="fair", hair="wig", hc="powder", hw=6.6, age=0, specs=False,
         specs_up=False, hat=None, dress="coat", coat=(60, 50, 44), vest=(210, 190, 150),
         neck="stock", bg="green", d=1, heavy=False, woman=False, brow=None,
         mouth=0, long_face=0.0, extra=None)

PEOPLE = {
    "portrait": dict(hair="short_tied", hc="brown", hat="tricorn", coat=(120, 64, 44),
                     vest=LINEN, neck="stock", bg="umber"),
    "hancock": dict(coat=(118, 34, 48), vest=(226, 196, 110), neck="jabot", bg="navy",
                    extra="gold_trim", hc="powder_warm"),
    "sam_adams": dict(hair="tied", hc="grey", age=2, coat=(150, 58, 44), vest=(150, 58, 44),
                      neck="stock", bg="umber", hw=6.8, d=-1),
    "abigail_adams": dict(woman=True, hair="updo", hc="dark_brown", dress="gown", coat=(118, 90, 130),
                          neck="fichu", bg="green", extra="pearls", hw=6.0, skin="pale"),
    "sherman": dict(hair="tied", hc="brown", age=1, coat=(74, 62, 50), vest=(74, 62, 50),
                    long_face=1.5, bg="slate", hw=6.2, mouth=-1),
    "attucks": dict(skin="brown", hair="short", hc="black", dress="jacket", coat=(40, 52, 86),
                    vest=(236, 226, 206), neck="kerchief", bg="teal", hw=6.8, d=-1),
    "wheatley": dict(woman=True, skin="dark", hair="mobcap", hc="black", dress="gown",
                     coat=(58, 48, 50), neck="collar", bg="umber", hw=5.8),
    "salomon": dict(skin="olive", hair="tied", hc="dark_brown", coat=(40, 44, 58), vest=(120, 100, 70),
                    neck="jabot", bg="oxblood", hw=6.4, d=-1),
    "ludington": dict(woman=True, hair="long", hc="auburn", hat="tricorn", dress="gown",
                      coat=(64, 72, 60), neck="fichu", bg="navy", hw=5.8, skin="pale"),
    "revere": dict(hair="short_tied", hc="brown", dress="shirt", vest=(64, 90, 72),
                   neck="open", bg="slate", hw=6.8, d=-1, extra="teapot"),
    "goddard": dict(woman=True, hair="mobcap", hc="brown", dress="gown", coat=(92, 74, 60),
                    neck="fichu", bg="oxblood", hw=6.0, age=1),
    "franklin": dict(hair="bald_long", hc="grey", age=2, specs=True, heavy=True, hw=7.2,
                     coat=(98, 76, 56), vest=(98, 76, 56), bg="oxblood", d=-1),
    "john_adams": dict(hair="wig_bald", hc="powder", heavy=True, hw=7.4, age=1,
                       coat=(56, 48, 44), bg="green"),
    "hamilton": dict(hair="tied", hc="red_brown", coat=(40, 44, 50), vest=(226, 214, 190),
                     neck="jabot", bg="plum", hw=6.1, mouth=1),
    "madison": dict(hair="combed", hc="powder_warm", coat=BLACK_COAT, vest=BLACK_COAT,
                    long_face=0.5, hw=5.8, age=1, bg="teal", d=-1),
    "morris": dict(hair="wig", hc="powder", heavy=True, hw=7.8, coat=(90, 96, 104),
                   vest=(210, 200, 176), neck="jabot", bg="umber"),
    "greene": dict(hair="tied", hc="grey", dress="uniform", bg="oxblood", hw=6.4, d=-1),
    "knox": dict(hair="wig", hc="powder", dress="uniform", heavy=True, hw=7.8, bg="slate"),
    "rush": dict(hair="tied", hc="powder", coat=(70, 50, 44), vest=(70, 50, 44), long_face=0.8,
                 bg="navy", hw=6.2, d=-1, mouth=1),
    "sampson": dict(woman=True, soldier=True, hair="tied", hc="brown", dress="uniform",
                    bg="green", hw=6.0),
    "armistead": dict(skin="dark", hair="short", hc="black", dress="uniform", bg="umber", hw=6.4,
                      d=-1),
    "freeman": dict(woman=True, skin="dark", hair="headwrap", hc="grey", age=2, dress="gown",
                    coat=(58, 74, 118), neck="shawl", extra="beads", bg="oxblood", hw=6.2),
    "jefferson": dict(hair="tied", hc="red_grey", coat=(44, 42, 40), vest=(170, 50, 40),
                      neck="stock", bg="navy", hw=6.2, long_face=0.6, d=-1),
    "jay": dict(hair="wig", hc="powder", coat=BLACK_COAT, vest=BLACK_COAT, neck="bands",
                long_face=1.4, hw=5.8, bg="oxblood", extra="robe"),
    "lafayette": dict(hair="tied", hc="ginger", dress="uniform", bg="navy", hw=6.0,
                      mouth=1),
    "steuben": dict(hair="wig_bald", hc="powder", dress="uniform", age=2, heavy=True, hw=7.0,
                    bg="green", extra="star", d=-1),
    "kosciuszko": dict(hair="tousled", hc="brown", dress="uniform", bg="plum", hw=6.2,
                       uniform=((60, 80, 70), (170, 40, 44))),
    "galvez": dict(skin="olive", hair="wig", hc="powder", dress="uniform",
                   uniform=((232, 228, 216), (176, 38, 40)), bg="navy", hw=6.2, d=-1,
                   extra="sash_red"),
    "pollock": dict(hair="wig", hc="powder_warm", coat=(110, 80, 50), vest=(190, 160, 110),
                    neck="stock", bg="teal", hw=6.8, age=1, hat="tricorn"),
    "banneker": dict(skin="dark", hair="short", hc="white", age=2, coat=(96, 88, 76),
                     vest=(96, 88, 76), neck="stock", bg="green", hw=6.6, extra="quaker"),
    "rittenhouse": dict(hair="tied", hc="grey_dark", coat=(80, 62, 50), vest=(80, 62, 50),
                        long_face=1.0, hw=6.0, age=1, bg="navy", d=-1),
    "washington": dict(hair="wig", hc="powder", dress="uniform", hw=7.0, long_face=0.6,
                       bg="umber", mouth=-1, extra="sash"),
    "henry": dict(hair="wig", hc="brown", specs_up=True, coat=(40, 38, 40), vest=(40, 38, 40),
                  neck="stock", bg="oxblood", hw=6.6, long_face=0.5, d=-1),
    "paine": dict(hair="tied", hc="dark_brown", coat=(80, 90, 70), vest=(210, 196, 160),
                  neck="stock", bg="slate", hw=6.2, mouth=1, extra="nose"),
    "carroll": dict(hair="combed", hc="white", age=2, coat=(36, 70, 56), vest=(36, 70, 56),
                    long_face=1.0, hw=5.8, bg="plum"),
    "salem": dict(skin="brown", hair="short", hc="black", hat="tricorn", dress="uniform",
                  bg="green", hw=6.6, d=-1, extra="crossbelt"),
    "hart": dict(woman=True, hair="long", hc="ginger", dress="homespun", coat=(110, 82, 56),
                 neck="kerchief_w", bg="umber", hw=6.4, age=1, skin="ruddy"),
    "wilson": dict(hair="wig", hc="powder", specs=True, heavy=True, hw=7.0, coat=BLACK_COAT,
                   vest=BLACK_COAT, neck="jabot", bg="teal", d=-1),
    "warren": dict(woman=True, hair="updo_cap", hc="dark_brown", dress="gown", coat=(44, 96, 110),
                   neck="lace", bg="oxblood", hw=5.9, d=-1),
}


def traits(pid):
    t = dict(D)
    t.update(PEOPLE.get(pid, {}))
    return t


# ---------------------------------------------------------------- helpers
def oval_mask(box):
    m = Image.new("L", (48 * SS, 48 * SS), 0)
    ImageDraw.Draw(m).ellipse([box[0] * SS, box[1] * SS, box[2] * SS - 1, box[3] * SS - 1], fill=255)
    return m


FRAME = (3, 1, 45, 47)
INNER = (4.2, 2.2, 43.8, 45.8)


def backdrop(ic, col):
    ic.ellipse(FRAME, GOLD_D, shade=False)
    ic.ellipse(INNER, col, light=0.0, dark=0.35, angle=-120)
    # soft glow behind the head, painted-portrait style
    for k in range(5):
        r = 15 - k * 2.4
        ic.ellipse((21 - r, 17 - r * 1.05, 21 + r, 17 + r * 1.05), mix(col, (255, 236, 196), 0.05 + k * 0.035), shade=False)


# ---------------------------------------------------------------- figure
class Face:
    def __init__(self, t):
        self.t = t
        self.skin = SKINS[t["skin"]]
        s = self.skin
        dark = t["skin"] in ("brown", "dark")
        self.shade = mul(s, 0.78)
        self.deep = mul(s, 0.58)
        self.hi = mix(s, (255, 244, 230), 0.22 if dark else 0.5)
        self.lip = mix(mul(s, 0.8), (150, 60, 56), 0.35 if dark else 0.45)
        self.cheek = mix(s, (200, 100, 90), (0.06 if dark else 0.22) + (0.05 if t["woman"] else 0))
        self.eye = (30, 22, 20)
        self.white = (236, 230, 220)
        self.hc = HAIR[t["hc"]]
        self.brow = t["brow"] or (mul(self.hc, 0.55) if sum(self.hc) < 540 else (120, 110, 104))
        self.cx = 24.0
        self.hw = t["hw"]
        self.top = 10.0 - t["long_face"] * 0.4
        self.bot = 27.4 + t["long_face"] * 0.6 + (0.4 if t["heavy"] else 0) - (0.8 if t["woman"] else 0)
        self.d = t["d"]


def draw_back_hair(ic, f):
    t, cx, hw, hc = f.t, f.cx, f.hw, f.hc
    st = t["hair"]
    if st in ("wig", "wig_bald"):
        ic.ellipse((cx - hw - 1.2, f.top - 1.5, cx + hw + 1.2, f.top + 13), hc)
        # queue ribbon at the nape
        bx = cx - f.d * (hw - 1.5)
        ic.ellipse((bx - 1.6, 26, bx + 1.6, 29), (30, 26, 28), shade=False)
    elif st in ("tied", "tousled", "short_tied", "combed"):
        ic.ellipse((cx - hw - 0.9, f.top - 1.0, cx + hw + 0.9, f.top + 12), hc)
        if st != "combed":
            bx = cx - f.d * (hw + 0.2)
            ic.poly([(bx - 1.5, 21), (bx + 1.5, 21), (bx + 1.2, 29), (bx - 1.2, 29)], mul(hc, 0.85))
            ic.ellipse((bx - 1.5, 23, bx + 1.5, 25.5), (30, 26, 28), shade=False)
    elif st == "bald_long":
        ic.ellipse((cx - hw - 2.2, f.top + 3, cx + hw + 2.2, 33), hc)
    elif st == "long":
        ic.ellipse((cx - hw - 1.8, f.top - 1.2, cx + hw + 1.8, 32), hc)
        ic.ellipse((cx - hw - 2.6, 20, cx + hw + 2.6, 34), mul(hc, 0.9))
    elif st in ("updo", "updo_cap"):
        ic.ellipse((cx - hw - 1.4, f.top - 3.5, cx + hw + 1.4, f.top + 12), hc)
    elif st == "mobcap":
        ic.ellipse((cx - hw - 3, f.top - 3.5, cx + hw + 3, f.top + 12.5), LACE)
    elif st == "headwrap":
        ic.ellipse((cx - hw - 1.8, f.top - 4, cx + hw + 2.2, f.top + 11), LACE)


def draw_clothes(ic, f):
    t, cx = f.t, f.cx
    dress = t["dress"]
    s = f.skin
    # neck
    nw = 2.2 if t["woman"] else 3.0
    ic.rect((cx - nw, f.bot - 5, cx + nw, 34), mix(s, f.shade, 0.75), light=0.1, dark=0.2)
    ic.ellipse((cx - nw, f.bot - 1.5, cx + nw, f.bot + 1.2), f.shade, shade=False)  # shadow under the chin
    if t["woman"] and dress != "uniform":
        ic.oy = -1.5  # gowns sit higher on the shoulders
        body = [(5, 48), (7, 40), (12, 34.5), (18, 32), (30, 32), (36, 34.5), (41, 40), (43, 48)]
    else:
        body = [(3, 48), (5, 39), (9, 33.5), (17, 31), (31, 31), (39, 33.5), (43, 39), (45, 48)]
    if t["heavy"]:
        body = [(x + (-1 if x < 24 else 1), y) for x, y in body]

    if dress == "uniform":
        coat, facing = t.get("uniform") or (BLUE_COAT, BUFF)
        ic.poly(body, coat)
        # waistcoat: buff for Continentals, white for Spain and Poland
        vest = mix(BUFF, WHITE, 0.35) if coat == BLUE_COAT else (236, 232, 222)
        ic.poly([(cx - 3.6, 31), (cx + 3.6, 31), (cx + 3, 48), (cx - 3, 48)], vest)
        for y in (38, 42, 46):
            ic.dot(cx + 0.2, y, GOLD_D, 0.55)
        # narrow lapels in the facing colour, split from the vest by a shadow
        lo = mul(coat, 0.6)
        for sx in (-1, 1):
            ic.poly([(cx + sx * 3.4, 31), (cx + sx * 8.2, 32.4), (cx + sx * 6.6, 42), (cx + sx * 3.4, 42.5)],
                    facing if sx < 0 else mul(facing, 0.9))
            ic.line([(cx + sx * 3.4, 31.5), (cx + sx * 3.2, 48)], lo, 0.6)
            for y in (34.5, 37.5, 40.5):
                ic.dot(cx + sx * (6.6 - (y - 34.5) * 0.18), y, GOLD, 0.5)
        # stand collar
        ic.poly([(cx - 5.2, 29), (cx + 5.2, 29), (cx + 5.8, 32), (cx - 5.8, 32)], facing)
        if not t.get("soldier") and t["extra"] != "crossbelt":
            # epaulettes
            for sx in (-1, 1):
                ex = cx + sx * 12.2
                ic.ellipse((ex - 3.4, 30.6, ex + 3.4, 33.6), GOLD, light=0.35)
                for k in range(4):
                    xx = ex - 2.4 + k * 1.6
                    ic.line([(xx, 33.2), (xx + sx * 0.3, 35.4)], GOLD_D, 0.7)
        else:
            # plain shoulder strap / private's coat
            for sx in (-1, 1):
                ex = cx + sx * 13.5
                ic.line([(ex - 2.5, 32.5), (ex + 2.5, 33.2)], facing, 1.2)
        if t["extra"] == "crossbelt":
            ic.poly([(9, 35), (12, 34), (38, 48), (34, 48)], LINEN)
        if t["extra"] == "sash":
            ic.poly([(8, 37), (10, 35), (40, 45), (39, 48)], (90, 150, 190))
        if t["extra"] == "sash_red":
            ic.poly([(9, 36), (11, 34.5), (40, 45), (39, 48)], (180, 40, 44))
        if t["extra"] == "star":
            sx0, sy0 = cx - 11, 40
            ic.poly([(sx0, sy0 - 4), (sx0 + 1, sy0 - 1), (sx0 + 4, sy0), (sx0 + 1, sy0 + 1),
                     (sx0, sy0 + 4), (sx0 - 1, sy0 + 1), (sx0 - 4, sy0), (sx0 - 1, sy0 - 1)],
                    SILVER, shade=False)
            ic.dot(sx0, sy0, GOLD_D, 0.9)
        # white stock and a little jabot
        ic.rect((cx - 3.2, 28.6, cx + 3.2, 31.4), WHITE, light=0.1, dark=0.2)
        ic.poly([(cx - 2.2, 31), (cx + 2.2, 31), (cx + 1.6, 36), (cx - 1.6, 36)], LACE)
        return

    if dress in ("gown", "homespun"):
        gown = t["coat"]
        ic.poly(body, gown)
        # neckline skin
        ic.poly([(cx - 8, 32.5), (cx + 8, 32.5), (cx + 5, 41), (cx - 5, 41)], s, light=0.1, dark=0.1)
        neck = t["neck"]
        if neck == "fichu":
            ic.poly([(cx - 9, 32), (cx - 3, 31), (cx + 2.5, 40), (cx, 43)], LACE)
            ic.poly([(cx + 9, 32), (cx + 3, 31), (cx - 2.5, 40), (cx, 43)], mul(LACE, 0.94))
        elif neck == "collar":
            ic.poly([(cx - 7, 31.5), (cx + 7, 31.5), (cx + 5, 36), (cx, 34.5), (cx - 5, 36)], LACE)
            ic.poly([(cx - 5, 36), (cx, 34.5), (cx + 5, 36), (cx + 5, 48), (cx - 5, 48)], gown)
        elif neck == "shawl":
            # a dark shawl over the shoulders, white kerchief at the throat
            ic.poly([(7, 44), (12, 35), (cx - 4, 32.5), (cx - 1, 42), (cx - 4, 48), (6, 48)], (150, 70, 52))
            ic.poly([(41, 44), (36, 35), (cx + 4, 32.5), (cx + 1, 42), (cx + 4, 48), (42, 48)], mul((150, 70, 52), 0.9))
            ic.poly([(cx - 4, 32), (cx + 4, 32), (cx + 1.5, 40), (cx - 1.5, 40)], LACE)
        elif neck == "lace":
            ic.rect((cx - 6, 37.5, cx + 6, 48), mul(gown, 1.15))
            ic.line([(cx - 7.5, 36.8), (cx + 7.5, 36.8)], LACE, 1.6)
            for k in range(6):
                ic.dot(cx - 6.2 + k * 2.5, 37.9, LACE, 0.6)
            ic.ellipse((cx - 1.6, 39, cx + 1.6, 42), (90, 140, 170), shade=False)
        elif neck == "kerchief_w":
            kc = (206, 186, 150)
            ic.poly([(cx - 9, 32), (cx - 3, 31), (cx + 2.5, 40), (cx, 43)], kc)
            ic.poly([(cx + 9, 32), (cx + 3, 31), (cx - 2.5, 40), (cx, 43)], mul(kc, 0.92))
            ic.line([(cx - 8, 33.5), (cx - 2, 41)], mul(kc, 0.8), 0.5)
        # bodice front
        if neck in ("fichu", "kerchief_w"):
            ic.poly([(cx - 6, 43), (cx + 6, 43), (cx + 5, 48), (cx - 5, 48)], mul(gown, 1.1))
        if t["extra"] == "pearls":
            for k in range(9):
                x = cx - 3.4 + k * 0.85
                y = 30.8 + 0.35 * (4 - abs(k - 4)) * 0.8
                ic.dot(x, y, (250, 246, 236), 0.5)
        if t["extra"] == "beads":
            for k in range(7):
                x = cx - 2.7 + k * 0.9
                y = 31.2 + 0.3 * (3 - abs(k - 3))
                ic.dot(x, y, GOLD, 0.5)
        return

    coat, vest = t["coat"], t["vest"]
    if dress == "shirt":
        # Revere: shirtsleeves and waistcoat, open collar
        ic.poly(body, (236, 230, 214))
        ic.line([(9, 38), (13, 44)], (206, 198, 180), 0.8)
        ic.line([(39, 38), (35, 44)], (206, 198, 180), 0.8)
        ic.poly([(cx - 10, 33), (cx - 3, 32), (cx - 1, 48), (cx - 12, 48)], vest)
        ic.poly([(cx + 10, 33), (cx + 3, 32), (cx + 1, 48), (cx + 12, 48)], mul(vest, 0.92))
        for y in (38, 42, 46):
            ic.dot(cx - 1.7, y, BRASS, 0.55)
        ic.poly([(cx - 3.5, 29.5), (cx + 3.5, 29.5), (cx + 4, 32.5), (cx, 36), (cx - 4, 32.5)], WHITE)
        ic.poly([(cx - 1.5, 31), (cx + 1.5, 31), (cx, 35)], f.shade, shade=False)
        return
    if dress == "jacket":
        ic.poly(body, coat)
        ic.poly([(cx - 5, 31), (cx + 5, 31), (cx + 4, 48), (cx - 4, 48)], vest)
        ic.poly([(cx - 4.5, 31), (cx - 10, 33.5), (cx - 6, 48), (cx - 3, 48)], mul(coat, 1.15))
        ic.poly([(cx + 4.5, 31), (cx + 10, 33.5), (cx + 6, 48), (cx + 3, 48)], mul(coat, 0.95))
        for y in (38, 42, 46):
            ic.dot(cx - 5.5, y, BRASS, 0.55)
        # red neckerchief
        ic.poly([(cx - 4, 29), (cx + 4, 29), (cx + 4.5, 32), (cx - 4.5, 32)], (176, 46, 40))
        ic.poly([(cx - 1, 31.5), (cx + 1.5, 31.5), (cx + 2.5, 36.5), (cx + 0.5, 37)], (150, 36, 34))
        return

    # gentleman's coat
    ic.poly(body, coat)
    if t["extra"] == "robe":
        ic.poly(body, (30, 28, 32))
        # judge's robe: black with a salmon satin edge
        for sx in (-1, 1):
            ic.poly([(cx + sx * 6, 31.5), (cx + sx * 11, 33), (cx + sx * 9.5, 48), (cx + sx * 7.8, 48)],
                    (176, 84, 72) if sx < 0 else (150, 70, 60))
    ic.poly([(cx - 5, 31), (cx + 5, 31), (cx + 4.5, 48), (cx - 4.5, 48)], vest)
    if vest != coat:
        for y in (38.5, 42, 45.5):
            ic.dot(cx + 0.2, y, mul(vest, 0.6), 0.5)
    lap = mul(coat, 1.18)
    ic.poly([(cx - 4.8, 31), (cx - 9.5, 32.5), (cx - 7, 42), (cx - 4.2, 48)], lap)
    ic.poly([(cx + 4.8, 31), (cx + 9.5, 32.5), (cx + 7, 42), (cx + 4.2, 48)], mul(coat, 0.95))
    ic.poly([(cx - 5.5, 29), (cx + 5.5, 29), (cx + 6.2, 32.5), (cx - 6.2, 32.5)], mul(coat, 0.9))
    if t["extra"] == "gold_trim":
        ic.line([(cx - 4.8, 31), (cx - 9.5, 32.5), (cx - 7, 42), (cx - 4.2, 48)], GOLD, 0.8)
        ic.line([(cx + 4.8, 31), (cx + 9.5, 32.5), (cx + 7, 42), (cx + 4.2, 48)], GOLD, 0.8)
        ic.line([(cx - 4, 36), (cx - 4, 48)], GOLD_D, 0.6)
    if t["extra"] == "quaker":
        pass
    neck = t["neck"]
    if neck == "stock":
        ic.rect((cx - 3.4, 28.6, cx + 3.4, 31.6), WHITE, light=0.1, dark=0.2)
        ic.poly([(cx - 2.2, 31), (cx + 2.2, 31), (cx + 1.4, 34.5), (cx - 1.4, 34.5)], mul(WHITE, 0.95))
    elif neck == "jabot":
        ic.rect((cx - 3.4, 28.6, cx + 3.4, 31.6), WHITE, light=0.1, dark=0.2)
        ic.poly([(cx - 2.6, 31), (cx + 2.6, 31), (cx + 3.2, 36.5), (cx, 38), (cx - 3.2, 36.5)], LACE)
        for y in (33, 35.5):
            ic.line([(cx - 2.2, y), (cx, y + 0.8), (cx + 2.2, y)], mul(LACE, 0.8), 0.5)
    elif neck == "bands":
        ic.rect((cx - 3.4, 28.6, cx + 3.4, 31.6), WHITE, shade=False)
        ic.rect((cx - 2.2, 31, cx - 0.3, 37), WHITE, shade=False)
        ic.rect((cx + 0.3, 31, cx + 2.2, 37), mul(WHITE, 0.92), shade=False)


def draw_head(ic, f):
    t, cx, hw, d = f.t, f.cx, f.hw, f.d
    s = f.skin
    top, bot = f.top, f.bot
    # ear on the far side from the gaze
    ex = cx - d * (hw - 0.3)
    if t["hair"] not in ("mobcap", "headwrap", "long", "bald_long") and not t["woman"]:
        ic.ellipse((ex - 1.8, 17.5, ex + 1.8, 23), s, light=0.1, dark=0.3)
        ic.dot(ex, 20.2, f.shade, 0.7)
    # skull + jaw
    ic.ellipse((cx - hw, top, cx + hw, bot - 2), s, light=0.22, dark=0.18)
    jw = hw * (0.88 if t["heavy"] else 0.66 if t["woman"] else 0.72)
    cw = 2.8 if not t["woman"] else 2.4
    ic.poly([(cx - hw + 0.1, 18), (cx + hw - 0.1, 18), (cx + hw - 0.4, 21.5), (cx + jw, bot - 3.2),
             (cx + cw, bot - 0.2), (cx, bot + 0.2), (cx - cw, bot - 0.2), (cx - jw, bot - 3.2),
             (cx - hw + 0.4, 21.5)], s, light=0.04, dark=0.08)
    if t["heavy"]:
        ic.arc((cx - 3.5, bot - 3, cx + 3.5, bot + 1.2), 20, 160, f.shade, 0.7)
    # far cheek in shadow (the head is turned slightly toward d)
    sx = cx - d * hw
    ic.poly([(sx, 16), (sx + d * 1.6, 16), (sx + d * 1.8, 23), (cx - d * 2.4, bot - 0.5), (sx + d * 0.6, 24)], f.shade, shade=False)
    # features, pushed toward the facing side
    fx = cx + d * 0.9
    ey = top + 8.2 + t["long_face"] * 0.25
    gap = 2.9 if hw > 6.3 else 2.6
    # Eyes are placed on whole pixels so they stay crisp after reduction:
    # a lid row over a white+iris row, brow two rows above.
    # Eyes go on whole output pixels (after the zoom) so they stay crisp:
    # a lid row over a white+iris row, brow two rows above.
    ey_px = round(ic.ty(ey))
    for side in (-1, 1):
        x = round(ic.tx(fx + side * gap))
        y = ey_px
        ic.px((x - 2, y - 2, x + 2, y), mix(s, f.shade, 0.45))  # brow-ridge shade
        ic.px((x - 1, y - 1, x + 1, y), mix(f.eye, s, 0.3))     # upper lid
        ic.px((x - 1, y, x + 1, y + 1), f.white)
        ix = x if d > 0 else x - 1
        ic.px((ix, y, ix + 1, y + 1), f.eye)                    # iris
        # brow, slightly longer on the outer side
        bo = -1 if side < 0 else 0
        if t["woman"]:
            # finer, lighter brows
            ic.px((x - 1 + bo, y - 3, x + 2 + bo, y - 2), mix(f.brow, s, 0.35))
        else:
            ic.px((x - 2 + bo, y - 3, x + 2 + bo, y - 2), f.brow)
        if t["age"] >= 2:
            ic.px((x - 1, y + 2, x + 1, y + 3), mix(s, f.shade, 0.7))
    # nose: lit bridge, shadow on the far side, nostril
    nx = fx + d * 0.4
    nlen = (3.7 if t["woman"] else 4.3) + t["long_face"] * 0.3 + (0.7 if t["extra"] == "nose" else 0)
    ic.line([(nx - d * 0.2, ey + 0.2), (nx + d * 0.5, ey + nlen - 0.6)], f.hi, 0.7)
    ic.line([(nx - d * 1.1, ey + 0.8), (nx - d * 1.2, ey + nlen - 0.3)], f.shade, 0.7)
    # nostril: one dark pixel with a softer one beside it, under the nose tip
    nxp, nyp = round(ic.tx(nx - d * 0.5)), round(ic.ty(ey + nlen - 0.2))
    ic.px((nxp, nyp, nxp + 1, nyp + 1), mix(f.deep, f.shade, 0.3))
    ic.px((nxp - d, nyp, nxp - d + 1, nyp + 1), mix(f.shade, s, 0.3))
    # cheeks
    for side in (-1, 1):
        ic.dot(fx + side * (gap + 0.8), ey + 3.6, f.cheek, 1.3 if t["woman"] else 1.1)
    # mouth
    my = ey + nlen + 2.4
    m = t["mouth"]
    mw = 2.3 if not t["woman"] else 1.9
    # mouth on whole pixels: a dark parting line, corners up or down, and a
    # lighter lower lip beneath
    mx, myp = round(ic.tx(fx - 0.5)), round(ic.ty(my))
    half = 2 if not t["woman"] else 1
    part = f.lip if t["woman"] else mix(f.lip, f.deep, 0.55)
    ic.px((mx - half, myp, mx + half + 1, myp + 1), part)
    corner = mix(part, f.shade, 0.3)
    if m > 0:
        ic.px((mx - half - 1, myp - 1, mx - half, myp), corner)
        ic.px((mx + half + 1, myp - 1, mx + half + 2, myp), corner)
    elif m < 0:
        ic.px((mx - half - 1, myp + 1, mx - half, myp + 2), corner)
        ic.px((mx + half + 1, myp + 1, mx + half + 2, myp + 2), corner)
    ic.px((mx - half + 1, myp + 1, mx + half, myp + 2), mix(f.lip, s, 0.45 if t["woman"] else 0.3))
    if not t["woman"]:
        ic.dot(fx - d * 0.2, my + 2.9, f.shade, 0.6)  # chin dimple shadow
    if t["age"] >= 1 and not t["woman"]:
        # nasolabial folds
        ic.line([(fx - gap + 0.3, ey + nlen - 0.5), (fx - mw - 0.6, my + 0.8)], f.shade, 0.5)
        ic.line([(fx + gap - 0.3, ey + nlen - 0.5), (fx + mw + 0.6, my + 0.8)], f.shade, 0.5)
    if t["age"] >= 2:
        ic.line([(cx - 3, top + 3.6), (cx + 3, top + 3.6)], f.shade, 0.5)
    # spectacles
    if t["specs"]:
        rim = (60, 50, 40)
        for side in (-1, 1):
            x = fx + side * gap
            ic.arc((x - 2, ey - 1.6, x + 2, ey + 1.8), 0, 360, rim, 0.55)
            ic.dot(x - 0.8, ey - 0.6, (250, 250, 255), 0.4)
        ic.line([(fx - gap + 2, ey - 0.4), (fx + gap - 2, ey - 0.4)], rim, 0.5)
        ic.line([(fx - d * (gap + 2), ey - 0.2), (cx - d * hw, ey - 1)], rim, 0.5)


def draw_front_hair(ic, f):
    t, cx, hw, hc, d = f.t, f.cx, f.hw, f.hc, f.d
    st = t["hair"]
    top = f.top
    line_c = mul(hc, 0.8)
    if st in ("wig", "wig_bald"):
        if st == "wig":
            ic.pie((cx - hw - 0.6, top - 1.2, cx + hw + 0.6, top + 8), 180, 360, hc)
            ic.line([(cx - 2, top + 1.5), (cx + d * 3, top + 3.5)], mul(hc, 0.88), 0.5)
        else:
            # receding: hair at the sides only, high bare forehead
            ic.pie((cx - hw - 0.8, top - 0.5, cx + hw + 0.8, top + 12), 180, 225, hc)
            ic.pie((cx - hw - 0.8, top - 0.5, cx + hw + 0.8, top + 12), 315, 360, hc)
        # side rolls: two stacked curls over each ear
        for side in (-1, 1):
            x0 = cx + side * (hw + 0.3)
            for k, y in enumerate((top + 5.5, top + 8.8)):
                ic.ellipse((x0 - 2.3, y, x0 + 2.3, y + 3.2), hc, light=0.3, dark=0.3)
                ic.line([(x0 - 1.4, y + 1.6), (x0 + 1.4, y + 1.6)], line_c, 0.5)
    elif st in ("tied", "short_tied", "tousled"):
        ic.pie((cx - hw - 0.5, top - 1.0, cx + hw + 0.5, top + 7.8), 180, 360, hc)
        # hair sweeps back over the temples to the ear
        for side in (-1, 1):
            x0 = cx + side * hw
            ic.poly([(x0, top + 3.5), (x0 - side * 1.8, top + 4.5), (x0 - side * 0.8, top + 9.5), (x0 + side * 0.6, top + 10)], hc)
        ic.line([(cx - d * 1, top + 0.8), (cx + d * 3.5, top + 3.4)], line_c, 0.5)
        if st == "tousled":
            for x, l in ((cx - 2, 2.5), (cx + 0.5, 3.3), (cx + 3, 2.2)):
                ic.line([(x, top + 2.5), (x + d * 0.8, top + 3 + l)], hc, 0.9)
    elif st == "combed":
        # Madison / Carroll: hair combed forward, fringe low on the brow
        ic.pie((cx - hw - 0.5, top - 1, cx + hw + 0.5, top + 11.5), 180, 360, hc)
        for x in (-4, -2, 0, 2, 4):
            ic.line([(cx + x, top + 3.5), (cx + x + d * 0.6, top + 5.4)], hc, 0.9)
        for side in (-1, 1):
            x0 = cx + side * (hw + 0.2)
            ic.ellipse((x0 - 1.8, top + 5, x0 + 1.8, top + 11), hc)
    elif st == "short":
        ic.pie((cx - hw - 0.4, top - 0.8, cx + hw + 0.4, top + 7.6), 180, 360, hc)
        for side in (-1, 1):
            x0 = cx + side * hw
            ic.poly([(x0, top + 3.5), (x0 - side * 1.2, top + 4.2), (x0 - side * 0.6, top + 8), (x0 + side * 0.4, top + 8)], hc)
        ic.speckle((cx - hw, top - 1, cx + hw, top + 4), mix(hc, (255, 255, 255), 0.18), 14, 0.35)
    elif st == "bald_long":
        # a fringe of grey hair at the temples, bare crown
        for side in (-1, 1):
            x0 = cx + side * (hw - 0.2)
            ic.poly([(x0 + side * 0.8, top + 4), (x0 - side * 1.5, top + 6.5), (x0 - side * 0.8, top + 12),
                     (x0 + side * 2.2, top + 20), (x0 + side * 2.5, top + 8)], hc)
        ic.dot(cx - 2.5, top + 2.2, f.hi, 1.2)
    elif st == "long":
        ic.pie((cx - hw - 0.8, top - 1.2, cx + hw + 0.8, top + 8.2), 180, 360, hc)
        # centre parting, locks falling past the cheeks
        ic.line([(cx + d * 0.5, top - 0.6), (cx + d * 0.8, top + 3.5)], mul(hc, 0.75), 0.6)
        for side in (-1, 1):
            x0 = cx + side * hw
            ic.poly([(x0 + side * 0.8, top + 2), (x0 - side * 1.6, top + 4.5), (x0 - side * 0.8, top + 12),
                     (x0 + side * 1.2, top + 18), (x0 + side * 2.2, top + 10)], hc)
    elif st in ("updo", "updo_cap"):
        ic.pie((cx - hw - 0.8, top - 3.2, cx + hw + 0.8, top + 8), 180, 360, hc)
        ic.line([(cx - 3, top - 0.5), (cx + 2, top + 1.4)], mul(hc, 1.3), 0.6)
        for side in (-1, 1):
            x0 = cx + side * (hw + 0.1)
            ic.ellipse((x0 - 1.6, top + 3, x0 + 1.6, top + 9), hc)
        if st == "updo_cap":
            # a small lace cap pinned over the dressed hair, ribbon at the side
            ic.pie((cx - hw - 1.5, top - 6, cx + hw + 1.5, top + 4), 180, 360, LACE)
            for k in range(9):
                u = -1 + k / 4
                ic.dot(cx + u * (hw + 1), top - 0.8 + 1.2 * u * u, mul(LACE, 0.86), 0.6)
            ic.dot(cx + d * (hw - 0.5), top - 2.5, (70, 120, 170), 1.2)
        else:
            ic.line([(cx - hw, top + 0.2), (cx + hw * 0.4, top - 2.6)], (250, 246, 236), 0.7)  # pearl string
    elif st == "mobcap":
        # a puffed linen cap with a ruffled edge that curves down past the temples
        ic.pie((cx - hw - 0.2, top + 1.2, cx + hw + 0.2, top + 9), 180, 360, hc)
        ic.pie((cx - hw - 2.8, top - 5.5, cx + hw + 2.8, top + 6.5), 180, 360, LACE)
        ic.arc((cx - hw - 1, top - 4.5, cx + hw + 1, top + 4), 200, 340, mul(LACE, 0.86), 0.6)
        for k in range(11):
            u = -1 + k / 5
            x = cx + u * (hw + 1.4)
            y = top + 1.3 + 3.4 * u * u
            ic.dot(x, y, LACE, 1.0)
            ic.dot(x + 0.4, y + 0.7, mul(LACE, 0.84), 0.35)
        ic.line([(cx - 4, top - 1.6), (cx + 4, top - 1.6)], (150, 120, 170) if t["skin"] == "dark" else (170, 60, 60), 0.8)
    elif st == "headwrap":
        ic.pie((cx - hw - 1.4, top - 4.2, cx + hw + 1.6, top + 8), 180, 360, LACE)
        ic.line([(cx - hw, top + 1.6), (cx + hw, top - 0.8)], mul(LACE, 0.8), 0.7)
        ic.line([(cx - hw + 1, top - 1), (cx + hw - 2, top - 3)], mul(LACE, 0.84), 0.6)
        ic.ellipse((cx + d * (hw - 0.5) - 2, top - 5, cx + d * (hw - 0.5) + 2, top - 1), LACE)
        ic.line([(cx - 2, top + 1.9), (cx + 2, top + 1.3)], hc, 0.7)
    if t["specs_up"]:
        # spectacles pushed up onto the forehead
        rim = (52, 42, 34)
        for side in (-1, 1):
            x = cx + side * 2.6 + d * 0.6
            ic.ellipse((x - 1.9, top + 2, x + 1.9, top + 4.6), (226, 236, 244), shade=False)
            ic.arc((x - 1.9, top + 2, x + 1.9, top + 4.6), 0, 360, rim, 0.6)
        ic.line([(cx - 0.7 + d * 0.6, top + 3), (cx + 0.7 + d * 0.6, top + 3)], rim, 0.5)
    hat = t["hat"]
    if hat == "tricorn":
        hy = top - 0.5
        felt = (46, 40, 38)
        ic.poly([(cx - 11, hy + 3), (cx, hy - 6), (cx + 11, hy + 3), (cx + 6, hy + 4.2), (cx, hy + 2), (cx - 6, hy + 4.2)], felt)
        ic.poly([(cx - 7, hy + 2.6), (cx, hy - 5), (cx + 7, hy + 2.6)], (66, 58, 54))
        ic.line([(cx - 10, hy + 3), (cx - 6, hy + 4.2), (cx, hy + 2), (cx + 6, hy + 4.2), (cx + 10, hy + 3)], BRASS if not t["woman"] else (170, 160, 150), 0.7)
        if t["dress"] == "uniform":
            ic.dot(cx - d * 5, hy + 1.8, WHITE, 1.1)  # cockade


ZOOM = 1.12


class Zoomed(Icon):
    """An Icon whose drawing coordinates are scaled by k about (ax, ay), so
    the whole figure can be enlarged while px() still hits exact pixels."""

    def __init__(self, k, ax, ay, seed=7):
        super().__init__(seed=seed)
        self.k, self.ax, self.ay = k, ax, ay
        self.oy = 0.0  # vertical nudge, e.g. to raise a gown's neckline

    def tx(self, x):
        return self.ax + (x - self.ax) * self.k

    def ty(self, y):
        return self.ay + (y + self.oy - self.ay) * self.k

    def _b(self, box):
        return (self.tx(box[0]), self.ty(box[1]), self.tx(box[2]), self.ty(box[3]))

    def _p(self, pts):
        return [(self.tx(x), self.ty(y)) for x, y in pts]

    def poly(self, pts, color, shade=True, **kw):
        super().poly(self._p(pts), color, shade, **kw)

    def rect(self, box, color, shade=True, radius=0, **kw):
        super().rect(self._b(box), color, shade, radius * self.k, **kw)

    def ellipse(self, box, color, shade=True, **kw):
        super().ellipse(self._b(box), color, shade, **kw)

    def line(self, pts, color, width=1.0, shade=False):
        super().line(self._p(pts), color, width * self.k, shade)

    def arc(self, box, start, end, color, width=1.0):
        super().arc(self._b(box), start, end, color, width * self.k)

    def pie(self, box, start, end, color, shade=True):
        super().pie(self._b(box), start, end, color, shade)

    def px(self, box, color):
        """Exact output-pixel rectangle, bypassing the zoom."""
        Icon.rect(self, box, color, shade=False)


def portrait(pid):
    t = traits(pid)
    f = Face(t)
    ic = Icon(seed=sum(map(ord, pid)))
    backdrop(ic, BACKDROPS[t["bg"]])
    fig = Zoomed(ZOOM, 24, 44)
    draw_back_hair(fig, f)
    draw_clothes(fig, f)
    fig.oy = 0.0
    draw_head(fig, f)
    draw_front_hair(fig, f)
    m = oval_mask(INNER)
    fig.img.putalpha(ImageChops.multiply(fig.img.getchannel("A"), m))
    ic.img.alpha_composite(fig.img)
    name = "portrait" if pid == "portrait" else "portrait_" + pid
    ic.save(name, colors=64)
    return name


def father_ids():
    with open(os.path.join(ROOT, "data", "content.json"), encoding="utf-8") as fh:
        return [x["id"] for x in json.load(fh)["fathers"]]


if __name__ == "__main__":
    ids = father_ids()
    only = sys.argv[2:] if len(sys.argv) > 2 else None
    names = [portrait(pid) for pid in (only or ["portrait"] + ids)]
    if len(sys.argv) > 1:
        sheet(names, sys.argv[1], scale=6 if only else 3, cols=8 if not only else min(4, len(names)))
