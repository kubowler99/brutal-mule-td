-- Hero Entity
-- The stationary player character positioned at the defensive wall

local Hero = Class("Hero")

function Hero:initialize(x, y)
  -- Fixed position (default to bottom center if not provided)
  self.x = x or 360
  self.y = y or 1180
  
  -- Health properties
  self.health = 100
  self.maxHealth = 100
  
  -- Level and XP properties
  self.level = 1
  self.xp = 0
  self.xpRequired = 100
  
  -- Abilities array (max 5 slots)
  self.abilities = {}
  
  -- Collection radius for XP orbs
  self.pickupRadius = 40
  
  -- Alive state
  self.isAlive = true
  
  -- Visual representation (placeholder circle for now)
  self.displayObject = display.newCircle(self.x, self.y, 30)
  self.displayObject:setFillColor(0.2, 0.5, 1.0) -- Blue color
end

function Hero:takeDamage(amount)
  if not self.isAlive then
    return
  end
  
  self.health = self.health - amount
  
  if self.health <= 0 then
    self.health = 0
    self.isAlive = false
  end
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
  -- Note: Level-up logic is handled externally by level_system
end

function Hero:destroy()
  if self.displayObject then
    self.displayObject:removeSelf()
    self.displayObject = nil
  end
end

return Hero
