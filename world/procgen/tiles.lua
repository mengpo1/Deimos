-- Tile constants and 2D grid helpers.
local Tiles = {
  WALL = "WALL",
  FLOOR = "FLOOR",
  DOOR = "DOOR",
}

function Tiles.create(width, height, value)
  local grid = {}
  local fill = value or Tiles.WALL
  for y = 1, height do
    grid[y] = {}
    for x = 1, width do
      grid[y][x] = fill
    end
  end
  return grid
end

function Tiles.inBounds(grid, x, y)
  return y >= 1 and y <= #grid and x >= 1 and x <= #grid[1]
end

function Tiles.get(grid, x, y)
  if Tiles.inBounds(grid, x, y) then
    return grid[y][x]
  end
  return nil
end

function Tiles.set(grid, x, y, value)
  if Tiles.inBounds(grid, x, y) then
    grid[y][x] = value
    return true
  end
  return false
end

function Tiles.isWalkable(value)
  return value == Tiles.FLOOR or value == Tiles.DOOR
end

return Tiles
