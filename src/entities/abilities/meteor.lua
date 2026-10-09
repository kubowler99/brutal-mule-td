-- Meteor Ability
-- Marks the densest group of enemies, then a meteor lands there after a short
-- delay, damaging and burning everything in its radius. Pending impacts are
-- resolved in update().

local ability_data_loader = require("src.models.ability_data_loader")
local combat_system = require("src.systems.combat_system")
local targeting = require("src.entities.abilities.targeting")

local Meteor = Class("Meteor")

-- Hard-coded fallback defaults (used when ability_data_loader has no data)
local DEFAULT_COOLDOWN = 4.0
local DEFAULT_DAMAGE = 40
local DEFAULT_RADIUS = 90
local DEFAULT_DELAY = 1.2
local DEFAULT_BURN_DPS = 6
local DEFAULT_BURN_DURATION = 2

-- Upgrade fallback defaults
local DEFAULT_RADIUS_MULTIPLIER = 1.25
local DEFAULT_COOLDOWN_REDUCTION = 1.0
local DEFAULT_MIN_COOLDOWN = 1.5
local DEFAULT_BURN_DURATION_MULTIPLIER = 2

-- The second meteor (top upgrade) is smaller
local SECOND_METEOR_RADIUS = 0.7
local SECOND_METEOR_DAMAGE = 0.6

-- Marker visual
local MARKER_COLOR = {1.0, 0.35, 0.15, 0.35}
local BLAST_COLOR = {1.0, 0.55, 0.2, 0.6}
local BLAST_FADE_MS = 250

function Meteor:initialize()
  self.id = "meteor"
  self.name = "Meteor"

  local baseStats = ability_data_loader.getBaseStats("meteor")
  self.cooldown = (baseStats and baseStats.cooldown) or DEFAULT_COOLDOWN
  self.damage = (baseStats and baseStats.damage) or DEFAULT_DAMAGE
  self.radius = (baseStats and baseStats.radius) or DEFAULT_RADIUS
  self.delay = (baseStats and baseStats.delay) or DEFAULT_DELAY
  self.burnDps = (baseStats and baseStats.burnDps) or DEFAULT_BURN_DPS
  self.burnDuration = (baseStats and baseStats.burnDuration) or DEFAULT_BURN_DURATION
  self.secondMeteor = false
  self.lastActivation = 0
  self.tier = 1

  -- Meteors on their way down: { x, y, radius, damage, timer, marker }
  self.impacts = {}
end

function Meteor:canActivate(currentTime, heroStats)
  self._lastCurrentTime = currentTime
  local cooldown = self.cooldown * ((heroStats and heroStats.cooldownMultiplier) or 1)
  return (currentTime - self.lastActivation) >= cooldown
end

--- Queue an impact and draw its target marker
function Meteor:queueImpact(x, y, radius, damage, displayGroup)
  local impact = { x = x, y = y, radius = radius, damage = damage, timer = self.delay }
  if displayGroup then
    pcall(function()
      impact.marker = display.newCircle(displayGroup, x, y, radius)
      impact.marker:setFillColor(MARKER_COLOR[1], MARKER_COLOR[2], MARKER_COLOR[3], MARKER_COLOR[4])
    end)
  end
  table.insert(self.impacts, impact)
end

--- Mark the densest group (and a second one with the top upgrade)
-- @return boolean True if a meteor was called down
function Meteor:activate(heroX, heroY, enemies, projectilePool, displayGroup, heroStats)
  local target = targeting.densest(enemies, self.radius)
  if not target then
    return false
  end

  self.lastActivation = self._lastCurrentTime or os.clock()
  local damage = self.damage * ((heroStats and heroStats.damageMultiplier) or 1)
  self:queueImpact(target.x, target.y, self.radius, damage, displayGroup)

  if self.secondMeteor then
    local firstX, firstY, firstRadius = target.x, target.y, self.radius
    local second = targeting.densest(enemies, self.radius * SECOND_METEOR_RADIUS, function(enemy)
      local dx, dy = enemy.x - firstX, enemy.y - firstY
      return dx * dx + dy * dy > firstRadius * firstRadius
    end)
    if second then
      self:queueImpact(second.x, second.y, self.radius * SECOND_METEOR_RADIUS,
        damage * SECOND_METEOR_DAMAGE, displayGroup)
    end
  end
  return true
end

--- Land meteors whose delay has passed
function Meteor:update(dt, originX, originY, enemies, displayGroup, heroStats)
  for i = #self.impacts, 1, -1 do
    local impact = self.impacts[i]
    impact.timer = impact.timer - dt
    if impact.timer <= 0 then
      for _, enemy in ipairs(targeting.within(impact.x, impact.y, impact.radius, enemies)) do
        local killed = combat_system.applyDamage(enemy, impact.damage)
        if not killed and enemy.isActive and enemy.applyBurn then
          enemy:applyBurn(self.burnDps, self.burnDuration)
        end
      end
      if impact.marker then
        local marker = impact.marker
        pcall(function()
          marker:setFillColor(BLAST_COLOR[1], BLAST_COLOR[2], BLAST_COLOR[3], BLAST_COLOR[4])
          transition.to(marker, {
            time = BLAST_FADE_MS, alpha = 0,
            onComplete = function() if marker.removeSelf then marker:removeSelf() end end
          })
        end)
      end
      table.remove(self.impacts, i)
    end
  end
end

function Meteor:upgrade(upgradeType)
  local params = ability_data_loader.getUpgradeParams("meteor", upgradeType)

  if upgradeType == "radius_increase" then
    self.radius = self.radius * ((params and params.radiusMultiplier) or DEFAULT_RADIUS_MULTIPLIER)
  elseif upgradeType == "attack_speed" then
    local reduction = (params and params.cooldownReduction) or DEFAULT_COOLDOWN_REDUCTION
    local minCooldown = (params and params.minCooldown) or DEFAULT_MIN_COOLDOWN
    self.cooldown = math.max(self.cooldown - reduction, minCooldown)
  elseif upgradeType == "burn_duration" then
    self.burnDuration = self.burnDuration * ((params and params.burnDurationMultiplier) or DEFAULT_BURN_DURATION_MULTIPLIER)
  elseif upgradeType == "second_meteor" then
    self.secondMeteor = true
  else
    return
  end
  self.tier = math.min(self.tier + 1, 5)
end

--- Remove pending markers
function Meteor:destroy()
  for _, impact in ipairs(self.impacts) do
    if impact.marker and impact.marker.removeSelf then
      impact.marker:removeSelf()
    end
  end
  self.impacts = {}
end

return Meteor
