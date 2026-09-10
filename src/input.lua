-- Hyperdertale - one input layer over keyboard, gamepad and touch screen.
-- The touch layer offers either a four-way pad or a floating analog stick;
-- both feed the same actions, so scenes never need to know which is in use.

local Input = {}

local ACTIONS = {"left", "right", "up", "down", "confirm", "cancel", "menu", "jump"}

local KEYS = {
  left    = {"left", "a"},
  right   = {"right", "d"},
  up      = {"up", "w"},
  down    = {"down", "s"},
  confirm = {"z", "return", "kpenter"},
  cancel  = {"x", "lshift", "rshift", "backspace"},
  menu    = {"c", "lctrl", "rctrl", "escape"},
  jump    = {"space", "k"},
}

local PADS = {
  left    = {"dpleft"},
  right   = {"dpright"},
  up      = {"dpup"},
  down    = {"dpdown"},
  confirm = {"a"},
  cancel  = {"b", "x"},
  menu    = {"start", "back"},
  jump    = {"y"},
}

local state, previous, touching = {}, {}, {}

for _, action in ipairs(ACTIONS) do
  state[action] = false
  previous[action] = false
  touching[action] = 0
end

-- Which finger holds which button, so a lifted finger clears the right one.
local fingers = {}

-- Analog input from the on-screen stick or a gamepad stick.
local analogX, analogY = 0, 0
local STICK_DEADZONE = 0.22

Input.showTouch = false
Input.style = "dpad"          -- "dpad" or "stick"
Input.buttonScale = 1.0
Input.buttons = {}
Input.stick = {active = false, id = nil, originX = 0, originY = 0,
               knobX = 0, knobY = 0, radius = 60, zone = nil}

function Input.setStyle(style)
  local wanted = (style == "stick") and "stick" or "dpad"
  -- Applying settings must not drop a thumb that is already on the stick, so
  -- an unchanged style is left completely alone.
  if wanted == Input.style then return end
  Input.style = wanted
  Input.releaseStick()
  Input.layout(love.graphics.getWidth(), love.graphics.getHeight())
end

function Input.setButtonScale(scale)
  local wanted = scale or 1.0
  if wanted == Input.buttonScale then return end
  Input.buttonScale = wanted
  Input.layout(love.graphics.getWidth(), love.graphics.getHeight())
end

-- ---- layout ----------------------------------------------------------------

--- Recompute the on-screen controls for the current window size.
function Input.layout(w, h)
  if not w or w <= 0 then return end

  local scale = Input.buttonScale
  local unit = math.floor(math.min(w * 0.30, h * 0.42) / 3 * scale)
  local margin = math.floor(math.min(w, h) * 0.05)

  Input.buttons = {}

  if Input.style == "dpad" then
    local padX = margin
    local padY = h - margin - unit * 3
    local pad = {
      {action = "up",    x = padX + unit,     y = padY},
      {action = "left",  x = padX,            y = padY + unit},
      {action = "right", x = padX + unit * 2, y = padY + unit},
      {action = "down",  x = padX + unit,     y = padY + unit * 2},
    }
    for _, button in ipairs(pad) do
      button.shape = "rect"
      button.w, button.h = unit, unit
      button.arrow = button.action
      Input.buttons[#Input.buttons + 1] = button
    end
  else
    -- The stick floats: it appears wherever the player's thumb lands inside
    -- this zone, which beats hunting for a fixed circle on a phone.
    Input.stick.radius = math.floor(unit * 1.1)
    Input.stick.zone = {
      x = 0, y = h * 0.30,
      w = w * 0.45, h = h * 0.70,
    }
  end

  local face = math.floor(unit * 1.15)
  local faceCX = w - margin - face
  local faceCY = h - margin - face

  local faceButtons = {
    {action = "confirm", label = "Z", x = faceCX,             y = faceCY,             r = face * 0.66},
    {action = "cancel",  label = "X", x = faceCX - face * 1.5, y = faceCY + face * 0.30, r = face * 0.55},
    {action = "jump",    label = "J", x = faceCX - face * 0.30, y = faceCY - face * 1.45, r = face * 0.55},
    {action = "menu",    label = "C", x = faceCX + face * 0.62, y = faceCY - face * 1.35, r = face * 0.42},
  }
  for _, button in ipairs(faceButtons) do
    button.shape = "circle"
    Input.buttons[#Input.buttons + 1] = button
  end
end

-- ---- touch -----------------------------------------------------------------

local function hit(button, x, y)
  if button.shape == "circle" then
    local dx, dy = x - button.x, y - button.y
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

local function inStickZone(x, y)
  local zone = Input.stick.zone
  if not zone then return false end
  return x >= zone.x and x <= zone.x + zone.w
     and y >= zone.y and y <= zone.y + zone.h
end

function Input.releaseStick()
  Input.stick.active = false
  Input.stick.id = nil
  analogX, analogY = 0, 0
end

local function moveStick(x, y)
  local stick = Input.stick
  local dx, dy = x - stick.originX, y - stick.originY
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance > stick.radius then
    dx = dx / distance * stick.radius
    dy = dy / distance * stick.radius
  end
  stick.knobX, stick.knobY = stick.originX + dx, stick.originY + dy
  analogX = dx / stick.radius
  analogY = dy / stick.radius
end

function Input.touchpressed(id, x, y)
  Input.showTouch = true

  local button = buttonAt(x, y)
  if button then
    grab(id, x, y)
    return
  end

  if Input.style == "stick" and not Input.stick.active and inStickZone(x, y) then
    Input.stick.active = true
    Input.stick.id = id
    Input.stick.originX, Input.stick.originY = x, y
    Input.stick.knobX, Input.stick.knobY = x, y
    analogX, analogY = 0, 0
  end
end

function Input.touchmoved(id, x, y)
  if Input.stick.active and Input.stick.id == id then
    moveStick(x, y)
    return
  end
  if fingers[id] ~= nil or buttonAt(x, y) then grab(id, x, y) end
end

function Input.touchreleased(id)
  if Input.stick.active and Input.stick.id == id then
    Input.releaseStick()
    return
  end
  local held = fingers[id]
  if held then
    touching[held] = math.max(0, touching[held] - 1)
    fingers[id] = nil
  end
end

-- ---- polling ---------------------------------------------------------------

--- Poll every source. Call once per frame before the scene updates.
function Input.update()
  local padX, padY = 0, 0

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
        if math.abs(ax) > math.abs(padX) then padX = ax end
        if math.abs(ay) > math.abs(padY) then padY = ay end
      end
    end
  end

  -- The on-screen stick wins when it is being held; otherwise a gamepad stick.
  if Input.stick.active then
    padX, padY = analogX, analogY
  else
    analogX, analogY = padX, padY
  end

  if math.abs(padX) < STICK_DEADZONE then padX = 0 end
  if math.abs(padY) < STICK_DEADZONE then padY = 0 end
  analogX = math.abs(analogX) < STICK_DEADZONE and 0 or analogX
  analogY = math.abs(analogY) < STICK_DEADZONE and 0 or analogY

  -- Analog deflection also drives the digital actions, so menus work with it.
  if padX < -0.45 then state.left = true elseif padX > 0.45 then state.right = true end
  if padY < -0.45 then state.up = true elseif padY > 0.45 then state.down = true end
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

--- Movement axes. Analog when a stick is in use, -1/0/1 otherwise. The pair is
--- clamped to length 1 so diagonals are not faster than straight lines.
function Input.axes()
  local x, y
  if analogX ~= 0 or analogY ~= 0 then
    x, y = analogX, analogY
  else
    x = (state.right and 1 or 0) - (state.left and 1 or 0)
    y = (state.down and 1 or 0) - (state.up and 1 or 0)
  end

  local length = math.sqrt(x * x + y * y)
  if length > 1 then x, y = x / length, y / length end
  return x, y
end

function Input.axisX() local x = Input.axes() return x end
function Input.axisY() local _, y = Input.axes() return y end

--- Drop every held input, used when a scene changes or the window loses focus.
function Input.clear()
  for _, action in ipairs(ACTIONS) do
    state[action] = false
    previous[action] = false
    touching[action] = 0
  end
  fingers = {}
  Input.releaseStick()
end

-- ---- drawing ---------------------------------------------------------------

local function drawArrow(direction, cx, cy, size)
  local half = size / 2
  local points
  if direction == "up" then
    points = {cx, cy - half, cx - half, cy + half, cx + half, cy + half}
  elseif direction == "down" then
    points = {cx, cy + half, cx - half, cy - half, cx + half, cy - half}
  elseif direction == "left" then
    points = {cx - half, cy, cx + half, cy - half, cx + half, cy + half}
  else
    points = {cx + half, cy, cx - half, cy - half, cx - half, cy + half}
  end
  love.graphics.polygon("fill", points)
end

--- Draw the on-screen controls in window coordinates, over the game canvas.
function Input.draw()
  if not Input.showTouch then return end

  local font = love.graphics.getFont()
  love.graphics.setLineWidth(2)

  if Input.style == "stick" then
    local stick = Input.stick
    if stick.active then
      love.graphics.setColor(1, 1, 1, 0.10)
      love.graphics.circle("fill", stick.originX, stick.originY, stick.radius)
      love.graphics.setColor(1, 1, 1, 0.45)
      love.graphics.circle("line", stick.originX, stick.originY, stick.radius)
      love.graphics.setColor(1, 1, 1, 0.55)
      love.graphics.circle("fill", stick.knobX, stick.knobY, stick.radius * 0.42)
    elseif stick.zone then
      -- A resting hint so the player knows where the stick lives.
      local cx = stick.zone.x + stick.radius * 1.6
      local cy = stick.zone.y + stick.zone.h - stick.radius * 1.6
      love.graphics.setColor(1, 1, 1, 0.07)
      love.graphics.circle("fill", cx, cy, stick.radius)
      love.graphics.setColor(1, 1, 1, 0.22)
      love.graphics.circle("line", cx, cy, stick.radius)
      love.graphics.circle("fill", cx, cy, stick.radius * 0.34)
    end
  end

  for _, button in ipairs(Input.buttons) do
    local held = touching[button.action] > 0
    local fill = held and 0.42 or 0.10
    local line = held and 0.95 or 0.55

    love.graphics.setColor(1, 1, 1, fill)
    if button.shape == "circle" then
      love.graphics.circle("fill", button.x, button.y, button.r)
    else
      love.graphics.rectangle("fill", button.x, button.y, button.w, button.h, 6, 6)
    end

    love.graphics.setColor(1, 1, 1, line)
    if button.shape == "circle" then
      love.graphics.circle("line", button.x, button.y, button.r)
      love.graphics.print(button.label,
        math.floor(button.x - font:getWidth(button.label) / 2),
        math.floor(button.y - font:getHeight() / 2))
    else
      love.graphics.rectangle("line", button.x, button.y, button.w, button.h, 6, 6)
      -- Arrows are drawn, not printed: no glyph to be missing from the font.
      drawArrow(button.arrow,
        button.x + button.w / 2, button.y + button.h / 2,
        button.w * 0.42)
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

return Input
