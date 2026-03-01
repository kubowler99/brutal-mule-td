-- Arcane Bolt Ability
-- The hero's default automatic projectile attack ability
-- Fires toward the nearest enemy with configurable damage, cooldown, and upgrades

local ArcaneBolt = Class("ArcaneBolt")

function ArcaneBolt:initialize()
  -- Ability identification
  self.id = "arcane_bolt"
  self.name = "Arcane Bolt"
  
  -- Base stats
  self.cooldown = 1.0  -- Base cooldown in seconds
  self.lastActivation = 0  -- Timestamp of last activation
  self.damage = 10  -- Base damage
  self.projectileSpeed = 400  -- Pixels per second
  
  -- Upgrade properties
  self.tier = 1  -- Current upgrade tier (1-5)
  self.pierceCount = 0  -- Number of enemies to pierce (0 = no pierce)
  self.projectileCount = 1  -- Number of projectiles per activation
end

function ArcaneBolt:canActivate(currentTime)
  -- Check if enough time has passed since last activation
  return (currentTime - self.lastActivation) >= self.cooldown
end

function ArcaneBolt:findNearestEnemy(heroX, heroY, enemies)
  if not enemies or #enemies == 0 then
    return nil
  end
  
  local nearestEnemy = nil
  local minDistance = math.huge
  
  for _, enemy in ipairs(enemies) do
    if enemy.isActive then
      -- Calculate distance to this enemy
      local dx = enemy.x - heroX
      local dy = enemy.y - heroY
      local distance = math.sqrt(dx * dx + dy * dy)
      
      -- Update nearest if this is closer
      if distance < minDistance then
        minDistance = distance
        nearestEnemy = enemy
      end
    end
  end
  
  return nearestEnemy
end

function ArcaneBolt:activate(heroX, heroY, enemies, projectilePool)
  -- Find the nearest enemy
  local target = self:findNearestEnemy(heroX, heroY, enemies)
  
  -- If no target, don't activate
  if not target then
    return false
  end
  
  -- Update last activation time
  self.lastActivation = os.clock()
  
  -- Create projectiles based on projectileCount
  for i = 1, self.projectileCount do
    local projectile = projectilePool:get()
    
    if projectile then
      -- Calculate target position (same for all projectiles in MVP)
      -- Future enhancement: spread projectiles in a pattern
      local targetX = target.x
      local targetY = target.y
      
      -- Activate the projectile
      projectile:activate(
        heroX,
        heroY,
        targetX,
        targetY,
        self.projectileSpeed,
        self.damage,
        self.pierceCount
      )
    end
  end
  
  return true
end

function ArcaneBolt:upgrade(upgradeType)
  -- Apply tier-based upgrades
  if upgradeType == "damage_increase" then
    self.damage = self.damage + 5
    self.tier = math.min(self.tier + 1, 5)
    
  elseif upgradeType == "attack_speed" then
    -- Reduce cooldown by 0.15s, minimum 0.25s
    self.cooldown = math.max(self.cooldown - 0.15, 0.25)
    self.tier = math.min(self.tier + 1, 5)
    
  elseif upgradeType == "projectile_count" then
    self.projectileCount = self.projectileCount + 1
    self.tier = math.min(self.tier + 1, 5)
    
  elseif upgradeType == "pierce" then
    self.pierceCount = self.pierceCount + 1
    self.tier = math.min(self.tier + 1, 5)
  end
end

return ArcaneBolt
