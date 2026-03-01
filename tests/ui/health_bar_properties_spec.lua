--- Property-based tests for Health Bar (Wall Health Display)
-- Feature: defensive-wall-entity
-- Tests Property 15

require("tests.spec_helper")

local HealthBar = require("src.ui.health_bar")
local Wall = require("src.entities.wall")

describe("Health Bar Wall Synchronization Properties", function()
  
  -- Property 15: Health Bar Synchronization
  -- **Validates: Requirements 7.1, 7.2, 7.3**
  describe("Property 15: Health Bar Synchronization", function()
    it("should display correct ratio of current/max health", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create health bar
        local healthBar = HealthBar:new(360, 50, 200, 20)
        
        -- Create wall with random health
        local wall = Wall:new(360, 1180, 720)
        wall.health = math.random(0, 100)
        
        -- Update health bar with wall health
        healthBar:update(wall.health, wall.maxHealth)
        
        -- Calculate expected ratio
        local expectedRatio = wall.health / wall.maxHealth
        
        -- Verify health bar displays correct ratio
        -- The health bar's foreground width should match the ratio
        local fillWidth = healthBar.foreground.width
        local maxWidth = healthBar.background.width
        local actualRatio = fillWidth / maxWidth
        
        -- Allow for small floating point differences
        local ratioDifference = math.abs(actualRatio - expectedRatio)
        assert.is_true(ratioDifference < 0.01)
        
        -- Cleanup
        healthBar:destroy()
        wall:destroy()
      end
    end)
    
    it("should update immediately after wall takes damage", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create health bar and wall
        local healthBar = HealthBar:new(360, 50, 200, 20)
        local wall = Wall:new(360, 1180, 720)
        
        -- Set initial health
        wall.health = 100
        healthBar:update(wall.health, wall.maxHealth)
        
        -- Record initial fill width
        local initialFillWidth = healthBar.foreground.width
        
        -- Apply random damage to wall
        local damage = math.random(10, 50)
        wall:takeDamage(damage)
        
        -- Update health bar immediately
        healthBar:update(wall.health, wall.maxHealth)
        
        -- Verify fill width decreased
        assert.is_true(healthBar.foreground.width < initialFillWidth)
        
        -- Verify new ratio is correct
        local expectedRatio = wall.health / wall.maxHealth
        local actualRatio = healthBar.foreground.width / healthBar.background.width
        local ratioDifference = math.abs(actualRatio - expectedRatio)
        assert.is_true(ratioDifference < 0.01)
        
        -- Cleanup
        healthBar:destroy()
        wall:destroy()
      end
    end)
    
    it("should handle zero health correctly", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create health bar and wall
        local healthBar = HealthBar:new(360, 50, 200, 20)
        local wall = Wall:new(360, 1180, 720)
        
        -- Set wall health to zero
        wall.health = 0
        healthBar:update(wall.health, wall.maxHealth)
        
        -- Verify health bar shows zero (foreground width should be 0 or very small)
        assert.is_true(healthBar.foreground.width <= 1)
        
        -- Cleanup
        healthBar:destroy()
        wall:destroy()
      end
    end)
    
    it("should handle full health correctly", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create health bar and wall
        local healthBar = HealthBar:new(360, 50, 200, 20)
        local wall = Wall:new(360, 1180, 720)
        
        -- Set wall health to full
        wall.health = wall.maxHealth
        healthBar:update(wall.health, wall.maxHealth)
        
        -- Verify health bar shows full (ratio should be 1.0)
        local ratio = healthBar.foreground.width / healthBar.background.width
        assert.is_true(math.abs(ratio - 1.0) < 0.01)
        
        -- Cleanup
        healthBar:destroy()
        wall:destroy()
      end
    end)
  end)
end)
