-- Upgrade System - New Ability Availability Based on Slots Property Tests
-- Property-based tests for new ability card availability when slots are available
-- Feature: ability-selection

require("tests.spec_helper")

local upgrade_system = require("src.systems.upgrade_system")
local ability_registry = require("src.models.ability_registry")
local Hero = require("src.entities.hero")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")
local lqc = require("lqc.quickcheck")
local property = require("lqc.property")
local lqc_gen = require("lqc.lqc_gen")

describe("Upgrade System - New Ability Availability Based on Slots Property Tests", function()
  before_each(function()
    -- Initialize lua-quickcheck with 100 iterations
    lqc.init(100, 100)  -- 100 tests, 100 shrinks
  end)

  -- Feature: ability-selection, Property 6: New Ability Availability Based on Slots
  describe("Property 6: New Ability Availability Based on Slots", function()
    it("should include at least one new_ability type card when hero has fewer than 5 abilities and unlocked abilities exist", function()
      -- **Validates: Requirements 2.1, 2.3, 4.2, 4.4, 5.5**

      -- Property: For any hero state where the abilities array has fewer than 5 elements,
      -- calling generateCards() should include at least one new_ability type card in the
      -- available upgrades (assuming unlocked abilities exist).

      property "generateCards includes new_ability cards when slots available" {
        generators = {
          lqc_gen.choose(0, 4)  -- Generate hero with 0-4 abilities
        },
        check = function(abilityCount)
          -- Create hero with specified number of abilities
          local hero = Hero:new(360, 1180)

          -- Add random number of abilities to hero (0-4)
          for i = 1, abilityCount do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i  -- Give unique IDs
            hero:addAbility(ability)
          end

          -- Initialize upgrade system
          local upgradeCallback = function() end
          upgrade_system.initialize(hero, upgradeCallback)

          -- Generate upgrade cards
          local cards = upgrade_system.generateCards(3)

          -- Check if there are any unlocked abilities in the registry
          local hasUnlockedAbilities = false
          local unlockedAbilityIds = {}
          for abilityId, _ in pairs(ability_registry.abilities) do
            if ability_registry.isUnlocked(abilityId) then
              hasUnlockedAbilities = true
              table.insert(unlockedAbilityIds, abilityId)
            end
          end

          -- Build set of abilities hero already has
          local heroAbilityIds = {}
          for _, ability in ipairs(hero.abilities) do
            if ability and ability.id then
              heroAbilityIds[ability.id] = true
            end
          end

          -- Check if there are any unlocked abilities that hero doesn't have
          local hasAvailableAbilities = false
          for _, abilityId in ipairs(unlockedAbilityIds) do
            if not heroAbilityIds[abilityId] then
              hasAvailableAbilities = true
              break
            end
          end

          -- If no unlocked abilities exist or hero already has all unlocked abilities,
          -- it's valid to have no new ability cards
          if not hasUnlockedAbilities or not hasAvailableAbilities then
            upgrade_system.cleanup()
            return true
          end

          -- Find all new_ability type cards
          local newAbilityCards = {}
          for _, card in ipairs(cards) do
            if card.type == "new_ability" then
              table.insert(newAbilityCards, card)
            end
          end

          -- Verify at least one new_ability card is present
          if #newAbilityCards == 0 then
            upgrade_system.cleanup()
            return false, "Should have at least one new_ability card when hero has " .. abilityCount .. " abilities and unlocked abilities exist"
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)

    it("should not include new_ability type cards when hero has exactly 5 abilities", function()
      -- **Validates: Requirements 2.3, 4.4**

      -- Property: For any hero state where the abilities array has exactly 5 elements,
      -- calling generateCards() should NOT include any new_ability type cards.

      property "generateCards excludes new_ability cards when all slots full" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(_)
          -- Create hero with exactly 5 abilities (all slots full)
          local hero = Hero:new(360, 1180)

          -- Fill all 5 slots
          for i = 1, 5 do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i  -- Give unique IDs
            hero:addAbility(ability)
          end

          -- Verify hero has exactly 5 abilities
          if #hero.abilities ~= 5 then
            upgrade_system.cleanup()
            return false, "Test setup failed: hero should have exactly 5 abilities, has " .. #hero.abilities
          end

          -- Initialize upgrade system
          local upgradeCallback = function() end
          upgrade_system.initialize(hero, upgradeCallback)

          -- Generate upgrade cards
          local cards = upgrade_system.generateCards(3)

          -- Check that no new_ability cards are present
          for _, card in ipairs(cards) do
            if card.type == "new_ability" then
              upgrade_system.cleanup()
              return false, "Should NOT have new_ability cards when all 5 slots are full"
            end
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)

    it("should include new_ability cards in getAvailableUpgrades when hero has fewer than 5 abilities", function()
      -- **Validates: Requirements 2.1, 4.2**

      -- Property: For any hero state where the abilities array has fewer than 5 elements,
      -- calling getAvailableUpgrades() should include at least one new_ability type card
      -- (assuming unlocked abilities exist that hero doesn't have).

      property "getAvailableUpgrades includes new_ability cards when slots available" {
        generators = {
          lqc_gen.choose(0, 4)  -- Generate hero with 0-4 abilities
        },
        check = function(abilityCount)
          -- Create hero with specified number of abilities
          local hero = Hero:new(360, 1180)

          -- Add random number of abilities to hero (0-4)
          for i = 1, abilityCount do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i  -- Give unique IDs
            hero:addAbility(ability)
          end

          -- Initialize upgrade system
          local upgradeCallback = function() end
          upgrade_system.initialize(hero, upgradeCallback)

          -- Get available upgrades
          local available = upgrade_system.getAvailableUpgrades()

          -- Check if there are any unlocked abilities in the registry
          local hasUnlockedAbilities = false
          local unlockedAbilityIds = {}
          for abilityId, _ in pairs(ability_registry.abilities) do
            if ability_registry.isUnlocked(abilityId) then
              hasUnlockedAbilities = true
              table.insert(unlockedAbilityIds, abilityId)
            end
          end

          -- Build set of abilities hero already has
          local heroAbilityIds = {}
          for _, ability in ipairs(hero.abilities) do
            if ability and ability.id then
              heroAbilityIds[ability.id] = true
            end
          end

          -- Check if there are any unlocked abilities that hero doesn't have
          local hasAvailableAbilities = false
          for _, abilityId in ipairs(unlockedAbilityIds) do
            if not heroAbilityIds[abilityId] then
              hasAvailableAbilities = true
              break
            end
          end

          -- If no unlocked abilities exist or hero already has all unlocked abilities,
          -- it's valid to have no new ability cards
          if not hasUnlockedAbilities or not hasAvailableAbilities then
            upgrade_system.cleanup()
            return true
          end

          -- Find all new_ability type cards
          local newAbilityCards = {}
          for _, upgrade in ipairs(available) do
            if upgrade.type == "new_ability" then
              table.insert(newAbilityCards, upgrade)
            end
          end

          -- Verify at least one new_ability card is present
          if #newAbilityCards == 0 then
            upgrade_system.cleanup()
            return false, "Should have at least one new_ability card in available upgrades when hero has " .. abilityCount .. " abilities and unlocked abilities exist"
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)

    it("should not include new_ability cards in getAvailableUpgrades when hero has exactly 5 abilities", function()
      -- **Validates: Requirements 2.3, 4.4**

      -- Property: For any hero state where the abilities array has exactly 5 elements,
      -- calling getAvailableUpgrades() should NOT include any new_ability type cards.

      property "getAvailableUpgrades excludes new_ability cards when all slots full" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(_)
          -- Create hero with exactly 5 abilities (all slots full)
          local hero = Hero:new(360, 1180)

          -- Fill all 5 slots
          for i = 1, 5 do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i  -- Give unique IDs
            hero:addAbility(ability)
          end

          -- Verify hero has exactly 5 abilities
          if #hero.abilities ~= 5 then
            upgrade_system.cleanup()
            return false, "Test setup failed: hero should have exactly 5 abilities, has " .. #hero.abilities
          end

          -- Initialize upgrade system
          local upgradeCallback = function() end
          upgrade_system.initialize(hero, upgradeCallback)

          -- Get available upgrades
          local available = upgrade_system.getAvailableUpgrades()

          -- Check that no new_ability cards are present
          for _, upgrade in ipairs(available) do
            if upgrade.type == "new_ability" then
              upgrade_system.cleanup()
              return false, "Should NOT have new_ability cards in available upgrades when all 5 slots are full"
            end
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)

    it("should correctly report slot availability via canOfferNewAbility", function()
      -- **Validates: Requirements 2.1, 4.2**

      -- Property: For any hero state, canOfferNewAbility() should return true
      -- if and only if the hero has fewer than 5 abilities.

      property "canOfferNewAbility returns correct boolean based on slot count" {
        generators = {
          lqc_gen.choose(0, 5)  -- Generate hero with 0-5 abilities
        },
        check = function(abilityCount)
          -- Create hero with specified number of abilities
          local hero = Hero:new(360, 1180)

          -- Add abilities to hero
          for i = 1, abilityCount do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i  -- Give unique IDs
            hero:addAbility(ability)
          end

          -- Initialize upgrade system
          local upgradeCallback = function() end
          upgrade_system.initialize(hero, upgradeCallback)

          -- Check canOfferNewAbility
          local canOffer = upgrade_system.canOfferNewAbility()

          -- Expected result: true if < 5 abilities, false if >= 5
          local expectedCanOffer = (abilityCount < 5)

          -- Verify result matches expectation
          if canOffer ~= expectedCanOffer then
            upgrade_system.cleanup()
            return false, "canOfferNewAbility returned " .. tostring(canOffer) .. " but expected " .. tostring(expectedCanOffer) .. " for hero with " .. abilityCount .. " abilities"
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)

    it("should maintain consistency between canOfferNewAbility and actual card generation", function()
      -- **Validates: Requirements 2.1, 2.3, 4.2, 4.4**

      -- Property: If canOfferNewAbility() returns true, then generateCards() should
      -- include at least one new_ability card (assuming unlocked abilities exist).
      -- If canOfferNewAbility() returns false, then generateCards() should NOT
      -- include any new_ability cards.

      property "canOfferNewAbility is consistent with card generation" {
        generators = {
          lqc_gen.choose(0, 5)  -- Generate hero with 0-5 abilities
        },
        check = function(abilityCount)
          -- Create hero with specified number of abilities
          local hero = Hero:new(360, 1180)

          -- Add abilities to hero
          for i = 1, abilityCount do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i  -- Give unique IDs
            hero:addAbility(ability)
          end

          -- Initialize upgrade system
          local upgradeCallback = function() end
          upgrade_system.initialize(hero, upgradeCallback)

          -- Check canOfferNewAbility
          local canOffer = upgrade_system.canOfferNewAbility()

          -- Generate cards
          local cards = upgrade_system.generateCards(3)

          -- Count new_ability cards
          local newAbilityCount = 0
          for _, card in ipairs(cards) do
            if card.type == "new_ability" then
              newAbilityCount = newAbilityCount + 1
            end
          end

          -- If canOffer is false, should have no new_ability cards
          if not canOffer and newAbilityCount > 0 then
            upgrade_system.cleanup()
            return false, "canOfferNewAbility returned false but generateCards included " .. newAbilityCount .. " new_ability cards"
          end

          -- If canOffer is true, should have at least one new_ability card
          -- (unless there are no unlocked abilities or hero has all of them)
          if canOffer then
            -- Check if there are any unlocked abilities hero doesn't have
            local hasAvailableAbilities = false
            local heroAbilityIds = {}
            for _, ability in ipairs(hero.abilities) do
              if ability and ability.id then
                heroAbilityIds[ability.id] = true
              end
            end

            for abilityId, _ in pairs(ability_registry.abilities) do
              if ability_registry.isUnlocked(abilityId) and not heroAbilityIds[abilityId] then
                hasAvailableAbilities = true
                break
              end
            end

            -- Only expect new_ability cards if there are available abilities
            if hasAvailableAbilities and newAbilityCount == 0 then
              upgrade_system.cleanup()
              return false, "canOfferNewAbility returned true and unlocked abilities exist, but generateCards included no new_ability cards"
            end
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)
  end)
end)
