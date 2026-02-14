-- Validation helpers for zone and full-level connectivity.
local Tiles = require("world.procgen.tiles")

local Validate = {}

local function keyOf(x, y)
  return string.format("%d,%d", x, y)
end

local function isWalkable(tile)
  return tile == Tiles.FLOOR or tile == Tiles.DOOR
end

function Validate.floodFill(grid, sx, sy)
  if not Tiles.inBounds(grid, sx, sy) or not isWalkable(Tiles.get(grid, sx, sy)) then
    return {}
  end

  local queue = { { x = sx, y = sy } }
  local visited = { [keyOf(sx, sy)] = true }
  local index = 1

  while index <= #queue do
    local node = queue[index]
    index = index + 1

    local neighbors = {
      { x = node.x + 1, y = node.y },
      { x = node.x - 1, y = node.y },
      { x = node.x, y = node.y + 1 },
      { x = node.x, y = node.y - 1 },
    }

    for _, n in ipairs(neighbors) do
      local k = keyOf(n.x, n.y)
      if Tiles.inBounds(grid, n.x, n.y) and isWalkable(Tiles.get(grid, n.x, n.y)) and not visited[k] then
        visited[k] = true
        table.insert(queue, n)
      end
    end
  end

  return visited
end

function Validate.zoneConnectivity(zone)
  if not zone.entryDoor or not zone.exitDoor then
    return false
  end

  local visited = Validate.floodFill(zone.tiles, zone.entryDoor.x, zone.entryDoor.y)
  return visited[keyOf(zone.exitDoor.x, zone.exitDoor.y)] == true
end

function Validate.zoneBounds(zone)
  for y = 1, zone.height do
    for x = 1, zone.width do
      local tile = zone.tiles[y][x]
      if tile ~= Tiles.WALL and tile ~= Tiles.FLOOR and tile ~= Tiles.DOOR then
        return false
      end
    end
  end
  return true
end

function Validate.fullLevel(level)
  for _, zone in ipairs(level.zones) do
    if not Validate.zoneBounds(zone) or not Validate.zoneConnectivity(zone) then
      return false
    end
  end
  return true
end

return Validate
