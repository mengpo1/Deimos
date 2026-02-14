-- Zone generator based on Hotline-style spatial grammar blocks.
local Tiles = require("world.procgen.tiles")
local Carve = require("world.procgen.carve")

local ZoneGen = {}

local function copyPoint(p)
  return { x = p.x, y = p.y }
end

local function buildEmptyZone(id, width, height)
  return {
    id = id,
    width = width,
    height = height,
    tiles = Tiles.createGrid(width, height, Tiles.WALL),
    rooms = {},
    corridors = {},
    entryDoor = nil,
    exitDoor = nil,
    blocks = {},
    doorSet = {},
    anomalyCount = 0,
    pivotCount = 0,
  }
end

local function placeFilter(zone, rng, cursor, params)
  local width = rng:randomInt(params.filterWidthRange[1], params.filterWidthRange[2])
  local length = rng:randomInt(params.filterLengthRange[1], params.filterLengthRange[2])
  local toX = cursor.x + length
  local toY = cursor.y

  local corridor, err = Carve.corridor(zone, cursor.x, cursor.y, toX, toY, width, "F")
  if not corridor then
    return nil, err
  end

  if rng:randomFloat() < 0.5 then
    local bumpW = width + 1
    local bumpH = width + 1
    local bx = math.max(2, toX - math.floor(bumpW / 2))
    local by = math.max(2, toY - math.floor(bumpH / 2))
    if Carve.isRectInside(zone, bx, by, bumpW, bumpH) then
      for yy = by, by + bumpH - 1 do
        for xx = bx, bx + bumpW - 1 do
          Tiles.set(zone.tiles, xx, yy, Tiles.FLOOR)
        end
      end
    end
  end

  local outDoor = { x = toX, y = toY }
  Carve.door(zone, nil, outDoor.x, outDoor.y)
  table.insert(zone.blocks, {
    kind = "F",
    bbox = { x = math.min(cursor.x, toX), y = cursor.y, w = math.abs(toX - cursor.x) + width, h = width },
    entry = copyPoint(cursor),
    exit = copyPoint(outDoor),
  })

  return outDoor
end

local function placeArena(zone, rng, cursor, params, isLarge)
  local minSize = isLarge and params.largeArenaSizeRange[1] or params.arenaSizeRange[1]
  local maxSize = isLarge and params.largeArenaSizeRange[2] or params.arenaSizeRange[2]
  local w = rng:randomInt(minSize, maxSize)
  local h = rng:randomInt(minSize, maxSize)
  local x = cursor.x + 1
  local y = cursor.y - math.floor(h / 2)

  local room, err = Carve.room(zone, x, y, w, h, "A")
  if not room then
    return nil, err
  end

  local entry = { x = x, y = math.max(y + 1, math.min(y + h - 2, cursor.y)) }
  Carve.door(zone, room, entry.x, entry.y)

  local exits = rng:randomInt(1, 3)
  local mainExit = { x = x + w - 1, y = y + math.floor(h / 2) }
  Carve.door(zone, room, mainExit.x, mainExit.y)

  if exits >= 2 then
    Carve.door(zone, room, x + math.floor(w / 2), y)
  end
  if exits >= 3 then
    Carve.door(zone, room, x + math.floor(w / 2), y + h - 1)
  end

  table.insert(zone.blocks, {
    kind = "A",
    bbox = { x = x, y = y, w = w, h = h },
    entry = entry,
    exit = copyPoint(mainExit),
    large = isLarge or false,
  })

  return mainExit
end

local function placePivot(zone, rng, cursor, params)
  local w = rng:randomInt(params.pivotSizeRange[1], params.pivotSizeRange[2])
  local h = rng:randomInt(params.pivotSizeRange[1], params.pivotSizeRange[2])
  local x = cursor.x + 1
  local y = cursor.y - math.floor(h / 2)

  local room, err = Carve.room(zone, x, y, w, h, "P")
  if not room then
    return nil, err
  end

  local entry = { x = x, y = y + math.floor(h / 2) }
  local exits = {
    { x = x + w - 1, y = y + math.floor(h / 2) },
    { x = x + math.floor(w / 2), y = y },
    { x = x + math.floor(w / 2), y = y + h - 1 },
    { x = x + w - 1, y = y + math.max(1, math.floor(h / 3)) },
  }

  Carve.door(zone, room, entry.x, entry.y)
  local exitCount = rng:randomInt(3, 4)
  for i = 1, exitCount do
    Carve.door(zone, room, exits[i].x, exits[i].y)
  end

  zone.pivotCount = zone.pivotCount + 1
  table.insert(zone.blocks, {
    kind = "P",
    bbox = { x = x, y = y, w = w, h = h },
    entry = entry,
    exits = exits,
  })

  return exits[1]
end

local function applySigma1(zone, rng, cursor, params)
  local target = copyPoint(cursor)
  local splitY = math.max(2, math.min(zone.height - 2, cursor.y + rng:randomChoice({ -4, -3, 3, 4 })))
  local splitX = math.max(2, cursor.x - rng:randomInt(6, 10))
  local width = rng:randomInt(params.filterWidthRange[1], params.filterWidthRange[2])
  local c1 = Carve.corridor(zone, splitX, splitY, target.x, target.y, width, "Sigma1")
  if not c1 then
    return false
  end
  Carve.door(zone, nil, target.x, target.y)

  table.insert(zone.blocks, {
    kind = "Σ1",
    bbox = { x = math.min(splitX, target.x), y = math.min(splitY, target.y), w = math.abs(target.x - splitX) + 1, h = math.abs(target.y - splitY) + 1 },
    targetDoor = target,
  })
  zone.anomalyCount = zone.anomalyCount + 1
  return true
end

local function applySigma4(zone, rng, params)
  if #zone.blocks < 3 then
    return false
  end

  local source = zone.blocks[rng:randomInt(1, math.max(1, #zone.blocks - 1))]
  local dest = zone.blocks[rng:randomInt(2, #zone.blocks)]
  if not source.exit or not dest.entry then
    return false
  end

  local width = rng:randomInt(params.filterWidthRange[1], params.filterWidthRange[2])
  local detourY = math.max(2, math.min(zone.height - 2, math.min(source.exit.y, dest.entry.y) - rng:randomInt(4, 10)))

  local c1 = Carve.corridor(zone, source.exit.x, source.exit.y, source.exit.x + 6, detourY, width, "Sigma4")
  if not c1 then
    return false
  end
  local c2 = Carve.corridor(zone, source.exit.x + 6, detourY, dest.entry.x, dest.entry.y, width, "Sigma4")
  if not c2 then
    return false
  end

  table.insert(zone.blocks, {
    kind = "Σ4",
    bbox = {
      x = math.min(source.exit.x, dest.entry.x),
      y = math.min(detourY, source.exit.y, dest.entry.y),
      w = math.abs(dest.entry.x - source.exit.x) + 7,
      h = math.abs(math.max(source.exit.y, dest.entry.y) - detourY) + 1,
    },
  })

  zone.anomalyCount = zone.anomalyCount + 1
  return true
end

local function applySigma2(zone, rng, cursor, params)
  local w = rng:randomInt(params.arenaSizeRange[1], params.arenaSizeRange[2])
  local h = rng:randomInt(params.arenaSizeRange[1], params.arenaSizeRange[2])
  local offset = rng:randomInt(5, 8)

  local roomA = Carve.room(zone, cursor.x + 2, cursor.y - h - 1, w, h, "Sigma2A")
  local roomB = Carve.room(zone, cursor.x + 2 + offset, cursor.y + 2, w, h, "Sigma2B")
  if not roomA or not roomB then
    return false
  end

  Carve.door(zone, roomA, roomA.x, roomA.y + math.floor(h / 2))
  Carve.door(zone, roomB, roomB.x + roomB.w - 1, roomB.y + math.floor(h / 2))

  Carve.corridor(zone, cursor.x, cursor.y, roomA.x, roomA.y + math.floor(h / 2), 1, "Sigma2")
  Carve.corridor(zone, cursor.x, cursor.y, roomB.x, roomB.y + math.floor(h / 2), 1, "Sigma2")

  table.insert(zone.blocks, {
    kind = "Σ2",
    bbox = {
      x = math.min(roomA.x, roomB.x),
      y = math.min(roomA.y, roomB.y),
      w = math.max(roomA.x + roomA.w, roomB.x + roomB.w) - math.min(roomA.x, roomB.x),
      h = math.max(roomA.y + roomA.h, roomB.y + roomB.h) - math.min(roomA.y, roomB.y),
    },
  })

  zone.anomalyCount = zone.anomalyCount + 1
  return true
end

local function applySigma5(zone, rng, cursor, params)
  local pivotExit, err = placePivot(zone, rng, cursor, params)
  if not pivotExit then
    return false, err
  end

  local backX = math.max(2, cursor.x - rng:randomInt(6, 10))
  local ok = Carve.corridor(zone, pivotExit.x, pivotExit.y, backX, cursor.y, 1, "Sigma5")
  if not ok then
    return false
  end

  table.insert(zone.blocks, {
    kind = "Σ5",
    bbox = { x = math.min(backX, cursor.x), y = math.min(cursor.y, pivotExit.y), w = math.abs(cursor.x - backX) + 1, h = math.abs(cursor.y - pivotExit.y) + 1 },
  })

  zone.anomalyCount = zone.anomalyCount + 1
  return true
end

local function applyAnomaly(zone, rng, cursor, params, allowed)
  local picks = {}
  for _, name in ipairs(allowed) do
    table.insert(picks, name)
  end

  while #picks > 0 do
    local index = rng:randomInt(1, #picks)
    local picked = table.remove(picks, index)
    local ok = false

    if picked == "Σ1" then
      ok = applySigma1(zone, rng, cursor, params)
    elseif picked == "Σ4" then
      ok = applySigma4(zone, rng, params)
    elseif picked == "Σ2" then
      ok = applySigma2(zone, rng, cursor, params)
    elseif picked == "Σ5" then
      ok = applySigma5(zone, rng, cursor, params)
    end

    if ok then
      return true
    end
  end

  return false
end

function ZoneGen.generateZone(zoneId, seed, config)
  local zone = buildEmptyZone(zoneId, config.width, config.height)
  local rng = config.rng

  local cursor = { x = 3, y = math.floor(zone.height / 2) }
  zone.entryDoor = copyPoint(cursor)
  Carve.door(zone, nil, cursor.x, cursor.y)

  for index, token in ipairs(config.grammar) do
    if token == "F" then
      local out, err = placeFilter(zone, rng, cursor, config)
      if not out then
        return nil, err
      end
      cursor = out
    elseif token == "A" then
      local out, err = placeArena(zone, rng, cursor, config, false)
      if not out then
        return nil, err
      end
      cursor = out
    elseif token == "A_LARGE" then
      local out, err = placeArena(zone, rng, cursor, config, true)
      if not out then
        return nil, err
      end
      cursor = out
    elseif token == "P" then
      local out, err = placePivot(zone, rng, cursor, config)
      if not out then
        return nil, err
      end
      cursor = out
    elseif token == "Σ" then
      local ok = applyAnomaly(zone, rng, cursor, config, config.allowedAnomalies)
      if not ok then
        return nil, "anomaly_failed"
      end
    end

    zone.blocks[#zone.blocks].order = index
  end

  zone.exitDoor = copyPoint(cursor)
  Carve.door(zone, nil, zone.exitDoor.x, zone.exitDoor.y)
  zone.doorSet = nil

  return zone
end

return ZoneGen
