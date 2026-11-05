#!/usr/bin/env python3
"""Kimmy's voice: a few soft synthesized sounds, written as WAV next to this file.

Run `python3 make_sounds.py` to rebuild them (standard library only). Each one is a
short, quiet blip of sine tones with an envelope, so nothing clicks and nothing startles.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
HERE = Path(__file__).parent


def tone(dur, f0, f1=None, vol=0.3, attack=0.01, wobble=0.0, wobble_hz=0.0, curve=1.0):
    """A sine that glides f0 → f1 with a soft attack and an exponential-ish release."""
    f1 = f0 if f1 is None else f1
    n = int(dur * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * (t ** curve)
        if wobble:
            f += math.sin(2 * math.pi * wobble_hz * i / RATE) * wobble
        phase += 2 * math.pi * f / RATE
        env = min(1.0, i / max(1, attack * RATE)) * (1 - t) ** 1.6
        out.append(math.sin(phase) * env * vol)
    return out


def silence(dur):
    return [0.0] * int(dur * RATE)


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def save(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.8 / peak)
    with wave.open(str(HERE / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))


def purr():
    # a low hum whose loudness flutters at ~24 Hz, with a little breathiness
    random.seed(7)
    n = int(0.9 * RATE)
    out = []
    for i in range(n):
        t = i / n
        flutter = 0.55 + 0.45 * math.sin(2 * math.pi * 24 * i / RATE)
        env = min(1.0, t / 0.15) * min(1.0, (1 - t) / 0.3)
        v = math.sin(2 * math.pi * 62 * i / RATE) * 0.6 + math.sin(2 * math.pi * 124 * i / RATE) * 0.25
        v += (random.random() - 0.5) * 0.08
        out.append(v * flutter * env * 0.35)
    return out


save("pip", tone(0.11, 880, 1320, 0.3))
save("boop", tone(0.12, 420, 280, 0.35))
save("thud", mix(tone(0.16, 130, 55, 0.5, attack=0.004), tone(0.05, 600, 300, 0.1, attack=0.002)))
save("whee", tone(0.34, 500, 1250, 0.28, attack=0.03, curve=1.4))
save("hello", tone(0.09, 660, 660, 0.28) + silence(0.03) + tone(0.14, 880, 990, 0.28))
save("sad", tone(0.4, 520, 330, 0.26, attack=0.03, wobble=8, wobble_hz=6))
save("yawn", tone(0.8, 330, 190, 0.2, attack=0.2, wobble=4, wobble_hz=4))
save("purr", purr())
# its chatter: four little syllables that make up a babble when it speaks
save("chirp1", tone(0.07, 700, 900, 0.22) + tone(0.06, 900, 760, 0.2))
save("chirp2", tone(0.09, 560, 840, 0.22, curve=0.7))
save("chirp3", tone(0.05, 980, 980, 0.2) + silence(0.02) + tone(0.07, 760, 1040, 0.2))
save("chirp4", tone(0.11, 820, 600, 0.2, wobble=20, wobble_hz=18))
