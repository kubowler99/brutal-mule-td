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

-- Upgrade fallback defaults
local DEFAULT_DAMAGE_INCREASE = 4
local DEFAULT_COUNT_INCREASE = 1
local DEFAULT_PIERCE_INCREASE = 1
local DEFAULT_SLOW_REDUCTION = 0.1
local DEFAULT_MIN_SLOW_FACTOR = 0.3

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

  self.tier = 1
end

--- Fire like Arcane Bolt, then give each shard the on-hit slow
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
    projectile.slowFactor = self.slowFactor
    projectile.slowDuration = self.slowDuration
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
  end
end

return FrostShard
