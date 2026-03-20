-- Tests for ability generators
-- Validates that test generators produce valid test data

require("tests.spec_helper")
local ability_generators = require("tests.generators.ability_generators")
local Hero = require("src.entities.hero")

describe("Ability Generators", function()
  
  describe("randomAbilityDefinition", function()
    it("should generate valid ability definition structure", function()
      local generator = ability_generators.randomAbilityDefinition()
      local definition = generator()
      
      assert.is_not_nil(definition)
      assert.is_not_nil(definition.class)
      assert.is_boolean(definition.unlocked)
      assert.is_number(definition.maxTier)
      assert.is_true(definition.maxTier >= 3 and definition.maxTier <= 5)
    end)
  end)
  
  describe("randomHeroState", function()
    it("should generate hero with specified ability count", function()
      for abilityCount = 0, 5 do
        local generator = ability_generators.randomHeroState(abilityCount)
        local hero = generator()
        
        assert.is_not_nil(hero)
        assert.are.equal(abilityCount, #hero.abilities)
      end
    end)
    
    it("should cap ability count at 5", function()
      local generator = ability_generators.randomHeroState(10)
      local hero = generator()
      
      assert.are.equal(5, #hero.abilities)
    end)
  end)
  
  describe("randomUpgradeCard", function()
    it("should generate new_ability card with required fields", function()
      local generator = ability_generators.randomUpgradeCard("new_ability")
      local card = generator()
      
      assert.is_not_nil(card.id)
      assert.are.equal("new_ability", card.type)
      assert.is_not_nil(card.abilityId)
      assert.is_not_nil(card.name)
      assert.is_not_nil(card.description)
      assert.is_not_nil(card.iconType)
      assert.is_function(card.apply)
    end)
    
    it("should generate tier_upgrade card with required fields", function()
      local generator = ability_generators.randomUpgradeCard("tier_upgrade")
      local card = generator()
      
      assert.is_not_nil(card.id)
      assert.are.equal("tier_upgrade", card.type)
      assert.is_function(card.apply)
    end)
    
    it("should generate stat_upgrade card with required fields", function()
      local generator = ability_generators.randomUpgradeCard("stat_upgrade")
      local card = generator()
      
      assert.is_not_nil(card.id)
      assert.are.equal("stat_upgrade", card.type)
      assert.is_function(card.apply)
    end)
  end)
  
  describe("heroWithAvailableSlots", function()
    it("should generate hero with less than 5 abilities", function()
      for i = 1, 10 do
        local generator = ability_generators.heroWithAvailableSlots()
        local hero = generator()
        
        assert.is_true(#hero.abilities < 5)
      end
    end)
  end)
  
  describe("heroWithFullSlots", function()
    it("should generate hero with exactly 5 abilities", function()
      local generator = ability_generators.heroWithFullSlots()
      local hero = generator()
      
      assert.are.equal(5, #hero.abilities)
    end)
  end)
  
  describe("randomAbilityCount", function()
    it("should generate count between 0 and 5", function()
      for i = 1, 20 do
        local generator = ability_generators.randomAbilityCount()
        local count = generator()
        
        assert.is_true(count >= 0 and count <= 5)
      end
    end)
  end)
  
  describe("randomTier", function()
    it("should generate tier between 1 and 5", function()
      for i = 1, 20 do
        local generator = ability_generators.randomTier()
        local tier = generator()
        
        assert.is_true(tier >= 1 and tier <= 5)
      end
    end)
  end)
  
end)
