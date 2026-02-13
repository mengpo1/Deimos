-- Zone 1 generator: stable euclidean orthogonal geometry.
-- Exposes Zone1Generator.generate(seed) -> zone1Data.

local Zone1Generator = {}

local function createRng(seed)
  local state = (tonumber(seed) or 1) % 2147483647
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

  return {
    randomFloat = randomFloat,
    randomInt = randomInt,
  }
end

local function keyOf(x, y)
  return string.format("%d,%d", x, y)
end

local function roomCenter(room)
  return {
    x = room.x + math.floor(room.width / 2),
    y = room.y + math.floor(room.height / 2),
  }
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

local function carveRect(floors, x, y, width, height)
  for yy = y, y + height - 1 do
    for xx = x, x + width - 1 do
      floors[keyOf(xx, yy)] = true
    end
  end
end

local function carveHorizontal(floors, fromX, toX, y, width)
  local minX, maxX = math.min(fromX, toX), math.max(fromX, toX)
  local half = math.floor(width / 2)
  for xx = minX, maxX do
    for dy = -half, width - half - 1 do
      floors[keyOf(xx, y + dy)] = true
    end
  end
end

local function carveVertical(floors, fromY, toY, x, width)
  local minY, maxY = math.min(fromY, toY), math.max(fromY, toY)
  local half = math.floor(width / 2)
  for yy = minY, maxY do
    for dx = -half, width - half - 1 do
      floors[keyOf(x + dx, yy)] = true
    end
  end
end

local function carveL(floors, a, b, corridorWidth)
  local pivot = { x = b.x, y = a.y }
  carveHorizontal(floors, a.x, pivot.x, a.y, corridorWidth)
  carveVertical(floors, pivot.y, b.y, pivot.x, corridorWidth)

  return {
    from = { x = a.x, y = a.y },
    pivot = pivot,
    to = { x = b.x, y = b.y },
    width = corridorWidth,
    orthogonal = true,
  }
end

local function addDoor(room, floors, x, y)
  floors[keyOf(x, y)] = true
  room.doors = room.doors or {}
  table.insert(room.doors, { x = x, y = y, type = "door" })
end

local function buildTiles(floors, doors)
  local tiles = {}
  local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge

  for key in pairs(floors) do
    local x, y = key:match("(-?%d+),(-?%d+)")
    x, y = tonumber(x), tonumber(y)
    minX, minY = math.min(minX, x), math.min(minY, y)
    maxX, maxY = math.max(maxX, x), math.max(maxY, y)
  end

  for y = minY - 1, maxY + 1 do
    for x = minX - 1, maxX + 1 do
      local k = keyOf(x, y)
      if floors[k] then
        table.insert(tiles, { x = x, y = y, type = "floor" })
      else
        local near = floors[keyOf(x + 1, y)] or floors[keyOf(x - 1, y)] or floors[keyOf(x, y + 1)] or floors[keyOf(x, y - 1)]
        if near then
          table.insert(tiles, { x = x, y = y, type = "wall" })
        end
      end
    end
  end

  for _, door in ipairs(doors) do
    table.insert(tiles, { x = door.x, y = door.y, type = "door" })
  end

  return tiles
end

local function floodFillConnected(floors, sx, sy)
  if not floors[keyOf(sx, sy)] then
    return false
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

  return floorCount == visitedCount
end

local function generateOnce(seed)
  local rng = createRng(seed)

  local gridSize = rng.randomInt(50, 70)
  local roomCount = rng.randomInt(8, 15)
  local corridorWidth = rng.randomInt(2, 4)
  local minRoomSize, maxRoomSize = 6, 12

  local rooms = {}
  local floors = {}

  local tries = 0
  local maxTries = roomCount * 300

  while #rooms < roomCount and tries < maxTries do
    tries = tries + 1
    local room = {
      x = rng.randomInt(2, gridSize - maxRoomSize - 1),
      y = rng.randomInt(2, gridSize - maxRoomSize - 1),
      width = rng.randomInt(minRoomSize, maxRoomSize),
      height = rng.randomInt(minRoomSize, maxRoomSize),
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

  if #rooms == 0 then
    return {
      dimensions = { width = gridSize, height = gridSize },
      rooms = {},
      corridors = {},
      tiles = {},
      connector_to_zone2 = nil,
      entry = nil,
      parameters = {
        gridSize = gridSize,
        roomCount = roomCount,
        minRoomSize = minRoomSize,
        maxRoomSize = maxRoomSize,
        corridorWidth = corridorWidth,
        allowDiagonal = false,
        allowIrregularRooms = false,
        connectivity = 0.0,
        loops = "minimal",
      },
      _floors = floors,
    }
  end

  table.sort(rooms, function(a, b)
    local ca, cb = roomCenter(a), roomCenter(b)
    if ca.x == cb.x then
      return ca.y < cb.y
    end
    return ca.x < cb.x
  end)

  local corridors = {}
  for i = 2, #rooms do
    local a = roomCenter(rooms[i - 1])
    local b = roomCenter(rooms[i])
    table.insert(corridors, carveL(floors, a, b, corridorWidth))
  end

  -- Minimal loops: optional one extra L corridor.
  if #rooms >= 4 and rng.randomFloat() < 0.35 then
    local i1 = rng.randomInt(1, #rooms - 2)
    local i2 = rng.randomInt(i1 + 2, #rooms)
    local a = roomCenter(rooms[i1])
    local b = roomCenter(rooms[i2])
    table.insert(corridors, carveL(floors, a, b, corridorWidth))
  end

  local firstCenter = roomCenter(rooms[1])
  local lastCenter = roomCenter(rooms[#rooms])

  local entry = { x = 1, y = firstCenter.y, edge = "left" }
  local connector = { x = gridSize, y = lastCenter.y, edge = "right" }

  addDoor(rooms[1], floors, entry.x, entry.y)
  addDoor(rooms[#rooms], floors, connector.x, connector.y)

  -- Force rational border access corridors from entry/exit to nearest room center.
  carveHorizontal(floors, entry.x + 1, firstCenter.x, firstCenter.y, corridorWidth)
  carveHorizontal(floors, lastCenter.x, connector.x - 1, lastCenter.y, corridorWidth)

  local doors = {
    { x = entry.x, y = entry.y },
    { x = connector.x, y = connector.y },
  }

  return {
    dimensions = { width = gridSize, height = gridSize },
    rooms = rooms,
    corridors = corridors,
    tiles = buildTiles(floors, doors),
    connector_to_zone2 = connector,
    entry = entry,
    parameters = {
      gridSize = gridSize,
      roomCount = roomCount,
      minRoomSize = minRoomSize,
      maxRoomSize = maxRoomSize,
      corridorWidth = corridorWidth,
      allowDiagonal = false,
      allowIrregularRooms = false,
      connectivity = 1.0,
      loops = "minimal",
    },
    _floors = floors,
  }
end

local function validate(zone)
  if not zone then
    return false
  end

  local params = zone.parameters
  if params.allowDiagonal or params.allowIrregularRooms then
    return false
  end

  if #zone.rooms < 8 or #zone.rooms > 15 then
    return false
  end

  for _, room in ipairs(zone.rooms) do
    if room.width < 6 or room.width > 12 or room.height < 6 or room.height > 12 then
      return false
    end
  end

  if not zone.entry or not zone.connector_to_zone2 then
    return false
  end

  for _, corridor in ipairs(zone.corridors) do
    if not corridor.orthogonal then
      return false
    end
    if corridor.width < 2 or corridor.width > 4 then
      return false
    end
  end

  local start = roomCenter(zone.rooms[1])
  if not floodFillConnected(zone._floors, start.x, start.y) then
    return false
  end

  return true
end

-- Generate Zone 1 with retry strategy until constraints are satisfied.
function Zone1Generator.generate(seed)
  assert(seed ~= nil, "Zone1Generator.generate(seed): seed obligatoire")

  local baseSeed = tonumber(seed) or 1
  local attempts = 20

  for i = 0, attempts - 1 do
    local zone = generateOnce(baseSeed + i)
    if validate(zone) then
      zone._floors = nil
      return zone
    end
  end

  error("Zone1Generator.generate(seed): impossible de générer une Zone 1 valide")
end

return Zone1Generator
