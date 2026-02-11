-- Simple class helper to enable object-style tables with optional inheritance.
-- Returns a table with :new(...) and a metatable chain to the base class.
local function Class(base)
  local cls = {}
  cls.__index = cls

  -- Create a new instance, calling init(...) when provided.
  function cls:new(...)
    local instance = setmetatable({}, cls)
    if instance.init then
      instance:init(...)
    end
    return instance
  end

  -- Inherit from base class when provided.
  if base then
    setmetatable(cls, { __index = base })
    cls.super = base
  end

  return cls
end

return Class
