-- Tests for Ability Registry
-- Validates ability definition retrieval, instantiation, and unlock status

require("tests.spec_helper")

local ability_registry = require("src.models.ability_registry")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")

describe("Ability Registry", function()
  
  before_each(function()
    -- Initialize with test data
    ability_registry.abilities = {
      arcane_bolt = {
        name = "Arcane Bolt",
        description = "Fires magical projectiles at enemies",
        module = "src.entities.abilities.arcane_bolt",
        unlocked = true,
        maxTier = 5,
        icon = "assets/images/abilities/arcane_bolt.png"
      }
    }
  end)
  
  describe("initialize", function()
    it("loads ability definitions from JSON file", function()
      local success = ability_registry.initialize("data/abilities.json")
      
      assert.is_true(success)
      assert.is_not_nil(ability_registry.abilities.arcane_bolt)
    end)
    
    it("returns false when file not found", function()
      local success = ability_registry.initialize("data/nonexistent.json")
      
      assert.is_false(success)
    end)
  end)
  
  describe("getAbility", function()
    it("returns correct definition for arcane_bolt", function()
      local abilityDef = ability_registry.getAbility("arcane_bolt")
      
      assert.is_not_nil(abilityDef)
      assert.are.equal("Arcane Bolt", abilityDef.name)
      assert.are.equal("src.entities.abilities.arcane_bolt", abilityDef.module)
      assert.is_true(abilityDef.unlocked)
      assert.are.equal(5, abilityDef.maxTier)
    end)
    
    it("returns nil for unknown ability ID", function()
      local abilityDef = ability_registry.getAbility("unknown_ability")
      
      assert.is_nil(abilityDef)
    end)
  end)
  
  describe("createInstance", function()
    it("creates new ability instance for arcane_bolt", function()
      local instance = ability_registry.createInstance("arcane_bolt")
      
      assert.is_not_nil(instance)
      assert.are.equal("arcane_bolt", instance.id)
      assert.are.equal("Arcane Bolt", instance.name)
      assert.are.equal(1.0, instance.cooldown)
      assert.are.equal(10, instance.damage)
      assert.are.equal(400, instance.projectileSpeed)
      assert.are.equal(1, instance.tier)
    end)
    
    it("creates independent instances", function()
      local instance1 = ability_registry.createInstance("arcane_bolt")
      local instance2 = ability_registry.createInstance("arcane_bolt")
      
      assert.is_not_nil(instance1)
      assert.is_not_nil(instance2)
      assert.are_not.equal(instance1, instance2)
      
      -- Modify one instance
      instance1.damage = 20
      
      -- Verify the other instance is unaffected
      assert.are.equal(20, instance1.damage)
      assert.are.equal(10, instance2.damage)
    end)
    
    it("returns nil for unknown ability ID", function()
      local instance = ability_registry.createInstance("unknown_ability")
      
      assert.is_nil(instance)
    end)
    
    it("returns nil when ability definition has no module reference", function()
      -- Temporarily add an ability with missing module reference
      ability_registry.abilities.test_no_module = {
        name = "Test No Module",
        unlocked = true,
        maxTier = 5
      }
      
      local instance = ability_registry.createInstance("test_no_module")
      
      assert.is_nil(instance)
      
      -- Clean up
      ability_registry.abilities.test_no_module = nil
    end)
  end)
  
  describe("isUnlocked", function()
    it("returns true for arcane_bolt (default unlocked)", function()
      local unlocked = ability_registry.isUnlocked("arcane_bolt")
      
      assert.is_true(unlocked)
    end)
    
    it("returns false for unknown ability ID", function()
      local unlocked = ability_registry.isUnlocked("unknown_ability")
      
      assert.is_false(unlocked)
    end)
    
    it("returns false for locked ability", function()
      -- Temporarily add a locked ability for testing
      ability_registry.abilities.test_locked = {
        name = "Test Locked",
        module = "src.entities.abilities.arcane_bolt",
        unlocked = false,
        maxTier = 5
      }
      
      local unlocked = ability_registry.isUnlocked("test_locked")
      
      assert.is_false(unlocked)
      
      -- Clean up
      ability_registry.abilities.test_locked = nil
    end)
  end)
  
  describe("getAllAbilityIds", function()
    it("returns all ability IDs", function()
      local ids = ability_registry.getAllAbilityIds()
      
      assert.is_not_nil(ids)
      assert.are.equal(1, #ids)
      assert.is_true(ids[1] == "arcane_bolt")
    end)
  end)
  
  describe("getUnlockedAbilityIds", function()
    it("returns only unlocked ability IDs", function()
      -- Add a locked ability
      ability_registry.abilities.test_locked = {
        name = "Test Locked",
        module = "src.entities.abilities.arcane_bolt",
        unlocked = false,
        maxTier = 5
      }
      
      local ids = ability_registry.getUnlockedAbilityIds()
      
      assert.is_not_nil(ids)
      assert.are.equal(1, #ids)
      assert.is_true(ids[1] == "arcane_bolt")
      
      -- Clean up
      ability_registry.abilities.test_locked = nil
    end)
  end)
  
end)
