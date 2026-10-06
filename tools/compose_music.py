"""Composes SANGA's background music and writes it to assets/music/*.wav.

Every track is original and made here from plain synthesis (no samples, no outside recordings),
so there is nothing to license. Each one is a seamless loop: notes and reverb that run past the
end wrap around to the start, so the loop point cannot be heard.

    python tools/compose_music.py            # all tracks
    python tools/compose_music.py market     # one track, by name

Needs numpy and scipy. The same seed gives the same music every time.
"""

import sys
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, lfilter, sosfilt

SR = 22050
# Every track is set to this loudness, so changing scenes never jumps in volume.
TARGET_RMS = -18.0
PEAK_LIMIT = 0.89
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "music"
NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(note):
    """'A4' -> 440.0, 'C#5', 'Bb3', or a MIDI number."""
    if isinstance(note, (int, float)):
        midi = note
    else:
        name, rest = note[0], note[1:]
        shift = 0
        while rest and rest[0] in "#b":
            shift += 1 if rest[0] == "#" else -1
            rest = rest[1:]
        midi = 12 * (int(rest) + 1) + NOTE_NAMES[name] + shift
    return 440.0 * 2 ** ((midi - 69) / 12)


def lowpass(signal, cutoff, order=2):
    sos = butter(order, min(cutoff, SR * 0.45), btype="low", fs=SR, output="sos")
    return sosfilt(sos, signal)


def highpass(signal, cutoff, order=2):
    sos = butter(order, cutoff, btype="high", fs=SR, output="sos")
    return sosfilt(sos, signal)


def times(seconds):
    return np.arange(int(seconds * SR)) / SR


def fade(signal, attack, release):
    """Linear fade in over `attack` seconds and out over `release` seconds."""
    n = len(signal)
    env = np.ones(n)
    a, r = min(int(attack * SR), n), min(int(release * SR), n)
    if a:
        env[:a] = np.linspace(0, 1, a)
    if r:
        env[n - r:] *= np.linspace(1, 0, r)
    return signal * env


# Instruments. Each returns a mono signal that may ring on past `dur`.

def music_box(f, dur, vel=1.0, detune_cents=0.0):
    f *= 2 ** (detune_cents / 1200)
    t = times(dur + 2.2)
    out = np.zeros_like(t)
    for ratio, amp, decay in ((1, 1.0, 1.6), (2, 0.32, 2.6), (3.0, 0.1, 3.5), (4.17, 0.08, 5.0), (5.43, 0.03, 7.0)):
        if f * ratio < SR / 2:
            out += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-decay * t)
    return fade(out, 0.002, 0.05) * vel


def piano(f, dur, vel=1.0, detune_cents=0.0):
    f *= 2 ** (detune_cents / 1200)
    t = times(dur + 1.6)
    out = np.zeros_like(t)
    for k in range(1, 9):
        fk = k * f * np.sqrt(1 + 0.0004 * k * k)
        if fk >= SR / 2:
            break
        amp = 1.0 / k ** 1.4
        for spread in (-0.6, 0.6):
            out += 0.5 * amp * np.sin(2 * np.pi * (fk + spread) * t) * np.exp(-(0.7 + 0.45 * k) * t)
    held = np.ones_like(t)
    end = int(dur * SR)
    held[end:] = np.exp(-np.arange(len(t) - end) / (0.25 * SR))
    return fade(lowpass(out * held, 2600), 0.004, 0.05) * vel


def pluck(f, dur, vel=1.0, rng=None):
    """Karplus-Strong string, like a nylon guitar."""
    rng = rng or np.random.default_rng(0)
    n = int((dur + 1.4) * SR)
    period = max(2, int(round(SR / f)))
    burst = np.zeros(n)
    burst[:period] = lowpass(rng.uniform(-1, 1, period), 3500, 1)
    # y[i] = x[i] + 0.4985 * (y[i - period] + y[i - period - 1]): the string's averaging loop.
    feedback = np.zeros(period + 2)
    feedback[0] = 1.0
    feedback[period] = feedback[period + 1] = -0.4985
    out = lfilter([1.0], feedback, burst)
    return fade(out, 0.001, 0.08) * vel


def marimba(f, dur, vel=1.0):
    t = times(dur + 1.0)
    out = np.sin(2 * np.pi * f * t) * np.exp(-4.0 * t)
    out += 0.25 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-11.0 * t)
    out += 0.06 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-25.0 * t)
    return fade(out, 0.002, 0.05) * vel


def bell(f, dur, vel=1.0):
    t = times(dur + 5.0)
    out = np.zeros_like(t)
    for ratio, amp, decay in ((0.5, 0.35, 0.5), (1, 1.0, 0.7), (2.0, 0.4, 1.1), (2.76, 0.45, 1.3), (5.4, 0.2, 2.4), (8.93, 0.08, 3.5)):
        if f * ratio < SR / 2:
            out += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-decay * t)
    return fade(out, 0.003, 0.2) * vel


def pad(notes, dur, vel=1.0, cutoff=1400.0, attack=1.6, release=2.2, rng=None):
    """Warm detuned saw chord, softened with a low-pass filter."""
    rng = rng or np.random.default_rng(0)
    t = times(dur + release)
    out = np.zeros_like(t)
    for note in notes:
        f = hz(note)
        for cents in (-7, 0, 7):
            fv = f * 2 ** (cents / 1200)
            phase = rng.uniform(0, 2 * np.pi)
            for k in range(1, 14):
                if fv * k >= SR / 2:
                    break
                out += np.sin(2 * np.pi * fv * k * t + phase * k) / k
    out *= 1 + 0.08 * np.sin(2 * np.pi * 0.23 * t)
    out = lowpass(out, cutoff)
    env = np.ones_like(t)
    a = int(attack * SR)
    env[:a] = np.linspace(0, 1, a) ** 1.5
    end = int(dur * SR)
    env[end:] = np.linspace(1, 0, len(t) - end)
    return out * env * vel / (len(notes) * 6)


def organ(notes, dur, vel=1.0):
    t = times(dur + 1.2)
    out = np.zeros_like(t)
    for note in notes:
        f = hz(note)
        for ratio, amp in ((0.5, 0.45), (1, 1.0), (2, 0.55), (3, 0.22), (4, 0.18), (6, 0.05)):
            if f * ratio < SR / 2:
                out += amp * np.sin(2 * np.pi * f * ratio * t)
    out *= 1 + 0.05 * np.sin(2 * np.pi * 5.2 * t)
    env = np.ones_like(t)
    a = int(0.45 * SR)
    env[:a] = np.linspace(0, 1, a)
    end = int(dur * SR)
    env[end:] = np.linspace(1, 0, len(t) - end)
    return lowpass(out * env, 2200) * vel / (len(notes) * 2.5)


def drone(f, seconds, vel=1.0, rng=None):
    """A held tone as long as the whole loop. Every partial makes whole cycles in `seconds`, and
    its breath of air is filtered round the loop, so it joins its own start without a click."""
    rng = rng or np.random.default_rng(0)
    t = times(seconds)
    seconds = len(t) / SR

    def tone(freq, amp, phase=0.0):
        cycles = max(1, round(freq * seconds))
        return amp * np.sin(2 * np.pi * cycles / seconds * t + phase)

    out = tone(f, 1.0) + tone(f * 1.5, 0.35, 1.0) + tone(f * 2.003, 0.2)
    out *= 0.75 + 0.25 * np.sin(2 * np.pi * t / seconds * 3)
    noise = rng.normal(0, 1, len(t))
    air = lowpass(np.concatenate([noise, noise]), 380, 2)[len(t):] * 0.5
    return (out * 0.5 + air) * vel


def thump(vel=1.0):
    """A soft low heartbeat."""
    t = times(0.5)
    f = 62 * np.exp(-3 * t) + 40
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * np.exp(-9 * t) * vel


def shaker(vel=1.0, rng=None):
    rng = rng or np.random.default_rng(0)
    t = times(0.12)
    return highpass(rng.normal(0, 1, len(t)), 5000) * np.exp(-40 * t) * vel


# Arranging.

class Loop:
    """A seamless loop. Anything past the end wraps to the start."""

    def __init__(self, bpm, beats):
        self.beat = 60.0 / bpm
        self.length = int(round(beats * self.beat * SR))
        self.buf = np.zeros(self.length)

    def add(self, beat, signal, gain=1.0):
        start = int(round(beat * self.beat * SR)) % self.length
        pos = 0
        while pos < len(signal):
            room = min(self.length - start, len(signal) - pos)
            self.buf[start:start + room] += signal[pos:pos + room] * gain
            pos += room
            start = 0

    def secs(self, beats):
        return beats * self.beat

    def finish(self, room=2.0, wet=0.3, brightness=5000.0, seed=0):
        """Adds a circular reverb, gently limits, and sets every track to the same loudness
        (TARGET_RMS), with peaks kept under PEAK_LIMIT."""
        rng = np.random.default_rng(seed)
        t = times(room)
        ir = rng.normal(0, 1, len(t)) * np.exp(-6.9 * t / room)
        ir = lowpass(ir, brightness)
        ir[0] = 0
        ir /= np.sqrt(np.sum(ir ** 2))
        tiled = np.concatenate([self.buf, self.buf])
        tail = fftconvolve(tiled, ir)[: 2 * self.length]
        wet_signal = tail[self.length: 2 * self.length]
        mix = self.buf * (1 - wet) + wet_signal * wet * 1.6
        mix = highpass(np.concatenate([mix, mix]), 35)[self.length:]
        mix /= np.sqrt(np.mean(mix ** 2)) / 10 ** (TARGET_RMS / 20)
        # Soft limiting: below the limit nothing changes, above it peaks round off smoothly.
        over = np.abs(mix) > PEAK_LIMIT * 0.8
        knee = PEAK_LIMIT * 0.8
        mix[over] = np.sign(mix[over]) * (knee + (PEAK_LIMIT - knee) * np.tanh((np.abs(mix[over]) - knee) / (PEAK_LIMIT - knee)))
        return mix


def chord_tones(notes, octave_shift=0):
    return [hz(n) * 2 ** octave_shift for n in notes]


# The tracks.

def menu():
    """Cozy Afternoon: the main screen. C major, music box and soft piano over a warm pad."""
    song = Loop(76, 64)
    rng = np.random.default_rng(11)
    chords = [
        ("C3", ["E4", "G4", "B4"]), ("A2", ["C4", "E4", "G4"]), ("F2", ["A3", "C4", "E4"]), ("G2", ["B3", "D4", "E4"]),
        ("E2", ["G3", "B3", "D4"]), ("A2", ["C4", "E4", "G4"]), ("D3", ["F4", "A4", "C5"]), ("G2", ["B3", "D4", "F4"]),
    ]
    melody = [
        [("E5", 0, 1), ("G5", 1, 1), ("C6", 2, 1.5), ("B5", 3.5, 0.5)],
        [("A5", 0, 2), ("E5", 2, 1), ("G5", 3, 1)],
        [("F5", 0, 1), ("A5", 1, 1), ("C6", 2, 1), ("E6", 3, 1)],
        [("D6", 0, 2.5), ("B5", 2.5, 0.5), ("G5", 3, 1)],
        [("B5", 0, 1), ("G5", 1, 1), ("E5", 2, 1.5), ("D5", 3.5, 0.5)],
        [("E5", 0, 1), ("A5", 1, 1), ("C6", 2, 2)],
        [("A5", 0, 1), ("F5", 1, 1), ("D5", 2, 1), ("C5", 3, 1)],
        [("D5", 0, 3), ("G4", 3, 1)],
    ]
    for rep in range(2):
        for bar, (bass, upper) in enumerate(chords):
            at = (rep * 8 + bar) * 4
            song.add(at, pad(upper, song.secs(4), 0.55, 1100, rng=rng))
            song.add(at, piano(hz(bass), song.secs(3.5), 0.55))
            for step, note in enumerate([bass] + upper + upper[1:2] + upper[::-1][:3]):
                if step == 0:
                    continue
                song.add(at + step * 0.5, piano(hz(note), song.secs(0.5), 0.16 + 0.04 * (step % 2)))
            for note, beat, length in melody[bar]:
                f = hz(note) * (0.5 if rep == 1 and bar in (2, 3) else 1)
                song.add(at + beat, music_box(f, song.secs(length), 0.42))
    return song.finish(room=2.4, wet=0.32, seed=1)


def market():
    """Palengke Morning: the public market (Tokhang). F major, plucked guitar and marimba. Once
    each time round, a borrowed B flat minor chord leaves a little unease."""
    song = Loop(96, 64)
    rng = np.random.default_rng(22)
    chords = [
        ("F2", ["F3", "A3", "C4", "F4"]), ("D2", ["D3", "A3", "D4", "F4"]), ("Bb1", ["Bb2", "F3", "Bb3", "D4"]), ("C2", ["C3", "G3", "C4", "E4"]),
        ("F2", ["F3", "A3", "C4", "F4"]), ("A1", ["A2", "E3", "A3", "C4"]), ("Bb1", ["Bb2", "F3", "Bb3", "Db4"]), ("C2", ["C3", "G3", "Bb3", "E4"]),
    ]
    melody = [
        [("C5", 0, 1), ("F5", 1, 0.5), ("G5", 1.5, 0.5), ("A5", 2, 2)],
        [("A5", 0, 1), ("G5", 1, 1), ("F5", 2, 1), ("D5", 3, 1)],
        [("D5", 0, 1.5), ("F5", 1.5, 0.5), ("Bb5", 2, 1), ("A5", 3, 1)],
        [("G5", 0, 3), ("E5", 3, 1)],
        [("F5", 0, 1), ("A5", 1, 1), ("C6", 2, 1.5), ("A5", 3.5, 0.5)],
        [("G5", 0, 1), ("E5", 1, 1), ("C5", 2, 2)],
        [("Db5", 0, 1.5), ("F5", 1.5, 0.5), ("Bb4", 2, 2)],
        [("C5", 0, 2), ("E5", 2, 1), ("G5", 3, 1)],
    ]
    pattern = [0, 2, 1, 3, 2, 1, 3, 2]
    for rep in range(2):
        for bar, (bass, tones) in enumerate(chords):
            at = (rep * 8 + bar) * 4
            song.add(at, pluck(hz(bass), song.secs(2), 0.55, rng))
            song.add(at + 2.5, pluck(hz(bass) * 1.5, song.secs(1), 0.35, rng))
            for step, index in enumerate(pattern):
                song.add(at + step * 0.5, pluck(hz(tones[index]), song.secs(0.5), 0.3, rng))
            song.add(at, pad(tones[1:], song.secs(4), 0.22, 900, rng=rng))
            for beat in range(4):
                song.add(at + beat + 0.5, shaker(0.09, rng))
            if rep == 1 or bar % 2 == 0:
                for note, beat, length in melody[bar]:
                    song.add(at + beat, marimba(hz(note), song.secs(length), 0.4))
    return song.finish(room=1.3, wet=0.2, brightness=6000, seed=2)


def church():
    """Nave: the church (Kumpisal). D minor, slow organ and a soft choir pad, a bell far off."""
    song = Loop(58, 48)
    rng = np.random.default_rng(33)
    chords = [
        ["D3", "F3", "A3", "D4"], ["Bb2", "F3", "Bb3", "D4"], ["F2", "C3", "A3", "F4"], ["C3", "G3", "C4", "E4"],
        ["G2", "D3", "Bb3", "D4"], ["D3", "A3", "D4", "F4"], ["Bb2", "F3", "D4", "F4"], ["A2", "E3", "A3", "C#4"],
    ]
    for bar in range(12):
        tones = chords[bar % 8]
        if bar == 11:
            tones = ["A2", "E3", "A3", "D4"]
        at = bar * 4
        song.add(at, organ(tones, song.secs(4.2), 0.9))
        song.add(at, pad([n[:-1] + str(int(n[-1]) + 1) for n in tones[1:]], song.secs(4), 0.3, 1600, 2.0, 2.5, rng))
    for beat, note in ((2, "A5"), (18, "F5"), (34, "D5"), (42, "E5")):
        song.add(beat, bell(hz(note), 1.0, 0.18))
    return song.finish(room=4.5, wet=0.45, brightness=3500, seed=3)


def confessional():
    """Kumpisal Booth: the confessional. A dark drone, slow dissonant swells, a faint bell and a
    pulse, under the confessions."""
    song = Loop(60, 48)
    rng = np.random.default_rng(44)
    song.add(0, drone(hz("D2"), song.secs(48), 0.55, rng))
    for at, tones in ((0, ["D3", "Eb3", "A3"]), (12, ["C3", "D3", "Ab3"]), (24, ["D3", "Eb3", "Bb3"]), (36, ["Bb2", "D3", "E3"])):
        song.add(at, pad(tones, song.secs(10), 0.5, 520, 4.0, 4.0, rng))
    for at in (5, 17.5, 30, 41):
        song.add(at, bell(hz(rng.choice(["D5", "Eb5", "A4"])), 1.0, 0.11))
    for at in range(0, 48, 4):
        song.add(at, thump(0.3))
    return song.finish(room=3.5, wet=0.4, brightness=2500, seed=4)


def apartment():
    """Padala Room: the apartment. A minor, a sparse, slightly out of tune piano and a music box
    over a quiet heartbeat."""
    song = Loop(64, 48)
    rng = np.random.default_rng(55)
    chords = [("A2", ["A3", "C4", "E4"]), ("F2", ["A3", "C4", "F4"]), ("D2", ["A3", "D4", "F4"]), ("E2", ["G#3", "B3", "E4"])]
    motif = [
        [("E5", 0, 1.5), ("C5", 1.5, 0.5), ("B4", 2, 2)],
        [("A4", 0, 3), ("C5", 3, 1)],
        [("D5", 0, 1.5), ("F5", 1.5, 0.5), ("E5", 2, 2)],
        [("G#4", 0, 2), ("B4", 2, 2)],
    ]
    for bar in range(12):
        bass, tones = chords[bar % 4]
        at = bar * 4
        song.add(at, pad(tones, song.secs(4), 0.32, 700, 1.5, 2.0, rng))
        song.add(at, piano(hz(bass), song.secs(3.5), 0.4, -6))
        song.add(at, thump(0.55))
        song.add(at + 0.45, thump(0.35))
        if bar % 4 != 3 or bar == 11:
            for note, beat, length in motif[bar % 4]:
                song.add(at + beat, piano(hz(note), song.secs(length), 0.38, -18 if bar >= 8 else -8))
        if bar >= 4 and bar % 2 == 0:
            song.add(at + 3, music_box(hz("E6"), song.secs(1), 0.12, -35))
    return song.finish(room=2.2, wet=0.3, brightness=3800, seed=5)


def reveal():
    """Timelines: the timeline ending screen. Reflective, a celesta over an airy pad, E major."""
    song = Loop(70, 64)
    rng = np.random.default_rng(66)
    chords = [("E3", ["G#3", "B3", "E4"]), ("C#3", ["G#3", "C#4", "E4"]), ("A2", ["A3", "C#4", "E4"]), ("B2", ["F#3", "B3", "D#4"])]
    for bar in range(16):
        bass, tones = chords[bar % 4]
        at = bar * 4
        song.add(at, pad(tones + [bass], song.secs(4), 0.6, 1800, 2.0, 2.6, rng))
        arpeggio = [tones[0], tones[1], tones[2], tones[1]]
        for step in range(8):
            note = arpeggio[step % 4]
            octave = 1 + (1 if step >= 4 and bar >= 8 else 0)
            song.add(at + step * 0.5, music_box(hz(note) * 2 ** octave, song.secs(0.5), 0.2 + 0.05 * (step == 0)))
    return song.finish(room=3.8, wet=0.42, brightness=5200, seed=6)


TRACKS = {
    "menu": menu,
    "market": market,
    "church": church,
    "confessional": confessional,
    "apartment": apartment,
    "reveal": reveal,
}


def main():
    names = sys.argv[1:] or list(TRACKS)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name in names:
        audio = TRACKS[name]()
        path = OUT_DIR / f"{name}.wav"
        wavfile.write(path, SR, (audio * 32767).astype(np.int16))
        print(f"{path.name}: {len(audio) / SR:.1f} s, {path.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
