-- Wall Entity
-- Defensive structure that serves as the primary damage target

local Wall = Class("Wall")

function Wall:initialize(x, y, width)
  -- Position properties
  self.x = x
  self.y = y or 1200
  self.width = width
  
  -- Health properties
  self.health = 100
  self.maxHealth = 100
  
  -- Visual representation (rectangle spanning screen width)
  self.displayObject = display.newRect(self.x, self.y, self.width, 80)
  self.displayObject:setFillColor(0.4, 0.3, 0.2)  -- Brown/stone color
  self.displayObject.strokeWidth = 3
  self.displayObject:setStrokeColor(0.2, 0.15, 0.1)  -- Darker border
end

function Wall:takeDamage(amount)
  -- Clamp damage to non-negative values
  if amount < 0 then
    amount = 0
  end
  
  -- Reduce health by damage amount
  self.health = self.health - amount
  
  -- Clamp health to minimum 0
  if self.health < 0 then
    self.health = 0
  end
  
  -- Trigger visual feedback
  self:flashDamage()
end

function Wall:isDead()
  return self.health <= 0
end

function Wall:flashDamage()
  if not self.displayObject then
    return
  end
  
  -- Flash to lighter color
  transition.to(self.displayObject, {
    time = 100,
    fillColor = {0.8, 0.6, 0.4},
    onComplete = function()
      -- Return to normal color
      transition.to(self.displayObject, {
        time = 100,
        fillColor = {0.4, 0.3, 0.2}
      })
    end
  })
end

function Wall:destroy()
  if self.displayObject then
    self.displayObject:removeSelf()
    self.displayObject = nil
  end
end

return Wall
