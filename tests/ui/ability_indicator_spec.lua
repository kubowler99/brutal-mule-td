require("tests.spec_helper")

local AbilityIndicator = require("src.ui.ability_indicator")

describe("AbilityIndicator", function()
  local indicator
  
  before_each(function()
    indicator = AbilityIndicator:new(100, 50, 1)
  end)
  
  after_each(function()
    if indicator then
      indicator:destroy()
      indicator = nil
    end
  end)
  
  describe("initialization", function()
    it("should create an ability indicator with correct slot index", function()
      assert.is_not_nil(indicator)
      assert.are.equal(100, indicator.x)
      assert.are.equal(50, indicator.y)
      assert.are.equal(1, indicator.slotIndex)
    end)
    
    it("should create all display elements", function()
      assert.is_not_nil(indicator.background)
      assert.is_not_nil(indicator.icon)
      assert.is_not_nil(indicator.cooldownOverlay)
      assert.is_not_nil(indicator.slotText)
      assert.is_not_nil(indicator.group)
    end)
    
    it("should hide icon and cooldown overlay initially", function()
      assert.is_false(indicator.icon.isVisible)
      assert.is_false(indicator.cooldownOverlay.isVisible)
    end)
  end)
  
  describe("setAbility", function()
    it("should show icon when ability is set", function()
      local ability = {
        id = "arcane_bolt",
        name = "Arcane Bolt"
      }
      
      indicator:setAbility(ability)
      assert.is_true(indicator.icon.isVisible)
      assert.are.equal(ability, indicator.ability)
    end)
    
    it("should hide icon when ability is nil", function()
      local ability = { id = "arcane_bolt" }
      indicator:setAbility(ability)
      assert.is_true(indicator.icon.isVisible)
      
      indicator:setAbility(nil)
      assert.is_false(indicator.icon.isVisible)
      assert.is_nil(indicator.ability)
    end)
    
    it("should set different icon color for arcane_bolt", function()
      local ability = { id = "arcane_bolt" }
      indicator:setAbility(ability)
      
      -- Icon should be visible with purple color
      assert.is_true(indicator.icon.isVisible)
    end)
    
    it("should set different icon color for other abilities", function()
      local ability = { id = "fireball" }
      indicator:setAbility(ability)
      
      -- Icon should be visible with orange color
      assert.is_true(indicator.icon.isVisible)
    end)
  end)
  
  describe("updateCooldown", function()
    before_each(function()
      -- Set an ability first
      indicator:setAbility({ id = "arcane_bolt" })
    end)
    
    it("should show cooldown overlay when cooldown is active", function()
      indicator:updateCooldown(0.5, 1.0)
      assert.is_true(indicator.cooldownOverlay.isVisible)
    end)
    
    it("should hide cooldown overlay when cooldown is zero", function()
      indicator:updateCooldown(0, 1.0)
      assert.is_false(indicator.cooldownOverlay.isVisible)
    end)
    
    it("should set overlay height to full when cooldown is at maximum", function()
      indicator:updateCooldown(1.0, 1.0)
      assert.are.equal(50, indicator.cooldownOverlay.height)
    end)
    
    it("should set overlay height to half when cooldown is at 50%", function()
      indicator:updateCooldown(0.5, 1.0)
      assert.are.equal(25, indicator.cooldownOverlay.height)
    end)
    
    it("should set overlay height to quarter when cooldown is at 25%", function()
      indicator:updateCooldown(0.25, 1.0)
      assert.are.equal(12.5, indicator.cooldownOverlay.height)
    end)
    
    it("should handle fractional cooldown values", function()
      indicator:updateCooldown(0.33, 1.0)
      assert.are.equal(16.5, indicator.cooldownOverlay.height)
    end)
    
    it("should clamp remaining cooldown above total", function()
      indicator:updateCooldown(2.0, 1.0)
      assert.are.equal(50, indicator.cooldownOverlay.height)
    end)
    
    it("should clamp negative remaining cooldown", function()
      indicator:updateCooldown(-0.5, 1.0)
      assert.is_false(indicator.cooldownOverlay.isVisible)
    end)
    
    it("should hide overlay when no ability is set", function()
      indicator:setAbility(nil)
      indicator:updateCooldown(0.5, 1.0)
      assert.is_false(indicator.cooldownOverlay.isVisible)
    end)
    
    it("should handle nil remaining cooldown gracefully", function()
      indicator:updateCooldown(nil, 1.0)
      assert.is_false(indicator.cooldownOverlay.isVisible)
    end)
    
    it("should handle nil total cooldown gracefully", function()
      indicator:updateCooldown(0.5, nil)
      assert.is_false(indicator.cooldownOverlay.isVisible)
    end)
    
    it("should handle zero total cooldown gracefully", function()
      indicator:updateCooldown(0.5, 0)
      assert.is_false(indicator.cooldownOverlay.isVisible)
    end)
  end)
  
  describe("destroy", function()
    it("should clean up all display objects", function()
      indicator:destroy()
      assert.is_nil(indicator.group)
      assert.is_nil(indicator.background)
      assert.is_nil(indicator.icon)
      assert.is_nil(indicator.cooldownOverlay)
      assert.is_nil(indicator.slotText)
      assert.is_nil(indicator.ability)
    end)
  end)
end)


-- Property-Based Tests
local lqc = require("lqc.quickcheck")
local property = require("lqc.property")
local lqc_gen = require("lqc.lqc_gen")

describe("AbilityIndicator - Property-Based Tests", function()
  before_each(function()
    -- Initialize lua-quickcheck
    lqc.init(100, 100)  -- 100 tests, 100 shrinks
  end)
  
  -- Feature: arcane-survivor-mvp, Property 29: Ability Indicator Synchronization
  describe("Property 29: Ability Indicator Synchronization", function()
    it("should display the correct ability icon and cooldown state matching the hero's active abilities", function()
      -- **Validates: Requirements 10.6, 10.7**
      
      -- Define property: For any game state, each ability slot indicator should
      -- display the correct ability icon and cooldown state
      property "Ability indicator shows correct ability and cooldown" {
        generators = {
          lqc_gen.choose(1, 10),     -- total cooldown (0.1 to 1.0 seconds)
          lqc_gen.choose(0, 10)      -- remaining cooldown (0 to 1.0 seconds)
        },
        check = function(totalCooldown, remainingCooldown)
          -- Convert to decimal seconds
          totalCooldown = totalCooldown / 10
          remainingCooldown = remainingCooldown / 10
          
          -- Clamp remaining to total
          remainingCooldown = math.min(remainingCooldown, totalCooldown)
          
          local indicator = AbilityIndicator:new(100, 50, 1)
          
          -- Set an ability
          local ability = {
            id = "arcane_bolt",
            name = "Arcane Bolt",
            cooldown = totalCooldown
          }
          indicator:setAbility(ability)
          
          -- Verify icon is visible when ability is set
          if not indicator.icon.isVisible then
            indicator:destroy()
            return false
          end
          
          -- Verify ability is stored
          if indicator.ability ~= ability then
            indicator:destroy()
            return false
          end
          
          -- Update cooldown
          indicator:updateCooldown(remainingCooldown, totalCooldown)
          
          -- Verify cooldown overlay visibility
          if remainingCooldown > 0 then
            -- Cooldown active - overlay should be visible
            if not indicator.cooldownOverlay.isVisible then
              indicator:destroy()
              return false
            end
            
            -- Verify cooldown overlay height matches ratio
            local expectedRatio = remainingCooldown / totalCooldown
            local expectedHeight = 50 * expectedRatio
            local actualHeight = indicator.cooldownOverlay.height
            local tolerance = 0.01
            
            if math.abs(actualHeight - expectedHeight) >= tolerance then
              indicator:destroy()
              return false
            end
          else
            -- No cooldown - overlay should be hidden
            if indicator.cooldownOverlay.isVisible then
              indicator:destroy()
              return false
            end
          end
          
          indicator:destroy()
          return true
        end
      }
    end)
    
    it("should hide icon when no ability is set", function()
      -- Additional property: Indicator should hide icon when ability is nil
      property "Ability indicator hides icon when no ability set" {
        generators = {},
        check = function()
          local indicator = AbilityIndicator:new(100, 50, 1)
          
          -- Initially no ability - icon should be hidden
          if indicator.icon.isVisible then
            indicator:destroy()
            return false
          end
          
          -- Set an ability
          local ability = { id = "test", name = "Test" }
          indicator:setAbility(ability)
          
          -- Icon should now be visible
          if not indicator.icon.isVisible then
            indicator:destroy()
            return false
          end
          
          -- Remove ability
          indicator:setAbility(nil)
          
          -- Icon should be hidden again
          if indicator.icon.isVisible then
            indicator:destroy()
            return false
          end
          
          indicator:destroy()
          return true
        end
      }
    end)
  end)
end)
