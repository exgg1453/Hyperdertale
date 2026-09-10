-- Hyperdertale - player state and its on-disk form.
-- Saves live in LOVE's per-game save directory, so the same code works on
-- Windows (%APPDATA%) and Android (app-private storage).

local Save = {}

local FILE = "hyperdertale.sav"

local function freshPlayer()
  return {
    name = "FRISK",
    lv = 1,
    hp = 20,
    maxhp = 20,
    at = 10,
    df = 10,
    exp = 0,
    gold = 0,
    room = "ruins_entry",
    x = 160,
    y = 150,
    kills = 0,
    spares = 0,
    playtime = 0,
    items = {"candy", "candy", "bandage"},
    flags = {},
  }
end

Save.player = freshPlayer()

-- ---- serialisation ---------------------------------------------------------
-- A small writer beats pulling in a dependency for a file this shape.

local function encode(value, indent)
  local t = type(value)
  if t == "number" or t == "boolean" then
    return tostring(value)
  elseif t == "string" then
    return string.format("%q", value)
  elseif t == "table" then
    local pad = string.rep("  ", indent + 1)
    local parts = {"{"}
    local isArray = #value > 0
    if isArray then
      for _, item in ipairs(value) do
        parts[#parts + 1] = pad .. encode(item, indent + 1) .. ","
      end
    else
      local keys = {}
      for key in pairs(value) do keys[#keys + 1] = key end
      table.sort(keys, function (a, b) return tostring(a) < tostring(b) end)
      for _, key in ipairs(keys) do
        parts[#parts + 1] = pad .. "[" .. string.format("%q", tostring(key)) .. "] = "
          .. encode(value[key], indent + 1) .. ","
      end
    end
    parts[#parts + 1] = string.rep("  ", indent) .. "}"
    return table.concat(parts, "\n")
  end
  return "nil"
end

local function decode(text)
  local chunk, err = load("return " .. text, "save", "t", {})
  if not chunk then return nil, err end
  local ok, result = pcall(chunk)
  if not ok then return nil, result end
  return result
end

-- ---- disk ------------------------------------------------------------------

function Save.exists()
  return love.filesystem.getInfo(FILE) ~= nil
end

function Save.write()
  local ok = love.filesystem.write(FILE, encode(Save.player, 0))
  return ok == true
end

function Save.read()
  if not Save.exists() then return false end
  local text = love.filesystem.read(FILE)
  if not text then return false end

  local data = decode(text)
  if type(data) ~= "table" then return false end

  -- Merge onto a fresh table so saves written by older builds still load.
  local player = freshPlayer()
  for key, default in pairs(player) do
    local saved = data[key]
    if saved ~= nil and type(saved) == type(default) then
      player[key] = saved
    end
  end
  Save.player = player
  return true
end

function Save.erase()
  if Save.exists() then love.filesystem.remove(FILE) end
end

function Save.reset()
  Save.player = freshPlayer()
  return Save.player
end

-- ---- rules -----------------------------------------------------------------

--- EXP needed to reach a level. One curve, whatever route the player takes.
function Save.expForLevel(lv)
  if lv <= 1 then return 0 end
  return math.floor(10 * (lv - 1) ^ 1.8 + 0.5)
end

--- Grant EXP; returns true when the player gained at least one level.
function Save.grantExp(amount)
  local p = Save.player
  p.exp = p.exp + amount
  local levelled = false
  while p.lv < 20 and p.exp >= Save.expForLevel(p.lv + 1) do
    p.lv = p.lv + 1
    p.maxhp = p.maxhp + 4
    p.hp = p.maxhp
    p.at = p.at + 2
    p.df = p.df + 1
    levelled = true
  end
  return levelled
end

function Save.heal(amount)
  local p = Save.player
  p.hp = math.min(p.maxhp, p.hp + amount)
  return p.hp
end

function Save.damage(amount)
  local p = Save.player
  p.hp = math.max(0, p.hp - amount)
  return p.hp
end

function Save.flag(name) return Save.player.flags[name] == true end

function Save.setFlag(name, value)
  Save.player.flags[name] = value ~= false
end

--- "0:12:34" for the save screen.
function Save.clock()
  local seconds = math.floor(Save.player.playtime)
  return string.format("%d:%02d:%02d",
    math.floor(seconds / 3600),
    math.floor(seconds / 60) % 60,
    seconds % 60)
end

return Save
