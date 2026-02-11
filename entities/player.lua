-- Player actor driven by input with smooth movement, aiming, and melee combat.
local Class = require("core.class")
local Actor = require("core.actor")
local WeaponDefinitions = require("core.weapon_definitions")

local Player = Class(Actor)

local function normalize(x, y)
  local length = math.sqrt(x * x + y * y)
  if length == 0 then
    return 0, 0, 0
  end
  return x / length, y / length, length
end

-- Initialize player state with speed, facing angle, and 2-slot inventory.
function Player:init(options)
  Player.super.init(self, options)
  self.speed = options.speed or 180
  self.color = options.color or { 0.92, 0.92, 0.92 }
  self.facingAngle = 0
  self.attackCooldownRemaining = 0
  self.inventory = {
    WeaponDefinitions.createInstance(options.equippedWeaponId or "fists"),
    nil,
  }
  self.activeSlot = 1
end

-- Place the player in the center of the room.
function Player:spawnAtRoomCenter(room)
  self.position.x = room.origin.x + room.width / 2
  self.position.y = room.origin.y + room.height / 2
end

-- Return currently equipped inventory item.
function Player:getEquippedItem()
  return self.inventory[self.activeSlot]
end

-- Return active weapon definition.
function Player:getEquippedWeapon()
  local item = self:getEquippedItem()
  return WeaponDefinitions.get(item and item.id or "fists")
end

-- Return durability text for HUD.
function Player:getEquippedDurabilityText()
  local item = self:getEquippedItem()
  if not item then
    return "-"
  end
  if item.durability == nil then
    return "∞"
  end
  return tostring(item.durability)
end

-- Switch primary/secondary weapon slot.
function Player:swapWeaponSlot(world)
  if self.inventory[2] == nil then
    world.message = "Aucune arme secondaire à équiper."
    world.messageTimer = 1.0
    return false
  end

  self.activeSlot = self.activeSlot == 1 and 2 or 1
  local weapon = self:getEquippedWeapon()
  world.message = string.format("Arme active : %s", weapon.label)
  world.messageTimer = 1.0
  return true
end

-- Add a weapon item to inventory, replacing active slot if full.
function Player:addWeaponItem(item, world)
  if self.inventory[1] == nil then
    self.inventory[1] = item
    self.activeSlot = 1
    return
  end

  if self.inventory[2] == nil then
    self.inventory[2] = item
    return
  end

  self:dropCurrentWeapon(world)
  self.inventory[self.activeSlot] = item
end

-- Drop current weapon to the floor (except fists).
function Player:dropCurrentWeapon(world)
  local item = self:getEquippedItem()
  if not item or item.id == "fists" then
    world.message = "Impossible de lâcher les poings."
    world.messageTimer = 1.0
    return false
  end

  table.insert(world.pickups, world:createPickup({
    x = self.position.x + math.cos(self.facingAngle) * 18,
    y = self.position.y + math.sin(self.facingAngle) * 18,
    weaponId = item.id,
    durability = item.durability,
  }))

  self.inventory[self.activeSlot] = WeaponDefinitions.createInstance("fists")
  world.message = "Arme lâchée au sol."
  world.messageTimer = 1.0
  return true
end

-- Consume one durability point on successful hit, break when reaching zero.
function Player:consumeDurability(world)
  local item = self:getEquippedItem()
  if not item or item.durability == nil then
    return
  end

  item.durability = item.durability - 1
  if item.durability <= 0 then
    local brokenWeapon = WeaponDefinitions.get(item.id)
    self.inventory[self.activeSlot] = WeaponDefinitions.createInstance("fists")
    world.message = string.format("%s se brise ! Retour aux poings.", brokenWeapon.label)
    world.messageTimer = 1.4
  end
end

-- Clamp player position so the triangle stays inside room bounds.
function Player:clampToRoom(room)
  local halfSize = self.size / 2
  self.position.x = math.max(room.origin.x + halfSize, math.min(self.position.x, room.origin.x + room.width - halfSize))
  self.position.y = math.max(room.origin.y + halfSize, math.min(self.position.y, room.origin.y + room.height - halfSize))
end

-- Update facing direction toward the current mouse pointer.
function Player:updateFacingToMouse()
  local mouseX, mouseY = love.mouse.getPosition()
  self.facingAngle = math.atan2(mouseY - self.position.y, mouseX - self.position.x)
end

-- Compute maximum attack distance in pixels from weapon range.
function Player:getAttackReach(room, target)
  local weapon = self:getEquippedWeapon()
  local bodyReach = (self.size + target.size) * 0.5
  local tileSize = (room and room.tileSize) or 32
  local weaponReach = weapon.range * tileSize
  return bodyReach + weaponReach
end

-- Return true when target is inside current weapon attack arc.
function Player:isTargetInArc(target)
  local weapon = self:getEquippedWeapon()
  local toTargetX = target.position.x - self.position.x
  local toTargetY = target.position.y - self.position.y
  local nx, ny, length = normalize(toTargetX, toTargetY)

  if length == 0 then
    return true
  end

  local dirX = math.cos(self.facingAngle)
  local dirY = math.sin(self.facingAngle)
  local dot = dirX * nx + dirY * ny
  local minDot = math.cos(math.rad(weapon.arcDegrees) * 0.5)
  return dot >= minDot
end

-- Return true when attacker is behind target (backstab).
function Player:isBackstab(target)
  local toPlayerX = self.position.x - target.position.x
  local toPlayerY = self.position.y - target.position.y
  local nx, ny, length = normalize(toPlayerX, toPlayerY)

  if length == 0 then
    return false
  end

  local targetForwardX = math.cos(target.facingAngle or 0)
  local targetForwardY = math.sin(target.facingAngle or 0)
  local dot = targetForwardX * nx + targetForwardY * ny
  return dot <= -0.35
end

-- Try applying a melee hit on the closest valid target in range.
function Player:performMeleeAttack(world)
  if self.attackCooldownRemaining > 0 then
    world.message = string.format("Attaque en recharge (%.2fs)", self.attackCooldownRemaining)
    world.messageTimer = 0.5
    return false
  end

  local weapon = self:getEquippedWeapon()
  self.attackCooldownRemaining = weapon.cooldown

  local bestTarget = nil
  local bestDistance = math.huge

  for _, target in ipairs(world.targets or {}) do
    if target.isAlive then
      local dx = target.position.x - self.position.x
      local dy = target.position.y - self.position.y
      local distance = math.sqrt(dx * dx + dy * dy)
      local attackReach = self:getAttackReach(world.room, target)

      if distance <= attackReach and self:isTargetInArc(target) and distance < bestDistance then
        bestTarget = target
        bestDistance = distance
      end
    end
  end

  if not bestTarget then
    world.message = string.format("%s rate sa cible.", weapon.label)
    world.messageTimer = 0.8
    return false
  end

  local damage = weapon.damage
  local crit = false
  if self:isBackstab(bestTarget) then
    damage = math.floor(damage * weapon.backstabMultiplier)
    crit = true
  end

  bestTarget:takeDamage(damage)

  local hitDirX, hitDirY = normalize(bestTarget.position.x - self.position.x, bestTarget.position.y - self.position.y)
  bestTarget:applyImpact(hitDirX * weapon.knockback, hitDirY * weapon.knockback, weapon.hitstun)

  self:consumeDurability(world)

  if crit then
    world.message = string.format("CRIT DOS ! %s inflige %d dégâts.", weapon.label, damage)
  else
    world.message = string.format("%s inflige %d dégâts.", weapon.label, damage)
  end
  world.messageTimer = 1.2
  return true
end

-- Try picking up a nearby weapon.
function Player:pickupNearbyWeapon(world)
  local pickupRadius = 26

  for index, pickup in ipairs(world.pickups or {}) do
    local dx = pickup.position.x - self.position.x
    local dy = pickup.position.y - self.position.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance <= pickupRadius then
      local item = pickup:toInventoryItem()
      local weapon = WeaponDefinitions.get(item.id)
      self:addWeaponItem(item, world)
      table.remove(world.pickups, index)
      world.message = string.format("Arme ramassée : %s (%d dmg, portée %d)", weapon.label, weapon.damage, weapon.range)
      world.messageTimer = 1.6
      return true
    end
  end

  world.message = "Aucune arme à ramasser ici."
  world.messageTimer = 1.0
  return false
end

-- Draw the player as a triangle whose tip points toward the cursor.
function Player:draw()
  local forwardX = math.cos(self.facingAngle)
  local forwardY = math.sin(self.facingAngle)
  local sideX = -forwardY
  local sideY = forwardX

  local tipDistance = self.size * 0.65
  local baseDistance = self.size * 0.45
  local halfBaseWidth = self.size * 0.5

  local tipX = self.position.x + forwardX * tipDistance
  local tipY = self.position.y + forwardY * tipDistance
  local baseCenterX = self.position.x - forwardX * baseDistance
  local baseCenterY = self.position.y - forwardY * baseDistance
  local leftX = baseCenterX + sideX * halfBaseWidth
  local leftY = baseCenterY + sideY * halfBaseWidth
  local rightX = baseCenterX - sideX * halfBaseWidth
  local rightY = baseCenterY - sideY * halfBaseWidth

  love.graphics.setColor(self.color)
  love.graphics.polygon("fill", tipX, tipY, leftX, leftY, rightX, rightY)
end

-- Consume movement, attack, pickup, and inventory actions.
function Player:takeTurn(input, world, dt)
  self.attackCooldownRemaining = math.max(0, self.attackCooldownRemaining - dt)

  local dx, dy = 0, 0
  if input:isDown("move_up") then dy = dy - 1 end
  if input:isDown("move_down") then dy = dy + 1 end
  if input:isDown("move_left") then dx = dx - 1 end
  if input:isDown("move_right") then dx = dx + 1 end

  if dx ~= 0 and dy ~= 0 then
    local normalization = math.sqrt(0.5)
    dx = dx * normalization
    dy = dy * normalization
  end

  local moved = false
  if dx ~= 0 or dy ~= 0 then
    local nextX = self.position.x + dx * self.speed * dt
    local nextY = self.position.y + dy * self.speed * dt

    if world.isWalkablePosition then
      local radius = self.size * 0.3
      if world:isWalkablePosition(nextX, self.position.y, radius) then
        self.position.x = nextX
        moved = true
      end
      if world:isWalkablePosition(self.position.x, nextY, radius) then
        self.position.y = nextY
        moved = true
      end
    elseif world.room then
      self.position.x = nextX
      self.position.y = nextY
      self:clampToRoom(world.room)
      moved = true
    end
  end

  self:updateFacingToMouse()

  local attacked = input:wasPressed("attack") and self:performMeleeAttack(world) or false
  local pickedUp = input:wasPressed("pickup") and self:pickupNearbyWeapon(world) or false
  local swapped = input:wasPressed("swap_weapon") and self:swapWeaponSlot(world) or false
  local dropped = input:wasPressed("drop_weapon") and self:dropCurrentWeapon(world) or false

  return moved or attacked or pickedUp or swapped or dropped
end

return Player
