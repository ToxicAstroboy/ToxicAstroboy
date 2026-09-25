"""Procedurally synthesises every sound effect and music loop used by Hollow Vigil.

Pure Python (no numpy), writes 16-bit mono WAV files into game/assets/sounds/.
Run:  python3 tools/gen_audio.py
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "sounds")
TAU = math.tau


def write(name, samples, peak=0.9):
    m = max(1e-6, max(abs(s) for s in samples))
    g = peak / m if m > peak else 1.0
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * g)) * 32767)) for s in samples))
    print("wrote", name, f"{len(samples) / SR:.2f}s")


def n(sec):
    return int(sec * SR)


def lowpass(x, a):
    y, out = 0.0, []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, a):
    lp = lowpass(x, a)
    return [s - l for s, l in zip(x, lp)]


def noise(count, rng=random):
    return [rng.uniform(-1, 1) for _ in range(count)]


def env_exp(count, decay):
    return [math.exp(-i / SR * decay) for i in range(count)]


def mix(*tracks):
    L = max(len(t) for t in tracks)
    out = [0.0] * L
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def gain(x, g):
    return [s * g for s in x]


def fade(x, fin=0.01, fout=0.05):
    a, b = n(fin), n(fout)
    x = list(x)
    for i in range(min(a, len(x))):
        x[i] *= i / max(1, a)
    for i in range(min(b, len(x))):
        x[-1 - i] *= i / max(1, b)
    return x


def loop_xfade(x, sec=0.5):
    """Crossfade the tail into the head so the file loops seamlessly."""
    k = n(sec)
    head, body, tail = x[:k], x[k:-k], x[-k:]
    blended = [tail[i] * (1 - i / k) + head[i] * (i / k) for i in range(k)]
    return body + blended


def tone(freq, sec, amp=1.0, decay=0.0, phase=0.0, vib=0.0, vib_rate=5.0):
    out = []
    ph = phase
    for i in range(n(sec)):
        t = i / SR
        f = freq * (1 + vib * math.sin(TAU * vib_rate * t))
        ph += TAU * f / SR
        out.append(math.sin(ph) * amp * math.exp(-t * decay))
    return out


# ---------------------------------------------------------------- weapons
def gunshot(sec, body_hz, decay, crack, lp):
    L = n(sec)
    nz = lowpass(noise(L), lp)
    e = env_exp(L, decay)
    thump = tone(body_hz, sec, 1.0, decay * 1.4)
    cr = [s * math.exp(-i / SR * 90) for i, s in enumerate(noise(L))]
    return fade(mix([a * b for a, b in zip(nz, e)], gain(thump, 0.8), gain(cr, crack)), 0.001, 0.05)


def click(freq=2400, sec=0.05):
    return fade([math.sin(TAU * freq * i / SR) * math.exp(-i / SR * 120) + random.uniform(-.4, .4) * math.exp(-i / SR * 200) for i in range(n(sec))], 0.0005, 0.01)


def reload_snd():
    s = [0.0] * n(0.9)
    for t0, f in ((0.0, 1800), (0.35, 900), (0.65, 2600)):
        c = click(f, 0.08)
        o = n(t0)
        for i, v in enumerate(c):
            if o + i < len(s):
                s[o + i] += v
    return s


def swish():
    L = n(0.28)
    out = []
    y = 0
    for i in range(L):
        t = i / L
        a = 0.05 + 0.5 * t
        y += a * (random.uniform(-1, 1) - y)
        out.append(y * math.sin(math.pi * t))
    return fade(out)


def flesh():
    L = n(0.25)
    nz = lowpass(noise(L), 0.15)
    return fade(mix([a * b for a, b in zip(nz, env_exp(L, 22))], tone(90, 0.25, 0.8, 18)))


def kick():
    return fade(mix(tone(60, 0.35, 1.0, 10), gain([a * b for a, b in zip(lowpass(noise(n(0.35)), 0.2), env_exp(n(0.35), 18))], 0.8)))


# ---------------------------------------------------------------- voices
def formant_voice(sec, base, vowels, rough=0.4, seed=0):
    """Crude growling voice: pulse train through 2 resonators with moving formants."""
    rng = random.Random(seed)
    L = n(sec)
    out = []
    ph = 0
    y1 = y2 = z1 = z2 = 0.0
    for i in range(L):
        t = i / L
        f0 = base * (1 + 0.15 * math.sin(TAU * 3 * t) + rough * 0.1 * rng.uniform(-1, 1))
        ph += f0 / SR
        src = (ph % 1.0) * 2 - 1 + rough * rng.uniform(-1, 1)
        k = t * (len(vowels) - 1)
        a, b = vowels[int(k)], vowels[min(len(vowels) - 1, int(k) + 1)]
        fr = k - int(k)
        F1 = a[0] + (b[0] - a[0]) * fr
        F2 = a[1] + (b[1] - a[1]) * fr
        r = 0.97
        c1 = 2 * r * math.cos(TAU * F1 / SR)
        c2 = 2 * r * math.cos(TAU * F2 / SR)
        o1 = src + c1 * y1 - r * r * y2
        y2, y1 = y1, o1
        o2 = src + c2 * z1 - r * r * z2
        z2, z1 = z1, o2
        env = math.sin(math.pi * min(1, t * 1.2)) ** 0.6
        out.append((o1 * 0.05 + o2 * 0.03) * env)
    return fade(out, 0.02, 0.1)


A, O, U, E, I = (800, 1200), (500, 900), (320, 800), (530, 1850), (300, 2200)


# ---------------------------------------------------------------- bells & atmos
def bell(sec, f, bright=1.0):
    partials = [(0.5, 1.0, 0.7), (1.0, 0.8, 1.0), (1.19, 0.6, 1.4), (1.5, 0.5, 1.8), (2.0, 0.45, 2.2),
                (2.51, 0.3 * bright, 3.0), (3.01, 0.2 * bright, 4.0), (4.1, 0.12 * bright, 5.5)]
    out = [0.0] * n(sec)
    for ratio, amp, dec in partials:
        ph = random.random() * TAU
        for i in range(len(out)):
            t = i / SR
            out[i] += math.sin(ph + TAU * f * ratio * t * (1 + 0.0008 * math.sin(TAU * 1.7 * t))) * amp * math.exp(-t * dec / 1.3)
    strike = [s * math.exp(-i / SR * 60) for i, s in enumerate(noise(n(0.1)))]
    return fade(mix(out, gain(strike, 0.5)), 0.001, 0.4)


def wind_loop(sec):
    L = n(sec)
    out = []
    y = 0
    for i in range(L):
        t = i / SR
        a = 0.01 + 0.015 * (1 + math.sin(TAU * t / 7.0)) * (1 + 0.5 * math.sin(TAU * t / 2.3))
        y += a * (random.uniform(-1, 1) - y)
        out.append(y)
    drone = mix(tone(55, sec, 0.25, 0, vib=0.004, vib_rate=0.2), tone(82.4, sec, 0.12, 0, vib=0.006, vib_rate=0.13),
                tone(58.3, sec, 0.12, 0))
    return loop_xfade(mix(gain(out, 3.0), drone), 1.0)


def organ_loop(sec):
    chords = [(110, 130.8, 164.8), (103.8, 130.8, 155.6), (98, 116.5, 146.8), (103.8, 123.5, 155.6)]
    seg = sec / len(chords)
    out = []
    for ch in chords:
        part = [0.0] * n(seg)
        for f in ch:
            for h, a in ((1, 1), (2, 0.5), (3, 0.25), (4, 0.15), (0.5, 0.4)):
                ph = random.random() * TAU
                for i in range(len(part)):
                    part[i] += math.sin(ph + TAU * f * h * i / SR) * a * 0.12
        for i in range(len(part)):
            part[i] *= min(1, i / n(1.0), (len(part) - i) / n(1.0)) * (0.85 + 0.15 * math.sin(TAU * 5 * i / SR))
        out += part
    return loop_xfade(out, 0.8)


def heartbeat():
    s = [0.0] * n(1.0)
    for t0, a in ((0.0, 1.0), (0.22, 0.7)):
        b = tone(48, 0.2, a, 25)
        for i, v in enumerate(b):
            s[n(t0) + i] += v
    return s


def boss_loop(sec):
    bpm = 132
    beat = 60 / bpm
    L = n(sec)
    out = [0.0] * L
    t = 0.0
    k = 0
    bass_notes = [55, 55, 65.4, 51.9]
    while t < sec - 0.3:
        kk = tone(50, 0.3, 1.0, 14)
        for i, v in enumerate(kk):
            j = n(t) + i
            if j < L:
                out[j] += v * 0.9
        f = bass_notes[(k // 8) % 4]
        bs = [math.copysign(1, math.sin(TAU * f * i / SR)) * 0.18 * math.exp(-i / SR * 5) for i in range(n(beat / 2))]
        bs = lowpass(bs, 0.08)
        for off in (0, n(beat / 2)):
            for i, v in enumerate(bs):
                j = n(t) + off + i
                if j < L:
                    out[j] += v * 3
        if k % 2 == 1:
            hh = [s * math.exp(-i / SR * 40) for i, s in enumerate(highpass(noise(n(0.1)), 0.3))]
            for i, v in enumerate(hh):
                j = n(t) + i
                if j < L:
                    out[j] += v * 0.35
        t += beat
        k += 1
    stab = [0.0] * L
    for bar in range(int(sec / (beat * 4))):
        f = [220, 207.6, 233.1, 196][bar % 4]
        st = n(bar * beat * 4)
        for i in range(n(beat * 3)):
            if st + i < L:
                tt = i / SR
                stab[st + i] += (math.sin(TAU * f * tt) + 0.5 * math.sin(TAU * f * 1.5 * tt) + 0.3 * math.sin(TAU * f * 2.02 * tt)) * 0.08 * math.exp(-tt * 1.5)
    return mix(out, stab)


def music_box(notes, step, reverse=False, detune=0.0):
    L = n(len(notes) * step + 2.0)
    out = [0.0] * L
    for idx, midi in enumerate(notes):
        if midi is None:
            continue
        f = 440 * 2 ** ((midi - 69) / 12) * (1 + detune * random.uniform(-1, 1))
        o = n(idx * step)
        for i in range(n(2.0)):
            tt = i / SR
            v = (math.sin(TAU * f * tt) + 0.3 * math.sin(TAU * f * 4.07 * tt) * math.exp(-tt * 8)) * math.exp(-tt * 2.2) * 0.3
            if o + i < L:
                out[o + i] += v
    if reverse:
        out = out[::-1]
    return fade(out, 0.01, 0.5)


LULLABY = [69, 72, 76, 74, 72, 71, 72, 69, None, 69, 72, 76, 77, 76, 74, 72, 71, None, 68, 71, 74, 72, 71, 69, 68, 69, None, None]


def screech():
    L = n(1.3)
    out = []
    ph = ph2 = 0
    for i in range(L):
        t = i / SR
        f = 900 + 600 * math.sin(TAU * 7 * t) + 1400 * t
        ph += TAU * f / SR
        ph2 += TAU * f * 1.414 / SR
        out.append((math.sin(ph) + 0.6 * math.sin(ph2) + random.uniform(-.6, .6)) * min(1, t * 20) * math.exp(-t * 1.5))
    return fade(mix(out, gain(bell(1.3, 70, 2.0), 0.8)))


def splash():
    L = n(1.2)
    nz = lowpass(noise(L), 0.25)
    return fade([s * math.exp(-i / SR * 3) for i, s in enumerate(nz)], 0.005, 0.3)


def creak():
    L = n(1.1)
    out = []
    ph = 0
    for i in range(L):
        t = i / SR
        f = 180 + 60 * math.sin(TAU * 1.3 * t) + 40 * random.uniform(-1, 1)
        ph += TAU * f / SR
        pulse = 1.0 if (ph % TAU) < 0.6 else 0.0
        out.append(pulse * 0.6 * math.sin(math.pi * t / 1.1))
    return fade(lowpass(out, 0.3))


def pickup():
    return fade(mix(tone(880, 0.25, 0.5, 10), [0] * n(0.07) + tone(1318.5, 0.3, 0.5, 9)))


def step_snd(seed):
    rng = random.Random(seed)
    L = n(0.12)
    return fade([s * math.exp(-i / SR * 45) for i, s in enumerate(lowpass([rng.uniform(-1, 1) for _ in range(L)], 0.12))], 0.001, 0.02)


def whoosh_orb():
    L = n(0.8)
    out = []
    ph = 0
    for i in range(L):
        t = i / SR
        ph += TAU * (300 - 200 * t) / SR
        out.append(math.sin(ph) * 0.4 * math.sin(math.pi * t / 0.8) + random.uniform(-.2, .2) * math.sin(math.pi * t / 0.8))
    return fade(out)


def chant_loop(sec):
    voices = []
    for k, base in enumerate((98, 110, 123.5, 146.8)):
        v = formant_voice(sec, base, [O, U, A, O, U, E, O], rough=0.15, seed=10 + k)
        voices.append(gain(v, 0.6))
    return loop_xfade(mix(*voices, tone(49, sec, 0.2)), 1.0)


def main():
    os.makedirs(OUT, exist_ok=True)
    random.seed(1234)
    write("pistol", gunshot(0.45, 140, 16, 0.6, 0.35))
    write("shotgun", gunshot(0.8, 80, 7, 0.7, 0.25))
    write("magnum", gunshot(1.1, 60, 5, 0.9, 0.3))
    write("empty", click(3000, 0.05))
    write("reload", reload_snd())
    write("knife", swish())
    write("flesh", flesh())
    write("kick", kick())
    for k, (base, vw) in enumerate([(110, [A, O, U]), (95, [E, A, O]), (130, [O, A, E, A]), (85, [U, O, A])]):
        write(f"groan{k}", formant_voice(0.9 + 0.2 * k, base, vw, 0.45, seed=k))
    write("death", formant_voice(1.3, 90, [A, O, U, U], 0.6, seed=9))
    write("roar", mix(formant_voice(1.8, 60, [A, A, O, U], 0.9, seed=21), gain(lowpass(noise(n(1.8)), 0.1), 0.6)))
    write("boss_roar", mix(formant_voice(2.6, 42, [U, O, A, A, O], 1.0, seed=31), gain(bell(2.6, 45, 0.3), 0.5)))
    write("hurt", formant_voice(0.35, 150, [A, E], 0.3, seed=7))
    write("bell", bell(6.0, 110))
    write("bell_low", bell(3.0, 98))
    write("bell_mid", bell(3.0, 146.8))
    write("bell_high", bell(3.0, 196, 1.3))
    write("amb_wind", wind_loop(24.0))
    write("amb_organ", organ_loop(20.0))
    write("amb_chant", chant_loop(12.0))
    write("heartbeat", heartbeat())
    write("boss_music", boss_loop(14.55))
    write("musicbox", music_box(LULLABY, 0.42))
    write("musicbox_rev", music_box(LULLABY, 0.5, reverse=True, detune=0.02))
    write("screech", screech())
    write("splash", splash())
    write("door", creak())
    write("pickup", pickup())
    for k in range(3):
        write(f"step{k}", step_snd(k))
    write("orb", whoosh_orb())
    write("coins", mix(click(4200, 0.06), [0] * n(0.05) + click(5200, 0.06), [0] * n(0.11) + click(4700, 0.08)))


if __name__ == "__main__":
    main()
