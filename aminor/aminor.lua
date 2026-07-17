-- aminor
-- a random sine note generator
--
-- notes drawn from the
-- A harmonic minor scale (weighted):
-- a b c d e f g#
--
-- waveform, envelope min/max and
-- note weights are set in the
-- PARAMS menu.
--
-- E2 : number of voices (1-40)
-- E3 : master amplitude
-- K2 : start
-- K3 : stop

-- Tell norns which SuperCollider engine to load.
-- This must match the class name Engine_SineNote in Engine_SineNote.sc
engine.name = "SineNote"

-- musicutil gives us helpers like note_num_to_freq()
local musicutil = require "musicutil"
-- controlspec describes a param's range/step/default for the PARAMS menu
local controlspec = require "controlspec"
-- util gives us clamp() etc.
local util = require "util"

-- ----------------------------------------------------------------------
-- configuration
-- ----------------------------------------------------------------------

-- the pitches we can choose from, each with a default selection weight.
-- { display name, param-safe id, default weight }
-- higher weight = picked more often. these need not sum to any total.
-- the actual weight used at runtime comes from the "weight_<id>" param.
local NOTES = {
  {"a",  "a",  5},
  {"b",  "b",  1},
  {"c",  "c",  2},
  {"d",  "d",  2},
  {"e",  "e",  3},
  {"f",  "f",  1},
  {"g#", "gs", 1},
}

-- the oscillator waveforms the "waveform" param can choose between.
-- the index (1-based here) maps to the engine's `wave` arg as index-1.
local WAVES = {"sine", "saw", "pulse"}

-- semitone offset of each note relative to C within one octave
local NOTE_SEMITONE = {
  c  = 0,
  d  = 2,
  e  = 4,
  f  = 5,
  ["g#"] = 8,
  a  = 9,
  b  = 11,
}

-- octave range to pick from (4 octaves: 3, 4, 5, 6)
local OCTAVE_MIN = 3
local OCTAVE_MAX = 6

-- how many voices are allowed at once
local VOICES_MIN = 1
local VOICES_MAX = 40

-- the envelope stages we expose as min/max params.
-- { id, display name, spec min, spec max, default min, default max }
local STAGES = {
  {"fade_in",  "fade in",  0, 30, 4,  12},
  {"sustain",  "sustain",  0, 60, 5,  15},
  {"fade_out", "fade out", 0, 30, 3,  8},
  {"pause",    "pause",    0, 30, 2,  8},
}

-- ----------------------------------------------------------------------
-- state
-- ----------------------------------------------------------------------

local playing = false        -- are we currently running?
local voices  = {}           -- clock ids of the active voice loops
local target_voices = 1      -- how many voices we want (E2)
local master_amp = 0.5       -- overall level (E3)
local last_note = ""         -- text of the most recently triggered note

-- ----------------------------------------------------------------------
-- helpers
-- ----------------------------------------------------------------------

-- turn a note name + octave into a frequency in Hz.
-- MIDI note 60 = C4, so: midi = (octave + 1) * 12 + semitone
local function note_to_freq(name, octave)
  local midi = (octave + 1) * 12 + NOTE_SEMITONE[name]
  return musicutil.note_num_to_freq(midi)
end

-- pick a note name using the live weight params.
-- roll a number in [0, total) and walk the list subtracting weights.
local function weighted_note()
  local total = 0
  for _, n in ipairs(NOTES) do total = total + params:get("weight_" .. n[2]) end
  if total <= 0 then return NOTES[1][1] end   -- all weights zeroed: fall back
  local r = math.random() * total
  for _, n in ipairs(NOTES) do
    r = r - params:get("weight_" .. n[2])
    if r <= 0 then return n[1] end
  end
  return NOTES[#NOTES][1]   -- fallback (floating-point safety)
end

-- pick a random float between the _min and _max params of a stage.
-- (guarded so it still works if you set min above max)
local function rand_stage(id)
  local a = params:get(id .. "_min")
  local b = params:get(id .. "_max")
  local lo, hi = math.min(a, b), math.max(a, b)
  return lo + math.random() * (hi - lo)
end

-- one voice: forever picks a note, rolls its envelope, plays it, waits.
-- each voice runs as its own clock coroutine, so voices are independent.
local function voice_loop()
  while true do
    -- with more than one voice, pause BEFORE the note so the voices
    -- start at different times and drift out of sync with each other.
    if target_voices > 1 then
      clock.sleep(rand_stage("pause"))
    end

    -- weighted pitch + random octave -> frequency
    local name = weighted_note()
    local octave = math.random(OCTAVE_MIN, OCTAVE_MAX)
    local freq = note_to_freq(name, octave)

    -- random duration for each envelope stage
    local fade_in  = rand_stage("fade_in")
    local sustain  = rand_stage("sustain")
    local fade_out = rand_stage("fade_out")

    -- current waveform (param is 1-based; engine wants 0-based)
    local wave = params:get("waveform") - 1

    last_note = name .. octave
    engine.playNote(freq, fade_in, sustain, fade_out, wave)
    redraw()

    -- wait out the whole note (the engine's envelope does the fades)
    clock.sleep(fade_in + sustain + fade_out)

    -- for a single voice keep the original trailing pause
    if target_voices <= 1 then
      clock.sleep(rand_stage("pause"))
    end
  end
end

-- start/stop individual voice coroutines so #voices == target_voices.
-- only does anything while playing.
local function match_voices()
  if not playing then return end
  while #voices < target_voices do
    table.insert(voices, clock.run(voice_loop))
  end
  while #voices > target_voices do
    clock.cancel(table.remove(voices))
  end
end

local function start()
  if playing then return end
  playing = true
  voices = {}
  match_voices()
  redraw()
end

local function stop()
  if not playing then return end
  playing = false
  for _, id in ipairs(voices) do clock.cancel(id) end
  voices = {}
  last_note = ""
  -- notes already sounding will finish their envelopes naturally.
  redraw()
end

-- ----------------------------------------------------------------------
-- norns lifecycle callbacks
-- ----------------------------------------------------------------------

function init()
  math.randomseed(os.time())

  -- oscillator waveform (shared by every note).
  params:add_separator("oscillator")
  params:add_option("waveform", "waveform", WAVES, 1)

  -- one min + one max control param per envelope stage.
  -- these show up under PARAMS > EDIT and are saved with the pset.
  params:add_separator("envelope (seconds)")
  for _, s in ipairs(STAGES) do
    local id, name, lo, hi, dmin, dmax = table.unpack(s)
    params:add_control(id .. "_min", name .. " min",
      controlspec.new(lo, hi, "lin", 0.1, dmin, "s"))
    params:add_control(id .. "_max", name .. " max",
      controlspec.new(lo, hi, "lin", 0.1, dmax, "s"))
  end

  -- one integer weight per note (0 = never played).
  params:add_separator("note weights")
  for _, n in ipairs(NOTES) do
    local name, id, default = table.unpack(n)
    params:add_number("weight_" .. id, "weight " .. name, 0, 20, default)
  end

  -- push the starting master amplitude to the engine
  engine.setAmp(master_amp)

  redraw()
end

-- encoders: n = which encoder (1,2,3), d = delta (+/-)
function enc(n, d)
  if n == 2 then
    -- E2: number of simultaneous voices
    target_voices = util.clamp(target_voices + d, VOICES_MIN, VOICES_MAX)
    match_voices()
    redraw()
  elseif n == 3 then
    -- E3: overall amplitude / master mix level
    master_amp = util.clamp(master_amp + d * 0.01, 0, 1)
    engine.setAmp(master_amp)
    redraw()
  end
end

-- keys: n = which key (1,2,3), z = 1 pressed / 0 released
function key(n, z)
  if z == 1 then
    if n == 2 then
      start()
    elseif n == 3 then
      stop()
    end
  end
end

function redraw()
  screen.clear()

  screen.level(15)
  screen.move(0, 10)
  screen.text("aminor")

  screen.move(0, 24)
  screen.level(playing and 15 or 4)
  screen.text(playing and ("playing  (" .. last_note .. ")") or "stopped")

  screen.level(6)
  screen.move(0, 38)
  screen.text("voices: " .. target_voices .. "   wave: " .. WAVES[params:get("waveform")])
  screen.move(0, 48)
  screen.text(string.format("amp: %.2f", master_amp))

  screen.level(3)
  screen.move(0, 62)
  screen.text("E2 voices  E3 amp  K2/3 go")

  screen.update()
end
