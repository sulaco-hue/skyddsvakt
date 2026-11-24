"""Bilder för webben: delningsbild (förhandsbild när någon länkar till spelet,
1200x630) och startbild (visas medan spelet laddar i stället för Godots logga).

    python3 verktyg/generera_delningsbild.py
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageEnhance

ROT = os.path.join(os.path.dirname(__file__), "..")
GFX = os.path.join(ROT, "assets", "gfx")
BG = (18, 24, 34)

logga = Image.open(os.path.join(GFX, "logga.png")).convert("RGBA")
karta = Image.open(os.path.join(GFX, "objektskarta_lastbil.png")).convert("RGBA")


def bild(w, h, med_karta=True, text=True):
    bakgrund = tuple(int(v * 0.45) for v in karta.getpixel((4, 4))[:3]) if med_karta else BG
    im = Image.new("RGBA", (w, h), bakgrund + (255,))
    if med_karta:
        k = karta.resize((int(karta.width * w / 960 * 1.05), int(karta.height * w / 960 * 1.05)), Image.NEAREST)
        k = ImageEnhance.Brightness(k).enhance(0.45)
        im.alpha_composite(k, ((w - k.width) // 2, (h - k.height) // 2 + h // 10))
    skala = max(1, int(w * 0.62 / logga.width))
    l = logga.resize((logga.width * skala, logga.height * skala), Image.NEAREST)
    im.alpha_composite(l, ((w - l.width) // 2, int(h * 0.18)))
    if text:
        d = ImageDraw.Draw(im)
        f = ImageFont.truetype(os.path.join(ROT, "assets", "fonts", "VT323-Regular.ttf"), int(h * 0.075))
        t = "Spela i webbläsaren"
        tw = d.textlength(t, font=f)
        d.text(((w - tw) / 2, int(h * 0.78)), t, font=f, fill=(242, 176, 52))
    return im.convert("RGB")


bild(1200, 630).save(os.path.join(ROT, "webb", "delningsbild.png"))
bild(1280, 720, med_karta=False, text=False).save(os.path.join(GFX, "startbild.png"))
print("webb/delningsbild.png, assets/gfx/startbild.png")
