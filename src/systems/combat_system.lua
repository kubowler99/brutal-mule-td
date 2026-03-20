--- Combat System
-- Orchestrates all combat-related activities: ability activation based on cooldowns,
-- projectile creation and movement, collision detection integration, and damage application.
--
-- @module combat_system

local M = {}

-- Internal state
local hero = nil
local projectilePool = nil
local activeProjectiles = {}
local enemies = {}
local sceneGroup = nil

--- Initialize the combat system
-- Sets up references to the hero, projectile pool, enemies array, and scene group.
--
-- @param heroEntity table The hero entity
-- @param projPool table Object pool for projectiles
-- @param enemiesArray table Reference to active enemies array
-- @param group table Optional scene group for inserting projectile display objects
function M.initialize(heroEntity, projPool, enemiesArray, group)
  hero = heroEntity
  projectilePool = projPool
  enemies = enemiesArray
  sceneGroup = group
  activeProjectiles = {}
end

--- Main update loop for combat system
-- Coordinates ability activation and projectile updates.
--
-- @param dt number Delta time in seconds
-- @param currentTime number Current game time in seconds
function M.update(dt, currentTime)
  if not hero or not hero.isAlive then
    return
  end
  
  -- Activate abilities based on cooldowns
  M.activateAbilities(currentTime)
  
  -- Update all active projectiles
  M.updateProjectiles(dt)
end

--- Activate hero abilities based on cooldown timers
-- Iterates through all hero abilities and activates those that are ready.
--
-- @param currentTime number Current game time in seconds
function M.activateAbilities(currentTime)
  if not hero or not hero.abilities then
    return
  end
  
  -- Check enemies array length before targeting (skip if empty)
  if not enemies or type(enemies) ~= "table" or #enemies == 0 then
    return
  end
  
  -- Check if there are any active enemies to target
  local hasEnemies = false
  for _, enemy in ipairs(enemies) do
    if enemy and enemy.isActive then
      hasEnemies = true
      break
    end
  end
  
  -- Skip activation if no enemies exist (for targeting abilities)
  if not hasEnemies then
    return
  end
  
  -- Iterate through hero abilities with pcall wrapper for critical operations
  for _, ability in ipairs(hero.abilities) do
    if ability and ability.canActivate and ability:canActivate(currentTime) then
      -- Create a tracking wrapper around the pool to capture created projectiles
      local trackingPool = {
        get = function(self, ...)
          local projectile = projectilePool:get(...)
          if projectile then
            -- We'll track it after activation completes
            table.insert(activeProjectiles, projectile)
          end
          return projectile
        end,
        release = function(self, obj)
          return projectilePool:release(obj)
        end
      }
      
      -- Wrap ability activation in pcall for error handling
      local success, result = pcall(function()
        return ability:activate(hero.x, hero.y, enemies, trackingPool)
      end)
      
      if success then
        -- If activation was successful, ensure display objects are in scene group
        if result then
          M.refreshActiveProjectiles()
        end
      else
        -- Log error but continue with other abilities
        print("Warning: Ability activation failed:", result)
      end
    end
  end
end

--- Refresh the active projectiles array
-- Scans all tracked projectiles and removes inactive ones.
-- Also picks up any newly created projectiles from the last ability activation.
-- Inserts new projectile display objects into the scene group if available.
function M.refreshActiveProjectiles()
  -- Insert display objects for any active projectiles not yet in the scene group
  for _, projectile in ipairs(activeProjectiles) do
    if projectile and projectile.isActive and sceneGroup and projectile.displayObject 
       and not projectile.displayObject.parent then
      sceneGroup:insert(projectile.displayObject)
    end
  end
end

--- Track a newly created projectile
-- Called by ability activation to register projectiles with the combat system.
-- @param projectile table The projectile entity to track
function M.trackProjectile(projectile)
  if projectile and projectile.isActive then
    table.insert(activeProjectiles, projectile)
    
    -- Insert display object into scene group if available
    if sceneGroup and projectile.displayObject and not projectile.displayObject.parent then
      sceneGroup:insert(projectile.displayObject)
    end
  end
end

--- Update all active projectiles
-- Moves projectiles and removes those that are off-screen.
--
-- @param dt number Delta time in seconds
function M.updateProjectiles(dt)
  if not activeProjectiles then
    return
  end
  
  -- Update each projectile
  -- Iterate backwards to safely remove projectiles during iteration
  for i = #activeProjectiles, 1, -1 do
    local projectile = activeProjectiles[i]
    
    if projectile and projectile.isActive then
      -- Wrap projectile update in pcall for error handling
      local success, err = pcall(function()
        projectile:update(dt)
      end)
      
      if not success then
        print("Warning: Projectile update failed:", err)
        -- Deactivate problematic projectile
        if projectile.deactivate then
          projectile:deactivate()
        end
        table.remove(activeProjectiles, i)
      else
        -- Check projectile bounds (deactivate if > 200px off-screen)
        -- Note: isOffScreen already checks 200px boundary internally
        if projectile.isOffScreen and projectile:isOffScreen() then
          if projectile.deactivate then
            projectile:deactivate()
          end
          table.remove(activeProjectiles, i)
        -- Remove from tracking if no longer active (off-screen or hit)
        elseif not projectile.isActive then
          table.remove(activeProjectiles, i)
        end
      end
    else
      -- Remove inactive projectiles from tracking
      table.remove(activeProjectiles, i)
    end
  end
end

--- Apply damage to an entity
-- Validates the damage amount and applies it to the entity.
--
-- @param entity table The entity to damage (must have takeDamage method)
-- @param amount number The damage amount to apply
function M.applyDamage(entity, amount)
  -- Validate entity
  if not entity or not entity.takeDamage then
    return
  end
  
  -- Validate damage values (clamp to minimum 0)
  local validAmount = 0
  if type(amount) == "number" then
    validAmount = math.max(0, amount)
  end
  
  -- Wrap damage application in pcall for error handling
  local success, err = pcall(function()
    entity:takeDamage(validAmount)
  end)
  
  if not success then
    print("Warning: Damage application failed:", err)
  end
end

--- Get active projectiles array
-- Returns the current array of active projectiles for collision detection.
--
-- @return table Array of active projectiles
function M.getActiveProjectiles()
  return activeProjectiles
end

--- Cleanup combat system resources
-- Deactivates all active projectiles and clears all references.
function M.cleanup()
  -- Deactivate and hide all tracked projectiles
  for _, projectile in ipairs(activeProjectiles) do
    if projectile then
      if projectile.deactivate then
        projectile:deactivate()
      end
      -- Ensure display object is hidden even if deactivate didn't handle it
      if projectile.displayObject then
        projectile.displayObject.isVisible = false
      end
    end
  end
  
  hero = nil
  projectilePool = nil
  activeProjectiles = {}
  enemies = {}
  sceneGroup = nil
end

return M
