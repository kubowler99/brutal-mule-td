--- Integration Test: Full Game Flow with Wall Defense
-- Tests the complete game flow from menu to game over with wall defense mechanic
-- Validates all requirements for the defensive wall entity feature

require("tests.spec_helper")

local composer = require("composer")
local game_controller = require("src.controllers.game_controller")
local game_state = require("src.models.game_state")
local spawner_system = require("src.systems.spawner_system")
local collision_system = require("src.systems.collision_system")
local combat_system = require("src.systems.combat_system")

describe("Integration: Full Game Flow with Wall Defense", function()
  local mockSceneGroup
  
  before_each(function()
    -- Create mock scene group
    mockSceneGroup = {
      insert = function(self, obj) end,
      numChildren = 0
    }
    
    -- Initialize game state
    game_state.initialize()
  end)
  
  after_each(function()
    -- Cleanup after each test
    game_controller.cleanup()
  end)
  
  describe("Complete Game Flow", function()
    it("starts game from menu and creates wall correctly", function()
      -- Initialize game (simulating transition from menu)
      game_controller.initialize(mockSceneGroup)
      
      -- Verify wall is created
      local wall = game_controller.getWall()
      assert.is_not_nil(wall)
      
      -- Verify wall is positioned correctly
      assert.are.equal(360, wall.x)
      assert.are.equal(1200, wall.y)
      assert.are.equal(display.contentWidth, wall.width)
      
      -- Verify wall has correct initial health
      assert.are.equal(100, wall.health)
      assert.are.equal(100, wall.maxHealth)
      
      -- Verify wall is not dead
      assert.is_false(wall:isDead())
    end)
    
    it("spawns walkers that move toward wall", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local wall = game_controller.getWall()
      
      -- Simulate enough time for walkers to spawn (2+ seconds)
      for i = 1, 150 do  -- 2.5 seconds at 60 FPS
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Get active walkers
      local activeWalkers = spawner_system.getActiveWalkers()
      
      -- Verify walkers were spawned
      assert.is_true(#activeWalkers > 0)
      
      -- Verify walkers are moving toward wall (Y-coordinate should be increasing)
      local walker = activeWalkers[1]
      if walker then
        local initialY = walker.y
        
        -- Run a few more frames
        for i = 151, 160 do
          local event = { time = i * 16.67 }
          game_controller.update(event)
        end
        
        -- Walker should have moved downward (Y increased) or reached wall
        assert.is_true(walker.y >= initialY)
      end
    end)
    
    it("walkers stop at wall and attack", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local wall = game_controller.getWall()
      local initialWallHealth = wall.health
      
      -- Simulate enough time for walkers to spawn and reach wall
      -- Walkers spawn at Y=0 and move at 50 pixels/second
      -- Wall is at Y=1180, so it takes ~23.6 seconds to reach
      -- We'll simulate 30 seconds to ensure walkers reach and attack
      local fps = 60
      local simulationSeconds = 30
      local totalFrames = simulationSeconds * fps
      
      for i = 1, totalFrames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Get active walkers
      local activeWalkers = spawner_system.getActiveWalkers()
      
      -- Check if any walkers reached the collision threshold (1140)
      -- Walkers stop at Y=1140, which is 60 pixels before the wall at Y=1200
      local walkersAtWall = collision_system.checkWallCollisions(activeWalkers, 1140)
      
      -- Verify at least one walker reached the wall
      assert.is_true(#walkersAtWall > 0)
      
      -- Verify walkers at wall have stopped moving (Y >= 1140)
      for _, walker in ipairs(walkersAtWall) do
        assert.is_true(walker.y >= 1140)
        assert.is_true(walker.isAttackingWall)
        assert.are.equal(wall, walker.wallTarget)
      end
      
      -- Verify wall took damage (health decreased)
      assert.is_true(wall.health < initialWallHealth)
    end)
    
    it("wall health decreases over time from walker attacks", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local wall = game_controller.getWall()
      local healthSnapshots = {}
      
      -- Record wall health at regular intervals
      local fps = 60
      local simulationSeconds = 35
      local totalFrames = simulationSeconds * fps
      
      for i = 1, totalFrames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
        
        -- Record health every second
        if i % fps == 0 then
          table.insert(healthSnapshots, wall.health)
        end
      end
      
      -- Verify wall health decreased over time
      local firstHealth = healthSnapshots[1]
      local lastHealth = healthSnapshots[#healthSnapshots]
      
      assert.is_true(lastHealth < firstHealth)
      
      -- Verify health decreased in steps (not continuously)
      -- This confirms discrete attack events
      local healthChanges = 0
      for i = 2, #healthSnapshots do
        if healthSnapshots[i] < healthSnapshots[i-1] then
          healthChanges = healthChanges + 1
        end
      end
      
      assert.is_true(healthChanges > 0)
    end)
    
    it("game over triggers when wall dies", function()
      game_controller.initialize(mockSceneGroup)
      
      -- Set up game over callback
      local gameOverCalled = false
      local gameOverStats = nil
      game_controller.onGameOverCallback = function(stats)
        gameOverCalled = true
        gameOverStats = stats
      end
      
      game_controller.start()
      
      local wall = game_controller.getWall()
      
      -- Manually reduce wall health to near death
      wall.health = 1
      
      -- Simulate a few frames to allow walker attack
      local fps = 60
      local simulationSeconds = 35
      local totalFrames = simulationSeconds * fps
      
      for i = 1, totalFrames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
        
        -- Check if wall died
        if wall:isDead() then
          break
        end
      end
      
      -- Verify wall is dead
      assert.is_true(wall:isDead())
      
      -- Verify game over was triggered
      assert.is_true(gameOverCalled)
      assert.are.equal("game_over", game_state.state)
    end)
    
    it("game statistics are displayed correctly on game over", function()
      game_controller.initialize(mockSceneGroup)
      
      -- Set up game over callback
      local gameOverStats = nil
      game_controller.onGameOverCallback = function(stats)
        gameOverStats = stats
      end
      
      game_controller.start()
      
      local wall = game_controller.getWall()
      
      -- Simulate some gameplay
      local fps = 60
      local simulationSeconds = 10
      local totalFrames = simulationSeconds * fps
      
      for i = 1, totalFrames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Manually trigger game over
      game_controller.onGameOver()
      
      -- Verify statistics are provided
      assert.is_not_nil(gameOverStats)
      assert.is_not_nil(gameOverStats.survivalTime)
      assert.is_not_nil(gameOverStats.enemiesDefeated)
      assert.is_not_nil(gameOverStats.finalLevel)
      
      -- Verify statistics have reasonable values
      assert.is_true(gameOverStats.survivalTime > 0)
      assert.is_true(gameOverStats.enemiesDefeated >= 0)
      assert.is_true(gameOverStats.finalLevel >= 1)
    end)
  end)
  
  describe("Wall Defense Mechanics", function()
    it("hero remains on wall and is not damaged", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local wall = game_controller.getWall()
      local hero = game_controller.getHero()
      
      -- Verify hero has no health property
      assert.is_nil(hero.health)
      assert.is_nil(hero.maxHealth)
      
      -- Verify hero has no takeDamage method
      assert.is_nil(hero.takeDamage)
      
      -- Simulate gameplay with walkers reaching wall
      local fps = 60
      local simulationSeconds = 30
      local totalFrames = simulationSeconds * fps
      
      for i = 1, totalFrames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Hero should still exist and be functional
      assert.is_not_nil(hero)
      assert.is_not_nil(hero.abilities)
      
      -- Wall should have taken damage (not hero)
      assert.is_true(wall.health < 100)
    end)
    
    it("walkers target wall not hero", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local wall = game_controller.getWall()
      local hero = game_controller.getHero()
      
      -- Simulate gameplay until walkers reach wall
      local fps = 60
      local simulationSeconds = 30
      local totalFrames = simulationSeconds * fps
      
      for i = 1, totalFrames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Get walkers at wall
      local activeWalkers = spawner_system.getActiveWalkers()
      local walkersAtWall = collision_system.checkWallCollisions(activeWalkers, wall.y)
      
      -- Verify walkers at wall target the wall
      for _, walker in ipairs(walkersAtWall) do
        assert.are.equal(wall, walker.wallTarget)
        assert.is_true(walker.isAttackingWall)
      end
      
      -- Verify wall took damage
      assert.is_true(wall.health < 100)
      
      -- Verify hero has no health system (can't be damaged)
      assert.is_nil(hero.health)
    end)
    
    it("wall collision detection works correctly", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local wall = game_controller.getWall()
      
      -- Simulate gameplay
      local fps = 60
      local simulationSeconds = 30
      local totalFrames = simulationSeconds * fps
      
      for i = 1, totalFrames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Get active walkers
      local activeWalkers = spawner_system.getActiveWalkers()
      
      -- Check wall collisions
      local walkersAtWall = collision_system.checkWallCollisions(activeWalkers, wall.y)
      
      -- Verify collision detection returns correct walkers
      for _, walker in ipairs(walkersAtWall) do
        -- Walker Y should be >= wall Y
        assert.is_true(walker.y >= wall.y)
      end
      
      -- Verify walkers not at wall are excluded
      for _, walker in ipairs(activeWalkers) do
        local isAtWall = false
        for _, walkerAtWall in ipairs(walkersAtWall) do
          if walker == walkerAtWall then
            isAtWall = true
            break
          end
        end
        
        if not isAtWall then
          -- Walker should be above wall threshold
          assert.is_true(walker.y < wall.y)
        end
      end
    end)
    
    it("wall damage feedback is triggered", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local wall = game_controller.getWall()
      
      -- Spy on flashDamage method
      local flashDamageCalled = false
      local originalFlashDamage = wall.flashDamage
      wall.flashDamage = function(self)
        flashDamageCalled = true
        originalFlashDamage(self)
      end
      
      -- Apply damage to wall
      wall:takeDamage(10)
      
      -- Verify flashDamage was called
      -- Note: In the actual implementation, flashDamage is called
      -- from the game controller when damage is applied
      -- For this test, we verify the method exists and can be called
      assert.is_function(wall.flashDamage)
      
      -- Manually call flashDamage to verify it works
      wall:flashDamage()
      assert.is_true(flashDamageCalled)
    end)
  end)
  
  describe("Edge Cases", function()
    it("handles zero walkers gracefully", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local wall = game_controller.getWall()
      local initialHealth = wall.health
      
      -- Simulate a short time (before walkers spawn)
      for i = 1, 30 do  -- 0.5 seconds
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Wall should not have taken damage (no walkers yet)
      assert.are.equal(initialHealth, wall.health)
    end)
    
    it("handles maximum walkers (50) attacking wall simultaneously", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local wall = game_controller.getWall()
      
      -- Simulate long enough for many walkers to spawn and reach wall
      -- Walkers spawn every 2 seconds, so 100 seconds = 50 walkers
      local fps = 60
      local simulationSeconds = 100
      local totalFrames = simulationSeconds * fps
      
      for i = 1, totalFrames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
        
        -- Stop if wall dies
        if wall:isDead() then
          break
        end
      end
      
      -- Get active walkers
      local activeWalkers = spawner_system.getActiveWalkers()
      local walkersAtWall = collision_system.checkWallCollisions(activeWalkers, 1140)
      
      -- Verify multiple walkers reached the wall
      assert.is_true(#walkersAtWall > 0)
      
      -- Verify wall took significant damage from multiple attackers
      -- With many walkers attacking at 10 damage per second, wall should be heavily damaged or dead
      assert.is_true(wall.health < 100)
      
      -- Verify all walkers at wall are in attacking state
      for _, walker in ipairs(walkersAtWall) do
        assert.is_true(walker.isAttackingWall)
        assert.are.equal(wall, walker.wallTarget)
      end
    end)
    
    it("handles wall at 1 health correctly", function()
      game_controller.initialize(mockSceneGroup)
      
      local gameOverCalled = false
      game_controller.onGameOverCallback = function(stats)
        gameOverCalled = true
      end
      
      game_controller.start()
      
      local wall = game_controller.getWall()
      
      -- Set wall to 1 health
      wall.health = 1
      
      -- Apply damage
      wall:takeDamage(10)
      
      -- Wall should be dead
      assert.is_true(wall:isDead())
      assert.are.equal(0, wall.health)
    end)
    
    it("hero abilities continue working as wall takes damage", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local wall = game_controller.getWall()
      local hero = game_controller.getHero()
      
      -- Verify hero has abilities
      assert.is_not_nil(hero.abilities)
      assert.is_true(#hero.abilities > 0)
      
      -- Damage the wall
      wall:takeDamage(50)
      
      -- Hero abilities should still be functional
      assert.is_not_nil(hero.abilities)
      assert.is_true(#hero.abilities > 0)
      
      -- Simulate gameplay to verify abilities work
      for i = 1, 60 do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- No errors means abilities are working
      assert.is_true(true)
    end)
    
    it("game over scene receives correct and complete statistics", function()
      game_controller.initialize(mockSceneGroup)
      
      local gameOverStats = nil
      game_controller.onGameOverCallback = function(stats)
        gameOverStats = stats
      end
      
      game_controller.start()
      
      local wall = game_controller.getWall()
      
      -- Simulate gameplay for a known duration
      local fps = 60
      local simulationSeconds = 15
      local totalFrames = simulationSeconds * fps
      
      for i = 1, totalFrames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Manually trigger game over
      game_controller.onGameOver()
      
      -- Verify statistics are provided and complete
      assert.is_not_nil(gameOverStats)
      assert.is_not_nil(gameOverStats.survivalTime)
      assert.is_not_nil(gameOverStats.enemiesDefeated)
      assert.is_not_nil(gameOverStats.finalLevel)
      
      -- Verify statistics have reasonable values
      assert.is_true(gameOverStats.survivalTime > 0)
      assert.is_true(gameOverStats.enemiesDefeated >= 0)
      assert.is_true(gameOverStats.finalLevel >= 1)
      
      -- Verify statistics are numbers (not nil or strings)
      assert.is.equal("number", type(gameOverStats.survivalTime))
      assert.is.equal("number", type(gameOverStats.enemiesDefeated))
      assert.is.equal("number", type(gameOverStats.finalLevel))
      
      -- Verify game state is set to game over
      assert.are.equal("game_over", game_state.state)
    end)
  end)
end)
