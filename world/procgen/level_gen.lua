-- Multi-zone top-down procedural level generator using spatial grammar.
local Rng = require("world.procgen.rng")
local ZoneGen = require("world.procgen.zone_gen")
local Validate = require("world.procgen.validate")

local LevelGen = {}

local DEFAULTS = {
  maxTries = 40,
  zones = {
    zone1 = { width = 96, height = 64 },
    zone2 = { width = 104, height = 68 },
    zone3 = { width = 112, height = 72 },
  },
  filterWidthRange = { 1, 3 },
  filterLengthRange = { 4, 12 },
  arenaSizeRange = { 6, 12 },
  largeArenaSizeRange = { 12, 18 },
  pivotSizeRange = { 10, 16 },
  connectorLengthRange = { 8, 16 },
}

local function mergeParams(params)
  local p = params or {}
  local merged = {
    maxTries = p.maxTries or DEFAULTS.maxTries,
    zones = {
      zone1 = p.zones and p.zones.zone1 or DEFAULTS.zones.zone1,
      zone2 = p.zones and p.zones.zone2 or DEFAULTS.zones.zone2,
      zone3 = p.zones and p.zones.zone3 or DEFAULTS.zones.zone3,
    },
    filterWidthRange = p.filterWidthRange or DEFAULTS.filterWidthRange,
    filterLengthRange = p.filterLengthRange or DEFAULTS.filterLengthRange,
    arenaSizeRange = p.arenaSizeRange or DEFAULTS.arenaSizeRange,
    largeArenaSizeRange = p.largeArenaSizeRange or DEFAULTS.largeArenaSizeRange,
    pivotSizeRange = p.pivotSizeRange or DEFAULTS.pivotSizeRange,
    connectorLengthRange = p.connectorLengthRange or DEFAULTS.connectorLengthRange,
  }
  return merged
end

local function zoneConfig(id, grammar, dims, rng, params, allowedAnomalies)
  return {
    id = id,
    width = dims.width,
    height = dims.height,
    grammar = grammar,
    rng = rng,
    filterWidthRange = params.filterWidthRange,
    filterLengthRange = params.filterLengthRange,
    arenaSizeRange = params.arenaSizeRange,
    largeArenaSizeRange = params.largeArenaSizeRange,
    pivotSizeRange = params.pivotSizeRange,
    allowedAnomalies = allowedAnomalies,
  }
end

local function buildConnectors(level, rng, params)
  local connectors = {}
  local c12 = {
    kind = "C",
    fromZone = "zone1",
    toZone = "zone2",
    fromDoor = level.zone1.exitDoor,
    toDoor = level.zone2.entryDoor,
    length = rng:randomInt(params.connectorLengthRange[1], params.connectorLengthRange[2]),
    orthogonal = true,
  }

  local c23 = {
    kind = "C",
    fromZone = "zone2",
    toZone = "zone3",
    fromDoor = level.zone2.exitDoor,
    toDoor = level.zone3.entryDoor,
    length = rng:randomInt(params.connectorLengthRange[1], params.connectorLengthRange[2]),
    orthogonal = true,
  }

  connectors[1] = c12
  connectors[2] = c23
  return connectors
end

local function buildMacroGraph(level)
  return {
    zones = {
      { id = "zone1", next = "zone2" },
      { id = "zone2", next = "zone3" },
      { id = "zone3", next = nil },
    },
    connectors = level.connectors,
  }
end

local function buildMicroGraph(level)
  return {
    zone1 = level.zone1.blocks,
    zone2 = level.zone2.blocks,
    zone3 = level.zone3.blocks,
  }
end

local function countAnomalies(blocks)
  local count = 0
  for _, block in ipairs(blocks) do
    if block.kind and string.sub(block.kind, 1, 1) == "Σ" then
      count = count + 1
    end
  end
  return count
end

local function validateZoneConstraints(level)
  if level.zone1.pivotCount < 1 or level.zone2.pivotCount < 1 or level.zone3.pivotCount < 1 then
    return false
  end

  local z1Sigma = countAnomalies(level.zone1.blocks)
  local z2Sigma = countAnomalies(level.zone2.blocks)
  local z3Sigma = countAnomalies(level.zone3.blocks)

  if z1Sigma ~= 0 then
    return false
  end
  if z2Sigma < 1 or z2Sigma > 2 then
    return false
  end
  if z3Sigma < 2 or z3Sigma > 3 then
    return false
  end

  return true
end

function LevelGen.generateLevel(seed, params)
  assert(seed ~= nil, "generateLevel(seed, params): seed obligatoire")

  local merged = mergeParams(params)

  for attempt = 0, merged.maxTries - 1 do
    local rng = Rng.new((tonumber(seed) or 1) + attempt)

    local zone1, err1 = ZoneGen.generateZone("zone1", seed, zoneConfig(
      "zone1",
      { "F", "A", "F", "A", "P", "F", "A" },
      merged.zones.zone1,
      rng,
      merged,
      {}
    ))

    local zone2 = err1 == nil and ZoneGen.generateZone("zone2", seed, zoneConfig(
      "zone2",
      { "F", "A", "Σ", "F", "A", "P", "Σ", "F", "A" },
      merged.zones.zone2,
      rng,
      merged,
      { "Σ1", "Σ4" }
    )) or nil

    local zone3 = zone2 and ZoneGen.generateZone("zone3", seed, zoneConfig(
      "zone3",
      { "F", "Σ", "A", "F", "A", "Σ", "P", "F", "A_LARGE" },
      merged.zones.zone3,
      rng,
      merged,
      { "Σ1", "Σ2", "Σ4", "Σ5" }
    )) or nil

    if zone1 and zone2 and zone3 then
      local level = {
        seed = seed,
        zone1 = zone1,
        zone2 = zone2,
        zone3 = zone3,
        zones = { zone1, zone2, zone3 },
      }

      level.connectors = buildConnectors(level, rng, merged)
      level.macroGraph = buildMacroGraph(level)
      level.microGraph = buildMicroGraph(level)

      if Validate.fullLevel(level) and validateZoneConstraints(level) then
        return level
      end
    end
  end

  error("generateLevel(seed, params): échec de génération après maxTries")
end

function LevelGen.quickTest(params)
  local errors = {}

  for seed = 1, 20 do
    local ok, result = pcall(LevelGen.generateLevel, seed, params)
    if not ok then
      table.insert(errors, string.format("seed %d: generation_failed", seed))
    else
      local level = result
      if not Validate.fullLevel(level) then
        table.insert(errors, string.format("seed %d: connectivity_or_bounds_invalid", seed))
      end
      if level.zone1.pivotCount < 1 or level.zone2.pivotCount < 1 or level.zone3.pivotCount < 1 then
        table.insert(errors, string.format("seed %d: missing_pivot", seed))
      end
    end
  end

  return {
    passed = #errors == 0,
    errors = errors,
    totalSeeds = 20,
  }
end

return LevelGen
