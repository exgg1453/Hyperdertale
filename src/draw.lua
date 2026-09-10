-- Hyperdertale - drawing helpers for the 320x240 logical screen.

local Font = require("src.font")

local Draw = {}

Draw.W = 320
Draw.H = 240
Draw.lineHeight = 11

local WHITE = {1, 1, 1}

local function setColor(color)
  if type(color) == "table" then
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
  else
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function Draw.load()
  Draw.font = Font.build()
  love.graphics.setFont(Draw.font)
  love.graphics.setLineStyle("rough")
end

function Draw.clear(color)
  local c = color or {0, 0, 0}
  love.graphics.clear(c[1], c[2], c[3], 1)
end

function Draw.rect(x, y, w, h, color)
  setColor(color or WHITE)
  love.graphics.rectangle("fill", math.floor(x), math.floor(y), math.floor(w), math.floor(h))
  love.graphics.setColor(1, 1, 1, 1)
end

--- Outlined rectangle, drawn inward so it never spills past x/y/w/h.
function Draw.frame(x, y, w, h, color, thickness)
  local t = thickness or 2
  Draw.rect(x, y, w, t, color)
  Draw.rect(x, y + h - t, w, t, color)
  Draw.rect(x, y, t, h, color)
  Draw.rect(x + w - t, y, t, h, color)
end

--- Black fill inside a white border: the game's entire UI language.
function Draw.box(x, y, w, h, border, fill)
  Draw.rect(x, y, w, h, fill or {0, 0, 0})
  Draw.frame(x, y, w, h, border or WHITE, 2)
end

function Draw.text(str, x, y, color)
  setColor(color or WHITE)
  love.graphics.print(str, math.floor(x), math.floor(y))
  love.graphics.setColor(1, 1, 1, 1)
end

--- Print at an integer scale, for headings and the title screen.
function Draw.textScaled(str, x, y, scale, color)
  setColor(color or WHITE)
  love.graphics.print(str, math.floor(x), math.floor(y), 0, scale, scale)
  love.graphics.setColor(1, 1, 1, 1)
end

function Draw.textScaledCentered(str, centreX, y, scale, color)
  Draw.textScaled(str, math.floor(centreX - Draw.measure(str) * scale / 2), y, scale, color)
end

function Draw.measure(str)
  return Draw.font:getWidth(str)
end

function Draw.textCentered(str, centreX, y, color)
  Draw.text(str, math.floor(centreX - Draw.measure(str) / 2), y, color)
end

--- Split on newlines. Written with find rather than gmatch because LuaJIT,
--- which LOVE runs on, returns an extra empty match between lines for a
--- pattern that can match nothing - which silently doubled line spacing.
local function splitLines(str)
  local parts = {}
  local start = 1
  while true do
    local from, to = string.find(str, "\n", start, true)
    if not from then
      parts[#parts + 1] = string.sub(str, start)
      break
    end
    parts[#parts + 1] = string.sub(str, start, from - 1)
    start = to + 1
  end
  return parts
end

--- Word-wrap to `width` pixels; returns a list of lines.
function Draw.wrap(str, width)
  local lines = {}
  for _, rawLine in ipairs(splitLines(tostring(str))) do
    local line = ""
    for word in rawLine:gmatch("%S+") do
      local candidate = line == "" and word or (line .. " " .. word)
      if Draw.measure(candidate) > width and line ~= "" then
        lines[#lines + 1] = line
        line = word
      else
        line = candidate
      end
    end
    lines[#lines + 1] = line
  end
  return lines
end

--- Draw a character-map sprite. '.' is transparent; other characters index
--- into `palette`.
function Draw.pixels(map, x, y, scale, palette)
  local s = scale or 1
  for row = 1, #map do
    local line = map[row]
    for col = 1, #line do
      local ch = line:sub(col, col)
      if ch ~= "." then
        local color = palette[ch]
        if color then
          setColor(color)
          love.graphics.rectangle("fill",
            math.floor(x + (col - 1) * s), math.floor(y + (row - 1) * s), s, s)
        end
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

--- Fill the screen with black at the given opacity, for fades.
function Draw.fade(alpha)
  if alpha <= 0 then return end
  love.graphics.setColor(0, 0, 0, math.min(1, alpha))
  love.graphics.rectangle("fill", 0, 0, Draw.W, Draw.H)
  love.graphics.setColor(1, 1, 1, 1)
end

--- A [dx, dy] offset for screen shake.
function Draw.shake(intensity)
  if intensity <= 0 then return 0, 0 end
  return math.floor((math.random() * 2 - 1) * intensity),
         math.floor((math.random() * 2 - 1) * intensity)
end

return Draw
