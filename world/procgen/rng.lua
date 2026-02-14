-- Seeded RNG helper for deterministic procedural generation.
local Rng = {}

function Rng.new(seed)
  assert(seed ~= nil, "Rng.new(seed): seed obligatoire")

  local state = (tonumber(seed) or 1) % 2147483647
  if state <= 0 then
    state = state + 2147483646
  end

  local rng = {}

  local function nextInt()
    state = (state * 48271) % 2147483647
    return state
  end

  function rng:randomFloat()
    return nextInt() / 2147483647
  end

  function rng:randomInt(minValue, maxValue)
    assert(minValue <= maxValue, "Rng.randomInt: invalid range")
    return minValue + math.floor(self:randomFloat() * (maxValue - minValue + 1))
  end

  function rng:choice(values)
    assert(type(values) == "table" and #values > 0, "Rng.choice: non-empty table required")
    return values[self:randomInt(1, #values)]
  end

  return rng
end

return Rng
