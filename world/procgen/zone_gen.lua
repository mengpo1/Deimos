-- Zone generation from Hotline-style spatial grammar blocks.
local Tiles = require("world.procgen.tiles")
local Carve = require("world.procgen.carve")

local ZoneGen = {}

local function copyPoint(p)
  return { x = p.x, y = p.y }
end

local function randomRoomY(rng, height, roomH)
  return math.max(2, math.min(height - roomH - 1, rng:randomInt(3, height - roomH - 2)))
end

local function pushBlock(zone, block)
  block.order = #zone.blocks + 1
  zone.blocks[#zone.blocks + 1] = block
end

local function buildZone(id, width, height)
  return {
    id = id,
    width = width,
    height = height,
    tiles = Tiles.create(width, height, Tiles.WALL),
    rooms = {},
    corridors = {},
    blocks = {},
    entryDoor = nil,
    exitDoor = nil,
    pivotCount = 0,
    anomalyCount = 0,
  }
end

local function placeFilter(zone, rng, cursor, params)
  local width = rng:randomInt(params.corridorWidthRange[1], params.corridorWidthRange[2])
  local length = rng:randomInt(params.filterLengthRange[1], params.filterLengthRange[2])
  local toX = cursor.x + length
  local toY = cursor.y

  local carved, err = Carve.corridor(zone, {
    kind = "F",
    fromX = cursor.x,
    fromY = cursor.y,
    toX = toX,
    toY = toY,
    width = width,
  })

  if not carved then
    return nil, err
  end

  -- Optional micro-widening (0..1) at filter exit.
  if rng:randomFloat() < 0.5 then
    local bumpW = width + 1
    local bumpH = width + 1
    local bx = math.max(2, toX - math.floor(bumpW / 2))
    local by = math.max(2, toY - math.floor(bumpH / 2))
    if Carve.rectInside(zone, bx, by, bumpW, bumpH) then
      for yy = by, by + bumpH - 1 do
        for xx = bx, bx + bumpW - 1 do
          Tiles.set(zone.tiles, xx, yy, Tiles.FLOOR)
        end
      end
    end
  end

  local exitDoor = { x = toX, y = toY }
  Carve.door(zone, nil, exitDoor.x, exitDoor.y)

  pushBlock(zone, {
    kind = "F",
    bbox = {
      x = math.min(cursor.x, toX),
      y = toY,
      w = math.abs(toX - cursor.x) + 1,
      h = width,
    },
    entry = copyPoint(cursor),
    exit = copyPoint(exitDoor),
  })

  return exitDoor
end

local function placeArena(zone, rng, cursor, params, large)
  local minSize = large and params.largeArenaSizeRange[1] or params.arenaSizeRange[1]
  local maxSize = large and params.largeArenaSizeRange[2] or params.arenaSizeRange[2]

  local w = rng:randomInt(minSize, maxSize)
  local h = rng:randomInt(minSize, maxSize)

  local candidates = {
    math.max(2, cursor.y - math.floor(h / 2)),
    randomRoomY(rng, zone.height, h),
    math.max(2, cursor.y - h + 2),
    math.max(2, cursor.y - 1),
  }

  local room
  for _, y in ipairs(candidates) do
    room = Carve.room(zone, {
      x = cursor.x + 1,
      y = y,
      w = w,
      h = h,
      type = "A",
    })
    if room then
      break
    end
  end

  if not room then
    return nil, "arena_failed"
  end

  local entry = { x = room.x, y = math.max(room.y + 1, math.min(room.y + room.h - 2, cursor.y)) }
  Carve.door(zone, room, entry.x, entry.y)

  local exitDoor = { x = room.x + room.w - 1, y = room.y + math.floor(room.h / 2) }
  Carve.door(zone, room, exitDoor.x, exitDoor.y)

  local extraEntries = rng:randomInt(0, 2)
  if extraEntries >= 1 then
    Carve.door(zone, room, room.x + math.floor(room.w / 2), room.y)
  end
  if extraEntries >= 2 then
    Carve.door(zone, room, room.x + math.floor(room.w / 2), room.y + room.h - 1)
  end

  pushBlock(zone, {
    kind = large and "A_LARGE" or "A",
    bbox = { x = room.x, y = room.y, w = room.w, h = room.h },
    entry = copyPoint(entry),
    exit = copyPoint(exitDoor),
  })

  return exitDoor
end

local function placePivot(zone, rng, cursor, params)
  local w = rng:randomInt(params.pivotSizeRange[1], params.pivotSizeRange[2])
  local h = rng:randomInt(params.pivotSizeRange[1], params.pivotSizeRange[2])

  local y = math.max(2, cursor.y - math.floor(h / 2))
  local room = Carve.room(zone, {
    x = cursor.x + 1,
    y = y,
    w = w,
    h = h,
    type = "P",
  })

  if not room then
    return nil, "pivot_failed"
  end

  local entry = { x = room.x, y = room.y + math.floor(room.h / 2) }
  Carve.door(zone, room, entry.x, entry.y)

  local exits = {
    { x = room.x + room.w - 1, y = room.y + math.floor(room.h / 2) },
    { x = room.x + math.floor(room.w / 2), y = room.y },
    { x = room.x + math.floor(room.w / 2), y = room.y + room.h - 1 },
    { x = room.x + room.w - 1, y = room.y + math.max(1, math.floor(room.h / 3)) },
  }

  local exitCount = rng:randomInt(3, 4)
  for i = 1, exitCount do
    Carve.door(zone, room, exits[i].x, exits[i].y)
  end

  zone.pivotCount = zone.pivotCount + 1
  pushBlock(zone, {
    kind = "P",
    bbox = { x = room.x, y = room.y, w = room.w, h = room.h },
    entry = copyPoint(entry),
    exits = exits,
  })

  return exits[1]
end

local function applySigma1(zone, rng, cursor, params)
  local width = rng:randomInt(params.corridorWidthRange[1], params.corridorWidthRange[2])
  local sourceA = { x = math.max(2, cursor.x - rng:randomInt(5, 8)), y = math.max(2, cursor.y - rng:randomInt(2, 5)) }
  local sourceB = { x = math.max(2, cursor.x - rng:randomInt(5, 8)), y = math.min(zone.height - 2, cursor.y + rng:randomInt(2, 5)) }
  local target = copyPoint(cursor)

  if not Carve.corridor(zone, { kind = "Σ1", fromX = sourceA.x, fromY = sourceA.y, toX = target.x, toY = target.y, width = width }) then
    return false
  end
  if not Carve.corridor(zone, { kind = "Σ1", fromX = sourceB.x, fromY = sourceB.y, toX = target.x, toY = target.y, width = width }) then
    return false
  end
  Carve.door(zone, nil, target.x, target.y)

  zone.anomalyCount = zone.anomalyCount + 1
  pushBlock(zone, {
    kind = "Σ1",
    bbox = {
      x = math.min(sourceA.x, sourceB.x, target.x),
      y = math.min(sourceA.y, sourceB.y, target.y),
      w = math.max(sourceA.x, sourceB.x, target.x) - math.min(sourceA.x, sourceB.x, target.x) + 1,
      h = math.max(sourceA.y, sourceB.y, target.y) - math.min(sourceA.y, sourceB.y, target.y) + 1,
    },
    targetDoor = target,
  })

  return true
end

local function applySigma2(zone, rng, cursor, params)
  local w = rng:randomInt(params.arenaSizeRange[1], params.arenaSizeRange[2])
  local h = rng:randomInt(params.arenaSizeRange[1], params.arenaSizeRange[2])
  local xA = cursor.x + 2
  local yA = math.max(2, cursor.y - h - 1)
  local xB = xA + rng:randomInt(5, 8)
  local yB = math.min(zone.height - h - 1, cursor.y + 2)

  local roomA = Carve.room(zone, { x = xA, y = yA, w = w, h = h, type = "A", margin = 0 })
  local roomB = Carve.room(zone, { x = xB, y = yB, w = w, h = h, type = "A", margin = 0 })

  if not roomA or not roomB then
    return false
  end

  local aDoor = { x = roomA.x, y = roomA.y + math.floor(roomA.h / 2) }
  local bDoor = { x = roomB.x + roomB.w - 1, y = roomB.y + math.floor(roomB.h / 2) }
  Carve.door(zone, roomA, aDoor.x, aDoor.y)
  Carve.door(zone, roomB, bDoor.x, bDoor.y)

  Carve.corridor(zone, { kind = "Σ2", fromX = cursor.x, fromY = cursor.y, toX = aDoor.x, toY = aDoor.y, width = 1 })
  Carve.corridor(zone, { kind = "Σ2", fromX = cursor.x, fromY = cursor.y, toX = bDoor.x, toY = bDoor.y, width = 1 })

  zone.anomalyCount = zone.anomalyCount + 1
  pushBlock(zone, {
    kind = "Σ2",
    bbox = {
      x = math.min(roomA.x, roomB.x),
      y = math.min(roomA.y, roomB.y),
      w = math.max(roomA.x + roomA.w - 1, roomB.x + roomB.w - 1) - math.min(roomA.x, roomB.x) + 1,
      h = math.max(roomA.y + roomA.h - 1, roomB.y + roomB.h - 1) - math.min(roomA.y, roomB.y) + 1,
    },
  })

  return true
end

local function applySigma3(zone, rng)
  if #zone.corridors == 0 then
    return false
  end

  local picked = zone.corridors[rng:randomInt(1, #zone.corridors)]
  local cells = picked.cells
  if #cells < 6 then
    return false
  end

  local startIndex = rng:randomInt(2, #cells - 3)
  local finishIndex = math.min(#cells, startIndex + rng:randomInt(2, 4))

  local x1 = math.min(cells[startIndex].x, cells[finishIndex].x)
  local y1 = math.min(cells[startIndex].y, cells[finishIndex].y)
  local x2 = math.max(cells[startIndex].x, cells[finishIndex].x)
  local y2 = math.max(cells[startIndex].y, cells[finishIndex].y)

  for y = y1, y2 do
    for x = x1, x2 do
      if x >= 2 and x <= zone.width - 1 and y >= 2 and y <= zone.height - 1 then
        Tiles.set(zone.tiles, x, y, Tiles.WALL)
        if x + 1 <= zone.width - 1 then
          Tiles.set(zone.tiles, x + 1, y, Tiles.WALL)
        end
      end
    end
  end

  zone.anomalyCount = zone.anomalyCount + 1
  pushBlock(zone, {
    kind = "Σ3",
    bbox = { x = x1, y = y1, w = (x2 - x1 + 2), h = (y2 - y1 + 1) },
  })

  return true
end

local function applySigma4(zone, rng, params)
  if #zone.blocks < 3 then
    return false
  end

  local source = zone.blocks[rng:randomInt(1, #zone.blocks - 1)]
  local dest = zone.blocks[rng:randomInt(2, #zone.blocks)]
  if not source.exit or not dest.entry then
    return false
  end

  local longLength = rng:randomInt(8, 14)
  local width = rng:randomInt(params.corridorWidthRange[1], params.corridorWidthRange[2])

  local midX = math.min(zone.width - 2, source.exit.x + longLength)
  local midY = math.max(2, math.min(zone.height - 2, math.min(source.exit.y, dest.entry.y) - rng:randomInt(3, 7)))

  if not Carve.corridor(zone, { kind = "Σ4", fromX = source.exit.x, fromY = source.exit.y, toX = midX, toY = midY, width = width }) then
    return false
  end

  if not Carve.corridor(zone, { kind = "Σ4", fromX = midX, fromY = midY, toX = dest.entry.x, toY = dest.entry.y, width = width }) then
    return false
  end

  zone.anomalyCount = zone.anomalyCount + 1
  pushBlock(zone, {
    kind = "Σ4",
    bbox = {
      x = math.min(source.exit.x, dest.entry.x, midX),
      y = math.min(source.exit.y, dest.entry.y, midY),
      w = math.max(source.exit.x, dest.entry.x, midX) - math.min(source.exit.x, dest.entry.x, midX) + 1,
      h = math.max(source.exit.y, dest.entry.y, midY) - math.min(source.exit.y, dest.entry.y, midY) + 1,
    },
  })

  return true
end

local function applySigma5(zone, rng, cursor, params)
  local pivotExit = placePivot(zone, rng, cursor, params)
  if not pivotExit then
    return false
  end

  local backX = math.max(2, cursor.x - rng:randomInt(6, 10))
  if not Carve.corridor(zone, { kind = "Σ5", fromX = pivotExit.x, fromY = pivotExit.y, toX = backX, toY = cursor.y, width = 1 }) then
    return false
  end

  zone.anomalyCount = zone.anomalyCount + 1
  pushBlock(zone, {
    kind = "Σ5",
    bbox = {
      x = math.min(backX, cursor.x, pivotExit.x),
      y = math.min(cursor.y, pivotExit.y),
      w = math.max(backX, cursor.x, pivotExit.x) - math.min(backX, cursor.x, pivotExit.x) + 1,
      h = math.max(cursor.y, pivotExit.y) - math.min(cursor.y, pivotExit.y) + 1,
    },
  })

  return true
end

local function applyAnomaly(zone, rng, cursor, params, allowed)
  local pool = {}
  for _, item in ipairs(allowed) do
    pool[#pool + 1] = item
  end

  while #pool > 0 do
    local idx = rng:randomInt(1, #pool)
    local token = table.remove(pool, idx)
    local ok = false

    if token == "Σ1" then
      ok = applySigma1(zone, rng, cursor, params)
    elseif token == "Σ2" then
      ok = applySigma2(zone, rng, cursor, params)
    elseif token == "Σ3" then
      ok = applySigma3(zone, rng)
    elseif token == "Σ4" then
      ok = applySigma4(zone, rng, params)
    elseif token == "Σ5" then
      ok = applySigma5(zone, rng, cursor, params)
    end

    if ok then
      return true
    end
  end

  return false
end

function ZoneGen.generate(config)
  local zone = buildZone(config.id, config.width, config.height)
  local rng = config.rng

  local cursor = { x = 3, y = math.floor(zone.height / 2) }
  zone.entryDoor = copyPoint(cursor)
  Carve.door(zone, nil, cursor.x, cursor.y)

  for _, symbol in ipairs(config.grammar) do
    if symbol == "F" then
      local nextCursor, err = placeFilter(zone, rng, cursor, config)
      if not nextCursor then
        return nil, err
      end
      cursor = nextCursor
    elseif symbol == "A" then
      local nextCursor, err = placeArena(zone, rng, cursor, config, false)
      if not nextCursor then
        return nil, err
      end
      cursor = nextCursor
    elseif symbol == "A_LARGE" then
      local nextCursor, err = placeArena(zone, rng, cursor, config, true)
      if not nextCursor then
        return nil, err
      end
      cursor = nextCursor
    elseif symbol == "P" then
      local nextCursor, err = placePivot(zone, rng, cursor, config)
      if not nextCursor then
        return nil, err
      end
      cursor = nextCursor
    elseif symbol == "Σ" then
      if not applyAnomaly(zone, rng, cursor, config, config.allowedAnomalies) then
        return nil, "anomaly_failed"
      end
    else
      return nil, "unknown_symbol"
    end
  end

  zone.exitDoor = copyPoint(cursor)
  Carve.door(zone, nil, zone.exitDoor.x, zone.exitDoor.y)
  zone._doorSet = nil

  return zone
end

return ZoneGen
