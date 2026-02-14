-- Public API for multi-zone procedural generation only.
local LevelGen = require("world.procgen.level_gen")

return {
  generateLevel = LevelGen.generateLevel,
  quickTest = LevelGen.quickTest,
}
