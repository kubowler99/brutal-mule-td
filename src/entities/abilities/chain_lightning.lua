-- Chain Lightning Ability
-- Strikes the enemy nearest the hero, then jumps to nearby enemies it has
-- not hit yet. Each jump deals less damage unless the falloff upgrade removes
-- the loss.

local ability_data_loader = require("src.models.ability_data_loader")
local combat_system = require("src.systems.combat_system")
local targeting = require("src.entities.abilities.targeting")

local ChainLightning = Class("ChainLightning")

-- Hard-coded fallback defaults (used when ability_data_loader has no data)
local DEFAULT_COOLDOWN = 1.6
local DEFAULT_DAMAGE = 18
local DEFAULT_JUMPS = 2
local DEFAULT_JUMP_RANGE = 180
local DEFAULT_FALLOFF = 0.7
local DEFAULT_STUN_DURATION = 0.5

-- Upgrade fallback defaults
local DEFAULT_JUMP_INCREASE = 1
local DEFAULT_DAMAGE_MULTIPLIER = 1.2
local DEFAULT_STUN_CHANCE = 0.2

-- Bolt visual
local BOLT_COLOR = {0.7, 0.6, 1.0}
local BOLT_WIDTH = 4
local BOLT_FADE_MS = 200

function ChainLightning:initialize()
  self.id = "chain_lightning"
  self.name = "Chain Lightning"

  local baseStats = ability_data_loader.getBaseStats("chain_lightning")
  self.cooldown = (baseStats and baseStats.cooldown) or DEFAULT_COOLDOWN
  self.damage = (baseStats and baseStats.damage) or DEFAULT_DAMAGE
  self.jumps = (baseStats and baseStats.jumps) or DEFAULT_JUMPS
  self.jumpRange = (baseStats and baseStats.jumpRange) or DEFAULT_JUMP_RANGE
  self.falloff = (baseStats and baseStats.falloff) or DEFAULT_FALLOFF
  self.stunChance = 0
  self.stunDuration = (baseStats and baseStats.stunDuration) or DEFAULT_STUN_DURATION
  self.lastActivation = 0
  self.tier = 1
end

--- Check whether the cooldown has elapsed
-- @param heroStats table|nil Hero stats; cooldownMultiplier scales the cooldown
function ChainLightning:canActivate(currentTime, heroStats)
  self._lastCurrentTime = currentTime
  local cooldown = self.cooldown * ((heroStats and heroStats.cooldownMultiplier) or 1)
  return (currentTime - self.lastActivation) >= cooldown
end

--- Draw a short-lived bolt between two points
local function drawBolt(displayGroup, x1, y1, x2, y2)
  if not displayGroup then
    return
  end
  pcall(function()
    local bolt = display.newLine(displayGroup, x1, y1, x2, y2)
    bolt.strokeWidth = BOLT_WIDTH
    bolt:setStrokeColor(BOLT_COLOR[1], BOLT_COLOR[2], BOLT_COLOR[3])
    transition.to(bolt, {
      time = BOLT_FADE_MS,
      alpha = 0,
      onComplete = function()
        if bolt.removeSelf then
          bolt:removeSelf()
        end
      end
    })
  end)
end

--- Strike the nearest enemy and chain to others
-- @return boolean True if the lightning fired
function ChainLightning:activate(heroX, heroY, enemies, projectilePool, displayGroup, heroStats)
  local current = targeting.nearest(heroX, heroY, enemies)
  if not current then
    return false
  end

  self.lastActivation = self._lastCurrentTime or os.clock()

  local damage = self.damage * ((heroStats and heroStats.damageMultiplier) or 1)
  local hit = {}
  local fromX, fromY = heroX, heroY
  for jump = 0, self.jumps do
    hit[current] = true
    drawBolt(displayGroup, fromX, fromY, current.x, current.y)
    fromX, fromY = current.x, current.y

    combat_system.applyDamage(current, damage * self.falloff ^ jump)
    if self.stunChance > 0 and current.isActive and current.applySlow and math.random() < self.stunChance then
      current:applySlow(0, self.stunDuration)
    end

    current = targeting.nearest(fromX, fromY, enemies, self.jumpRange, hit)
    if not current then
      break
    end
  end
  return true
end

function ChainLightning:upgrade(upgradeType)
  local params = ability_data_loader.getUpgradeParams("chain_lightning", upgradeType)

  if upgradeType == "jump_count" then
    self.jumps = self.jumps + ((params and params.jumpIncrease) or DEFAULT_JUMP_INCREASE)
  elseif upgradeType == "damage_increase" then
    self.damage = self.damage * ((params and params.damageMultiplier) or DEFAULT_DAMAGE_MULTIPLIER)
  elseif upgradeType == "no_falloff" then
    self.falloff = 1
  elseif upgradeType == "stun" then
    self.stunChance = (params and params.stunChance) or DEFAULT_STUN_CHANCE
  else
    return
  end
  self.tier = math.min(self.tier + 1, 5)
end

return ChainLightning
