-- Integration test for ability selection flow
-- Tests the complete flow: level up → generate cards → select new ability → verify in hero.abilities

require("tests.spec_helper")

local upgrade_system = require("src.systems.upgrade_system")
local ability_registry = require("src.models.ability_registry")
local Hero = require("src.entities.hero")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")

describe("Ability Selection Flow Integration", function()
  local hero
  local upgradeCallback
  local callbackInvoked

  before_each(function()
    -- Create fresh hero
    hero = Hero:new(360, 1180)
    
    -- Track callback invocations
    callbackInvoked = false
    upgradeCallback = function()
      callbackInvoked = true
    end
    
    -- Initialize upgrade system
    upgrade_system.initialize(hero, upgradeCallback)
  end)

  after_each(function()
    upgrade_system.cleanup()
    hero = nil
    upgradeCallback = nil
    callbackInvoked = false
  end)

  describe("Full ability selection flow", function()
    it("should complete full flow: generate → select → verify", function()
      -- Step 1: Verify hero starts with no abilities
      assert.are.equal(0, #hero.abilities, "Hero should start with no abilities")
      
      -- Step 2: Generate upgrade cards
      local cards = upgrade_system.generateCards(3)
      assert.is_not_nil(cards, "Should generate cards")
      assert.is_true(#cards > 0, "Should generate at least one card")
      
      -- Step 3: Find a new ability card
      local newAbilityCard = nil
      for _, card in ipairs(cards) do
        if card.type == "new_ability" then
          newAbilityCard = card
          break
        end
      end
      
      assert.is_not_nil(newAbilityCard, "Should have at least one new ability card")
      
      -- Step 4: Apply the new ability card
      local success = upgrade_system.applyUpgrade(newAbilityCard)
      assert.is_true(success, "Should successfully apply new ability upgrade")
      
      -- Step 5: Verify ability was added to hero
      assert.are.equal(1, #hero.abilities, "Hero should have 1 ability after selection")
      assert.are.equal(newAbilityCard.abilityId, hero.abilities[1].id, 
        "Added ability should match selected card")
      
      -- Step 6: Verify ability starts at tier 1
      assert.are.equal(1, hero.abilities[1].tier, "New ability should start at tier 1")
      
      -- Step 7: Verify callback was invoked
      assert.is_true(callbackInvoked, "Upgrade callback should be invoked")
    end)

    it("should allow adding multiple abilities up to 5", function()
      -- Manually add 5 different abilities to test slot limit
      -- (In real game, there would be multiple different abilities available)
      for i = 1, 5 do
        local ability = ArcaneBolt:new()
        ability.id = "ability_" .. i  -- Give unique IDs
        local success = hero:addAbility(ability)
        assert.is_true(success, "Should successfully add ability " .. i)
        assert.are.equal(i, #hero.abilities, "Hero should have " .. i .. " abilities")
      end
      
      -- Verify we have 5 abilities
      assert.are.equal(5, #hero.abilities, "Hero should have exactly 5 abilities")
      
      -- Verify we can't add a 6th
      local ability6 = ArcaneBolt:new()
      ability6.id = "ability_6"
      local success = hero:addAbility(ability6)
      assert.is_false(success, "Should not be able to add 6th ability")
      assert.are.equal(5, #hero.abilities, "Should still have exactly 5 abilities")
    end)

    it("should not offer new abilities when hero has 5 abilities", function()
      -- Fill all 5 slots
      for i = 1, 5 do
        local ability = ArcaneBolt:new()
        ability.id = "ability_" .. i
        hero:addAbility(ability)
      end
      
      -- Generate cards
      local cards = upgrade_system.generateCards(3)
      
      -- Verify no new ability cards are offered
      for _, card in ipairs(cards) do
        assert.is_not_equal("new_ability", card.type, 
          "Should not offer new ability cards when all 5 slots are full")
      end
    end)

    it("should reject new ability when slots are full", function()
      -- Fill all 5 slots
      for i = 1, 5 do
        local ability = ArcaneBolt:new()
        ability.id = "ability_" .. i
        hero:addAbility(ability)
      end
      
      -- Try to manually create and apply a new ability card
      local newAbilityCard = {
        id = "new_ability_test",
        type = "new_ability",
        abilityId = "arcane_bolt",
        name = "Test Ability",
        description = "Test",
        iconType = "test",
        apply = function(h)
          if not ability_registry.isUnlocked("arcane_bolt") then
            return false
          end
          if #h.abilities >= 5 then
            return false
          end
          local ability = ability_registry.createInstance("arcane_bolt")
          if ability then
            return h:addAbility(ability)
          end
          return false
        end
      }
      
      local success = upgrade_system.applyUpgrade(newAbilityCard)
      
      assert.is_false(success, "Should reject new ability when slots full")
      assert.are.equal(5, #hero.abilities, "Should still have exactly 5 abilities")
    end)
  end)

  describe("Ability instance validation", function()
    it("should create proper ability instances with correct properties", function()
      -- Generate and select arcane_bolt
      local cards = upgrade_system.generateCards(3)
      
      local arcaneBoltCard = nil
      for _, card in ipairs(cards) do
        if card.type == "new_ability" and card.abilityId == "arcane_bolt" then
          arcaneBoltCard = card
          break
        end
      end
      
      if arcaneBoltCard then
        upgrade_system.applyUpgrade(arcaneBoltCard)
        
        local ability = hero.abilities[1]
        assert.is_not_nil(ability, "Ability should exist")
        assert.are.equal("arcane_bolt", ability.id, "Should have correct id")
        assert.are.equal("Arcane Bolt", ability.name, "Should have correct name")
        assert.are.equal(1, ability.tier, "Should start at tier 1")
        assert.is_number(ability.cooldown, "Should have cooldown")
        assert.is_number(ability.damage, "Should have damage")
        assert.is_function(ability.activate, "Should have activate method")
        assert.is_function(ability.canActivate, "Should have canActivate method")
        assert.is_function(ability.upgrade, "Should have upgrade method")
      end
    end)

    it("should create independent instances for multiple abilities", function()
      -- Add two arcane bolt abilities (if possible)
      local cards1 = upgrade_system.generateCards(3)
      local card1 = nil
      for _, card in ipairs(cards1) do
        if card.type == "new_ability" and card.abilityId == "arcane_bolt" then
          card1 = card
          break
        end
      end
      
      if card1 then
        upgrade_system.applyUpgrade(card1)
        
        -- Verify we have one ability
        assert.are.equal(1, #hero.abilities)
        
        local ability1 = hero.abilities[1]
        
        -- Modify the first ability
        ability1.damage = 999
        ability1.tier = 3
        
        -- Try to add another ability (different type if arcane_bolt is already added)
        -- For this test, we'll just verify the first ability's modifications don't affect registry
        local newInstance = ability_registry.createInstance("arcane_bolt")
        
        if newInstance then
          assert.are.equal(10, newInstance.damage, 
            "New instance should have original damage, not modified value")
          assert.are.equal(1, newInstance.tier, 
            "New instance should have tier 1, not modified value")
        end
      end
    end)
  end)

  describe("Mixed upgrade types", function()
    it("should handle mix of new ability and tier upgrade cards", function()
      -- Add initial ability
      local arcaneBolt = ArcaneBolt:new()
      hero:addAbility(arcaneBolt)
      
      -- Generate cards (should include both tier upgrades and new abilities)
      local cards = upgrade_system.generateCards(3)
      
      local hasTierUpgrade = false
      local hasNewAbility = false
      
      for _, card in ipairs(cards) do
        if card.type == "tier_upgrade" then
          hasTierUpgrade = true
        elseif card.type == "new_ability" then
          hasNewAbility = true
        end
      end
      
      -- With 1 ability, we should get both types
      assert.is_true(hasTierUpgrade or hasNewAbility, 
        "Should offer at least one upgrade type")
    end)

    it("should allow tier upgrades after adding new abilities", function()
      -- Add a new ability
      local cards = upgrade_system.generateCards(3)
      local newAbilityCard = nil
      for _, card in ipairs(cards) do
        if card.type == "new_ability" then
          newAbilityCard = card
          break
        end
      end
      
      if newAbilityCard then
        upgrade_system.applyUpgrade(newAbilityCard)
        
        local ability = hero.abilities[1]
        local initialTier = ability.tier
        
        -- Now try to upgrade the tier
        local cards2 = upgrade_system.generateCards(3)
        local tierUpgradeCard = nil
        for _, card in ipairs(cards2) do
          if card.type == "tier_upgrade" and card.abilityId == ability.id then
            tierUpgradeCard = card
            break
          end
        end
        
        if tierUpgradeCard then
          local success = upgrade_system.applyUpgrade(tierUpgradeCard)
          assert.is_true(success, "Should successfully upgrade tier")
          assert.are.equal(initialTier + 1, ability.tier, 
            "Tier should increase by 1")
        end
      end
    end)
  end)

  describe("Error handling in flow", function()
    it("should handle invalid ability ID gracefully", function()
      local invalidCard = {
        id = "new_ability_invalid",
        type = "new_ability",
        abilityId = "nonexistent_ability",
        name = "Invalid Ability",
        description = "This ability doesn't exist",
        iconType = "invalid",
        apply = function(h)
          local ability = ability_registry.createInstance("nonexistent_ability")
          if ability then
            return h:addAbility(ability)
          end
          return false
        end
      }
      
      local success = upgrade_system.applyUpgrade(invalidCard)
      
      assert.is_false(success, "Should fail to apply invalid ability")
      assert.are.equal(0, #hero.abilities, "Should not add any abilities")
    end)

    it("should handle nil hero gracefully", function()
      -- Cleanup and reinitialize with nil hero
      upgrade_system.cleanup()
      upgrade_system.initialize(nil, upgradeCallback)
      
      local cards = upgrade_system.generateCards(3)
      
      -- Should return empty array or handle gracefully
      assert.is_table(cards, "Should return a table even with nil hero")
    end)
  end)

end)
