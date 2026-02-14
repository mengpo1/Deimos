-- Save/load helper with 5 fixed slots.
local SaveSystem = {}

local SLOT_COUNT = 5

local function serialize(value)
  local valueType = type(value)

  if valueType == "number" or valueType == "boolean" then
    return tostring(value)
  end

  if valueType == "string" then
    return string.format("%q", value)
  end

  if valueType == "table" then
    local parts = { "{" }
    for key, tableValue in pairs(value) do
      local serializedKey
      if type(key) == "string" and key:match("^[%a_][%w_]*$") then
        serializedKey = key
      else
        serializedKey = "[" .. serialize(key) .. "]"
      end

      table.insert(parts, serializedKey .. "=" .. serialize(tableValue) .. ",")
    end
    table.insert(parts, "}")
    return table.concat(parts)
  end

  return "nil"
end

local function slotFilename(slot)
  return string.format("save_slot_%d.lua", slot)
end

function SaveSystem.getSlotCount()
  return SLOT_COUNT
end

function SaveSystem.getSlotInfo(slot)
  local filename = slotFilename(slot)
  local info = love.filesystem.getInfo(filename)
  return {
    slot = slot,
    filename = filename,
    exists = info ~= nil,
    size = info and info.size or 0,
    modtime = info and info.modtime or nil,
  }
end

function SaveSystem.save(slot, payload)
  local filename = slotFilename(slot)
  local content = "return " .. serialize(payload)
  return love.filesystem.write(filename, content)
end

function SaveSystem.load(slot)
  local filename = slotFilename(slot)
  local chunk, err = love.filesystem.load(filename)
  if not chunk then
    return nil, err
  end

  local ok, data = pcall(chunk)
  if not ok then
    return nil, data
  end

  return data, nil
end

return SaveSystem
