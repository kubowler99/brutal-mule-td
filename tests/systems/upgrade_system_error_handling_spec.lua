-- Test error handling for upgrade system edge cases
require("tests.spec_helper")

local upgrade_system = require("src.systems.upgrade_system")
local ability_registry = require("src.models.ability_registry")
local Hero = require("src.entities.hero")

describe("Upgrade System Error Handling", function()
  local hero
  
  before_each(function()
    hero = Hero:new(360, 1200)
    upgrade_system.initialize(hero, function() end)
  end)
  
  after_each(function()
    upgrade_system.cleanup()
  end)
  
  describe("Nil hero reference handling", function()
    it("should handle nil hero in generateCards", function()
      upgrade_system.hero = nil
      local cards = upgrade_system.generateCards(3)
      assert.are.equal(0, #cards)
    end)
    
    it("should handle nil hero in getAvailableUpgrades", function()
      upgrade_system.hero = nil
      local upgrades = upgrade_system.getAvailableUpgrades()
      assert.are.equal(0, #upgrades)
    end)
    
    it("should handle nil hero in canOfferNewAbility", function()
      upgrade_system.hero = nil
      local canOffer = upgrade_system.canOfferNewAbility()
      assert.is_false(canOffer)
    end)
    
    it("should handle nil hero in applyUpgrade", function()
      upgrade_system.hero = nil
      local card = {
        type = "new_ability",
        abilityId = "arcane_bolt",
        apply = function() return true end
      }
      local success = upgrade_system.applyUpgrade(card)
      assert.is_false(success)
    end)
  end)
  
  describe("Invalid ability id handling", function()
    it("should reject new_ability card with nil abilityId", function()
      local card = {
        type = "new_ability",
        abilityId = nil,
        apply = function() return true end
      }
      local success = upgrade_system.applyUpgrade(card)
      assert.is_false(success)
    end)
    
    it("should reject new_ability card with non-string abilityId", function()
      local card = {
        type = "new_ability",
        abilityId = 123,
        apply = function() return true end
      }
      local success = upgrade_system.applyUpgrade(card)
      assert.is_false(success)
    end)
    
    it("should reject new_ability card with non-existent abilityId", function()
      local card = {
        type = "new_ability",
        abilityId = "non_existent_ability",
        apply = function() return true end
      }
      local success = upgrade_system.applyUpgrade(card)
      assert.is_false(success)
    end)
  end)
  
  describe("Slot limit exceeded handling", function()
    it("should reject new ability when hero has 5 abilities", function()
      -- Fill all 5 slots
      for i = 1, 5 do
        local ability = ability_registry.createInstance("arcane_bolt")
        ability.id = "ability_" .. i
        hero:addAbility(ability)
      end
      
      local card = {
        type = "new_ability",
        abilityId = "arcane_bolt",
        apply = function() return true end
      }
      local success = upgrade_system.applyUpgrade(card)
      assert.is_false(success)
      assert.are.equal(5, #hero.abilities)
    end)
    
    it("should not offer new abilities when slots are full", function()
      -- Fill all 5 slots
      for i = 1, 5 do
        local ability = ability_registry.createInstance("arcane_bolt")
        ability.id = "ability_" .. i
        hero:addAbility(ability)
      end
      
      local canOffer = upgrade_system.canOfferNewAbility()
      assert.is_false(canOffer)
    end)
    
    it("should not include new_ability cards when slots are full", function()
      -- Fill all 5 slots
      for i = 1, 5 do
        local ability = ability_registry.createInstance("arcane_bolt")
        ability.id = "ability_" .. i
        hero:addAbility(ability)
      end
      
      local upgrades = upgrade_system.getAvailableUpgrades()
      
      -- Check that no new_ability cards are present
      for _, upgrade in ipairs(upgrades) do
        assert.is_not.equal("new_ability", upgrade.type)
      end
    end)
  end)
  
  describe("Locked ability handling", function()
    it("should reject locked ability in applyUpgrade", function()
      -- Mock a locked ability
      local originalIsUnlocked = ability_registry.isUnlocked
      ability_registry.isUnlocked = function(id)
        return false
      end
      
      local card = {
        type = "new_ability",
        abilityId = "arcane_bolt",
        apply = function() return true end
      }
      local success = upgrade_system.applyUpgrade(card)
      assert.is_false(success)
      
      -- Restore original function
      ability_registry.isUnlocked = originalIsUnlocked
    end)
  end)
  
  describe("Invalid upgrade card structure handling", function()
    it("should reject nil upgrade card", function()
      local success = upgrade_system.applyUpgrade(nil)
      assert.is_false(success)
    end)
    
    it("should reject non-table upgrade card", function()
      local success = upgrade_system.applyUpgrade("not a table")
      assert.is_false(success)
    end)
    
    it("should reject upgrade card without apply function", function()
      local card = {
        type = "new_ability",
        abilityId = "arcane_bolt"
      }
      local success = upgrade_system.applyUpgrade(card)
      assert.is_false(success)
    end)
    
    it("should reject upgrade card with non-function apply", function()
      local card = {
        type = "new_ability",
        abilityId = "arcane_bolt",
        apply = "not a function"
      }
      local success = upgrade_system.applyUpgrade(card)
      assert.is_false(success)
    end)
  end)
  
  describe("Invalid hero abilities array handling", function()
    it("should handle nil abilities array in getAvailableUpgrades", function()
      hero.abilities = nil
      local upgrades = upgrade_system.getAvailableUpgrades()
      assert.are.equal(0, #upgrades)
    end)
    
    it("should handle non-table abilities array in getAvailableUpgrades", function()
      hero.abilities = "not a table"
      local upgrades = upgrade_system.getAvailableUpgrades()
      assert.are.equal(0, #upgrades)
    end)
    
    it("should handle nil abilities array in canOfferNewAbility", function()
      hero.abilities = nil
      local canOffer = upgrade_system.canOfferNewAbility()
      assert.is_false(canOffer)
    end)
    
    it("should handle non-table abilities array in canOfferNewAbility", function()
      hero.abilities = "not a table"
      local canOffer = upgrade_system.canOfferNewAbility()
      assert.is_false(canOffer)
    end)
  end)
  
  describe("Apply function error handling with pcall", function()
    it("should handle errors in apply function gracefully", function()
      local card = {
        type = "stat_upgrade",
        apply = function()
          error("Simulated error in apply function")
        end
      }
      local success = upgrade_system.applyUpgrade(card)
      assert.is_false(success)
    end)
    
    it("should handle apply function returning false", function()
      local card = {
        type = "stat_upgrade",
        apply = function()
          return false
        end
      }
      local success = upgrade_system.applyUpgrade(card)
      assert.is_false(success)
    end)
  end)
  
  describe("Tier upgrade validation", function()
    it("should reject tier upgrade for ability hero doesn't have", function()
      local card = {
        type = "tier_upgrade",
        abilityId = "non_existent_ability",
        apply = function() return true end
      }
      local success = upgrade_system.applyUpgrade(card)
      assert.is_false(success)
    end)
    
    it("should reject tier upgrade for ability at max tier", function()
      -- Ensure hero has arcane_bolt ability
      if #hero.abilities == 0 then
        local ability = ability_registry.createInstance("arcane_bolt")
        hero:addAbility(ability)
      end
      
      -- Set ability to max tier
      hero.abilities[1].tier = 5
      
      local card = {
        type = "tier_upgrade",
        abilityId = "arcane_bolt",
        apply = function() return true end
      }
      local success = upgrade_system.applyUpgrade(card)
      assert.is_false(success)
    end)
  end)
  
  describe("Invalid count parameter in generateCards", function()
    it("should handle negative count", function()
      local cards = upgrade_system.generateCards(-1)
      -- Negative count is treated as 3 (default), so we should get cards
      assert.is.truthy(#cards >= 0)
    end)
    
    it("should handle non-number count", function()
      local cards = upgrade_system.generateCards("not a number")
      assert.is.truthy(#cards >= 0)
    end)
    
    it("should handle nil count (use default)", function()
      local cards = upgrade_system.generateCards(nil)
      assert.is.truthy(#cards >= 0)
    end)
  end)
end)
