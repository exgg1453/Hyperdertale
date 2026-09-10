-- Hyperdertale - walking around, talking, jumping, saving, and running into
-- monsters.

local Draw = require("src.draw")
local Input = require("src.input")
local Audio = require("src.audio")
local Save = require("src.save")
local Sprites = require("src.sprites")
local Textbox = require("src.textbox")
local Items = require("src.data.items")
local SettingsMenu = require("src.settingsmenu")
local Game = require("src.game")

local Overworld = {}

local SPEED = 74
local SCALE = 2
local HERO_W = Sprites.heroWidth * SCALE      -- 24
local HERO_H = Sprites.heroHeight * SCALE     -- 30
local FOOT_W, FOOT_H = 18, 10                 -- only the feet collide

local JUMP_TIME = 0.52
local JUMP_HEIGHT = 14

-- ---- rooms -----------------------------------------------------------------

local ROOMS = {
  ruins_entry = {
    title = "RUINS - ENTRANCE",
    music = "overworld",
    floor = {0.16, 0.13, 0.22},
    wall = {0.30, 0.24, 0.42},
    walls = {
      {x = 0, y = 0, w = 320, h = 40},
      {x = 0, y = 0, w = 40, h = 240},
      {x = 280, y = 0, w = 40, h = 240},
      -- The south wall is split so the doorway is a real gap you can walk
      -- into, not a trigger sitting on top of solid stone.
      {x = 0, y = 214, w = 140, h = 26},
      {x = 180, y = 214, w = 140, h = 26},
    },
    entities = {
      {kind = "bed", x = 48, y = 44, w = 32, h = 36},
      {kind = "bed", x = 240, y = 44, w = 32, h = 36},
      {
        kind = "npc", sprite = "guide", palette = "guide",
        x = 92, y = 92, w = 24, h = 34,
        dialogue = {
          "* Oh! You are the one who fell.",
          "* This is the RUINS. Everything here is old, and most of it is patient.",
          "* Down the hall there are monsters. They are not cruel, only bored.",
          "* You can FIGHT them. You can also TALK to them, and let them go.",
          "* Both work. Only one of them is quiet afterwards.",
          "* Rest in a bed first, if you like. They are older than I am.",
        },
        repeatDialogue = {
          "* The beds are yours if you want them. Sleeping mends what hurts.",
          "* Mind the crack in the long hall. You can hop over it.",
          "* Take your time. The RUINS have plenty of it.",
        },
        flag = "metGuide",
      },
      {kind = "save", x = 200, y = 104, w = 18, h = 18},
      {
        kind = "door", x = 140, y = 214, w = 40, h = 14,
        to = "ruins_hall", spawnX = 160, spawnY = 62,
      },
    },
  },

  ruins_hall = {
    title = "RUINS - LONG HALL",
    music = "overworld",
    floor = {0.13, 0.11, 0.19},
    wall = {0.26, 0.21, 0.38},
    walls = {
      {x = 0, y = 0, w = 140, h = 34},
      {x = 180, y = 0, w = 140, h = 34},
      {x = 0, y = 0, w = 52, h = 240},
      {x = 268, y = 0, w = 52, h = 240},
      {x = 0, y = 214, w = 320, h = 26},
      {x = 52, y = 120, w = 34, h = 16},
      {x = 234, y = 120, w = 34, h = 16},
    },
    -- A crack in the floor: walk around it, or hop straight over.
    pits = {
      {x = 120, y = 116, w = 80, h = 24},
    },
    grass = {x = 60, y = 152, w = 200, h = 54},
    encounter = {enemy = "critter", chance = 0.9},
    entities = {
      {
        kind = "door", x = 140, y = 24, w = 40, h = 14,
        to = "ruins_entry", spawnX = 160, spawnY = 196,
      },
      {
        kind = "sign", x = 236, y = 58, w = 16, h = 20,
        dialogue = {
          "* (The sign is worn almost smooth.)",
          "* (HOLD X TO RUN.)",
          "* (PRESS J - OR SPACE - TO JUMP. THE FLOOR IS NOT EVERYWHERE.)",
        },
      },
      {
        kind = "item", id = "pie", flag = "tookPie",
        x = 66, y = 60, w = 16, h = 16,
        text = "* (A slice of pie, still warm.)\n* You take it.",
        emptyText = "* (Only crumbs now.)",
      },
    },
  },
}

-- ---- helpers ---------------------------------------------------------------

local function overlaps(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

function Overworld:footBox(x, y)
  return x - FOOT_W / 2, y - FOOT_H, FOOT_W, FOOT_H
end

function Overworld:airborne()
  return self.jumpTimer > 0
end

function Overworld:blocked(x, y)
  local fx, fy, fw, fh = self:footBox(x, y)

  for _, wall in ipairs(self.room.walls) do
    if overlaps(fx, fy, fw, fh, wall.x, wall.y, wall.w, wall.h) then return true end
  end

  -- Pits only stop you while your feet are on the ground.
  if not self:airborne() and self.room.pits then
    for _, pit in ipairs(self.room.pits) do
      if overlaps(fx, fy, fw, fh, pit.x, pit.y, pit.w, pit.h) then return true end
    end
  end

  for _, entity in ipairs(self.room.entities) do
    if entity.kind == "npc" or entity.kind == "sign" or entity.kind == "save"
       or entity.kind == "bed" then
      if overlaps(fx, fy, fw, fh, entity.x, entity.y, entity.w, entity.h) then return true end
    end
  end
  return false
end

--- The entity the player is facing, within arm's reach.
function Overworld:facingEntity()
  local reach = 12
  local px, py = self.x, self.y
  if self.facing == "up" then py = py - reach
  elseif self.facing == "down" then py = py + reach
  elseif self.facing == "left" then px = px - reach
  else px = px + reach end

  local fx, fy, fw, fh = self:footBox(px, py)
  for _, entity in ipairs(self.room.entities) do
    if entity.kind ~= "door" then
      if overlaps(fx, fy, fw, fh, entity.x, entity.y, entity.w, entity.h) then
        return entity
      end
    end
  end
  return nil
end

-- ---- lifecycle -------------------------------------------------------------

function Overworld:enter(args)
  args = args or {}
  local roomName = args.room or Save.player.room or "ruins_entry"
  self.room = ROOMS[roomName] or ROOMS.ruins_entry
  self.roomName = ROOMS[roomName] and roomName or "ruins_entry"

  self.x = args.x or Save.player.x or 160
  self.y = args.y or Save.player.y or 150
  self.facing = args.facing or "down"
  self.frame = 1
  self.animTimer = 0
  self.steps = 0
  self.jumpTimer = 0
  self.encounterCooldown = args.fromBattle and 1.2 or 0.4
  self.titleTimer = 2.2
  self.menuOpen = false
  self.menuIndex = 1
  self.menuPage = "root"
  self.itemIndex = 1
  self.settings = nil
  self.sleep = nil
  self.flash = 0

  self.box = Textbox.new()
  Save.player.room = self.roomName

  Audio.play(self.room.music or "overworld")

  if args.intro then
    self.box:say({
      "* You wake up on a bed of golden flowers.",
      "* You do not remember falling. You remember deciding to.",
    })
  end
end

function Overworld:leave()
  Save.player.x = self.x
  Save.player.y = self.y
  Save.player.room = self.roomName
end

-- ---- interaction -----------------------------------------------------------

function Overworld:interact()
  local entity = self:facingEntity()
  if not entity then return end

  if entity.kind == "save" then
    Audio.sfx("save")
    Save.player.hp = Save.player.maxhp
    Save.player.x, Save.player.y = self.x, self.y
    Save.player.room = self.roomName
    local written = Save.write()
    self.box:say({
      "* (The star hums. You feel determined.)",
      written and ("* HP restored.  SAVED.  " .. Save.clock())
              or "* HP restored.  (This device would not let the game save.)",
    })
    return
  end

  if entity.kind == "bed" then
    if Save.player.hp >= Save.player.maxhp then
      self.box:say("* (The bed is made up and waiting.)\n* You are not tired.")
    else
      self.sleep = {phase = "out", t = 0}
      Audio.sfx("save")
    end
    return
  end

  if entity.kind == "npc" then
    local seen = entity.flag and Save.flag(entity.flag)
    local lines = seen and (entity.repeatDialogue or entity.dialogue) or entity.dialogue
    if entity.flag then Save.setFlag(entity.flag, true) end
    self.box:say(lines)
    return
  end

  if entity.kind == "item" then
    if Save.flag(entity.flag) then
      self.box:say(entity.emptyText or "* (Nothing left.)")
    else
      Save.setFlag(entity.flag, true)
      table.insert(Save.player.items, entity.id)
      Audio.sfx("pickup")
      local item = Items[entity.id]
      self.box:say(entity.text .. "\n* (" .. (item and item.name or entity.id) .. " added.)")
    end
    return
  end

  if entity.kind == "sign" then
    self.box:say(entity.dialogue)
  end
end

function Overworld:useItem(index)
  local player = Save.player
  local id = player.items[index]
  local item = id and Items[id]
  if not item then return end

  table.remove(player.items, index)
  Save.heal(item.heal)
  Audio.sfx("heal")
  self.itemIndex = math.min(self.itemIndex, math.max(1, #player.items))
  self.menuOpen = false
  self.box:say(item.use .. "\n* You recovered " .. item.heal .. " HP.")
end

-- ---- update ----------------------------------------------------------------

local ROOT_OPTIONS = {"ITEM", "STAT", "SETTINGS", "CLOSE"}

function Overworld:updateMenu(dt)
  local player = Save.player

  if self.menuPage == "settings" then
    if self.settings:update(dt) then
      self.menuPage = "root"
      self.settings = nil
    end
    return
  end

  if self.menuPage == "root" then
    if Input.pressed("up") then
      self.menuIndex = self.menuIndex > 1 and self.menuIndex - 1 or #ROOT_OPTIONS
      Audio.sfx("move")
    elseif Input.pressed("down") then
      self.menuIndex = self.menuIndex < #ROOT_OPTIONS and self.menuIndex + 1 or 1
      Audio.sfx("move")
    end

    if Input.pressed("confirm") then
      local choice = ROOT_OPTIONS[self.menuIndex]
      Audio.sfx("select")
      if choice == "CLOSE" then
        self.menuOpen = false
      elseif choice == "ITEM" then
        self.menuPage = "item"
        self.itemIndex = 1
      elseif choice == "SETTINGS" then
        self.menuPage = "settings"
        self.settings = SettingsMenu.new()
      else
        self.menuPage = "stat"
      end
    elseif Input.pressed("cancel") or Input.pressed("menu") then
      self.menuOpen = false
      Audio.sfx("cancel")
    end
    return
  end

  if self.menuPage == "item" then
    local count = #player.items
    if count > 0 then
      if Input.pressed("up") then
        self.itemIndex = self.itemIndex > 1 and self.itemIndex - 1 or count
        Audio.sfx("move")
      elseif Input.pressed("down") then
        self.itemIndex = self.itemIndex < count and self.itemIndex + 1 or 1
        Audio.sfx("move")
      end
      if Input.pressed("confirm") then self:useItem(self.itemIndex) return end
    end
    if Input.pressed("cancel") or Input.pressed("menu") then
      self.menuPage = "root"
      Audio.sfx("cancel")
    end
    return
  end

  if Input.pressed("cancel") or Input.pressed("confirm") or Input.pressed("menu") then
    self.menuPage = "root"
    Audio.sfx("cancel")
  end
end

local SLEEP_FADE, SLEEP_HOLD = 0.7, 1.4

function Overworld:updateSleep(dt)
  local sleep = self.sleep
  sleep.t = sleep.t + dt

  if sleep.phase == "out" and sleep.t >= SLEEP_FADE then
    sleep.phase, sleep.t = "hold", 0
    Save.player.hp = Save.player.maxhp
    -- Resting costs time, the way an inn does.
    Save.player.playtime = Save.player.playtime + 60
  elseif sleep.phase == "hold" and sleep.t >= SLEEP_HOLD then
    sleep.phase, sleep.t = "in", 0
    Audio.sfx("heal")
  elseif sleep.phase == "in" and sleep.t >= SLEEP_FADE then
    self.sleep = nil
    self.box:say("* You slept for a while.\n* HP fully restored.")
  end
end

--- 0 to 1: how black the screen is during the nap.
function Overworld:sleepDarkness()
  local sleep = self.sleep
  if not sleep then return 0 end
  if sleep.phase == "out" then return math.min(1, sleep.t / SLEEP_FADE) end
  if sleep.phase == "hold" then return 1 end
  return math.max(0, 1 - sleep.t / SLEEP_FADE)
end

function Overworld:update(dt)
  self.titleTimer = math.max(0, self.titleTimer - dt)
  self.flash = math.max(0, self.flash - dt * 3)
  Save.player.playtime = Save.player.playtime + dt

  if self.sleep then
    self:updateSleep(dt)
    return
  end

  if self.box.active then
    self.box:update(dt)
    return
  end

  if self.menuOpen then
    self:updateMenu(dt)
    return
  end

  if Input.pressed("menu") then
    self.menuOpen = true
    self.menuPage = "root"
    self.menuIndex = 1
    Audio.sfx("menu")
    return
  end

  -- ---- jumping ----
  local wasAirborne = self:airborne()
  if self.jumpTimer > 0 then
    self.jumpTimer = math.max(0, self.jumpTimer - dt)
    if wasAirborne and self.jumpTimer == 0 then Audio.sfx("land") end
  elseif Input.pressed("jump") then
    self.jumpTimer = JUMP_TIME
    Audio.sfx("jump")
  end

  if Input.pressed("confirm") and not self:airborne() then
    self:interact()
    return
  end

  -- ---- movement ----
  local dx, dy = Input.axes()
  local running = Input.down("cancel")
  local speed = SPEED * (running and 1.6 or 1)

  if dx ~= 0 or dy ~= 0 then
    if math.abs(dx) > math.abs(dy) then
      self.facing = dx > 0 and "right" or "left"
    else
      self.facing = dy > 0 and "down" or "up"
    end

    local stepX = dx * speed * dt
    local stepY = dy * speed * dt
    if not self:blocked(self.x + stepX, self.y) then self.x = self.x + stepX end
    if not self:blocked(self.x, self.y + stepY) then self.y = self.y + stepY end

    self.animTimer = self.animTimer + dt
    if self.animTimer > 0.16 then
      self.animTimer = 0
      self.frame = self.frame == 1 and 2 or 1
    end
    self.steps = self.steps + speed * dt
  else
    if not self:airborne() then self.frame = 1 end
    self.animTimer = 0
  end

  -- Landing inside a pit is not survivable ground: nudge back out.
  if wasAirborne and not self:airborne() and self:blocked(self.x, self.y) then
    local pushed = false
    for _, offset in ipairs({{0, -14}, {0, 14}, {-14, 0}, {14, 0}, {0, -26}, {0, 26}}) do
      if not self:blocked(self.x + offset[1], self.y + offset[2]) then
        self.x, self.y = self.x + offset[1], self.y + offset[2]
        pushed = true
        break
      end
    end
    if not pushed then self.y = self.y - 26 end
  end

  -- ---- doors ----
  local fx, fy, fw, fh = self:footBox(self.x, self.y)
  for _, entity in ipairs(self.room.entities) do
    if entity.kind == "door"
       and overlaps(fx, fy, fw, fh, entity.x, entity.y, entity.w, entity.h) then
      Save.player.x, Save.player.y = entity.spawnX, entity.spawnY
      Save.player.room = entity.to
      Game.switch("overworld", {
        room = entity.to, x = entity.spawnX, y = entity.spawnY, facing = self.facing,
      })
      return
    end
  end

  -- ---- random encounters ----
  self.encounterCooldown = math.max(0, self.encounterCooldown - dt)
  local grass = self.room.grass
  if grass and self.room.encounter and self.encounterCooldown == 0 and not self:airborne() then
    if overlaps(fx, fy, fw, fh, grass.x, grass.y, grass.w, grass.h) and self.steps > 0 then
      -- Chance scales with distance walked, so standing still is safe - and so
      -- is hopping across.
      if math.random() < self.room.encounter.chance * dt * (speed / SPEED) then
        self.steps = 0
        Save.player.x, Save.player.y = self.x, self.y
        Save.player.room = self.roomName
        Audio.sfx("encounter")
        self.flash = 1
        Game.switch("battle", {
          enemy = self.room.encounter.enemy,
          returnRoom = self.roomName,
          returnX = self.x, returnY = self.y,
        })
      end
    end
  end
end

-- ---- draw ------------------------------------------------------------------

function Overworld:drawMenu()
  local player = Save.player

  if self.menuPage == "settings" then
    self.settings:draw(20, 26, 280, 176)
    return
  end

  Draw.box(184, 6, 130, 132)
  Draw.text(player.name, 194, 16)
  Draw.text("LV  " .. player.lv, 194, 30)
  Draw.text("HP  " .. player.hp .. " / " .. player.maxhp, 194, 42)
  Draw.text("G   " .. player.gold, 194, 54)

  if self.menuPage == "root" then
    for i, label in ipairs(ROOT_OPTIONS) do
      local y = 70 + (i - 1) * 14
      local selected = i == self.menuIndex
      if selected then
        Draw.pixels(Sprites.heart, 196, y + 2, 1, Sprites.palette.heart)
      end
      Draw.text(label, 208, y, selected and {1, 1, 0.2} or {1, 1, 1})
    end
    return
  end

  Draw.box(8, 108, 168, 96)
  if self.menuPage == "item" then
    if #player.items == 0 then
      Draw.text("* Pockets empty.", 20, 122)
    else
      for i, id in ipairs(player.items) do
        local item = Items[id]
        local y = 118 + (i - 1) * 12
        local selected = i == self.itemIndex
        if selected then
          Draw.pixels(Sprites.heart, 20, y + 2, 1, Sprites.palette.heart)
        end
        Draw.text(item and item.name or id, 32, y, selected and {1, 1, 0.2} or {1, 1, 1})
      end
      Draw.text("Z USE   X BACK", 20, 188, {0.55, 0.55, 0.55})
    end
  else
    Draw.text("* " .. player.name, 20, 118)
    Draw.text("LV " .. player.lv, 20, 132)
    Draw.text("AT " .. player.at .. "   DF " .. player.df, 20, 144)
    Draw.text("EXP " .. player.exp, 20, 156)
    Draw.text("NEXT " ..
      math.max(0, Save.expForLevel(player.lv + 1) - player.exp), 20, 168)
    Draw.text("TIME " .. Save.clock(), 20, 180, {0.7, 0.7, 0.7})
  end
end

function Overworld:drawHero()
  local key = (self.facing == "left" or self.facing == "right") and "side" or self.facing
  local frames = Sprites.hero[key] or Sprites.hero.down
  local map = frames[self.frame] or frames[1]

  if self.facing == "left" then
    local mirrored = {}
    for i, line in ipairs(map) do mirrored[i] = line:reverse() end
    map = mirrored
  end

  local lift = 0
  if self:airborne() then
    -- A simple arc: up, then down, over the length of the hop.
    local progress = 1 - (self.jumpTimer / JUMP_TIME)
    lift = math.sin(progress * math.pi) * JUMP_HEIGHT

    -- The shadow stays on the ground and shrinks as the hop peaks.
    local shrink = 1 - (lift / JUMP_HEIGHT) * 0.45
    local shadowW = HERO_W * 0.6 * shrink
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", self.x, self.y - 2, shadowW / 2, 3 * shrink)
    love.graphics.setColor(1, 1, 1, 1)
  end

  Draw.pixels(map, self.x - HERO_W / 2, self.y - HERO_H - lift, SCALE, Sprites.palette.hero)
end

function Overworld:draw()
  local room = self.room
  Draw.clear(room.floor)

  for _, wall in ipairs(room.walls) do
    Draw.rect(wall.x, wall.y, wall.w, wall.h, room.wall)
    Draw.rect(wall.x, wall.y + wall.h - 3, wall.w, 3, {
      room.wall[1] * 0.6, room.wall[2] * 0.6, room.wall[3] * 0.6,
    })
  end

  if room.pits then
    for _, pit in ipairs(room.pits) do
      Draw.rect(pit.x, pit.y, pit.w, pit.h, {0.02, 0.02, 0.04})
      Draw.rect(pit.x, pit.y, pit.w, 2, {0.08, 0.07, 0.12})
      Draw.rect(pit.x, pit.y + pit.h - 2, pit.w, 2, {0.20, 0.17, 0.28})
    end
  end

  if room.grass then
    local g = room.grass
    Draw.rect(g.x, g.y, g.w, g.h, {0.10, 0.28, 0.16})
    for bx = 0, g.w - 4, 6 do
      for by = 0, g.h - 4, 8 do
        Draw.rect(g.x + bx + ((by / 8) % 2) * 3, g.y + by, 2, 6, {0.16, 0.42, 0.22})
      end
    end
  end

  for _, entity in ipairs(room.entities) do
    if entity.kind == "npc" then
      Draw.pixels(Sprites[entity.sprite] or Sprites.guide, entity.x, entity.y, SCALE,
        Sprites.palette[entity.palette] or Sprites.palette.guide)
    elseif entity.kind == "bed" then
      Draw.pixels(Sprites.bed, entity.x, entity.y, 2, Sprites.palette.bed)
    elseif entity.kind == "save" then
      local time = love.timer.getTime()
      local pulse = 0.72 + 0.28 * math.sin(time * 3)
      local cx, cy = entity.x + 9, entity.y + 9

      -- Pixel beams rather than a smooth circle: a round gradient reads as a
      -- dark disc against this floor and fights the rest of the art.
      local reach = 7 + 3 * pulse
      for _, beam in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
        for step = 3, reach do
          local fade = (1 - (step - 3) / reach) * 0.5 * pulse
          Draw.rect(cx + beam[1] * step - 1, cy + beam[2] * step - 1, 2, 2,
            {1, 0.95, 0.55, fade})
        end
      end

      Draw.pixels(Sprites.star, entity.x, entity.y, 2,
        {["1"] = {1, 0.86 + 0.14 * pulse, 0.20 + 0.25 * pulse}})

      -- Three sparks orbiting the star, so it reads as "something happens here".
      for i = 0, 2 do
        local angle = time * 1.5 + i * (math.pi * 2 / 3)
        local radius = 13 + math.sin(time * 3 + i) * 2
        Draw.rect(cx + math.cos(angle) * radius - 1, cy + math.sin(angle) * radius - 1,
          2, 2, {1, 1, 0.65, 0.85})
      end
    elseif entity.kind == "sign" then
      Draw.rect(entity.x, entity.y, entity.w, entity.h, {0.45, 0.35, 0.25})
      Draw.rect(entity.x + 2, entity.y + 2, entity.w - 4, entity.h - 8, {0.75, 0.68, 0.55})
    elseif entity.kind == "item" then
      if not Save.flag(entity.flag) then
        local bob = math.sin(love.timer.getTime() * 2) * 1.5
        Draw.rect(entity.x + 2, entity.y + 4 + bob, 12, 9, {0.85, 0.70, 0.35})
        Draw.rect(entity.x + 2, entity.y + 4 + bob, 12, 3, {0.95, 0.85, 0.55})
      end
    elseif entity.kind == "door" then
      local d = entity
      local frame = {room.wall[1] * 1.25, room.wall[2] * 1.25, room.wall[3] * 1.25}

      Draw.rect(d.x - 5, d.y - 7, d.w + 10, d.h + 12, frame)
      Draw.rect(d.x - 5, d.y - 7, d.w + 10, 2,
        {room.wall[1] * 1.6, room.wall[2] * 1.6, room.wall[3] * 1.6})

      -- The opening itself, with the corners squared off into an arch.
      Draw.rect(d.x, d.y - 3, d.w, d.h + 6, {0.03, 0.02, 0.05})
      Draw.rect(d.x, d.y - 3, 4, 4, frame)
      Draw.rect(d.x + d.w - 4, d.y - 3, 4, 4, frame)

      -- A little light spilling through, so it reads as a way out.
      local glow = 0.16 + 0.06 * math.sin(love.timer.getTime() * 2)
      Draw.rect(d.x + 3, d.y + d.h - 1, d.w - 6, 3, {0.55, 0.45, 0.75, glow})
      Draw.rect(d.x + 2, d.y + d.h + 3, d.w - 4, 2,
        {room.wall[1] * 0.8, room.wall[2] * 0.8, room.wall[3] * 0.8})
    end
  end

  self:drawHero()

  if self.titleTimer > 0 then
    local alpha = math.min(1, self.titleTimer)
    Draw.text(room.title, 8, 8, {alpha, alpha, alpha})
  end

  if self.menuOpen then self:drawMenu() end
  self.box:draw()

  local dark = self:sleepDarkness()
  if dark > 0 then
    Draw.fade(dark)
    if self.sleep and self.sleep.phase == "hold" then
      local dots = 1 + math.floor(self.sleep.t * 2) % 3
      Draw.textCentered(string.rep("Z", dots), Draw.W / 2, Draw.H / 2 - 4, {0.8, 0.8, 0.9})
    end
  end

  if self.flash > 0 then
    love.graphics.setColor(1, 1, 1, math.min(1, self.flash))
    love.graphics.rectangle("fill", 0, 0, Draw.W, Draw.H)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

return Overworld
