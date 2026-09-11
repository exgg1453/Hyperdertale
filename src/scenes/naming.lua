-- Hyperdertale - the naming screen shown once, at the start of a new run.

local Draw = require("src.draw")
local Input = require("src.input")
local Audio = require("src.audio")
local Save = require("src.save")
local Sprites = require("src.sprites")
local Game = require("src.game")

local Naming = {}

local MAX_LENGTH = 6

-- Uppercase only: the generated font draws lowercase with the same glyphs, so
-- a lowercase grid would look identical and just cost the player keystrokes.
local GRID = {
  {"A", "B", "C", "D", "E", "F"},
  {"G", "H", "I", "J", "K", "L"},
  {"M", "N", "O", "P", "Q", "R"},
  {"S", "T", "U", "V", "W", "X"},
  {"Y", "Z", "0", "1", "2", "3"},
  {"4", "5", "6", "7", "8", "9"},
}

local COLS, ROWS = 6, 6
local ACTION_ROW = ROWS + 1

local CELL_W, CELL_H = 34, 18
local GRID_X = (Draw.W - COLS * CELL_W) / 2
local GRID_Y = 66

local ACTIONS = {
  {label = "QUIT", x = 92},
  {label = "DONE", x = 196},
}
local ACTION_Y = GRID_Y + ROWS * CELL_H + 8

function Naming:enter()
  self.name = ""
  self.row = 1
  self.col = 1
  self.blink = 0
  self.confirming = false
  self.confirmIndex = 2   -- default to YES, as the player just chose DONE
  Audio.play("title")
end

-- ---- helpers ---------------------------------------------------------------

function Naming:onActions()
  return self.row == ACTION_ROW
end

function Naming:canFinish()
  return #self.name > 0
end

function Naming:append(char)
  if #self.name >= MAX_LENGTH then
    Audio.sfx("cancel")
    return
  end
  self.name = self.name .. char
  Audio.sfx("select")
end

function Naming:backspace()
  if #self.name == 0 then
    Audio.sfx("cancel")
    return
  end
  self.name = self.name:sub(1, #self.name - 1)
  Audio.sfx("cancel")
end

function Naming:finish()
  -- The old run is only thrown away once a name is actually confirmed, so
  -- backing out of this screen leaves an existing save alone.
  Save.erase()
  Save.reset()
  Save.player.name = self.name
  Audio.sfx("levelup")
  Game.switch("overworld", {room = "ruins_entry", intro = true})
end

-- ---- update ----------------------------------------------------------------

function Naming:updateConfirm()
  if Input.pressed("left") or Input.pressed("right") then
    self.confirmIndex = self.confirmIndex == 1 and 2 or 1
    Audio.sfx("move")
  end

  if Input.pressed("confirm") then
    if self.confirmIndex == 2 then
      self:finish()
    else
      self.confirming = false
      Audio.sfx("cancel")
    end
  elseif Input.pressed("cancel") or Input.pressed("menu") then
    self.confirming = false
    Audio.sfx("cancel")
  end
end

function Naming:move(dx, dy)
  if dx ~= 0 then
    if self:onActions() then
      self.col = self.col == 1 and 2 or 1
    else
      self.col = self.col + dx
      if self.col < 1 then self.col = COLS end
      if self.col > COLS then self.col = 1 end
    end
    Audio.sfx("move")
    return
  end

  if dy > 0 then
    if self:onActions() then
      self.row, self.col = 1, 1            -- wrap back to the top of the grid
    elseif self.row == ROWS then
      -- Drop onto whichever action sits under the current column.
      self.row = ACTION_ROW
      self.col = self.col <= 3 and 1 or 2
    else
      self.row = self.row + 1
    end
  else
    if self:onActions() then
      self.row = ROWS
      self.col = self.col == 1 and 2 or 5
    elseif self.row == 1 then
      self.row = ACTION_ROW
      self.col = 1
    else
      self.row = self.row - 1
    end
  end
  Audio.sfx("move")
end

function Naming:update(dt)
  self.blink = self.blink + dt

  if self.confirming then
    self:updateConfirm()
    return
  end

  local dx = (Input.pressed("right") and 1 or 0) - (Input.pressed("left") and 1 or 0)
  local dy = (Input.pressed("down") and 1 or 0) - (Input.pressed("up") and 1 or 0)
  if dx ~= 0 then self:move(dx, 0) end
  if dy ~= 0 then self:move(0, dy) end

  if Input.pressed("confirm") then
    if self:onActions() then
      if self.col == 1 then
        Audio.sfx("cancel")
        Game.switch("title")
      elseif self:canFinish() then
        self.confirming = true
        self.confirmIndex = 2
        Audio.sfx("select")
      else
        Audio.sfx("cancel")
      end
    else
      self:append(GRID[self.row][self.col])
    end
    return
  end

  if Input.pressed("cancel") then
    self:backspace()
  elseif Input.pressed("menu") then
    Audio.sfx("cancel")
    Game.switch("title")
  end
end

-- ---- draw ------------------------------------------------------------------

function Naming:drawName()
  local shown = self.name
  local caret = #self.name < MAX_LENGTH and (self.blink % 1) < 0.55

  local width = Draw.measure(shown) * 2
  local x = Draw.W / 2 - width / 2
  Draw.textScaled(shown, x, 34, 2, {1, 1, 1})

  if caret then
    Draw.rect(x + width + 2, 34, 8, 16, {1, 1, 0.2})
  end

  -- An underline the width of the longest allowed name, so the field reads as
  -- a field even while it is empty.
  local fieldWidth = Draw.measure(string.rep("M", MAX_LENGTH)) * 2
  Draw.rect(Draw.W / 2 - fieldWidth / 2, 54, fieldWidth, 1, {0.4, 0.4, 0.4})
end

function Naming:draw()
  Draw.clear({0, 0, 0})

  Draw.textCentered("NAME THE FALLEN HUMAN.", Draw.W / 2, 16, {1, 1, 1})
  self:drawName()

  for row = 1, ROWS do
    for col = 1, COLS do
      local char = GRID[row][col]
      local cx = GRID_X + (col - 1) * CELL_W + CELL_W / 2
      local cy = GRID_Y + (row - 1) * CELL_H
      local selected = not self:onActions() and row == self.row and col == self.col

      if selected then
        Draw.pixels(Sprites.heart, cx - 16, cy + 1, 1, Sprites.palette.heart)
      end
      Draw.textCentered(char, cx, cy, selected and {1, 1, 0.2} or {1, 1, 1})
    end
  end

  for i, action in ipairs(ACTIONS) do
    local selected = self:onActions() and i == self.col
    local enabled = i == 1 or self:canFinish()

    local color = {0.45, 0.45, 0.45}
    if enabled then color = selected and {1, 1, 0.2} or {1, 1, 1} end

    if selected then
      Draw.pixels(Sprites.heart, action.x - 14, ACTION_Y + 1, 1, Sprites.palette.heart)
    end
    Draw.text(action.label, action.x, ACTION_Y, color)
  end

  Draw.textCentered("Z SELECT    X BACKSPACE", Draw.W / 2, Draw.H - 16, {0.5, 0.5, 0.5})

  if self.confirming then
    -- Dim the grid so the question is clearly the thing being answered.
    Draw.fade(0.6)
    Draw.box(56, 84, 208, 62)
    Draw.textCentered("IS THIS NAME CORRECT?", Draw.W / 2, 98)
    Draw.textCentered(self.name, Draw.W / 2, 112, {1, 1, 0.2})

    local options = {"NO", "YES"}
    for i, label in ipairs(options) do
      local x = i == 1 and 106 or 186
      local selected = i == self.confirmIndex
      if selected then
        Draw.pixels(Sprites.heart, x - 14, 129, 1, Sprites.palette.heart)
      end
      Draw.text(label, x, 128, selected and {1, 1, 0.2} or {1, 1, 1})
    end
  end
end

return Naming
