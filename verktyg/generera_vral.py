"""Syntetiserar yxmannens vrål: obegriplig, arg "gibberish" i C64/SID-stil.

    python3 verktyg/generera_vral.py      ->  assets/ljud/vral_0..3.ogg

Varje vrål är 3–6 "stavelser". En stavelse är en pulsvåg (som SID-kretsen)
med fallande tonhöjd, snabbt vibrato och en enkel formant (vokalfärg) som
skiftar mellan stavelserna, plus lite brus i början (konsonant). Allt
kvantiseras grovt för den knastriga 8-bitarskänslan.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 22050
UT = os.path.join(os.path.dirname(__file__), "..", "assets", "ljud")


def puls(f, t, bredd):
    fas = np.cumsum(f) / SR
    return np.where((fas % 1.0) < bredd, 1.0, -1.0)


def stavelse(rng, langd, grundton, vokal):
    n = int(SR * langd)
    t = np.arange(n) / SR
    # Tonhöjd: hugg uppåt, sedan fall (argt), med snabbt vibrato
    glid = grundton * (1.35 - 0.55 * (t / langd)) * (1 + 0.06 * np.sin(2 * np.pi * 9 * t))
    bredd = 0.2 + 0.25 * (0.5 + 0.5 * np.sin(2 * np.pi * 3 * t + rng.uniform(0, 6)))  # PWM
    s = puls(glid, t, bredd)
    # Grov "formant": ringmodulera med en vokalfrekvens ger röstlik färg
    s = 0.65 * s + 0.35 * s * np.sin(2 * np.pi * vokal * t)
    # Konsonant: kort brusstöt i början
    k = int(SR * rng.uniform(0.015, 0.05))
    s[:k] += rng.uniform(-1, 1, k) * np.linspace(1, 0, k)
    # Kuvert: snabb attack, lite sustain, avklingning
    kuv = np.minimum(1, t / 0.012) * np.clip(1.15 - t / langd, 0, 1)
    return s * kuv


def vral(seed):
    rng = np.random.default_rng(seed)
    delar = []
    grund = rng.uniform(95, 130)
    for i in range(rng.integers(3, 7)):
        langd = rng.uniform(0.09, 0.2) if i < 5 else rng.uniform(0.35, 0.55)
        vokal = rng.choice([320, 450, 620, 780, 900])
        delar.append(stavelse(rng, langd, grund * rng.uniform(0.85, 1.25), vokal))
        delar.append(np.zeros(int(SR * rng.uniform(0.01, 0.04))))
    # Sista stavelsen: långt "VRÅÅÅL" som faller
    delar.append(stavelse(rng, rng.uniform(0.45, 0.65), grund * 1.3, 520))
    s = np.concatenate(delar)
    s = np.tanh(2.2 * s)  # lite distorsion
    s = np.round(s * 15) / 15  # 4-bitars kvantisering, knastrigt
    return (s / np.max(np.abs(s)) * 0.8 * 32767).astype(np.int16)


os.makedirs(UT, exist_ok=True)
for i in range(4):
    data = vral(2026 + i)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        wav = f.name
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    ut = os.path.join(UT, f"vral_{i}.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ut], check=True)
    os.remove(wav)
    print(ut, round(len(data) / SR, 2), "s")
