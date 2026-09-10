-- Hyperdertale - scene registry, scene switching and screen fades.

local Draw = require("src.draw")
local Input = require("src.input")

local Game = {}

Game.scenes = {}
Game.scene = nil
Game.sceneName = nil

local FADE_TIME = 0.28
local transition = nil

function Game.register(name, scene)
  Game.scenes[name] = scene
end

--- Switch immediately, without a fade.
function Game.set(name, args)
  local scene = Game.scenes[name]
  if not scene then
    error("unknown scene: " .. tostring(name))
  end
  if Game.scene and Game.scene.leave then Game.scene:leave() end
  Input.clear()
  Game.scene = scene
  Game.sceneName = name
  if scene.enter then scene:enter(args or {}) end
end

--- Fade out, switch, fade back in.
function Game.switch(name, args)
  if transition then return end
  transition = {phase = "out", t = 0, target = name, args = args}
end

function Game.isTransitioning()
  return transition ~= nil
end

function Game.update(dt)
  if transition then
    transition.t = transition.t + dt
    if transition.phase == "out" and transition.t >= FADE_TIME then
      Game.set(transition.target, transition.args)
      transition.phase = "in"
      transition.t = 0
    elseif transition.phase == "in" and transition.t >= FADE_TIME then
      transition = nil
    end
  end

  -- A scene still updates under a fade so animations do not freeze mid-wipe.
  if Game.scene and Game.scene.update then Game.scene:update(dt) end
end

function Game.draw()
  if Game.scene and Game.scene.draw then Game.scene:draw() end

  if transition then
    local ratio = math.min(1, transition.t / FADE_TIME)
    Draw.fade(transition.phase == "out" and ratio or (1 - ratio))
  end
end

return Game
