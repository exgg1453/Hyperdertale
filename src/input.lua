-- Hyperdertale - one input layer over keyboard, gamepad and touch screen.

local Input = {}

local ACTIONS = {"left", "right", "up", "down", "confirm", "cancel", "menu"}

local KEYS = {
  left    = {"left", "a"},
  right   = {"right", "d"},
  up      = {"up", "w"},
  down    = {"down", "s"},
  confirm = {"z", "return", "space", "kpenter"},
  cancel  = {"x", "lshift", "rshift", "backspace"},
  menu    = {"c", "lctrl", "rctrl", "escape"},
}

local PADS = {
  left    = {"dpleft"},
  right   = {"dpright"},
  up      = {"dpup"},
  down    = {"dpdown"},
  confirm = {"a"},
  cancel  = {"b", "x"},
  menu    = {"y", "start"},
}

local state, previous, touching = {}, {}, {}

for _, action in ipairs(ACTIONS) do
  state[action] = false
  previous[action] = false
  touching[action] = 0     -- how many fingers are on this button
end

-- Which finger is holding which button, so a lifted finger clears the right one.
local fingers = {}

Input.showTouch = false
Input.buttons = {}

--- Recompute the on-screen pad for the current window size.
function Input.layout(w, h)
  local unit = math.floor(math.min(w * 0.30, h * 0.42) / 3)
  local pad = math.floor(math.min(w, h) * 0.05)

  local padX = pad
  local padY = h - pad - unit * 3
  local faceSize = math.floor(unit * 1.35)
  local faceX = w - pad - faceSize * 2 - math.floor(unit * 0.25)
  local faceY = h - pad - faceSize * 2

  Input.buttons = {
    {action = "up",      shape = "rect",   x = padX + unit,     y = padY,            w = unit, h = unit, label = "^"},
    {action = "left",    shape = "rect",   x = padX,            y = padY + unit,     w = unit, h = unit, label = "<"},
    {action = "right",   shape = "rect",   x = padX + unit * 2, y = padY + unit,     w = unit, h = unit, label = ">"},
    {action = "down",    shape = "rect",   x = padX + unit,     y = padY + unit * 2, w = unit, h = unit, label = "v"},

    {action = "confirm", shape = "circle", x = faceX + faceSize * 1.5, y = faceY + faceSize * 1.4,
     r = faceSize * 0.62, label = "Z"},
    {action = "cancel",  shape = "circle", x = faceX + faceSize * 0.35, y = faceY + faceSize * 1.9,
     r = faceSize * 0.52, label = "X"},
    {action = "menu",    shape = "circle", x = faceX + faceSize * 1.75, y = faceY + faceSize * 0.25,
     r = faceSize * 0.40, label = "C"},
  }
end

local function hit(button, x, y)
  if button.shape == "circle" then
    local dx, dy = x - button.x, y - button.y
    -- A slightly generous radius; thumbs are not precise.
    return dx * dx + dy * dy <= (button.r * 1.15) ^ 2
  end
  return x >= button.x and x <= button.x + button.w
     and y >= button.y and y <= button.y + button.h
end

local function buttonAt(x, y)
  for _, button in ipairs(Input.buttons) do
    if hit(button, x, y) then return button end
  end
  return nil
end

local function grab(id, x, y)
  local button = buttonAt(x, y)
  local held = fingers[id]
  if held == (button and button.action or nil) then return end

  if held then
    touching[held] = math.max(0, touching[held] - 1)
    fingers[id] = nil
  end
  if button then
    touching[button.action] = touching[button.action] + 1
    fingers[id] = button.action
  end
end

function Input.touchpressed(id, x, y)
  Input.showTouch = true
  grab(id, x, y)
end

function Input.touchmoved(id, x, y)
  -- Sliding from one button to another swaps which one is held.
  if fingers[id] ~= nil or buttonAt(x, y) then grab(id, x, y) end
end

function Input.touchreleased(id)
  local held = fingers[id]
  if held then
    touching[held] = math.max(0, touching[held] - 1)
    fingers[id] = nil
  end
end

--- Poll every source. Call once per frame before the scene updates.
function Input.update()
  for _, action in ipairs(ACTIONS) do
    local held = false

    for _, key in ipairs(KEYS[action]) do
      if love.keyboard.isDown(key) then held = true break end
    end

    if not held and touching[action] > 0 then held = true end

    state[action] = held
  end

  if love.joystick then
    for _, stick in ipairs(love.joystick.getJoysticks()) do
      if stick:isGamepad() then
        for _, action in ipairs(ACTIONS) do
          for _, gpButton in ipairs(PADS[action]) do
            if stick:isGamepadDown(gpButton) then state[action] = true end
          end
        end
        local ax = stick:getGamepadAxis("leftx") or 0
        local ay = stick:getGamepadAxis("lefty") or 0
        if ax < -0.4 then state.left = true end
        if ax > 0.4 then state.right = true end
        if ay < -0.4 then state.up = true end
        if ay > 0.4 then state.down = true end
      end
    end
  end
end

--- Call once per frame after the scene updates.
function Input.flush()
  for _, action in ipairs(ACTIONS) do previous[action] = state[action] end
end

function Input.down(action) return state[action] == true end

function Input.pressed(action)
  return state[action] == true and previous[action] ~= true
end

function Input.released(action)
  return state[action] ~= true and previous[action] == true
end

function Input.anyPressed()
  for _, action in ipairs(ACTIONS) do
    if Input.pressed(action) then return true end
  end
  return false
end

function Input.axisX()
  return (state.right and 1 or 0) - (state.left and 1 or 0)
end

function Input.axisY()
  return (state.down and 1 or 0) - (state.up and 1 or 0)
end

--- Drop every held input, used when a scene changes or the window loses focus.
function Input.clear()
  for _, action in ipairs(ACTIONS) do
    state[action] = false
    previous[action] = false
    touching[action] = 0
  end
  fingers = {}
end

--- Draw the on-screen pad in window coordinates, over the scaled game canvas.
function Input.draw()
  if not Input.showTouch then return end

  local font = love.graphics.getFont()

  for _, button in ipairs(Input.buttons) do
    local held = touching[button.action] > 0
    local alpha = held and 0.42 or 0.10

    love.graphics.setColor(1, 1, 1, alpha)
    if button.shape == "circle" then
      love.graphics.circle("fill", button.x, button.y, button.r)
    else
      love.graphics.rectangle("fill", button.x, button.y, button.w, button.h, 6, 6)
    end

    love.graphics.setColor(1, 1, 1, held and 0.95 or 0.55)
    love.graphics.setLineWidth(2)
    if button.shape == "circle" then
      love.graphics.circle("line", button.x, button.y, button.r)
      love.graphics.print(button.label,
        math.floor(button.x - font:getWidth(button.label) / 2),
        math.floor(button.y - font:getHeight() / 2))
    else
      love.graphics.rectangle("line", button.x, button.y, button.w, button.h, 6, 6)
      love.graphics.print(button.label,
        math.floor(button.x + button.w / 2 - font:getWidth(button.label) / 2),
        math.floor(button.y + button.h / 2 - font:getHeight() / 2))
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

return Input
