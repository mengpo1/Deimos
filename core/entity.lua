-- Base drawable entity with position, size, and color.
local Class = require("core.class")

local Entity = Class()

-- Initialize the entity with position/size/color options.
function Entity:init(options)
  self.position = {
    x = options.x or 0,
    y = options.y or 0,
  }
  self.size = options.size or 24
  self.color = options.color or { 0.9, 0.9, 0.9 }
end

-- Draw the entity as a filled square.
function Entity:draw()
  love.graphics.setColor(self.color)
  love.graphics.rectangle(
    "fill",
    self.position.x - self.size / 2,
    self.position.y - self.size / 2,
    self.size,
    self.size
  )
end

return Entity
