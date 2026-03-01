require("tests.spec_helper")

local XPBar = require("src.ui.xp_bar")

describe("XPBar", function()
  local xpBar
  
  before_each(function()
    xpBar = XPBar:new(100, 50, 200, 20)
  end)
  
  after_each(function()
    if xpBar then
      xpBar:destroy()
      xpBar = nil
    end
  end)
  
  describe("initialization", function()
    it("should create an XP bar with correct dimensions", function()
      assert.is_not_nil(xpBar)
      assert.are.equal(100, xpBar.x)
      assert.are.equal(50, xpBar.y)
      assert.are.equal(200, xpBar.width)
      assert.are.equal(20, xpBar.height)
    end)
    
    it("should create background and foreground rectangles", function()
      assert.is_not_nil(xpBar.background)
      assert.is_not_nil(xpBar.foreground)
      assert.is_not_nil(xpBar.group)
    end)
  end)
  
  describe("update", function()
    it("should display full bar when XP equals required", function()
      xpBar:update(100, 100)
      assert.are.equal(200, xpBar.foreground.width)
    end)
    
    it("should display half bar when XP is at 50%", function()
      xpBar:update(50, 100)
      assert.are.equal(100, xpBar.foreground.width)
    end)
    
    it("should display empty bar when XP is zero", function()
      xpBar:update(0, 100)
      assert.are.equal(0, xpBar.foreground.width)
    end)
    
    it("should display three-quarter bar when XP is at 75%", function()
      xpBar:update(75, 100)
      assert.are.equal(150, xpBar.foreground.width)
    end)
    
    it("should handle fractional XP values correctly", function()
      xpBar:update(33, 100)
      assert.are.equal(66, xpBar.foreground.width)
    end)
    
    it("should handle different required XP values", function()
      xpBar:update(60, 120)
      assert.are.equal(100, xpBar.foreground.width) -- 60/120 = 0.5
    end)
    
    it("should clamp XP above required to full bar", function()
      xpBar:update(150, 100)
      assert.are.equal(200, xpBar.foreground.width)
    end)
    
    it("should clamp negative XP to empty bar", function()
      xpBar:update(-10, 100)
      assert.are.equal(0, xpBar.foreground.width)
    end)
    
    it("should handle nil current XP gracefully", function()
      xpBar:update(nil, 100)
      -- Should not crash
      assert.is_not_nil(xpBar.foreground)
    end)
    
    it("should handle nil required XP gracefully", function()
      xpBar:update(50, nil)
      -- Should not crash
      assert.is_not_nil(xpBar.foreground)
    end)
    
    it("should handle zero required XP gracefully", function()
      xpBar:update(50, 0)
      -- Should not crash or divide by zero
      assert.is_not_nil(xpBar.foreground)
    end)
  end)
  
  describe("destroy", function()
    it("should clean up all display objects", function()
      xpBar:destroy()
      assert.is_nil(xpBar.group)
      assert.is_nil(xpBar.background)
      assert.is_nil(xpBar.foreground)
    end)
  end)
end)


-- Property-Based Tests
local lqc = require("lqc.quickcheck")
local property = require("lqc.property")
local lqc_gen = require("lqc.lqc_gen")

describe("XPBar - Property-Based Tests", function()
  before_each(function()
    -- Initialize lua-quickcheck
    lqc.init(100, 100)  -- 100 tests, 100 shrinks
  end)
  
  -- Feature: arcane-survivor-mvp, Property 26: XP Bar Accuracy
  describe("Property 26: XP Bar Accuracy", function()
    it("should accurately reflect the ratio of current XP to XP required for next level", function()
      -- **Validates: Requirements 10.3**
      
      -- Define property: For any game state, the displayed XP bar should
      -- accurately reflect the ratio of hero's current XP to XP required for next level
      property "XP bar displays correct fill ratio" {
        generators = {
          lqc_gen.choose(1, 1000),   -- required XP
          lqc_gen.choose(0, 1000)    -- current XP
        },
        check = function(requiredXP, currentXP)
          -- Clamp current XP to required XP
          currentXP = math.min(currentXP, requiredXP)
          
          local xpBar = XPBar:new(100, 50, 200, 20)
          xpBar:update(currentXP, requiredXP)
          
          -- Calculate expected ratio
          local expectedRatio = currentXP / requiredXP
          local expectedWidth = 200 * expectedRatio
          
          -- Check that the foreground width matches the expected ratio
          local actualWidth = xpBar.foreground.width
          local tolerance = 0.01  -- Allow small floating point differences
          
          xpBar:destroy()
          
          return math.abs(actualWidth - expectedWidth) < tolerance
        end
      }
    end)
  end)
end)
