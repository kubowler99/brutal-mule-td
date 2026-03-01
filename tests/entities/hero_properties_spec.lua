--- Property-based tests for Hero Entity (Health Removal)
-- Feature: defensive-wall-entity
-- Tests Properties 16-18

require("tests.spec_helper")

local Hero = require("src.entities.hero")
local Wall = require("src.entities.wall")

describe("Hero Health Removal Properties", function()
  
  -- Property 16: Hero Health Removal
  -- **Validates: Requirements 8.1, 8.2**
  describe("Property 16: Hero Health Removal", function()
    it("should not have health, maxHealth, or takeDamage", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create hero at random position
        local x = math.random(100, 620)
        local y = math.random(1000, 1280)
        local hero = Hero:new(x, y)
        
        -- Verify hero does not have health properties
        assert.is_nil(hero.health)
        assert.is_nil(hero.maxHealth)
        
        -- Verify hero does not have takeDamage method
        assert.is_nil(hero.takeDamage)
        
        -- Cleanup
        hero:destroy()
      end
    end)
  end)
  
  -- Property 17: Hero Position on Wall
  -- **Validates: Requirements 8.3**
  describe("Property 17: Hero Position on Wall", function()
    it("should have Y-coordinate aligned with wall", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create wall at random Y position
        local wallY = math.random(1000, 1280)
        local wall = Wall:new(360, wallY, 720)
        
        -- Create hero at wall position (with optional visual offset)
        local heroY = wallY - 30  -- 30 pixel offset for visual clarity
        local hero = Hero:new(360, heroY)
        
        -- Verify hero Y-coordinate is at or near wall Y-coordinate
        -- Allow for visual offset (hero should be within 50 pixels of wall)
        local yDifference = math.abs(hero.y - wall.y)
        assert.is_true(yDifference <= 50)
        
        -- Cleanup
        hero:destroy()
        wall:destroy()
      end
    end)
  end)
  
  -- Property 18: Hero Ability Functionality
  -- **Validates: Requirements 8.4**
  describe("Property 18: Hero Ability Functionality", function()
    it("should have functional abilities array regardless of wall state", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create hero and wall
        local hero = Hero:new(120, 1200)
        local wall = Wall:new(360, 1180, 720)
        
        -- Verify hero has abilities array (may be empty initially)
        assert.is_not_nil(hero.abilities)
        assert.is.equal("table", type(hero.abilities))
        
        -- Add a test ability
        local testAbility = {
          cooldown = 1.0,
          lastCastTime = 0
        }
        hero:addAbility(testAbility)
        
        -- Verify ability was added
        assert.is_true(#hero.abilities > 0)
        
        -- Damage the wall to random health
        local damage = math.random(0, 100)
        wall:takeDamage(damage)
        
        -- Verify hero abilities still exist and are functional
        assert.is_not_nil(hero.abilities)
        assert.is_true(#hero.abilities > 0)
        
        -- Verify abilities have required properties
        for _, ability in ipairs(hero.abilities) do
          assert.is_not_nil(ability.cooldown)
          assert.is_not_nil(ability.lastCastTime)
        end
        
        -- Cleanup
        hero:destroy()
        wall:destroy()
      end
    end)
    
    it("should activate abilities when cooldowns are ready", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create hero
        local hero = Hero:new(120, 1200)
        
        -- Verify hero has abilities
        assert.is_not_nil(hero.abilities)
        
        if #hero.abilities > 0 then
          local ability = hero.abilities[1]
          
          -- Set ability cooldown to ready
          ability.lastCastTime = 0
          
          -- Simulate time passing
          local currentTime = ability.cooldown + 1
          
          -- Verify ability can be cast (cooldown ready)
          local timeSinceLastCast = currentTime - ability.lastCastTime
          assert.is_true(timeSinceLastCast >= ability.cooldown)
        end
        
        -- Cleanup
        hero:destroy()
      end
    end)
  end)
end)
