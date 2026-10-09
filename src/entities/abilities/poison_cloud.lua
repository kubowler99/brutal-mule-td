-- Poison Cloud Ability
-- Drops a lingering cloud on the densest group of enemies near the wall.
-- The cloud poisons every enemy inside it in ticks. Clouds are updated in
-- update().

local ability_data_loader = require("src.models.ability_data_loader")
local combat_system = require("src.systems.combat_system")
local targeting = require("src.entities.abilities.targeting")

local PoisonCloud = Class("PoisonCloud")

-- Hard-coded fallback defaults (used when ability_data_loader has no data)
local DEFAULT_COOLDOWN = 5.0
local DEFAULT_DAMAGE_PER_SECOND = 6
local DEFAULT_RADIUS = 80
local DEFAULT_DURATION = 4
local DEFAULT_RANGE = 350          -- only targets enemies this close to the wall
local DEFAULT_TICK_INTERVAL = 0.5

-- Upgrade fallback defaults
local DEFAULT_DURATION_MULTIPLIER = 1.5
local DEFAULT_STACK_INCREASE = 1
local DEFAULT_VULNERABILITY = 0.1
local BURST_RADIUS = 0.6           -- burst clouds are smaller...
local BURST_DURATION = 2           -- ...and shorter

-- Cloud visual
local CLOUD_COLOR = {0.35, 0.85, 0.3, 0.3}

function PoisonCloud:initialize()
  self.id = "poison_cloud"
  self.name = "Poison Cloud"

  local baseStats = ability_data_loader.getBaseStats("poison_cloud")
  self.cooldown = (baseStats and baseStats.cooldown) or DEFAULT_COOLDOWN
  self.damagePerSecond = (baseStats and baseStats.damagePerSecond) or DEFAULT_DAMAGE_PER_SECOND
  self.radius = (baseStats and baseStats.radius) or DEFAULT_RADIUS
  self.duration = (baseStats and baseStats.duration) or DEFAULT_DURATION
  self.range = (baseStats and baseStats.range) or DEFAULT_RANGE
  self.tickInterval = (baseStats and baseStats.tickInterval) or DEFAULT_TICK_INTERVAL
  self.stacksPerTick = 1
  self.vulnerability = 0
  self.burstOnDeath = false
  self.lastActivation = 0
  self.tier = 1

  -- Active clouds: { x, y, radius, remaining, tickTimer, damagePerSecond, object }
  self.clouds = {}
end

function PoisonCloud:canActivate(currentTime, heroStats)
  self._lastCurrentTime = currentTime
  local cooldown = self.cooldown * ((heroStats and heroStats.cooldownMultiplier) or 1)
  return (currentTime - self.lastActivation) >= cooldown
end

--- Add a cloud and draw it
function PoisonCloud:addCloud(x, y, radius, duration, damagePerSecond, displayGroup)
  local cloud = { x = x, y = y, radius = radius, remaining = duration, tickTimer = 0,
    damagePerSecond = damagePerSecond }
  if displayGroup then
    pcall(function()
      cloud.object = display.newCircle(displayGroup, x, y, radius)
      cloud.object:setFillColor(CLOUD_COLOR[1], CLOUD_COLOR[2], CLOUD_COLOR[3], CLOUD_COLOR[4])
    end)
  end
  table.insert(self.clouds, cloud)
  return cloud
end

--- Drop a cloud on the densest group within range of the wall
-- @param heroY number The wall line
-- @return boolean True if a cloud was dropped
function PoisonCloud:activate(heroX, heroY, enemies, projectilePool, displayGroup, heroStats)
  local minY = heroY - self.range
  local target = targeting.densest(enemies, self.radius, function(enemy)
    return enemy.y >= minY
  end)
  if not target then
    return false
  end

  self.lastActivation = self._lastCurrentTime or os.clock()
  local damagePerSecond = self.damagePerSecond * ((heroStats and heroStats.damageMultiplier) or 1)
  self:addCloud(target.x, target.y, self.radius, self.duration, damagePerSecond, displayGroup)
  self._displayGroup = displayGroup
  return true
end

--- Poison enemies inside clouds and let clouds expire
function PoisonCloud:update(dt, originX, originY, enemies, displayGroup, heroStats)
  for i = #self.clouds, 1, -1 do
    local cloud = self.clouds[i]
    cloud.remaining = cloud.remaining - dt
    cloud.tickTimer = cloud.tickTimer + dt
    while cloud.tickTimer >= self.tickInterval do
      cloud.tickTimer = cloud.tickTimer - self.tickInterval
      local tickDamage = cloud.damagePerSecond * self.tickInterval * self.stacksPerTick
      for _, enemy in ipairs(targeting.within(cloud.x, cloud.y, cloud.radius, enemies)) do
        -- Poisoned enemies take more damage from everything (upgrade)
        if self.vulnerability > 0 then
          enemy.vulnerableBonus = self.vulnerability
          enemy.vulnerableRemaining = self.tickInterval * 1.5
        end
        local x, y = enemy.x, enemy.y
        local killed = combat_system.applyDamage(enemy, tickDamage)
        -- Enemies that die while poisoned burst into a small cloud (upgrade)
        if killed and self.burstOnDeath then
          self:addCloud(x, y, self.radius * BURST_RADIUS, BURST_DURATION, cloud.damagePerSecond,
            displayGroup or self._displayGroup)
        end
      end
    end
    if cloud.remaining <= 0 then
      if cloud.object and cloud.object.removeSelf then
        cloud.object:removeSelf()
      end
      table.remove(self.clouds, i)
    end
  end
end

function PoisonCloud:upgrade(upgradeType)
  local params = ability_data_loader.getUpgradeParams("poison_cloud", upgradeType)

  if upgradeType == "duration_increase" then
    self.duration = self.duration * ((params and params.durationMultiplier) or DEFAULT_DURATION_MULTIPLIER)
  elseif upgradeType == "stack_increase" then
    self.stacksPerTick = self.stacksPerTick + ((params and params.stackIncrease) or DEFAULT_STACK_INCREASE)
  elseif upgradeType == "vulnerability" then
    self.vulnerability = (params and params.damageTakenIncrease) or DEFAULT_VULNERABILITY
  elseif upgradeType == "burst" then
    self.burstOnDeath = true
  else
    return
  end
  self.tier = math.min(self.tier + 1, 5)
end

--- Remove cloud display objects
function PoisonCloud:destroy()
  for _, cloud in ipairs(self.clouds) do
    if cloud.object and cloud.object.removeSelf then
      cloud.object:removeSelf()
    end
  end
  self.clouds = {}
end

return PoisonCloud
