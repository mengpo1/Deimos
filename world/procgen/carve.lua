-- Orthogonal carving helpers for rooms/corridors/doors.
local Tiles = require("world.procgen.tiles")

local Carve = {}

local function keyOf(x, y)
  return string.format("%d,%d", x, y)
end

function Carve.isRectInside(zone, x, y, w, h)
  return x >= 2 and y >= 2 and x + w - 1 <= zone.width - 1 and y + h - 1 <= zone.height - 1
end

function Carve.roomOverlaps(zone, x, y, w, h, margin)
  local m = margin or 1
  for _, room in ipairs(zone.rooms) do
    if not (
      x + w + m <= room.x or
      room.x + room.w + m <= x or
      y + h + m <= room.y or
      room.y + room.h + m <= y
    ) then
      return true
    end
  end
  return false
end

function Carve.room(zone, x, y, w, h, roomType)
  if not Carve.isRectInside(zone, x, y, w, h) then
    return nil, "room_oob"
  end

  if Carve.roomOverlaps(zone, x, y, w, h, 1) then
    return nil, "room_overlap"
  end

  local room = { x = x, y = y, w = w, h = h, doors = {}, type = roomType or "A" }
  for yy = y, y + h - 1 do
    for xx = x, x + w - 1 do
      Tiles.set(zone.tiles, xx, yy, Tiles.FLOOR)
    end
  end

  table.insert(zone.rooms, room)
  return room
end

function Carve.door(zone, room, x, y)
  if not Tiles.inBounds(zone.tiles, x, y) then
    return false
  end
  Tiles.set(zone.tiles, x, y, Tiles.DOOR)
  if room then
    table.insert(room.doors, { x = x, y = y })
  end
  zone.doorSet[keyOf(x, y)] = true
  return true
end

function Carve.corridor(zone, fromX, fromY, toX, toY, width, tag)
  local corridor = {
    from = { x = fromX, y = fromY },
    to = { x = toX, y = toY },
    width = width,
    tag = tag or "F",
    orthogonal = true,
    cells = {},
  }

  local function carveLine(x1, y1, x2, y2)
    local dx = (x2 > x1) and 1 or (x2 < x1 and -1 or 0)
    local dy = (y2 > y1) and 1 or (y2 < y1 and -1 or 0)
    local cx, cy = x1, y1
    while true do
      for wy = 0, width - 1 do
        for wx = 0, width - 1 do
          local tx = cx + (dx == 0 and wx or 0)
          local ty = cy + (dy == 0 and wy or 0)
          if not Tiles.set(zone.tiles, tx, ty, Tiles.FLOOR) then
            return false
          end
          table.insert(corridor.cells, { x = tx, y = ty })
        end
      end
      if cx == x2 and cy == y2 then
        break
      end
      cx, cy = cx + dx, cy + dy
    end
    return true
  end

  if fromX ~= toX and fromY ~= toY then
    local okA = carveLine(fromX, fromY, toX, fromY)
    local okB = okA and carveLine(toX, fromY, toX, toY)
    if not okB then
      return nil, "corridor_oob"
    end
  else
    local ok = carveLine(fromX, fromY, toX, toY)
    if not ok then
      return nil, "corridor_oob"
    end
  end

  table.insert(zone.corridors, corridor)
  return corridor
end

return Carve
