-- Hyperdertale - every sound in the game is synthesised at runtime.
-- No audio files ship with the project; songs are note tables rendered into
-- SoundData the first time they are played.

local Audio = {}

local RATE = 22050
local songs, sfx = {}, {}
local cache = {}
local current, currentName = nil, nil
local muted = false

-- Semitone offset from A4 for each note name.
local STEPS = {
  C = -9, ["C#"] = -8, D = -7, ["D#"] = -6, E = -5, F = -4,
  ["F#"] = -3, G = -2, ["G#"] = -1, A = 0, ["A#"] = 1, B = 2,
}

local function freq(name)
  if name == "-" then return 0 end
  local letter = name:sub(1, -2)
  local octave = tonumber(name:sub(-1))
  local step = STEPS[letter]
  if not step or not octave then return 0 end
  return 440 * 2 ^ ((step + (octave - 4) * 12) / 12)
end

-- ---- waveforms -------------------------------------------------------------

local function square(phase, duty)
  return (phase % 1) < (duty or 0.5) and 1 or -1
end

local function triangle(phase)
  return 4 * math.abs((phase % 1) - 0.5) - 1
end

local function saw(phase)
  return 2 * (phase % 1) - 1
end

local WAVES = {square = square, triangle = triangle, saw = saw}

-- ---- songs -----------------------------------------------------------------
-- Each entry is {note, beats}. These melodies are original to Hyperdertale.

songs.title = {
  tempo = 96, gain = 0.30,
  tracks = {
    {wave = "square", gain = 0.5, duty = 0.5, notes = {
      {"E4", 2}, {"G4", 1}, {"A4", 3}, {"G4", 1}, {"E4", 2}, {"D4", 2},
      {"C4", 2}, {"D4", 1}, {"E4", 3}, {"D4", 1}, {"C4", 2}, {"A3", 2},
    }},
    {wave = "triangle", gain = 0.6, notes = {
      {"A2", 2}, {"A2", 2}, {"E2", 2}, {"E2", 2},
      {"F2", 2}, {"F2", 2}, {"G2", 2}, {"G2", 2},
    }},
  },
}

songs.overworld = {
  tempo = 128, gain = 0.26,
  tracks = {
    {wave = "square", gain = 0.45, duty = 0.25, notes = {
      {"A4", 1}, {"C5", 1}, {"E5", 1}, {"D5", 1}, {"C5", 1}, {"A4", 1}, {"G4", 2},
      {"F4", 1}, {"A4", 1}, {"C5", 1}, {"B4", 1}, {"A4", 1}, {"G4", 1}, {"E4", 2},
    }},
    {wave = "triangle", gain = 0.55, notes = {
      {"A2", 2}, {"A2", 2}, {"E2", 2}, {"E2", 2},
      {"F2", 2}, {"F2", 2}, {"G2", 2}, {"G2", 2},
    }},
  },
}

songs.battle = {
  tempo = 160, gain = 0.30,
  tracks = {
    {wave = "square", gain = 0.42, duty = 0.5, notes = {
      {"D4", 1}, {"D4", 1}, {"D5", 1}, {"A4", 2}, {"G#4", 1}, {"G4", 1}, {"F4", 1},
      {"D4", 1}, {"F4", 1}, {"G4", 1},
      {"C4", 1}, {"C4", 1}, {"D5", 1}, {"A4", 2}, {"G#4", 1}, {"G4", 1}, {"F4", 1},
      {"D4", 1}, {"F4", 1}, {"G4", 1},
    }},
    {wave = "triangle", gain = 0.6, notes = {
      {"D2", 1}, {"D2", 1}, {"D2", 1}, {"D2", 1}, {"D2", 1}, {"D2", 1},
      {"C2", 1}, {"C2", 1}, {"C2", 1}, {"C2", 1},
      {"A#1", 1}, {"A#1", 1}, {"A#1", 1}, {"A#1", 1}, {"A#1", 1},
      {"A1", 1}, {"A1", 1}, {"A1", 1}, {"A1", 1}, {"A1", 1},
    }},
  },
}

songs.gameover = {
  tempo = 60, gain = 0.28,
  tracks = {
    {wave = "triangle", gain = 0.6, notes = {
      {"A3", 3}, {"G3", 1}, {"F3", 3}, {"E3", 1}, {"D3", 4},
      {"-", 2}, {"C3", 2}, {"A2", 4},
    }},
  },
}

songs.rest = {
  tempo = 80, gain = 0.24,
  tracks = {
    {wave = "triangle", gain = 0.5, notes = {
      {"C4", 2}, {"E4", 2}, {"G4", 2}, {"E4", 2},
      {"F4", 2}, {"A4", 2}, {"G4", 4},
    }},
  },
}

--- Render one song table into a looping SoundData.
local function renderSong(spec)
  local beat = 60 / spec.tempo

  local longest = 0
  for _, track in ipairs(spec.tracks) do
    local beats = 0
    for _, note in ipairs(track.notes) do beats = beats + note[2] end
    longest = math.max(longest, beats)
  end

  local frames = math.max(1, math.floor(longest * beat * RATE))
  local data = love.sound.newSoundData(frames, RATE, 16, 1)
  local mix = {}
  for i = 0, frames - 1 do mix[i] = 0 end

  for _, track in ipairs(spec.tracks) do
    local wave = WAVES[track.wave] or square
    local offset = 0
    for _, note in ipairs(track.notes) do
      local f = freq(note[1])
      local length = note[2] * beat
      local count = math.floor(length * RATE)
      if f > 0 then
        local sustain = math.floor(count * 0.9)
        for i = 0, count - 1 do
          local index = offset + i
          if index >= frames then break end
          local t = i / RATE
          -- Short attack, long decay: enough shape to sound plucked.
          local env
          if i < 120 then
            env = i / 120
          elseif i < sustain then
            env = 1 - 0.55 * (i - 120) / math.max(1, sustain - 120)
          else
            env = 0
          end
          mix[index] = mix[index] + wave(t * f, track.duty) * env * (track.gain or 0.5)
        end
      end
      offset = offset + count
    end
  end

  for i = 0, frames - 1 do
    local v = mix[i] * spec.gain
    if v > 1 then v = 1 elseif v < -1 then v = -1 end
    data:setSample(i, v)
  end

  return data
end

-- ---- sound effects ---------------------------------------------------------
-- Each generator writes `count` samples through a callback.

local function renderSfx(seconds, generator)
  local frames = math.max(1, math.floor(seconds * RATE))
  local data = love.sound.newSoundData(frames, RATE, 16, 1)
  for i = 0, frames - 1 do
    local v = generator(i / RATE, i / frames)
    if v > 1 then v = 1 elseif v < -1 then v = -1 end
    data:setSample(i, v)
  end
  return data
end

local SFX = {
  blip = function ()
    return renderSfx(0.05, function (t, p)
      return square(t * 660) * (1 - p) * 0.30
    end)
  end,
  select = function ()
    return renderSfx(0.09, function (t, p)
      return square(t * 880) * (1 - p) * 0.35
    end)
  end,
  move = function ()
    return renderSfx(0.05, function (t, p)
      return square(t * 440) * (1 - p) * 0.28
    end)
  end,
  cancel = function ()
    return renderSfx(0.11, function (t, p)
      return square(t * 300) * (1 - p) * 0.32
    end)
  end,
  slash = function ()
    return renderSfx(0.26, function (t, p)
      return (math.random() * 2 - 1) * (1 - p) ^ 2 * 0.55
    end)
  end,
  hurt = function ()
    return renderSfx(0.30, function (t, p)
      local tone = saw(t * (240 - 140 * p)) * 0.4
      local grit = (math.random() * 2 - 1) * 0.25
      return (tone + grit) * (1 - p) ^ 1.5
    end)
  end,
  heal = function ()
    return renderSfx(0.36, function (t, p)
      local f = p < 0.33 and 523 or (p < 0.66 and 659 or 784)
      return triangle(t * f) * (1 - p) * 0.4
    end)
  end,
  spare = function ()
    return renderSfx(0.5, function (t, p)
      local f = p < 0.3 and 659 or (p < 0.6 and 784 or 988)
      return triangle(t * f) * (1 - p) * 0.4
    end)
  end,
  save = function ()
    return renderSfx(0.34, function (t, p)
      local f = p < 0.4 and 1046 or 1318
      return triangle(t * f) * (1 - p) * 0.35
    end)
  end,
  encounter = function ()
    return renderSfx(0.45, function (t, p)
      local tone = saw(t * 110) * 0.35
      local grit = (math.random() * 2 - 1) * 0.3
      return (tone + grit) * (1 - p) * 0.9
    end)
  end,
  levelup = function ()
    return renderSfx(0.6, function (t, p)
      local steps = {523, 659, 784, 1046}
      local f = steps[math.min(4, math.floor(p * 4) + 1)]
      return square(t * f) * (1 - p * 0.6) * 0.32
    end)
  end,
  jump = function ()
    return renderSfx(0.16, function (t, p)
      -- A short rising blip, so the hop reads even without looking down.
      return square(t * (380 + 320 * p)) * (1 - p) * 0.30
    end)
  end,
  land = function ()
    return renderSfx(0.10, function (t, p)
      return (math.random() * 2 - 1) * (1 - p) ^ 2 * 0.28
    end)
  end,
  pickup = function ()
    return renderSfx(0.34, function (t, p)
      local f = p < 0.5 and 784 or 1046
      return square(t * f) * (1 - p) * 0.30
    end)
  end,
  menu = function ()
    return renderSfx(0.07, function (t, p)
      return square(t * 520) * (1 - p) * 0.26
    end)
  end,
}

-- ---- public API ------------------------------------------------------------

function Audio.load()
  -- Effects are tiny, so they are built up front; songs stay lazy.
  for name, build in pairs(SFX) do
    local ok, data = pcall(build)
    if ok then sfx[name] = love.audio.newSource(data, "static") end
  end
end

function Audio.play(name)
  if currentName == name then return end
  Audio.stop()
  local spec = songs[name]
  if not spec then return end

  if not cache[name] then
    local ok, data = pcall(renderSong, spec)
    if not ok then return end
    cache[name] = love.audio.newSource(data, "static")
    cache[name]:setLooping(true)
  end

  current, currentName = cache[name], name
  current:setVolume(muted and 0 or 1)
  current:play()
end

function Audio.stop()
  if current then current:stop() end
  current, currentName = nil, nil
end

function Audio.playing() return currentName end

function Audio.sfx(name)
  if muted then return end
  local source = sfx[name]
  if not source then return end
  source:stop()
  source:play()
end

function Audio.toggleMute()
  Audio.setEnabled(muted)
  return muted
end

--- Turn all sound on or off; the settings screen drives this.
function Audio.setEnabled(enabled)
  muted = not enabled
  love.audio.setVolume(muted and 0 or 1)
  if muted then
    if current then current:pause() end
  elseif current then
    current:play()
  end
end

function Audio.isEnabled() return not muted end

function Audio.isMuted() return muted end

return Audio
