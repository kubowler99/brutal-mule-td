-- Flame Slash Ability
-- Short-range sweep from the ability's slot on the wall. Damages every enemy
-- within range and, once upgraded, sets them on fire.

local ability_data_loader = require("src.models.ability_data_loader")
local combat_system = require("src.systems.combat_system")

local FlameSlash = Class("FlameSlash")

-- Hard-coded fallback defaults (used when ability_data_loader has no data)
local DEFAULT_COOLDOWN = 1.5
local DEFAULT_DAMAGE = 14
local DEFAULT_RANGE = 220
local DEFAULT_BURN_DURATION = 3

-- Upgrade fallback defaults
local DEFAULT_DAMAGE_INCREASE = 6
local DEFAULT_RANGE_INCREASE = 40
local DEFAULT_COOLDOWN_REDUCTION = 0.2
local DEFAULT_MIN_COOLDOWN = 0.6
local DEFAULT_BURN_INCREASE = 4

-- Slash visual
local SLASH_COLOR = {1.0, 0.5, 0.15, 0.4}
local SLASH_FADE_MS = 200

function FlameSlash:initialize()
  self.id = "flame_slash"
  self.name = "Flame Slash"

  local baseStats = ability_data_loader.getBaseStats("flame_slash")

  self.cooldown = (baseStats and baseStats.cooldown) or DEFAULT_COOLDOWN
  self.lastActivation = 0
  self.damage = (baseStats and baseStats.damage) or DEFAULT_DAMAGE
  self.range = (baseStats and baseStats.range) or DEFAULT_RANGE
  -- Burn starts off and comes from upgrades
  self.burnDps = 0
  self.burnDuration = (baseStats and baseStats.burnDuration) or DEFAULT_BURN_DURATION

  self.tier = 1
end

--- Check whether the cooldown has elapsed
-- @param currentTime number Game time in seconds
-- @param heroStats table|nil Hero stats; cooldownMultiplier scales the cooldown
function FlameSlash:canActivate(currentTime, heroStats)
  self._lastCurrentTime = currentTime
  local cooldown = self.cooldown * ((heroStats and heroStats.cooldownMultiplier) or 1)
  return (currentTime - self.lastActivation) >= cooldown
end

--- Active enemies within range of the slash origin
-- @param originX number Slot X on the wall
-- @param originY number Slot Y on the wall
-- @param enemies table Array of enemies
-- @return table Array of enemies in range
function FlameSlash:findTargets(originX, originY, enemies)
  local targets = {}
  local rangeSq = self.range * self.range
  for _, enemy in ipairs(enemies or {}) do
    if enemy.isActive then
      local dx = enemy.x - originX
      local dy = enemy.y - originY
      if dx * dx + dy * dy <= rangeSq then
        table.insert(targets, enemy)
      end
    end
  end
  return targets
end

--- Draw a short-lived arc showing the slash range
local function showSlash(self, originX, originY, displayGroup)
  if not displayGroup then
    return
  end
  pcall(function()
    local arc = display.newCircle(displayGroup, originX, originY, self.range)
    arc:setFillColor(SLASH_COLOR[1], SLASH_COLOR[2], SLASH_COLOR[3], SLASH_COLOR[4])
    transition.to(arc, {
      time = SLASH_FADE_MS,
      alpha = 0,
      onComplete = function()
        if arc.removeSelf then
          arc:removeSelf()
        end
      end
    })
  end)
end

--- Slash every enemy in range; does not use the cooldown when none is in range
-- @param heroStats table|nil Hero stats; damageMultiplier scales damage
-- @return boolean True if the slash happened
function FlameSlash:activate(originX, originY, enemies, projectilePool, displayGroup, heroStats)
  local targets = self:findTargets(originX, originY, enemies)
  if #targets == 0 then
    return false
  end

  self.lastActivation = self._lastCurrentTime or os.clock()

  local damage = self.damage * ((heroStats and heroStats.damageMultiplier) or 1)
  for _, enemy in ipairs(targets) do
    combat_system.applyDamage(enemy, damage)
    if self.burnDps > 0 and enemy.isActive and enemy.applyBurn then
      enemy:applyBurn(self.burnDps, self.burnDuration)
    end
  end

  showSlash(self, originX, originY, displayGroup)
  return true
end

function FlameSlash:upgrade(upgradeType)
  local params = ability_data_loader.getUpgradeParams("flame_slash", upgradeType)

  if upgradeType == "damage_increase" then
    self.damage = self.damage + ((params and params.damageIncrease) or DEFAULT_DAMAGE_INCREASE)
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "range_increase" then
    self.range = self.range + ((params and params.rangeIncrease) or DEFAULT_RANGE_INCREASE)
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "attack_speed" then
    local reduction = (params and params.cooldownReduction) or DEFAULT_COOLDOWN_REDUCTION
    local minCooldown = (params and params.minCooldown) or DEFAULT_MIN_COOLDOWN
    self.cooldown = math.max(self.cooldown - reduction, minCooldown)
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "burn" then
    self.burnDps = self.burnDps + ((params and params.burnIncrease) or DEFAULT_BURN_INCREASE)
    self.tier = math.min(self.tier + 1, 5)
  end
end

return FlameSlash
