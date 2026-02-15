-- World pickup representing an equippable melee weapon.
local Class = require("core.class")
local WeaponDefinitions = require("core.weapon_definitions")

local WeaponPickup = Class()

-- Initialize pickup with world position and weapon id.
function WeaponPickup:init(options)
  self.position = {
    x = options.x,
    y = options.y,
  }
  self.weaponId = options.weaponId
  self.durability = options.durability
  self.radius = options.radius or 10
end

-- Return linked weapon stats.
function WeaponPickup:getWeapon()
  return WeaponDefinitions.get(self.weaponId)
end

-- Convert pickup data into inventory item instance.
function WeaponPickup:toInventoryItem()
  local definition = self:getWeapon()
  return {
    id = definition.id,
    durability = self.durability ~= nil and self.durability or definition.durability,
  }
end

-- Draw pickup as a small circle with weapon initial.
function WeaponPickup:draw()
  local weapon = self:getWeapon()
  local label = string.sub(weapon.label, 1, 1)

  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.circle("fill", self.position.x, self.position.y, self.radius)

  love.graphics.setColor(0.08, 0.08, 0.08)
  love.graphics.print(label, self.position.x - 4, self.position.y - 6)
end

return WeaponPickup
