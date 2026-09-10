-- Hyperdertale - the game over screen and the way back into the run.

local Draw = require("src.draw")
local Input = require("src.input")
local Audio = require("src.audio")
local Save = require("src.save")
local Sprites = require("src.sprites")
local Game = require("src.game")

local Gameover = {}

local LINES = {
  "* You cannot give up just yet.",
  "* Hyperdertale is counting on you.",
  "* Stay determined...",
}

function Gameover:enter(args)
  args = args or {}
  self.time = 0
  self.shards = {}
  self.canContinue = false

  -- The soul breaks into pieces that scatter and fall.
  for i = 1, 10 do
    local angle = (i / 10) * math.pi * 2 + math.random() * 0.4
    self.shards[i] = {
      x = Draw.W / 2,
      y = 86,
      vx = math.cos(angle) * (26 + math.random() * 34),
      vy = math.sin(angle) * (26 + math.random() * 34) - 22,
      size = math.random(2, 4),
    }
  end

  Audio.stop()
  Audio.sfx("hurt")
  Audio.play("gameover")
end

function Gameover:update(dt)
  self.time = self.time + dt

  for _, shard in ipairs(self.shards) do
    shard.vy = shard.vy + 90 * dt
    shard.x = shard.x + shard.vx * dt
    shard.y = shard.y + shard.vy * dt
  end

  if self.time > 2.4 then self.canContinue = true end

  if self.canContinue and Input.pressed("confirm") then
    Audio.sfx("select")
    if Save.exists() and Save.read() then
      Save.player.hp = Save.player.maxhp
      Game.switch("overworld", {
        room = Save.player.room, x = Save.player.x, y = Save.player.y, fromBattle = true,
      })
    else
      -- No save file: start the run over rather than stranding the player.
      Save.reset()
      Game.switch("overworld", {room = "ruins_entry", intro = true})
    end
  end
end

function Gameover:draw()
  Draw.clear({0, 0, 0})

  for _, shard in ipairs(self.shards) do
    Draw.rect(shard.x, shard.y, shard.size, shard.size, {0.85, 0.08, 0.08})
  end

  local shown = math.min(#LINES, math.floor(self.time / 0.8) + 1)
  for i = 1, shown do
    Draw.textCentered(LINES[i], Draw.W / 2, 128 + (i - 1) * 16, {1, 1, 1})
  end

  if self.canContinue and (self.time % 1) < 0.65 then
    Draw.textCentered("PRESS Z TO CONTINUE", Draw.W / 2, 196, {0.7, 0.7, 0.7})
    Draw.pixels(Sprites.heart, Draw.W / 2 - 52, 197, 1, Sprites.palette.heart)
  end
end

return Gameover
