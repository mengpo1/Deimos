-- Input binding helper for movement and actions.
local Class = require("core.class")

local Input = Class()

-- Initialize with an optional bindings table (action -> list of keys).
function Input:init(bindings)
  self.bindings = bindings or {}
  self.pressed = {}
  self.held = {}
end

-- Assign a new list of keys for a specific action.
function Input:bind(action, keys)
  self.bindings[action] = keys
end

-- Record a key as pressed and held.
function Input:registerPress(key)
  self.pressed[key] = true
  self.held[key] = true
end

-- Record a key release.
function Input:registerRelease(key)
  self.held[key] = nil
end

-- Check if any key mapped to the action was pressed this frame.
function Input:wasPressed(action)
  local keys = self.bindings[action] or {}
  for _, key in ipairs(keys) do
    if self.pressed[key] then
      return true
    end
  end
  return false
end

-- Check if any key mapped to the action is currently held.
function Input:isDown(action)
  local keys = self.bindings[action] or {}
  for _, key in ipairs(keys) do
    if self.held[key] then
      return true
    end
  end
  return false
end

-- Clear the one-frame pressed cache.
function Input:clearPressed()
  self.pressed = {}
end

return Input
