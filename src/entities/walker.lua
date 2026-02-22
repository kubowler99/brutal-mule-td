-- Walker Entity
-- Basic melee enemy that advances toward the defensive wall

local Walker = Class("Walker")

function Walker:initialize()
  -- Position properties
  self.x = 0
  self.y = 0
  self.lane = 0  -- Assigned lane (X coordinate)
  
  -- Health properties
  self.health = 20
  self.maxHealth = 20
  
  -- Movement and combat properties
  self.speed = 80  -- Pixels per second
  self.damage = 5  -- Melee damage
  self.attackCooldown = 1.0  -- Time between attacks (seconds)
  self.lastAttackTime = 0  -- Timestamp of last attack
  self.attackRange = 30  -- Distance to hero for melee
  
  -- Pool state
  self.isActive = false
  
  -- Visual representation (placeholder circle for now)
  self.displayObject = nil
end

function Walker:activate(x, y, lane)
  -- Set spawn position and lane
  self.x = x
  self.y = y
  self.lane = lane
  
  -- Reset health
  self.health = self.maxHealth
  
  -- Reset attack timer
  self.lastAttackTime = 0
  
  -- Mark as active
  self.isActive = true
  
  -- Create or update display object
  if not self.displayObject then
    self.displayObject = display.newCircle(self.x, self.y, 20)
    self.displayObject:setFillColor(0.8, 0.2, 0.2)  -- Red color
  else
    self.displayObject.x = self.x
    self.displayObject.y = self.y
    self.displayObject.isVisible = true
  end
end

function Walker:update(dt, heroX, heroY)
  if not self.isActive then
    return
  end
  
  -- Move down the lane (vertical movement, constant X)
  self.y = self.y + (self.speed * dt)
  
  -- Update display object position
  if self.displayObject then
    self.displayObject.y = self.y
  end
  
  -- Check if within melee range of hero
  local distance = self:getDistance(heroX, heroY)
  if distance <= self.attackRange then
    -- Attack logic is handled externally by combat system
    -- This just tracks the distance
  end
end

function Walker:takeDamage(amount)
  if not self.isActive then
    return
  end
  
  self.health = self.health - amount
  
  if self.health <= 0 then
    self.health = 0
    self:deactivate()
  end
end

function Walker:deactivate()
  self.isActive = false
  
  -- Hide display object
  if self.displayObject then
    self.displayObject.isVisible = false
  end
end

function Walker:getDistance(x, y)
  local dx = x - self.x
  local dy = y - self.y
  return math.sqrt(dx * dx + dy * dy)
end

function Walker:destroy()
  if self.displayObject then
    self.displayObject:removeSelf()
    self.displayObject = nil
  end
end

return Walker
