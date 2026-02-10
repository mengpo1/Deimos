-- Love2D entry point wiring the core systems together.
local Input = require("core.input")
local Room = require("world.room")
local Player = require("entities.player")
local TurnManager = require("core.turn_manager")

local room
local player
local turnManager
local input

-- Define default input bindings for movement actions.
local function buildBindings()
  return {
    move_up = { "up", "w" },
    move_down = { "down", "s" },
    move_left = { "left", "a" },
    move_right = { "right", "d" },
  }
end

-- Initialize the room, player, input, and turn manager.
function love.load()
  love.window.setTitle("Deimos - Prototype")
  love.graphics.setBackgroundColor(0.04, 0.04, 0.04)

  room = Room:new({
    tileSize = 32,
    tilesWide = 18,
    tilesHigh = 12,
  })

  local windowWidth = room.width + room.padding * 2
  local windowHeight = room.height + room.padding * 2
  love.window.setMode(windowWidth, windowHeight, { resizable = false })

  room.origin.x = room.padding
  room.origin.y = room.padding

  player = Player:new({
    size = 24,
    gridX = math.ceil(room.tilesWide / 2),
    gridY = math.ceil(room.tilesHigh / 2),
  })
  player:syncToRoom(room)

  input = Input:new(buildBindings())

  turnManager = TurnManager:new({ player })
end

-- Update the active turn and clear input each frame.
function love.update()
  turnManager:update(input, room)
  input:clearPressed()
end

-- Render the room, player, and helper text.
function love.draw()
  room:draw()
  player:draw()

  love.graphics.setColor(0.75, 0.75, 0.75)
  love.graphics.print("Flèches ou WASD pour bouger", 24, 12)
end

-- Register key presses for turn consumption.
function love.keypressed(key)
  input:registerPress(key)
end
