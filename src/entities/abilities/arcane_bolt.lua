-- Arcane Bolt Ability
-- The hero's default automatic projectile attack ability
-- Fires toward the nearest enemy with configurable damage, cooldown, and upgrades

local ability_data_loader = require("src.models.ability_data_loader")
local config_loader = require("src.models.config_loader")

local ArcaneBolt = Class("ArcaneBolt")

-- Hard-coded fallback defaults (used when ability_data_loader has no data)
local DEFAULT_COOLDOWN = 1.0
local DEFAULT_DAMAGE = 10
local DEFAULT_PROJECTILE_SPEED = 400
local DEFAULT_PIERCE_COUNT = 0
local DEFAULT_PROJECTILE_COUNT = 1

-- Each projectile past the first cuts per-projectile damage by this fraction
-- (multiplicative: 2 projectiles deal 80% each, 3 deal 64% each)
local DEFAULT_EXTRA_PROJECTILE_PENALTY = 0.2

-- Upgrade fallback defaults
local DEFAULT_DAMAGE_INCREASE = 5
local DEFAULT_COOLDOWN_REDUCTION = 0.15
local DEFAULT_MIN_COOLDOWN = 0.25
local DEFAULT_COUNT_INCREASE = 1
local DEFAULT_PIERCE_INCREASE = 1

function ArcaneBolt:initialize()
  -- Ability identification
  self.id = "arcane_bolt"
  self.name = "Arcane Bolt"

  -- Try to load base stats from data file, fall back to hard-coded defaults
  local baseStats = ability_data_loader.getBaseStats("arcane_bolt")

  -- Base stats
  self.cooldown = (baseStats and baseStats.cooldown) or DEFAULT_COOLDOWN
  self.lastActivation = 0  -- Timestamp of last activation
  self.damage = (baseStats and baseStats.damage) or DEFAULT_DAMAGE
  self.projectileSpeed = (baseStats and baseStats.projectileSpeed) or DEFAULT_PROJECTILE_SPEED

  -- Upgrade properties
  self.tier = 1  -- Current upgrade tier (1-5)
  self.pierceCount = (baseStats and baseStats.pierceCount) or DEFAULT_PIERCE_COUNT
  self.projectileCount = (baseStats and baseStats.projectileCount) or DEFAULT_PROJECTILE_COUNT
end

--- Check whether the cooldown has elapsed
-- @param currentTime number Game time in seconds
-- @param heroStats table|nil Hero stats; cooldownMultiplier scales the cooldown
function ArcaneBolt:canActivate(currentTime, heroStats)
  -- Store currentTime so activate() can use the same time source
  self._lastCurrentTime = currentTime
  local cooldown = self.cooldown * ((heroStats and heroStats.cooldownMultiplier) or 1)
  -- Check if enough time has passed since last activation
  return (currentTime - self.lastActivation) >= cooldown
end

function ArcaneBolt:findNearestEnemy(heroX, heroY, enemies)
  if not enemies or #enemies == 0 then
    return nil
  end

  local nearestEnemy = nil
  local minDistance = math.huge

  for _, enemy in ipairs(enemies) do
    if enemy.isActive then
      -- Calculate distance to this enemy
      local dx = enemy.x - heroX
      local dy = enemy.y - heroY
      local distance = math.sqrt(dx * dx + dy * dy)

      -- Update nearest if this is closer
      if distance < minDistance then
        minDistance = distance
        nearestEnemy = enemy
      end
    end
  end

  return nearestEnemy
end

--- Where to aim at an enemy so a projectile from (fromX, fromY) meets it
-- Enemies move straight down; lead the shot by the enemy's current speed
-- (slowed, frozen, or charging enemies move at a different speed).
-- @param fromX number Firing position X
-- @param fromY number Firing position Y
-- @param enemy table Target enemy
-- @return number, number Aim point
function ArcaneBolt:predictAim(fromX, fromY, enemy)
  local speed = enemy.getCurrentSpeed and enemy:getCurrentSpeed() or enemy.speed or 0
  if speed <= 0 then
    return enemy.x, enemy.y
  end

  local dx = enemy.x - fromX
  local dy = enemy.y - fromY
  local timeToHit = math.sqrt(dx * dx + dy * dy) / self.projectileSpeed
  return enemy.x, enemy.y + speed * timeToHit
end

--- Active enemies sorted nearest first, up to a limit
-- @param heroX number Firing position X
-- @param heroY number Firing position Y
-- @param enemies table Array of enemies
-- @param limit number Maximum number to return
-- @return table Array of enemies
function ArcaneBolt:findNearestEnemies(heroX, heroY, enemies, limit)
  local candidates = {}
  for _, enemy in ipairs(enemies or {}) do
    if enemy.isActive then
      local dx = enemy.x - heroX
      local dy = enemy.y - heroY
      table.insert(candidates, { enemy = enemy, distSq = dx * dx + dy * dy })
    end
  end
  table.sort(candidates, function(a, b) return a.distSq < b.distSq end)

  local nearest = {}
  for i = 1, math.min(limit, #candidates) do
    nearest[i] = candidates[i].enemy
  end
  return nearest
end

--- Aim points for one volley, one per projectile
-- Arcane Bolt sends each projectile at a different enemy, nearest first.
-- With fewer enemies than projectiles, the extras go around the list again.
-- @return table Array of { x, y } (empty when there is no target)
function ArcaneBolt:getAimPoints(heroX, heroY, enemies, heroStats)
  local count = self:getVolleyCount(heroStats)
  local targets = self:findNearestEnemies(heroX, heroY, enemies, count)
  local aims = {}
  if #targets == 0 then
    return aims
  end
  for i = 1, count do
    local target = targets[((i - 1) % #targets) + 1]
    local x, y = self:predictAim(heroX, heroY, target)
    aims[i] = { x = x, y = y }
  end
  return aims
end

--- Damage of each projectile in a volley
-- More projectiles per volley means less damage each, so count upgrades add
-- coverage with diminishing total damage (see projectiles.extraProjectilePenalty).
-- @param heroStats table|nil Hero stats; damageMultiplier scales damage
-- @return number Damage per projectile
function ArcaneBolt:getProjectileDamage(heroStats)
  local penalty = config_loader.get("projectiles.extraProjectilePenalty", DEFAULT_EXTRA_PROJECTILE_PENALTY)
  if type(penalty) ~= "number" or penalty < 0 or penalty >= 1 then
    penalty = DEFAULT_EXTRA_PROJECTILE_PENALTY
  end
  -- Split Shot lowers the penalty as it levels up
  penalty = math.max(0, penalty - ((heroStats and heroStats.extraProjectilePenaltyReduction) or 0))
  local countFactor = (1 - penalty) ^ math.max(0, self:getVolleyCount(heroStats) - 1)
  return self.damage * ((heroStats and heroStats.damageMultiplier) or 1) * countFactor
end

--- Projectiles per volley: the ability's count plus extras from cards
-- @param heroStats table|nil Hero stats; extraProjectiles adds projectiles
function ArcaneBolt:getVolleyCount(heroStats)
  return self.projectileCount + math.floor((heroStats and heroStats.extraProjectiles) or 0)
end

--- Fire one volley
-- @param heroStats table|nil Hero stats; damageMultiplier scales projectile damage
function ArcaneBolt:activate(heroX, heroY, enemies, projectilePool, displayGroup, heroStats)
  local aims = self:getAimPoints(heroX, heroY, enemies, heroStats)

  -- If no target, don't activate
  if #aims == 0 then
    return false
  end

  -- Update last activation time using the same time source as canActivate
  -- (currentTime from game loop is passed via the combat system)
  self.lastActivation = self._lastCurrentTime or os.clock()

  local damage = self:getProjectileDamage(heroStats)
  for _, aim in ipairs(aims) do
    local projectile = projectilePool:get()
    if projectile then
      projectile:activate(heroX, heroY, aim.x, aim.y, self.projectileSpeed, damage, self.pierceCount)
    end
  end

  return true
end

function ArcaneBolt:upgrade(upgradeType)
  -- Read upgrade params from data loader, fall back to hard-coded defaults
  local params = ability_data_loader.getUpgradeParams("arcane_bolt", upgradeType)

  if upgradeType == "damage_increase" then
    local increase = (params and params.damageIncrease) or DEFAULT_DAMAGE_INCREASE
    self.damage = self.damage + increase
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "attack_speed" then
    local reduction = (params and params.cooldownReduction) or DEFAULT_COOLDOWN_REDUCTION
    local minCooldown = (params and params.minCooldown) or DEFAULT_MIN_COOLDOWN
    self.cooldown = math.max(self.cooldown - reduction, minCooldown)
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "projectile_count" then
    local increase = (params and params.countIncrease) or DEFAULT_COUNT_INCREASE
    self.projectileCount = self.projectileCount + increase
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "pierce" then
    local increase = (params and params.pierceIncrease) or DEFAULT_PIERCE_INCREASE
    self.pierceCount = self.pierceCount + increase
    self.tier = math.min(self.tier + 1, 5)
  end

  -- Tier only tracks how many upgrades were taken. An upgrade applies exactly
  -- the effect its card describes; tier bonuses are not stacked on top.
end

return ArcaneBolt
