-- Hyperdertale - enemy attack patterns.
-- A pattern owns its own timers in `state` and spawns bullets through
-- ctx.spawn. The battle scene handles movement, collision and clean-up.

local Patterns = {}

local WHITE = {1, 1, 1}
local BLUE = {0.45, 0.72, 1.00}

--- Bullets rain down through the box, with a safe lane the player can find.
Patterns.rain = {
  duration = 5.5,
  start = function (state, ctx)
    state.timer = 0
    state.interval = 0.22
    state.lane = math.random(0, 3)   -- one column stays clear
  end,
  update = function (state, dt, ctx)
    state.timer = state.timer - dt
    if state.timer > 0 then return end
    state.timer = state.interval

    local box = ctx.box
    local columns = 8
    local columnWidth = box.w / columns
    for column = 0, columns - 1 do
      if column % 4 ~= state.lane then
        ctx.spawn({
          x = box.x + column * columnWidth + columnWidth / 2 - 2,
          y = box.y - 8,
          w = 4, h = 8,
          vx = 0, vy = 78 + 14 * ctx.difficulty,
          color = WHITE, damage = 3,
        })
      end
    end
    -- Shift the safe lane so standing still stops working.
    if math.random() < 0.5 then state.lane = math.random(0, 3) end
  end,
}

--- Bars slide in from the sides at the player's height, then past it.
Patterns.sideBars = {
  duration = 5.5,
  start = function (state, ctx)
    state.timer = 0.3
  end,
  update = function (state, dt, ctx)
    state.timer = state.timer - dt
    if state.timer > 0 then return end
    state.timer = 0.55

    local box = ctx.box
    local fromLeft = math.random() < 0.5
    local speed = 92 + 16 * ctx.difficulty
    -- Aim near the soul so the player has to move rather than park.
    local y = math.max(box.y + 2,
      math.min(box.y + box.h - 10, ctx.soul.y - 4 + math.random(-14, 14)))

    ctx.spawn({
      x = fromLeft and (box.x - 18) or (box.x + box.w + 2),
      y = y,
      w = 16, h = 6,
      vx = fromLeft and speed or -speed,
      vy = 0,
      color = WHITE, damage = 3,
    })
  end,
}

--- Bursts of bullets fly outward from the monster's side of the box.
Patterns.radial = {
  duration = 5.0,
  start = function (state, ctx)
    state.timer = 0.4
    state.spin = 0
  end,
  update = function (state, dt, ctx)
    state.timer = state.timer - dt
    if state.timer > 0 then return end
    state.timer = 1.1

    local box = ctx.box
    local originX = box.x + box.w / 2
    local originY = box.y - 6
    local count = 9
    local speed = 62 + 12 * ctx.difficulty
    state.spin = state.spin + 0.35

    for i = 0, count - 1 do
      local angle = state.spin + (i / count) * math.pi * 2
      ctx.spawn({
        x = originX - 3, y = originY - 3,
        w = 5, h = 5,
        vx = math.cos(angle) * speed,
        vy = math.abs(math.sin(angle)) * speed * 0.9 + 24,
        color = WHITE, damage = 4,
      })
    end
  end,
}

--- A wall with a single gap sweeps across the box.
Patterns.sweep = {
  duration = 5.5,
  start = function (state, ctx)
    state.timer = 0.2
    state.fromLeft = math.random() < 0.5
  end,
  update = function (state, dt, ctx)
    state.timer = state.timer - dt
    if state.timer > 0 then return end
    state.timer = 1.6

    local box = ctx.box
    local speed = 58 + 10 * ctx.difficulty
    local rows = 7
    local rowHeight = box.h / rows
    local gap = math.random(0, rows - 2)

    for row = 0, rows - 1 do
      if row ~= gap and row ~= gap + 1 then
        ctx.spawn({
          x = state.fromLeft and (box.x - 10) or (box.x + box.w + 4),
          y = box.y + row * rowHeight + 1,
          w = 6, h = math.max(4, rowHeight - 2),
          vx = state.fromLeft and speed or -speed,
          vy = 0,
          color = BLUE, damage = 3,
        })
      end
    end
    state.fromLeft = not state.fromLeft
  end,
}

--- Build a live instance of a named pattern.
function Patterns.create(name)
  local spec = Patterns[name] or Patterns.rain
  return {
    spec = spec,
    state = {},
    elapsed = 0,
    duration = spec.duration,
  }
end

return Patterns
