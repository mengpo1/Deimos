-- Procedural multi-zone level generator (Zone1 -> Zone2 -> Zone3).
-- Exposes generateLevel(seed) -> levelData.

local LevelGenerator = {}

-- Deterministic RNG (LCG) to ensure reproducibility from seed.
local function createRng(seed)
  local state = (seed or 1) % 2147483647
  if state <= 0 then
    state = state + 2147483646
  end

  local function nextInt()
    state = (state * 48271) % 2147483647
    return state
  end

  local function randomFloat()
    return nextInt() / 2147483647
  end

  local function randomInt(minValue, maxValue)
    return minValue + math.floor(randomFloat() * (maxValue - minValue + 1))
  end

  local function pick(list)
    return list[randomInt(1, #list)]
  end

  return {
    randomFloat = randomFloat,
    randomInt = randomInt,
    pick = pick,
  }
end

local function keyOf(x, y)
  return string.format("%d,%d", x, y)
end

local function clonePoint(point)
  return { x = point.x, y = point.y }
end

local function carveRect(floors, x, y, width, height)
  for yy = y, y + height - 1 do
    for xx = x, x + width - 1 do
      floors[keyOf(xx, yy)] = true
    end
  end
end

local function carveLineOrthogonal(floors, x1, y1, x2, y2, thickness)
  local t = thickness or 1

  if x1 == x2 then
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    for y = minY, maxY do
      for dx = 0, t - 1 do
        floors[keyOf(x1 + dx, y)] = true
      end
    end
    return
  end

  if y1 == y2 then
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    for x = minX, maxX do
      for dy = 0, t - 1 do
        floors[keyOf(x, y1 + dy)] = true
      end
    end
  end
end

local function carveLShapedCorridor(floors, fromPoint, toPoint, thickness)
  local mid = { x = toPoint.x, y = fromPoint.y }
  carveLineOrthogonal(floors, fromPoint.x, fromPoint.y, mid.x, mid.y, thickness)
  carveLineOrthogonal(floors, mid.x, mid.y, toPoint.x, toPoint.y, thickness)

  return {
    { x = fromPoint.x, y = fromPoint.y },
    { x = mid.x, y = mid.y },
    { x = toPoint.x, y = toPoint.y },
    thickness = thickness or 1,
  }
end

local function roomCenter(room)
  return {
    x = room.x + math.floor(room.width / 2),
    y = room.y + math.floor(room.height / 2),
  }
end

local function toTileListFromFloors(floors)
  local tiles = {}
  local minX, maxX = math.huge, -math.huge
  local minY, maxY = math.huge, -math.huge

  for key in pairs(floors) do
    local x, y = key:match("(-?%d+),(-?%d+)")
    x, y = tonumber(x), tonumber(y)
    minX = math.min(minX, x)
    maxX = math.max(maxX, x)
    minY = math.min(minY, y)
    maxY = math.max(maxY, y)
  end

  if minX == math.huge then
    return tiles
  end

  for y = minY - 1, maxY + 1 do
    for x = minX - 1, maxX + 1 do
      local floor = floors[keyOf(x, y)]
      if floor then
        table.insert(tiles, { x = x, y = y, type = "floor" })
      else
        local nearFloor = floors[keyOf(x + 1, y)] or floors[keyOf(x - 1, y)] or floors[keyOf(x, y + 1)] or floors[keyOf(x, y - 1)]
        if nearFloor then
          table.insert(tiles, { x = x, y = y, type = "wall" })
        end
      end
    end
  end

  return tiles
end

local function addDoor(doors, floors, x, y)
  floors[keyOf(x, y)] = true
  table.insert(doors, { x = x, y = y, type = "door" })
end

local function floodFillConnected(floors, startX, startY)
  local startKey = keyOf(startX, startY)
  if not floors[startKey] then
    return false
  end

  local queue = { { x = startX, y = startY } }
  local visited = { [startKey] = true }
  local index = 1

  while index <= #queue do
    local current = queue[index]
    index = index + 1

    local neighbors = {
      { x = current.x + 1, y = current.y },
      { x = current.x - 1, y = current.y },
      { x = current.x, y = current.y + 1 },
      { x = current.x, y = current.y - 1 },
    }

    for _, n in ipairs(neighbors) do
      local k = keyOf(n.x, n.y)
      if floors[k] and not visited[k] then
        visited[k] = true
        table.insert(queue, n)
      end
    end
  end

  local floorCount = 0
  for _ in pairs(floors) do
    floorCount = floorCount + 1
  end

  local visitedCount = 0
  for _ in pairs(visited) do
    visitedCount = visitedCount + 1
  end

  return visitedCount == floorCount
end

local function roomsOverlap(a, b, margin)
  local m = margin or 1
  return not (
    a.x + a.width + m <= b.x or
    b.x + b.width + m <= a.x or
    a.y + a.height + m <= b.y or
    b.y + b.height + m <= a.y
  )
end

local function edgeConnector(dimensions, edge, coordinate)
  if edge == "left" then
    return { x = 1, y = coordinate, edge = edge }
  elseif edge == "right" then
    return { x = dimensions.width, y = coordinate, edge = edge }
  elseif edge == "top" then
    return { x = coordinate, y = 1, edge = edge }
  end
  return { x = coordinate, y = dimensions.height, edge = "bottom" }
end

local function buildZone1(rng)
  local width = rng.randomInt(50, 70)
  local height = rng.randomInt(50, 70)
  local roomTarget = rng.randomInt(8, 15)

  local rooms = {}
  local floors = {}

  local attempts = 0
  while #rooms < roomTarget and attempts < roomTarget * 30 do
    attempts = attempts + 1
    local room = {
      x = rng.randomInt(2, width - 12),
      y = rng.randomInt(2, height - 12),
      width = rng.randomInt(6, 12),
      height = rng.randomInt(6, 12),
      doors = {},
    }

    local overlap = false
    for _, existing in ipairs(rooms) do
      if roomsOverlap(room, existing, 1) then
        overlap = true
        break
      end
    end

    if not overlap then
      table.insert(rooms, room)
      carveRect(floors, room.x, room.y, room.width, room.height)
    end
  end

  table.sort(rooms, function(a, b)
    return a.x < b.x
  end)

  local corridors = {}
  for i = 2, #rooms do
    local c1 = roomCenter(rooms[i - 1])
    local c2 = roomCenter(rooms[i])
    table.insert(corridors, carveLShapedCorridor(floors, c1, c2, 1))
  end

  local entryY = rng.randomInt(2, height - 1)
  local connectorY = rng.randomInt(2, height - 1)
  local entry = edgeConnector({ width = width, height = height }, "left", entryY)
  local connectorToZone2 = edgeConnector({ width = width, height = height }, "right", connectorY)

  addDoor(rooms[1].doors, floors, entry.x, entry.y)
  addDoor(rooms[#rooms].doors, floors, connectorToZone2.x, connectorToZone2.y)

  -- Ensure border doors connect inward.
  floors[keyOf(entry.x + 1, entry.y)] = true
  floors[keyOf(connectorToZone2.x - 1, connectorToZone2.y)] = true

  return {
    dimensions = { width = width, height = height },
    rooms = rooms,
    corridors = corridors,
    tiles = toTileListFromFloors(floors),
    floors = floors,
    entry = entry,
    connector_to_zone2 = connectorToZone2,
  }
end

local function buildZone2(rng)
  local width = rng.randomInt(40, 60)
  local height = rng.randomInt(40, 60)
  local roomTarget = rng.randomInt(10, 20)

  local rooms = {}
  local corridors = {}
  local floors = {}

  local centralRoom = {
    x = math.floor(width / 2) - rng.randomInt(5, 7),
    y = math.floor(height / 2) - rng.randomInt(5, 7),
    width = rng.randomInt(12, 16),
    height = rng.randomInt(12, 16),
    doors = {},
    isCentral = true,
  }
  table.insert(rooms, centralRoom)
  carveRect(floors, centralRoom.x, centralRoom.y, centralRoom.width, centralRoom.height)

  local frontier = { 1 }
  while #rooms < roomTarget and #frontier > 0 do
    local parentIndex = frontier[rng.randomInt(1, #frontier)]
    local parent = rooms[parentIndex]
    local parentCenter = roomCenter(parent)

    local newRoom = {
      width = rng.randomInt(4, 8),
      height = rng.randomInt(4, 8),
      doors = {},
    }

    local direction = rng.pick({ "left", "right", "up", "down" })
    if direction == "left" then
      newRoom.x = parent.x - newRoom.width - rng.randomInt(2, 5)
      newRoom.y = parentCenter.y - math.floor(newRoom.height / 2)
    elseif direction == "right" then
      newRoom.x = parent.x + parent.width + rng.randomInt(2, 5)
      newRoom.y = parentCenter.y - math.floor(newRoom.height / 2)
    elseif direction == "up" then
      newRoom.x = parentCenter.x - math.floor(newRoom.width / 2)
      newRoom.y = parent.y - newRoom.height - rng.randomInt(2, 5)
    else
      newRoom.x = parentCenter.x - math.floor(newRoom.width / 2)
      newRoom.y = parent.y + parent.height + rng.randomInt(2, 5)
    end

    if newRoom.x < 2 or newRoom.y < 2 or newRoom.x + newRoom.width > width - 1 or newRoom.y + newRoom.height > height - 1 then
      if rng.randomFloat() < 0.35 then
        for i = #frontier, 1, -1 do
          if frontier[i] == parentIndex then
            table.remove(frontier, i)
            break
          end
        end
      end
    else
      local overlap = false
      for _, existing in ipairs(rooms) do
        if roomsOverlap(newRoom, existing, 1) then
          overlap = true
          break
        end
      end

      if not overlap then
        table.insert(rooms, newRoom)
        carveRect(floors, newRoom.x, newRoom.y, newRoom.width, newRoom.height)
        local newCenter = roomCenter(newRoom)
        local thickness = rng.pick({ 1, 2 })
        table.insert(corridors, carveLShapedCorridor(floors, parentCenter, newCenter, thickness))
        table.insert(frontier, #rooms)
      end
    end
  end

  local connectorFromZone1 = edgeConnector({ width = width, height = height }, "left", rng.randomInt(2, height - 1))
  local connectorToZone3 = edgeConnector({ width = width, height = height }, "right", rng.randomInt(2, height - 1))

  addDoor(centralRoom.doors, floors, connectorFromZone1.x, connectorFromZone1.y)
  addDoor(centralRoom.doors, floors, connectorToZone3.x, connectorToZone3.y)
  floors[keyOf(connectorFromZone1.x + 1, connectorFromZone1.y)] = true
  floors[keyOf(connectorToZone3.x - 1, connectorToZone3.y)] = true

  -- Ensure at least 2 dead-end corridors by carving small spur branches.
  local spurCount = 0
  while spurCount < 2 do
    local baseRoom = rooms[rng.randomInt(2, #rooms)]
    local c = roomCenter(baseRoom)
    local endpoint = {
      x = math.max(2, math.min(width - 1, c.x + rng.pick({ -1, 1 }) * rng.randomInt(2, 4))),
      y = math.max(2, math.min(height - 1, c.y + rng.pick({ -1, 1 }) * rng.randomInt(2, 4))),
    }
    table.insert(corridors, carveLShapedCorridor(floors, c, endpoint, rng.pick({ 1, 2 })))
    spurCount = spurCount + 1
  end

  return {
    dimensions = { width = width, height = height },
    rooms = rooms,
    corridors = corridors,
    tiles = toTileListFromFloors(floors),
    floors = floors,
    connector_from_zone1 = connectorFromZone1,
    connector_to_zone3 = connectorToZone3,
  }
end

local function carveBlobRoom(floors, room, rng)
  for y = room.y, room.y + room.height - 1 do
    for x = room.x, room.x + room.width - 1 do
      local nx = (x - (room.x + room.width / 2)) / (room.width / 2)
      local ny = (y - (room.y + room.height / 2)) / (room.height / 2)
      local dist = (nx * nx) + (ny * ny)
      local threshold = 1.0 + (rng.randomFloat() * 0.25)
      if dist <= threshold then
        floors[keyOf(x, y)] = true
      end
    end
  end
end

local function buildZone3(rng)
  local width = rng.randomInt(60, 80)
  local height = rng.randomInt(60, 80)
  local roomTarget = rng.randomInt(3, 6)

  local rooms = {}
  local corridors = {}
  local floors = {}

  for _ = 1, roomTarget do
    local room = {
      x = rng.randomInt(3, width - 20),
      y = rng.randomInt(3, height - 20),
      width = rng.randomInt(12, 20),
      height = rng.randomInt(12, 20),
      doors = {},
    }
    table.insert(rooms, room)
    carveBlobRoom(floors, room, rng)
  end

  table.sort(rooms, function(a, b)
    return (a.width * a.height) > (b.width * b.height)
  end)
  rooms[1].isFinal = true

  for i = 2, #rooms do
    local a = roomCenter(rooms[i - 1])
    local b = roomCenter(rooms[i])
    table.insert(corridors, carveLShapedCorridor(floors, a, b, 2))
  end

  local connectorFromZone2 = edgeConnector({ width = width, height = height }, "left", rng.randomInt(2, height - 1))
  addDoor(rooms[1].doors, floors, connectorFromZone2.x, connectorFromZone2.y)
  floors[keyOf(connectorFromZone2.x + 1, connectorFromZone2.y)] = true

  return {
    dimensions = { width = width, height = height },
    rooms = rooms,
    corridors = corridors,
    tiles = toTileListFromFloors(floors),
    floors = floors,
    connector_from_zone2 = connectorFromZone2,
    final_room = rooms[1],
  }
end

local function validateZone(zone)
  local startRoom = zone.rooms[1]
  if not startRoom then
    return false
  end

  local c = roomCenter(startRoom)
  return floodFillConnected(zone.floors, c.x, c.y)
end

local function validateGlobalPath(level)
  if not validateZone(level.zone1) then
    return false
  end
  if not validateZone(level.zone2) then
    return false
  end
  if not validateZone(level.zone3) then
    return false
  end

  if not level.zone1.connector_to_zone2 then
    return false
  end
  if not level.zone2.connector_to_zone3 then
    return false
  end

  return true
end

-- Generate the full seeded level data for the 3-zone structure.
function LevelGenerator.generateLevel(seed)
  assert(seed ~= nil, "generateLevel(seed): seed obligatoire")

  local maxAttempts = 12
  local baseSeed = tonumber(seed) or 1

  for attempt = 1, maxAttempts do
    local rng = createRng(baseSeed + attempt - 1)

    local zone1 = buildZone1(rng)
    local zone2 = buildZone2(rng)
    local zone3 = buildZone3(rng)

    local level = {
      seed = baseSeed,
      zone1 = {
        dimensions = zone1.dimensions,
        rooms = zone1.rooms,
        corridors = zone1.corridors,
        tiles = zone1.tiles,
        connector_to_zone2 = {
          zone1 = clonePoint(zone1.connector_to_zone2),
          zone2 = clonePoint(zone2.connector_from_zone1),
        },
      },
      zone2 = {
        dimensions = zone2.dimensions,
        rooms = zone2.rooms,
        corridors = zone2.corridors,
        tiles = zone2.tiles,
        connector_from_zone1 = clonePoint(zone2.connector_from_zone1),
        connector_to_zone3 = {
          zone2 = clonePoint(zone2.connector_to_zone3),
          zone3 = clonePoint(zone3.connector_from_zone2),
        },
      },
      zone3 = {
        dimensions = zone3.dimensions,
        rooms = zone3.rooms,
        corridors = zone3.corridors,
        tiles = zone3.tiles,
        connector_from_zone2 = clonePoint(zone3.connector_from_zone2),
      },
    }

    if validateGlobalPath({ zone1 = zone1, zone2 = zone2, zone3 = zone3 }) then
      return level
    end
  end

  error("generateLevel(seed): impossible de générer un niveau valide après plusieurs tentatives")
end

return LevelGenerator
