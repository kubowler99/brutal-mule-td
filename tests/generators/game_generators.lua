-- game_generators.lua
-- Custom generators for property-based testing in Arcane Survivor MVP
-- These generators create random test data for property tests using lua-quickcheck

local generators = {}

-- Generate random hero levels (1-20)
-- Used for testing level-based mechanics like spawn rate scaling
function generators.heroLevel()
  return function()
    return math.random(1, 20)
  end
end

-- Generate random positions within game area
-- Game area: 720x1280 (portrait orientation)
-- Returns: {x = number, y = number}
function generators.position()
  return function()
    return {
      x = math.random(0, 720),
      y = math.random(0, 1280)
    }
  end
end

-- Generate random walker configurations
-- Walkers spawn at top edge (y ≈ 0) within playable bounds (x: 50-670)
-- Returns: {x = number, y = number, health = number, lane = number}
function generators.walker()
  return function()
    local spawnX = math.random(50, 670)
    return {
      x = spawnX,
      y = math.random(0, 100),  -- Near top of screen
      health = math.random(1, 20),
      lane = spawnX  -- Lane equals spawn X coordinate
    }
  end
end

-- Generate random ability configurations
-- Used for testing ability mechanics and upgrades
-- Returns: {cooldown = number, damage = number, tier = number}
function generators.ability()
  return function()
    return {
      cooldown = math.random(1, 5) * 0.5,  -- 0.5s to 2.5s
      damage = math.random(5, 50),
      tier = math.random(1, 5)
    }
  end
end

-- Generate arrays of walkers with configurable size
-- Used for testing collision detection and combat with multiple enemies
-- Parameters:
--   minSize: minimum number of walkers (default 0)
--   maxSize: maximum number of walkers (default 50)
-- Returns: array of walker configurations
function generators.walkerArray(minSize, maxSize)
  minSize = minSize or 0
  maxSize = maxSize or 50
  
  return function()
    local count = math.random(minSize, maxSize)
    local walkers = {}
    for _ = 1, count do
      table.insert(walkers, generators.walker()())
    end
    return walkers
  end
end

-- Generate random damage amounts
-- Used for testing damage application and hero death
-- Returns: number (1-50 damage)
function generators.damageAmount()
  return function()
    return math.random(1, 50)
  end
end

-- Generate random XP amounts
-- Used for testing XP collection and level-up mechanics
-- Returns: number (1-100 XP)
function generators.xpAmount()
  return function()
    return math.random(1, 100)
  end
end

-- Generate random time intervals (in seconds)
-- Used for testing time-based mechanics like cooldowns and spawn intervals
-- Returns: number (0.1 to 10.0 seconds)
function generators.timeInterval()
  return function()
    return math.random(1, 100) / 10  -- 0.1 to 10.0 seconds
  end
end

-- Generate random positive numbers within a range
-- Used for testing numeric properties like health, XP, dimensions
-- Parameters:
--   min: minimum value (default 0)
--   max: maximum value (default 1000)
-- Returns: number
function generators.positiveNumber(min, max)
  min = min or 0
  max = max or 1000
  
  return function()
    return math.random(min * 100, max * 100) / 100  -- Support decimals
  end
end

-- Generate random wall health values
-- Used for testing wall damage and death mechanics
-- Returns: number (0-200 health)
function generators.wallHealth()
  return function()
    return math.random(0, 200)
  end
end

-- Generate random wall threshold Y-coordinates
-- Wall threshold is the Y-position where walkers stop and attack
-- Game area: 720x1280, wall typically at bottom (y ≈ 1180)
-- Returns: number (1000-1280)
function generators.wallThreshold()
  return function()
    return math.random(1000, 1280)
  end
end

-- Generate walker at or below wall threshold
-- Used for testing walker attack behavior when at wall
-- Parameters:
--   threshold: Y-coordinate of wall (default 1180)
-- Returns: walker configuration with y >= threshold
function generators.walkerAtWall(threshold)
  threshold = threshold or 1180
  
  return function()
    local spawnX = math.random(50, 670)
    return {
      x = spawnX,
      y = math.random(threshold, 1280),  -- At or below threshold
      health = math.random(1, 20),
      lane = spawnX
    }
  end
end

-- Generate walker above wall threshold
-- Used for testing walker movement behavior before reaching wall
-- Parameters:
--   threshold: Y-coordinate of wall (default 1180)
-- Returns: walker configuration with y < threshold
function generators.walkerAboveWall(threshold)
  threshold = threshold or 1180
  
  return function()
    local spawnX = math.random(50, 670)
    return {
      x = spawnX,
      y = math.random(0, threshold - 1),  -- Above threshold
      health = math.random(1, 20),
      lane = spawnX
    }
  end
end

return generators

