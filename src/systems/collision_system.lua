--- Collision System
-- Handles all distance-based collision detection in the game.
-- Uses simple distance calculations without a physics engine.
--
-- @module collision_system

local config_loader = require("src.models.config_loader")

local M = {}

-- Collision thresholds (in pixels) - read from config_loader with hard-coded fallbacks
local PROJECTILE_ENEMY_THRESHOLD = config_loader.positiveNumber(
  config_loader.get("collision.projectileEnemyThreshold"), 20
)
local HERO_ENEMY_MELEE_THRESHOLD = config_loader.positiveNumber(
  config_loader.get("collision.heroEnemyMeleeThreshold"), 30
)

--- Calculate distance between two points using the distance formula
-- @param x1 number X coordinate of first point
-- @param y1 number Y coordinate of first point
-- @param x2 number X coordinate of second point
-- @param y2 number Y coordinate of second point
-- @return number The distance between the two points
function M.checkDistance(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

--- Check for collisions between projectiles and enemies
-- Detects when a projectile is within collision threshold of an enemy.
-- Returns array of collision pairs for the combat system to process.
--
-- @param projectiles table Array of active projectile entities
-- @param enemies table Array of active enemy entities
-- @return table Array of collision pairs {projectile=proj, enemy=enemy}
function M.checkProjectileCollisions(projectiles, enemies)
  local collisions = {}
  
  -- Validate inputs
  if not projectiles or not enemies then
    return collisions
  end
  
  -- Check each projectile against each enemy
  for i = 1, #projectiles do
    local projectile = projectiles[i]
    
    -- Skip inactive projectiles or invalid positions
    if projectile and projectile.isActive and 
       type(projectile.x) == "number" and type(projectile.y) == "number" then
      
      for j = 1, #enemies do
        local enemy = enemies[j]
        
        -- Skip inactive enemies or invalid positions
        if enemy and enemy.isActive and 
           type(enemy.x) == "number" and type(enemy.y) == "number" then
          
          local distance = M.checkDistance(
            projectile.x, projectile.y,
            enemy.x, enemy.y
          )
          
          -- Check if collision occurred
          if distance <= PROJECTILE_ENEMY_THRESHOLD then
            table.insert(collisions, {
              projectile = projectile,
              enemy = enemy
            })
          end
        end
      end
    end
  end
  
  return collisions
end

--- Check for enemies within melee range of the hero
-- Detects when enemies are close enough to attack the hero.
-- Returns array of enemies within melee range.
--
-- @param hero table Hero entity with x and y properties
-- @param enemies table Array of active enemy entities
-- @return table Array of enemies within melee attack range
function M.checkMeleeRange(hero, enemies)
  local meleeEnemies = {}
  
  -- Validate inputs
  if not hero or not enemies then
    return meleeEnemies
  end
  
  -- Validate hero position
  if type(hero.x) ~= "number" or type(hero.y) ~= "number" then
    return meleeEnemies
  end
  
  -- Check each enemy against hero melee range
  for i = 1, #enemies do
    local enemy = enemies[i]
    
    -- Skip inactive enemies or invalid positions
    if enemy and enemy.isActive and 
       type(enemy.x) == "number" and type(enemy.y) == "number" then
      
      local distance = M.checkDistance(
        hero.x, hero.y,
        enemy.x, enemy.y
      )
      
      -- Check if enemy is within melee range
      if distance <= HERO_ENEMY_MELEE_THRESHOLD then
        table.insert(meleeEnemies, enemy)
      end
    end
  end
  
  return meleeEnemies
end

--- Check for walkers that have reached the wall threshold
-- Detects when walkers have reached the wall's Y-coordinate position.
-- Returns array of walkers that have collided with the wall.
--
-- @param walkers table Array of active walker entities
-- @param wallThreshold number Y-coordinate of the wall position
-- @return table Array of walkers that have reached the wall
function M.checkWallCollisions(walkers, wallThreshold)
  local collisions = {}
  
  -- Validate inputs
  if not walkers or type(wallThreshold) ~= "number" then
    return collisions
  end
  
  -- Check each walker against wall threshold
  for i = 1, #walkers do
    local walker = walkers[i]
    
    -- Skip inactive walkers or invalid positions
    if walker and walker.isActive and type(walker.y) == "number" then
      -- Check if walker has reached or passed the wall threshold
      if walker.y >= wallThreshold then
        table.insert(collisions, walker)
      end
    end
  end
  
  return collisions
end

return M
