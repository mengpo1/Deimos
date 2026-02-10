-- Player actor driven by input with grid-based movement.
local Class = require("core.class")
local Actor = require("core.actor")

local Player = Class(Actor)

-- Initialize player state, including grid position.
function Player:init(options)
  Player.super.init(self, options)
  self.gridPosition = {
    x = options.gridX or 1,
    y = options.gridY or 1,
  }
  self.color = options.color or { 0.92, 0.92, 0.92 }
end

-- Sync the world position to the grid position.
function Player:syncToRoom(room)
  self.position.x, self.position.y = room:gridToWorld(self.gridPosition.x, self.gridPosition.y)
end

-- Attempt to move by a grid delta; returns true on success.
function Player:moveBy(dx, dy, room)
  local targetX = self.gridPosition.x + dx
  local targetY = self.gridPosition.y + dy

  if room:isInsideGrid(targetX, targetY) then
    self.gridPosition.x = targetX
    self.gridPosition.y = targetY
    self:syncToRoom(room)
    return true
  end

  return false
end

-- Consume one input action per turn to move the player.
function Player:takeTurn(input, room)
  local dx, dy = 0, 0

  if input:wasPressed("move_up") then
    dy = -1
  elseif input:wasPressed("move_down") then
    dy = 1
  elseif input:wasPressed("move_left") then
    dx = -1
  elseif input:wasPressed("move_right") then
    dx = 1
  else
    return false
  end

  return self:moveBy(dx, dy, room)
end

return Player
