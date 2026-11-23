"""Genererar kartan för scenariot "Fotografen" och skriver in den i scenariofilen.

Användning:  python3 verktyg/generera_karta.py [storlek]   (standard 52)

Skyddsobjektet (staket, byggnad, grind) placeras som en mall nära mitten.
Runt det genereras skog, väg, stigar, stugor, en lada, en sjö, stenar och buskar.
Alla koordinater i scenariot (start, mål, skyddsområde) flyttas med.
Slumpen är låst (frö) så att samma storlek alltid ger samma karta.
"""
import json
import math
import random
import sys
from collections import OrderedDict

N = int(sys.argv[1]) if len(sys.argv) > 1 else 52
SCENARIO = "data/scenarier/fotografen.json"
rng = random.Random(2026)

# Mall: skyddsobjektet med närmaste omgivning (18x18, staket 3..12).
MALL_MARK = [
    "..................", "..................", "..................",
    "...iiiiiiiiii.....", "...iiggggggii.....", "...iiggggggii.....", "...iiggggggii.....",
    "...iiggggggii.....", "...iiggggggii.....", "...iiiiiiaaaadadad", "...iiiiiiaaaaaaaaa",
    "...iiiiiiiiii.....", "...iiiiiiiiii.....", "..................", "..................",
    "..................", "..................", "..................",
]
MALL_OBJ = [
    "..................", "..................", "..................",
    "...FFFFFSFFFF...C.", "...FL.....PLF.....", "...F..BBBB..F.....", "...F..BBBB..F.....",
    "...F..BBBB..F.....", "...F........FL....", "...F.......VG.....", "...F........G.....",
    "...F......K.FL....", "...FFFFFFFFFF.....", "..................", "..................",
    "..................", "..................", "..................",
]
# Mallens placering (övre vänstra hörnet) – staketet hamnar på OX+3..OX+12.
OX = N // 2 - 8
OY = N // 2 - 11
FENCE0, FENCE1 = (OX + 3, OY + 3), (OX + 12, OY + 12)
VAG_Y = (OY + 9, OY + 10)

mark = [["." for _ in range(N)] for _ in range(N)]
obj = [["." for _ in range(N)] for _ in range(N)]
skyddad = set()  # rutor där genereringen inte får placera något


def inne(x, y):
    return 0 <= x < N and 0 <= y < N


for y in range(18):
    for x in range(18):
        mx, my = OX + x, OY + y
        if inne(mx, my):
            mark[my][mx] = MALL_MARK[y][x]
            obj[my][mx] = MALL_OBJ[y][x]

# Fri zon runt staketet (ingen skog direkt invid objektet).
for y in range(FENCE0[1] - 3, FENCE1[1] + 4):
    for x in range(FENCE0[0] - 3, FENCE1[0] + 4):
        if inne(x, y):
            skyddad.add((x, y))
for y in range(OY, OY + 18):
    for x in range(OX, OX + 18):
        skyddad.add((x, y))


def satt_mark(x, y, t, ersatt=(".",)):
    if inne(x, y) and mark[y][x] in ersatt:
        mark[y][x] = t
        skyddad.add((x, y))


def linje(a, b, t, bredd=1):
    """Stig/väg mellan två punkter (Bresenham), med lätt slingring."""
    (x0, y0), (x1, y1) = a, b
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        for k in range(bredd):
            satt_mark(x0, y0 + k, t)
        if (x0, y0) == (x1, y1):
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


# --- Väg österut från grinden till kartkanten, med mittlinje
for x in range(OX + 18, N):
    mark[VAG_Y[0]][x] = "d" if x % 2 == 0 else "a"
    mark[VAG_Y[1]][x] = "a"
    skyddad.update({(x, VAG_Y[0]), (x, VAG_Y[1])})
# --- Väg söderut från en korsning
KX = min(N - 6, OX + 24)
for y in range(VAG_Y[1] + 1, N):
    for x in (KX, KX + 1):
        mark[y][x] = "a"
        skyddad.add((x, y))

# --- Stugor och lada längs vägen
byggnader = []  # (ankare-tecken, blockerat-tecken, x, y, bredd, djup)


def placera(ankare, block, x, y, bredd, djup):
    if not (inne(x, y) and inne(x + bredd - 1, y + djup - 1)):
        return False
    for yy in range(y - 1, y + djup + 1):
        for xx in range(x - 1, x + bredd + 1):
            if inne(xx, yy) and (obj[yy][xx] != "." or mark[yy][xx] in "adw"):
                return False
    for yy in range(y, y + djup):
        for xx in range(x, x + bredd):
            obj[yy][xx] = block
            skyddad.add((xx, yy))
    obj[y + djup - 1][x + bredd - 1] = ankare
    byggnader.append((x, y, bredd, djup))
    return True


husplatser = [("H", "h", KX + 3, VAG_Y[0] - 4, 2, 2), ("I", "i", KX + 7, VAG_Y[0] - 4, 2, 2),
              ("H", "h", KX - 6, VAG_Y[0] - 4, 2, 2), ("A", "j", KX + 3, VAG_Y[1] + 3, 3, 2),
              ("I", "i", KX - 5, VAG_Y[1] + 4, 2, 2)]
for (a, b, x, y, w, h) in husplatser:
    if placera(a, b, x, y, w, h):
        # gårdsplan och stig till vägen
        dorr = (x + w, y + h // 2)
        mal_y = VAG_Y[0] - 1 if y < VAG_Y[0] else VAG_Y[1] + 1
        linje(dorr, (x + w, mal_y), "p")
        if y < VAG_Y[0]:
            satt_mark(x + w + 1, mal_y, ".")
            if inne(x + w + 1, mal_y) and obj[mal_y][x + w + 1] == ".":
                obj[mal_y][x + w + 1] = "M"  # brevlåda

# --- Sjö i sydväst
SX, SY, RX, RY = max(8, N // 5), N - max(9, N // 5), max(5, N // 8), max(4, N // 10)
for y in range(N):
    for x in range(N):
        d = ((x - SX) / RX) ** 2 + ((y - SY) / RY) ** 2
        brus = 0.12 * math.sin(x * 1.3) * math.cos(y * 1.7)
        if d + brus < 1.0:
            mark[y][x] = "w"
            skyddad.add((x, y))

# --- Stigar: runt staketet (patrullstig), till sjön och genom skogen
f0x, f0y = FENCE0[0] - 2, FENCE0[1] - 2
f1x, f1y = FENCE1[0] + 2, FENCE1[1] + 2
linje((f0x, f0y), (f1x, f0y), "p")
linje((f0x, f0y), (f0x, f1y), "p")
linje((f0x, f1y), (f1x, f1y), "p")
linje((f1x, f0y), (f1x, VAG_Y[0] - 1), "p")
linje((f1x, VAG_Y[1] + 1), (f1x, f1y), "p")
linje((f0x, f1y), (SX + RX // 2, SY - RY - 1), "p")
linje((0, f0y + 3), (f0x, f0y + 3), "p")
linje((f0x + 4, f0y), (f0x + 1, 0), "p")

# --- Skog: täthet från slumpade skogscentra, tätare mot kanterna
centra = [(rng.uniform(0, N), rng.uniform(0, N), rng.uniform(N / 10, N / 5)) for _ in range(max(6, N // 5))]


def tathet(x, y):
    t = sum(math.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (r * r)) for cx, cy, r in centra)
    kant = min(x, y, N - 1 - x, N - 1 - y)
    return min(1.0, t * 0.55 + (0.45 if kant < 3 else 0.0))


for y in range(N):
    for x in range(N):
        if (x, y) in skyddad or obj[y][x] != "." or mark[y][x] != ".":
            continue
        t = tathet(x, y)
        r = rng.random()
        if r < t * 0.55:
            obj[y][x] = "T" if rng.random() < 0.7 else "t"
        elif r < t * 0.55 + 0.012:
            obj[y][x] = "R"
        elif r < t * 0.55 + 0.03:
            obj[y][x] = "U"

# Stenar längs sjöstranden
for y in range(N):
    for x in range(N):
        if mark[y][x] == "." and obj[y][x] == "." and rng.random() < 0.18:
            if any(inne(x + dx, y + dy) and mark[y + dy][x + dx] == "w" for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                obj[y][x] = "R"

# Mallens gamla granar utanför objektet får ligga kvar (de finns redan i obj).

# ------------------------------------------------ Skriv till scenariot --
sc = json.load(open(SCENARIO), object_pairs_hook=OrderedDict)
k = sc["karta"]
k["mark"] = ["".join(r) for r in mark]
k["objekt"] = ["".join(r) for r in obj]
k["skyddsomrade"] = [FENCE0[0], FENCE0[1], FENCE1[0], FENCE1[1]]
k["storlek"] = N
k["teckenforklaring"] = OrderedDict([
    ("mark", OrderedDict([(".", "gräs"), ("i", "gräs innanför staket"), ("g", "grus"), ("a", "asfalt"),
                          ("d", "asfalt med mittlinje"), ("p", "stig"), ("w", "vatten (går ej att gå i)")])),
    ("objekt", OrderedDict([("F", "staket"), ("S", "staket med skylt"), ("G", "grind/bom"), ("B", "byggnad"),
                            ("K", "vaktkur"), ("T", "gran"), ("t", "liten gran"), ("L", "lyktstolpe"),
                            ("C", "bil"), ("P", "spelarens start"), ("V", "stridsparskamrat"),
                            ("H", "röd stuga (ankare)"), ("h", "röd stuga"), ("I", "gul stuga (ankare)"),
                            ("i", "gul stuga"), ("A", "lada (ankare)"), ("j", "lada"), ("R", "sten"),
                            ("U", "buske"), ("M", "brevlåda")])),
])
DX, DY = OX, OY  # mallens koordinater -> kartans
sc["npc"]["fotografen"]["start"] = [15 + DX, 4 + DY]
sc["handelser"][0]["mal"] = [9 + DX, 1 + DY]
json.dump(sc, open(SCENARIO, "w"), ensure_ascii=False, indent=2)
print(f"karta {N}x{N}, skyddsobjekt {FENCE0}-{FENCE1}, byggnader {len(byggnader)}")
