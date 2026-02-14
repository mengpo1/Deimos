-- Public API for procedural 3-zone level generation.
local LevelGen = require("world.procgen.level_gen")

return {
  generateLevel = LevelGen.generateLevel,
  quickTest = LevelGen.quickTest,
}
