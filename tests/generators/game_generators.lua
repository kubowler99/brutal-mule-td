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

return generators
