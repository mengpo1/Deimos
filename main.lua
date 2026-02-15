-- Love2D entry point: runtime wired to procedural level generator output.
local Input = require("core.input")
local Player = require("entities.player")
local TurnManager = require("core.turn_manager")
local WeaponPickup = require("world.weapon_pickup")
local SaveSystem = require("core.save_system")
local LevelGenerator = require("world.level_generator")

local world
local player
local turnManager
local input

local TILE_SIZE = 24

local gameState = {
  seed = nil,
}

local resolutionOptions = {
  { width = 960, height = 540 },
  { width = 1280, height = 720 },
  { width = 1600, height = 900 },
  { width = 1920, height = 1080 },
}

local optionsState = {
  resolutionIndex = 2,
  bindingSelection = 1,
  waitingForAction = nil,
}

local bindingsConfig = {
  move_up = { "up", "w" },
  move_down = { "down", "s" },
  move_left = { "left", "a" },
  move_right = { "right", "d" },
  attack = { "space", "mouse1" },
  pickup = { "e" },
  swap_weapon = { "q" },
  drop_weapon = { "g" },
}

local bindingOrder = {
  "move_up",
  "move_down",
  "move_left",
  "move_right",
  "attack",
  "pickup",
  "swap_weapon",
  "drop_weapon",
}

local bindingLabels = {
  move_up = "Déplacer haut",
  move_down = "Déplacer bas",
  move_left = "Déplacer gauche",
  move_right = "Déplacer droite",
  attack = "Attaquer",
  pickup = "Ramasser",
  swap_weapon = "Changer d'arme",
  drop_weapon = "Lâcher arme",
}

local menu = {
  isOpen = false,
  screen = "main",
  selection = 1,
  slotSelection = 1,
}

local function tileKey(x, y)
  return string.format("%d,%d", x, y)
end

local function buildBindings()
  return {
    move_up = { bindingsConfig.move_up[1], bindingsConfig.move_up[2] },
    move_down = { bindingsConfig.move_down[1], bindingsConfig.move_down[2] },
    move_left = { bindingsConfig.move_left[1], bindingsConfig.move_left[2] },
    move_right = { bindingsConfig.move_right[1], bindingsConfig.move_right[2] },
    attack = { bindingsConfig.attack[1], bindingsConfig.attack[2] },
    pickup = { bindingsConfig.pickup[1] },
    swap_weapon = { bindingsConfig.swap_weapon[1] },
    drop_weapon = { bindingsConfig.drop_weapon[1] },
  }
end

local function applyResolution()
  local option = resolutionOptions[optionsState.resolutionIndex]
  love.window.setMode(option.width, option.height, { resizable = false })
end

local function tileToWorld(tx, ty)
  return {
    x = (tx - 0.5) * TILE_SIZE,
    y = (ty - 0.5) * TILE_SIZE,
  }
end

local function worldToTile(x, y)
  return math.floor(x / TILE_SIZE) + 1, math.floor(y / TILE_SIZE) + 1
end

local function placeZoneTiles(tileLookup, zone, offsetX)
  for y = 1, zone.height do
    for x = 1, zone.width do
      local tile = zone.tiles[y][x]
      if tile ~= "WALL" then
        tileLookup[tileKey(offsetX + x - 1, y)] = tile
      end
    end
  end
end

local function carveConnector(tileLookup, from, to)
  local x, y = from.x, from.y
  local tx, ty = to.x, to.y

  while x ~= tx do
    tileLookup[tileKey(x, y)] = "FLOOR"
    x = x + (tx > x and 1 or -1)
  end

  while y ~= ty do
    tileLookup[tileKey(x, y)] = "FLOOR"
    y = y + (ty > y and 1 or -1)
  end

  tileLookup[tileKey(tx, ty)] = "DOOR"
end

local function buildWorld(levelData, pickupState)
  local zone1Offset = 1
  local zone2Offset = zone1Offset + levelData.zone1.width + levelData.connectors[1].length
  local zone3Offset = zone2Offset + levelData.zone2.width + levelData.connectors[2].length

  local tileLookup = {}
  placeZoneTiles(tileLookup, levelData.zone1, zone1Offset)
  placeZoneTiles(tileLookup, levelData.zone2, zone2Offset)
  placeZoneTiles(tileLookup, levelData.zone3, zone3Offset)

  local c1From = { x = zone1Offset + levelData.zone1.exitDoor.x - 1, y = levelData.zone1.exitDoor.y }
  local c1To = { x = zone2Offset + levelData.zone2.entryDoor.x - 1, y = levelData.zone2.entryDoor.y }
  local c2From = { x = zone2Offset + levelData.zone2.exitDoor.x - 1, y = levelData.zone2.exitDoor.y }
  local c2To = { x = zone3Offset + levelData.zone3.entryDoor.x - 1, y = levelData.zone3.entryDoor.y }

  carveConnector(tileLookup, c1From, c1To)
  carveConnector(tileLookup, c2From, c2To)

  local worldTilesWide = zone3Offset + levelData.zone3.width
  local worldTilesHigh = math.max(levelData.zone1.height, levelData.zone2.height, levelData.zone3.height)

  local worldState = {
    level = levelData,
    offsets = {
      zone1 = zone1Offset,
      zone2 = zone2Offset,
      zone3 = zone3Offset,
    },
    room = {
      origin = { x = 0, y = 0 },
      tileSize = TILE_SIZE,
      tilesWide = worldTilesWide,
      tilesHigh = worldTilesHigh,
      width = worldTilesWide * TILE_SIZE,
      height = worldTilesHigh * TILE_SIZE,
    },
    tileLookup = tileLookup,
    pickups = {},
    targets = {},
    message = "",
    messageTimer = 0,
  }

  if pickupState and #pickupState > 0 then
    for _, pick in ipairs(pickupState) do
      table.insert(worldState.pickups, WeaponPickup:new({
        x = pick.x,
        y = pick.y,
        weaponId = pick.weaponId,
        durability = pick.durability,
      }))
    end
  else
    local entryTile = {
      x = zone1Offset + levelData.zone1.entryDoor.x + 2,
      y = levelData.zone1.entryDoor.y,
    }

    local pivotTile = {
      x = zone2Offset + levelData.zone2.entryDoor.x + 6,
      y = levelData.zone2.entryDoor.y,
    }

    local a = tileToWorld(entryTile.x, entryTile.y)
    local b = tileToWorld(pivotTile.x, pivotTile.y)

    worldState.pickups = {
      WeaponPickup:new({ x = a.x, y = a.y, weaponId = "stick" }),
      WeaponPickup:new({ x = b.x, y = b.y, weaponId = "knife" }),
    }
  end

  function worldState:createPickup(options)
    return WeaponPickup:new(options)
  end

  function worldState:getCameraRect(focus)
    local focusX = (focus and focus.position and focus.position.x) or (self.room.width * 0.5)
    local focusY = (focus and focus.position and focus.position.y) or (self.room.height * 0.5)

    local viewWidth = love.graphics.getWidth()
    local viewHeight = love.graphics.getHeight()

    local x = focusX - viewWidth * 0.5
    local y = focusY - viewHeight * 0.5

    x = math.max(0, math.min(x, self.room.width - viewWidth))
    y = math.max(0, math.min(y, self.room.height - viewHeight))

    local minTileX = math.floor(x / TILE_SIZE) + 1
    local minTileY = math.floor(y / TILE_SIZE) + 1
    local maxTileX = math.ceil((x + viewWidth) / TILE_SIZE)
    local maxTileY = math.ceil((y + viewHeight) / TILE_SIZE)

    return {
      x = x,
      y = y,
      minTileX = minTileX,
      minTileY = minTileY,
      maxTileX = maxTileX,
      maxTileY = maxTileY,
    }
  end

  function worldState:isWalkablePosition(x, y, radius)
    local r = radius or 0
    local points = {
      { x = x, y = y },
      { x = x - r, y = y },
      { x = x + r, y = y },
      { x = x, y = y - r },
      { x = x, y = y + r },
    }

    for _, p in ipairs(points) do
      if p.x < 0 or p.y < 0 or p.x > self.room.width or p.y > self.room.height then
        return false
      end

      local tx, ty = worldToTile(p.x, p.y)
      local tile = self.tileLookup[tileKey(tx, ty)]
      if tile ~= "FLOOR" and tile ~= "DOOR" then
        return false
      end
    end

    return true
  end

  return worldState
end

local function spawnPlayerAtLevelEntry(levelData, worldState)
  local tx = worldState.offsets.zone1 + levelData.zone1.entryDoor.x
  local ty = levelData.zone1.entryDoor.y
  local pos = tileToWorld(tx, ty)
  player.position.x = pos.x
  player.position.y = pos.y
end

local function serializePickups()
  local data = {}
  for _, pick in ipairs(world.pickups) do
    table.insert(data, {
      x = pick.position.x,
      y = pick.position.y,
      weaponId = pick.weaponId,
      durability = pick.durability,
    })
  end
  return data
end

local function serializePlayer()
  return {
    position = { x = player.position.x, y = player.position.y },
    facingAngle = player.facingAngle,
    inventory = player.inventory,
    activeSlot = player.activeSlot,
  }
end

local function startNewGame(seed, loaded)
  gameState.seed = seed or love.math.random(1, 999999)
  local levelData = LevelGenerator.generateLevel(gameState.seed)
  world = buildWorld(levelData, loaded and loaded.pickups or nil)

  player = Player:new({ size = 16, speed = 520, equippedWeaponId = "fists" })

  if loaded and loaded.player then
    player.position.x = loaded.player.position.x
    player.position.y = loaded.player.position.y
    player.facingAngle = loaded.player.facingAngle or 0
    player.inventory = loaded.player.inventory or player.inventory
    player.activeSlot = loaded.player.activeSlot or 1
  else
    spawnPlayerAtLevelEntry(levelData, world)
  end

  input = Input:new(buildBindings())
  turnManager = TurnManager:new({ player })

  world.message = string.format("Niveau généré (seed %d)", gameState.seed)
  world.messageTimer = 2.2
end

local function saveToSlot(slot)
  local payload = {
    seed = gameState.seed,
    player = serializePlayer(),
    pickups = serializePickups(),
    resolutionIndex = optionsState.resolutionIndex,
    bindings = bindingsConfig,
  }

  local ok = SaveSystem.save(slot, payload)
  world.message = ok and string.format("Partie sauvegardée slot %d", slot) or "Échec sauvegarde"
  world.messageTimer = 1.6
end

local function loadFromSlot(slot)
  local payload = SaveSystem.load(slot)
  if not payload then
    world.message = "Slot vide ou invalide"
    world.messageTimer = 1.6
    return
  end

  if payload.bindings then
    bindingsConfig = payload.bindings
  end

  if payload.resolutionIndex then
    optionsState.resolutionIndex = math.max(1, math.min(#resolutionOptions, payload.resolutionIndex))
    applyResolution()
  end

  startNewGame(payload.seed, payload)
  world.message = string.format("Partie chargée slot %d", slot)
  world.messageTimer = 1.6
end

local function drawWorld(worldState, cam)
  for ty = cam.minTileY, cam.maxTileY do
    for tx = cam.minTileX, cam.maxTileX do
      local tile = worldState.tileLookup[tileKey(tx, ty)]
      local x = (tx - 1) * TILE_SIZE
      local y = (ty - 1) * TILE_SIZE

      if tile == "FLOOR" then
        love.graphics.setColor(0.14, 0.14, 0.14)
      elseif tile == "DOOR" then
        love.graphics.setColor(0.75, 0.75, 0.75)
      else
        love.graphics.setColor(0.04, 0.04, 0.04)
      end

      love.graphics.rectangle("fill", x, y, TILE_SIZE, TILE_SIZE)
    end
  end
end

local function openMenu()
  menu.isOpen = true
  menu.screen = "main"
  menu.selection = 1
end

local function closeMenu()
  menu.isOpen = false
  menu.screen = "main"
  optionsState.waitingForAction = nil
end

local function drawMenu()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, 0, w, h)

  love.graphics.setColor(0.9, 0.9, 0.9)
  love.graphics.print("MENU", 24, 20)

  if menu.screen == "main" then
    local entries = { "Nouveau jeu", "Sauvegarder", "Charger", "Options", "Quitter" }
    for i, entry in ipairs(entries) do
      love.graphics.setColor(i == menu.selection and 1 or 0.75, i == menu.selection and 1 or 0.75, i == menu.selection and 1 or 0.75)
      love.graphics.print((i == menu.selection and "> " or "  ") .. entry, 24, 48 + i * 20)
    end
  elseif menu.screen == "save" or menu.screen == "load" then
    local title = menu.screen == "save" and "Sauvegarder - 5 slots" or "Charger - 5 slots"
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print(title, 24, 48)
    for slot = 1, SaveSystem.getSlotCount() do
      local info = SaveSystem.getSlotInfo(slot)
      local label = string.format("Slot %d - %s", slot, info.exists and "occupé" or "vide")
      love.graphics.setColor(slot == menu.slotSelection and 1 or 0.75, slot == menu.slotSelection and 1 or 0.75, slot == menu.slotSelection and 1 or 0.75)
      love.graphics.print((slot == menu.slotSelection and "> " or "  ") .. label, 24, 72 + slot * 20)
    end
  elseif menu.screen == "options" then
    local entries = { "Touches", "Résolution", "Retour" }
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("Options", 24, 48)

    for i, entry in ipairs(entries) do
      local suffix = ""
      if entry == "Résolution" then
        local r = resolutionOptions[optionsState.resolutionIndex]
        suffix = string.format(" (%dx%d)", r.width, r.height)
      elseif entry == "Touches" and optionsState.waitingForAction then
        suffix = " (appuyez sur une touche...)"
      end

      love.graphics.setColor(i == menu.selection and 1 or 0.75, i == menu.selection and 1 or 0.75, i == menu.selection and 1 or 0.75)
      love.graphics.print((i == menu.selection and "> " or "  ") .. entry .. suffix, 24, 72 + i * 20)
    end

    local y = 154
    for idx, action in ipairs(bindingOrder) do
      love.graphics.setColor(idx == optionsState.bindingSelection and 1 or 0.7, idx == optionsState.bindingSelection and 1 or 0.7, idx == optionsState.bindingSelection and 1 or 0.7)
      love.graphics.print(string.format("%s: %s", bindingLabels[action], bindingsConfig[action][1]), 24, y)
      y = y + 16
    end
  end
end

local function handleMainMenuKey(key)
  local max = 5
  if key == "up" then
    menu.selection = math.max(1, menu.selection - 1)
  elseif key == "down" then
    menu.selection = math.min(max, menu.selection + 1)
  elseif key == "return" or key == "kpenter" then
    if menu.selection == 1 then
      startNewGame()
      closeMenu()
    elseif menu.selection == 2 then
      menu.screen = "save"
      menu.slotSelection = 1
    elseif menu.selection == 3 then
      menu.screen = "load"
      menu.slotSelection = 1
    elseif menu.selection == 4 then
      menu.screen = "options"
      menu.selection = 1
    elseif menu.selection == 5 then
      love.event.quit()
    end
  end
end

local function handleSlotMenuKey(key)
  if key == "up" then
    menu.slotSelection = math.max(1, menu.slotSelection - 1)
  elseif key == "down" then
    menu.slotSelection = math.min(SaveSystem.getSlotCount(), menu.slotSelection + 1)
  elseif key == "return" or key == "kpenter" then
    if menu.screen == "save" then
      saveToSlot(menu.slotSelection)
    else
      loadFromSlot(menu.slotSelection)
    end
    closeMenu()
  elseif key == "backspace" then
    menu.screen = "main"
    menu.selection = 1
  end
end

local function handleOptionsMenuKey(key)
  if optionsState.waitingForAction then
    bindingsConfig[optionsState.waitingForAction][1] = key
    optionsState.waitingForAction = nil
    input = Input:new(buildBindings())
    return
  end

  local max = 3
  if key == "up" then
    menu.selection = math.max(1, menu.selection - 1)
  elseif key == "down" then
    menu.selection = math.min(max, menu.selection + 1)
  elseif key == "left" then
    optionsState.bindingSelection = math.max(1, optionsState.bindingSelection - 1)
  elseif key == "right" then
    optionsState.bindingSelection = math.min(#bindingOrder, optionsState.bindingSelection + 1)
  elseif key == "return" or key == "kpenter" then
    if menu.selection == 1 then
      optionsState.waitingForAction = bindingOrder[optionsState.bindingSelection]
    elseif menu.selection == 2 then
      optionsState.resolutionIndex = (optionsState.resolutionIndex % #resolutionOptions) + 1
      applyResolution()
    else
      menu.screen = "main"
      menu.selection = 1
    end
  elseif key == "backspace" then
    menu.screen = "main"
    menu.selection = 1
  end
end

function love.load()
  love.window.setTitle("Deimos - Niveau généré")
  love.graphics.setBackgroundColor(0.03, 0.03, 0.03)

  love.math.setRandomSeed(os.time())
  applyResolution()
  startNewGame()
end

function love.update(dt)
  if menu.isOpen then
    return
  end

  world.cameraRect = world:getCameraRect(player)
  turnManager:update(input, world, dt)

  if world.messageTimer > 0 then
    world.messageTimer = math.max(0, world.messageTimer - dt)
    if world.messageTimer == 0 then
      world.message = ""
    end
  end

  input:clearPressed()
end

function love.draw()
  local cam = world:getCameraRect(player)
  love.graphics.push()
  love.graphics.translate(-cam.x, -cam.y)

  drawWorld(world, cam)

  for _, pickup in ipairs(world.pickups) do
    pickup:draw()
  end

  player:draw()
  love.graphics.pop()

  local weapon = player:getEquippedWeapon()
  love.graphics.setColor(0.85, 0.85, 0.85)
  love.graphics.print(string.format("Niveau seed: %d", gameState.seed or 0), 12, 8)
  love.graphics.print("Déplacement: Flèches/WASD | Echap: menu", 12, 24)
  love.graphics.print(string.format("Arme: %s | Dégâts: %d | Portée: %d", weapon.label, weapon.damage, weapon.range), 12, 40)

  if world.message ~= "" then
    love.graphics.print(world.message, 12, 56)
  end

  if menu.isOpen then
    drawMenu()
  end
end

function love.keypressed(key)
  if key == "escape" then
    if menu.isOpen then
      closeMenu()
    else
      openMenu()
    end
    return
  end

  if menu.isOpen then
    if menu.screen == "main" then
      handleMainMenuKey(key)
    elseif menu.screen == "save" or menu.screen == "load" then
      handleSlotMenuKey(key)
    elseif menu.screen == "options" then
      handleOptionsMenuKey(key)
    end
    return
  end

  input:registerPress(key)
end

function love.keyreleased(key)
  if menu.isOpen then
    return
  end
  input:registerRelease(key)
end

function love.mousepressed(_, _, button)
  if menu.isOpen then
    return
  end

  if button == 1 then
    input:registerPress("mouse1")
  end
end

function love.mousereleased(_, _, button)
  if menu.isOpen then
    return
  end

  if button == 1 then
    input:registerRelease("mouse1")
  end
end
