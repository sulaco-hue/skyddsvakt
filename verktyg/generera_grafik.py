"""Genererar pixelgrafik för Godot-projektet (dubbel upplösning: rutor 32x16 px).

Användning:  python3 generera_grafik.py <utmapp>

Alla objekt ritas i samma isometriska rutnät och beskärs. Fotpunkten (där
objektet står på marken, mitt i sin ruta) sparas i anchors.json så att spelet
kan placera bilden exakt.
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
random.seed(11)
anchors = {}

TW, TH = 32, 16           # rutstorlek
HX, HY = TW // 2, TH // 2  # halva
CW, CH = 900, 600
OX, OY = 450, 140


def iso(gx, gy, h=0):
    return (round(OX + (gx - gy) * HX), round(OY + (gx + gy) * HY - h))


def save_obj(name, draw_fn, foot, size=(CW, CH)):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    draw_fn(d, im)
    bbox = im.getbbox()
    fx, fy = iso(*foot)
    l, t, r, b = bbox
    l, t = min(l, fx), min(t, fy)
    r, b = max(r, fx + 1), max(b, fy + 1)
    im.crop((l, t, r, b)).save(os.path.join(OUT, name + ".png"))
    anchors[name] = [fx - l, fy - t]


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3])


def face_quad(gxa, gya, gxb, gyb, h0, h1):
    """Fyrhörning på en vägg mellan två markpunkter och två höjder."""
    return [iso(gxa, gya, h0), iso(gxb, gyb, h0), iso(gxb, gyb, h1), iso(gxa, gya, h1)]


def block(d, x0, x1, y0, y1, h, top, left, right, outline=None):
    d.polygon(face_quad(x0, y1, x1, y1, 0, h), fill=left)
    d.polygon(face_quad(x1, y0, x1, y1, 0, h), fill=right)
    d.polygon([iso(x0, y0, h), iso(x1, y0, h), iso(x1, y1, h), iso(x0, y1, h)], fill=top)
    if outline:
        d.line([iso(x0, y1, h), iso(x1, y1, h), iso(x1, y0, h)], fill=outline)


# ================================================================ Rutor ==
def diamond_rows(ox, img, colfn):
    for r in range(TH):
        w = 2 * (r + 1) if r < HY else 2 * (TH - r)
        for x in range(HX - w, HX + w):
            img.putpixel((ox + x, r), colfn(x, r))


TILES = ["gras_a", "gras_b", "inne_a", "inne_b", "grus_a", "grus_b", "asfalt", "asfalt_streck",
         "stig_a", "stig_b", "vatten_a", "vatten_b"]
atlas = Image.new("RGBA", (TW * len(TILES), TH), (0, 0, 0, 0))


def grass(base, light, dark, blade):
    def f(x, r):
        v = random.random()
        if v < 0.06:
            return blade + (255,)
        if v < 0.22:
            return light + (255,)
        if v < 0.34:
            return dark + (255,)
        return base + (255,)
    return f


def gravel(base):
    def f(x, r):
        v = random.random()
        if v < 0.10:
            return shade(base, 1.18) + (255,)
        if v < 0.20:
            return shade(base, 0.86) + (255,)
        if v < 0.23:
            return (126, 120, 108, 255)
        return base + (255,)
    return f


def asphalt(x, r):
    v = random.random()
    if v < 0.08:
        return (76, 78, 82, 255)
    if v < 0.14:
        return (58, 60, 64, 255)
    return (66, 68, 72, 255)


fns = [
    grass((72, 94, 54), (82, 106, 60), (62, 82, 48), (108, 132, 76)),
    grass((68, 90, 51), (78, 100, 57), (58, 78, 45), (104, 128, 72)),
    grass((86, 102, 64), (96, 114, 70), (76, 92, 58), (118, 136, 82)),
    grass((82, 98, 61), (92, 110, 67), (72, 88, 55), (114, 132, 78)),
    gravel((98, 98, 92)), gravel((92, 92, 86)), asphalt, asphalt,
]
def dirt(base):
    def f(x, r):
        v = random.random()
        if v < 0.14:
            return shade(base, 1.15) + (255,)
        if v < 0.26:
            return shade(base, 0.85) + (255,)
        return base + (255,)
    return f


def water(base):
    def f(x, r):
        if (x + r * 3) % 11 == 0 and random.random() < 0.7:
            return (96, 132, 160, 255)  # krusning
        v = random.random()
        if v < 0.15:
            return shade(base, 1.08) + (255,)
        return base + (255,)
    return f


fns += [dirt((112, 92, 64)), dirt((106, 87, 60)), water((44, 74, 102)), water((42, 71, 98))]
for i, fn in enumerate(fns):
    diamond_rows(i * TW, atlas, fn)
# grässtrån (små lodräta streck) på gräsrutorna
for i in range(4):
    for _ in range(5):
        x, r = random.randint(8, 23), random.randint(4, 11)
        if atlas.getpixel((i * TW + x, r))[3] and atlas.getpixel((i * TW + x, r - 1))[3]:
            atlas.putpixel((i * TW + x, r), (112, 138, 80, 255))
            atlas.putpixel((i * TW + x, r - 1), (126, 150, 88, 255))
# spricka i asfalten
for (x, r) in [(9, 6), (10, 7), (11, 7), (12, 8)]:
    atlas.putpixel((6 * TW + x, r), (52, 54, 58, 255))
# mittlinje (streckad) längs ruta-kanten mot nästa körfält
for t in range(0, 12):
    x = 6 + t
    r = 11 + t // 2 - 0
    if 0 <= r < TH and atlas.getpixel((7 * TW + x, r))[3]:
        atlas.putpixel((7 * TW + x, r), (206, 200, 168, 255))
        if r + 1 < TH and atlas.getpixel((7 * TW + x, r + 1))[3]:
            pass
atlas.save(os.path.join(OUT, "rutor.png"))


# ============================================================ Byggnader ==
WALL_L, WALL_R, ROOF = (98, 102, 92), (76, 80, 72), (112, 116, 106)
WIN_DARK, WIN_LIT, WIN_LIT2 = (34, 42, 52), (246, 208, 104), (255, 232, 160)


def window_left(d, gx, y_face, h, w=0.32, hgt=9, lit=False):
    q = face_quad(gx, y_face, gx + w, y_face, h, h + hgt)
    d.polygon(q, fill=WIN_LIT if lit else WIN_DARK)
    if lit:
        d.line([q[3], q[2]], fill=WIN_LIT2)
    # fönsterbleck
    d.line([iso(gx - 0.03, y_face, h - 1), iso(gx + w + 0.03, y_face, h - 1)], fill=shade(WALL_L, 1.25))


def window_right(d, x_face, gy, h, w=0.32, hgt=9, lit=False):
    q = face_quad(x_face, gy, x_face, gy + w, h, h + hgt)
    d.polygon(q, fill=WIN_LIT if lit else WIN_DARK)
    d.line([iso(x_face, gy - 0.03, h - 1), iso(x_face, gy + w + 0.03, h - 1)], fill=shade(WALL_R, 1.25))


def building(d, im):
    x0, x1, y0, y1, H = 6, 10, 5, 8, 46
    block(d, x0, x1, y0, y1, H, ROOF, WALL_L, WALL_R)
    # sockel
    d.polygon(face_quad(x0, y1, x1, y1, 0, 4), fill=shade(WALL_L, 0.78))
    d.polygon(face_quad(x1, y0, x1, y1, 0, 4), fill=shade(WALL_R, 0.78))
    # fasadskarvar
    for gx in [6.5, 7.5, 8.5, 9.5]:
        d.line([iso(gx, y1, 4), iso(gx, y1, H - 2)], fill=shade(WALL_L, 0.92))
    for gy in [5.75, 6.5, 7.25]:
        d.line([iso(x1, gy, 4), iso(x1, gy, H - 2)], fill=shade(WALL_R, 0.9))
    # våningsband
    d.line([iso(x0, y1, 24), iso(x1, y1, 24)], fill=shade(WALL_L, 0.85))
    d.line([iso(x1, y0, 24), iso(x1, y1, 24)], fill=shade(WALL_R, 0.85))
    # fönster
    lit = {(0, 1), (2, 0), (3, 1), (1, 0)}
    for i, gx in enumerate([6.2, 7.0, 7.8, 8.6, 9.35]):
        for j, h in enumerate([10, 31]):
            window_left(d, gx, y1, h, lit=(i, j) in lit)
    for i, gy in enumerate([5.25, 6.9]):
        window_right(d, x1, gy, 31, lit=i == 1)
    window_right(d, x1, 5.25, 10)
    # dörr med lampa
    q = face_quad(x1, 6.15, x1, 6.6, 0, 16)
    d.polygon(q, fill=(46, 52, 60))
    d.line([q[3], q[2]], fill=(30, 34, 40))
    lx, ly = iso(x1, 6.37, 19)
    d.rectangle([lx - 1, ly - 1, lx, ly], fill=WIN_LIT2)
    # takkant
    d.line([iso(x0, y1, H), iso(x1, y1, H)], fill=shade(ROOF, 1.2))
    d.line([iso(x1, y1, H), iso(x1, y0, H)], fill=shade(ROOF, 1.1))
    d.line([iso(x0, y0, H), iso(x1, y0, H)], fill=shade(ROOF, 0.85))
    d.line([iso(x0, y0, H), iso(x0, y1, H)], fill=shade(ROOF, 0.85))
    # ventilationsaggregat på taket
    def roofbox(a, b, c, e, hh, col):
        d.polygon([iso(a, e, H), iso(b, e, H), iso(b, e, H + hh), iso(a, e, H + hh)], fill=shade(col, 0.9))
        d.polygon([iso(b, c, H), iso(b, e, H), iso(b, e, H + hh), iso(b, c, H + hh)], fill=shade(col, 0.72))
        d.polygon([iso(a, c, H + hh), iso(b, c, H + hh), iso(b, e, H + hh), iso(a, e, H + hh)], fill=col)
    roofbox(6.5, 7.3, 5.4, 6.0, 5, (132, 134, 128))
    roofbox(7.6, 8.0, 7.2, 7.6, 3, (120, 122, 116))
    # mast med stag
    mx, my = iso(9.0, 5.8, H)
    d.line([(mx, my), (mx, my - 34)], fill=(160, 162, 166))
    for k, w in [(12, 4), (22, 3)]:
        d.line([(mx - w, my - k), (mx + w, my - k)], fill=(150, 152, 156))
    d.line([(mx, my - 30), (mx + 3, my - 26)], fill=(150, 152, 156))
    d.rectangle([mx - 1, my - 36, mx, my - 35], fill=(236, 64, 52))

save_obj("byggnad", building, (9.5, 7.5))


def booth(d, im):
    x0, x1, y0, y1, H = 10.12, 10.88, 11.12, 11.88, 22
    block(d, x0, x1, y0, y1, H, (58, 72, 52), (86, 102, 72), (66, 80, 58))
    # fönsterband
    q = face_quad(x0 + 0.08, y1, x1 - 0.08, y1, 11, 18)
    d.polygon(q, fill=WIN_LIT)
    d.line([q[3], q[2]], fill=WIN_LIT2)
    q = face_quad(x1, y0 + 0.1, x1, y0 + 0.45, 11, 18)
    d.polygon(q, fill=(36, 44, 54))
    q = face_quad(x1, y0 + 0.52, x1, y1 - 0.08, 0, 16)
    d.polygon(q, fill=(52, 62, 48))
    # takutsprång (tunn skiva ovanpå)
    a0, a1, b0, b1 = x0 - 0.08, x1 + 0.08, y0 - 0.08, y1 + 0.08
    d.polygon(face_quad(a0, b1, a1, b1, H, H + 3), fill=(40, 50, 36))
    d.polygon(face_quad(a1, b0, a1, b1, H, H + 3), fill=(34, 42, 30))
    d.polygon([iso(x0 - 0.08, y0 - 0.08, H + 3), iso(x1 + 0.08, y0 - 0.08, H + 3),
               iso(x1 + 0.08, y1 + 0.08, H + 3), iso(x0 - 0.08, y1 + 0.08, H + 3)], fill=(64, 78, 58))

save_obj("vaktkur", booth, (10.5, 11.5))


def car(d, im):
    x0, x1, y0, y1 = 15.85, 17.1, 3.15, 3.85
    # hjul
    for gx in (16.05, 16.8):
        x, y = iso(gx, y1)
        d.rectangle([x - 1, y - 3, x + 1, y], fill=(20, 20, 22))
    for gx in (16.05, 16.8):
        x, y = iso(gx, y0)
        d.rectangle([x, y - 3, x + 1, y - 1], fill=(20, 20, 22))
    block(d, x0, x1, y0, y1, 9, (128, 50, 44), (110, 40, 36), (88, 32, 30))
    d.line([iso(x0, y1, 5), iso(x1, y1, 5)], fill=(140, 62, 54))
    # kaross ovan + rutor
    block(d, 16.1, 16.85, 3.22, 3.78, 15, (118, 46, 40), (70, 84, 102), (56, 66, 82))
    d.line([iso(16.45, 3.78, 9), iso(16.45, 3.78, 15)], fill=(118, 46, 40))
    # strålkastare (fram = +x)
    x, y = iso(x1, 3.3, 6)
    d.point((x, y), fill=(250, 240, 200))
    x, y = iso(x1, 3.7, 6)
    d.point((x, y), fill=(250, 240, 200))

save_obj("bil", car, (16.5, 3.5))


def spruce_fn(scale, seed):
    def f(d, im):
        rnd = random.Random(seed)
        x, y = iso(0.5, 0.5)
        d.rectangle([x - 1, y - 6, x, y], fill=(78, 54, 38))
        tiers = [(11, 6), (9, 14), (8, 21), (6, 28), (4, 34)]
        for i, (w, hh) in enumerate(tiers):
            w = round(w * scale)
            hh = round(hh * scale)
            top = y - hh - round(9 * scale)
            base = y - hh + 3
            d.polygon([(x - w, base), (x + w, base), (x, top)], fill=(30, 58, 42))
            # ljusare högersida, mörk underkant
            d.polygon([(x, base), (x + w, base), (x, top)], fill=(26, 50, 36))
            d.polygon([(x - w, base), (x, base), (x, top)], fill=(40, 76, 52))
            d.line([(x - w, base), (x + w, base)], fill=(22, 42, 30))
            for _ in range(int(w * 1.5)):
                px = x + rnd.randint(-w + 1, w - 1)
                py = rnd.randint(top + 2, base - 1)
                if im.getpixel((px, py))[3]:
                    d.point((px, py), fill=(54, 96, 64) if px < x else (34, 64, 46))
        d.point((x, y - round(44 * scale)), fill=(56, 98, 66))
    return f

save_obj("gran", spruce_fn(1.0, 1), (0.5, 0.5))
save_obj("gran_liten", spruce_fn(0.7, 2), (0.5, 0.5))


def lamp(d, im):
    x, y = iso(0.5, 0.5)
    d.rectangle([x - 1, y - 2, x + 1, y], fill=(54, 58, 64))
    d.line([(x, y), (x, y - 26)], fill=(78, 82, 88))
    d.line([(x, y - 26), (x + 4, y - 27)], fill=(78, 82, 88))
    d.rectangle([x + 3, y - 27, x + 6, y - 26], fill=(60, 64, 70))
    d.rectangle([x + 3, y - 25, x + 6, y - 25], fill=(255, 236, 160))

save_obj("lykta", lamp, (0.5, 0.5))

glow = Image.new("RGBA", (80, 40), (0, 0, 0, 0))
for yy in range(40):
    for xx in range(80):
        dx, dy = (xx - 39.5) / 40, (yy - 19.5) / 20
        r = math.sqrt(dx * dx + dy * dy)
        if r < 1:
            a = int(72 * (1 - r))
            a = (a // 12) * 12
            if (xx + yy) % 2 and a < 20:
                a = 0  # ditheradkant
            glow.putpixel((xx, yy), (255, 214, 130, a))
glow.save(os.path.join(OUT, "ljus.png"))
anchors["ljus"] = [40, 20]

# ======================================================= Hus och lada ==
def gavelhus(namn, bredd, djup, vagg, tak, takhojd, vagghojd, fonster_tant, dorr=True, port=False):
    """Hus med sadeltak; nock längs x-axeln, gavel mot +x."""
    x0, x1, y0, y1 = 0.08, bredd - 0.08, 0.08, djup - 0.08
    ym = (y0 + y1) / 2
    H, R = vagghojd, takhojd
    vagg_v, vagg_h = vagg, shade(vagg, 0.78)
    vit = (232, 230, 222)

    def f(d, im):
        # bakre takfall
        d.polygon([iso(x0, ym, H + R), iso(x1, ym, H + R), iso(x1, y0, H), iso(x0, y0, H)], fill=shade(tak, 0.8))
        # långsida (mot +y)
        d.polygon(face_quad(x0, y1, x1, y1, 0, H), fill=vagg_v)
        # gavel (mot +x)
        d.polygon([iso(x1, y0, 0), iso(x1, y1, 0), iso(x1, y1, H), iso(x1, ym, H + R), iso(x1, y0, H)], fill=vagg_h)
        # vita knutar
        for (gx, gy) in [(x0, y1), (x1, y1), (x1, y0)]:
            d.line([iso(gx, gy, 0), iso(gx, gy, H)], fill=vit)
        # fönster på långsidan
        antal = max(2, int(bredd * 1.3))
        for i in range(antal):
            gx = x0 + (i + 0.6) * (x1 - x0) / (antal + 0.2)
            q = face_quad(gx, y1, gx + 0.28, y1, H * 0.35, H * 0.35 + 8)
            tand = (i in fonster_tant)
            d.polygon(q, fill=(246, 208, 104) if tand else (40, 48, 58))
            d.polygon(q, outline=vit)
        # dörr / port på gaveln
        if dorr:
            q = face_quad(x1, ym - 0.18, x1, ym + 0.18, 0, min(13, H - 2))
            d.polygon(q, fill=(70, 54, 40) if not port else shade(vagg_h, 0.7))
            d.polygon(q, outline=vit)
        if port:
            q = face_quad(x1, ym - 0.45, x1, ym + 0.45, 0, H - 3)
            d.polygon(q, fill=shade(vagg_h, 0.75))
            d.line([iso(x1, ym, 0), iso(x1, ym, H - 3)], fill=vit)
            d.polygon(q, outline=vit)
        # gavelfönster
        gq = face_quad(x1, ym - 0.12, x1, ym + 0.12, H + 3, H + 9)
        d.polygon(gq, fill=(40, 48, 58))
        # främre takfall
        d.polygon([iso(x0, y1, H), iso(x1, y1, H), iso(x1, ym, H + R), iso(x0, ym, H + R)], fill=tak)
        d.line([iso(x0, ym, H + R), iso(x1, ym, H + R)], fill=shade(tak, 1.3))
        d.line([iso(x0, y1, H), iso(x1, y1, H)], fill=shade(tak, 0.7))
        # vindskiva
        d.line([iso(x1, y1, H), iso(x1, ym, H + R), iso(x1, y0, H)], fill=vit)
        # skorsten
        cx = x0 + (x1 - x0) * 0.3
        d.polygon(face_quad(cx, ym + 0.15, cx + 0.2, ym + 0.15, H + R - 2, H + R + 7), fill=(120, 60, 50))
    save_obj(namn, f, (bredd - 0.5, djup - 0.5))

gavelhus("hus_rod", 2, 2, (150, 44, 36), (46, 46, 50), 12, 18, {0, 2})
gavelhus("hus_gul", 2, 2, (204, 170, 84), (60, 58, 62), 12, 18, {1})
gavelhus("lada", 3, 2, (118, 50, 40), (88, 74, 66), 14, 22, set(), dorr=False, port=True)


def rock(d, im):
    x, y = iso(0.5, 0.5)
    d.polygon([(x - 6, y), (x - 4, y - 5), (x + 1, y - 7), (x + 5, y - 4), (x + 6, y)], fill=(112, 114, 116))
    d.polygon([(x + 1, y - 7), (x + 5, y - 4), (x + 6, y), (x + 1, y)], fill=(88, 90, 92))
    d.point((x - 2, y - 4), fill=(140, 142, 144))
    d.point((x - 4, y - 2), fill=(96, 118, 70))

save_obj("sten", rock, (0.5, 0.5))


def bush(d, im):
    rnd = random.Random(5)
    x, y = iso(0.5, 0.5)
    d.ellipse([x - 7, y - 9, x + 7, y], fill=(46, 82, 50))
    d.ellipse([x - 4, y - 11, x + 5, y - 3], fill=(56, 96, 58))
    for _ in range(14):
        px, py = x + rnd.randint(-6, 6), y - rnd.randint(1, 10)
        if im.getpixel((px, py))[3]:
            d.point((px, py), fill=(72, 116, 70) if px < x else (38, 70, 44))

save_obj("buske", bush, (0.5, 0.5))


def mailbox(d, im):
    x, y = iso(0.5, 0.5)
    d.line([(x, y), (x, y - 9)], fill=(90, 70, 50))
    d.rectangle([x - 3, y - 13, x + 3, y - 9], fill=(40, 90, 150))
    d.rectangle([x - 3, y - 13, x + 3, y - 13], fill=(60, 110, 170))
    d.point((x + 3, y - 14), fill=(200, 50, 40))

save_obj("brevlada", mailbox, (0.5, 0.5))


# ================================================= Fler skyddsobjekt ==
def vapenforrad(d, im):
    """Låg lagerbyggnad i plåt med rullport på gaveln. Fotavtryck 4x3 rutor."""
    x0, x1, y0, y1, H = 0.05, 3.95, 0.05, 2.95, 24
    vagg, vagg_m, tak = (104, 112, 100), (82, 88, 78), (90, 94, 88)
    d.polygon(face_quad(x0, y1, x1, y1, 0, H), fill=vagg)
    d.polygon(face_quad(x1, y0, x1, y1, 0, H), fill=vagg_m)
    # korrugerad plåt: lodräta ränder
    for i in range(40):
        gx = x0 + i * (x1 - x0) / 40
        d.line([iso(gx, y1, 1), iso(gx, y1, H - 1)], fill=shade(vagg, 0.9 if i % 2 else 1.06))
    for i in range(30):
        gy = y0 + i * (y1 - y0) / 30
        d.line([iso(x1, gy, 1), iso(x1, gy, H - 1)], fill=shade(vagg_m, 0.9 if i % 2 else 1.06))
    # tak med kant
    d.polygon([iso(x0, y0, H), iso(x1, y0, H), iso(x1, y1, H), iso(x0, y1, H)], fill=tak)
    d.line([iso(x0, y1, H), iso(x1, y1, H), iso(x1, y0, H)], fill=shade(tak, 1.25))
    for gx in (0.8, 1.8, 2.8):
        d.line([iso(gx, y0, H), iso(gx, y1, H)], fill=shade(tak, 0.9))
    # rullport på gaveln
    q = face_quad(x1, 0.7, x1, 2.3, 0, 17)
    d.polygon(q, fill=(70, 74, 76))
    for h in range(2, 17, 2):
        d.line([iso(x1, 0.7, h), iso(x1, 2.3, h)], fill=(58, 62, 64))
    d.polygon(q, outline=(40, 42, 44))
    # gul-svart markering vid porten
    for k, h in enumerate(range(0, 17, 3)):
        d.line([iso(x1, 0.62, h), iso(x1, 0.62, h + 2)], fill=(230, 196, 40) if k % 2 == 0 else (24, 24, 26))
    # personaldörr och belysning på långsidan
    q = face_quad(2.9, y1, 3.25, y1, 0, 13)
    d.polygon(q, fill=(60, 66, 62))
    d.polygon(q, outline=(40, 44, 42))
    lx, ly = iso(3.07, y1, 17)
    d.rectangle([lx - 2, ly - 1, lx + 1, ly], fill=(255, 236, 170))
    # skylt med nummer
    sx, sy = iso(1.0, y1, 15)
    d.rectangle([sx, sy - 3, sx + 6, sy + 1], fill=(236, 232, 214))
    d.line([(sx + 2, sy - 2), (sx + 2, sy)], fill=(30, 30, 30))
    d.line([(sx + 4, sy - 2), (sx + 4, sy)], fill=(30, 30, 30))
    # ventilationshuv
    d.polygon(face_quad(1.5, 1.2, 1.9, 1.2, H, H + 4), fill=(120, 124, 120))

save_obj("vapenforrad", vapenforrad, (3.5, 2.5))


def radiomast(d, im):
    """Fackverksmast (cirka 130 px) med staglinor, paraboler och toppljus."""
    x, y = iso(0.5, 0.5)
    hojd = 132
    # staglinor
    for (ax, ay) in [(-1.6, 0.5), (2.4, 0.2), (0.6, 2.4)]:
        gx, gy = iso(ax, ay)
        for k, frac in enumerate((0.45, 0.8)):
            d.line([(gx, gy), (x, y - int(hojd * frac))], fill=(150, 154, 160, 150))
        d.rectangle([gx - 1, gy - 1, gx + 1, gy], fill=(110, 112, 116))
    # ben och stag
    def bredd(h):
        return 6 - 4 * h / hojd
    for h in range(0, hojd, 6):
        b0, b1 = bredd(h), bredd(h + 6)
        col = (200, 60, 50) if (h // 18) % 2 == 0 and h > hojd - 54 else (180, 184, 188)
        d.line([(x - b0, y - h), (x - b1, y - h - 6)], fill=col)
        d.line([(x + b0, y - h), (x + b1, y - h - 6)], fill=col)
        d.line([(x - b0, y - h), (x + b1, y - h - 6)], fill=shade(col, 0.8))
        d.line([(x + b0, y - h), (x - b1, y - h - 6)], fill=shade(col, 0.8))
        d.line([(x - b0, y - h), (x + b0, y - h)], fill=shade(col, 0.85))
    # paraboler och antenner
    for (dx, h, r) in [(-5, 70, 4), (5, 88, 3), (-4, 104, 3)]:
        d.ellipse([x + dx - r, y - h - r, x + dx + r, y - h + r], fill=(226, 228, 230))
        d.point((x + dx, y - h), fill=(120, 124, 128))
    d.line([(x, y - hojd), (x, y - hojd - 10)], fill=(180, 184, 188))
    d.rectangle([x - 1, y - hojd - 12, x, y - hojd - 11], fill=(255, 50, 40))
    # fundament
    d.polygon([(x - 8, y), (x, y - 4), (x + 8, y), (x, y + 4)], fill=(120, 120, 116))

save_obj("radiomast", radiomast, (0.5, 0.5))


def teknikbod(d, im):
    block(d, 0.1, 0.9, 0.1, 0.9, 14, (150, 154, 148), (128, 132, 126), (106, 110, 104))
    q = face_quad(0.9, 0.3, 0.9, 0.65, 0, 11)
    d.polygon(q, fill=(90, 96, 92))
    d.polygon(q, outline=(60, 64, 62))
    x, y = iso(0.5, 0.9, 12)
    d.rectangle([x - 2, y - 1, x + 2, y], fill=(80, 84, 80))  # galler/ventil
    gx, gy = iso(0.7, 0.4, 14)
    d.line([(gx, gy), (gx, gy - 6)], fill=(170, 172, 176))

save_obj("teknikbod", teknikbod, (0.5, 0.5))


# ========================================================= Lastbil ==
# Olivgrön lastbil med kapell och "HELIKOPTER" handmålat på sidan.
GLYFER = {
    "H": ["101", "101", "111", "101", "101"], "E": ["111", "100", "110", "100", "111"],
    "L": ["100", "100", "100", "100", "111"], "I": ["111", "010", "010", "010", "111"],
    "K": ["101", "101", "110", "101", "101"], "O": ["111", "101", "101", "101", "111"],
    "P": ["110", "101", "110", "100", "100"], "T": ["111", "010", "010", "010", "010"],
    "R": ["110", "101", "110", "101", "101"],
}


def lastbil(d, im):
    rnd = random.Random(79)
    y0, y1 = 0.24, 0.76
    oliv, oliv_m, kapell, kapell_m = (98, 102, 78), (74, 78, 60), (114, 116, 100), (88, 90, 76)

    def lada(x0, x1, ya, yb, h0, h1, top, vanster, hoger):
        d.polygon(face_quad(x0, yb, x1, yb, h0, h1), fill=vanster)
        d.polygon(face_quad(x1, ya, x1, yb, h0, h1), fill=hoger)
        d.polygon([iso(x0, ya, h1), iso(x1, ya, h1), iso(x1, yb, h1), iso(x0, yb, h1)], fill=top)

    # chassi och stötfångare
    lada(0.15, 4.2, y0 + 0.08, y1 - 0.08, 3, 6, (44, 46, 40), (40, 42, 36), (32, 34, 30))
    # flak (öppet nedtill mot hjulen)
    lada(0.1, 2.85, y0, y1, 6, 13, oliv, oliv, oliv_m)
    d.line([iso(0.1, y1, 13), iso(2.85, y1, 13)], fill=shade(oliv, 1.2))
    d.line([iso(0.1, y1, 6), iso(2.85, y1, 6)], fill=shade(oliv, 0.7))
    # kapell ovanpå flaket
    lada(0.12, 2.83, y0 + 0.02, y1 - 0.02, 13, 27, shade(kapell, 1.1), kapell, kapell_m)
    for gx in (0.8, 1.5, 2.2):
        d.line([iso(gx, y1 - 0.02, 14), iso(gx, y1 - 0.02, 27)], fill=shade(kapell, 0.92))
    d.line([iso(0.12, y1 - 0.02, 27), iso(2.83, y1 - 0.02, 27)], fill=shade(kapell, 1.2))
    # hytt med vindruta och sidoruta
    lada(2.9, 3.85, y0, y1, 6, 22, oliv, oliv, oliv_m)
    q = face_quad(3.1, y1, 3.6, y1, 13, 19)
    d.polygon(q, fill=(52, 64, 74))
    d.line([q[3], q[2]], fill=(130, 150, 160))
    q = face_quad(3.85, y0 + 0.07, 3.85, y1 - 0.07, 13, 20)
    d.polygon(q, fill=(52, 64, 74))
    d.line([iso(3.85, y0 + 0.5 * (y1 - y0), 13), iso(3.85, y0 + 0.5 * (y1 - y0), 20)], fill=oliv_m)
    # motorhuv och skärmar
    lada(3.85, 4.3, y0 + 0.05, y1 - 0.05, 6, 13, shade(oliv, 1.05), oliv, oliv_m)
    for gy in (y0 + 0.13, y1 - 0.13):
        x, y = iso(4.3, gy, 9)
        d.rectangle([x, y - 1, x + 1, y], fill=(236, 226, 176))
    # hjul (framför chassit)
    for gx in (0.6, 1.35, 3.55):
        x, y = iso(gx, y1, 0)
        d.ellipse([x - 5, y - 9, x + 4, y + 1], fill=(28, 28, 28))
        d.ellipse([x - 2, y - 6, x + 1, y - 2], fill=(92, 94, 76))
    # "HELIKOPTER" handmålat: förskjuts bokstav för bokstav längs kapellets lutning
    text = "HELIKOPTER"
    bx, by = iso(0.3, y1 - 0.02, 23)
    px = 0
    for bokstav in text:
        dy = px // 2 + rnd.choice([0, 0, 0, 1])
        for r, rad in enumerate(GLYFER[bokstav]):
            for c, tecken in enumerate(rad):
                if tecken == "1":
                    d.point((bx + px + c, by + dy + r), fill=(244, 244, 238))
        px += 4


save_obj("lastbil", lastbil, (3.5, 0.5), size=(CW, CH))


# =============================================================== Staket ==
POST, POST_HI = (150, 156, 162), (196, 200, 206)
RAIL, MESH, WIRE = (132, 138, 146), (118, 124, 132, 150), (172, 176, 182)
FH = 13  # staketets höjd


def fence_half(dx, dy):
    def f(d, im):
        a = iso(0.5, 0.5)
        b = iso(0.5 + dx, 0.5 + dy)
        n = max(1, abs(b[0] - a[0]))
        for i in range(n + 1):
            t = i / n
            x = round(a[0] + (b[0] - a[0]) * t)
            yb = a[1] + (b[1] - a[1]) * t
            # nät (glest rutmönster)
            for hh in range(2, FH - 1):
                if (x + hh) % 3 == 0 or (x - hh) % 3 == 0:
                    im.putpixel((x, round(yb) - hh), MESH)
            for hh, col in [(FH, RAIL), (FH - 6, RAIL), (1, RAIL)]:
                im.putpixel((x, round(yb) - hh), col + (255,))
            if i % 2 == 0:
                im.putpixel((x, round(yb) - FH - 2), WIRE + (255,))
        # stolpe i änden
        d.line([b, (b[0], b[1] - FH - 2)], fill=POST)
        d.point((b[0], b[1] - FH - 2), fill=POST_HI)
    return f

for name, dx, dy in [("staket_xp", 0.5, 0), ("staket_xn", -0.5, 0), ("staket_yp", 0, 0.5), ("staket_yn", 0, -0.5)]:
    save_obj(name, fence_half(dx, dy), (0.5, 0.5))


def post(d, im):
    a = iso(0.5, 0.5)
    d.rectangle([a[0], a[1] - FH - 2, a[0] + 1, a[1]], fill=POST)
    d.line([(a[0], a[1] - FH - 2), (a[0], a[1])], fill=POST_HI)

save_obj("staket_stolpe", post, (0.5, 0.5))


def gate_half(dx, dy):
    def f(d, im):
        a = iso(0.5, 0.5)
        b = iso(0.5 + dx, 0.5 + dy)
        n = max(1, abs(b[0] - a[0]))
        for i in range(n + 1):
            t = i / n
            x = round(a[0] + (b[0] - a[0]) * t)
            y = round(a[1] + (b[1] - a[1]) * t) - 8
            col = (222, 58, 48) if (i // 3) % 2 else (240, 240, 234)
            for k in range(3):
                d.point((x, y - k), fill=col if k < 2 else shade(col, 0.75))
    return f

for name, dx, dy in [("bom_yp", 0, 0.5), ("bom_yn", 0, -0.5), ("bom_xp", 0.5, 0), ("bom_xn", -0.5, 0)]:
    save_obj(name, gate_half(dx, dy), (0.5, 0.5))


def gate_up(d, im):
    """Uppfälld bom vid gångjärnet (änden mot +y)."""
    bx, by = iso(0.5, 0.95)
    for k in range(34):
        col = (222, 58, 48) if (k // 4) % 2 else (240, 240, 234)
        d.point((bx, by - 8 - k), fill=col)
        d.point((bx + 1, by - 8 - k), fill=shade(col, 0.8))

save_obj("bom_uppe", gate_up, (0.5, 0.5))


def gate_foot(d, im):
    bx, by = iso(0.5, 0.95)
    d.rectangle([bx - 2, by - 9, bx + 3, by], fill=(70, 74, 80))
    d.rectangle([bx - 2, by - 9, bx + 3, by - 8], fill=(222, 58, 48))
    d.point((bx + 2, by - 5), fill=(120, 220, 110))

save_obj("bom_fot", gate_foot, (0.5, 0.5))


def sign(d, im):
    x, y = iso(0.5, 0.5)
    d.rectangle([x - 5, y - 17, x + 6, y - 8], fill=(240, 236, 220))
    d.rectangle([x - 5, y - 17, x + 6, y - 8], outline=(196, 52, 44))
    d.line([(x - 3, y - 15), (x + 4, y - 15)], fill=(196, 52, 44))
    for yy in (y - 13, y - 11):
        d.line([(x - 3, yy), (x + 4, yy)], fill=(60, 60, 64))
    d.point((x + 4, y - 11), fill=(240, 236, 220))

save_obj("skylt", sign, (0.5, 0.5))

# ============================================================== Figurer ==
PAL = {
    "H": (46, 62, 38), "h": (66, 86, 52), "s": (226, 182, 142), "S": (196, 150, 112), "e": (34, 30, 30),
    "c": (90, 108, 64), "C": (62, 78, 46), "v": (230, 214, 72), "B": (26, 26, 28), "k": (40, 46, 34),
    "b": (28, 28, 30), "R": (180, 58, 48), "r": (140, 42, 36), "j": (184, 122, 62), "J": (144, 92, 46),
    "n": (62, 84, 128), "N": (46, 62, 98), "K": (22, 22, 24),
    "A": (16, 16, 18), "a": (58, 60, 64), "E": (64, 96, 52), "p": (18, 18, 20), "P": (232, 196, 40),
    "W": (236, 232, 220), "X": (255, 140, 40),
    "Y": (62, 96, 150), "y": (46, 72, 116), "Z": (78, 80, 66), "z": (152, 140, 108), "O": (28, 28, 30),
    "Q": (60, 62, 66), "u": (222, 192, 112), "m": (222, 112, 152),
}
# ---- M/90-mönster (kantiga splitterfält i fyra färger) ------------------
M90 = [(124, 138, 92), (84, 104, 62), (50, 68, 42), (26, 28, 24)]


def m90_texture(w, h, seed=90, scale=1.0):
    rnd = random.Random(seed)
    tex = Image.new("RGB", (w, h), M90[0])
    td = ImageDraw.Draw(tex)
    for col, n in [(M90[1], int(w * h / 40)), (M90[2], int(w * h / 70)), (M90[3], int(w * h / 160))]:
        for _ in range(n):
            cx, cy = rnd.uniform(-4, w + 4), rnd.uniform(-4, h + 4)
            L = rnd.uniform(3, 8) * scale
            t = rnd.uniform(1, 2.4) * scale
            # splitter: smala, snedställda fyrhörningar
            ang = math.radians(rnd.choice([-35, -30, -25, 145, 150]))
            dx, dy = math.cos(ang) * L, math.sin(ang) * L
            nx, ny = -math.sin(ang) * t, math.cos(ang) * t
            k = rnd.uniform(0.2, 0.8)
            td.polygon([(cx, cy), (cx + dx, cy + dy), (cx + dx * k + nx, cy + dy * k + ny),
                        (cx + nx * 0.6, cy + ny * 0.6)], fill=col)
    return tex

M90_SPRITE = m90_texture(48, 40, seed=7)

# Skyddsvakt i M/90 med hjälm, gröna hörselskydd (E), skyddsvaktsmärke (p/P)
# och svart automatkarbin (A/a). U = uniform, H = hjälm (mönstrad).
GUARD_TOP = [
    "...HHHHHH...",
    "..HHHHHHHH..",
    ".HHHHHHHHHH.",
    "..EssssssE..",
    "..EsesseSE..",
    "...SssssS...",
    "....SSSS..a.",
    "..UUUUUUUAA.",
    ".UUpPUUUAAU.",
    ".UUppUAAkUU.",
    ".UUUAAaUUUU.",
    ".UUAAkaUUUU.",
    ".kAAUUUUUUk.",
    ".k.BBBBBB.k.",
]
GUARD_LEGS = [
    ["...UUUUUU...", "...UUU.UUU..", "...UUU.UUU..", "...UUU.UUU..", "...UUU.UUU..", "...UUU.UUU..",
     "...bbb.bbb..", "..bbbb.bbbb."],
    ["...UUUUUU...", "..UUU..UUU..", "..UUU...UUU.", ".UUU....UUU.", ".UUU....UUU.", ".UUU....UUU.",
     ".bbb....bbb.", "bbbb.....bbb"],
]
CIV_TOP = [
    "....RRRR....",
    "...RrRRrR...",
    "..RRRRRRRR..",
    "..rrrrrrrr..",
    "...ssssss...",
    "KKKKssess...",
    "KKKKssss....",
    "..KSSSS.....",
    "..jJjjjjJ...",
    ".jjJjjjjJj..",
    "jjjjJjjjJjj.",
    "jjjjJjjjJjj.",
    ".jjjJjjjJjj.",
    ".JjjjjjjjJJ.",
]
CIV_LEGS = [
    ["..nnnnnnn...", "..nNn.nNn...", "..nNn.nNn...", "..nNn.nNn...", "..nNn.nNn...", "..nNn.nNn...",
     "..bbb.bbb...", ".bbbb.bbbb.."],
    ["..nnnnnnn...", ".nNn...nNn..", ".nNn...nNn..", "nNn.....nNn.", "nNn.....nNn.", "nNn.....nNn.",
     "bbb.....bbb.", "bbbb....bbbb"],
]


def figure(name, top, legs):
    art = top + legs
    w, h = 16, len(art) + 3
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([1, h - 5, 14, h - 1], fill=(18, 26, 18, 140))
    for r, row in enumerate(art):
        for c, ch in enumerate(row):
            if ch == "U":
                col = M90_SPRITE.getpixel((c + 3, r + 2))
            elif ch == "H":
                col = shade(M90_SPRITE.getpixel((c + 20, r + 20)), 0.85)
            elif ch != ".":
                col = PAL[ch]
            else:
                continue
            d.point((2 + c, r), fill=col + (255,))
    # konturer på hjälmens underkant för läsbarhet
    for c, ch in enumerate(art[2]):
        if ch == "H":
            d.point((2 + c, 2), fill=shade(PAL["k"], 0.8) + (255,))
    im.save(os.path.join(OUT, name + ".png"))
    anchors[name] = [8, h - 3]

# Viloanimationer: radbyten mot grundfiguren (rad -> ny rad, 12 tecken).
# W = kopp/cigarett, X = glöd.
VILA = {
    "titta_v": {4: "..EessesSE.."},
    "titta_h": {4: "..EssesseE.."},
    "kaffe_lag": {9: ".UUppUAAkWW.", 12: ".kAAUUUUUUU."},
    "kaffe_dricker": {5: "...SsssWWk..", 6: "....SSSWWka.", 12: ".kAAUUUUUUU."},
    "roka_ner": {11: ".UUAAkaUUUWX", 12: ".kAAUUUUUUU."},
    "roka_hand": {5: "...SssssSWX.", 6: "....SSSS.ka.", 12: ".kAAUUUUUUU."},
    "fippla_radio": {7: ".kUUUUUUUAA.", 12: "..AAUUUUUUk.", 13: "...BBBBBB.k."},
    "fippla_hjalm": {2: "kHHHHHHHHHH.", 3: ".kEssssssE..", 12: "..AAUUUUUUk.", 13: "...BBBBBB.k."},
}

for i in range(2):
    figure(f"vakt_{i}", GUARD_TOP, GUARD_LEGS[i])
for namn, byten in VILA.items():
    topp = list(GUARD_TOP)
    for rad, text in byten.items():
        assert len(text) == 12, (namn, rad, text)
        topp[rad] = text
    figure(f"vakt_vila_{namn}", topp, GUARD_LEGS[0])

# rök och ånga
rok = Image.new("RGBA", (5, 4), (0, 0, 0, 0))
for (x, y, a) in [(1, 0, 120), (2, 0, 150), (3, 0, 110), (0, 1, 110), (1, 1, 170), (2, 1, 190), (3, 1, 160),
                  (4, 1, 90), (1, 2, 140), (2, 2, 170), (3, 2, 130), (2, 3, 90)]:
    rok.putpixel((x, y), (200, 204, 208, a))
rok.save(os.path.join(OUT, "rok.png"))
anchors["rok"] = [2, 2]
anga = Image.new("RGBA", (3, 3), (0, 0, 0, 0))
for (x, y, a) in [(1, 0, 150), (0, 1, 120), (1, 1, 200), (2, 1, 120), (1, 2, 140)]:
    anga.putpixel((x, y), (240, 244, 248, a))
anga.save(os.path.join(OUT, "anga.png"))
anchors["anga"] = [1, 1]
for i in range(2):
    figure(f"civil_{i}", CIV_TOP, CIV_LEGS[i])

# Piloten (pappa med keps, glasögon och handkontroll) och dottern Elsa
PAPPA_TOP = [
    "....ZZZZ....",
    "...ZZZZZZZ..",
    "...ssssss...",
    "..sOOsOOs...",
    "...ssssss...",
    "...SsssS....",
    "....SSSS....",
    "..YYYYYYYY..",
    ".YYyYYYYyYY.",
    ".YYyYYYYyYY.",
    ".YYsQQQsYYY.",
    ".YYyYYYYyYY.",
    ".yYYYYYYYYy.",
    "..yyyyyyyy..",
]
PAPPA_LEGS = [
    ["...zzzzzz...", "...zzz.zzz..", "...zzz.zzz..", "...zzz.zzz..", "...zzz.zzz..", "...zzz.zzz..",
     "...bbb.bbb..", "..bbbb.bbbb."],
    ["...zzzzzz...", "..zzz..zzz..", "..zzz...zzz.", ".zzz....zzz.", ".zzz....zzz.", ".zzz....zzz.",
     ".bbb....bbb.", "bbbb.....bbb"],
]
BARN_TOP = [
    "....uuuu....",
    "...uuuuuu...",
    "...ussssu...",
    "...sesses...",
    "...ussssu...",
    "....SSSS....",
    "...mmmmmm...",
    "..mmmmmmmm..",
    "..smmmmmms..",
    "...mmmmmm...",
]
BARN_LEGS = [
    ["...nn..nn...", "...nn..nn...", "...bb..bb...", "..bbb..bbb.."],
    ["...nn..nn...", "..nn....nn..", "..bb....bb..", ".bbb....bbb."],
]
for i in range(2):
    figure(f"pappa_{i}", PAPPA_TOP, PAPPA_LEGS[i])
    figure(f"barn_{i}", BARN_TOP, BARN_LEGS[i])


# Drönare (två bilder för blinkande lampa), skugga och vrak
def dronare(namn, lampa):
    im = Image.new("RGBA", (15, 7), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for (x0, y0, x1, y1) in [(2, 1, 6, 3), (12, 1, 8, 3), (2, 5, 6, 3), (12, 5, 8, 3)]:
        d.line([(x0, y0), (x1, y1)], fill=(70, 72, 76))
    for (cx, cy) in [(2, 1), (12, 1), (2, 5), (12, 5)]:
        d.line([(cx - 2, cy), (cx + 2, cy)], fill=(180, 184, 188, 200))
    d.rectangle([5, 2, 9, 4], fill=(40, 42, 46))
    d.rectangle([6, 2, 8, 2], fill=(90, 94, 100))
    d.point((7, 5), fill=(20, 20, 22))
    if lampa:
        d.point((5, 4), fill=(255, 60, 50))
        d.point((9, 4), fill=(80, 255, 90))
    im.save(os.path.join(OUT, namn + ".png"))
    anchors[namn] = [7, 4]

dronare("dronare_0", True)
dronare("dronare_1", False)
sk = Image.new("RGBA", (13, 5), (0, 0, 0, 0))
ImageDraw.Draw(sk).ellipse([0, 0, 12, 4], fill=(10, 16, 12, 110))
sk.save(os.path.join(OUT, "dronare_skugga.png"))
anchors["dronare_skugga"] = [6, 2]
vr = Image.new("RGBA", (15, 6), (0, 0, 0, 0))
vd = ImageDraw.Draw(vr)
vd.rectangle([5, 2, 9, 4], fill=(40, 42, 46))
vd.line([(1, 4), (4, 3)], fill=(70, 72, 76))
vd.line([(10, 2), (13, 0)], fill=(70, 72, 76))
vd.line([(11, 5), (14, 5)], fill=(160, 164, 168))
vd.point((3, 1), fill=(160, 164, 168))
vd.point((7, 1), fill=(255, 150, 40))
vr.save(os.path.join(OUT, "dronare_vrak.png"))
anchors["dronare_vrak"] = [7, 4]


# ============================================================= Markörer ==
def diamond_outline(name, col, thick=1):
    im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    for r in range(TH):
        w = 2 * (r + 1) if r < HY else 2 * (TH - r)
        xs = []
        for k in range(2 * thick):
            xs += [HX - w + k, HX + w - 1 - k]
        for x in xs:
            if 0 <= x < TW:
                im.putpixel((x, r), col)
    im.save(os.path.join(OUT, name + ".png"))
    anchors[name] = [HX, HY]

diamond_outline("markor_hover", (230, 235, 224, 140))
diamond_outline("markor_mal", (141, 191, 90, 255))
diamond_outline("markor_larm", (242, 177, 52, 255), thick=1)

ex = Image.new("RGBA", (5, 13), (0, 0, 0, 0))
ed = ImageDraw.Draw(ex)
ed.rectangle([0, 0, 4, 8], fill=(60, 40, 10, 255))
ed.rectangle([1, 0, 3, 7], fill=(242, 177, 52, 255))
ed.rectangle([0, 10, 4, 12], fill=(60, 40, 10, 255))
ed.rectangle([1, 10, 3, 12], fill=(242, 177, 52, 255))
ex.save(os.path.join(OUT, "utrop.png"))
anchors["utrop"] = [2, 13]

fl = Image.new("RGBA", (7, 7), (0, 0, 0, 0))
for p in [(3, 0), (3, 1), (0, 3), (1, 3), (5, 3), (6, 3), (3, 5), (3, 6), (2, 2), (4, 2), (2, 4), (4, 4)]:
    fl.putpixel(p, (255, 250, 210, 200))
for p in [(3, 2), (2, 3), (3, 3), (4, 3), (3, 4)]:
    fl.putpixel(p, (255, 255, 255, 255))
fl.save(os.path.join(OUT, "blixt.png"))
anchors["blixt"] = [3, 3]


# ============================================================== Porträtt ==
def portrait(kind):
    S = 80
    im = Image.new("RGB", (S, S), (34, 46, 58))
    p = ImageDraw.Draw(im)
    # bakgrund: skog i skymning
    for i, x in enumerate(range(-6, S, 14)):
        hgt = 26 + (i * 7) % 12
        p.polygon([(x, 62), (x + 14, 62), (x + 7, 62 - hgt)], fill=(28, 40, 44))
    p.rectangle([0, 60, S, S], fill=(26, 36, 44))
    skin, skin_d, skin_l = (224, 180, 140), (196, 150, 112), (238, 200, 162)
    if kind == "pappa":
        jacket, jacket_d, jacket_l = (62, 96, 150), (46, 72, 116), (84, 118, 172)
    elif kind == "civil":
        jacket, jacket_d, jacket_l = (176, 114, 58), (136, 86, 42), (198, 136, 74)
    else:
        jacket, jacket_d, jacket_l = M90[0], M90[2], M90[0]
    # överkropp
    p.polygon([(8, S), (14, 62), (30, 56), (50, 56), (66, 62), (72, S)], fill=jacket)
    p.polygon([(8, S), (14, 62), (30, 56), (34, S)], fill=jacket_d)
    p.line([(50, 56), (66, 62)], fill=jacket_l)
    if kind == "pappa":
        p.polygon([(30, 56), (40, 66), (50, 56)], fill=(220, 220, 210))  # krage
        p.rectangle([26, 70, 54, 79], fill=(60, 62, 66))  # handkontroll
        p.line([(30, 70), (28, 62)], fill=(140, 140, 144))
        p.line([(50, 70), (52, 62)], fill=(140, 140, 144))
        p.rectangle([36, 72, 44, 77], fill=(90, 150, 200))
        p.rectangle([22, 74, 27, 79], fill=skin_d)
        p.rectangle([53, 74, 58, 79], fill=skin_d)
    elif kind == "civil":
        p.polygon([(30, 56), (40, 68), (50, 56)], fill=(110, 70, 34))
        p.line([(40, 68), (40, S)], fill=(110, 70, 34))
        p.line([(39, 70), (39, S)], fill=(150, 150, 140))  # dragkedja
        for y in range(62, S, 6):
            p.line([(18, y), (22, y + 2)], fill=jacket_d)
        p.line([(20, 60), (32, S)], fill=(20, 20, 22), width=2)  # kamerarem
    else:
        # M/90-mönster i överkroppen
        tex = m90_texture(S, S, seed=31, scale=2.2)
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).polygon([(8, S), (14, 62), (30, 56), (50, 56), (66, 62), (72, S)], fill=255)
        im.paste(tex, (0, 0), mask)
        p.line([(30, 56), (40, 66), (50, 56)], fill=M90[3])  # krage
        # skyddsvaktsmärke på bröstet
        p.rectangle([16, 63, 28, 78], fill=(18, 18, 20))
        p.line([(18, 64), (26, 64)], fill=(232, 196, 40))
        p.line([(18, 77), (26, 77)], fill=(232, 196, 40))
        p.rectangle([19, 67, 25, 74], fill=(232, 196, 40))
        p.rectangle([20, 67, 24, 73], fill=(48, 96, 176))
        for q in [(21, 68), (23, 68), (22, 71)]:
            p.point(q, fill=(240, 204, 48))
        p.rectangle([56, 58, 62, 68], fill=(24, 24, 26))  # radio
        p.line([(60, 48), (60, 58)], fill=(24, 24, 26), width=2)
        p.point((59, 61), fill=(120, 200, 110))
        # automatkarbin diagonalt över bröstet, med bärrem
        p.line([(30, 57), (8, 76)], fill=(36, 38, 40), width=2)
        p.polygon([(6, 80), (60, 62), (63, 66), (10, 80)], fill=(18, 18, 20))
        p.line([(12, 78), (60, 63)], fill=(60, 62, 66))
        p.polygon([(30, 74), (36, 72), (38, 80), (32, 80)], fill=(18, 18, 20))  # magasin
        p.polygon([(44, 68), (48, 67), (50, 73), (46, 74)], fill=(18, 18, 20))  # pistolgrepp
        p.rectangle([60, 61, 70, 63], fill=(26, 26, 28))  # pipa
        p.rectangle([20, 70, 26, 74], fill=(196, 150, 112))  # hand
        p.rectangle([48, 64, 53, 68], fill=(196, 150, 112))  # hand
    # hals
    p.rectangle([34, 48, 46, 58], fill=skin_d)
    # huvud
    p.rectangle([24, 20, 55, 52], fill=skin)
    p.rectangle([26, 52, 53, 54], fill=skin)
    p.rectangle([24, 20, 28, 52], fill=skin_d)
    for (x, y) in [(24, 20), (55, 20), (24, 52), (55, 52), (24, 21), (55, 21)]:
        p.point((x, y), fill=(34, 46, 58))
    p.rectangle([50, 24, 53, 36], fill=skin_l)
    # öron
    p.rectangle([20, 30, 23, 39], fill=skin_d)
    p.rectangle([56, 30, 59, 39], fill=skin_d)
    p.point((21, 34), fill=(170, 124, 90))
    p.point((58, 34), fill=(170, 124, 90))
    if kind == "pappa":
        # keps
        p.rectangle([22, 10, 57, 23], fill=(78, 80, 66))
        p.rectangle([22, 10, 57, 12], fill=(96, 98, 82))
        p.rectangle([40, 21, 66, 25], fill=(64, 66, 54))
        p.line([(29, 30), (35, 29)], fill=(110, 80, 50), width=2)
        p.line([(44, 29), (50, 30)], fill=(110, 80, 50), width=2)
        brow_y = 33
    elif kind == "civil":
        # mössa (stickad)
        p.rectangle([22, 6, 57, 22], fill=(180, 58, 48))
        for y in range(8, 20, 2):
            for x in range(23, 57, 3):
                p.point((x, y), fill=(156, 46, 38))
        p.rectangle([22, 20, 57, 25], fill=(140, 42, 36))
        for x in range(23, 57, 2):
            p.point((x, 22), fill=(120, 34, 30))
        p.rectangle([36, 2, 43, 6], fill=(190, 66, 54))
        # ögonbryn (irriterad)
        p.line([(29, 29), (35, 31)], fill=(84, 58, 40), width=2)
        p.line([(44, 31), (50, 29)], fill=(84, 58, 40), width=2)
        brow_y = 33
    else:
        # hjälm med M/90-överdrag
        tex = m90_texture(S, S, seed=55, scale=2.0)
        mask = Image.new("L", (S, S), 0)
        md = ImageDraw.Draw(mask)
        md.ellipse([16, 2, 63, 40], fill=255)
        md.rectangle([0, 24, S, S], fill=0)
        md.rectangle([15, 20, 64, 27], fill=255)
        dark = tex.point(lambda v: int(v * 0.85))
        im.paste(dark, (0, 0), mask)
        p.line([(15, 27), (64, 27)], fill=(30, 34, 28))
        p.arc([16, 2, 63, 40], 200, 340, fill=(150, 160, 120))
        # gröna hörselskydd (comtacs) med mikrofon
        for x0 in (14, 57):
            p.rounded_rectangle([x0, 27, x0 + 9, 42], radius=3, fill=(64, 96, 52))
            p.rectangle([x0 + 2, 29, x0 + 3, 40], fill=(84, 118, 66))
        p.line([(22, 40), (32, 47)], fill=(24, 24, 26), width=2)
        p.rectangle([32, 46, 34, 48], fill=(24, 24, 26))
        p.line([(29, 30), (35, 30)], fill=(70, 52, 36), width=2)
        p.line([(44, 30), (50, 30)], fill=(70, 52, 36), width=2)
        brow_y = 33
    # ögon
    for ex_ in (30, 45):
        p.rectangle([ex_, brow_y, ex_ + 4, brow_y + 2], fill=(244, 242, 236))
        p.rectangle([ex_ + 2, brow_y, ex_ + 3, brow_y + 2], fill=(46, 60, 72))
        p.point((ex_ + 2, brow_y), fill=(20, 20, 24))
    p.line([(30, brow_y + 3), (34, brow_y + 3)], fill=skin_d)
    p.line([(45, brow_y + 3), (49, brow_y + 3)], fill=skin_d)
    # näsa
    p.line([(39, 34), (39, 41)], fill=skin_d)
    p.line([(37, 42), (41, 42)], fill=skin_d)
    p.point((42, 41), fill=skin_d)
    if kind == "pappa":
        for gx in (28, 43):
            p.rectangle([gx, brow_y - 2, gx + 8, brow_y + 4], outline=(28, 28, 30))
        p.line([(36, brow_y), (43, brow_y)], fill=(28, 28, 30))
    # mun
    if kind == "pappa":
        p.line([(34, 46), (45, 46)], fill=(140, 84, 70))
        p.point((33, 45), fill=(140, 84, 70))
        p.point((46, 45), fill=(140, 84, 70))
    elif kind == "civil":
        p.line([(34, 46), (45, 46)], fill=(130, 74, 62), width=1)
        p.point((33, 47), fill=(130, 74, 62))
        p.point((46, 47), fill=(130, 74, 62))
        for y in range(43, 54, 2):
            for x in range(28, 52, 3):
                if (x + y) % 4 and im.getpixel((x, y)) == skin:
                    p.point((x, y), fill=(192, 150, 116))
    else:
        p.line([(34, 46), (45, 46)], fill=(140, 84, 70))
    return im

portrait("civil").save(os.path.join(OUT, "portratt_civil.png"))
portrait("vakt").save(os.path.join(OUT, "portratt_vakt.png"))
portrait("pappa").save(os.path.join(OUT, "portratt_pappa.png"))

# ============================================================ Ikoner ==
def hogtalare(namn, extra):
    T, R = (230, 235, 224, 255), (240, 124, 140, 255)
    rader = ["......X.....", ".....XX.....", "....XXX.....", "XXXXXXX.....", "XXXXXXX.....",
             "XXXXXXX.....", "XXXXXXX.....", "....XXX.....", ".....XX.....", "......X....."]
    im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    for y, rad in enumerate(rader):
        for x, c in enumerate(rad):
            if c == "X":
                im.putpixel((x, y + 1), T)
    for (x, y, rod) in extra:
        im.putpixel((x, y), R if rod else T)
    im.save(os.path.join(OUT, namn + ".png"))

hogtalare("hogtalare_pa", [(8, 4, 0), (8, 5, 0), (8, 6, 0), (8, 7, 0), (9, 2, 0), (10, 3, 0), (10, 4, 0),
                           (10, 5, 0), (10, 6, 0), (10, 7, 0), (10, 8, 0), (9, 9, 0)])
hogtalare("hogtalare_av", [(7 + i, 3 + i, 1) for i in range(5)] + [(11 - i, 3 + i, 1) for i in range(5)])

with open(os.path.join(OUT, "anchors.json"), "w") as f:
    json.dump(anchors, f, indent=1, sort_keys=True)
print("ok", len(anchors))
