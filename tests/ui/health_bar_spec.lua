require("tests.spec_helper")

local HealthBar = require("src.ui.health_bar")

describe("HealthBar", function()
  local healthBar
  
  before_each(function()
    healthBar = HealthBar:new(100, 50, 200, 20)
  end)
  
  after_each(function()
    if healthBar then
      healthBar:destroy()
      healthBar = nil
    end
  end)
  
  describe("initialization", function()
    it("should create a health bar with correct dimensions", function()
      assert.is_not_nil(healthBar)
      assert.are.equal(100, healthBar.x)
      assert.are.equal(50, healthBar.y)
      assert.are.equal(200, healthBar.width)
      assert.are.equal(20, healthBar.height)
    end)
    
    it("should create background and foreground rectangles", function()
      assert.is_not_nil(healthBar.background)
      assert.is_not_nil(healthBar.foreground)
      assert.is_not_nil(healthBar.group)
    end)
  end)
  
  describe("update", function()
    it("should display full bar when health is at maximum", function()
      healthBar:update(100, 100)
      assert.are.equal(200, healthBar.foreground.width)
    end)
    
    it("should display half bar when health is at 50%", function()
      healthBar:update(50, 100)
      assert.are.equal(100, healthBar.foreground.width)
    end)
    
    it("should display empty bar when health is zero", function()
      healthBar:update(0, 100)
      assert.are.equal(0, healthBar.foreground.width)
    end)
    
    it("should display quarter bar when health is at 25%", function()
      healthBar:update(25, 100)
      assert.are.equal(50, healthBar.foreground.width)
    end)
    
    it("should handle fractional health values correctly", function()
      healthBar:update(33, 100)
      assert.are.equal(66, healthBar.foreground.width)
    end)
    
    it("should clamp health above maximum to full bar", function()
      healthBar:update(150, 100)
      assert.are.equal(200, healthBar.foreground.width)
    end)
    
    it("should clamp negative health to empty bar", function()
      healthBar:update(-10, 100)
      assert.are.equal(0, healthBar.foreground.width)
    end)
    
    it("should handle nil current health gracefully", function()
      healthBar:update(nil, 100)
      -- Should not crash, foreground width should remain unchanged
      assert.is_not_nil(healthBar.foreground)
    end)
    
    it("should handle nil max health gracefully", function()
      healthBar:update(50, nil)
      -- Should not crash
      assert.is_not_nil(healthBar.foreground)
    end)
    
    it("should handle zero max health gracefully", function()
      healthBar:update(50, 0)
      -- Should not crash or divide by zero
      assert.is_not_nil(healthBar.foreground)
    end)
  end)
  
  describe("destroy", function()
    it("should clean up all display objects", function()
      healthBar:destroy()
      assert.is_nil(healthBar.group)
      assert.is_nil(healthBar.background)
      assert.is_nil(healthBar.foreground)
    end)
  end)
end)


-- Property-Based Tests
local lqc = require("lqc.quickcheck")
local property = require("lqc.property")
local lqc_gen = require("lqc.lqc_gen")

describe("HealthBar - Property-Based Tests", function()
  before_each(function()
    -- Initialize lua-quickcheck
    lqc.init(100, 100)  -- 100 tests, 100 shrinks
  end)
  
  -- Feature: arcane-survivor-mvp, Property 25: Health Bar Accuracy
  describe("Property 25: Health Bar Accuracy", function()
    it("should accurately reflect the ratio of current health to maximum health", function()
      -- **Validates: Requirements 10.1**
      
      -- Define property: For any game state, the displayed health bar should
      -- accurately reflect the ratio of hero's current health to maximum health
      property "Health bar displays correct fill ratio" {
        generators = {
          lqc_gen.choose(1, 1000),   -- max health
          lqc_gen.choose(0, 1000)    -- current health
        },
        check = function(maxHealth, currentHealth)
          -- Clamp current health to max health
          currentHealth = math.min(currentHealth, maxHealth)
          
          local healthBar = HealthBar:new(100, 50, 200, 20)
          healthBar:update(currentHealth, maxHealth)
          
          -- Calculate expected ratio
          local expectedRatio = currentHealth / maxHealth
          local expectedWidth = 200 * expectedRatio
          
          -- Check that the foreground width matches the expected ratio
          local actualWidth = healthBar.foreground.width
          local tolerance = 0.01  -- Allow small floating point differences
          
          healthBar:destroy()
          
          return math.abs(actualWidth - expectedWidth) < tolerance
        end
      }
    end)
  end)
end)
