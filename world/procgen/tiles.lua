-- Tile constants and grid helpers.
local Tiles = {
  WALL = "WALL",
  FLOOR = "FLOOR",
  DOOR = "DOOR",
}

function Tiles.createGrid(width, height, defaultTile)
  local grid = {}
  for y = 1, height do
    grid[y] = {}
    for x = 1, width do
      grid[y][x] = defaultTile or Tiles.WALL
    end
  end
  return grid
end

function Tiles.inBounds(grid, x, y)
  return y >= 1 and y <= #grid and x >= 1 and x <= #grid[1]
end

function Tiles.set(grid, x, y, value)
  if Tiles.inBounds(grid, x, y) then
    grid[y][x] = value
    return true
  end
  return false
end

function Tiles.get(grid, x, y)
  if Tiles.inBounds(grid, x, y) then
    return grid[y][x]
  end
  return nil
end

return Tiles
