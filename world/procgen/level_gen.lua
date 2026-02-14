-- 3-zone procedural level generator orchestrator and fast tests.
local Rng = require("world.procgen.rng")
local ZoneGen = require("world.procgen.zone_gen")
local Validate = require("world.procgen.validate")

local LevelGen = {}

local DEFAULTS = {
  maxTries = 60,
  zones = {
    zone1 = { width = 96, height = 56 },
    zone2 = { width = 104, height = 64 },
    zone3 = { width = 120, height = 72 },
  },
  corridorWidthRange = { 1, 3 },
  filterLengthRange = { 4, 12 },
  arenaSizeRange = { 6, 12 },
  largeArenaSizeRange = { 12, 18 },
  pivotSizeRange = { 10, 16 },
  connectorLengthRange = { 8, 16 },
}

local function deepCopy(source)
  local out = {}
  for k, v in pairs(source) do
    if type(v) == "table" then
      out[k] = deepCopy(v)
    else
      out[k] = v
    end
  end
  return out
end

local function mergeParams(params)
  local merged = deepCopy(DEFAULTS)
  local incoming = params or {}

  for key, value in pairs(incoming) do
    if type(value) == "table" and type(merged[key]) == "table" then
      for subKey, subValue in pairs(value) do
        if type(subValue) == "table" and type(merged[key][subKey]) == "table" then
          for kk, vv in pairs(subValue) do
            merged[key][subKey][kk] = vv
          end
        else
          merged[key][subKey] = subValue
        end
      end
    else
      merged[key] = value
    end
  end

  return merged
end

local function countSigma(zone)
  local count = 0
  for _, block in ipairs(zone.blocks) do
    if block.kind and string.sub(block.kind, 1, 1) == "Σ" then
      count = count + 1
    end
  end
  return count
end

local function countPivot(zone)
  local pivots = 0
  for _, block in ipairs(zone.blocks) do
    if block.kind == "P" then
      pivots = pivots + 1
    end
  end
  return pivots
end

local function validateZoneCounts(level)
  local z1Sigma = countSigma(level.zone1)
  local z2Sigma = countSigma(level.zone2)
  local z3Sigma = countSigma(level.zone3)

  if z1Sigma ~= 0 then
    return false
  end
  if z2Sigma < 1 or z2Sigma > 2 then
    return false
  end
  if z3Sigma < 2 or z3Sigma > 3 then
    return false
  end

  if countPivot(level.zone1) < 1 or countPivot(level.zone2) < 1 or countPivot(level.zone3) < 1 then
    return false
  end

  return true
end

local function buildConnector(rng, fromZone, toZone, params)
  return {
    kind = "C",
    fromZone = fromZone.id,
    toZone = toZone.id,
    fromDoor = { x = fromZone.exitDoor.x, y = fromZone.exitDoor.y },
    toDoor = { x = toZone.entryDoor.x, y = toZone.entryDoor.y },
    length = rng:randomInt(params.connectorLengthRange[1], params.connectorLengthRange[2]),
    orthogonal = true,
  }
end

local function buildZoneConfig(id, dims, grammar, anomalies, rng, params)
  return {
    id = id,
    width = dims.width,
    height = dims.height,
    grammar = grammar,
    allowedAnomalies = anomalies,
    rng = rng,
    corridorWidthRange = params.corridorWidthRange,
    filterLengthRange = params.filterLengthRange,
    arenaSizeRange = params.arenaSizeRange,
    largeArenaSizeRange = params.largeArenaSizeRange,
    pivotSizeRange = params.pivotSizeRange,
  }
end

function LevelGen.generateLevel(seed, params)
  assert(seed ~= nil, "generateLevel(seed, params): seed obligatoire")

  local cfg = mergeParams(params)
  for attempt = 0, cfg.maxTries - 1 do
    local rng = Rng.new((tonumber(seed) or 1) + attempt)

    local zone1 = ZoneGen.generate(buildZoneConfig(
      "zone1",
      cfg.zones.zone1,
      { "F", "A", "F", "A", "P", "F", "A" },
      {},
      rng,
      cfg
    ))

    if zone1 then
      local zone2 = ZoneGen.generate(buildZoneConfig(
        "zone2",
        cfg.zones.zone2,
        { "F", "A", "Σ", "F", "A", "P", "Σ", "F", "A" },
        { "Σ1", "Σ4" },
        rng,
        cfg
      ))

      if zone2 then
        local zone3 = ZoneGen.generate(buildZoneConfig(
          "zone3",
          cfg.zones.zone3,
          { "F", "Σ", "A", "F", "A", "Σ", "P", "F", "A_LARGE" },
          { "Σ1", "Σ2", "Σ3", "Σ4", "Σ5" },
          rng,
          cfg
        ))

        if zone3 then
          local levelData = {
            seed = seed,
            params = cfg,
            zone1 = zone1,
            zone2 = zone2,
            zone3 = zone3,
            zones = { zone1, zone2, zone3 },
          }

          levelData.connectors = {
            buildConnector(rng, zone1, zone2, cfg),
            buildConnector(rng, zone2, zone3, cfg),
          }

          levelData.macroGraph = {
            zones = {
              { id = "zone1", next = "zone2" },
              { id = "zone2", next = "zone3" },
              { id = "zone3", next = nil },
            },
            connectors = levelData.connectors,
          }

          levelData.microGraph = {
            zone1 = zone1.blocks,
            zone2 = zone2.blocks,
            zone3 = zone3.blocks,
          }

          if Validate.level(levelData) and validateZoneCounts(levelData) then
            return levelData
          end
        end
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
      errors[#errors + 1] = string.format("seed %d: generation_failed", seed)
    else
      local level = result
      if not Validate.level(level) then
        errors[#errors + 1] = string.format("seed %d: connectivity_or_bounds", seed)
      end

      if countPivot(level.zone1) < 1 or countPivot(level.zone2) < 1 or countPivot(level.zone3) < 1 then
        errors[#errors + 1] = string.format("seed %d: missing_pivot", seed)
      end

      local z2Sigma = countSigma(level.zone2)
      local z3Sigma = countSigma(level.zone3)
      if z2Sigma < 1 or z2Sigma > 2 then
        errors[#errors + 1] = string.format("seed %d: z2_sigma_out_of_range", seed)
      end
      if z3Sigma < 2 or z3Sigma > 3 then
        errors[#errors + 1] = string.format("seed %d: z3_sigma_out_of_range", seed)
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
