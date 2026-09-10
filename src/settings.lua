-- Hyperdertale - player preferences, kept separately from the save file so
-- they survive starting a new game.

local Save = require("src.save")
local Audio = require("src.audio")

local Settings = {}

local FILE = "hyperdertale.cfg"

local SCALE_LABELS = {"SMALL", "MEDIUM", "LARGE"}
local SCALE_VALUES = {0.78, 1.0, 1.28}

local function defaults()
  return {
    sound = true,
    controls = "dpad",   -- "dpad" or "stick"
    buttonSize = 2,      -- index into SCALE_VALUES
    touchUI = "auto",    -- "auto", "on" or "off"
  }
end

Settings.data = defaults()

Settings.scaleLabels = SCALE_LABELS

function Settings.buttonScale()
  return SCALE_VALUES[Settings.data.buttonSize] or 1.0
end

function Settings.load()
  local ok = false
  if love.filesystem.getInfo(FILE) then
    local text = love.filesystem.read(FILE)
    if text then
      local parsed = Save.decode(text)
      if type(parsed) == "table" then
        local merged = defaults()
        for key, value in pairs(merged) do
          if parsed[key] ~= nil and type(parsed[key]) == type(value) then
            merged[key] = parsed[key]
          end
        end
        Settings.data = merged
        ok = true
      end
    end
  end
  return ok
end

function Settings.save()
  return love.filesystem.write(FILE, Save.encode(Settings.data)) == true
end

--- Push the current settings into the systems that act on them.
function Settings.apply()
  local Input = require("src.input")
  Audio.setEnabled(Settings.data.sound)
  Input.setStyle(Settings.data.controls)
  Input.setButtonScale(Settings.buttonScale())
  if Settings.data.touchUI == "on" then
    Input.showTouch = true
  elseif Settings.data.touchUI == "off" then
    Input.showTouch = false
  end
end

return Settings
