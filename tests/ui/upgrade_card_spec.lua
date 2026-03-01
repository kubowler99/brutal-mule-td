require("tests.spec_helper")

local UpgradeCard = require("src.ui.upgrade_card")

describe("UpgradeCard", function()
  local card
  local upgradeData
  
  before_each(function()
    upgradeData = {
      id = "arcane_bolt_damage",
      type = "tier_upgrade",
      name = "Arcane Bolt Damage",
      description = "+5 damage per bolt",
      icon = "assets/images/upgrades/bolt_dmg.png"
    }
    card = UpgradeCard:new(200, 300, upgradeData)
  end)
  
  after_each(function()
    if card then
      card:destroy()
      card = nil
    end
  end)
  
  describe("initialization", function()
    it("should create an upgrade card with correct position", function()
      assert.is_not_nil(card)
      assert.are.equal(200, card.x)
      assert.are.equal(300, card.y)
    end)
    
    it("should store upgrade data", function()
      assert.are.equal(upgradeData, card.upgradeData)
    end)
    
    it("should create all display elements", function()
      assert.is_not_nil(card.background)
      assert.is_not_nil(card.icon)
      assert.is_not_nil(card.nameText)
      assert.is_not_nil(card.descriptionText)
      assert.is_not_nil(card.group)
    end)
    
    it("should display upgrade name", function()
      assert.are.equal("Arcane Bolt Damage", card.nameText.text)
    end)
    
    it("should display upgrade description", function()
      assert.are.equal("+5 damage per bolt", card.descriptionText.text)
    end)
    
    it("should use green icon color for new abilities", function()
      local newAbilityData = {
        id = "fireball",
        type = "new_ability",
        name = "Fireball",
        description = "Launch a fireball"
      }
      local newCard = UpgradeCard:new(200, 300, newAbilityData)
      
      assert.is_not_nil(newCard.icon)
      newCard:destroy()
    end)
    
    it("should use orange icon color for tier upgrades", function()
      assert.is_not_nil(card.icon)
    end)
    
    it("should handle missing name gracefully", function()
      local dataWithoutName = {
        id = "test",
        type = "tier_upgrade",
        description = "Test description"
      }
      local testCard = UpgradeCard:new(200, 300, dataWithoutName)
      
      assert.are.equal("Unknown", testCard.nameText.text)
      testCard:destroy()
    end)
    
    it("should handle missing description gracefully", function()
      local dataWithoutDesc = {
        id = "test",
        type = "tier_upgrade",
        name = "Test Upgrade"
      }
      local testCard = UpgradeCard:new(200, 300, dataWithoutDesc)
      
      assert.are.equal("", testCard.descriptionText.text)
      testCard:destroy()
    end)
  end)
  
  describe("onTap", function()
    it("should store callback function", function()
      local callback = function() end
      card:onTap(callback)
      
      assert.are.equal(callback, card.callback)
    end)
    
    it("should call callback with upgrade data when tapped", function()
      local callbackCalled = false
      local receivedData = nil
      
      card:onTap(function(data)
        callbackCalled = true
        receivedData = data
      end)
      
      -- Simulate touch event
      local touchEvent = {
        phase = "began",
        x = 200,
        y = 300,
        target = card.background
      }
      card:_handleTouch(touchEvent)
      
      touchEvent.phase = "ended"
      card:_handleTouch(touchEvent)
      
      assert.is_true(callbackCalled)
      assert.are.equal(upgradeData, receivedData)
    end)
    
    it("should provide visual feedback on touch began", function()
      card:onTap(function() end)
      
      local touchEvent = {
        phase = "began",
        x = 200,
        y = 300,
        target = card.background
      }
      card:_handleTouch(touchEvent)
      
      assert.is_true(card.isPressed)
    end)
    
    it("should restore appearance on touch ended", function()
      card:onTap(function() end)
      
      local touchEvent = {
        phase = "began",
        x = 200,
        y = 300,
        target = card.background
      }
      card:_handleTouch(touchEvent)
      
      touchEvent.phase = "ended"
      card:_handleTouch(touchEvent)
      
      assert.is_false(card.isPressed)
    end)
    
    it("should cancel touch when moved outside bounds", function()
      card:onTap(function() end)
      
      -- Begin touch
      local touchEvent = {
        phase = "began",
        x = 200,
        y = 300,
        target = card.background
      }
      card:_handleTouch(touchEvent)
      assert.is_true(card.isPressed)
      
      -- Move outside bounds
      touchEvent.phase = "moved"
      touchEvent.x = 1000
      touchEvent.y = 1000
      card:_handleTouch(touchEvent)
      
      assert.is_false(card.isPressed)
    end)
    
    it("should not call callback when touch cancelled", function()
      local callbackCalled = false
      
      card:onTap(function()
        callbackCalled = true
      end)
      
      local touchEvent = {
        phase = "began",
        x = 200,
        y = 300,
        target = card.background
      }
      card:_handleTouch(touchEvent)
      
      touchEvent.phase = "cancelled"
      card:_handleTouch(touchEvent)
      
      assert.is_false(callbackCalled)
    end)
  end)
  
  describe("destroy", function()
    it("should clean up all display objects", function()
      card:destroy()
      assert.is_nil(card.group)
      assert.is_nil(card.background)
      assert.is_nil(card.icon)
      assert.is_nil(card.nameText)
      assert.is_nil(card.descriptionText)
      assert.is_nil(card.upgradeData)
      assert.is_nil(card.callback)
    end)
  end)
end)
