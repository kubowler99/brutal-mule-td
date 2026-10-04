-- Projectile Entity
-- Velocity-based projectile for ability attacks (e.g., Arcane Bolt)

local placeholder_graphics = require("src.utils.placeholder_graphics")

local Projectile = Class("Projectile")

-- Sprite image per projectile visual, all pointing up (rotation 0 = moving up)
local SPRITES = {
  arcane_bolt = { path = "assets/images/projectiles/arcane_bolt.png", size = 28 },
  frost_shard = { path = "assets/images/projectiles/frost_shard.png", size = 32 },
}
local DEFAULT_VISUAL = "arcane_bolt"

--- Build the projectile display group: one image per visual, or the
--- placeholder circle if no image loads
-- @return table Display group, table images keyed by visual name
local function createDisplayObject(x, y)
  local group = display.newGroup()
  local images = {}
  for name, sprite in pairs(SPRITES) do
    local image = display.newImageRect(group, sprite.path, sprite.size, sprite.size)
    if image then
      image.isVisible = false
      images[name] = image
    end
  end
  if next(images) == nil then
    group:removeSelf()
    return placeholder_graphics.createProjectileSprite(x, y), images
  end
  group.x = x
  group.y = y
  return group, images
end

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
  
  -- On-hit effects (set by abilities such as Frost Shard after activation)
  self.slowFactor = nil
  self.slowDuration = nil
  self.freezeChance = nil
  self.freezeDuration = nil
  self.ricochetsLeft = 0
  self.needsRicochet = false
  
  -- Reset hit tracking
  self.hitEnemies = {}
  
  -- Mark as active
  self.isActive = true
  
  -- Create or update display object
  if not self.displayObject then
    self.displayObject, self.images = createDisplayObject(self.x, self.y)
    if self.parentGroup and self.displayObject then
      self.parentGroup:insert(self.displayObject)
    end
  else
    self.displayObject.x = self.x
    self.displayObject.y = self.y
    self.displayObject.isVisible = true
  end
  self.displayObject.rotation = math.deg(math.atan2(self.vy, self.vx)) + 90
  self:setVisual(DEFAULT_VISUAL)
end

--- Show the sprite for one projectile visual and hide the others
-- @param name string Visual name, e.g. "arcane_bolt" or "frost_shard"
function Projectile:setVisual(name)
  if not self.images or not self.images[name] then
    return
  end
  self.visual = name
  for imageName, image in pairs(self.images) do
    image.isVisible = (imageName == name)
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
  
  -- Out of pierce: ricochet to a new target if any ricochets are left
  -- (the game controller picks the target), otherwise stop
  if self.pierceCount < 0 then
    if (self.ricochetsLeft or 0) > 0 then
      self.ricochetsLeft = self.ricochetsLeft - 1
      self.pierceCount = 0
      self.needsRicochet = true
    else
      self:deactivate()
    end
    return true
  end
  
  return true
end

--- Turn toward a new target at the same speed (used for ricochets)
-- @param targetX number Target X
-- @param targetY number Target Y
function Projectile:redirect(targetX, targetY)
  local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
  local dx = targetX - self.x
  local dy = targetY - self.y
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance > 0 then
    self.vx = (dx / distance) * speed
    self.vy = (dy / distance) * speed
  end
  if self.displayObject then
    self.displayObject.rotation = math.deg(math.atan2(self.vy, self.vx)) + 90
  end
  self.needsRicochet = false
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
  self.images = nil
end

return Projectile
