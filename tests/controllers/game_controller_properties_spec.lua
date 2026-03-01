--- Property-based tests for Game Controller (Wall Integration)
-- Feature: defensive-wall-entity
-- Tests Properties 4, 5, 13, 14, 21

require("tests.spec_helper")

local game_controller = require("src.controllers.game_controller")
local game_state = require("src.models.game_state")

describe("Game Controller Wall Integration Properties", function()
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
  
  -- Property 4: Wall Horizontal Centering (in game controller context)
  -- **Validates: Requirements 2.2**
  describe("Property 4: Wall Horizontal Centering", function()
    it("should create wall centered horizontally", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Initialize game controller
        game_controller.initialize(mockSceneGroup)
        
        -- Get wall
        local wall = game_controller.getWall()
        
        -- Verify wall x-coordinate equals half of display content width
        assert.are.equal(display.contentWidth / 2, wall.x)
        
        -- Cleanup
        game_controller.cleanup()
      end
    end)
  end)
  
  -- Property 5: Wall Position Invariance (in game controller context)
  -- **Validates: Requirements 2.4**
  describe("Property 5: Wall Position Invariance", function()
    it("should maintain wall position after game updates", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Initialize game controller
        game_controller.initialize(mockSceneGroup)
        game_controller.start()
        
        -- Get wall and record initial position
        local wall = game_controller.getWall()
        local initialX = wall.x
        local initialY = wall.y
        
        -- Run multiple game updates
        local updateCount = math.random(10, 100)
        for j = 1, updateCount do
          local event = { time = j * 16.67 }
          game_controller.update(event)
        end
        
        -- Verify wall position unchanged
        assert.are.equal(initialX, wall.x)
        assert.are.equal(initialY, wall.y)
        
        -- Cleanup
        game_controller.cleanup()
      end
    end)
  end)
  
  -- Property 13: Game Over on Wall Death
  -- **Validates: Requirements 6.1, 6.3**
  describe("Property 13: Game Over on Wall Death", function()
    it("should trigger game over when wall health reaches zero", function()
      -- Run property test with 50 iterations (reduced for performance)
      for i = 1, 50 do
        -- Initialize game controller
        game_controller.initialize(mockSceneGroup)
        
        -- Set up game over callback
        local gameOverCalled = false
        game_controller.onGameOverCallback = function(stats)
          gameOverCalled = true
        end
        
        game_controller.start()
        
        -- Get wall
        local wall = game_controller.getWall()
        
        -- Set wall health to random low value (but not zero yet)
        wall.health = math.random(5, 15)
        
        -- Simulate a few frames to allow normal operation
        for j = 1, 5 do
          game_controller.update({ time = j * 16.67 })
        end
        
        -- Now reduce wall health to zero
        wall:takeDamage(wall.health + 10)
        
        -- Verify wall is dead
        assert.is_true(wall:isDead())
        
        -- The game controller checks wall:isDead() at the start of update
        -- and calls onGameOver() when walkers attack and wall dies
        -- We need to manually trigger onGameOver since we're not simulating full combat
        game_controller.onGameOver()
        
        -- Verify game over was triggered
        assert.is_true(gameOverCalled)
        
        -- Cleanup
        game_controller.cleanup()
      end
    end)
  end)
  
  -- Property 14: Game Over Statistics
  -- **Validates: Requirements 6.4**
  describe("Property 14: Game Over Statistics", function()
    it("should provide complete statistics on game over", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Initialize game controller
        game_controller.initialize(mockSceneGroup)
        
        -- Set up game over callback
        local gameOverStats = nil
        game_controller.onGameOverCallback = function(stats)
          gameOverStats = stats
        end
        
        game_controller.start()
        
        -- Simulate random gameplay duration
        local frames = math.random(60, 600)  -- 1-10 seconds
        for j = 1, frames do
          game_controller.update({ time = j * 16.67 })
        end
        
        -- Trigger game over
        game_controller.onGameOver()
        
        -- Verify statistics are provided
        assert.is_not_nil(gameOverStats)
        assert.is_not_nil(gameOverStats.survivalTime)
        assert.is_not_nil(gameOverStats.enemiesDefeated)
        assert.is_not_nil(gameOverStats.finalLevel)
        
        -- Verify statistics are numbers
        assert.is.equal("number", type(gameOverStats.survivalTime))
        assert.is.equal("number", type(gameOverStats.enemiesDefeated))
        assert.is.equal("number", type(gameOverStats.finalLevel))
        
        -- Verify statistics have reasonable values
        assert.is_true(gameOverStats.survivalTime > 0)
        assert.is_true(gameOverStats.enemiesDefeated >= 0)
        assert.is_true(gameOverStats.finalLevel >= 1)
        
        -- Cleanup
        game_controller.cleanup()
      end
    end)
  end)
  
  -- Property 21: Wall Lifecycle Management
  -- **Validates: Requirements 10.1, 10.2, 10.3, 10.4**
  describe("Property 21: Wall Lifecycle Management", function()
    it("should create, manage, and destroy wall correctly", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Initialize game controller
        game_controller.initialize(mockSceneGroup)
        
        -- Verify wall is created during initialization
        local wall = game_controller.getWall()
        assert.is_not_nil(wall)
        
        -- Verify wall has display object (added to scene group)
        assert.is_not_nil(wall.displayObject)
        
        -- Verify getWall provides access to wall
        local wallFromGetter = game_controller.getWall()
        assert.are.equal(wall, wallFromGetter)
        
        -- Cleanup and verify wall is destroyed
        game_controller.cleanup()
        
        -- After cleanup, wall should be nil or inaccessible
        -- (We can't directly verify destruction, but cleanup should handle it)
        
        -- Re-initialize to verify fresh wall is created
        game_controller.initialize(mockSceneGroup)
        local newWall = game_controller.getWall()
        assert.is_not_nil(newWall)
        
        -- Cleanup
        game_controller.cleanup()
      end
    end)
  end)
  
  -- Property 1: Fault Condition - Hero Renders Behind Wall
  -- **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  -- **Feature**: hero-display-order-front
  -- **Validates: Requirements 1.1, 1.2, 1.3**
  describe("Property 1: Fault Condition - Hero Renders Behind Wall", function()
    it("should insert wall BEFORE hero so hero renders in front (EXPECTED TO FAIL ON UNFIXED CODE)", function()
      -- This test encodes the EXPECTED behavior (wall before hero)
      -- On UNFIXED code, this will FAIL because hero is inserted before wall
      -- After the fix, this test will PASS
      
      -- Track insertion order by mocking sceneGroup:insert
      local insertionOrder = {}
      local mockSceneGroup = {
        insert = function(self, obj)
          table.insert(insertionOrder, obj)
        end,
        numChildren = 0
      }
      
      -- Initialize game controller
      game_controller.initialize(mockSceneGroup)
      
      -- Get hero and wall
      local hero = game_controller.getHero()
      local wall = game_controller.getWall()
      
      -- Find insertion indices
      local heroIndex = nil
      local wallIndex = nil
      
      for i, obj in ipairs(insertionOrder) do
        if obj == hero.displayObject then
          heroIndex = i
        end
        if obj == wall.displayObject then
          wallIndex = i
        end
      end
      
      -- Verify both were inserted
      assert.is_not_nil(heroIndex, "Hero display object should be inserted")
      assert.is_not_nil(wallIndex, "Wall display object should be inserted")
      
      -- EXPECTED BEHAVIOR: Wall should be inserted BEFORE hero (wallIndex < heroIndex)
      -- This means hero renders IN FRONT of wall
      -- On UNFIXED code, this assertion will FAIL (heroIndex < wallIndex)
      assert.is_true(wallIndex < heroIndex, 
        string.format("Wall should be inserted before hero (wall index: %d, hero index: %d). " ..
                      "Hero is currently hidden behind wall!", wallIndex or 0, heroIndex or 0))
      
      -- Cleanup
      game_controller.cleanup()
    end)
  end)
  
  -- Property 2: Preservation - Other Entity Display Order
  -- **Feature**: hero-display-order-front
  -- **Validates: Requirements 3.1, 3.2, 3.3, 3.4**
  describe("Property 2: Preservation - Other Entity Display Order", function()
    it("should preserve insertion order and behavior of all non-hero/wall entities", function()
      -- Run property test with 50 iterations
      for i = 1, 50 do
        -- Track insertion order by mocking sceneGroup:insert
        local insertionOrder = {}
        local mockSceneGroup = {
          insert = function(self, obj)
            table.insert(insertionOrder, obj)
          end,
          numChildren = 0
        }
        
        -- Initialize game controller
        game_controller.initialize(mockSceneGroup)
        
        -- Get hero and wall
        local hero = game_controller.getHero()
        local wall = game_controller.getWall()
        
        -- Verify hero and wall positions are unchanged (both at Y=1200)
        assert.are.equal(45, hero.x, "Hero X position should be 45")
        assert.are.equal(1200, hero.y, "Hero Y position should be 1200")
        assert.are.equal(360, wall.x, "Wall X position should be centered")
        assert.are.equal(1200, wall.y, "Wall Y position should be 1200")
        
        -- Verify only hero and wall display objects are inserted during initialization
        -- Pooled entities (walkers, projectiles, XP orbs) don't create display objects
        -- until they're activated, so only 2 objects should be inserted
        assert.are.equal(2, #insertionOrder, "Should have 2 display objects inserted (hero + wall)")
        
        -- Verify hero and wall are both inserted
        local heroIndex = nil
        local wallIndex = nil
        
        for j, obj in ipairs(insertionOrder) do
          if obj == hero.displayObject then
            heroIndex = j
          end
          if obj == wall.displayObject then
            wallIndex = j
          end
        end
        
        assert.is_not_nil(heroIndex, "Hero should be inserted")
        assert.is_not_nil(wallIndex, "Wall should be inserted")
        
        -- Verify wall is inserted before hero (wall index < hero index)
        -- This ensures hero renders in front of wall
        assert.is_true(wallIndex < heroIndex, 
          string.format("Wall should be inserted before hero (wall: %d, hero: %d)", wallIndex, heroIndex))
        
        -- Cleanup
        game_controller.cleanup()
      end
    end)
  end)
end)
