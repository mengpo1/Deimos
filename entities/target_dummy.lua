-- Simple target used to validate melee attacks and damage values.
local Class = require("core.class")
local Entity = require("core.entity")

local TargetDummy = Class(Entity)

-- Initialize dummy state with health and color.
function TargetDummy:init(options)
  TargetDummy.super.init(self, options)
  self.maxHealth = options.maxHealth or 30
  self.health = self.maxHealth
  self.color = options.color or { 0.45, 0.45, 0.45 }
  self.isAlive = true
  self.facingAngle = options.facingAngle or 0
  self.velocity = { x = 0, y = 0 }
  self.hitstunRemaining = 0
end

-- Apply incoming damage and mark dummy dead when health reaches zero.
function TargetDummy:takeDamage(amount)
  self.health = math.max(0, self.health - amount)
  self.isAlive = self.health > 0
end

-- Apply knockback velocity and hitstun duration.
function TargetDummy:applyImpact(forceX, forceY, hitstun)
  self.velocity.x = self.velocity.x + forceX
  self.velocity.y = self.velocity.y + forceY
  self.hitstunRemaining = math.max(self.hitstunRemaining, hitstun or 0)
end

-- Update dummy effects (knockback damping + hitstun countdown).
function TargetDummy:update(dt, room)
  if not self.isAlive then
    return
  end

  if self.hitstunRemaining > 0 then
    self.hitstunRemaining = math.max(0, self.hitstunRemaining - dt)
  end

  self.position.x = self.position.x + self.velocity.x * dt
  self.position.y = self.position.y + self.velocity.y * dt

  local damping = math.exp(-8 * dt)
  self.velocity.x = self.velocity.x * damping
  self.velocity.y = self.velocity.y * damping

  local halfSize = self.size / 2
  self.position.x = math.max(room.origin.x + halfSize, math.min(self.position.x, room.origin.x + room.width - halfSize))
  self.position.y = math.max(room.origin.y + halfSize, math.min(self.position.y, room.origin.y + room.height - halfSize))
end

-- Draw dummy only while alive.
function TargetDummy:draw()
  if not self.isAlive then
    return
  end

  love.graphics.setColor(self.color)
  love.graphics.rectangle(
    "fill",
    self.position.x - self.size / 2,
    self.position.y - self.size / 2,
    self.size,
    self.size
  )

  local fx = math.cos(self.facingAngle) * (self.size * 0.7)
  local fy = math.sin(self.facingAngle) * (self.size * 0.7)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(2)
  love.graphics.line(self.position.x, self.position.y, self.position.x + fx, self.position.y + fy)

  love.graphics.setColor(0.9, 0.9, 0.9)
  love.graphics.print(tostring(self.health), self.position.x - 6, self.position.y - 8)
end

return TargetDummy
