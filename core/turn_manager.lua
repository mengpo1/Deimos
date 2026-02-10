-- Turn manager to sequence actor turns in a simple round-robin loop.
local Class = require("core.class")

local TurnManager = Class()

-- Initialize with an optional list of actors.
function TurnManager:init(actors)
  self.actors = actors or {}
  self.activeIndex = 1
end

-- Add a new actor to the turn order.
function TurnManager:addActor(actor)
  table.insert(self.actors, actor)
end

-- Return the actor whose turn is active.
function TurnManager:getActiveActor()
  return self.actors[self.activeIndex]
end

-- Advance to the next actor in the list.
function TurnManager:advance()
  if #self.actors == 0 then
    return
  end
  self.activeIndex = self.activeIndex + 1
  if self.activeIndex > #self.actors then
    self.activeIndex = 1
  end
end

-- Let the active actor attempt a turn, then advance on success.
function TurnManager:update(input, room)
  local actor = self:getActiveActor()
  if not actor then
    return
  end

  if actor:takeTurn(input, room) then
    self:advance()
  end
end

return TurnManager
