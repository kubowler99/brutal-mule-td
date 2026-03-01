--- Property-based tests for Wall Entity
-- Feature: defensive-wall-entity
-- Tests Properties 1-5, 20

require("tests.spec_helper")

local Wall = require("src.entities.wall")
local combat_system = require("src.systems.combat_system")
local generators = require("tests.generators.game_generators")

describe("Wall Entity Properties", function()
  
  -- Property 1: Wall Initialization
  -- **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
  describe("Property 1: Wall Initialization", function()
    it("should have correct properties for any wall instance", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Generate random wall parameters
        local x = math.random(100, 620)
        local y = math.random(1000, 1280)
        local width = math.random(500, 800)
        
        -- Create wall
        local wall = Wall:new(x, y, width)
        
        -- Verify health initialized to 100
        assert.are.equal(100, wall.health)
        assert.are.equal(100, wall.maxHealth)
        
        -- Verify position properties are numbers
        assert.is.equal("number", type(wall.x))
        assert.is.equal("number", type(wall.y))
        assert.are.equal(x, wall.x)
        assert.are.equal(y, wall.y)
        
        -- Verify width equals provided width
        assert.are.equal(width, wall.width)
        
        -- Verify display object is not nil
        assert.is_not_nil(wall.displayObject)
        
        -- Cleanup
        wall:destroy()
      end
    end)
  end)
  
  -- Property 2: Wall Damage Application
  -- **Validates: Requirements 1.5, 4.3, 4.4**
  describe("Property 2: Wall Damage Application", function()
    it("should reduce health by exact damage amount (clamped to 0)", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create wall
        local wall = Wall:new(360, 1180, 720)
        
        -- Generate random damage amount (0-200)
        local damage = math.random(0, 200)
        
        -- Record initial health
        local initialHealth = wall.health
        
        -- Apply damage
        wall:takeDamage(damage)
        
        -- Calculate expected health (clamped to 0)
        local expectedHealth = math.max(0, initialHealth - damage)
        
        -- Verify health reduced by exact amount (clamped)
        assert.are.equal(expectedHealth, wall.health)
        
        -- Cleanup
        wall:destroy()
      end
    end)
    
    it("should work correctly with combat_system.applyDamage", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create wall
        local wall = Wall:new(360, 1180, 720)
        
        -- Generate random damage amount (0-200)
        local damage = math.random(0, 200)
        
        -- Record initial health
        local initialHealth = wall.health
        
        -- Apply damage through combat system
        combat_system.applyDamage(wall, damage)
        
        -- Calculate expected health (clamped to 0)
        local expectedHealth = math.max(0, initialHealth - damage)
        
        -- Verify health reduced correctly
        assert.are.equal(expectedHealth, wall.health)
        
        -- Cleanup
        wall:destroy()
      end
    end)
  end)
  
  -- Property 3: Wall Death Detection
  -- **Validates: Requirements 1.6**
  describe("Property 3: Wall Death Detection", function()
    it("should return true if and only if health <= 0", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create wall
        local wall = Wall:new(360, 1180, 720)
        
        -- Generate random health value (0-200)
        local health = math.random(0, 200)
        wall.health = health
        
        -- Check isDead
        local isDead = wall:isDead()
        
        -- Verify isDead returns true iff health <= 0
        if health <= 0 then
          assert.is_true(isDead)
        else
          assert.is_false(isDead)
        end
        
        -- Cleanup
        wall:destroy()
      end
    end)
  end)
  
  -- Property 4: Wall Horizontal Centering
  -- **Validates: Requirements 2.2**
  describe("Property 4: Wall Horizontal Centering", function()
    it("should be centered horizontally when created at centerX", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create wall at center X
        local centerX = display.contentWidth / 2
        local wall = Wall:new(centerX, 1180, display.contentWidth)
        
        -- Verify x-coordinate equals half of display content width
        assert.are.equal(centerX, wall.x)
        assert.are.equal(display.contentWidth / 2, wall.x)
        
        -- Cleanup
        wall:destroy()
      end
    end)
  end)
  
  -- Property 5: Wall Position Invariance
  -- **Validates: Requirements 2.4**
  describe("Property 5: Wall Position Invariance", function()
    it("should maintain position after any operations", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create wall
        local wall = Wall:new(360, 1180, 720)
        
        -- Record initial position
        local initialX = wall.x
        local initialY = wall.y
        
        -- Perform various operations
        wall:takeDamage(10)
        wall:flashDamage()
        wall:isDead()
        wall:takeDamage(20)
        
        -- Verify position unchanged
        assert.are.equal(initialX, wall.x)
        assert.are.equal(initialY, wall.y)
        
        -- Cleanup
        wall:destroy()
      end
    end)
  end)
  
  -- Property 20: Wall Damage Feedback
  -- **Validates: Requirements 9.1**
  describe("Property 20: Wall Damage Feedback", function()
    it("should invoke flashDamage when takeDamage is called", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create wall
        local wall = Wall:new(360, 1180, 720)
        
        -- Spy on flashDamage method
        local flashDamageCalled = false
        local originalFlashDamage = wall.flashDamage
        wall.flashDamage = function(self)
          flashDamageCalled = true
          originalFlashDamage(self)
        end
        
        -- Generate random damage
        local damage = math.random(1, 100)
        
        -- Apply damage
        wall:takeDamage(damage)
        
        -- Verify flashDamage was called
        assert.is_true(flashDamageCalled)
        
        -- Cleanup
        wall:destroy()
      end
    end)
  end)
end)
