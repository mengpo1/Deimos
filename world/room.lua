-- Room container that defines a bounded grid for movement.
local Class = require("core.class")

local Room = Class()

-- Initialize the room geometry and grid dimensions.
function Room:init(options)
  self.tileSize = options.tileSize or 32
  self.tilesWide = options.tilesWide or 18
  self.tilesHigh = options.tilesHigh or 12
  self.padding = options.padding or 36

  self.width = self.tilesWide * self.tileSize
  self.height = self.tilesHigh * self.tileSize

  self.origin = {
    x = options.originX or 0,
    y = options.originY or 0,
  }
end

-- Convert world coordinates to grid coordinates.
function Room:worldToGrid(x, y)
  local gx = math.floor((x - self.origin.x) / self.tileSize) + 1
  local gy = math.floor((y - self.origin.y) / self.tileSize) + 1
  return gx, gy
end

-- Convert grid coordinates to world coordinates (center of tile).
function Room:gridToWorld(gx, gy)
  local x = self.origin.x + (gx - 0.5) * self.tileSize
  local y = self.origin.y + (gy - 0.5) * self.tileSize
  return x, y
end

-- Check if a grid coordinate is inside the room bounds.
function Room:isInsideGrid(gx, gy)
  return gx >= 1 and gx <= self.tilesWide and gy >= 1 and gy <= self.tilesHigh
end

-- Draw the room background and outline.
function Room:draw()
  love.graphics.setColor(0.07, 0.07, 0.07)
  love.graphics.rectangle("fill", self.origin.x, self.origin.y, self.width, self.height)

  love.graphics.setColor(0.22, 0.22, 0.22)
  love.graphics.setLineWidth(4)
  love.graphics.rectangle("line", self.origin.x, self.origin.y, self.width, self.height)
end

return Room
