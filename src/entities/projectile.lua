-- Projectile Entity
-- Velocity-based projectile for ability attacks (e.g., Arcane Bolt)

local placeholder_graphics = require("src.utils.placeholder_graphics")

local Projectile = Class("Projectile")

function Projectile:initialize(parentGroup)
  -- Parent display group for display objects
  self.parentGroup = parentGroup
  
  -- Position properties
  self.x = 0
  self.y = 0
  
  -- Velocity properties
  self.vx = 0
  self.vy = 0
  
  -- Combat properties
  self.damage = 0
  self.pierceCount = 0  -- Remaining pierce count
  
  -- Pool state
  self.isActive = false
  
  -- Track enemies that have been hit (for pierce mechanic)
  self.hitEnemies = {}
  
  -- Visual representation (placeholder circle for now)
  self.displayObject = nil
end

function Projectile:activate(x, y, targetX, targetY, speed, damage, pierce)
  -- Set spawn position
  self.x = x
  self.y = y
  
  -- Calculate direction vector to target
  local dx = targetX - x
  local dy = targetY - y
  local distance = math.sqrt(dx * dx + dy * dy)
  
  -- Normalize and scale by speed to get velocity
  if distance > 0 then
    self.vx = (dx / distance) * speed
    self.vy = (dy / distance) * speed
  else
    -- If target is at same position, default to moving up
    self.vx = 0
    self.vy = -speed
  end
  
  -- Set combat properties
  self.damage = damage
  self.pierceCount = pierce
  
  -- Reset hit tracking
  self.hitEnemies = {}
  
  -- Mark as active
  self.isActive = true
  
  -- Create or update display object
  if not self.displayObject then
    self.displayObject = placeholder_graphics.createProjectileSprite(self.x, self.y)
    if self.parentGroup and self.displayObject then
      self.parentGroup:insert(self.displayObject)
    end
  else
    self.displayObject.x = self.x
    self.displayObject.y = self.y
    self.displayObject.isVisible = true
  end
end

function Projectile:update(dt)
  if not self.isActive then
    return
  end
  
  -- Update position based on velocity
  self.x = self.x + (self.vx * dt)
  self.y = self.y + (self.vy * dt)
  
  -- Update display object position
  if self.displayObject then
    self.displayObject.x = self.x
    self.displayObject.y = self.y
  end
  
  -- Check if off-screen and deactivate if needed
  if self:isOffScreen() then
    self:deactivate()
  end
end

function Projectile:onHit(enemy)
  if not self.isActive then
    return false
  end
  
  -- Check if we've already hit this enemy (for pierce)
  for _, hitEnemy in ipairs(self.hitEnemies) do
    if hitEnemy == enemy then
      return false  -- Already hit this enemy, skip
    end
  end
  
  -- Record this enemy as hit
  table.insert(self.hitEnemies, enemy)
  
  -- Decrement pierce count
  self.pierceCount = self.pierceCount - 1
  
  -- Deactivate if no pierce remaining
  if self.pierceCount < 0 then
    self:deactivate()
    return true
  end
  
  return true
end

function Projectile:deactivate()
  self.isActive = false
  
  -- Hide display object
  if self.displayObject then
    self.displayObject.isVisible = false
  end
  
  -- Clear hit tracking
  self.hitEnemies = {}
end

function Projectile:isOffScreen()
  -- Check if projectile is beyond game area boundaries (200 pixels buffer)
  local buffer = 200
  local screenWidth = 720
  local screenHeight = 1280
  
  return self.x < -buffer or 
         self.x > screenWidth + buffer or
         self.y < -buffer or
         self.y > screenHeight + buffer
end

function Projectile:destroy()
  if self.displayObject then
    self.displayObject:removeSelf()
    self.displayObject = nil
  end
end

return Projectile
