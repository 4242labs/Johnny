#!/usr/bin/env python3
"""Generate johnny's `hey` attention sounds — short, distinct, self-contained WAVs
that play on macOS (afplay) and Linux (paplay/aplay). Pure stdlib, no deps.

Run from anywhere:  python3 generate.py   (writes the .wav files next to this script)
Regenerate whenever you want to tweak the palette; commit the resulting .wav files.
"""
import math, os, struct, wave

SR = 44100  # sample rate


def _write(name, samples):
    """samples: list of floats in [-1, 1]."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
        w.writeframes(frames)
    return path


def _tone(freq, dur, vol=0.6, attack=0.005, release=0.06, harmonics=(1.0,)):
    """One shaped note. harmonics = relative amplitudes of freq, 2*freq, 3*freq ..."""
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        # click-free envelope: quick attack, exponential-ish release
        if t < attack:
            env = t / attack
        else:
            env = math.exp(-(t - attack) / release)
        s = sum(h * math.sin(2 * math.pi * freq * k * t) for k, h in enumerate(harmonics, start=1))
        out.append(vol * env * s / max(1.0, sum(harmonics)))
    return out


def _silence(dur):
    return [0.0] * int(SR * dur)


def _mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, s in enumerate(l):
            out[i] += s
    return out


# 1) ping — one clean, bright sine blip. The minimal "over to you."
def ping():
    return _tone(880, 0.18, vol=0.7, release=0.09, harmonics=(1.0, 0.15))


# 2) chirp — two-note rising pip. Friendly "ready."
def chirp():
    return _tone(660, 0.10, vol=0.6, release=0.05) + _silence(0.01) + \
        _tone(990, 0.14, vol=0.6, release=0.07)


# 3) knock — two soft low woodblock thumps. Discreet "knock knock."
def knock():
    def thock():
        return _tone(196, 0.09, vol=0.85, attack=0.001, release=0.025, harmonics=(1.0, 0.4, 0.2))
    return thock() + _silence(0.08) + thock()


# 4) coin — a jaunty pop-culture pickup blip (short low grace note into a held high one).
def coin():
    return _tone(988, 0.06, vol=0.55, release=0.04) + \
        _tone(1319, 0.26, vol=0.6, release=0.12, harmonics=(1.0, 0.25))


if __name__ == "__main__":
    for name, fn in (("ping", ping), ("chirp", chirp), ("knock", knock), ("coin", coin)):
        p = _write(name, fn())
        print("wrote", os.path.basename(p))
