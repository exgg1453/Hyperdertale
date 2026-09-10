-- Hyperdertale - the battle scene: menus, the attack bar, and bullet dodging.

local Draw = require("src.draw")
local Input = require("src.input")
local Audio = require("src.audio")
local Save = require("src.save")
local Sprites = require("src.sprites")
local Textbox = require("src.textbox")
local Items = require("src.data.items")
local Enemies = require("src.data.enemies")
local Patterns = require("src.data.patterns")
local Game = require("src.game")

local Battle = {}

local BOX = {x = 32, y = 126, w = 256, h = 62}
local BUTTONS = {"FIGHT", "ACT", "ITEM", "MERCY"}
local BUTTON_Y, BUTTON_H, BUTTON_W, BUTTON_GAP = 210, 24, 66, 8
local BUTTON_X0 = 16

local SOUL_SPEED = 88
local SOUL_SIZE = 7
local INVULN = 1.0

-- ---- helpers ---------------------------------------------------------------

local function buttonRect(index)
  return BUTTON_X0 + (index - 1) * (BUTTON_W + BUTTON_GAP), BUTTON_Y, BUTTON_W, BUTTON_H
end

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

-- ---- lifecycle -------------------------------------------------------------

function Battle:enter(args)
  args = args or {}
  local template = Enemies[args.enemy] or Enemies.critter

  -- Copy the template so a fight never mutates the shared definition.
  self.enemy = {}
  for key, value in pairs(template) do self.enemy[key] = value end
  self.enemy.hp = template.hp
  self.enemy.maxhp = template.hp

  self.returnRoom = args.returnRoom or Save.player.room
  self.returnX = args.returnX or Save.player.x
  self.returnY = args.returnY or Save.player.y

  self.state = "intro"
  self.button = 1
  self.subIndex = 1
  self.mercy = 0
  self.turn = 0
  self.actCounts = {}
  self.spareable = false
  self.shake = 0
  self.enemyFlash = 0
  self.invuln = 0
  self.bullets = {}
  self.pattern = nil
  self.result = nil

  self.soul = {x = BOX.x + BOX.w / 2, y = BOX.y + BOX.h / 2}

  self.box = Textbox.new({x = BOX.x, y = BOX.y, w = BOX.w, h = BOX.h})
  self.message = self.enemy.intro
  self.flavor = self.enemy.intro

  self.attack = nil

  Audio.play("battle")
end

-- ---- damage ----------------------------------------------------------------

function Battle:playerDamage(multiplier)
  local player = Save.player
  local base = player.at + 2 - self.enemy.df
  return math.max(1, math.floor(base * multiplier + 0.5))
end

function Battle:hurtPlayer(amount)
  if self.invuln > 0 then return end
  local player = Save.player
  local damage = math.max(1, amount + self.enemy.at - math.floor(player.df / 2))
  Save.damage(damage)
  self.invuln = INVULN
  self.shake = 4
  Audio.sfx("hurt")

  if player.hp <= 0 then
    self.state = "defeat"
    self.bullets = {}
    Audio.stop()
    self.box:say("* You cannot give up just yet...", function ()
      Game.switch("gameover", {returnRoom = self.returnRoom})
    end)
  end
end

-- ---- turn flow -------------------------------------------------------------

function Battle:beginEnemyTurn()
  self.turn = self.turn + 1
  self.state = "enemyTurn"
  self.bullets = {}
  self.soul.x = BOX.x + BOX.w / 2
  self.soul.y = BOX.y + BOX.h / 2

  local names = self.enemy.patterns
  local name = names[((self.turn - 1) % #names) + 1]
  self.pattern = Patterns.create(name)
  if self.pattern.spec.start then
    self.pattern.spec.start(self.pattern.state, self:patternContext())
  end
end

function Battle:patternContext()
  return {
    box = BOX,
    soul = self.soul,
    difficulty = math.min(4, self.turn),
    spawn = function (bullet)
      bullet.color = bullet.color or {1, 1, 1}
      self.bullets[#self.bullets + 1] = bullet
    end,
  }
end

function Battle:backToMenu()
  self.state = "menu"
  self.bullets = {}
  self.flavor = self:pickFlavor()
end

function Battle:pickFlavor()
  local pool = (self.spareable and self.enemy.tired) or self.enemy.idle
  if not pool or #pool == 0 then return "* ..." end
  return pool[math.random(#pool)]
end

function Battle:checkSpareable()
  if self.mercy >= self.enemy.spareAt or self.enemy.hp <= self.enemy.maxhp * 0.25 then
    self.spareable = true
  end
end

function Battle:win(spared)
  local player = Save.player
  self.state = "result"
  self.bullets = {}
  Audio.stop()

  local gold = self.enemy.gold
  player.gold = player.gold + gold

  local lines
  if spared then
    player.spares = player.spares + 1
    Audio.sfx("spare")
    lines = {
      self.enemy.spareText,
      "* You earned 0 EXP and " .. gold .. " GOLD.",
    }
  else
    player.kills = player.kills + 1
    Audio.sfx("levelup")
    local levelled = Save.grantExp(self.enemy.exp)
    lines = {
      self.enemy.killText,
      "* You earned " .. self.enemy.exp .. " EXP and " .. gold .. " GOLD.",
    }
    if levelled then
      lines[#lines + 1] = "* Your LOVE increased.  LV " .. player.lv .. "."
    end
  end

  self.box:say(lines, function ()
    Game.switch("overworld", {
      room = self.returnRoom, x = self.returnX, y = self.returnY, fromBattle = true,
    })
  end)
end

-- ---- menu ------------------------------------------------------------------

function Battle:submenuItems()
  if self.state ~= "submenu" then return {} end

  if self.sub == "ACT" then
    local list = {}
    for _, act in ipairs(self.enemy.acts) do list[#list + 1] = act.name end
    return list
  elseif self.sub == "ITEM" then
    local list = {}
    for _, id in ipairs(Save.player.items) do
      local item = Items[id]
      list[#list + 1] = item and item.name or id
    end
    return list
  elseif self.sub == "MERCY" then
    return {self.spareable and "SPARE" or "SPARE?", "FLEE"}
  end
  return {}
end

function Battle:openSubmenu(name)
  self.sub = name
  self.state = "submenu"
  self.subIndex = 1
end

function Battle:runAct(index)
  local act = self.enemy.acts[index]
  if not act then return end

  self.actCounts[act.name] = (self.actCounts[act.name] or 0) + 1
  local repeated = self.actCounts[act.name] > 1
  local text = (repeated and act.repeatText) or act.text

  if act.mercy > 0 and not repeated then
    self.mercy = self.mercy + act.mercy
    self:checkSpareable()
  end

  self.state = "message"
  self.box:say(text, function () self:beginEnemyTurn() end)
end

function Battle:useItem(index)
  local player = Save.player
  local id = player.items[index]
  local item = id and Items[id]
  if not item then return end

  table.remove(player.items, index)
  Save.heal(item.heal)
  Audio.sfx("heal")

  self.state = "message"
  self.box:say(item.use .. "\n* You recovered " .. item.heal .. " HP.",
    function () self:beginEnemyTurn() end)
end

function Battle:runMercy(index)
  if index == 1 then
    if self.spareable then
      self:win(true)
    else
      self.state = "message"
      self.box:say("* The HYPERLING is not ready to leave yet.",
        function () self:beginEnemyTurn() end)
    end
    return
  end

  -- FLEE: better odds the longer the fight has gone on.
  if math.random() < 0.35 + 0.15 * self.turn then
    Audio.stop()
    self.state = "result"
    self.box:say("* You ran away.", function ()
      Game.switch("overworld", {
        room = self.returnRoom, x = self.returnX, y = self.returnY, fromBattle = true,
      })
    end)
  else
    self.state = "message"
    self.box:say("* You tried to run. The HYPERLING got there first.",
      function () self:beginEnemyTurn() end)
  end
end

function Battle:startAttack()
  self.state = "attack"
  self.attack = {
    x = BOX.x + 12,
    speed = 210,
    done = false,
    timer = 0,
    damage = 0,
  }
end

-- ---- update ----------------------------------------------------------------

function Battle:updateMenu(dt)
  if Input.pressed("left") then
    self.button = self.button > 1 and self.button - 1 or #BUTTONS
    Audio.sfx("move")
  elseif Input.pressed("right") then
    self.button = self.button < #BUTTONS and self.button + 1 or 1
    Audio.sfx("move")
  end

  if Input.pressed("confirm") then
    Audio.sfx("select")
    local choice = BUTTONS[self.button]
    if choice == "FIGHT" then
      self:startAttack()
    else
      self:openSubmenu(choice)
    end
  end
end

function Battle:updateSubmenu(dt)
  local items = self:submenuItems()

  if #items == 0 then
    if Input.pressed("cancel") or Input.pressed("confirm") then
      Audio.sfx("cancel")
      self.state = "menu"
    end
    return
  end

  if Input.pressed("up") then
    self.subIndex = self.subIndex > 1 and self.subIndex - 1 or #items
    Audio.sfx("move")
  elseif Input.pressed("down") then
    self.subIndex = self.subIndex < #items and self.subIndex + 1 or 1
    Audio.sfx("move")
  end

  if Input.pressed("cancel") then
    Audio.sfx("cancel")
    self.state = "menu"
    return
  end

  if Input.pressed("confirm") then
    Audio.sfx("select")
    if self.sub == "ACT" then
      self:runAct(self.subIndex)
    elseif self.sub == "ITEM" then
      self:useItem(self.subIndex)
    else
      self:runMercy(self.subIndex)
    end
  end
end

function Battle:updateAttack(dt)
  local attack = self.attack

  if not attack.done then
    attack.x = attack.x + attack.speed * dt
    local limit = BOX.x + BOX.w - 12
    if attack.x >= limit then
      attack.x = limit
      attack.done = true
      attack.damage = 0        -- ran off the end: a clean miss
      Audio.sfx("cancel")
      attack.timer = 0.5
    end

    if Input.pressed("confirm") then
      local centre = BOX.x + BOX.w / 2
      local span = BOX.w / 2 - 12
      local offset = math.abs(attack.x - centre) / span     -- 0 dead centre, 1 at the edge
      local multiplier = clamp(2.2 - offset * 2.0, 0.2, 2.2)

      attack.done = true
      attack.damage = self:playerDamage(multiplier)
      attack.timer = 0.6
      self.enemy.hp = math.max(0, self.enemy.hp - attack.damage)
      self.enemyFlash = 0.35
      self.shake = 3
      Audio.sfx("slash")
      self:checkSpareable()
    end
    return
  end

  attack.timer = attack.timer - dt
  if attack.timer > 0 then return end

  if self.enemy.hp <= 0 then
    self:win(false)
  else
    self:beginEnemyTurn()
  end
end

function Battle:updateBullets(dt)
  local soulX = self.soul.x - SOUL_SIZE / 2
  local soulY = self.soul.y - SOUL_SIZE / 2

  for i = #self.bullets, 1, -1 do
    local bullet = self.bullets[i]
    bullet.x = bullet.x + bullet.vx * dt
    bullet.y = bullet.y + bullet.vy * dt

    local outside = bullet.x + bullet.w < BOX.x - 40
      or bullet.x > BOX.x + BOX.w + 40
      or bullet.y + bullet.h < BOX.y - 40
      or bullet.y > BOX.y + BOX.h + 40

    if outside then
      table.remove(self.bullets, i)
    elseif self.invuln <= 0
       and soulX < bullet.x + bullet.w and bullet.x < soulX + SOUL_SIZE
       and soulY < bullet.y + bullet.h and bullet.y < soulY + SOUL_SIZE then
      self:hurtPlayer(bullet.damage or 3)
    end
  end
end

function Battle:updateEnemyTurn(dt)
  local pattern = self.pattern
  pattern.elapsed = pattern.elapsed + dt

  if pattern.elapsed < pattern.duration then
    pattern.spec.update(pattern.state, dt, self:patternContext())
  end

  -- The soul, confined to the box.
  local dx, dy = Input.axes()
  self.soul.x = clamp(self.soul.x + dx * SOUL_SPEED * dt,
    BOX.x + 4 + SOUL_SIZE / 2, BOX.x + BOX.w - 4 - SOUL_SIZE / 2)
  self.soul.y = clamp(self.soul.y + dy * SOUL_SPEED * dt,
    BOX.y + 4 + SOUL_SIZE / 2, BOX.y + BOX.h - 4 - SOUL_SIZE / 2)

  self:updateBullets(dt)

  if self.state ~= "enemyTurn" then return end   -- the player may have died

  if pattern.elapsed >= pattern.duration and #self.bullets == 0 then
    self:backToMenu()
  end
end

function Battle:update(dt)
  Save.player.playtime = Save.player.playtime + dt
  self.invuln = math.max(0, self.invuln - dt)
  self.shake = math.max(0, self.shake - dt * 12)
  self.enemyFlash = math.max(0, self.enemyFlash - dt)

  if self.box.active then
    self.box:update(dt)
    if self.state == "intro" and not self.box.active then
      self.state = "menu"
      self.flavor = self:pickFlavor()
    end
    return
  end

  if self.state == "intro" then
    self.box:say(self.enemy.intro)
  elseif self.state == "menu" then
    self:updateMenu(dt)
  elseif self.state == "submenu" then
    self:updateSubmenu(dt)
  elseif self.state == "attack" then
    self:updateAttack(dt)
  elseif self.state == "enemyTurn" then
    self:updateEnemyTurn(dt)
  end
end

-- ---- draw ------------------------------------------------------------------

function Battle:drawEnemy()
  local map = (self.spareable and self.enemy.tiredSprite)
    and Sprites[self.enemy.tiredSprite] or Sprites[self.enemy.sprite]
  map = map or Sprites.critter

  local palette = Sprites.palette.critter
  if self.enemyFlash > 0 then
    palette = {["1"] = {1, 1, 1}, ["2"] = {1, 1, 1}, ["3"] = {1, 1, 1}, ["6"] = {1, 1, 1}}
  end

  local scale = 4
  local width = #map[1] * scale
  Draw.pixels(map, Draw.W / 2 - width / 2, 26, scale, palette)

  -- Enemy health bar, shown once the fight has started.
  if self.enemy.hp < self.enemy.maxhp then
    local barW = 80
    local x = Draw.W / 2 - barW / 2
    Draw.rect(x, 76, barW, 6, {0.35, 0.05, 0.05})
    Draw.rect(x, 76, barW * (self.enemy.hp / self.enemy.maxhp), 6, {0.30, 0.90, 0.30})
  end

  Draw.textCentered(self.enemy.name, Draw.W / 2, 90,
    self.spareable and {1, 1, 0.2} or {1, 1, 1})
end

function Battle:drawStats()
  local player = Save.player
  local y = 194

  Draw.text(player.name, 24, y)
  Draw.text("LV " .. player.lv, 88, y)

  local barX, barW = 140, 60
  Draw.text("HP", barX - 20, y)
  Draw.rect(barX, y, barW, 8, {0.45, 0.05, 0.05})
  Draw.rect(barX, y, barW * math.max(0, player.hp / player.maxhp), 8, {1, 1, 0.2})
  Draw.text(player.hp .. " / " .. player.maxhp, barX + barW + 8, y)
end

function Battle:drawButtons()
  for i, label in ipairs(BUTTONS) do
    local x, y, w, h = buttonRect(i)
    local selected = (self.state == "menu" or self.state == "submenu") and i == self.button
    local color = selected and {1, 1, 0.2} or {1, 0.55, 0.1}

    Draw.frame(x, y, w, h, color, 2)
    Draw.textCentered(label, x + w / 2, y + h / 2 - 4, color)

    if selected and self.state == "menu" then
      Draw.pixels(Sprites.heart, x - 12, y + h / 2 - 3, 1, Sprites.palette.heart)
    end
  end
end

function Battle:drawBoxContents()
  if self.box.active then
    self.box:draw()
    return
  end

  Draw.box(BOX.x, BOX.y, BOX.w, BOX.h)

  if self.state == "menu" then
    Draw.text(self.flavor or "", BOX.x + 12, BOX.y + 12)
    return
  end

  if self.state == "submenu" then
    local items = self:submenuItems()
    if #items == 0 then
      Draw.text("* You have nothing to use.", BOX.x + 12, BOX.y + 12)
      return
    end

    -- Two columns, the way the item and act lists are laid out in the genre.
    for i, label in ipairs(items) do
      local column = (i - 1) % 2
      local row = math.floor((i - 1) / 2)
      local x = BOX.x + 24 + column * 120
      local y = BOX.y + 12 + row * 16
      local selected = i == self.subIndex

      if selected then
        Draw.pixels(Sprites.heart, x - 14, y + 1, 1, Sprites.palette.heart)
      end

      local color = {1, 1, 1}
      if self.sub == "MERCY" and i == 1 and self.spareable then color = {1, 1, 0.2} end
      Draw.text(label, x, y, color)
    end
    return
  end

  if self.state == "attack" then
    local attack = self.attack
    -- The target zone: the closer to the middle, the harder you hit.
    local centre = BOX.x + BOX.w / 2
    Draw.rect(BOX.x + 12, BOX.y + 14, BOX.w - 24, 34, {0.10, 0.10, 0.14})
    Draw.rect(centre - 12, BOX.y + 14, 24, 34, {0.22, 0.22, 0.30})
    Draw.rect(centre - 2, BOX.y + 14, 4, 34, {0.45, 0.45, 0.55})

    Draw.rect(attack.x - 1, BOX.y + 10, 3, 42, attack.done and {1, 0.3, 0.3} or {1, 1, 1})

    if attack.done then
      local label = attack.damage > 0 and tostring(attack.damage) or "MISS"
      Draw.textCentered(label, Draw.W / 2, 100, {1, 0.25, 0.25})
    end
    return
  end

  if self.state == "enemyTurn" then
    -- Clip to the inside of the box: bullets enter and leave at its edges
    -- instead of flying across the buttons below.
    love.graphics.setScissor(BOX.x + 2, BOX.y + 2, BOX.w - 4, BOX.h - 4)

    for _, bullet in ipairs(self.bullets) do
      Draw.rect(bullet.x, bullet.y, bullet.w, bullet.h, bullet.color)
    end

    -- The soul flickers while the player is briefly invulnerable.
    local visible = self.invuln <= 0 or (math.floor(self.invuln * 16) % 2 == 0)
    if visible then
      Draw.pixels(Sprites.heart, self.soul.x - 3.5, self.soul.y - 3, 1, Sprites.palette.heart)
    end

    love.graphics.setScissor()
  end
end

function Battle:draw()
  Draw.clear({0, 0, 0})

  local sx, sy = Draw.shake(self.shake)
  love.graphics.push()
  love.graphics.translate(sx, sy)

  self:drawEnemy()
  self:drawBoxContents()
  self:drawStats()
  self:drawButtons()

  love.graphics.pop()
end

return Battle
