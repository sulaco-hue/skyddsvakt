"""Syntetiserar "Grindpostens marsch" – en egen, nyskriven marsch i C64/SID-stil.

Användning:  python3 generera_marsch.py <utfil.wav>

Tre röster som på SID-kretsen plus brus:
  1. Melodi: pulsvåg (25 %) med fördröjt vibrato
  2. Ackord: snabba arpeggion (typiskt C64) på "pah"-slagen, pulsbreddsmodulerad
  3. Bas: triangelvåg i "um-pa"
  + Trummor: brusvirvel och syntetisk bastrumma
"""
import sys
import wave

import numpy as np

SR = 44100
BPM = 116
ATTONDEL = 60.0 / BPM / 2  # sekunder per åttondel (2/4-takt)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# ------------------------------------------------------------- Noter --
# (midi eller None för paus, längd i åttondelar). Tonart Bb-dur.
INTRO = [(65, 1), (65, 1), (70, 1), (74, 1), (77, 2), (74, 1), (70, 1),
         (72, 1), (75, 1), (79, 1), (75, 1), (77, 4)]
A = [(70, 2), (74, 1), (77, 1), (79, 2), (77, 1), (75, 1),
     (74, 1), (72, 1), (70, 1), (74, 1), (72, 4),
     (72, 2), (75, 1), (79, 1), (81, 2), (79, 1), (77, 1),
     (75, 1), (74, 1), (72, 1), (69, 1), (70, 4)]
B = [(74, 1), (74, 1), (75, 1), (77, 1), (79, 3), (75, 1),
     (77, 1), (77, 1), (79, 1), (81, 1), (82, 3), (77, 1),
     (79, 1), (77, 1), (75, 1), (74, 1), (72, 2), (77, 2),
     (74, 1), (70, 1), (72, 1), (69, 1), (70, 2), (None, 2)]

# Ackord per takt: (grundton som midi i basläge, typ)
DUR, MOLL, DOM7 = [0, 4, 7], [0, 3, 7], [0, 4, 7, 10]
Bb, Eb, F, Cm = (46, DUR), (51, DUR), (41, DUR), (48, MOLL)
F7 = (41, DOM7)
ACK_INTRO = [Bb, Bb, Cm, F]
ACK_A = [Bb, Eb, Bb, F, Cm, F, F7, Bb]
ACK_B = [Bb, Eb, F, Bb, Eb, F, F7, Bb]

DELAR = [(INTRO, ACK_INTRO, "intro"), (A, ACK_A, "a"), (A, ACK_A, "a2"), (B, ACK_B, "b"), (A, ACK_A, "slut")]


# ------------------------------------------------------------ Vågor --
def puls(f, t, bredd):
    fas = (f * t) % 1.0
    return np.where(fas < bredd, 1.0, -1.0)


def triangel(f, t):
    fas = (f * t) % 1.0
    return 4 * np.abs(fas - 0.5) - 1


def envelope(n, a=0.004, d=0.08, s=0.6, r=0.03, hall=None):
    hall = n if hall is None else hall
    t = np.arange(n) / SR
    env = np.ones(n) * s
    na, nd = int(a * SR), int(d * SR)
    env[:na] = np.linspace(0, 1, na, endpoint=False) if na else env[:na]
    env[na:na + nd] = np.linspace(1, s, len(env[na:na + nd]))
    nr = int(r * SR)
    if hall < n:
        env[hall:] = 0
    if nr and hall > nr:
        env[hall - nr:hall] *= np.linspace(1, 0, nr)
    return env


total_attondelar = sum(sum(l for _, l in m) for m, _, _ in DELAR)
N = int(total_attondelar * ATTONDEL * SR) + SR
mix = np.zeros(N)
rng = np.random.default_rng(64)


def lagg(signal, start):
    s = int(start * SR)
    e = min(N, s + len(signal))
    mix[s:e] += signal[:e - s]


tid = 0.0
for melodi, ackord, namn in DELAR:
    # --- melodi
    t0 = tid
    for midi, langd in melodi:
        dur = langd * ATTONDEL
        if midi is not None:
            oktav = 12 if namn == "a2" else 0  # andra A-delen en oktav upp
            n = int(dur * SR)
            t = np.arange(n) / SR
            vib = 1 + 0.006 * np.sin(2 * np.pi * 6 * t) * np.clip((t - 0.12) * 6, 0, 1)
            fas = np.cumsum(hz(midi + oktav) * vib) / SR
            v = np.where(fas % 1.0 < 0.25, 1.0, -1.0)
            lagg(v * envelope(n, d=0.1, s=0.7, hall=int(n * 0.92)) * 0.20, t0)
        t0 += dur
    # --- ackord, bas och trummor per takt
    for takt, (rot, typ) in enumerate(ackord):
        ts = tid + takt * 4 * ATTONDEL
        for slag in range(4):
            st = ts + slag * ATTONDEL
            n = int(ATTONDEL * SR)
            t = np.arange(n) / SR
            if slag in (0, 2):  # "um": bas
                bas = rot if slag == 0 else rot + 7 - 12 * (rot + 7 > 52)
                lagg(triangel(hz(bas), t) * envelope(n, d=0.15, s=0.5, hall=int(n * 0.85)) * 0.32, st)
                # bastrumma
                kn = int(0.12 * SR)
                kt = np.arange(kn) / SR
                kf = 110 * np.exp(-kt * 30) + 45
                kick = np.sin(2 * np.pi * np.cumsum(kf) / SR) * np.exp(-kt * 22)
                lagg(kick * (0.30 if slag == 0 else 0.20), st)
            else:  # "pa": arpeggioackord
                ton = [rot + 24 + i for i in typ]
                steg = int(SR / 50)  # 50 Hz som på C64
                idx = (np.arange(n) // steg) % len(ton)
                fr = np.array([hz(x) for x in ton])[idx]
                fas = np.cumsum(fr) / SR
                bredd = 0.3 + 0.15 * np.sin(2 * np.pi * 0.5 * (st + t))
                v = np.where(fas % 1.0 < bredd, 1.0, -1.0)
                lagg(v * envelope(n, d=0.05, s=0.5, hall=int(n * 0.6)) * 0.09, st)
                # virvel på "pa"
                sn = int(0.09 * SR)
                brus = rng.uniform(-1, 1, sn)
                lagg(brus * np.exp(-np.arange(sn) / SR * 38) * 0.10, st)
        # virvelslinga i sista takten av varje del
        if takt == len(ackord) - 1 and namn != "slut":
            for k in range(8):
                st = ts + k * ATTONDEL / 2
                sn = int(0.06 * SR)
                brus = rng.uniform(-1, 1, sn)
                lagg(brus * np.exp(-np.arange(sn) / SR * 45) * (0.06 + 0.012 * k), st)
    tid += sum(l for _, l in melodi) * ATTONDEL

mix = mix[:int(tid * SR)]
# mjuk lågpass (SID-filter-känsla) och normalisering
kern = np.ones(3) / 3
mix = np.convolve(mix, kern, mode="same")
mix = mix / np.max(np.abs(mix)) * 0.85
pcm = (mix * 32767).astype(np.int16)
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print(f"ok {tid:.1f} s")
