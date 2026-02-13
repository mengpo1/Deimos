-- Love2D entry point wiring input, world state, movement, and melee combat.
local Input = require("core.input")
local Room = require("world.room")
local Player = require("entities.player")
local TargetDummy = require("entities.target_dummy")
local TurnManager = require("core.turn_manager")
local WeaponPickup = require("world.weapon_pickup")

local world
local player
local turnManager
local input

-- Define default input bindings for movement, attack, pickup, and inventory actions.
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

-- Spawn basic targets and weapon pickups for combat iteration.
local function buildWorldContent(room)
  local targets = {
    TargetDummy:new({ x = room.origin.x + room.width * 0.72, y = room.origin.y + room.height * 0.50, size = 24, maxHealth = 40, facingAngle = math.pi }),
    TargetDummy:new({ x = room.origin.x + room.width * 0.62, y = room.origin.y + room.height * 0.32, size = 20, maxHealth = 25, facingAngle = math.pi * 0.5 }),
  }

  local pickups = {
    WeaponPickup:new({ x = room.origin.x + room.width * 0.30, y = room.origin.y + room.height * 0.30, weaponId = "stick" }),
    WeaponPickup:new({ x = room.origin.x + room.width * 0.22, y = room.origin.y + room.height * 0.64, weaponId = "bat" }),
    WeaponPickup:new({ x = room.origin.x + room.width * 0.82, y = room.origin.y + room.height * 0.28, weaponId = "knife" }),
    WeaponPickup:new({ x = room.origin.x + room.width * 0.80, y = room.origin.y + room.height * 0.72, weaponId = "sabre" }),
  }

  return targets, pickups
end

-- Initialize room prototype, entities, input, and turn manager.
function love.load()
  love.window.setTitle("Deimos - Prototype")
  love.graphics.setBackgroundColor(0.04, 0.04, 0.04)

  local room = Room:new({ tileSize = 32, tilesWide = 22, tilesHigh = 14 })
  local windowWidth = room.width + room.padding * 2
  local windowHeight = room.height + room.padding * 2
  love.window.setMode(windowWidth, windowHeight, { resizable = false })

  room.origin.x = room.padding
  room.origin.y = room.padding

  player = Player:new({ size = 24, speed = 384, equippedWeaponId = "fists" })
  player:spawnAtRoomCenter(room)

  local targets, pickups = buildWorldContent(room)
  world = {
    room = room,
    targets = targets,
    pickups = pickups,
    message = "",
    messageTimer = 0,
  }

  function world:createPickup(options)
    return WeaponPickup:new(options)
  end

  input = Input:new(buildBindings())
  turnManager = TurnManager:new({ player })
end

-- Update active actor, dummies effects, and transient UI messages.
function love.update(dt)
  turnManager:update(input, world, dt)

  for _, target in ipairs(world.targets) do
    target:update(dt, world.room)
  end

  if world.messageTimer > 0 then
    world.messageTimer = math.max(0, world.messageTimer - dt)
    if world.messageTimer == 0 then
      world.message = ""
    end
  end

  input:clearPressed()
end

-- Draw room geometry, entities, pickups, and HUD.
function love.draw()
  world.room:draw()

  for _, pickup in ipairs(world.pickups) do
    pickup:draw()
  end

  for _, target in ipairs(world.targets) do
    target:draw()
  end

  player:draw()

  local weapon = player:getEquippedWeapon()

  love.graphics.setColor(0.75, 0.75, 0.75)
  love.graphics.print("Déplacement: Flèches/WASD (nerveux)", 24, 8)
  love.graphics.print("Attaque: Espace ou clic gauche", 24, 24)
  love.graphics.print("Ramasser: E | Swap: Q | Lâcher: G", 24, 40)
  love.graphics.print(string.format("Arme: %s | Dégâts: %d | Portée: %d", weapon.label, weapon.damage, weapon.range), 24, 56)
  love.graphics.print(string.format("Cooldown: %.2fs | Arc: %d° | Durabilité: %s", weapon.cooldown, weapon.arcDegrees, player:getEquippedDurabilityText()), 24, 72)

  if world.message ~= "" then
    love.graphics.setColor(0.88, 0.88, 0.88)
    love.graphics.print(world.message, 24, 94)
  end
end

-- Register key presses for action handling.
function love.keypressed(key)
  input:registerPress(key)
end

-- Register key releases for held-state handling.
function love.keyreleased(key)
  input:registerRelease(key)
end

-- Register left-click as attack input.
function love.mousepressed(_, _, button)
  if button == 1 then
    input:registerPress("mouse1")
  end
end

-- Release left-click held state.
function love.mousereleased(_, _, button)
  if button == 1 then
    input:registerRelease("mouse1")
  end
end
