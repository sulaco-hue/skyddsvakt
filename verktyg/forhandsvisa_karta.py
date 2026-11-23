"""Förhandsvisning av spelvärlden utanför Godot.

Bygger kartan ur scenariofilen med samma regler som scripts/varld/varld.gd
(ankarpunkter, staketlogik, y-sortering) och sparar en bild. Används för att
kontrollera kartan och för objektskartan i briefingen.
"""
import json
import sys
from PIL import Image

ROOT = sys.argv[1]
OUT = sys.argv[2]
SCALE = int(sys.argv[3]) if len(sys.argv) > 3 else 1
UTBREDD = int(sys.argv[4]) if len(sys.argv) > 4 else 0  # skala ner till denna bredd (t.ex. briefingkartan)
OBJEKTTYP = sys.argv[5] if len(sys.argv) > 5 else "byggnad"
GFX = ROOT + "/assets/gfx/"
karta = json.load(open(ROOT + "/data/kartor/granasen.json"))
anchors = json.load(open(GFX + "anchors.json"))
mark = karta["mark"]
obj = karta["objekt"]
W, H = len(mark[0]), len(mark)

TW, TH = 32, 16
PW = (W + H) * TW // 2 + 2 * TW
PH = (W + H) * TH // 2 + 110
ORG = (PW // 2 + (H - W) * TW // 4, 70)


def center(x, y):
    return (ORG[0] + (x - y) * (TW // 2), ORG[1] + (x + y) * (TH // 2) + TH // 2)


img = Image.new("RGBA", (PW, PH), (18, 24, 34, 255))
from PIL import ImageDraw
d = ImageDraw.Draw(img)
# platta
v = center(0, H - 1); v = (v[0] - TW // 2, v[1])
n = center(W - 1, H - 1); n = (n[0], n[1] + TH // 2)
h = center(W - 1, 0); h = (h[0] + TW // 2, h[1])
d.polygon([v, n, (n[0], n[1] + 14), (v[0], v[1] + 14)], fill=(70, 52, 38))
d.polygon([n, h, (h[0], h[1] + 14), (n[0], n[1] + 14)], fill=(52, 38, 28))

atlas = Image.open(GFX + "rutor.png").convert("RGBA")
MR = {".": [0, 1], "i": [2, 3], "g": [4, 5], "a": [6, 6], "d": [7, 7], "p": [8, 9], "w": [10, 11]}
SPRITES = {"K": "vaktkur", "T": "gran", "t": "gran_liten", "C": "bil", "H": "hus_rod", "I": "hus_gul",
           "A": "lada", "R": "sten", "U": "buske", "M": "brevlada", "Q": "lastbil"}
for y in range(H):
    for x in range(W):
        idx = MR.get(mark[y][x], [0, 1])[(x + y) % 2]
        t = atlas.crop((idx * TW, 0, idx * TW + TW, TH))
        cx, cy = center(x, y)
        img.alpha_composite(t, (cx - TW // 2, cy - TH // 2))

items = []  # (y, ordning, namn, cell)
order = 0


def add(name, c):
    global order
    items.append((center(*c)[1], order, name, c))
    order += 1


decals = []
staket, skyltar, bygg = {}, [], []
start = {}
for y in range(H):
    for x in range(W):
        ch = obj[y][x]
        c = (x, y)
        if ch in "FS":
            staket[c] = "F"
            if ch == "S":
                skyltar.append(c)
        elif ch == "G":
            staket[c] = "G"
        elif ch == "B":
            bygg.append(c)
        elif ch == "L":
            add("lykta", c)
            decals.append(("ljus", c))
        elif ch in SPRITES:
            add(SPRITES[ch], c)
        elif ch in "PV":
            start[ch] = c
DIRS = [((1, 0), "xp"), ((-1, 0), "xn"), ((0, 1), "yp"), ((0, -1), "yn")]
for c, typ in staket.items():
    if typ == "F":
        add("staket_stolpe", c)
    for (dx, dy), s in DIRS:
        nb = (c[0] + dx, c[1] + dy)
        if nb in staket:
            add(("bom_" if typ == "G" else "staket_") + s, c)
for c in skyltar:
    add("skylt", c)
if bygg:
    a = bygg[0]
    mx, my = min(c[0] for c in bygg), min(c[1] for c in bygg)
    for c in bygg:
        if c[0] + c[1] > a[0] + a[1] or (c[0] + c[1] == a[0] + a[1] and c[0] > a[0]):
            a = c
    if OBJEKTTYP == "lastbil":
        add("lastbil", (mx + 3, my + 1))
    elif OBJEKTTYP == "radiomast":
        add("radiomast", (mx + 1, my + 1))
        add("teknikbod", (mx + 3, my + 2))
    else:
        add("vapenforrad" if OBJEKTTYP == "vapenforrad" else "byggnad", a)
add("vakt_0", start["P"])
add("vakt_0", start["V"])
add("civil_0", tuple(karta["punkter"]["fotograf_mal"]))


def blit(name, c):
    im = Image.open(GFX + name + ".png").convert("RGBA")
    ax, ay = anchors[name]
    cx, cy = center(*c)
    img.alpha_composite(im, (cx - ax, cy - ay))


glow = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
for name, c in decals:
    im = Image.open(GFX + name + ".png").convert("RGBA")
    ax, ay = anchors[name]
    cx, cy = center(*c)
    glow.alpha_composite(im, (cx - ax, cy - ay))
for _, _, name, c in sorted(items):
    blit(name, c)
# skymning (CanvasModulate) + additivt ljus
px = img.load()
for yy in range(PH):
    for xx in range(PW):
        r, g, b, a = px[xx, yy]
        px[xx, yy] = (int(r * 0.80), int(g * 0.84), int(b * 0.97), a)
gp = glow.load()
for yy in range(PH):
    for xx in range(PW):
        r, g, b, a = gp[xx, yy]
        if a:
            R, G, B, A = px[xx, yy]
            f = a / 255
            px[xx, yy] = (min(255, int(R + r * f)), min(255, int(G + g * f)), min(255, int(B + b * f)), A)
img = img.convert("RGB")
if UTBREDD:
    img = img.resize((UTBREDD, round(img.height * UTBREDD / img.width)), Image.LANCZOS)
elif SCALE > 1:
    img = img.resize((PW * SCALE, PH * SCALE), Image.NEAREST)
img.save(OUT)
print("ok")
