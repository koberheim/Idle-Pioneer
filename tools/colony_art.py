# Colony sprites, executed inside gen_sprites.py (shares OUT, Image, random).
# 32x32 settlements in 3/4 top-down view, lit from the top-left.
import math

rnd = random.Random(7)


def colony_sprite(stage, name, capital=False):
    S = 32
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()

    def put(x, y, c, a=255):
        if 0 <= x < S and 0 <= y < S:
            if a < 255 and px[x, y][3] > 0:
                o = px[x, y]
                f = a / 255
                px[x, y] = (int(o[0] * (1 - f) + c[0] * f), int(o[1] * (1 - f) + c[1] * f), int(o[2] * (1 - f) + c[2] * f), 255)
            elif a == 255:
                px[x, y] = tuple(c) + (255,)

    def mul(c, k):
        return tuple(max(0, min(255, int(v * k))) for v in c)

    # trodden dirt clearing with a ragged grassy edge
    for y in range(S):
        for x in range(S):
            d = ((x - 15.5) / 15.0) ** 2 + ((y - 18) / 12.5) ** 2
            if d < 1.0 - rnd.random() * 0.12:
                base = (150, 122, 80) if rnd.random() < 0.7 else (132, 106, 70)
                if d > 0.75:
                    base = (112, 128, 70) if rnd.random() < 0.6 else base
                put(x, y, base)

    def shadow(x0, y0, w, h):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                put(x, y, (40, 34, 24), 110)

    def house(x, y, w=7, roof=(168, 64, 48), wall=(222, 196, 146), roof_h=4, wall_h=3):
        shadow(x + 2, y + 2, w, roof_h + wall_h)
        for yy in range(roof_h):
            k = 1.18 if yy < roof_h // 2 else 0.86
            for xx in range(w):
                c = mul(roof, k)
                if (xx + yy) % 3 == 0:
                    c = mul(c, 0.94)
                put(x + xx, y + yy, c)
        for xx in range(w):
            put(x + xx, y - 1, mul(roof, 0.4))
            put(x + xx, y + roof_h // 2, mul(roof, 1.3) if xx % 2 == 0 else mul(roof, 1.18))
        for yy in range(wall_h):
            for xx in range(w):
                put(x + xx, y + roof_h + yy, wall if xx < w - 1 else mul(wall, 0.78))
        for yy in range(-1, roof_h + wall_h + 1):
            side = roof if yy < roof_h else wall
            put(x - 1, y + yy, mul(side, 0.4))
            put(x + w, y + yy, mul(side, 0.35))
        for xx in range(-1, w + 1):
            put(x + xx, y + roof_h + wall_h, (58, 42, 30))
        put(x + w // 2, y + roof_h + 1, (86, 56, 34))
        put(x + w // 2, y + roof_h + 2, (86, 56, 34))
        if w >= 6:
            put(x + 1, y + roof_h + 1, (120, 170, 200))
        put(x + w - 2, y - 2, (120, 110, 100))
        put(x + w - 2, y - 1, (90, 80, 72))

    def church(x, y):
        house(x, y + 3, 7, roof=(96, 100, 110), wall=(236, 232, 220), roof_h=4, wall_h=4)
        for yy in range(y - 4, y + 3):
            put(x + 2, yy, (236, 232, 220)); put(x + 3, yy, (236, 232, 220)); put(x + 4, yy, (196, 190, 178))
            put(x + 1, yy, (70, 64, 60)); put(x + 5, yy, (60, 56, 52))
        put(x + 3, y - 5, (70, 64, 60)); put(x + 3, y - 6, (230, 190, 70)); put(x + 3, y - 1, (70, 64, 60))

    def palisade(gate_x):
        for i in range(90):
            a = i / 90 * 6.2832
            x = int(round(15.5 + 14.2 * math.cos(a)))
            y = int(round(18.5 + 10.8 * math.sin(a)))
            if abs(x - gate_x) <= 2 and y > 24:
                continue
            put(x, y, (126, 84, 46)); put(x, y - 1, (170, 120, 70)); put(x, y - 2, (98, 64, 36))

    def fort_walls():
        stone, stone_d, stone_l = (168, 164, 150), (112, 108, 100), (206, 202, 190)
        for x in range(2, 30):
            put(x, 7, stone_l); put(x, 8, stone)
            put(x, 29, stone); put(x, 30, stone_d)
        for y in range(7, 31):
            put(2, y, stone_l); put(3, y, stone)
            put(28, y, stone); put(29, y, stone_d)
        for bx, by in ((1, 6), (27, 6), (1, 28), (27, 28)):
            for y in range(by, by + 4):
                for x in range(bx, bx + 4):
                    put(x, y, stone_l if (x - bx) + (y - by) < 3 else stone)
        for x in range(14, 18):
            put(x, 29, (86, 58, 34)); put(x, 30, (70, 46, 28))
        for x in range(3, 29, 2):
            put(x, 6, stone_d)

    if capital:
        fort_walls()
        house(5, 10, 7, roof=(170, 60, 46))
        house(18, 10, 8, roof=(146, 52, 44))
        church(12, 17)
        house(4, 20, 6, roof=(120, 70, 44))
        house(21, 20, 6, roof=(170, 60, 46))
    else:
        palisade(15)
        if stage == 1:
            house(10, 11, 7, roof=(118, 78, 46), wall=(176, 134, 88))
            put(20, 20, (240, 180, 70)); put(21, 20, (220, 110, 40)); put(20, 21, (110, 70, 40))
            for x in range(6, 9):
                put(x, 21, (170, 126, 74)); put(x, 22, (130, 92, 52))
        elif stage == 2:
            house(5, 9, 7, roof=(170, 60, 46))
            house(18, 9, 7, roof=(118, 78, 46), wall=(190, 150, 100))
            house(11, 17, 7, roof=(146, 52, 44))
        else:
            house(4, 8, 7, roof=(170, 60, 46))
            house(15, 7, 6, roof=(146, 52, 44))
            church(22, 11)
            house(5, 17, 6, roof=(118, 78, 46), wall=(190, 150, 100))
            house(13, 17, 7, roof=(170, 60, 46))
    img.save(os.path.join(OUT, "map", name + ".png"))


colony_sprite(1, "colony_1")
colony_sprite(2, "colony_2")
colony_sprite(3, "colony_3")
colony_sprite(3, "capital", capital=True)
