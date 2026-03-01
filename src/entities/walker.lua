-- Walker Entity
-- Basic melee enemy that advances toward the defensive wall

local placeholder_graphics = require("src.utils.placeholder_graphics")

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
  
  -- Wall targeting properties
  self.wallTarget = nil  -- Reference to wall entity
  self.isAttackingWall = false  -- Attack state flag
  
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
  
  -- Reset wall targeting
  self.wallTarget = nil
  self.isAttackingWall = false
  
  -- Mark as active
  self.isActive = true
  
  -- Create or update display object
  if not self.displayObject then
    self.displayObject = placeholder_graphics.createWalkerSprite(self.x, self.y)
  else
    self.displayObject.x = self.x
    self.displayObject.y = self.y
    self.displayObject.isVisible = true
  end
end

function Walker:update(dt, wallThreshold)
  if not self.isActive then
    return
  end
  
  -- Check if walker has reached the wall threshold
  if self.y >= wallThreshold then
    -- Stop moving and set attacking state
    self.isAttackingWall = true
  else
    -- Continue moving downward toward the wall
    self.y = self.y + (self.speed * dt)
    
    -- Check again after movement to ensure we don't overshoot
    if self.y >= wallThreshold then
      self.y = wallThreshold
      self.isAttackingWall = true
    end
  end
  
  -- Update display object position (always sync with logical position)
  if self.displayObject then
    self.displayObject.y = self.y
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
  
  -- Reset wall targeting
  self.wallTarget = nil
  self.isAttackingWall = false
  
  -- Hide display object
  if self.displayObject then
    self.displayObject.isVisible = false
  end
end

function Walker:destroy()
  if self.displayObject then
    self.displayObject:removeSelf()
    self.displayObject = nil
  end
end

return Walker
