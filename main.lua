-- Love2D demo: seeded procedural 3-zone generation + player roaming.
local Input = require("core.input")
local Player = require("entities.player")
local TurnManager = require("core.turn_manager")
local LevelGenerator = require("world.level_generator")

local world
local player
local turnManager
local input
local generationReport

local TILE_SIZE = 12
local ZONE_GAP = 8

-- Define input bindings for movement and legacy combat/inventory actions.
local function buildBindings()
  return {
    move_up = { "up", "w" },
    move_down = { "down", "s" },
    move_left = { "left", "a" },
    move_right = { "right", "d" },
    attack = { "space", "mouse1" },
    pickup = { "e" },
    swap_weapon = { "q" },
    drop_weapon = { "g" },
  }
end

local function tileKey(tx, ty)
  return string.format("%d,%d", tx, ty)
end

local function toGlobalPoint(localPoint, offset)
  return {
    x = offset.x + localPoint.x - 1,
    y = offset.y + localPoint.y - 1,
  }
end

local function carveBridgeTiles(tileMap, fromPoint, toPoint)
  local x1, y1 = fromPoint.x, fromPoint.y
  local x2, y2 = toPoint.x, toPoint.y

  local step = x1 <= x2 and 1 or -1
  for x = x1, x2, step do
    tileMap[tileKey(x, y1)] = "floor"
  end

  if y1 ~= y2 then
    local yStep = y1 <= y2 and 1 or -1
    for y = y1, y2, yStep do
      tileMap[tileKey(x2, y)] = "floor"
    end
  end
end

local function bakeZoneTiles(tileMap, zoneData, offset)
  for _, tile in ipairs(zoneData.tiles) do
    local gx = offset.x + tile.x - 1
    local gy = offset.y + tile.y - 1
    local key = tileKey(gx, gy)

    if tile.type == "floor" then
      tileMap[key] = "floor"
    elseif tileMap[key] ~= "floor" then
      tileMap[key] = "wall"
    end
  end

  for _, room in ipairs(zoneData.rooms) do
    for _, door in ipairs(room.doors or {}) do
      local gx = offset.x + door.x - 1
      local gy = offset.y + door.y - 1
      tileMap[tileKey(gx, gy)] = "door"
    end
  end
end

local function buildPlayableMap(level)
  local offsets = {
    zone1 = { x = 2, y = 2 },
    zone2 = { x = 2 + level.zone1.dimensions.width + ZONE_GAP, y = 2 },
    zone3 = { x = 2 + level.zone1.dimensions.width + ZONE_GAP + level.zone2.dimensions.width + ZONE_GAP, y = 2 },
  }

  local tileMap = {}
  bakeZoneTiles(tileMap, level.zone1, offsets.zone1)
  bakeZoneTiles(tileMap, level.zone2, offsets.zone2)
  bakeZoneTiles(tileMap, level.zone3, offsets.zone3)

  local connector12a = toGlobalPoint(level.zone1.connector_to_zone2.zone1, offsets.zone1)
  local connector12b = toGlobalPoint(level.zone1.connector_to_zone2.zone2, offsets.zone2)
  local connector23a = toGlobalPoint(level.zone2.connector_to_zone3.zone2, offsets.zone2)
  local connector23b = toGlobalPoint(level.zone2.connector_to_zone3.zone3, offsets.zone3)

  carveBridgeTiles(tileMap, connector12a, connector12b)
  carveBridgeTiles(tileMap, connector23a, connector23b)

  local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
  for key in pairs(tileMap) do
    local tx, ty = key:match("(-?%d+),(-?%d+)")
    tx, ty = tonumber(tx), tonumber(ty)
    minX = math.min(minX, tx)
    maxX = math.max(maxX, tx)
    minY = math.min(minY, ty)
    maxY = math.max(maxY, ty)
  end

  return {
    tileMap = tileMap,
    offsets = offsets,
    connectors = {
      zone1_to_zone2 = { from = connector12a, to = connector12b },
      zone2_to_zone3 = { from = connector23a, to = connector23b },
    },
    bounds = {
      minX = minX,
      minY = minY,
      maxX = maxX,
      maxY = maxY,
    },
  }
end

local function pixelToTile(worldState, x, y)
  local tx = math.floor(x / worldState.tileSize) + 1
  local ty = math.floor(y / worldState.tileSize) + 1
  return tx, ty
end

local function isWalkableTile(worldState, tx, ty)
  local t = worldState.tileMap[tileKey(tx, ty)]
  return t == "floor" or t == "door"
end

local function buildWorldFromLevel(level)
  local map = buildPlayableMap(level)
  local worldWidth = (map.bounds.maxX + 2) * TILE_SIZE
  local worldHeight = (map.bounds.maxY + 2) * TILE_SIZE

  local worldState = {
    room = {
      tileSize = TILE_SIZE,
      origin = { x = 0, y = 0 },
      width = worldWidth,
      height = worldHeight,
    },
    tileSize = TILE_SIZE,
    tileMap = map.tileMap,
    mapBounds = map.bounds,
    connectors = map.connectors,
    zoneOffsets = map.offsets,
    level = level,
    targets = {},
    pickups = {},
    message = "",
    messageTimer = 0,
  }

  function worldState:createPickup(options)
    return {
      position = { x = options.x, y = options.y },
      toInventoryItem = function()
        return { id = options.weaponId, durability = options.durability }
      end,
      getWeapon = function()
        return { id = options.weaponId, label = options.weaponId, damage = 0, range = 0 }
      end,
      draw = function() end,
    }
  end

  function worldState:isWalkablePosition(x, y, radius)
    local r = radius or 0
    local points = {
      { x = x, y = y },
      { x = x - r, y = y },
      { x = x + r, y = y },
      { x = x, y = y - r },
      { x = x, y = y + r },
    }

    for _, point in ipairs(points) do
      local tx, ty = pixelToTile(self, point.x, point.y)
      if not isWalkableTile(self, tx, ty) then
        return false
      end
    end

    return true
  end

  return worldState
end

local function spawnPlayerAtZone1Entry(worldState)
  local entry = worldState.level.zone1.entry
  local offset = worldState.zoneOffsets.zone1
  local gx = offset.x + entry.x - 1
  local gy = offset.y + entry.y - 1
  return (gx - 0.5) * worldState.tileSize, (gy - 0.5) * worldState.tileSize
end

local function drawGeneratedWorld(worldState)
  local minX, maxX = worldState.mapBounds.minX - 1, worldState.mapBounds.maxX + 1
  local minY, maxY = worldState.mapBounds.minY - 1, worldState.mapBounds.maxY + 1

  for ty = minY, maxY do
    for tx = minX, maxX do
      local t = worldState.tileMap[tileKey(tx, ty)]
      local px = (tx - 1) * worldState.tileSize
      local py = (ty - 1) * worldState.tileSize

      if t == "floor" then
        love.graphics.setColor(0.13, 0.13, 0.13)
        love.graphics.rectangle("fill", px, py, worldState.tileSize, worldState.tileSize)
      elseif t == "door" then
        love.graphics.setColor(0.72, 0.72, 0.72)
        love.graphics.rectangle("fill", px, py, worldState.tileSize, worldState.tileSize)
      else
        love.graphics.setColor(0.07, 0.07, 0.07)
        love.graphics.rectangle("fill", px, py, worldState.tileSize, worldState.tileSize)
      end
    end
  end
end

-- Initialize generation test + playable map.
function love.load()
  love.window.setTitle("Deimos - Procedural Level Roaming")
  love.graphics.setBackgroundColor(0.03, 0.03, 0.03)

  local seed = 1337
  generationReport = LevelGenerator.runSmokeTest(seed, 3)
  local level = LevelGenerator.generateLevel(seed)
  world = buildWorldFromLevel(level)

  local windowWidth = (world.mapBounds.maxX + 3) * world.tileSize
  local windowHeight = math.max((world.mapBounds.maxY + 3) * world.tileSize, 220)
  love.window.setMode(windowWidth, windowHeight, { resizable = false })

  player = Player:new({
    size = world.tileSize * 0.8,
    speed = world.tileSize * 12,
    equippedWeaponId = "fists",
  })

  player.position.x, player.position.y = spawnPlayerAtZone1Entry(world)

  input = Input:new(buildBindings())
  turnManager = TurnManager:new({ player })
end

-- Update actor and transient message states.
function love.update(dt)
  turnManager:update(input, world, dt)

  if world.messageTimer > 0 then
    world.messageTimer = math.max(0, world.messageTimer - dt)
    if world.messageTimer == 0 then
      world.message = ""
    end
  end

  input:clearPressed()
end

-- Draw generated level and player roaming HUD.
function love.draw()
  drawGeneratedWorld(world)
  player:draw()

  local weapon = player:getEquippedWeapon()

  love.graphics.setColor(0.9, 0.9, 0.9)
  love.graphics.print(string.format("Seed: %d | Smoke test: %s (%d runs)", generationReport.seed, generationReport.ok and "OK" or "KO", generationReport.runs), 14, 10)
  love.graphics.print("Déplacement: Flèches/WASD (plus nerveux) | Niveau procédural multi-zones", 14, 28)
  love.graphics.print(string.format("Arme active: %s | Dégâts: %d | Portée: %d", weapon.label, weapon.damage, weapon.range), 14, 46)

  if world.message ~= "" then
    love.graphics.print(world.message, 14, 64)
  end
end

function love.keypressed(key)
  input:registerPress(key)
end

function love.keyreleased(key)
  input:registerRelease(key)
end

function love.mousepressed(_, _, button)
  if button == 1 then
    input:registerPress("mouse1")
  end
end

function love.mousereleased(_, _, button)
  if button == 1 then
    input:registerRelease("mouse1")
  end
end
