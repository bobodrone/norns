# norns patches

A small collection of [norns](https://monome.org/docs/norns/) scripts by
@bobodrone, each a self-contained Lua UI + SuperCollider engine, and each a
readable example of the norns ⇄ SuperCollider split. Two are drone / generative
sound tools built around plain sine (and friends) oscillators; one is a
real-time effect that mangles the audio inputs.

| Patch | What it is | Sound |
|-------|-----------|-------|
| [`aminor`](https://github.com/bobodrone/aminor) | A weighted **random note generator** in the A harmonic minor scale. | Layered long tones (sine/saw/pulse) fading in and out, forever. |
| [`drifting`](https://github.com/bobodrone/drifting) | A 21-oscillator **additive drone** — one fundamental plus its harmonics, reshaped live. | Evolving overtone drones, from pure sine to buzzing to shimmering clusters. |
| [`illfanas`](https://github.com/bobodrone/illfanas) | A real-time stereo **input mangler** that flips the signal toward the amplitude rails. | Hard, wavefolder-ish distortion, from subtle grit to brutal near-square. |

Each folder has its own detailed `README.md`; the summaries below are the quick tour.

---

## aminor

A generative sequencer that keeps choosing notes from the **A harmonic minor**
scale (`a b c d e f g#`) and plays them as long, overlapping tones — each one
fading in, sustaining, fading out, and pausing.

- **E2** — number of simultaneous voices (**1–42**), each an independent loop
  that drifts out of sync with the others.
- **E3** — master amplitude.
- **K3** start · **K2** stop.
- **PARAMS** — waveform (sine/saw/pulse), per-stage envelope min/max, and
  **weighted** note + octave probabilities (7 notes × 6 octaves = 42 tones).

Good for slowly shifting, semi-random tonal beds. See
[`aminor/README.md`](https://github.com/bobodrone/aminor/blob/main/README.md).

## drifting

An **additive drone**: 21 sine oscillators sound at once. Oscillator 1 is the
fundamental; the other 20 are harmonics whose spacing and balance you sculpt in
real time.

- **E1** — base pitch (`0.05–1000 Hz`, exponential).
- **E2** — amplitude **tilt** across the partials (fundamental ↔ equal ↔ top).
- **E3** — harmonic **spacing** (`0` = all on the fundamental, `1.0` = natural
  overtone series, up to `4.0`).
- **K3** — drone on/off · **K2** (tap) — reset E1/E2/E3.
- **Shifts** — **K1+E3** master level; **K2+E2 / K2+E3** set the speed of two
  slow triangle **LFOs** that sweep tilt and spacing on their own.
- **PARAMS** — master level, per-oscillator **drift** (detune/shimmer, so the
  partials don't phase-lock into a "motorboat" pulse), and LFO speeds/depths.

Good for glacial, mutating overtone textures. See
[`drifting/README.md`](https://github.com/bobodrone/drifting/blob/main/README.md).

## illfänas

*Old Swedish for "make a racket".* A real-time **input mangler**: it reads the
two audio inputs, flips every sample toward the `±1` amplitude rails while
keeping its sign (`flip(x) = sign(x)·(warp − |x|)`), and sends the result back
out — so quiet parts get thrown loud and loud parts pulled quiet.

- **E1** — combined **DJ filter** (CCW lowpass · 12 o'clock thru · CW highpass).
- **E2** — **warp**: how extreme the flip is (`0` mild → `1` the flip → `2`
  brutal, near-square).
- **E3** — dry / wet **mix** (`0` = untouched input, `1` = fully flipped).
- **K2+E2** — filter resonance · **K3** — kill: a ~5 s fade of the mix back to
  the dry signal (press again to fade back up).
- **PARAMS** — output level, filter resonance.

Warp and mix both start at **0**, so twist **E2** and **E3** up until happiness
appears. The script does its own dry/wet inside the engine and mutes norns'
input monitor so you don't hear the raw signal twice. See
[`illfanas/README.md`](https://github.com/bobodrone/illfanas/blob/main/README.md).

---

## How a norns patch is built

Every patch here is **two files linked by a name**:

- a **Lua** script (`<name>.lua`) — the UI and logic: keys, encoders, the
  screen, and the timing. It declares `engine.name = "<Name>"`.
- a **SuperCollider** engine (`Engine_<Name>.sc`) — the actual DSP: a
  `CroneEngine` subclass that defines `SynthDef`s and exposes commands the Lua
  side calls (e.g. `engine.setBase(freq)`).

norns loads the matching engine when the script starts. As a rule of thumb:
editing only the `.lua` needs a **script reload**; editing the `.sc` needs a
**full reload / audio restart** so SuperCollider recompiles it.

## Install

Copy a patch folder into your norns at `~/dust/code/`:

```
scp -r drifting we@norns.local:~/dust/code/
```

Then on the device: **SELECT > drifting** (or **aminor** / **illfanas**), and
press **K3**.

## License

[MIT](./LICENSE) © 2026 Fredric Bergström
