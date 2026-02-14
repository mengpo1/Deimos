-- Deprecated: random Zone1 generation removed for single-room phase.
local Zone1Generator = {}

function Zone1Generator.generate()
  error("Zone1 generation is disabled in single-room mode")
end

return Zone1Generator
