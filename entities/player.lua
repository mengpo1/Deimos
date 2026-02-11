-- Player actor driven by input with smooth bounded movement.
local Class = require("core.class")
local Actor = require("core.actor")

local Player = Class(Actor)

-- Initialize player state with speed and optional spawn position.
function Player:init(options)
  Player.super.init(self, options)
  self.speed = options.speed or 180
  self.color = options.color or { 0.92, 0.92, 0.92 }
end

-- Place the player in the center of the room.
function Player:spawnAtRoomCenter(room)
  self.position.x = room.origin.x + room.width / 2
  self.position.y = room.origin.y + room.height / 2
end

-- Clamp player position so the square stays inside room bounds.
function Player:clampToRoom(room)
  local halfSize = self.size / 2
  self.position.x = math.max(room.origin.x + halfSize, math.min(self.position.x, room.origin.x + room.width - halfSize))
  self.position.y = math.max(room.origin.y + halfSize, math.min(self.position.y, room.origin.y + room.height - halfSize))
end

-- Consume continuous input for smooth movement each frame.
function Player:takeTurn(input, room, dt)
  local dx, dy = 0, 0

  if input:isDown("move_up") then
    dy = dy - 1
  end
  if input:isDown("move_down") then
    dy = dy + 1
  end
  if input:isDown("move_left") then
    dx = dx - 1
  end
  if input:isDown("move_right") then
    dx = dx + 1
  end

  if dx == 0 and dy == 0 then
    return false
  end

  if dx ~= 0 and dy ~= 0 then
    local normalization = math.sqrt(0.5)
    dx = dx * normalization
    dy = dy * normalization
  end

  self.position.x = self.position.x + dx * self.speed * dt
  self.position.y = self.position.y + dy * self.speed * dt
  self:clampToRoom(room)

  return true
end

return Player
