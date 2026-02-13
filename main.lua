-- Love2D entry point: generate Zone 1 and let player roam in it.
local Input = require("core.input")
local Room = require("world.room")
local Player = require("entities.player")
local TurnManager = require("core.turn_manager")
local WeaponPickup = require("world.weapon_pickup")
local Zone1Generator = require("world.zone1_generator")

local world
local player
local turnManager
local input

local TILE_SIZE = 16
local SEED = 1337

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

local function buildZoneTileLookup(zone)
  local lookup = {}
  for _, tile in ipairs(zone.tiles) do
    lookup[tileKey(tile.x, tile.y)] = tile.type
  end
  return lookup
end

local function tileToWorld(room, tx, ty)
  return {
    x = room.origin.x + (tx - 0.5) * room.tileSize,
    y = room.origin.y + (ty - 0.5) * room.tileSize,
  }
end

local function worldToTile(room, x, y)
  local tx = math.floor((x - room.origin.x) / room.tileSize) + 1
  local ty = math.floor((y - room.origin.y) / room.tileSize) + 1
  return tx, ty
end

local function isWalkableTile(worldState, tx, ty)
  local tileType = worldState.tileLookup[tileKey(tx, ty)]
  return tileType == "floor" or tileType == "door"
end

local function buildWorldFromZone(zone)
  local room = Room:new({
    tileSize = TILE_SIZE,
    tilesWide = zone.dimensions.width,
    tilesHigh = zone.dimensions.height,
    padding = 24,
  })

  local windowWidth = room.width + room.padding * 2
  local windowHeight = room.height + room.padding * 2
  love.window.setMode(windowWidth, windowHeight, { resizable = false })

  room.origin.x = room.padding
  room.origin.y = room.padding

  local worldState = {
    room = room,
    zone = zone,
    tileLookup = buildZoneTileLookup(zone),
    targets = {},
    pickups = {
      WeaponPickup:new({ x = room.origin.x + room.width * 0.25, y = room.origin.y + room.height * 0.30, weaponId = "stick" }),
      WeaponPickup:new({ x = room.origin.x + room.width * 0.70, y = room.origin.y + room.height * 0.65, weaponId = "knife" }),
    },
    message = "",
    messageTimer = 0,
  }

  function worldState:createPickup(options)
    return WeaponPickup:new(options)
  end

  function worldState:isWalkablePosition(x, y, radius)
    local r = radius or 0
    local samples = {
      { x = x, y = y },
      { x = x - r, y = y },
      { x = x + r, y = y },
      { x = x, y = y - r },
      { x = x, y = y + r },
    }

    for _, sample in ipairs(samples) do
      local tx, ty = worldToTile(self.room, sample.x, sample.y)
      if not isWalkableTile(self, tx, ty) then
        return false
      end
    end

    return true
  end

  return worldState
end

local function spawnPlayerInZoneEntry(worldState)
  local spawnTile = {
    x = math.min(worldState.zone.entry.x + 1, worldState.zone.dimensions.width),
    y = worldState.zone.entry.y,
  }

  local spawn = tileToWorld(worldState.room, spawnTile.x, spawnTile.y)
  player.position.x = spawn.x
  player.position.y = spawn.y
end

local function drawZoneTiles(worldState)
  for _, tile in ipairs(worldState.zone.tiles) do
    local x = worldState.room.origin.x + (tile.x - 1) * worldState.room.tileSize
    local y = worldState.room.origin.y + (tile.y - 1) * worldState.room.tileSize

    if tile.type == "floor" then
      love.graphics.setColor(0.14, 0.14, 0.14)
    elseif tile.type == "door" then
      love.graphics.setColor(0.72, 0.72, 0.72)
    else
      love.graphics.setColor(0.07, 0.07, 0.07)
    end

    love.graphics.rectangle("fill", x, y, worldState.room.tileSize, worldState.room.tileSize)
  end

  love.graphics.setColor(0.24, 0.24, 0.24)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", worldState.room.origin.x, worldState.room.origin.y, worldState.room.width, worldState.room.height)
end

function love.load()
  love.window.setTitle("Deimos - Zone 1 générée")
  love.graphics.setBackgroundColor(0.04, 0.04, 0.04)

  local zone = Zone1Generator.generate(SEED)
  world = buildWorldFromZone(zone)

  player = Player:new({ size = 12, speed = 420, equippedWeaponId = "fists" })
  spawnPlayerInZoneEntry(world)

  input = Input:new(buildBindings())
  turnManager = TurnManager:new({ player })

  world.message = string.format("Zone 1 générée (seed %d) - promène-toi.", SEED)
  world.messageTimer = 3.0
end

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

function love.draw()
  drawZoneTiles(world)

  for _, pickup in ipairs(world.pickups) do
    pickup:draw()
  end

  player:draw()

  local weapon = player:getEquippedWeapon()

  love.graphics.setColor(0.85, 0.85, 0.85)
  love.graphics.print("Zone 1 stable (orthogonale) générée procéduralement", 16, 6)
  love.graphics.print("Déplacement: Flèches/WASD", 16, 24)
  love.graphics.print(string.format("Arme: %s | Dégâts: %d | Portée: %d", weapon.label, weapon.damage, weapon.range), 16, 42)

  if world.message ~= "" then
    love.graphics.print(world.message, 16, 60)
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
