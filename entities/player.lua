-- Player actor driven by input with smooth bounded movement and mouse aiming.
local Class = require("core.class")
local Actor = require("core.actor")

local Player = Class(Actor)

-- Initialize player state with speed, facing angle, and optional spawn position.
function Player:init(options)
  Player.super.init(self, options)
  self.speed = options.speed or 180
  self.color = options.color or { 0.92, 0.92, 0.92 }
  self.facingAngle = 0
end

-- Place the player in the center of the room.
function Player:spawnAtRoomCenter(room)
  self.position.x = room.origin.x + room.width / 2
  self.position.y = room.origin.y + room.height / 2
end

-- Clamp player position so the triangle stays inside room bounds.
function Player:clampToRoom(room)
  local halfSize = self.size / 2
  self.position.x = math.max(room.origin.x + halfSize, math.min(self.position.x, room.origin.x + room.width - halfSize))
  self.position.y = math.max(room.origin.y + halfSize, math.min(self.position.y, room.origin.y + room.height - halfSize))
end

-- Update facing direction toward the current mouse pointer.
function Player:updateFacingToMouse()
  local mouseX, mouseY = love.mouse.getPosition()
  self.facingAngle = math.atan2(mouseY - self.position.y, mouseX - self.position.x)
end

-- Draw the player as a triangle whose tip points toward the cursor.
function Player:draw()
  local forwardX = math.cos(self.facingAngle)
  local forwardY = math.sin(self.facingAngle)
  local sideX = -forwardY
  local sideY = forwardX

  local tipDistance = self.size * 0.65
  local baseDistance = self.size * 0.45
  local halfBaseWidth = self.size * 0.5

  local tipX = self.position.x + forwardX * tipDistance
  local tipY = self.position.y + forwardY * tipDistance

  local baseCenterX = self.position.x - forwardX * baseDistance
  local baseCenterY = self.position.y - forwardY * baseDistance

  local leftX = baseCenterX + sideX * halfBaseWidth
  local leftY = baseCenterY + sideY * halfBaseWidth
  local rightX = baseCenterX - sideX * halfBaseWidth
  local rightY = baseCenterY - sideY * halfBaseWidth

  love.graphics.setColor(self.color)
  love.graphics.polygon("fill", tipX, tipY, leftX, leftY, rightX, rightY)
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

  if dx ~= 0 and dy ~= 0 then
    local normalization = math.sqrt(0.5)
    dx = dx * normalization
    dy = dy * normalization
  end

  if dx ~= 0 or dy ~= 0 then
    self.position.x = self.position.x + dx * self.speed * dt
    self.position.y = self.position.y + dy * self.speed * dt
    self:clampToRoom(room)
  end

  self:updateFacingToMouse()

  return dx ~= 0 or dy ~= 0
end

return Player
