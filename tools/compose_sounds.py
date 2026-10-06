"""Makes SANGA's sound effects and writes them to assets/sounds/*.wav.

There are only two, and both are quiet so they sit under the piano:

    click   a soft felt tap, for every button
    strike  a pencil stroke across paper with a faint chime, for a finished objective

Like the music, they are synthesised here, so there is nothing to license.

    python tools/compose_sounds.py

Needs numpy and scipy. The same seed gives the same sounds every time.
"""

from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 22050
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def band(signal, low, high):
    sos = butter(2, [low, high], btype="band", fs=SR, output="sos")
    return sosfilt(sos, signal)


def lowpass(signal, cutoff):
    sos = butter(2, cutoff, btype="low", fs=SR, output="sos")
    return sosfilt(sos, signal)


def times(seconds):
    return np.arange(int(seconds * SR)) / SR


def normalise(signal, peak_db):
    return signal / np.max(np.abs(signal)) * 10 ** (peak_db / 20)


def click():
    """A short, rounded tap, like a felt hammer on wood."""
    rng = np.random.default_rng(1)
    t = times(0.09)
    body = np.sin(2 * np.pi * (520 + 380 * np.exp(-t * 90)) * t) * np.exp(-t * 70)
    knock = band(rng.normal(0, 1, len(t)), 900, 3200) * np.exp(-t * 420) * 0.5
    tap = lowpass(body + knock, 3000)
    tap[: int(0.001 * SR)] *= np.linspace(0, 1, int(0.001 * SR))
    return normalise(tap, -10)


def strike():
    """A pencil drawn across paper as the line goes through, then a faint, high chime."""
    rng = np.random.default_rng(2)
    stroke_seconds = 0.35
    t = times(0.9)
    grain = rng.normal(0, 1, len(t)) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 37 * t)))
    paper = band(grain, 1800, 6500)
    shape = np.clip(t / 0.04, 0, 1) * np.clip((stroke_seconds - t) / 0.12, 0, 1)
    pencil = paper * shape * 0.55
    chime = np.zeros_like(t)
    start = int(stroke_seconds * 0.85 * SR)
    ct = t[: len(t) - start]
    for ratio, amp, decay in ((1.0, 1.0, 6.0), (2.0, 0.3, 9.0), (3.01, 0.08, 14.0)):
        chime[start:] += amp * np.sin(2 * np.pi * 1318.5 * ratio * ct) * np.exp(-decay * ct)
    sound = pencil + chime * 0.22
    sound[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))
    return normalise(sound, -12)


SOUNDS = {"click": click, "strike": strike}


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        audio = make()
        path = OUT_DIR / f"{name}.wav"
        wavfile.write(path, SR, (audio * 32767).astype(np.int16))
        print(f"{path.name}: {len(audio) / SR:.2f} s")


if __name__ == "__main__":
    main()
