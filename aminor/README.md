# aminor

A minimal norns script that teaches the SuperCollider ↔ Lua split.

It plays long sine notes drawn from the **A harmonic minor scale**
(`a b c d e f g#`), each one fading in, sustaining, fading out, then pausing —
forever, until you stop it. You can layer many independent voices that drift
out of sync with each other.

## Controls

- **K2** — start
- **K3** — stop
- **E2** — number of simultaneous voices (**1–40**, starts at 1)
- **E3** — master amplitude / overall mix level (0.00–1.00)

## What one voice does each cycle

1. pick a **weighted** random pitch (see weights below)
2. pick a random octave (3–6, four octaves)
3. fade in from amplitude **0** to **0.5**
4. sustain
5. fade out
6. pause
7. repeat with a fresh pitch + octave

Each envelope stage (fade in, sustain, fade out, pause) is **randomised per
note** between a **min** and **max** you set in the **PARAMS** menu, so no two
notes have the same shape.

### Note weights

Pitches are not chosen evenly — each has a weight (edit the `NOTES` table in
`aminor.lua` to retune). Defaults:

| note | weight | chance |
|------|--------|--------|
| a    | 5      | ~33%   |
| e    | 3      | 20%    |
| c    | 2      | ~13%   |
| d    | 2      | ~13%   |
| b    | 1      | ~7%    |
| f    | 1      | ~7%    |
| g#   | 1      | ~7%    |

The weights don't need to sum to any particular total — the script totals them
at pick time.

### Voices (E2)

Each voice is its own independent loop with its own random note and envelope.
With **more than one voice**, a random pause is applied **before** each note
(rather than after) so the voices start at different times and drift apart.
Turning E2 up while playing spawns more voices live; turning it down removes
them.

> Many voices add up. 40 notes each peaking at 0.5 will clip hard — use
> **E3** to pull the master level down as you raise the voice count.

## The two files

| File | Language | Role |
|------|----------|------|
| `Engine_SineNote.sc` | SuperCollider | Makes the sound. Defines the sine + envelope `SynthDef`, a shared master-amplitude bus, and exposes `playNote(freq, fadeIn, sustain, fadeOut)` and `setAmp(level)`. |
| `aminor.lua` | Lua | The interface + logic. Handles keys/encoders, draws the screen, picks weighted notes, runs the voice loops, and calls the engine commands. |

They are linked by two matching names:

- Lua: `engine.name = "SineNote"`
- SC:  `Engine_SineNote : CroneEngine`

### Where the timing lives

The **envelope in the engine** (`EnvGen` / `Env`) does the fade in → sustain →
fade out at audio rate, so the volume is perfectly smooth. `doneAction:
Done.freeSelf` frees each note synth automatically when it finishes.

The **Lua clock coroutines** only handle the *coarse* scheduling: wait for the
note to finish, wait the pause, then trigger the next note. `clock.sleep()`
inside a `clock.run()` is the idiomatic norns way to sequence over time
without blocking the UI — and each voice gets its own coroutine.

### Where the master level lives

**E3** doesn't touch each note in Lua. Instead the engine holds one
**control bus** (`ampBus`); every note synth reads it live with `In.kr` and
multiplies its output by it. So `setAmp` changes the level of notes that are
*already sounding*, not just future ones.

## Install on hardware / a norns install

Copy this whole `aminor` folder into your norns at:

```
~/dust/code/aminor/
```

(e.g. over the WiFi/USB `dust` share, or `scp -r aminor we@norns.local:~/dust/code/`)

Then on the norns: **SELECT > aminor**, and press **K2** to start.

The `.sc` engine is compiled by SuperCollider when the script loads. If you
edit `Engine_SineNote.sc`, you must reload the script (or restart audio) for
SuperCollider to pick up the change — editing only the `.lua` just needs a
script reload.

## Things to try (to keep learning)

- Change the wave: swap `SinOsc` for `Saw` or `Pulse` in the engine.
- Auto-scale the level by voice count (e.g. divide by `sqrt(voices)`) so the
  overall loudness stays roughly constant as you raise E2.
- Expose the note weights as PARAMS so you can retune them live instead of
  editing the `NOTES` table.
- Make **K3** cut sounding notes immediately by adding a gated envelope in the
  engine and a `stopNote` command (right now K3 stops *scheduling* and any
  current notes finish their fade naturally).
