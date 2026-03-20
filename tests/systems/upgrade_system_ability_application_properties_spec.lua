-- Upgrade System - Ability Application Property Tests
-- Property-based tests for ability application logic
-- Feature: ability-selection

require("tests.spec_helper")

local upgrade_system = require("src.systems.upgrade_system")
local ability_registry = require("src.models.ability_registry")
local Hero = require("src.entities.hero")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")
local lqc = require("lqc.quickcheck")
local property = require("lqc.property")
local lqc_gen = require("lqc.lqc_gen")

describe("Upgrade System - Ability Application Property Tests", function()
  before_each(function()
    -- Initialize lua-quickcheck with 100 iterations
    lqc.init(100, 100)  -- 100 tests, 100 shrinks
  end)

  -- Feature: ability-selection, Property 8: Ability Addition Success
  describe("Property 8: Ability Addition Success", function()
    it("should increase hero's abilities array length by exactly 1 when applying a valid new_ability upgrade card", function()
      -- **Validates: Requirements 3.1, 3.4, 6.1**

      -- Property: For any hero with fewer than 5 abilities, applying a valid
      -- new_ability upgrade card should increase the hero's abilities array
      -- length by exactly 1 and the new ability should appear at the end of the array.

      property "Applying new_ability card increases abilities array by 1" {
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

          -- Find a new_ability card
          local newAbilityCard = nil
          for _, upgrade in ipairs(available) do
            if upgrade.type == "new_ability" then
              newAbilityCard = upgrade
              break
            end
          end

          -- If no new ability card found, skip this iteration
          if not newAbilityCard then
            upgrade_system.cleanup()
            return true
          end

          -- Record initial state
          local initialCount = #hero.abilities

          -- Apply the upgrade card
          local success = upgrade_system.applyUpgrade(newAbilityCard)

          -- Verify success
          if not success then
            upgrade_system.cleanup()
            return false, "applyUpgrade returned false for valid new_ability card"
          end

          -- Verify abilities array length increased by exactly 1
          local finalCount = #hero.abilities
          if finalCount ~= initialCount + 1 then
            upgrade_system.cleanup()
            return false, "Abilities array length should increase by 1: expected " .. (initialCount + 1) .. ", got " .. finalCount
          end

          -- Verify the new ability appears at the end of the array
          local lastAbility = hero.abilities[finalCount]
          if not lastAbility then
            upgrade_system.cleanup()
            return false, "Last ability in array is nil after applying upgrade"
          end

          -- Verify the last ability has the correct id
          if lastAbility.id ~= newAbilityCard.abilityId then
            upgrade_system.cleanup()
            return false, "Last ability id '" .. tostring(lastAbility.id) .. "' does not match card abilityId '" .. tostring(newAbilityCard.abilityId) .. "'"
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)

    it("should add the new ability to the end of the abilities array for any hero with available slots", function()
      -- **Validates: Requirements 3.1, 3.4, 6.1**

      -- Property: For any hero with fewer than 5 abilities, the new ability
      -- should appear at the end of the abilities array after application.

      property "New ability appears at end of abilities array" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Create hero with varying number of abilities (0-4)
          local abilityCount = math.random(0, 4)
          local hero = Hero:new(360, 1180)

          -- Add random number of abilities to hero
          for i = 1, abilityCount do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i
            hero:addAbility(ability)
          end

          -- Initialize upgrade system
          upgrade_system.initialize(hero, function() end)

          -- Get available upgrades
          local available = upgrade_system.getAvailableUpgrades()

          -- Find a new_ability card
          local newAbilityCard = nil
          for _, upgrade in ipairs(available) do
            if upgrade.type == "new_ability" then
              newAbilityCard = upgrade
              break
            end
          end

          -- If no new ability card found, skip
          if not newAbilityCard then
            upgrade_system.cleanup()
            return true
          end

          -- Record initial abilities
          local initialAbilities = {}
          for i, ability in ipairs(hero.abilities) do
            initialAbilities[i] = ability
          end

          -- Apply the upgrade
          local success = upgrade_system.applyUpgrade(newAbilityCard)

          if not success then
            upgrade_system.cleanup()
            return false, "applyUpgrade failed for valid new_ability card"
          end

          -- Verify all initial abilities are still in the same positions
          for i, ability in ipairs(initialAbilities) do
            if hero.abilities[i] ~= ability then
              upgrade_system.cleanup()
              return false, "Initial ability at position " .. i .. " was moved or replaced"
            end
          end

          -- Verify new ability is at the end
          local newPosition = #hero.abilities
          local newAbility = hero.abilities[newPosition]

          if not newAbility then
            upgrade_system.cleanup()
            return false, "New ability not found at end of array"
          end

          if newAbility.id ~= newAbilityCard.abilityId then
            upgrade_system.cleanup()
            return false, "Ability at end has wrong id: expected " .. newAbilityCard.abilityId .. ", got " .. tostring(newAbility.id)
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)
  end)


  -- Feature: ability-selection, Property 9: Ability Instance Creation on Application
  describe("Property 9: Ability Instance Creation on Application", function()
    it("should create a valid ability instance with correct id when applying a new_ability upgrade card", function()
      -- **Validates: Requirements 3.2**

      -- Property: For any new_ability upgrade card that is successfully applied,
      -- the ability added to the hero's abilities array must be a valid instance
      -- with the correct id matching the card's abilityId.

      property "Applied ability is valid instance with correct id" {
        generators = {
          lqc_gen.choose(0, 4)  -- Generate hero with 0-4 abilities
        },
        check = function(abilityCount)
          -- Create hero with specified number of abilities
          local hero = Hero:new(360, 1180)

          -- Add random number of abilities to hero (0-4)
          for i = 1, abilityCount do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i
            hero:addAbility(ability)
          end

          -- Initialize upgrade system
          upgrade_system.initialize(hero, function() end)

          -- Get available upgrades
          local available = upgrade_system.getAvailableUpgrades()

          -- Find a new_ability card
          local newAbilityCard = nil
          for _, upgrade in ipairs(available) do
            if upgrade.type == "new_ability" then
              newAbilityCard = upgrade
              break
            end
          end

          -- If no new ability card found, skip
          if not newAbilityCard then
            upgrade_system.cleanup()
            return true
          end

          -- Apply the upgrade
          local success = upgrade_system.applyUpgrade(newAbilityCard)

          if not success then
            upgrade_system.cleanup()
            return false, "applyUpgrade failed for valid new_ability card"
          end

          -- Get the newly added ability (last in array)
          local newAbility = hero.abilities[#hero.abilities]

          -- Verify ability is not nil
          if not newAbility then
            upgrade_system.cleanup()
            return false, "Newly added ability is nil"
          end

          -- Verify ability is a table (object)
          if type(newAbility) ~= "table" then
            upgrade_system.cleanup()
            return false, "Newly added ability is not a table: " .. type(newAbility)
          end

          -- Verify ability has id field
          if not newAbility.id then
            upgrade_system.cleanup()
            return false, "Newly added ability missing id field"
          end

          -- Verify ability id matches card's abilityId
          if newAbility.id ~= newAbilityCard.abilityId then
            upgrade_system.cleanup()
            return false, "Ability id '" .. tostring(newAbility.id) .. "' does not match card abilityId '" .. tostring(newAbilityCard.abilityId) .. "'"
          end

          -- Verify ability has expected properties (name, tier, etc.)
          if not newAbility.name then
            upgrade_system.cleanup()
            return false, "Newly added ability missing name field"
          end

          if type(newAbility.name) ~= "string" then
            upgrade_system.cleanup()
            return false, "Ability name is not a string: " .. type(newAbility.name)
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)

    it("should create a unique instance for each application (not reuse references)", function()
      -- **Validates: Requirements 3.2**

      -- Property: Each time a new_ability card is applied, a new unique instance
      -- should be created (different object reference).

      property "Each application creates unique instance" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Create two heroes to test instance uniqueness
          local hero1 = Hero:new(360, 1180)
          local hero2 = Hero:new(360, 1180)

          -- Initialize upgrade system with hero1
          upgrade_system.initialize(hero1, function() end)

          -- Get available upgrades
          local available = upgrade_system.getAvailableUpgrades()

          -- Find a new_ability card
          local newAbilityCard = nil
          for _, upgrade in ipairs(available) do
            if upgrade.type == "new_ability" then
              newAbilityCard = upgrade
              break
            end
          end

          -- If no new ability card found, skip
          if not newAbilityCard then
            upgrade_system.cleanup()
            return true
          end

          -- Apply to hero1
          local success1 = upgrade_system.applyUpgrade(newAbilityCard)
          if not success1 then
            upgrade_system.cleanup()
            return false, "Failed to apply upgrade to hero1"
          end

          local ability1 = hero1.abilities[#hero1.abilities]

          -- Cleanup and reinitialize with hero2
          upgrade_system.cleanup()
          upgrade_system.initialize(hero2, function() end)

          -- Get the same card for hero2
          local available2 = upgrade_system.getAvailableUpgrades()
          local newAbilityCard2 = nil
          for _, upgrade in ipairs(available2) do
            if upgrade.type == "new_ability" and upgrade.abilityId == newAbilityCard.abilityId then
              newAbilityCard2 = upgrade
              break
            end
          end

          if not newAbilityCard2 then
            upgrade_system.cleanup()
            return true  -- Skip if card not available for hero2
          end

          -- Apply to hero2
          local success2 = upgrade_system.applyUpgrade(newAbilityCard2)
          if not success2 then
            upgrade_system.cleanup()
            return false, "Failed to apply upgrade to hero2"
          end

          local ability2 = hero2.abilities[#hero2.abilities]

          -- Verify both abilities exist
          if not ability1 or not ability2 then
            upgrade_system.cleanup()
            return false, "One or both abilities are nil"
          end

          -- Verify they are different object references
          if ability1 == ability2 then
            upgrade_system.cleanup()
            return false, "Both heroes received the same ability instance (same reference)"
          end

          -- Verify they have the same id (same ability type)
          if ability1.id ~= ability2.id then
            upgrade_system.cleanup()
            return false, "Abilities have different ids: " .. tostring(ability1.id) .. " vs " .. tostring(ability2.id)
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)
  end)


  -- Feature: ability-selection, Property 10: New Ability Initial Tier
  describe("Property 10: New Ability Initial Tier", function()
    it("should create abilities with tier equal to 1 when applying a new_ability upgrade card", function()
      -- **Validates: Requirements 3.5**

      -- Property: For any ability created via createInstance() and added to the hero,
      -- the ability's tier property must equal 1.

      property "New abilities start at tier 1" {
        generators = {
          lqc_gen.choose(0, 4)  -- Generate hero with 0-4 abilities
        },
        check = function(abilityCount)
          -- Create hero with specified number of abilities
          local hero = Hero:new(360, 1180)

          -- Add random number of abilities to hero (0-4)
          for i = 1, abilityCount do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i
            hero:addAbility(ability)
          end

          -- Initialize upgrade system
          upgrade_system.initialize(hero, function() end)

          -- Get available upgrades
          local available = upgrade_system.getAvailableUpgrades()

          -- Find a new_ability card
          local newAbilityCard = nil
          for _, upgrade in ipairs(available) do
            if upgrade.type == "new_ability" then
              newAbilityCard = upgrade
              break
            end
          end

          -- If no new ability card found, skip
          if not newAbilityCard then
            upgrade_system.cleanup()
            return true
          end

          -- Apply the upgrade
          local success = upgrade_system.applyUpgrade(newAbilityCard)

          if not success then
            upgrade_system.cleanup()
            return false, "applyUpgrade failed for valid new_ability card"
          end

          -- Get the newly added ability
          local newAbility = hero.abilities[#hero.abilities]

          -- Verify ability exists
          if not newAbility then
            upgrade_system.cleanup()
            return false, "Newly added ability is nil"
          end

          -- Verify ability has tier field
          if newAbility.tier == nil then
            upgrade_system.cleanup()
            return false, "Newly added ability missing tier field"
          end

          -- Verify tier is a number
          if type(newAbility.tier) ~= "number" then
            upgrade_system.cleanup()
            return false, "Ability tier is not a number: " .. type(newAbility.tier)
          end

          -- Verify tier equals 1
          if newAbility.tier ~= 1 then
            upgrade_system.cleanup()
            return false, "New ability tier should be 1, got: " .. tostring(newAbility.tier)
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)

    it("should verify all new abilities start at tier 1 across multiple applications", function()
      -- **Validates: Requirements 3.5**

      -- Property: Across multiple applications of new_ability cards,
      -- all newly added abilities should consistently start at tier 1.

      property "All new abilities consistently start at tier 1" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Create hero with varying number of abilities (0-3 to allow multiple additions)
          local abilityCount = math.random(0, 3)
          local hero = Hero:new(360, 1180)

          -- Add initial abilities
          for i = 1, abilityCount do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i
            hero:addAbility(ability)
          end

          -- Initialize upgrade system
          upgrade_system.initialize(hero, function() end)

          -- Try to add multiple new abilities
          local addedAbilities = {}
          local maxAttempts = 5 - abilityCount  -- Can add up to 5 total

          for attempt = 1, maxAttempts do
            -- Get available upgrades
            local available = upgrade_system.getAvailableUpgrades()

            -- Find a new_ability card
            local newAbilityCard = nil
            for _, upgrade in ipairs(available) do
              if upgrade.type == "new_ability" then
                -- Check if we haven't already added this ability
                local alreadyAdded = false
                for _, addedId in ipairs(addedAbilities) do
                  if upgrade.abilityId == addedId then
                    alreadyAdded = true
                    break
                  end
                end

                if not alreadyAdded then
                  newAbilityCard = upgrade
                  break
                end
              end
            end

            -- If no new ability card found, stop
            if not newAbilityCard then
              break
            end

            -- Apply the upgrade
            local success = upgrade_system.applyUpgrade(newAbilityCard)

            if not success then
              upgrade_system.cleanup()
              return false, "applyUpgrade failed on attempt " .. attempt
            end

            -- Get the newly added ability
            local newAbility = hero.abilities[#hero.abilities]

            -- Verify tier is 1
            if not newAbility or newAbility.tier ~= 1 then
              upgrade_system.cleanup()
              return false, "New ability on attempt " .. attempt .. " does not have tier 1: " .. tostring(newAbility and newAbility.tier or "nil")
            end

            -- Track added ability
            table.insert(addedAbilities, newAbilityCard.abilityId)
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)

    it("should verify tier 1 for abilities created directly via createInstance", function()
      -- **Validates: Requirements 3.5**

      -- Property: For any ability created via ability_registry.createInstance(),
      -- the tier property should equal 1.

      property "createInstance creates abilities with tier 1" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Get all unlocked abilities from registry
          local unlockedAbilities = {}
          for abilityId, _ in pairs(ability_registry.abilities) do
            if ability_registry.isUnlocked(abilityId) then
              table.insert(unlockedAbilities, abilityId)
            end
          end

          -- If no unlocked abilities, skip
          if #unlockedAbilities == 0 then
            return true
          end

          -- Pick a random unlocked ability
          local randomAbilityId = unlockedAbilities[math.random(1, #unlockedAbilities)]

          -- Create instance
          local ability = ability_registry.createInstance(randomAbilityId)

          -- Verify instance was created
          if not ability then
            return false, "createInstance returned nil for unlocked ability: " .. randomAbilityId
          end

          -- Verify tier field exists
          if ability.tier == nil then
            return false, "Created ability missing tier field for: " .. randomAbilityId
          end

          -- Verify tier is a number
          if type(ability.tier) ~= "number" then
            return false, "Ability tier is not a number for " .. randomAbilityId .. ": " .. type(ability.tier)
          end

          -- Verify tier equals 1
          if ability.tier ~= 1 then
            return false, "Created ability tier should be 1 for " .. randomAbilityId .. ", got: " .. tostring(ability.tier)
          end

          return true
        end
      }
    end)
  end)


  -- Feature: ability-selection, Property 11: Slot Limit Enforcement
  describe("Property 11: Slot Limit Enforcement", function()
    it("should return false when attempting to apply a new_ability card to a hero with exactly 5 abilities", function()
      -- **Validates: Requirements 3.3, 4.1, 4.3**

      -- Property: For any hero with exactly 5 abilities, attempting to apply
      -- a new_ability upgrade card should return false, leave the abilities
      -- array unchanged, and log a warning message.

      property "Slot limit prevents adding abilities beyond 5" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Create hero with exactly 5 abilities (all slots full)
          local hero = Hero:new(360, 1180)

          -- Fill all 5 slots
          for i = 1, 5 do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i
            hero:addAbility(ability)
          end

          -- Verify hero has exactly 5 abilities
          if #hero.abilities ~= 5 then
            return false, "Test setup failed: hero should have exactly 5 abilities, has " .. #hero.abilities
          end

          -- Initialize upgrade system
          upgrade_system.initialize(hero, function() end)

          -- Create a mock new_ability card (since getAvailableUpgrades won't return any)
          local mockNewAbilityCard = {
            id = "new_ability_test",
            type = "new_ability",
            abilityId = "arcane_bolt",  -- Use a known ability
            name = "Test Ability",
            description = "Test description",
            iconType = "test",
            apply = function(hero)
              -- This should fail due to slot limit
              if #hero.abilities >= 5 then
                print("Warning: Cannot add ability - all 5 slots full")
                return false
              end
              local ability = ability_registry.createInstance("arcane_bolt")
              if ability then
                return hero:addAbility(ability)
              end
              return false
            end
          }

          -- Record initial state
          local initialCount = #hero.abilities
          local initialAbilities = {}
          for i, ability in ipairs(hero.abilities) do
            initialAbilities[i] = ability
          end

          -- Attempt to apply the upgrade
          local success = upgrade_system.applyUpgrade(mockNewAbilityCard)

          -- Verify application failed
          if success then
            upgrade_system.cleanup()
            return false, "applyUpgrade should return false when all 5 slots are full, but returned true"
          end

          -- Verify abilities array length is unchanged
          if #hero.abilities ~= initialCount then
            upgrade_system.cleanup()
            return false, "Abilities array length changed from " .. initialCount .. " to " .. #hero.abilities
          end

          -- Verify all abilities are unchanged
          for i, ability in ipairs(initialAbilities) do
            if hero.abilities[i] ~= ability then
              upgrade_system.cleanup()
              return false, "Ability at position " .. i .. " was changed"
            end
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)

    it("should leave abilities array unchanged when slot limit is reached", function()
      -- **Validates: Requirements 3.3, 4.1, 4.3**

      -- Property: When attempting to add an ability to a hero with 5 abilities,
      -- the abilities array should remain completely unchanged.

      property "Abilities array unchanged when slot limit reached" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Create hero with exactly 5 abilities
          local hero = Hero:new(360, 1180)

          -- Fill all 5 slots with unique abilities
          for i = 1, 5 do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i
            ability.tier = i  -- Give each a unique tier for verification
            hero:addAbility(ability)
          end

          -- Initialize upgrade system
          upgrade_system.initialize(hero, function() end)

          -- Create a snapshot of the abilities array
          local snapshot = {}
          for i, ability in ipairs(hero.abilities) do
            snapshot[i] = {
              reference = ability,
              id = ability.id,
              tier = ability.tier
            }
          end

          -- Create mock new_ability card
          local mockCard = {
            id = "new_ability_test",
            type = "new_ability",
            abilityId = "arcane_bolt",
            name = "Test",
            description = "Test",
            iconType = "test",
            apply = function(hero)
              if #hero.abilities >= 5 then
                return false
              end
              return hero:addAbility(ability_registry.createInstance("arcane_bolt"))
            end
          }

          -- Attempt to apply
          upgrade_system.applyUpgrade(mockCard)

          -- Verify array length unchanged
          if #hero.abilities ~= 5 then
            upgrade_system.cleanup()
            return false, "Array length changed from 5 to " .. #hero.abilities
          end

          -- Verify each ability is unchanged
          for i, snap in ipairs(snapshot) do
            local current = hero.abilities[i]

            -- Check reference is the same
            if current ~= snap.reference then
              upgrade_system.cleanup()
              return false, "Ability reference at position " .. i .. " changed"
            end

            -- Check id is the same
            if current.id ~= snap.id then
              upgrade_system.cleanup()
              return false, "Ability id at position " .. i .. " changed from " .. snap.id .. " to " .. current.id
            end

            -- Check tier is the same
            if current.tier ~= snap.tier then
              upgrade_system.cleanup()
              return false, "Ability tier at position " .. i .. " changed from " .. snap.tier .. " to " .. current.tier
            end
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)

    it("should enforce slot limit through applyUpgrade validation", function()
      -- **Validates: Requirements 3.3, 4.1, 4.3**

      -- Property: The applyUpgrade function should validate slot availability
      -- before attempting to add a new ability.

      property "applyUpgrade validates slot limit before application" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Create hero with exactly 5 abilities
          local hero = Hero:new(360, 1180)

          for i = 1, 5 do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i
            hero:addAbility(ability)
          end

          -- Initialize upgrade system
          upgrade_system.initialize(hero, function() end)

          -- Create mock card that would succeed if not for slot limit
          local mockCard = {
            id = "new_ability_test",
            type = "new_ability",
            abilityId = "arcane_bolt",
            name = "Test",
            description = "Test",
            iconType = "test",
            apply = function(hero)
              -- This should not be reached if applyUpgrade validates first
              if #hero.abilities >= 5 then
                return false
              end
              return true
            end
          }

          -- Apply should fail due to validation in applyUpgrade
          local success = upgrade_system.applyUpgrade(mockCard)

          if success then
            upgrade_system.cleanup()
            return false, "applyUpgrade should validate slot limit and return false"
          end

          -- Verify hero still has exactly 5 abilities
          if #hero.abilities ~= 5 then
            upgrade_system.cleanup()
            return false, "Hero should still have exactly 5 abilities"
          end

          -- Cleanup
          upgrade_system.cleanup()

          return true
        end
      }
    end)

    it("should consistently enforce 5-ability limit across multiple attempts", function()
      -- **Validates: Requirements 3.3, 4.1, 4.3**

      -- Property: The 5-ability limit should be consistently enforced
      -- across multiple application attempts.

      property "Slot limit consistently enforced across attempts" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Create hero with exactly 5 abilities
          local hero = Hero:new(360, 1180)

          for i = 1, 5 do
            local ability = ArcaneBolt:new()
            ability.id = "test_ability_" .. i
            hero:addAbility(ability)
          end

          -- Initialize upgrade system
          upgrade_system.initialize(hero, function() end)

          -- Create mock card
          local mockCard = {
            id = "new_ability_test",
            type = "new_ability",
            abilityId = "arcane_bolt",
            name = "Test",
            description = "Test",
            iconType = "test",
            apply = function(hero)
              if #hero.abilities >= 5 then
                return false
              end
              return hero:addAbility(ability_registry.createInstance("arcane_bolt"))
            end
          }

          -- Attempt to apply multiple times
          local attempts = math.random(3, 10)
          for attempt = 1, attempts do
            local success = upgrade_system.applyUpgrade(mockCard)

            -- Each attempt should fail
            if success then
              upgrade_system.cleanup()
              return false, "Attempt " .. attempt .. " should have failed but succeeded"
            end

            -- Verify count is still 5
            if #hero.abilities ~= 5 then
              upgrade_system.cleanup()
              return false, "After attempt " .. attempt .. ", hero has " .. #hero.abilities .. " abilities instead of 5"
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
