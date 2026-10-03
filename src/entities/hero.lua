-- Hero Entity
-- The stationary player character positioned at the defensive wall

local placeholder_graphics = require("src.utils.placeholder_graphics")
local synergy = require("src.models.synergy")

local Hero = Class("Hero")

function Hero:initialize(x, y)
  -- Fixed position (default to bottom center if not provided)
  self.x = x or 360
  self.y = y or 1200
  
  -- Level and XP properties
  self.level = 1
  self.xp = 0
  self.xpRequired = 100
  
  -- Abilities array (max 5 slots)
  self.abilities = {}
  
  -- Stats before passives (set from permanent upgrades and the hero choice)
  self.baseStats = { damageMultiplier = 1, cooldownMultiplier = 1 }
  
  -- Alive state
  self.isAlive = true
  
  -- Visual representation using placeholder graphics
  self.displayObject = placeholder_graphics.createHeroSprite(self.x, self.y)
end

function Hero:addAbility(ability)
  -- Check if we have room for more abilities (max 5)
  if #self.abilities >= 5 then
    return false
  end
  
  table.insert(self.abilities, ability)
  return true
end

-- Lowest cooldown multiplier passives can reach
local MIN_COOLDOWN_MULTIPLIER = 0.4

--- Combined stats from base stats, passive abilities, and synergies
-- Abilities read these when they activate.
-- @return table { damageMultiplier, cooldownMultiplier }
function Hero:getStats()
  local stats = {
    damageMultiplier = self.baseStats.damageMultiplier,
    cooldownMultiplier = self.baseStats.cooldownMultiplier,
  }
  for _, ability in ipairs(self.abilities) do
    if ability.applyStats then
      ability:applyStats(stats)
    end
  end
  -- Each tag shared by two or more abilities adds a damage bonus
  stats.damageMultiplier = stats.damageMultiplier + synergy.getDamageBonus(self.abilities)
  stats.cooldownMultiplier = math.max(stats.cooldownMultiplier, MIN_COOLDOWN_MULTIPLIER)
  return stats
end

--- Tint the hero's body
-- @param color table { r, g, b }
function Hero:setColor(color)
  local body = self.displayObject and self.displayObject[1]
  if body and body.setFillColor then
    body:setFillColor(color[1], color[2], color[3])
  end
end

function Hero:addXP(amount)
  self.xp = self.xp + amount
  -- Note: Level-up logic is handled externally by experience_system
end

function Hero:destroy()
  -- Abilities may own display objects (e.g. orbiting blades)
  for _, ability in ipairs(self.abilities) do
    if ability.destroy then
      ability:destroy()
    end
  end
  
  if self.displayObject then
    self.displayObject:removeSelf()
    self.displayObject = nil
  end
end

return Hero
