-- Actor base class: entities that can take turns.
local Class = require("core.class")
local Entity = require("core.entity")

local Actor = Class(Entity)

-- Initialize the actor with entity defaults.
function Actor:init(options)
  Actor.super.init(self, options or {})
end

-- Override in subclasses to perform an action; return true when action consumed.
function Actor:takeTurn()
  return false
end

return Actor
