-- Spirit Turret Ability
-- Spirit turrets sit along the wall and each fires its own projectile at the
-- enemy nearest to it. Turrets ignore the hero's fire position.

local ability_data_loader = require("src.models.ability_data_loader")
local targeting = require("src.entities.abilities.targeting")

local SpiritTurret = Class("SpiritTurret")

-- Hard-coded fallback defaults (used when ability_data_loader has no data)
local DEFAULT_COOLDOWN = 1.2
local DEFAULT_DAMAGE = 8
local DEFAULT_TURRET_COUNT = 1
local DEFAULT_PROJECTILE_SPEED = 900
local DEFAULT_TURRET_OFFSET = 40   -- distance in front of the wall line

-- Upgrade fallback defaults
local DEFAULT_COUNT_INCREASE = 1
local DEFAULT_MAX_TURRETS = 4
local DEFAULT_FIRE_RATE_MULTIPLIER = 1.3
local DEFAULT_MIN_COOLDOWN = 0.4
local DEFAULT_PIERCE_INCREASE = 1
local ELEMENTAL_SLOW_FACTOR = 0.7
local ELEMENTAL_SLOW_DURATION = 1
local ELEMENTAL_BURN_DPS = 4
local ELEMENTAL_BURN_DURATION = 3

-- Turret visual
local TURRET_COLOR = {0.7, 0.55, 1.0}
local TURRET_RADIUS = 12

function SpiritTurret:initialize()
  self.id = "spirit_turret"
  self.name = "Spirit Turret"

  local baseStats = ability_data_loader.getBaseStats("spirit_turret")
  self.cooldown = (baseStats and baseStats.cooldown) or DEFAULT_COOLDOWN
  self.damage = (baseStats and baseStats.damage) or DEFAULT_DAMAGE
  self.turretCount = (baseStats and baseStats.turretCount) or DEFAULT_TURRET_COUNT
  self.projectileSpeed = (baseStats and baseStats.projectileSpeed) or DEFAULT_PROJECTILE_SPEED
  self.turretOffset = (baseStats and baseStats.turretOffset) or DEFAULT_TURRET_OFFSET
  self.pierceCount = 0
  self.elementalShots = false
  self.lastActivation = 0
  self.tier = 1
  self.turretObjects = {}
end

function SpiritTurret:canActivate(currentTime, heroStats)
  self._lastCurrentTime = currentTime
  local cooldown = self.cooldown * ((heroStats and heroStats.cooldownMultiplier) or 1)
  return (currentTime - self.lastActivation) >= cooldown
end

--- Turret positions, spread evenly along the wall
-- @param wallY number The wall line
-- @return table Array of { x, y }
function SpiritTurret:getTurretPositions(wallY)
  local positions = {}
  local width = display.contentWidth or 720
  for i = 1, self.turretCount do
    positions[i] = { x = width * i / (self.turretCount + 1), y = wallY - self.turretOffset }
  end
  return positions
end

--- Keep one circle per turret at its position
local function syncTurretObjects(self, positions, displayGroup)
  if not displayGroup then
    return
  end
  for i, position in ipairs(positions) do
    local object = self.turretObjects[i]
    if not object then
      pcall(function()
        object = display.newCircle(displayGroup, position.x, position.y, TURRET_RADIUS)
        object:setFillColor(TURRET_COLOR[1], TURRET_COLOR[2], TURRET_COLOR[3])
      end)
      self.turretObjects[i] = object
    end
    if object then
      object.x, object.y = position.x, position.y
    end
  end
end

--- Draw the turrets (they appear as soon as the ability is picked)
function SpiritTurret:update(dt, originX, originY, enemies, displayGroup, heroStats)
  syncTurretObjects(self, self:getTurretPositions(originY), displayGroup)
end

--- Each turret fires one projectile at the enemy nearest to it
-- @return boolean True if any turret fired
function SpiritTurret:activate(heroX, heroY, enemies, projectilePool, displayGroup, heroStats)
  local damage = self.damage * ((heroStats and heroStats.damageMultiplier) or 1)
  local fired = false
  for _, turret in ipairs(self:getTurretPositions(heroY)) do
    local target = targeting.nearest(turret.x, turret.y, enemies)
    local projectile = target and projectilePool and projectilePool:get()
    if projectile then
      projectile:activate(turret.x, turret.y, target.x, target.y, self.projectileSpeed, damage, self.pierceCount)
      if self.elementalShots then
        projectile.slowFactor = ELEMENTAL_SLOW_FACTOR
        projectile.slowDuration = ELEMENTAL_SLOW_DURATION
        projectile.burnDps = ELEMENTAL_BURN_DPS
        projectile.burnDuration = ELEMENTAL_BURN_DURATION
      end
      fired = true
    end
  end
  if fired then
    self.lastActivation = self._lastCurrentTime or os.clock()
  end
  return fired
end

function SpiritTurret:upgrade(upgradeType)
  local params = ability_data_loader.getUpgradeParams("spirit_turret", upgradeType)

  if upgradeType == "turret_count" then
    local maxTurrets = (params and params.maxTurrets) or DEFAULT_MAX_TURRETS
    self.turretCount = math.min(self.turretCount + ((params and params.countIncrease) or DEFAULT_COUNT_INCREASE), maxTurrets)
  elseif upgradeType == "fire_rate" then
    local multiplier = (params and params.fireRateMultiplier) or DEFAULT_FIRE_RATE_MULTIPLIER
    local minCooldown = (params and params.minCooldown) or DEFAULT_MIN_COOLDOWN
    self.cooldown = math.max(self.cooldown / multiplier, minCooldown)
  elseif upgradeType == "pierce" then
    self.pierceCount = self.pierceCount + ((params and params.pierceIncrease) or DEFAULT_PIERCE_INCREASE)
  elseif upgradeType == "elemental_shots" then
    self.elementalShots = true
  else
    return
  end
  self.tier = math.min(self.tier + 1, 5)
end

--- Remove turret display objects
function SpiritTurret:destroy()
  for _, object in pairs(self.turretObjects) do
    if object and object.removeSelf then
      object:removeSelf()
    end
  end
  self.turretObjects = {}
end

return SpiritTurret
