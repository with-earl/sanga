"""Composes SANGA's background music and writes it to assets/music/*.wav.

All of it is slow, quiet solo piano: one original waltz theme (whimsical and nostalgic, in the
spirit of 90s Filipino pop ballads) arranged differently for each scene. A different key, mode,
register, tempo and accompaniment give each place its own colour, from the warm main screen to
the fragmented, out of tune version in the apartment.

The theme and every arrangement are original, and the piano is synthesised here (no samples), so
there is nothing to license. Each track is a seamless loop: notes and reverb that run past the
end wrap round to the start.

    python tools/compose_music.py            # all tracks
    python tools/compose_music.py market     # one track, by name

Needs numpy and scipy. The same seed gives the same music every time.
"""

import sys
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

SR = 22050
# Every track is set to this loudness, so changing scenes never jumps in volume.
TARGET_RMS = -20.0
PEAK_LIMIT = 0.85
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "music"

MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]

# The theme: a 16-bar waltz in two halves. Each note is (scale degree, beat in the bar, beats
# long); degree 0 is the tonic, 7 the tonic an octave up, negative numbers go below.
THEME = [
    [(4, 0, 2), (2, 2, 1)],
    [(3, 0, 1), (4, 1, 1), (5, 2, 1)],
    [(4, 0, 3)],
    [(2, 0, 1), (1, 1, 1), (0, 2, 1)],
    [(1, 0, 2), (2, 2, 1)],
    [(3, 0, 1), (2, 1, 1), (1, 2, 1)],
    [(2, 0, 3)],
    [(-3, 2, 1)],
    [(7, 0, 2), (6, 2, 1)],
    [(5, 0, 1), (4, 1, 1), (3, 2, 1)],
    [(5, 0, 2), (4, 2, 1)],
    [(2, 0, 3)],
    [(3, 0, 1), (5, 1, 1), (8, 2, 1)],
    [(7, 0, 2), (6, 2, 1)],
    [(7, 0, 3)],
    [],
]
# The chord under each bar, as the scale degree of its root.
HARMONY = [0, 3, 0, 5, 4, 1, 0, 4, 5, 3, 1, 0, 1, 4, 0, 0]
BEATS_PER_BAR = 3


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def lowpass(signal, cutoff, order=2):
    sos = butter(order, min(cutoff, SR * 0.45), btype="low", fs=SR, output="sos")
    return sosfilt(sos, signal)


def highpass(signal, cutoff, order=2):
    sos = butter(order, cutoff, btype="high", fs=SR, output="sos")
    return sosfilt(sos, signal)


def pitch(tonic, scale, degree, raise_leading=False):
    """The MIDI note for a scale degree. In minor, the leading tone can be raised (harmonic
    minor) so the chord on the fifth pulls home."""
    octave, step = divmod(degree, 7)
    semitones = scale[step]
    if raise_leading and scale is MINOR and step == 6:
        semitones = 11
    return tonic + 12 * octave + semitones


class Piano:
    """A soft felt-like piano: slightly inharmonic strings, each partial fading at its own rate,
    a gentle hammer, brightness that follows how hard a key is played, and the damper pedal
    letting notes ring until `held` runs out."""

    def __init__(self, seed):
        self.rng = np.random.default_rng(seed)

    def note(self, midi, held, velocity, detune_cents=0.0):
        f = hz(midi) * 2 ** (detune_cents / 1200)
        ring = held + 1.2
        t = np.arange(int(ring * SR)) / SR
        out = np.zeros_like(t)
        # Low notes ring longer than high ones.
        sustain = np.interp(midi, [36, 96], [7.0, 1.6])
        for k in range(1, 12):
            fk = k * f * np.sqrt(1 + 0.00035 * k * k)
            if fk >= SR * 0.45:
                break
            amp = (1.0 / k ** 1.25) * (velocity ** (0.25 * (k - 1)))
            fast = np.exp(-t * (2.5 + 1.2 * k))
            slow = np.exp(-t * (1.0 + 0.35 * k) / sustain)
            env = 0.35 * fast + 0.65 * slow
            for spread in (-0.35, 0.35):
                out += 0.5 * amp * env * np.sin(2 * np.pi * (fk + spread * k * 0.3) * t + self.rng.uniform(0, 6.28))
        hammer = lowpass(self.rng.normal(0, 1, int(0.02 * SR)), 1800, 1) * np.exp(-np.arange(int(0.02 * SR)) / (0.004 * SR))
        out[: len(hammer)] += hammer * 0.04 * velocity
        # The damper comes down when the note is no longer held.
        end = int(held * SR)
        if end < len(out):
            out[end:] *= np.exp(-np.arange(len(out) - end) / (0.18 * SR))
        attack = int(0.003 * SR)
        out[:attack] *= np.linspace(0, 1, attack)
        cutoff = 900 + 2600 * velocity
        return lowpass(out, cutoff) * velocity


class Loop:
    """A seamless loop. Anything past the end wraps to the start."""

    def __init__(self, bpm, bars):
        self.beat = 60.0 / bpm
        self.length = int(round(bars * BEATS_PER_BAR * self.beat * SR))
        self.buf = np.zeros(self.length)

    def secs(self, beats):
        return beats * self.beat

    def add(self, beat, signal):
        start = int(round(beat * self.beat * SR)) % self.length
        pos = 0
        while pos < len(signal):
            room = min(self.length - start, len(signal) - pos)
            self.buf[start:start + room] += signal[pos:pos + room]
            pos += room
            start = 0

    def finish(self, room, wet, seed):
        """A soft circular reverb, then every track set to the same quiet loudness."""
        rng = np.random.default_rng(seed)
        t = np.arange(int(room * SR)) / SR
        ir = lowpass(rng.normal(0, 1, len(t)) * np.exp(-6.9 * t / room), 3200)
        ir[: int(0.012 * SR)] = 0
        ir /= np.sqrt(np.sum(ir ** 2))
        tiled = np.concatenate([self.buf, self.buf])
        wet_signal = fftconvolve(tiled, ir)[self.length: 2 * self.length]
        mix = self.buf * (1 - wet) + wet_signal * wet * 1.4
        mix = highpass(np.concatenate([mix, mix]), 40)[self.length:]
        mix /= np.sqrt(np.mean(mix ** 2)) / 10 ** (TARGET_RMS / 20)
        knee = PEAK_LIMIT * 0.8
        over = np.abs(mix) > knee
        mix[over] = np.sign(mix[over]) * (knee + (PEAK_LIMIT - knee) * np.tanh((np.abs(mix[over]) - knee) / (PEAK_LIMIT - knee)))
        return mix


def arrange(tonic, scale, bpm, style, melody_octave=0, seed=0, room=2.6, wet=0.35,
            velocity=0.35, detune=0.0, drift=0.0, keep=None, humanise=0.0, double_octave=False):
    """Plays the theme once round (16 bars) as one version.

    style          the left hand: "waltz" (bass, then two soft chords), "rolled" (a slow rolled
                   chord held by the pedal), "chorale" (block chords, like a hymn), "arpeggio"
                   (slow broken chords) or "sparse" (a low note now and then).
    keep           which bars keep their melody, or None for all of them.
    detune, drift  cents out of tune at the start, and how much more by the end.
    humanise       how far, in beats, notes may hesitate after the beat.
    """
    piano = Piano(seed)
    rng = np.random.default_rng(seed + 100)
    song = Loop(bpm, 16)
    for bar in range(16):
        at = bar * BEATS_PER_BAR
        root = HARMONY[bar]
        lead = root == 4
        cents = detune + drift * bar / 15
        chord = [pitch(tonic, scale, root + step, lead) for step in (0, 2, 4)]
        bass = chord[0] - 12 if chord[0] - 12 >= tonic - 14 else chord[0]
        upper = [n + 12 for n in chord]

        def play(beat, midi, beats, vel):
            late = rng.uniform(0, humanise) if humanise else 0.0
            song.add(at + beat + late, piano.note(midi, song.secs(beats), vel * rng.uniform(0.9, 1.05), cents + rng.uniform(-1.5, 1.5)))

        if style == "waltz":
            play(0, bass, 3, velocity * 0.8)
            for beat in (1, 2):
                for n in upper[1:]:
                    play(beat, n, 0.9, velocity * 0.32)
        elif style == "rolled":
            for i, n in enumerate([bass] + upper):
                play(i * 0.18, n, 3, velocity * (0.7 if i == 0 else 0.38))
        elif style == "chorale":
            play(0, bass, 3, velocity * 0.75)
            for n in upper:
                play(0, n, 3, velocity * 0.42)
        elif style == "arpeggio":
            notes = [bass, upper[0], upper[1], upper[2], upper[1], upper[0]]
            for i, n in enumerate(notes):
                play(i * 0.5, n, 3 - i * 0.5, velocity * (0.65 if i == 0 else 0.3))
        elif style == "sparse":
            if bar % 2 == 0:
                play(0, bass, 6, velocity * 0.7)
            if bar % 4 == 2:
                play(1.5, upper[1], 2, velocity * 0.25)
        if keep is not None and bar not in keep:
            continue
        for degree, beat, beats in THEME[bar]:
            midi = pitch(tonic, scale, degree, lead) + 12 + 12 * melody_octave
            play(beat, midi, beats, velocity)
            if double_octave:
                play(beat, midi + 12, beats, velocity * 0.35)
    return song.finish(room, wet, seed)


# The versions, one per scene.

def menu():
    """Main screen: the theme as it is, warm and gentle. C major, a slow waltz."""
    return arrange(60, MAJOR, 62, "waltz", seed=1)


def market():
    """Public market (Tokhang): a little brighter and lighter. G major, slow broken chords."""
    return arrange(55, MAJOR, 66, "arpeggio", melody_octave=1, seed=2, velocity=0.32, room=2.0, wet=0.3)


def church():
    """Church nave (Kumpisal): a quiet hymn. D minor, block chords, a long reverb."""
    return arrange(50, MINOR, 52, "chorale", seed=3, room=4.5, wet=0.5, velocity=0.33)


def confessional():
    """Confessional: only fragments of the theme, low and far apart. A minor, very slow."""
    return arrange(45, MINOR, 46, "sparse", seed=4, room=4.0, wet=0.5,
                   velocity=0.3, keep={0, 1, 2, 8, 9, 10}, humanise=0.25, detune=-6)


def apartment():
    """Apartment room (Padala): hesitant and slowly going out of tune. A minor, rolled chords."""
    return arrange(57, MINOR, 54, "rolled", seed=5, velocity=0.3, detune=-4, drift=-22,
                   keep={0, 1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 13}, humanise=0.3)


def reveal():
    """Timeline ending: the whole theme, high and reflective. E major, rolled chords, the melody
    doubled an octave up."""
    return arrange(52, MAJOR, 58, "rolled", melody_octave=1, seed=6, room=3.8, wet=0.45, velocity=0.3, double_octave=True)


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
