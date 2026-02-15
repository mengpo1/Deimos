-- Weapon catalog used by melee combat and pickups.
local WeaponDefinitions = {
  fists = {
    id = "fists",
    label = "Poings",
    damage = 1,
    range = 0,
    cooldown = 0.20,
    arcDegrees = 70,
    durability = nil,
    knockback = 70,
    hitstun = 0.12,
    backstabMultiplier = 1.5,
  },
  stick = {
    id = "stick",
    label = "Bâton",
    damage = 3,
    range = 2,
    cooldown = 0.42,
    arcDegrees = 90,
    durability = 28,
    knockback = 120,
    hitstun = 0.16,
    backstabMultiplier = 1.6,
  },
  bat = {
    id = "bat",
    label = "Batte",
    damage = 4,
    range = 2,
    cooldown = 0.52,
    arcDegrees = 100,
    durability = 26,
    knockback = 170,
    hitstun = 0.20,
    backstabMultiplier = 1.7,
  },
  knife = {
    id = "knife",
    label = "Couteau",
    damage = 10,
    range = 1,
    cooldown = 0.30,
    arcDegrees = 55,
    durability = 20,
    knockback = 80,
    hitstun = 0.10,
    backstabMultiplier = 2.2,
  },
  sabre = {
    id = "sabre",
    label = "Sabre",
    damage = 20,
    range = 2,
    cooldown = 0.65,
    arcDegrees = 115,
    durability = 16,
    knockback = 220,
    hitstun = 0.24,
    backstabMultiplier = 2.0,
  },
}

-- Return a definition by id, defaulting to fists.
function WeaponDefinitions.get(weaponId)
  return WeaponDefinitions[weaponId] or WeaponDefinitions.fists
end

-- Create an inventory instance for a weapon id.
function WeaponDefinitions.createInstance(weaponId)
  local definition = WeaponDefinitions.get(weaponId)
  return {
    id = definition.id,
    durability = definition.durability,
  }
end

return WeaponDefinitions
