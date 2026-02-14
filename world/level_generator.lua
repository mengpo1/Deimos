-- Deprecated: random level generation removed for single-room phase.
local LevelGenerator = {}

function LevelGenerator.generateLevel()
  error("Level generation is disabled in single-room mode")
end

function LevelGenerator.quickTest()
  return { passed = true, errors = {}, totalSeeds = 0 }
end

return LevelGenerator
