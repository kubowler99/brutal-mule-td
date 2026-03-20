-- Arcane Bolt Ability
-- The hero's default automatic projectile attack ability
-- Fires toward the nearest enemy with configurable damage, cooldown, and upgrades

local ability_data_loader = require("src.models.ability_data_loader")

local ArcaneBolt = Class("ArcaneBolt")

-- Hard-coded fallback defaults (used when ability_data_loader has no data)
local DEFAULT_COOLDOWN = 1.0
local DEFAULT_DAMAGE = 10
local DEFAULT_PROJECTILE_SPEED = 400
local DEFAULT_PIERCE_COUNT = 0
local DEFAULT_PROJECTILE_COUNT = 1

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

function ArcaneBolt:canActivate(currentTime)
  -- Store currentTime so activate() can use the same time source
  self._lastCurrentTime = currentTime
  -- Check if enough time has passed since last activation
  return (currentTime - self.lastActivation) >= self.cooldown
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

function ArcaneBolt:activate(heroX, heroY, enemies, projectilePool)
  -- Find the nearest enemy
  local target = self:findNearestEnemy(heroX, heroY, enemies)

  -- If no target, don't activate
  if not target then
    return false
  end

  -- Update last activation time using the same time source as canActivate
  -- (currentTime from game loop is passed via the combat system)
  self.lastActivation = self._lastCurrentTime or os.clock()

  -- Predictive targeting: aim where the enemy will be, not where it is now
  local targetX = target.x
  local targetY = target.y

  -- Walkers move straight down at target.speed pixels/sec (vx=0, vy=speed)
  local enemyVX = 0
  local enemyVY = target.speed or 0

  -- Only predict if the enemy is actually moving
  if enemyVY > 0 then
    -- Estimate time for projectile to reach the target's current position
    local dx = targetX - heroX
    local dy = targetY - heroY
    local dist = math.sqrt(dx * dx + dy * dy)
    local timeToHit = dist / self.projectileSpeed

    -- Lead the shot: aim at predicted future position
    targetX = targetX + enemyVX * timeToHit
    targetY = targetY + enemyVY * timeToHit
  end

  -- Create projectiles based on projectileCount
  for _ = 1, self.projectileCount do
    local projectile = projectilePool:get()

    if projectile then
      -- Activate the projectile toward the predicted position
      projectile:activate(
        heroX,
        heroY,
        targetX,
        targetY,
        self.projectileSpeed,
        self.damage,
        self.pierceCount
      )
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

  -- Apply tier-based bonuses from data loader
  local tierParams = ability_data_loader.getTierParams("arcane_bolt", self.tier)
  if tierParams then
    if tierParams.damageBonus then
      self.damage = self.damage + tierParams.damageBonus
    end
    if tierParams.cooldownReduction then
      self.cooldown = math.max(self.cooldown - tierParams.cooldownReduction, DEFAULT_MIN_COOLDOWN)
    end
    if tierParams.projectileCountBonus then
      self.projectileCount = self.projectileCount + tierParams.projectileCountBonus
    end
    if tierParams.pierceBonus then
      self.pierceCount = self.pierceCount + tierParams.pierceBonus
    end
  end
end

return ArcaneBolt
