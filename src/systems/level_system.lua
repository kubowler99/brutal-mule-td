-- Level System
-- Manages XP accumulation, orb spawning/collection, and level-up triggers

local level_system = {}

-- State
level_system.hero = nil
level_system.xpOrbPool = nil
level_system.activeOrbs = {}
level_system.onLevelUp = nil

-- Initialize the level system
function level_system.initialize(hero, xpOrbPool, onLevelUpCallback)
  level_system.hero = hero
  level_system.xpOrbPool = xpOrbPool
  level_system.onLevelUp = onLevelUpCallback
  level_system.activeOrbs = {}
end

-- Update active XP orbs (check lifetime expiration)
function level_system.update(dt, currentTime)
  -- Validate parameters
  if type(dt) ~= "number" or type(currentTime) ~= "number" then
    print("Warning: Invalid parameters for level_system.update")
    return
  end
  
  -- Update all active orbs (iterate backwards to safely remove)
  for i = #level_system.activeOrbs, 1, -1 do
    local orb = level_system.activeOrbs[i]
    
    -- Validate orb exists and has update method
    if orb and type(orb.update) == "function" then
      -- Update orb (checks lifetime expiration)
      orb:update(currentTime)
      
      -- Remove if deactivated (expired or collected)
      if not orb.isActive then
        if level_system.xpOrbPool then
          level_system.xpOrbPool:release(orb)
        end
        table.remove(level_system.activeOrbs, i)
      end
    else
      -- Remove invalid orb
      print("Warning: Invalid orb found in activeOrbs, removing")
      table.remove(level_system.activeOrbs, i)
    end
  end
end

-- Spawn an XP orb at the specified position
function level_system.spawnXPOrb(x, y)
  -- Validate position coordinates
  if type(x) ~= "number" or type(y) ~= "number" then
    print("Warning: Invalid XP orb spawn position:", x, y)
    return nil
  end
  
  -- Check if pool is available
  if not level_system.xpOrbPool then
    print("Warning: XP orb pool not initialized")
    return nil
  end
  
  -- Get orb from pool
  local orb = level_system.xpOrbPool:get()
  
  -- Activate the orb with position
  orb:activate(x, y)
  
  table.insert(level_system.activeOrbs, orb)
  return orb
end

-- Check for XP orb collection based on hero proximity
function level_system.checkOrbCollection(heroX, heroY, heroRadius)
  -- Validate hero position and radius
  if type(heroX) ~= "number" or type(heroY) ~= "number" or type(heroRadius) ~= "number" then
    print("Warning: Invalid hero position or radius for orb collection")
    return
  end
  
  -- Ensure radius is positive
  if heroRadius <= 0 then
    print("Warning: Invalid hero pickup radius:", heroRadius)
    return
  end
  
  for i = #level_system.activeOrbs, 1, -1 do
    local orb = level_system.activeOrbs[i]
    
    if orb and orb.isActive then
      -- Validate orb position
      if type(orb.x) == "number" and type(orb.y) == "number" then
        -- Calculate distance between hero and orb
        local dx = orb.x - heroX
        local dy = orb.y - heroY
        local distance = math.sqrt(dx * dx + dy * dy)
        
        -- Check if within pickup radius
        if distance <= heroRadius then
          -- Collect the orb
          orb:collect()
          
          -- Add XP to hero
          level_system.addXP(orb.xpValue)
          
          -- Remove from active orbs
          level_system.xpOrbPool:release(orb)
          table.remove(level_system.activeOrbs, i)
        end
      end
    end
  end
end

-- Add XP to hero and check for level-up
function level_system.addXP(amount)
  if not level_system.hero then
    return
  end
  
  -- Validate XP amount is positive
  if type(amount) ~= "number" or amount <= 0 then
    print("Warning: Invalid XP amount:", amount)
    return
  end
  
  -- Clamp XP to reasonable maximum (999999)
  local clampedAmount = math.min(amount, 999999)
  if clampedAmount ~= amount then
    print("Warning: XP amount clamped from", amount, "to", clampedAmount)
  end
  
  -- Add XP to hero
  level_system.hero:addXP(clampedAmount)
  
  -- Check if hero has enough XP to level up
  while level_system.hero.xp >= level_system.hero.xpRequired do
    -- Subtract XP requirement from current XP
    level_system.hero.xp = level_system.hero.xp - level_system.hero.xpRequired
    
    -- Increment level
    level_system.hero.level = level_system.hero.level + 1
    
    -- Calculate new XP requirement
    level_system.hero.xpRequired = level_system.calculateXPRequired(level_system.hero.level)
    
    -- Check game state before pausing for level-up
    -- Only trigger level-up callback if callback exists and hero is valid
    if level_system.onLevelUp and level_system.hero then
      level_system.onLevelUp(level_system.hero.level)
    end
  end
end

-- Calculate XP required for a given level
-- Formula: 100 + (level - 1) * 20
function level_system.calculateXPRequired(level)
  -- Validate level is a positive number
  if type(level) ~= "number" or level < 1 then
    print("Warning: Invalid level for XP calculation:", level)
    return 100  -- Return base XP requirement
  end
  
  return 100 + (level - 1) * 20
end

-- Get active orbs array (for external access)
function level_system.getActiveOrbs()
  return level_system.activeOrbs
end

-- Cleanup the level system
function level_system.cleanup()
  -- Deactivate all active orbs
  for i = #level_system.activeOrbs, 1, -1 do
    local orb = level_system.activeOrbs[i]
    orb:deactivate()
    level_system.xpOrbPool:release(orb)
  end
  
  level_system.activeOrbs = {}
  level_system.hero = nil
  level_system.xpOrbPool = nil
  level_system.onLevelUp = nil
end

return level_system
