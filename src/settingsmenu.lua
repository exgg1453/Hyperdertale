-- Hyperdertale - the settings panel. It is a widget rather than a scene so the
-- title screen and the in-game menu can both show the same one.

local Draw = require("src.draw")
local Input = require("src.input")
local Audio = require("src.audio")
local Sprites = require("src.sprites")
local Settings = require("src.settings")

local Menu = {}
Menu.__index = Menu

local function isMobile()
  local os_name = love.system.getOS()
  return os_name == "Android" or os_name == "iOS"
end

local function buildRows()
  local data = Settings.data
  local rows = {
    {
      label = "SOUND",
      value = function () return data.sound and "ON" or "OFF" end,
      change = function () data.sound = not data.sound end,
    },
    {
      label = "CONTROLS",
      value = function () return data.controls == "stick" and "JOYSTICK" or "D-PAD" end,
      change = function ()
        data.controls = (data.controls == "stick") and "dpad" or "stick"
      end,
    },
    {
      label = "BUTTON SIZE",
      value = function () return Settings.scaleLabels[data.buttonSize] end,
      change = function (step)
        data.buttonSize = data.buttonSize + step
        if data.buttonSize < 1 then data.buttonSize = 3 end
        if data.buttonSize > 3 then data.buttonSize = 1 end
      end,
    },
    {
      label = "TOUCH PAD",
      value = function () return string.upper(data.touchUI) end,
      change = function (step)
        local order = {"auto", "on", "off"}
        local index = 1
        for i, name in ipairs(order) do
          if order[i] == data.touchUI then index = i end
        end
        index = index + step
        if index < 1 then index = #order end
        if index > #order then index = 1 end
        data.touchUI = order[index]
      end,
    },
  }

  if not isMobile() then
    rows[#rows + 1] = {
      label = "FULLSCREEN",
      value = function () return love.window.getFullscreen() and "ON" or "OFF" end,
      change = function ()
        love.window.setFullscreen(not love.window.getFullscreen())
      end,
    }
  end

  rows[#rows + 1] = {label = "BACK", back = true}
  return rows
end

function Menu.new()
  local self = setmetatable({}, Menu)
  self.rows = buildRows()
  self.index = 1
  return self
end

--- Returns true on the frame the player leaves the panel.
function Menu:update(dt)
  if Input.pressed("up") then
    self.index = self.index > 1 and self.index - 1 or #self.rows
    Audio.sfx("move")
  elseif Input.pressed("down") then
    self.index = self.index < #self.rows and self.index + 1 or 1
    Audio.sfx("move")
  end

  local row = self.rows[self.index]

  local step = 0
  if Input.pressed("right") then step = 1
  elseif Input.pressed("left") then step = -1 end

  if row and row.change and step ~= 0 then
    row.change(step)
    Audio.sfx("select")
    Settings.apply()
    Settings.save()
    -- Changing the pad style rebuilds the buttons, so re-read the labels.
    return false
  end

  if Input.pressed("confirm") then
    if row and row.back then
      Audio.sfx("cancel")
      Settings.save()
      return true
    elseif row and row.change then
      row.change(1)
      Audio.sfx("select")
      Settings.apply()
      Settings.save()
    end
  end

  if Input.pressed("cancel") or Input.pressed("menu") then
    Audio.sfx("cancel")
    Settings.save()
    return true
  end

  return false
end

function Menu:draw(x, y, w, h)
  Draw.box(x, y, w, h)
  Draw.textCentered("SETTINGS", x + w / 2, y + 8, {1, 1, 0.2})

  local top = y + 26
  for i, row in ipairs(self.rows) do
    local rowY = top + (i - 1) * 14
    local selected = i == self.index

    if selected then
      Draw.pixels(Sprites.heart, x + 10, rowY + 1, 1, Sprites.palette.heart)
    end

    local color = selected and {1, 1, 0.2} or {1, 1, 1}
    Draw.text(row.label, x + 22, rowY, color)

    if row.value then
      local text = "< " .. row.value() .. " >"
      Draw.text(text, x + w - 12 - Draw.measure(text), rowY, color)
    end
  end

  Draw.text("ARROWS CHANGE     X BACK", x + 22, y + h - 14, {0.5, 0.5, 0.5})
end

return Menu
