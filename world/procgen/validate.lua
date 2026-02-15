-- Flood-fill and structural validations for zones/levels.
local Tiles = require("world.procgen.tiles")

local Validate = {}

local function keyOf(x, y)
  return string.format("%d,%d", x, y)
end

function Validate.floodFill(grid, start)
  if not Tiles.inBounds(grid, start.x, start.y) then
    return {}
  end

  if not Tiles.isWalkable(Tiles.get(grid, start.x, start.y)) then
    return {}
  end

  local queue = { { x = start.x, y = start.y } }
  local visited = { [keyOf(start.x, start.y)] = true }
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
      if (not visited[k]) and Tiles.inBounds(grid, n.x, n.y) and Tiles.isWalkable(Tiles.get(grid, n.x, n.y)) then
        visited[k] = true
        queue[#queue + 1] = n
      end
    end
  end

  return visited
end

function Validate.zoneTilesInBounds(zone)
  for y = 1, zone.height do
    if type(zone.tiles[y]) ~= "table" then
      return false
    end
    for x = 1, zone.width do
      local tile = zone.tiles[y][x]
      if tile ~= Tiles.WALL and tile ~= Tiles.FLOOR and tile ~= Tiles.DOOR then
        return false
      end
    end
  end
  return true
end

function Validate.zoneConnected(zone)
  if not zone.entryDoor or not zone.exitDoor then
    return false
  end

  local visited = Validate.floodFill(zone.tiles, zone.entryDoor)
  return visited[keyOf(zone.exitDoor.x, zone.exitDoor.y)] == true
end

function Validate.zone(levelZone)
  return Validate.zoneTilesInBounds(levelZone) and Validate.zoneConnected(levelZone)
end

function Validate.level(levelData)
  for _, zone in ipairs(levelData.zones) do
    if not Validate.zone(zone) then
      return false
    end
  end

  if #levelData.connectors ~= 2 then
    return false
  end

  return true
end

return Validate
