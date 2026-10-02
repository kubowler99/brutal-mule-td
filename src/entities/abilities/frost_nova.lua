-- Frost Nova Ability
-- Area ability that pulses frost along the front of the wall
-- Damages and slows every enemy within range of the wall line

local ability_data_loader = require("src.models.ability_data_loader")
local combat_system = require("src.systems.combat_system")

local FrostNova = Class("FrostNova")

-- Hard-coded fallback defaults (used when ability_data_loader has no data)
local DEFAULT_COOLDOWN = 4.0
local DEFAULT_DAMAGE = 8
local DEFAULT_RANGE = 250
local DEFAULT_SLOW_FACTOR = 0.5
local DEFAULT_SLOW_DURATION = 2.0

-- Upgrade fallback defaults
local DEFAULT_DAMAGE_INCREASE = 4
local DEFAULT_RANGE_INCREASE = 50
local DEFAULT_COOLDOWN_REDUCTION = 0.5
local DEFAULT_MIN_COOLDOWN = 1.5
local DEFAULT_SLOW_REDUCTION = 0.1
local DEFAULT_MIN_SLOW_FACTOR = 0.2

-- Pulse visual
local PULSE_COLOR = {0.5, 0.8, 1.0, 0.35}
local PULSE_FADE_MS = 300

function FrostNova:initialize()
  -- Ability identification
  self.id = "frost_nova"
  self.name = "Frost Nova"

  -- Try to load base stats from data file, fall back to hard-coded defaults
  local baseStats = ability_data_loader.getBaseStats("frost_nova")

  self.cooldown = (baseStats and baseStats.cooldown) or DEFAULT_COOLDOWN
  self.lastActivation = 0  -- Timestamp of last activation
  self.damage = (baseStats and baseStats.damage) or DEFAULT_DAMAGE
  self.range = (baseStats and baseStats.range) or DEFAULT_RANGE
  self.slowFactor = (baseStats and baseStats.slowFactor) or DEFAULT_SLOW_FACTOR
  self.slowDuration = (baseStats and baseStats.slowDuration) or DEFAULT_SLOW_DURATION

  -- Upgrade tier (1-5)
  self.tier = 1
end

function FrostNova:canActivate(currentTime)
  -- Store currentTime so activate() can use the same time source
  self._lastCurrentTime = currentTime
  return (currentTime - self.lastActivation) >= self.cooldown
end

--- Find active enemies within range of the wall line
-- The hero sits on the wall, so heroY is the wall line.
-- @param heroY number Y position of the hero (the wall line)
-- @param enemies table Array of enemies
-- @return table Array of enemies inside the pulse
function FrostNova:findTargets(heroY, enemies)
  local targets = {}
  if not enemies then
    return targets
  end

  local minY = heroY - self.range
  for _, enemy in ipairs(enemies) do
    if enemy.isActive and type(enemy.y) == "number" and enemy.y >= minY then
      table.insert(targets, enemy)
    end
  end
  return targets
end

--- Show a short frost band in front of the wall
-- @param heroY number Y position of the wall line
-- @param displayGroup table Group to draw into (skipped when nil)
function FrostNova:showPulse(heroY, displayGroup)
  if not displayGroup then
    return
  end

  pcall(function()
    local width = display.contentWidth
    local band = display.newRect(displayGroup, width / 2, heroY - self.range / 2, width, self.range)
    band:setFillColor(PULSE_COLOR[1], PULSE_COLOR[2], PULSE_COLOR[3], PULSE_COLOR[4])
    transition.to(band, {
      time = PULSE_FADE_MS,
      alpha = 0,
      onComplete = function()
        if band.removeSelf then
          band:removeSelf()
        end
      end
    })
  end)
end

--- Pulse frost: slow then damage every enemy in range
-- Does not use the cooldown when no enemy is in range.
-- @param heroX number Hero X position (unused; the pulse spans the wall)
-- @param heroY number Hero Y position (the wall line)
-- @param enemies table Array of enemies
-- @param projectilePool table Unused (Frost Nova fires no projectiles)
-- @param displayGroup table Optional group for the pulse visual
-- @return boolean True if the nova fired
function FrostNova:activate(heroX, heroY, enemies, projectilePool, displayGroup)
  local targets = self:findTargets(heroY, enemies)
  if #targets == 0 then
    return false
  end

  self.lastActivation = self._lastCurrentTime or os.clock()

  for _, enemy in ipairs(targets) do
    -- Slow first: a killed enemy ignores the slow
    if enemy.applySlow then
      enemy:applySlow(self.slowFactor, self.slowDuration)
    end
    combat_system.applyDamage(enemy, self.damage)
  end

  self:showPulse(heroY, displayGroup)
  return true
end

function FrostNova:upgrade(upgradeType)
  -- Read upgrade params from data loader, fall back to hard-coded defaults
  local params = ability_data_loader.getUpgradeParams("frost_nova", upgradeType)

  if upgradeType == "damage_increase" then
    local increase = (params and params.damageIncrease) or DEFAULT_DAMAGE_INCREASE
    self.damage = self.damage + increase
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "range_increase" then
    local increase = (params and params.rangeIncrease) or DEFAULT_RANGE_INCREASE
    self.range = self.range + increase
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "attack_speed" then
    local reduction = (params and params.cooldownReduction) or DEFAULT_COOLDOWN_REDUCTION
    local minCooldown = (params and params.minCooldown) or DEFAULT_MIN_COOLDOWN
    self.cooldown = math.max(self.cooldown - reduction, minCooldown)
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "slow_increase" then
    local reduction = (params and params.slowReduction) or DEFAULT_SLOW_REDUCTION
    local minFactor = (params and params.minSlowFactor) or DEFAULT_MIN_SLOW_FACTOR
    self.slowFactor = math.max(self.slowFactor - reduction, minFactor)
    self.tier = math.min(self.tier + 1, 5)
  end
end

return FrostNova
