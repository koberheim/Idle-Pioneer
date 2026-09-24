"""Reference icons showing how to use lib.py. Run: python tools/hd/samples.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: E402,F401


def gold():
    ic = Icon()
    # one big coin, seen slightly from the side so its milled edge shows
    ic.ellipse((5, 7, 43, 45), GOLD_D, light=0.1, dark=0.3)
    ic.ellipse((4, 4, 42, 42), GOLD, light=0.28, dark=0.3)
    ic.circle(23, 23, 14.5, GOLD_D, shade=False)
    ic.circle(23, 23, 13.2, GOLD, light=0.3, dark=0.22, angle=45)
    # crown stamp
    ic.poly([(14, 29), (13, 17), (18, 22), (23, 14), (28, 22), (33, 17), (32, 29)], GOLD_D, shade=False)
    ic.rect((14, 29, 32, 32), GOLD_D, shade=False)
    ic.dot(13, 17, GOLD_D, 1.3)
    ic.dot(23, 14, GOLD_D, 1.3)
    ic.dot(33, 17, GOLD_D, 1.3)
    ic.dot(12, 12, CREAM, 1.6)
    ic.dot(9.5, 16, CREAM, 0.8)
    ic.save("gold")


def timber():
    ic = Icon()
    # three logs stacked, end grain facing us
    logs = [(6, 26), (22, 26), (14, 12)]
    for x, y in logs:
        ic.rect((x + 9, y, x + 30, y + 16), BARK, radius=2)
    for x, y in logs:
        ic.circle(x + 9, y + 8, 8.5, BARK, light=0.1, dark=0.3)
        ic.circle(x + 9, y + 8, 7, PINE, light=0.2, dark=0.1)
        ic.arc((x + 4, y + 3, x + 14, y + 13), 0, 360, WOOD_L, 0.8)
        ic.arc((x + 6.5, y + 5.5, x + 11.5, y + 10.5), 0, 360, WOOD_L, 0.8)
        ic.dot(x + 9, y + 8, WOOD, 0.9)
        ic.line([(x + 18, y + 4), (x + 27, y + 4)], mul(BARK, 0.75), 0.8)
        ic.line([(x + 20, y + 11), (x + 29, y + 11)], mul(BARK, 0.75), 0.8)
    ic.save("timber")


def colonist():
    ic = Icon()
    ic.shadow(24, 44, 12, 3)
    # legs and boots
    ic.rect((17, 33, 23, 43), (84, 70, 56))
    ic.rect((25, 33, 31, 43), (84, 70, 56))
    ic.rect((16, 41, 23, 45), INK_SOFT, radius=1)
    ic.rect((25, 41, 32, 45), INK_SOFT, radius=1)
    # coat
    ic.poly([(14, 20), (34, 20), (36, 36), (12, 36)], (120, 64, 44))
    ic.rect((22, 20, 26, 34), LINEN, shade=False)
    ic.rect((13, 31, 35, 33), LEATHER_D, shade=False)
    ic.rect((22.5, 30.5, 25.5, 33.5), BRASS, shade=False)
    # arms
    ic.poly([(14, 21), (10, 32), (13, 33), (17, 24)], (110, 58, 40))
    ic.poly([(34, 21), (38, 32), (35, 33), (31, 24)], (110, 58, 40))
    ic.circle(11.5, 33, 2, SKIN)
    ic.circle(36.5, 33, 2, SKIN)
    # head
    ic.ellipse((18, 9, 30, 22), SKIN)
    ic.dot(21.5, 15, INK, 0.6)
    ic.dot(26.5, 15, INK, 0.6)
    ic.line([(22.5, 18.5), (25.5, 18.5)], SKIN_D, 0.7)
    # tricorn hat
    ic.poly([(13, 11), (24, 4), (35, 11), (30, 12), (24, 10), (18, 12)], (48, 40, 36))
    ic.poly([(17, 11), (24, 5.5), (31, 11)], (64, 54, 48))
    ic.line([(14, 11), (18, 12), (24, 10), (30, 12), (34, 11)], BRASS, 0.8)
    ic.save("colonist")


if __name__ == "__main__":
    gold()
    timber()
    colonist()
    if len(sys.argv) > 1:
        sheet(["gold", "timber", "colonist"], sys.argv[1], scale=4, cols=3)
