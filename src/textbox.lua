-- Hyperdertale - the typewriter dialogue box used by every scene.

local Draw = require("src.draw")
local Audio = require("src.audio")
local Input = require("src.input")

local Textbox = {}
Textbox.__index = Textbox

local CHARS_PER_SECOND = 30

--- Create a box. `opts` may set x, y, w, h, speaker and voice.
function Textbox.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Textbox)
  self.x = opts.x or 16
  self.y = opts.y or 160
  self.w = opts.w or 288
  self.h = opts.h or 64
  self.voice = opts.voice or "blip"
  self.speed = opts.speed or CHARS_PER_SECOND
  self.pages = {}
  self.page = 0
  self.lines = {}
  self.revealed = 0
  self.total = 0
  self.active = false
  self.onDone = nil
  self.blink = 0
  return self
end

--- Queue one string or a list of strings. Each entry is one page.
function Textbox:say(text, onDone)
  self.pages = type(text) == "table" and text or {text}
  self.page = 0
  self.active = true
  self.onDone = onDone
  self:advance()
end

function Textbox:advance()
  self.page = self.page + 1
  if self.page > #self.pages then
    self.active = false
    self.lines = {}
    if self.onDone then
      local callback = self.onDone
      self.onDone = nil
      callback()
    end
    return
  end

  self.lines = Draw.wrap(self.pages[self.page], self.w - 20)
  self.total = 0
  for _, line in ipairs(self.lines) do self.total = self.total + #line end
  self.revealed = 0
end

function Textbox:isFinished()
  return self.revealed >= self.total
end

--- Reveal the whole page at once.
function Textbox:skip()
  self.revealed = self.total
end

function Textbox:update(dt)
  if not self.active then return end
  self.blink = self.blink + dt

  if not self:isFinished() then
    local before = math.floor(self.revealed)
    self.revealed = math.min(self.total, self.revealed + self.speed * dt)
    if math.floor(self.revealed) > before then Audio.sfx(self.voice) end

    if Input.pressed("confirm") or Input.pressed("cancel") then
      self:skip()
    end
  elseif Input.pressed("confirm") then
    Audio.sfx("select")
    self:advance()
  end
end

function Textbox:draw()
  if not self.active then return end

  Draw.box(self.x, self.y, self.w, self.h)

  local budget = math.floor(self.revealed)
  local ty = self.y + 10
  for _, line in ipairs(self.lines) do
    if budget <= 0 then break end
    local shown = line:sub(1, math.min(#line, budget))
    Draw.text(shown, self.x + 10, ty)
    budget = budget - #line
    ty = ty + Draw.lineHeight
  end

  -- A blinking marker tells the player the box is waiting on them.
  if self:isFinished() and (self.blink % 1) < 0.6 then
    Draw.text("*", self.x + self.w - 14, self.y + self.h - 16, {1, 1, 1})
  end
end

return Textbox
