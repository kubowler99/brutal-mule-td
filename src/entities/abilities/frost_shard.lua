-- Frost Shard Ability
-- Piercing projectile fired at the nearest enemy that slows what it hits.
-- Reuses Arcane Bolt's targeting and firing; adds an on-hit slow.

local ability_data_loader = require("src.models.ability_data_loader")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")

local FrostShard = ArcaneBolt:subclass("FrostShard")

-- Hard-coded fallback defaults (used when ability_data_loader has no data)
local DEFAULT_COOLDOWN = 1.2
local DEFAULT_DAMAGE = 7
local DEFAULT_PROJECTILE_SPEED = 900
local DEFAULT_PIERCE_COUNT = 1
local DEFAULT_PROJECTILE_COUNT = 1
local DEFAULT_SLOW_FACTOR = 0.7
local DEFAULT_SLOW_DURATION = 1.5
local DEFAULT_FREEZE_DURATION = 0.8

-- Upgrade fallback defaults
local DEFAULT_DAMAGE_INCREASE = 4
local DEFAULT_COUNT_INCREASE = 1
local DEFAULT_PIERCE_INCREASE = 1
local DEFAULT_SLOW_REDUCTION = 0.1
local DEFAULT_MIN_SLOW_FACTOR = 0.3
local DEFAULT_RICOCHET_INCREASE = 1
local DEFAULT_MAX_RICOCHETS = 3
local DEFAULT_FREEZE_CHANCE_INCREASE = 0.15
local DEFAULT_MAX_FREEZE_CHANCE = 0.6

function FrostShard:initialize()
  self.id = "frost_shard"
  self.name = "Frost Shard"

  local baseStats = ability_data_loader.getBaseStats("frost_shard")

  self.cooldown = (baseStats and baseStats.cooldown) or DEFAULT_COOLDOWN
  self.lastActivation = 0
  self.damage = (baseStats and baseStats.damage) or DEFAULT_DAMAGE
  self.projectileSpeed = (baseStats and baseStats.projectileSpeed) or DEFAULT_PROJECTILE_SPEED
  self.pierceCount = (baseStats and baseStats.pierceCount) or DEFAULT_PIERCE_COUNT
  self.projectileCount = (baseStats and baseStats.projectileCount) or DEFAULT_PROJECTILE_COUNT
  self.slowFactor = (baseStats and baseStats.slowFactor) or DEFAULT_SLOW_FACTOR
  self.slowDuration = (baseStats and baseStats.slowDuration) or DEFAULT_SLOW_DURATION
  -- Ricochet and freeze start at zero and come from upgrades
  self.ricochets = 0
  self.freezeChance = 0
  self.freezeDuration = (baseStats and baseStats.freezeDuration) or DEFAULT_FREEZE_DURATION

  self.tier = 1
end

-- Angle between neighboring shards in a fan (radians, about 12 degrees)
local FAN_ANGLE = math.rad(12)

--- Aim points for one volley: a fan centered on the nearest enemy
-- One shard flies straight at the target; extra shards spread evenly to
-- either side, so a volley sweeps several lanes.
-- @return table Array of { x, y } (empty when there is no target)
function FrostShard:getAimPoints(heroX, heroY, enemies, heroStats)
  local target = self:findNearestEnemies(heroX, heroY, enemies, 1)[1]
  if not target then
    return {}
  end

  local centerX, centerY = self:predictAim(heroX, heroY, target)
  local dx = centerX - heroX
  local dy = centerY - heroY
  local distance = math.sqrt(dx * dx + dy * dy)
  local baseAngle = math.atan2(dy, dx)

  local count = self:getVolleyCount(heroStats)
  local aims = {}
  for i = 1, count do
    local angle = baseAngle + (i - (count + 1) / 2) * FAN_ANGLE
    aims[i] = {
      x = heroX + math.cos(angle) * distance,
      y = heroY + math.sin(angle) * distance,
    }
  end
  return aims
end

--- Fire like Arcane Bolt, then give each shard the on-hit slow, ricochets,
--- and freeze chance
function FrostShard:activate(heroX, heroY, enemies, projectilePool, displayGroup, heroStats)
  local fired = {}
  local capturingPool = {
    get = function(_, ...)
      local projectile = projectilePool:get(...)
      if projectile then
        table.insert(fired, projectile)
      end
      return projectile
    end,
    release = function(_, obj)
      return projectilePool:release(obj)
    end,
  }

  local activated = ArcaneBolt.activate(self, heroX, heroY, enemies, capturingPool, displayGroup, heroStats)

  for _, projectile in ipairs(fired) do
    if projectile.setVisual then
      projectile:setVisual("frost_shard")
    end
    projectile.slowFactor = self.slowFactor
    projectile.slowDuration = self.slowDuration
    projectile.ricochetsLeft = self.ricochets
    if self.freezeChance > 0 then
      projectile.freezeChance = self.freezeChance
      projectile.freezeDuration = self.freezeDuration
    end
  end

  return activated
end

function FrostShard:upgrade(upgradeType)
  local params = ability_data_loader.getUpgradeParams("frost_shard", upgradeType)

  if upgradeType == "damage_increase" then
    self.damage = self.damage + ((params and params.damageIncrease) or DEFAULT_DAMAGE_INCREASE)
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "shard_count" then
    self.projectileCount = self.projectileCount + ((params and params.countIncrease) or DEFAULT_COUNT_INCREASE)
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "pierce" then
    self.pierceCount = self.pierceCount + ((params and params.pierceIncrease) or DEFAULT_PIERCE_INCREASE)
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "slow_increase" then
    local reduction = (params and params.slowReduction) or DEFAULT_SLOW_REDUCTION
    local minFactor = (params and params.minSlowFactor) or DEFAULT_MIN_SLOW_FACTOR
    self.slowFactor = math.max(self.slowFactor - reduction, minFactor)
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "ricochet" then
    local increase = (params and params.ricochetIncrease) or DEFAULT_RICOCHET_INCREASE
    local maxRicochets = (params and params.maxRicochets) or DEFAULT_MAX_RICOCHETS
    self.ricochets = math.min(self.ricochets + increase, maxRicochets)
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "freeze_chance" then
    local increase = (params and params.chanceIncrease) or DEFAULT_FREEZE_CHANCE_INCREASE
    local maxChance = (params and params.maxChance) or DEFAULT_MAX_FREEZE_CHANCE
    self.freezeChance = math.min(self.freezeChance + increase, maxChance)
    self.tier = math.min(self.tier + 1, 5)
  end
end

return FrostShard
