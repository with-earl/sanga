"""Makes SANGA's sound effects and writes them to assets/sounds/*.wav.

A few, and all are quiet so they sit under the piano:

    click        a soft felt tap, for every button
    strike       a pencil stroke across paper with a faint chime, for a finished objective
    memory       a breath drawn in, then three soft bells, when a choice only a memory allows is taken
    engine_ride  a small motorbike engine at cruising speed with wind, made to loop (Tokhang's first intro frame)
    engine_off   the key turned and the engine dying down to a few last beats and a tick (Tokhang's third intro frame)

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


def memory():
    """A breath drawn in (soft noise swelling), then three bells rising, ringing on together, like
    something remembered."""
    rng = np.random.default_rng(3)
    t = times(2.6)
    swell = band(rng.normal(0, 1, len(t)), 600, 4000) * np.clip(t / 0.45, 0, 1) ** 2 * np.clip((0.55 - t) / 0.1, 0, 1)
    bells = np.zeros_like(t)
    for start, freq in ((0.5, 659.25), (0.62, 830.61), (0.74, 987.77)):
        s = int(start * SR)
        bt = t[: len(t) - s]
        for ratio, amp, decay in ((1.0, 1.0, 1.6), (2.0, 0.25, 3.0), (2.76, 0.1, 5.0)):
            bells[s:] += amp * np.sin(2 * np.pi * freq * ratio * bt) * np.exp(-decay * bt) * np.clip(bt / 0.004, 0, 1)
    shimmer = 1 + 0.06 * np.sin(2 * np.pi * 5.5 * t)
    sound = lowpass(swell * 0.25 + bells * 0.5 * shimmer, 5000)
    sound[-int(0.2 * SR):] *= np.linspace(1, 0, int(0.2 * SR))
    return normalise(sound, -11)


def _pulse(length_seconds, pitch, decay):
    """One exhaust beat of a single-cylinder engine: a low thump that rings down, with a puff of noise on it."""
    rng = np.random.default_rng(int(pitch * 10))
    t = times(length_seconds)
    thump = np.sin(2 * np.pi * pitch * (1.0 + 0.5 * np.exp(-t * 40)) * t) * np.exp(-t * decay)
    puff = band(rng.normal(0, 1, len(t)), 140, 900) * np.exp(-t * decay * 1.6) * 0.55
    return thump + puff


def _engine(total_seconds, rate_of, amp_of=None, wind=0.0, seed=7):
    """An engine as a train of beats whose rate follows `rate_of(t)` beats a second and loudness `amp_of(t)`;
    the beats are a little uneven, as a real single is. A muffler (low pass), a quiet mechanical tick and
    some wind sit on top."""
    rng = np.random.default_rng(seed)
    n = int(total_seconds * SR)
    out = np.zeros(n + int(0.3 * SR))
    tick_track = np.zeros_like(out)
    t = 0.0
    while t < total_seconds:
        rate = max(rate_of(t), 0.5)
        pitch = 70.0 + 2.2 * rate
        length = min(0.16, 0.9 / rate)
        beat = _pulse(length, pitch, 38.0) * (amp_of(t) if amp_of else 1.0) * (0.85 + 0.3 * rng.random())
        i = int(t * SR)
        out[i : i + len(beat)] += beat[: len(out) - i]
        if rate > 6.0:
            tick = band(rng.normal(0, 1, 120), 1800, 4800) * np.exp(-np.arange(120) / SR * 900) * 0.05
            tick_track[i : i + 120] += tick[: len(tick_track) - i]
        t += (1.0 / rate) * (0.94 + 0.12 * rng.random())
    sound = lowpass(out + tick_track, 1400)
    if wind > 0.0:
        noise = band(rng.normal(0, 1, len(out)), 160, 1700)
        gust = 0.7 + 0.3 * np.sin(2 * np.pi * 0.35 * np.arange(len(out)) / SR)
        sound = sound + noise * gust * wind
    return sound[:n], sound[n:]


def engine_ride():
    """A small bike at cruising speed (about 3,600 rpm: thirty beats a second) with a slow swell as the rider
    rolls the throttle, wind in the ear, and a seamless loop: the ring of the last beats is laid over the start."""
    seconds = 4.0
    body, tail = _engine(seconds, lambda t: 30.0 * (1.0 + 0.045 * np.sin(2 * np.pi * t / seconds)), wind=0.045)
    # The last beats ring on past the end, so they are added over the start, as a loop's end runs into its beginning.
    body[: len(tail)] += tail
    return normalise(body, -6)


def engine_off():
    """The key is turned: a small click, then the engine stumbles down, beats slowing and weakening (from
    about thirty a second to three), a last rattle of the stand, and a faint tick of the hot metal cooling."""
    seconds = 2.2
    rng = np.random.default_rng(11)
    body, tail = _engine(seconds, lambda t: 30.0 * np.exp(-t * 2.5) + 2.5 * np.exp(-t * 0.6) * (1.0 if t < 1.5 else 0.0) + 1.0,
                         amp_of=lambda t: float(np.exp(-t * 1.5)), wind=0.0, seed=13)
    out = np.concatenate([body, tail[: int(0.2 * SR)]])
    key = np.sin(2 * np.pi * 1700 * times(0.03)) * np.exp(-times(0.03) * 260) * 0.5 + band(rng.normal(0, 1, int(0.03 * SR)), 2200, 5200) * np.exp(-times(0.03) * 300) * 0.4
    out[: len(key)] += key
    # The hot metal cooling: three faint ticks, a little apart.
    for at in (1.55, 1.82, 2.05):
        i = int(at * SR)
        tick = band(rng.normal(0, 1, 150), 2400, 5600) * np.exp(-np.arange(150) / SR * 700) * 0.12
        out[i : i + len(tick)] += tick[: len(out) - i]
    out[-int(0.05 * SR) :] *= np.linspace(1.0, 0.0, int(0.05 * SR))
    return normalise(out, -8)


SOUNDS = {"click": click, "strike": strike, "memory": memory, "engine_ride": engine_ride, "engine_off": engine_off}


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        audio = make()
        path = OUT_DIR / f"{name}.wav"
        wavfile.write(path, SR, (audio * 32767).astype(np.int16))
        print(f"{path.name}: {len(audio) / SR:.2f} s")


if __name__ == "__main__":
    main()
