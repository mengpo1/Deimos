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

local TILE_SIZE = 24
local SEED = 1337
local ROOM_VIEW_PADDING_TILES = 2

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
  local activeRoom = zone.rooms[1]

  local room = Room:new({
    tileSize = TILE_SIZE,
    tilesWide = zone.dimensions.width,
    tilesHigh = zone.dimensions.height,
    padding = 24,
  })

  local viewTilesWide = activeRoom.width + ROOM_VIEW_PADDING_TILES * 2
  local viewTilesHigh = activeRoom.height + ROOM_VIEW_PADDING_TILES * 2
  local windowWidth = viewTilesWide * TILE_SIZE
  local windowHeight = viewTilesHigh * TILE_SIZE
  love.window.setMode(windowWidth, windowHeight, { resizable = false })

  room.origin.x = 0
  room.origin.y = 0

  local worldState = {
    room = room,
    zone = zone,
    activeRoom = activeRoom,
    tileLookup = buildZoneTileLookup(zone),
    targets = {},
    pickups = {},
    message = "",
    messageTimer = 0,
  }


  local pickupTileA = { x = activeRoom.x + 2, y = activeRoom.y + 2 }
  local pickupTileB = { x = activeRoom.x + activeRoom.width - 3, y = activeRoom.y + activeRoom.height - 3 }
  local pickupA = tileToWorld(room, pickupTileA.x, pickupTileA.y)
  local pickupB = tileToWorld(room, pickupTileB.x, pickupTileB.y)

  worldState.pickups = {
    WeaponPickup:new({ x = pickupA.x, y = pickupA.y, weaponId = "stick" }),
    WeaponPickup:new({ x = pickupB.x, y = pickupB.y, weaponId = "knife" }),
  }
  function worldState:createPickup(options)
    return WeaponPickup:new(options)
  end


  function worldState:getCameraRect(focus)
    local focusX = (focus and focus.position and focus.position.x) or (self.room.width * 0.5)
    local focusY = (focus and focus.position and focus.position.y) or (self.room.height * 0.5)

    local viewWidth = love.graphics.getWidth()
    local viewHeight = love.graphics.getHeight()

    local x = focusX - viewWidth * 0.5
    local y = focusY - viewHeight * 0.5

    x = math.max(0, math.min(x, self.room.width - viewWidth))
    y = math.max(0, math.min(y, self.room.height - viewHeight))

    local minTileX = math.floor(x / self.room.tileSize) + 1
    local minTileY = math.floor(y / self.room.tileSize) + 1
    local maxTileX = math.ceil((x + viewWidth) / self.room.tileSize)
    local maxTileY = math.ceil((y + viewHeight) / self.room.tileSize)

    return {
      x = x,
      y = y,
      width = viewWidth,
      height = viewHeight,
      minTileX = minTileX,
      minTileY = minTileY,
      maxTileX = maxTileX,
      maxTileY = maxTileY,
    }
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
  local room = worldState.activeRoom
  local spawnTile = {
    x = room.x + 1,
    y = room.y + math.floor(room.height / 2),
  }

  local spawn = tileToWorld(worldState.room, spawnTile.x, spawnTile.y)
  player.position.x = spawn.x
  player.position.y = spawn.y
end

local function drawZoneTiles(worldState, cam)

  for ty = cam.minTileY, cam.maxTileY do
    for tx = cam.minTileX, cam.maxTileX do
      local tileType = worldState.tileLookup[tileKey(tx, ty)] or "void"
      local x = (tx - 1) * worldState.room.tileSize
      local y = (ty - 1) * worldState.room.tileSize

      if tileType == "floor" then
        love.graphics.setColor(0.14, 0.14, 0.14)
      elseif tileType == "door" then
        love.graphics.setColor(0.72, 0.72, 0.72)
      elseif tileType == "wall" then
        love.graphics.setColor(0.07, 0.07, 0.07)
      else
        love.graphics.setColor(0.02, 0.02, 0.02)
      end

      love.graphics.rectangle("fill", x, y, worldState.room.tileSize, worldState.room.tileSize)
    end
  end

  love.graphics.setColor(0.26, 0.26, 0.26)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", (worldState.activeRoom.x - 1) * worldState.room.tileSize, (worldState.activeRoom.y - 1) * worldState.room.tileSize, worldState.activeRoom.width * worldState.room.tileSize, worldState.activeRoom.height * worldState.room.tileSize)
end

function love.load()
  love.window.setTitle("Deimos - Zone 1 générée")
  love.graphics.setBackgroundColor(0.04, 0.04, 0.04)

  local zone = Zone1Generator.generate(SEED)
  world = buildWorldFromZone(zone)

  player = Player:new({ size = 16, speed = 520, equippedWeaponId = "fists" })
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
  local cam = world:getCameraRect(player)
  love.graphics.push()
  love.graphics.translate(-cam.x, -cam.y)

  drawZoneTiles(world, cam)

  for _, pickup in ipairs(world.pickups) do
    pickup:draw()
  end

  player:draw()
  love.graphics.pop()

  local weapon = player:getEquippedWeapon()

  love.graphics.setColor(0.85, 0.85, 0.85)
  love.graphics.print("Caméra qui suit le joueur", 12, 8)
  love.graphics.print("Déplacement: Flèches/WASD", 12, 24)
  love.graphics.print(string.format("Arme: %s | Dégâts: %d | Portée: %d", weapon.label, weapon.damage, weapon.range), 12, 40)

  if world.message ~= "" then
    love.graphics.print(world.message, 12, 56)
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
