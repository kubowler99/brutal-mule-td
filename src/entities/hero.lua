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
  
  -- Collection radius for XP orbs
  self.pickupRadius = 40
  
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

function Hero:addXP(amount)
  self.xp = self.xp + amount
  -- Note: Level-up logic is handled externally by experience_system
end

function Hero:destroy()
  if self.displayObject then
    self.displayObject:removeSelf()
    self.displayObject = nil
  end
end

return Hero
