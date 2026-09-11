-- Hyperdertale - entry point: window scaling, the main loop, and input plumbing.

local Draw = require("src.draw")
local Input = require("src.input")
local Audio = require("src.audio")
local Save = require("src.save")
local Settings = require("src.settings")
local Game = require("src.game")

local canvas
local scale, offsetX, offsetY = 1, 0, 0

local function computeScale()
  local windowW, windowH = love.graphics.getDimensions()
  -- Integer scaling keeps the pixels square; phones in portrait fall back to
  -- a fractional scale so the screen still fills the width.
  local raw = math.min(windowW / Draw.W, windowH / Draw.H)
  scale = raw >= 1 and math.floor(raw) or raw
  offsetX = math.floor((windowW - Draw.W * scale) / 2)
  offsetY = math.floor((windowH - Draw.H * scale) / 2)
  Input.layout(windowW, windowH)
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  math.randomseed(os.time())

  canvas = love.graphics.newCanvas(Draw.W, Draw.H)
  canvas:setFilter("nearest", "nearest")

  Draw.load()
  Audio.load()

  Settings.load()

  Game.register("title", require("src.scenes.title"))
  Game.register("naming", require("src.scenes.naming"))
  Game.register("overworld", require("src.scenes.overworld"))
  Game.register("battle", require("src.scenes.battle"))
  Game.register("gameover", require("src.scenes.gameover"))

  -- Touch devices get the on-screen pad from the first frame.
  local os_name = love.system.getOS()
  if os_name == "Android" or os_name == "iOS" then
    Input.showTouch = true
  end

  computeScale()
  Settings.apply()   -- after the first layout, so it can rebuild the buttons
  Game.set("title")
end

function love.resize()
  computeScale()
end

function love.update(dt)
  -- A long stall (window drag, app resumed from the background) must not
  -- teleport the player through walls.
  dt = math.min(dt, 1 / 30)

  Input.update()
  Game.update(dt)
  Input.flush()
end

function love.draw()
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 1)
  Game.draw()
  love.graphics.setCanvas()

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)

  Input.draw()
end

-- ---- input events ----------------------------------------------------------

function love.touchpressed(id, x, y)
  Input.touchpressed(id, x, y)
end

function love.touchmoved(id, x, y)
  Input.touchmoved(id, x, y)
end

function love.touchreleased(id, x, y)
  Input.touchreleased(id, x, y)
end

-- The mouse drives the same on-screen pad, which makes it testable on desktop.
function love.mousepressed(x, y, button, isTouch)
  if isTouch then return end
  if Input.showTouch then Input.touchpressed("mouse", x, y) end
end

function love.mousemoved(x, y, dx, dy, isTouch)
  if isTouch then return end
  if Input.showTouch then Input.touchmoved("mouse", x, y) end
end

function love.mousereleased(x, y, button, isTouch)
  if isTouch then return end
  Input.touchreleased("mouse")
end

function love.keypressed(key)
  if key == "f11" or (key == "return" and love.keyboard.isDown("lalt", "ralt")) then
    love.window.setFullscreen(not love.window.getFullscreen())
    computeScale()
  elseif key == "m" then
    Settings.data.sound = not Settings.data.sound
    Settings.apply()
    Settings.save()
  elseif key == "f1" then
    Input.showTouch = not Input.showTouch
    Settings.data.touchUI = Input.showTouch and "on" or "off"
    Settings.save()
  end
end

function love.focus(focused)
  if not focused then Input.clear() end
end

-- Android sends this when the app is backgrounded; save so nothing is lost.
function love.quit()
  if Game.sceneName == "overworld" and Save.exists() then
    Save.write()
  end
  return false
end
