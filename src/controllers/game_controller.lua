-- Game Controller
-- Orchestrates the main game loop and coordinates all game systems
-- Manages game state transitions, system updates, and scene lifecycle

local pool = require("src.utils.pool")
local Hero = require("src.entities.hero")
local Wall = require("src.entities.wall")
local Walker = require("src.entities.walker")
local Projectile = require("src.entities.projectile")

local ArcaneBolt = require("src.entities.abilities.arcane_bolt")
local combat_system = require("src.systems.combat_system")
local spawner_system = require("src.systems.spawner_system")
local experience_system = require("src.systems.experience_system")
local upgrade_system = require("src.systems.upgrade_system")
local collision_system = require("src.systems.collision_system")
local game_state = require("src.models.game_state")
local ability_data_loader = require("src.models.ability_data_loader")
local ability_registry = require("src.models.ability_registry")
local config_loader = require("src.models.config_loader")
local meta_progression = require("src.models.meta_progression")
local effects = require("src.systems.effects")
local sound = require("src.systems.sound")

local M = {}

-- Internal state
local hero
local wall
local walkerPool
local projectilePool
local sceneGroup
local gameLoopListener
local isPaused = false

-- Longest frame step simulated at once. Solar2D stops sending frames while
-- the app is suspended, so the first frame back can span minutes; capping it
-- stops enemies from jumping forward.
local MAX_FRAME_DT = 0.1

-- Screen shake (pixels) for heavy wall hits and boss arrivals
local HEAVY_HIT_DAMAGE = 10
local HEAVY_HIT_SHAKE = 4
local BOSS_HIT_SHAKE = 8
local BOSS_SPAWN_SHAKE = 6

--- Initialize the game controller and set up game session
-- Creates hero, initializes object pools, and sets up all systems
-- @param group table The scene group to add display objects to
-- @param heroId string|nil Hero for this run (default: the selected hero)
function M.initialize(group, heroId)
  sceneGroup = group
  isPaused = false
  
  -- Initialize data loaders before any entity or system that depends on them
  ability_data_loader.initialize()
  ability_registry.initialize()
  config_loader.initialize()
  
  -- Initialize game state
  game_state.initialize()
  
  -- Hero choice and permanent upgrades for this run
  heroId = heroId or meta_progression.getSelectedHeroId()
  local heroDefinition = heroId and meta_progression.getHero(heroId)
  local bonuses = meta_progression.getRunBonuses(heroId)
  
  -- Create wall at fixed position (360, 1200, display.contentWidth)
  -- Wall is positioned at Y=1200 with height 80
  wall = Wall:new(360, 1200, display.contentWidth)
  wall.maxHealth = wall.maxHealth + bonuses.wallHealth
  wall.health = wall.maxHealth
  
  -- Add wall display object to scene group FIRST (renders behind hero)
  if wall.displayObject and sceneGroup then
    sceneGroup:insert(wall.displayObject)
  end
  
  -- Create hero at fixed position (60, 1200)
  -- Hero is positioned on the left side of the wall at wall's center Y
  -- Positioned at X=60 to maintain 5px gap from first ability indicator (left edge at X=95)
  hero = Hero:new(45, 1200)
  hero.heroId = heroId
  hero.baseStats.damageMultiplier = bonuses.damageMultiplier
  hero.baseStats.cooldownMultiplier = bonuses.cooldownMultiplier
  hero.baseStats.lowWallDamageBonus = bonuses.lowWallDamageMultiplier
  hero.xpMultiplier = bonuses.xpMultiplier
  if heroDefinition and type(heroDefinition.color) == "table" then
    hero:setColor(heroDefinition.color)
  end
  
  -- Add the hero's starting ability (Arcane Bolt if none is defined)
  local startingAbility = heroDefinition and heroDefinition.startingAbility
    and ability_registry.createInstance(heroDefinition.startingAbility)
  hero:addAbility(startingAbility or ArcaneBolt:new())
  
  -- Add hero display object to scene group AFTER wall (renders in front)
  if hero.displayObject and sceneGroup then
    sceneGroup:insert(hero.displayObject)
  end
  
  -- Initialize object pools
  walkerPool = pool.new(
    function() return Walker:new(sceneGroup) end,
    nil  -- No reset function, we'll call activate manually
  )
  
  projectilePool = pool.new(
    function() return Projectile:new(sceneGroup) end,
    nil  -- No reset function, we'll call activate manually
  )
  
  -- Add display objects from pools to scene group
  if sceneGroup then
    -- Pre-warm pools and add display objects
    for i = 1, 10 do
      local walker = Walker:new(sceneGroup)
      if walker.displayObject then
        sceneGroup:insert(walker.displayObject)
      end
      walkerPool:release(walker)
    end
    
    for i = 1, 20 do
      local projectile = Projectile:new(sceneGroup)
      if projectile.displayObject then
        sceneGroup:insert(projectile.displayObject)
      end
      projectilePool:release(projectile)
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
  -- IMPORTANT: spawner must be initialized BEFORE combat_system so that
  -- combat_system receives the live activeWalkers reference
  spawner_system.initialize(walkerPool, hero.level)
  combat_system.initialize(hero, projectilePool, spawner_system.getActiveWalkers(), sceneGroup)
  combat_system.onEnemyKilled = M.onEnemyKilled
  combat_system.onEnemyDamaged = M.onEnemyDamaged
  
  -- Feedback: effects draw in the game layer, which also shakes
  effects.initialize(sceneGroup)
  sound.initialize()
  spawner_system.onBossSpawned = M.onBossSpawned
  experience_system.initialize(hero, M.onLevelUp)
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
  
  sound.playMusic()
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
  local dt = math.min((event.time - (M.lastFrameTime or event.time)) / 1000, MAX_FRAME_DT)
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
      
      -- Burn damage goes through combat_system so burn kills are rewarded
      local burnDamage = walker.takePendingBurnDamage and walker:takePendingBurnDamage() or 0
      if burnDamage > 0 then
        combat_system.applyDamage(walker, burnDamage)
      end
    end
  end
  
  -- Let the hero know how damaged the wall is (some heroes get stronger)
  hero.wallHealthRatio = wall.health / wall.maxHealth
  
  -- 4. Collision detection
  -- Check projectile-enemy collisions
  local projectiles = combat_system.getActiveProjectiles()
  local projectileCollisions = collision_system.checkProjectileCollisions(projectiles, activeWalkers)
  
  -- Apply damage from projectile collisions
  for _, collision in ipairs(projectileCollisions) do
    local projectile = collision.projectile
    local enemy = collision.enemy

    -- Collisions are gathered before any damage is applied, so an earlier pair
    -- this frame may have killed the enemy or spent the projectile's pierce.
    -- Skip those pairs so a kill is only rewarded once.
    if enemy.isActive and projectile.isActive then
      -- Apply damage to enemy (kills are rewarded through onEnemyKilled)
      combat_system.applyDamage(enemy, projectile.damage)

      -- On-hit slow from frost projectiles (ignored if the hit killed the enemy)
      if projectile.slowFactor and enemy.isActive and enemy.applySlow then
        enemy:applySlow(projectile.slowFactor, projectile.slowDuration or 0)
      end

      -- Chance to freeze (a full stop for a short time)
      if projectile.freezeChance and enemy.isActive and enemy.applySlow
         and math.random() < projectile.freezeChance then
        enemy:applySlow(0, projectile.freezeDuration or 0)
      end

      -- Handle projectile hit (pierce logic)
      projectile:onHit(enemy)
      
      if projectile.needsRicochet then
        M.ricochet(projectile, activeWalkers)
      end
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
      sound.play("wall_hit")
      
      -- Heavy hits shake the screen
      if enemy.isBoss then
        effects.screenShake(BOSS_HIT_SHAKE, 0.3)
      elseif enemy.damage >= HEAVY_HIT_DAMAGE then
        effects.screenShake(HEAVY_HIT_SHAKE, 0.15)
      end
      
      -- Ranged enemies show a projectile flying to the wall
      if (enemy.attackRange or 0) > 0 then
        M.showRangedAttack(enemy)
      end
      
      -- Check if wall died
      if wall:isDead() then
        M.onGameOver()
        return
      end
    end
  end
  
  -- 5. Combat system (ability activation and projectile updates)
  combat_system.update(dt, currentTime)
  
  -- 6. Screen shake
  effects.update(dt)
end

--- Reward a kill from any damage source
-- Awards XP and counts the kill. Set as combat_system.onEnemyKilled.
-- @param enemy table The enemy that was killed
function M.onEnemyKilled(enemy)
  experience_system.awardXP(enemy.type or "walker", enemy.x, enemy.y, enemy.xpMultiplier)
  game_state.enemiesDefeated = game_state.enemiesDefeated + 1
  
  -- Killing the final boss wins the run
  if enemy.isFinalBoss then
    M.onVictory()
  end
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
  -- Reset lastFrameTime so the first frame after resume doesn't get a huge dt
  M.lastFrameTime = nil
  game_state.resume()
end

--- Handle level-up event
-- Pauses game and triggers upgrade UI display
-- @param level number The new hero level
function M.onLevelUp(level)
  M.pause()
  sound.play("level_up")
  
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

--- Hit feedback for any damage source: number, spark, and sound
-- Set as combat_system.onEnemyDamaged.
-- @param enemy table The enemy that was hit
-- @param amount number Damage dealt
-- @param killed boolean True if the hit killed it
function M.onEnemyDamaged(enemy, amount, killed)
  effects.damageNumber(enemy.x, enemy.y, amount, killed)
  effects.hitSpark(enemy.x, enemy.y)
  sound.play(killed and "enemy_death" or "hit")
end

-- Ricochets only jump to enemies this close to the hit
local RICOCHET_RANGE = 300

--- Send a spent projectile to the nearest enemy it has not hit yet
-- Stops the projectile when no such enemy is in range.
-- @param projectile table The projectile that just used up its pierce
-- @param enemies table Active enemies
function M.ricochet(projectile, enemies)
  local hit = {}
  for _, enemy in ipairs(projectile.hitEnemies or {}) do
    hit[enemy] = true
  end

  local nearest, nearestDistSq = nil, RICOCHET_RANGE * RICOCHET_RANGE
  for _, enemy in ipairs(enemies) do
    if enemy.isActive and not hit[enemy] then
      local dx = enemy.x - projectile.x
      local dy = enemy.y - projectile.y
      local distSq = dx * dx + dy * dy
      if distSq <= nearestDistSq then
        nearest, nearestDistSq = enemy, distSq
      end
    end
  end

  if nearest then
    projectile:redirect(nearest.x, nearest.y)
  else
    projectile:deactivate()
  end
end

-- Ranged attack visual
local SPIT_COLOR = {0.7, 1.0, 0.3}
local SPIT_TRAVEL_MS = 250

--- Draw a short-lived projectile from a ranged enemy to the wall
-- The damage is already applied; this is only feedback.
-- @param enemy table The attacking enemy
function M.showRangedAttack(enemy)
  if not sceneGroup then
    return
  end
  pcall(function()
    local spit = display.newCircle(sceneGroup, enemy.x, enemy.y, 6)
    spit:setFillColor(SPIT_COLOR[1], SPIT_COLOR[2], SPIT_COLOR[3])
    transition.to(spit, {
      time = SPIT_TRAVEL_MS,
      y = 1160,  -- top edge of the wall
      onComplete = function()
        if spit.removeSelf then
          spit:removeSelf()
        end
      end
    })
  end)
end

--- Announce a boss (handled by the scene through onBossSpawnedCallback)
-- @param boss table The boss enemy that spawned
function M.onBossSpawned(boss)
  sound.play("boss")
  effects.screenShake(BOSS_SPAWN_SHAKE, 0.5)
  
  if M.onBossSpawnedCallback then
    M.onBossSpawnedCallback(boss)
  end
end

--- Handle victory (final boss defeated)
-- Ends the run as a win and transitions like game over.
function M.onVictory()
  M.pause()
  sound.play("victory")
  
  game_state.finalLevel = hero.level
  game_state.endGame(true)
  
  if M.onGameOverCallback then
    M.onGameOverCallback(game_state.getStatistics())
  end
end

--- Get the active boss, if any
-- @return table|nil The first active boss enemy
function M.getActiveBoss()
  for _, enemy in ipairs(spawner_system.getActiveWalkers()) do
    if enemy.isActive and enemy.isBoss then
      return enemy
    end
  end
  return nil
end

--- Handle game over event
-- Ends the game session and transitions to game over scene
function M.onGameOver()
  M.pause()
  sound.play("defeat")
  
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
  effects.cleanup()
  sound.cleanup()
  combat_system.cleanup()
  spawner_system.cleanup()
  experience_system.cleanup()
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
  
  -- Clear pools (destroy display objects first)
  if walkerPool then
    for _, walker in ipairs(walkerPool._available or {}) do
      if walker and walker.destroy then
        walker:destroy()
      end
    end
    walkerPool:clear()
    walkerPool = nil
  end
  
  if projectilePool then
    for _, projectile in ipairs(projectilePool._available or {}) do
      if projectile and projectile.destroy then
        projectile:destroy()
      end
    end
    projectilePool:clear()
    projectilePool = nil
  end
  
  -- Clear references
  sceneGroup = nil
  isPaused = false
  M.lastFrameTime = nil
end

return M
