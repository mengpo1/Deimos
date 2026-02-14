-- Orthogonal carving helpers for room/corridor/door blocks.
local Tiles = require("world.procgen.tiles")

local Carve = {}

local function keyOf(x, y)
  return string.format("%d,%d", x, y)
end

function Carve.rectInside(zone, x, y, w, h)
  return x >= 2 and y >= 2 and (x + w - 1) <= zone.width - 1 and (y + h - 1) <= zone.height - 1
end

function Carve.roomsOverlap(zone, x, y, w, h, margin)
  local m = margin or 1
  for _, room in ipairs(zone.rooms) do
    local noOverlap = (
      x + w + m <= room.x or
      room.x + room.w + m <= x or
      y + h + m <= room.y or
      room.y + room.h + m <= y
    )
    if not noOverlap then
      return true
    end
  end
  return false
end

function Carve.room(zone, options)
  local x, y, w, h = options.x, options.y, options.w, options.h
  if not Carve.rectInside(zone, x, y, w, h) then
    return nil, "room_oob"
  end

  local allowOverlap = options.allowOverlap == true
  if (not allowOverlap) and Carve.roomsOverlap(zone, x, y, w, h, options.margin or 1) then
    return nil, "room_overlap"
  end

  local room = {
    x = x,
    y = y,
    w = w,
    h = h,
    type = options.type or "A",
    doors = {},
  }

  for yy = y, y + h - 1 do
    for xx = x, x + w - 1 do
      Tiles.set(zone.tiles, xx, yy, Tiles.FLOOR)
    end
  end

  table.insert(zone.rooms, room)
  return room
end

function Carve.door(zone, room, x, y)
  if not Tiles.set(zone.tiles, x, y, Tiles.DOOR) then
    return false
  end

  zone._doorSet = zone._doorSet or {}
  zone._doorSet[keyOf(x, y)] = true
  if room then
    table.insert(room.doors, { x = x, y = y })
  end

  return true
end

local function carveLine(zone, corridor, x1, y1, x2, y2, width)
  local dx = (x2 > x1) and 1 or (x2 < x1 and -1 or 0)
  local dy = (y2 > y1) and 1 or (y2 < y1 and -1 or 0)
  local cx, cy = x1, y1

  while true do
    for offset = 0, width - 1 do
      local tx = cx + (dy ~= 0 and offset or 0)
      local ty = cy + (dx ~= 0 and offset or 0)
      if not Tiles.set(zone.tiles, tx, ty, Tiles.FLOOR) then
        return false
      end
      corridor.cells[#corridor.cells + 1] = { x = tx, y = ty }
    end

    if cx == x2 and cy == y2 then
      break
    end

    cx = cx + dx
    cy = cy + dy
  end

  return true
end

function Carve.corridor(zone, options)
  local fromX, fromY = options.fromX, options.fromY
  local toX, toY = options.toX, options.toY
  local width = options.width

  local corridor = {
    kind = options.kind or "F",
    from = { x = fromX, y = fromY },
    to = { x = toX, y = toY },
    width = width,
    orthogonal = true,
    cells = {},
  }

  local ok
  if fromX ~= toX and fromY ~= toY then
    local pivotX, pivotY = toX, fromY
    ok = carveLine(zone, corridor, fromX, fromY, pivotX, pivotY, width)
    if ok then
      ok = carveLine(zone, corridor, pivotX, pivotY, toX, toY, width)
    end
    corridor.pivot = { x = pivotX, y = pivotY }
  else
    ok = carveLine(zone, corridor, fromX, fromY, toX, toY, width)
  end

  if not ok then
    return nil, "corridor_oob"
  end

  zone.corridors[#zone.corridors + 1] = corridor
  return corridor
end

return Carve
