-- Input binding helper for turn-based movement and actions.
local Class = require("core.class")

local Input = Class()

-- Initialize with an optional bindings table (action -> list of keys).
function Input:init(bindings)
  self.bindings = bindings or {}
  self.pressed = {}
end

-- Assign a new list of keys for a specific action.
function Input:bind(action, keys)
  self.bindings[action] = keys
end

-- Record a key as pressed during the current turn.
function Input:registerPress(key)
  self.pressed[key] = true
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

-- Clear the pressed cache at the end of the turn.
function Input:clearPressed()
  self.pressed = {}
end

return Input
