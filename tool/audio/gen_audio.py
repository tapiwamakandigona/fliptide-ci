#!/usr/bin/env python3
"""Fliptide's original soundtrack and SFX, synthesised from scratch.

No samples, no third-party audio: every file here is rendered by this script,
so Tsoro Studios owns the result outright. Deterministic (seeded), requires
numpy + ffmpeg (libvorbis).

    python3 tool/audio/gen_audio.py            # writes assets/audio/*

Mastering notes (what keeps this from sounding like a beeping toy):
- Composed, not rolled: the run loop is a written 8-bar melody with a
  call-and-response motif over a I–VI–VII–i / i–III–VII–v progression in
  A minor; the title loop is a slow A-Dorian pad piece. The RNG only
  humanises timing/velocity (±6 ms, ±10%), never picks notes.
- Voices: PWM pulse lead with vibrato through a 2-pole lowpass, detuned-saw
  pad, triangle+sub bass, 909-ish kick/snare/hat built from sine sweeps and
  filtered noise. Every note has a real ADSR; nothing hard-cuts.
- Effects: dotted-eighth feedback delay on the lead, Schroeder reverb on a
  send, gentle bus compression, soft clipper, then peak-normalised. Stereo
  via Haas-offset pad/lead and centred bass/drums.
- Seamless loops: the piece is rendered twice back-to-back through the
  effects and the SECOND pass is exported, so delay/reverb tails of the end
  already sit under the start. Ogg Vorbis keeps loop points sample-exact.
- SFX are 22.05 kHz mono WAV: tiny, decode-free, universal. Music sits
  ~6 dB under them (kMusicVolume in flip_audio_players.dart).
"""
from __future__ import annotations

import subprocess
import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio"
RNG = np.random.default_rng(7)


# ------------------------------------------------------------------ DSP kit
def adsr(n: int, a: float, d: float, s: float, r: float, hold: float | None = None) -> np.ndarray:
    """ADSR over n samples. a/d/r in seconds, s = sustain level (0..1).
    `hold` = note length in seconds (release starts there); None → n - r."""
    t = np.arange(n) / SR
    length = n / SR if hold is None else hold
    env = np.zeros(n)
    a = max(a, 1e-4); d = max(d, 1e-4); r = max(r, 1e-4)
    att = t < a
    env[att] = t[att] / a
    dec = (t >= a) & (t < a + d)
    env[dec] = 1 + (s - 1) * (t[dec] - a) / d
    sus = (t >= a + d) & (t < length)
    env[sus] = s
    rel = t >= length
    level_at_release = s if length >= a + d else (1 + (s - 1) * max(0, length - a) / d if length >= a else length / a)
    env[rel] = level_at_release * np.exp(-(t[rel] - length) / (r / 4))
    return env


def osc(freq, n, kind="sine", duty=0.5, sweep_to=None, vib_hz=0.0, vib_depth=0.0, pwm_hz=0.0, pwm_depth=0.0):
    t = np.arange(n) / SR
    f = np.full(n, float(freq))
    if sweep_to is not None:
        f = freq * (sweep_to / freq) ** (t / max(t[-1], 1e-6))
    if vib_hz:
        f = f * (1 + vib_depth * np.sin(2 * np.pi * vib_hz * t))
    phase = (2 * np.pi * np.cumsum(f) / SR) % (2 * np.pi)
    u = phase / (2 * np.pi)
    if kind == "sine":
        return np.sin(phase)
    if kind == "square":
        d = duty + (pwm_depth * np.sin(2 * np.pi * pwm_hz * t) if pwm_hz else 0)
        return np.where(u < d, 1.0, -1.0)
    if kind == "tri":
        return 2 * np.abs(2 * u - 1) - 1
    if kind == "saw":
        return 2 * u - 1
    raise ValueError(kind)


def noise(n):
    return RNG.uniform(-1, 1, n)


def lowpass(x, cutoff, order=2):
    """Zero-phase FFT lowpass with a soft Butterworth-like knee (order poles)."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    gain = 1 / np.sqrt(1 + (freqs / cutoff) ** (2 * order))
    return np.fft.irfft(spec * gain, n=len(x))


def highpass(x, cutoff, order=2):
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    with np.errstate(divide="ignore"):
        gain = 1 / np.sqrt(1 + (cutoff / np.maximum(freqs, 1e-9)) ** (2 * order))
    gain[0] = 0
    return np.fft.irfft(spec * gain, n=len(x))


def delay(x, seconds, feedback=0.35, mix=0.25, damp=3500):
    d = int(seconds * SR)
    out = np.zeros(len(x) + d * 6)
    buf = x.copy()
    out[: len(x)] += x
    for k in range(1, 7):
        buf = lowpass(buf, damp) * feedback
        out[k * d : k * d + len(x)] += buf * mix / feedback
    return out[: len(x)]  # tails beyond the buffer are dropped; loops render twice so they wrap


def reverb(x, size=0.6, mix=0.18):
    """Schroeder: 4 parallel combs → 2 series allpasses. Mono in, mono out."""
    combs = [int(SR * s * size) for s in (0.0297, 0.0371, 0.0411, 0.0437)]
    y = np.zeros(len(x))
    for c in combs:
        g = 0.805
        buf = np.zeros(len(x))
        for i in range(len(x)):
            buf[i] = x[i] + (g * buf[i - c] if i >= c else 0)
        y += buf
    y /= len(combs)
    for ap in (int(SR * 0.005), int(SR * 0.0017)):
        g = 0.7
        out = np.zeros(len(y))
        for i in range(len(y)):
            back = out[i - ap] if i >= ap else 0
            xin = y[i - ap] if i >= ap else 0
            out[i] = -g * y[i] + xin + g * back
        y = out
    return x * (1 - mix) + lowpass(y, 5000) * mix


def compress(x, thresh_db=-14, ratio=3.0, attack=0.004, release=0.12):
    """Feed-forward RMS-ish compressor with one-pole envelope follower."""
    a_att = np.exp(-1 / (attack * SR)); a_rel = np.exp(-1 / (release * SR))
    env = np.zeros(len(x)); e = 0.0
    ax = np.abs(x)
    for i in range(len(x)):
        coef = a_att if ax[i] > e else a_rel
        e = coef * e + (1 - coef) * ax[i]
        env[i] = e
    env_db = 20 * np.log10(np.maximum(env, 1e-6))
    over = np.maximum(env_db - thresh_db, 0)
    gain_db = -over * (1 - 1 / ratio)
    return x * 10 ** (gain_db / 20)


def softclip(x, drive=1.2):
    return np.tanh(x * drive) / np.tanh(drive)


def normalise(x, peak_db=-1.0):
    m = np.max(np.abs(x)) or 1.0
    return x / m * (10 ** (peak_db / 20))


def declick(x, ms=3.0):
    n = int(SR * ms / 1000)
    ramp = np.linspace(0, 1, n)
    x = x.copy()
    x[:n] *= ramp
    x[-n:] *= ramp[::-1]
    return x


def write_wav(path: Path, x: np.ndarray):
    """x: (n,) mono or (n, 2) stereo, float -1..1."""
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    ch = 1 if data.ndim == 1 else data.shape[1]
    with wave.open(str(path), "wb") as w:
        w.setnchannels(ch); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(path: Path, x: np.ndarray, quality=5):
    tmp = path.with_suffix(".tmp.wav")
    write_wav(tmp, x)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp), "-codec:a", "libvorbis",
                    "-q:a", str(quality), "-ar", str(SR), str(path)], check=True)
    tmp.unlink()


def note_hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def place(buf, start_s, sig, gain=1.0):
    i = int(round(start_s * SR))
    if i < 0:
        sig = sig[-i:]; i = 0
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[: j - i] * gain


def human(t, ms=6):
    return t + RNG.normal(0, ms / 1000)


def vel(v=1.0, spread=0.1):
    return v * (1 + RNG.uniform(-spread, spread))


# --------------------------------------------------------------------- SFX
def sfx_flip():
    # A soft "bloop": sine with a quick upward pitch bend, a hint of 2nd
    # harmonic, tiny noise transient. Reads as "hop", not "beep".
    n = int(0.10 * SR)
    body = osc(330, n, "sine", sweep_to=760) * adsr(n, 0.002, 0.05, 0.3, 0.04, hold=0.06)
    harm = osc(660, n, "tri", sweep_to=1520) * adsr(n, 0.002, 0.03, 0.15, 0.03, hold=0.04) * 0.35
    tick = lowpass(noise(n), 4000) * adsr(n, 0.0005, 0.008, 0, 0.005, hold=0.006) * 0.3
    return normalise(lowpass(body + harm + tick, 5500), -3)


def sfx_land():
    n = int(0.13 * SR)
    thud = osc(140, n, "sine", sweep_to=52) * adsr(n, 0.001, 0.07, 0.2, 0.05, hold=0.07)
    dust = lowpass(noise(n), 1500) * adsr(n, 0.001, 0.03, 0.1, 0.04, hold=0.03)
    return normalise(thud + 0.3 * dust, -5)


def sfx_death():
    n = int(0.55 * SR)
    fall = osc(520, n, "saw", sweep_to=60) * adsr(n, 0.002, 0.25, 0.3, 0.2, hold=0.3)
    sub = osc(110, n, "sine", sweep_to=35) * adsr(n, 0.001, 0.2, 0.3, 0.2, hold=0.25) * 0.8
    crunch = lowpass(noise(n), 2600) * adsr(n, 0.001, 0.09, 0.05, 0.08, hold=0.08)
    x = softclip(fall * 0.7 + sub + 0.5 * crunch, 1.6)
    return normalise(reverb(lowpass(x, 6000), size=0.5, mix=0.12), -1.5)


def sfx_win():
    # C5 E5 G5 C6, triangle lead with a sine octave, into a short reverb.
    notes = [523.25, 659.25, 783.99, 1046.5]
    step = 0.105
    n = int((step * len(notes) + 0.7) * SR)
    x = np.zeros(n)
    for i, f in enumerate(notes):
        m = int(0.75 * SR)
        seg = (osc(f, m, "tri", vib_hz=5, vib_depth=0.004) * 0.8 + osc(f * 2, m, "sine") * 0.22)
        seg *= adsr(m, 0.004, 0.18, 0.35, 0.3, hold=0.22 if i < 3 else 0.42)
        place(x, i * step, seg)
    return normalise(reverb(lowpass(x, 7500), size=0.7, mix=0.22), -2)


def sfx_star():
    n = int(0.5 * SR)
    partials = [(1318.5, 1.0), (1975.5, 0.55), (2637.0, 0.3), (3951.0, 0.12)]
    x = np.zeros(n)
    for f, g in partials:
        x += osc(f * (1 + RNG.uniform(-0.0015, 0.0015)), n, "sine") * adsr(n, 0.002, 0.25, 0.2, 0.2, hold=0.2) * g
    return normalise(reverb(x, size=0.6, mix=0.2), -4)


def sfx_tap():
    n = int(0.06 * SR)
    x = osc(1100, n, "sine", sweep_to=700) * adsr(n, 0.001, 0.025, 0.1, 0.02, hold=0.02)
    x += lowpass(noise(n), 5000) * adsr(n, 0.0005, 0.006, 0, 0.004, hold=0.004) * 0.25
    return normalise(x, -8)


def sfx_checkpoint():
    n = int(0.3 * SR)
    x = osc(880, n, "tri") * adsr(n, 0.003, 0.1, 0.4, 0.12, hold=0.1)
    x += 0.5 * osc(1320, n, "sine") * adsr(n, 0.05, 0.1, 0.3, 0.12, hold=0.12)
    return normalise(reverb(x, size=0.5, mix=0.15), -6)


# ------------------------------------------------------------------- music
def stereo(mono_l, mono_r=None):
    r = mono_l if mono_r is None else mono_r
    return np.stack([mono_l, r], axis=1)


def haas(x, ms=12.0, width=0.7):
    """Widen a mono signal: right channel delayed by `ms`, mixed by `width`."""
    d = int(SR * ms / 1000)
    r = np.zeros(len(x)); r[d:] = x[:-d]
    left = x
    right = x * (1 - width) + r * width
    return left, right


def render_twice(build, loop_s: float):
    """Render two consecutive loops through the effects and keep the second,
    so end-of-loop tails already sit under the loop start."""
    n = int(round(loop_s * SR))
    full_l, full_r = build(2 * n, loop_s)
    return declick(full_l[n:]), declick(full_r[n:])


def kick(n=None):
    n = n or int(0.22 * SR)
    body = osc(150, n, "sine", sweep_to=42) * adsr(n, 0.0005, 0.12, 0.15, 0.08, hold=0.1)
    click = highpass(noise(n), 2000) * adsr(n, 0.0002, 0.004, 0, 0.003, hold=0.003) * 0.35
    return softclip(body * 1.1 + click, 1.5)


def snare(n=None):
    n = n or int(0.18 * SR)
    tone = osc(190, n, "sine", sweep_to=150) * adsr(n, 0.0005, 0.06, 0.1, 0.05, hold=0.05) * 0.5
    nse = highpass(lowpass(noise(n), 7000), 900) * adsr(n, 0.0005, 0.08, 0.15, 0.06, hold=0.06)
    return tone + nse * 0.8


def hat(n=None, open_=False):
    n = n or int((0.09 if open_ else 0.04) * SR)
    x = highpass(noise(n), 6000) * adsr(n, 0.0003, 0.05 if open_ else 0.02, 0.1, 0.03, hold=0.03 if open_ else 0.012)
    return x


def music_run():
    """'Undertow' — the run loop. 128 BPM, 8 bars (15.0 s), A minor."""
    bpm, bars = 128, 8
    spb = 60 / bpm
    loop_s = bars * 4 * spb

    # Harmony (bar roots as MIDI): Am Am F G | Am C G Em
    roots = [57, 57, 53, 55, 57, 60, 55, 52]
    chords = {57: [57, 60, 64], 53: [53, 57, 60], 55: [55, 59, 62], 60: [60, 64, 67], 52: [52, 55, 59]}
    # Melody: (beat offset within 2-bar phrase, midi, length in beats). Two phrases: call, response.
    # A minor pentatonic + passing B/F. Written to sit against the roots above.
    call = [(0, 76, 0.5), (0.5, 79, 0.5), (1, 81, 1.0), (2, 79, 0.5), (2.5, 76, 0.5), (3, 74, 1.0),
            (4, 72, 0.5), (4.5, 74, 0.5), (5, 76, 1.0), (6, 74, 0.5), (6.5, 72, 0.5), (7, 69, 1.0)]
    response = [(0, 76, 0.5), (0.5, 79, 0.5), (1, 84, 1.0), (2, 81, 0.5), (2.5, 79, 0.5), (3, 81, 1.0),
                (4, 79, 0.5), (4.5, 76, 0.5), (5, 74, 1.0), (6, 72, 0.5), (6.5, 71, 0.5), (7, 69, 1.5)]
    variation = [(0, 76, 0.5), (0.5, 79, 0.5), (1, 81, 0.5), (1.5, 84, 0.5), (2, 81, 1.0), (3, 79, 1.0),
                 (4, 76, 0.5), (4.5, 74, 0.5), (5, 76, 1.0), (6, 79, 0.5), (6.5, 76, 0.5), (7, 74, 1.0)]
    ending = [(0, 76, 0.5), (0.5, 79, 0.5), (1, 84, 1.5), (2.5, 81, 0.5), (3, 79, 1.0),
              (4, 76, 1.0), (5, 74, 1.0), (6, 72, 0.5), (6.5, 71, 0.5), (7, 69, 1.0)]
    phrases = [call, response, variation, ending]

    def build(n_total, _):
        lead = np.zeros(n_total); pad = np.zeros(n_total); bass = np.zeros(n_total); drums = np.zeros(n_total)
        total_bars = int(round(n_total / SR / (4 * spb)))
        for bar in range(total_bars):
            b0 = bar * 4 * spb
            root = roots[bar % 8]
            # --- pad: detuned saws, slow filter, quiet
            m = int(4.2 * spb * SR)
            chord = np.zeros(m)
            for midi in chords[root]:
                for det in (-6, 6):
                    chord += osc(note_hz(midi) * 2 ** (det / 1200), m, "saw") * 0.08
            chord = lowpass(chord, 1200 + 300 * np.sin(bar)) * adsr(m, 0.35, 0.5, 0.75, 0.6, hold=3.8 * spb)
            place(pad, b0, chord)
            # --- bass: root on 1, octave-up pickup on the "and" of 2, root on 3, fifth on 4.5
            for beat, off, ln in ((0, 0, 0.9), (1.5, 12, 0.4), (2, 0, 0.9), (3.5, 7, 0.45)):
                mm = int((ln + 0.3) * spb * SR)
                f = note_hz(root - 12 + off)
                sig = (osc(f, mm, "tri") * 0.7 + osc(f / 2, mm, "sine") * 0.5) * adsr(mm, 0.006, 0.12, 0.6, 0.12, hold=ln * spb)
                place(bass, human(b0 + beat * spb, 3), lowpass(sig, 900), vel(0.9, 0.06))
            # --- drums
            for beat in range(4):
                t0 = b0 + beat * spb
                if beat in (0, 2):
                    place(drums, human(t0, 2), kick(), vel(1.0, 0.04))
                if beat in (1, 3):
                    place(drums, human(t0, 3), snare(), vel(0.55, 0.08))
                place(drums, human(t0 + spb / 2, 4), hat(), vel(0.28, 0.15))
                if beat == 3 and bar % 2 == 1:
                    place(drums, human(t0 + spb * 0.75, 4), hat(open_=True), 0.22)
            # extra kick on the "and" of 3 every other bar for drive
            if bar % 2 == 0:
                place(drums, human(b0 + 2.5 * spb, 2), kick(), 0.75)
        # --- lead: phrases over 2-bar groups
        for group in range(total_bars // 2):
            phrase = phrases[group % 4]
            g0 = group * 8 * spb
            for beat, midi, ln in phrase:
                mm = int((ln * spb + 0.35) * SR)
                f = note_hz(midi)
                sig = osc(f, mm, "square", duty=0.42, vib_hz=5.5, vib_depth=0.003, pwm_hz=0.7, pwm_depth=0.08)
                sig = lowpass(sig, 2600) * adsr(mm, 0.008, 0.08, 0.7, 0.16, hold=ln * spb * 0.92)
                place(lead, human(g0 + beat * spb, 5), sig, vel(0.5, 0.08))
        lead = delay(lead, spb * 0.75, feedback=0.32, mix=0.22)  # dotted eighth
        # --- mix (mono busses) then stereo placement
        mix_c = bass * 0.9 + drums * 0.95
        pad_l, pad_r = haas(pad, 14, 0.8)
        lead_l, lead_r = haas(lead, 9, 0.5)
        left = mix_c + pad_l * 0.55 + lead_l * 0.85
        right = mix_c + pad_r * 0.55 + lead_r * 0.85
        wet_l = reverb(left, size=0.55, mix=0.14); wet_r = reverb(right, size=0.58, mix=0.14)
        out_l = highpass(softclip(compress(wet_l), 1.15), 28); out_r = highpass(softclip(compress(wet_r), 1.15), 28)
        peak = max(np.max(np.abs(out_l)), np.max(np.abs(out_r)))
        k = 10 ** (-1.0 / 20) / peak
        return out_l * k, out_r * k

    l, r = render_twice(build, loop_s)
    return stereo(l, r), loop_s


def music_title():
    """'Slack Water' — the title loop. 72 BPM, 8 bars (26.67 s), A Dorian."""
    bpm, bars = 72, 8
    spb = 60 / bpm
    loop_s = bars * 4 * spb
    # Am9 | D(add9) | Am9 | G6 | Am9 | Fmaj7 | D(add9) | Em7 → resolves back to Am9
    prog = [[45, 57, 60, 64, 71], [50, 54, 57, 64], [45, 57, 60, 64, 71], [43, 55, 59, 64],
            [45, 57, 60, 64, 71], [41, 53, 57, 60, 64], [50, 54, 57, 64], [40, 52, 55, 59, 62]]
    # A slow melody, one idea per two bars, mostly on chord tones, long notes.
    melody = [(0, 76, 3), (3, 79, 1), (4, 81, 3.5), (8, 79, 2), (10, 76, 2), (12, 74, 2), (14, 72, 2),
              (16, 76, 3), (19, 74, 1), (20, 72, 2), (22, 74, 2), (24, 71, 3), (27, 72, 1), (28, 69, 4)]

    def build(n_total, _):
        pad = np.zeros(n_total); mel = np.zeros(n_total); sub = np.zeros(n_total); wash = np.zeros(n_total)
        total_bars = int(round(n_total / SR / (4 * spb)))
        for bar in range(total_bars):
            b0 = bar * 4 * spb
            notes = prog[bar % 8]
            m = int(4.6 * spb * SR)
            chord = np.zeros(m)
            for k, midi in enumerate(notes):
                g = 0.05 if k else 0.07
                for det in (-5, 5):
                    chord += osc(note_hz(midi) * 2 ** (det / 1200), m, "saw") * g
            cutoff = 1500 + 400 * np.sin(2 * np.pi * bar / 8)
            chord = lowpass(chord, cutoff) * adsr(m, 0.9, 1.0, 0.8, 1.2, hold=3.6 * spb)
            place(pad, b0, chord)
            # sub bass on the root, very soft
            mm = int(4.2 * spb * SR)
            place(sub, b0, osc(note_hz(notes[0] - 12), mm, "sine") * adsr(mm, 0.4, 0.5, 0.7, 0.8, hold=3.4 * spb), 0.22)
        for beat, midi, ln in melody:
            for rep in range(total_bars // 8):
                mm = int((ln * spb + 1.2) * SR)
                f = note_hz(midi)
                sig = (osc(f, mm, "sine", vib_hz=4.5, vib_depth=0.0025) + 0.3 * osc(f * 2, mm, "sine") + 0.08 * osc(f * 3, mm, "tri")) * 0.35
                sig *= adsr(mm, 0.12, 0.4, 0.6, 0.9, hold=ln * spb * 0.9)
                place(mel, human(rep * 32 * spb + beat * spb, 8), sig, vel(1.0, 0.08))
        # tide wash: slow filtered noise swell, twice per loop, stereo-drifting
        t = np.arange(n_total) / SR
        swell = 0.5 - 0.5 * np.cos(2 * np.pi * t / (loop_s / 2))
        w = lowpass(noise(n_total), 420) * swell * 0.05
        wash += w
        mel = delay(mel, spb * 1.5, feedback=0.3, mix=0.2)
        pad_l, pad_r = haas(pad, 18, 0.85)
        mel_l, mel_r = haas(mel, 11, 0.5)
        wash_l, wash_r = wash, np.roll(wash, int(SR * 0.021))
        left = pad_l + mel_l + sub + wash_l
        right = pad_r + mel_r + sub + wash_r
        wet_l = reverb(left, size=0.9, mix=0.26); wet_r = reverb(right, size=0.94, mix=0.26)
        out_l = highpass(softclip(compress(wet_l, thresh_db=-16, ratio=2.5), 1.1), 28)
        out_r = highpass(softclip(compress(wet_r, thresh_db=-16, ratio=2.5), 1.1), 28)
        peak = max(np.max(np.abs(out_l)), np.max(np.abs(out_r)))
        k = 10 ** (-2.0 / 20) / peak
        return out_l * k, out_r * k

    l, r = render_twice(build, loop_s)
    return stereo(l, r), loop_s


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in {"flip": sfx_flip, "land": sfx_land, "death": sfx_death, "win": sfx_win,
                     "star": sfx_star, "tap": sfx_tap, "checkpoint": sfx_checkpoint}.items():
        write_wav(OUT / f"{name}.wav", declick(fn(), 1.5))
    run, run_s = music_run()
    write_ogg(OUT / "music_run.ogg", run)
    title, title_s = music_title()
    write_ogg(OUT / "music_title.ogg", title)
    for p in sorted(OUT.iterdir()):
        print(f"{p.name:18s} {p.stat().st_size:>8d} B")
    print(f"loops: run {run_s:.3f}s  title {title_s:.3f}s")


if __name__ == "__main__":
    main()
