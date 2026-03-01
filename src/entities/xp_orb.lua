-- XP Orb Entity
-- Collectible experience point dropped by defeated enemies

local placeholder_graphics = require("src.utils.placeholder_graphics")

local XPOrb = Class("XPOrb")

function XPOrb:initialize()
  -- Position properties
  self.x = 0
  self.y = 0
  
  -- XP properties
  self.xpValue = 10  -- XP granted on collection
  self.lifetime = 30  -- Seconds before despawn
  self.spawnTime = 0  -- Timestamp of spawn
  
  -- Pool state
  self.isActive = false
  
  -- Visual representation (placeholder circle for now)
  self.displayObject = nil
end

function XPOrb:activate(x, y)
  -- Set spawn position
  self.x = x
  self.y = y
  
  -- Record spawn time (using system.getTimer() for milliseconds)
  self.spawnTime = system.getTimer() / 1000  -- Convert to seconds
  
  -- Mark as active
  self.isActive = true
  
  -- Create or update display object
  if not self.displayObject then
    self.displayObject = placeholder_graphics.createXPOrbSprite(self.x, self.y)
  else
    self.displayObject.x = self.x
    self.displayObject.y = self.y
    self.displayObject.isVisible = true
  end
end

function XPOrb:update(currentTime)
  if not self.isActive then
    return
  end
  
  -- Check if lifetime has expired (30 seconds)
  local elapsed = currentTime - self.spawnTime
  if elapsed >= self.lifetime then
    self:deactivate()
  end
end

function XPOrb:collect()
  if not self.isActive then
    return false
  end
  
  -- Deactivate the orb (it's been collected)
  self:deactivate()
  return true
end

function XPOrb:deactivate()
  self.isActive = false
  
  -- Hide display object
  if self.displayObject then
    self.displayObject.isVisible = false
  end
end

function XPOrb:destroy()
  if self.displayObject then
    self.displayObject:removeSelf()
    self.displayObject = nil
  end
end

return XPOrb
