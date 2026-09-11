-- Hyperdertale - title screen and main menu.

local Draw = require("src.draw")
local Input = require("src.input")
local Audio = require("src.audio")
local Save = require("src.save")
local Sprites = require("src.sprites")
local SettingsMenu = require("src.settingsmenu")
local Game = require("src.game")

local Title = {}

local function buildMenu()
  local items = {}
  if Save.exists() then
    items[#items + 1] = {label = "CONTINUE", action = "continue"}
  end
  items[#items + 1] = {label = "NEW GAME", action = "new"}
  items[#items + 1] = {label = "SETTINGS", action = "settings"}
  if love.system.getOS() ~= "Android" and love.system.getOS() ~= "iOS" then
    items[#items + 1] = {label = "QUIT", action = "quit"}
  end
  return items
end

function Title:enter()
  self.menu = buildMenu()
  self.index = 1
  self.time = 0
  self.confirmingNew = false
  self.settings = nil
  Audio.play("title")
end

function Title:choose()
  local item = self.menu[self.index]
  if not item then return end

  if item.action == "settings" then
    Audio.sfx("select")
    self.settings = SettingsMenu.new()
    return
  end

  if item.action == "quit" then
    love.event.quit()
    return
  end

  if item.action == "continue" then
    Audio.sfx("select")
    Save.read()
    Game.switch("overworld", {room = Save.player.room, resume = true})
    return
  end

  if item.action == "new" then
    -- Starting over throws away a run, so ask first when one exists.
    if Save.exists() and not self.confirmingNew then
      self.confirmingNew = true
      Audio.sfx("select")
      return
    end
    Audio.sfx("select")
    Game.switch("naming")
  end
end

function Title:update(dt)
  self.time = self.time + dt

  if self.settings then
    if self.settings:update(dt) then self.settings = nil end
    return
  end

  if self.confirmingNew then
    if Input.pressed("confirm") then
      Audio.sfx("select")
      Game.switch("naming")
    elseif Input.pressed("cancel") or Input.pressed("menu") then
      self.confirmingNew = false
      Audio.sfx("cancel")
    end
    return
  end

  if Input.pressed("up") then
    self.index = self.index > 1 and self.index - 1 or #self.menu
    Audio.sfx("move")
  elseif Input.pressed("down") then
    self.index = self.index < #self.menu and self.index + 1 or 1
    Audio.sfx("move")
  end

  if Input.pressed("confirm") then self:choose() end
end

function Title:draw()
  Draw.clear({0, 0, 0})

  -- Title, with a soft shadow so the letters read against the black.
  Draw.textScaledCentered("HYPERDERTALE", Draw.W / 2 + 1, 43, 3, {0.35, 0.06, 0.06})
  Draw.textScaledCentered("HYPERDERTALE", Draw.W / 2, 42, 3, {1, 1, 1})
  Draw.textCentered("A FAN GAME BUILT FROM SCRATCH", Draw.W / 2, 78, {0.6, 0.6, 0.6})

  Draw.pixels(Sprites.heart, Draw.W / 2 - 14, 96, 4, Sprites.palette.heart)

  if self.settings then
    self.settings:draw(20, 26, 280, 176)
    return
  end

  if self.confirmingNew then
    Draw.box(40, 150, 240, 56)
    Draw.textCentered("ERASE YOUR SAVED RUN?", Draw.W / 2, 164)
    Draw.textCentered("Z - YES     X - NO", Draw.W / 2, 182, {0.75, 0.75, 0.75})
    return
  end

  local top = 152
  for i, item in ipairs(self.menu) do
    local y = top + (i - 1) * 16
    local selected = i == self.index
    if selected then
      Draw.pixels(Sprites.heart, Draw.W / 2 - Draw.measure(item.label) / 2 - 22, y + 1, 2,
        Sprites.palette.heart)
    end
    Draw.textCentered(item.label, Draw.W / 2, y, selected and {1, 1, 0.2} or {0.8, 0.8, 0.8})
  end

  local hint = Input.showTouch and "TAP Z TO CONFIRM" or "Z CONFIRM   X CANCEL   ARROWS MOVE"
  Draw.textCentered(hint, Draw.W / 2, Draw.H - 16, {0.45, 0.45, 0.45})
end

return Title
