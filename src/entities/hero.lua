-- Hero Entity
-- The stationary player character positioned at the defensive wall

local placeholder_graphics = require("src.utils.placeholder_graphics")

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

--- Combined stats from passive abilities
-- Abilities read these when they activate.
-- @return table { damageMultiplier, cooldownMultiplier }
function Hero:getStats()
  local stats = { damageMultiplier = 1, cooldownMultiplier = 1 }
  for _, ability in ipairs(self.abilities) do
    if ability.applyStats then
      ability:applyStats(stats)
    end
  end
  stats.cooldownMultiplier = math.max(stats.cooldownMultiplier, MIN_COOLDOWN_MULTIPLIER)
  return stats
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
