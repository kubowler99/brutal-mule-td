-- Game Controller
-- Orchestrates the main game loop and coordinates all game systems
-- Manages game state transitions, system updates, and scene lifecycle

local pool = require("src.utils.pool")
local Hero = require("src.entities.hero")
local Wall = require("src.entities.wall")
local Walker = require("src.entities.walker")
local Projectile = require("src.entities.projectile")
local XPOrb = require("src.entities.xp_orb")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")
local combat_system = require("src.systems.combat_system")
local spawner_system = require("src.systems.spawner_system")
local level_system = require("src.systems.level_system")
local upgrade_system = require("src.systems.upgrade_system")
local collision_system = require("src.systems.collision_system")
local game_state = require("src.models.game_state")

local M = {}

-- Internal state
local hero = nil
local wall = nil
local walkerPool = nil
local projectilePool = nil
local xpOrbPool = nil
local sceneGroup = nil
local gameLoopListener = nil
local isPaused = false

--- Initialize the game controller and set up game session
-- Creates hero, initializes object pools, and sets up all systems
-- @param group table The scene group to add display objects to
function M.initialize(group)
  sceneGroup = group
  isPaused = false
  
  -- Initialize game state
  game_state.initialize()
  
  -- Create wall at fixed position (360, 1200, display.contentWidth)
  -- Wall is positioned at Y=1200 with height 80
  wall = Wall:new(360, 1200, display.contentWidth)
  
  -- Add wall display object to scene group FIRST (renders behind hero)
  if wall.displayObject and sceneGroup then
    sceneGroup:insert(wall.displayObject)
  end
  
  -- Create hero at fixed position (60, 1200)
  -- Hero is positioned on the left side of the wall at wall's center Y
  -- Positioned at X=60 to maintain 5px gap from first ability indicator (left edge at X=95)
  hero = Hero:new(45, 1200)
  
  -- Add hero's starting ability (Arcane Bolt)
  local arcaneBolt = ArcaneBolt:new()
  hero:addAbility(arcaneBolt)
  
  -- Add hero display object to scene group AFTER wall (renders in front)
  if hero.displayObject and sceneGroup then
    sceneGroup:insert(hero.displayObject)
  end
  
  -- Initialize object pools
  walkerPool = pool.new(
    function() return Walker:new() end,
    nil  -- No reset function, we'll call activate manually
  )
  
  projectilePool = pool.new(
    function() return Projectile:new() end,
    nil  -- No reset function, we'll call activate manually
  )
  
  xpOrbPool = pool.new(
    function() return XPOrb:new() end,
    nil  -- No reset function, we'll call activate manually
  )
  
  -- Add display objects from pools to scene group
  if sceneGroup then
    -- Pre-warm pools and add display objects
    for i = 1, 10 do
      local walker = Walker:new()
      if walker.displayObject then
        sceneGroup:insert(walker.displayObject)
      end
      walkerPool:release(walker)
    end
    
    for i = 1, 20 do
      local projectile = Projectile:new()
      if projectile.displayObject then
        sceneGroup:insert(projectile.displayObject)
      end
      projectilePool:release(projectile)
    end
    
    for i = 1, 20 do
      local orb = XPOrb:new()
      if orb.displayObject then
        sceneGroup:insert(orb.displayObject)
      end
      xpOrbPool:release(orb)
    end
    
    -- Move wall to front after pool pre-warming to ensure correct display order
    -- Pool pre-warming inserts 50 objects, which would push wall back in Z-order
    if wall and wall.displayObject then
      wall.displayObject:toFront()
    end
    
    -- Move hero to front after wall to ensure hero is topmost game entity
    -- This maintains correct visual hierarchy: pooled objects → wall → hero
    if hero and hero.displayObject then
      hero.displayObject:toFront()
    end
  end
  
  -- Initialize systems
  combat_system.initialize(hero, projectilePool, spawner_system.getActiveWalkers())
  spawner_system.initialize(walkerPool, hero.level)
  level_system.initialize(hero, xpOrbPool, M.onLevelUp)
  upgrade_system.initialize(hero, M.onUpgradeSelected)
end

--- Start the game loop
-- Begins the main game update cycle via enterFrame listener
function M.start()
  if gameLoopListener then
    return  -- Already started
  end
  
  isPaused = false
  game_state.resume()
  
  -- Add enterFrame listener for game loop
  gameLoopListener = Runtime:addEventListener("enterFrame", M.update)
end

--- Main game update function (called every frame)
-- Coordinates system updates in the correct order
-- @param event table The enterFrame event
function M.update(event)
  if isPaused or not wall or wall:isDead() then
    return
  end
  
  -- Calculate delta time (event.time is in milliseconds)
  local currentTime = event.time / 1000  -- Convert to seconds
  local dt = (event.time - (M.lastFrameTime or event.time)) / 1000
  M.lastFrameTime = event.time
  
  -- Update game state elapsed time
  game_state.update(dt)
  
  -- Update systems in correct order:
  -- 1. Spawner system (create new enemies)
  spawner_system.update(dt, currentTime)
  
  -- 2. Update spawner difficulty based on hero level
  spawner_system.updateDifficulty(hero.level)
  
  -- 3. Update walker entities (movement)
  -- Walkers stop at Y=1140 (accounting for 20px radius to touch wall at Y=1160)
  local activeWalkers = spawner_system.getActiveWalkers()
  for _, walker in ipairs(activeWalkers) do
    if walker.isActive then
      walker:update(dt, 1140)
    end
  end
  
  -- 4. Collision detection
  -- Check projectile-enemy collisions
  local projectiles = combat_system.getActiveProjectiles()
  local projectileCollisions = collision_system.checkProjectileCollisions(projectiles, activeWalkers)
  
  -- Apply damage from projectile collisions
  for _, collision in ipairs(projectileCollisions) do
    local projectile = collision.projectile
    local enemy = collision.enemy
    
    -- Apply damage to enemy
    combat_system.applyDamage(enemy, projectile.damage)
    
    -- Handle projectile hit (pierce logic)
    projectile:onHit(enemy)
    
    -- If enemy was defeated, spawn XP orb
    if not enemy.isActive then
      level_system.spawnXPOrb(enemy.x, enemy.y)
      game_state.enemiesDefeated = game_state.enemiesDefeated + 1
    end
  end
  
  -- Check wall collisions
  -- Walkers stop at Y=1140 and attack the wall from that position
  local wallCollisions = collision_system.checkWallCollisions(activeWalkers, 1140)
  for _, enemy in ipairs(wallCollisions) do
    -- Set walker wall target and attack state
    enemy.wallTarget = wall
    enemy.isAttackingWall = true
    
    -- Check if enemy can attack (cooldown)
    if currentTime - enemy.lastAttackTime >= enemy.attackCooldown then
      combat_system.applyDamage(wall, enemy.damage)
      wall:flashDamage()
      enemy.lastAttackTime = currentTime
      
      -- Check if wall died
      if wall:isDead() then
        M.onGameOver()
        return
      end
    end
  end
  
  -- Check XP orb collection
  local activeOrbs = level_system.getActiveOrbs()
  level_system.checkOrbCollection(hero.x, hero.y, hero.pickupRadius)
  
  -- 5. Combat system (ability activation and projectile updates)
  combat_system.update(dt, currentTime)
  
  -- 6. Level system (orb lifetime checks)
  level_system.update(dt, currentTime)
end

--- Pause the game
-- Stops game loop updates but keeps state intact
function M.pause()
  isPaused = true
  game_state.pause()
end

--- Resume the game
-- Restarts game loop updates
function M.resume()
  isPaused = false
  game_state.resume()
end

--- Handle level-up event
-- Pauses game and triggers upgrade UI display
-- @param level number The new hero level
function M.onLevelUp(level)
  M.pause()
  
  -- Generate upgrade cards
  local cards = upgrade_system.generateCards(3)
  
  -- Trigger upgrade UI display (handled by scene)
  -- This is a callback that the scene should set
  if M.onLevelUpCallback then
    M.onLevelUpCallback(cards)
  end
end

--- Handle upgrade selection
-- Applies the selected upgrade and resumes the game
-- @param upgrade table The selected upgrade card
function M.onUpgradeSelected(upgrade)
  if upgrade then
    upgrade_system.applyUpgrade(upgrade)
  end
  
  M.resume()
end

--- Handle game over event
-- Ends the game session and transitions to game over scene
function M.onGameOver()
  M.pause()
  
  -- Set final statistics
  game_state.finalLevel = hero.level
  game_state.endGame(false)  -- false = defeat (not victory)
  
  -- Trigger game over callback (handled by scene)
  if M.onGameOverCallback then
    M.onGameOverCallback(game_state.getStatistics())
  end
end

--- Get the hero entity
-- @return Hero The hero entity
function M.getHero()
  return hero
end

--- Get the wall entity
-- @return Wall The wall entity
function M.getWall()
  return wall
end

--- Cleanup game controller resources
-- Removes listeners, cleans up systems, and releases pooled objects
function M.cleanup()
  -- Remove game loop listener
  if gameLoopListener then
    Runtime:removeEventListener("enterFrame", M.update)
    gameLoopListener = nil
  end
  
  -- Cleanup systems
  combat_system.cleanup()
  spawner_system.cleanup()
  level_system.cleanup()
  upgrade_system.cleanup()
  
  -- Destroy hero
  if hero then
    hero:destroy()
    hero = nil
  end
  
  -- Destroy wall
  if wall then
    wall:destroy()
    wall = nil
  end
  
  -- Clear pools
  if walkerPool then
    walkerPool:clear()
    walkerPool = nil
  end
  
  if projectilePool then
    projectilePool:clear()
    projectilePool = nil
  end
  
  if xpOrbPool then
    xpOrbPool:clear()
    xpOrbPool = nil
  end
  
  -- Clear references
  sceneGroup = nil
  isPaused = false
  M.lastFrameTime = nil
end

return M
