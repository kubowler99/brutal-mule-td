-- Ability Registry Property Tests
-- Property-based tests for ability registry structure and behavior
-- Feature: ability-selection

require("tests.spec_helper")

local ability_registry = require("src.models.ability_registry")
local lqc = require("lqc.quickcheck")
local property = require("lqc.property")
local lqc_gen = require("lqc.lqc_gen")

describe("Ability Registry - Property Tests", function()
  before_each(function()
    -- Initialize lua-quickcheck with 100 iterations
    lqc.init(100, 100)  -- 100 tests, 100 shrinks
    
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

  -- Feature: ability-selection, Property 1: Ability Definition Structure
  describe("Property 1: Ability Definition Structure", function()
    it("should have required fields (module, unlocked, maxTier) for any registered ability", function()
      -- **Validates: Requirements 1.1, 1.2, 7.1**

      -- Property: For any ability registered in the ability registry,
      -- the definition must contain the required fields: module (path to ability class),
      -- unlocked (boolean), and maxTier (number).

      -- Get all ability IDs from the registry
      local abilityIds = {}
      for id, _ in pairs(ability_registry.abilities) do
        table.insert(abilityIds, id)
      end

      -- Ensure we have at least one ability to test
      assert.is_true(#abilityIds > 0, "Registry should have at least one ability")

      -- Test each ability definition 100 times (randomized order)
      property "All ability definitions have required structure" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Randomly select an ability ID to test
          local randomIndex = math.random(1, #abilityIds)
          local abilityId = abilityIds[randomIndex]

          -- Get the ability definition
          local abilityDef = ability_registry.abilities[abilityId]

          -- Verify definition exists
          if not abilityDef then
            return false, "Ability definition for '" .. abilityId .. "' is nil"
          end

          -- Verify 'module' field exists and is not nil
          if abilityDef.module == nil then
            return false, "Ability '" .. abilityId .. "' missing 'module' field"
          end

          -- Verify 'module' is a string (module path in Lua)
          if type(abilityDef.module) ~= "string" then
            return false, "Ability '" .. abilityId .. "' has invalid 'module' type: " .. type(abilityDef.module)
          end

          -- Verify 'unlocked' field exists
          if abilityDef.unlocked == nil then
            return false, "Ability '" .. abilityId .. "' missing 'unlocked' field"
          end

          -- Verify 'unlocked' is a boolean
          if type(abilityDef.unlocked) ~= "boolean" then
            return false, "Ability '" .. abilityId .. "' has invalid 'unlocked' type: " .. type(abilityDef.unlocked)
          end

          -- Verify 'maxTier' field exists
          if abilityDef.maxTier == nil then
            return false, "Ability '" .. abilityId .. "' missing 'maxTier' field"
          end

          -- Verify 'maxTier' is a number
          if type(abilityDef.maxTier) ~= "number" then
            return false, "Ability '" .. abilityId .. "' has invalid 'maxTier' type: " .. type(abilityDef.maxTier)
          end

          -- Verify 'maxTier' is a positive integer (typically 1-5)
          if abilityDef.maxTier < 1 or abilityDef.maxTier ~= math.floor(abilityDef.maxTier) then
            return false, "Ability '" .. abilityId .. "' has invalid 'maxTier' value: " .. abilityDef.maxTier
          end

          return true
        end
      }
    end)

    it("should maintain consistent structure across all registered abilities", function()
      -- **Validates: Requirements 1.1, 1.2, 7.1**

      -- Property: All abilities in the registry should have the same structure
      -- (same set of required fields)

      property "All abilities have consistent structure" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          local requiredFields = {"module", "unlocked", "maxTier"}
          local fieldTypes = {
            module = "string",
            unlocked = "boolean",
            maxTier = "number"
          }

          -- Check all abilities in the registry
          for abilityId, abilityDef in pairs(ability_registry.abilities) do
            -- Verify all required fields are present
            for _, field in ipairs(requiredFields) do
              if abilityDef[field] == nil then
                return false, "Ability '" .. abilityId .. "' missing required field: " .. field
              end

              -- Verify field type matches expected type
              local expectedType = fieldTypes[field]
              local actualType = type(abilityDef[field])
              if actualType ~= expectedType then
                return false, "Ability '" .. abilityId .. "' field '" .. field .. "' has wrong type: expected " .. expectedType .. ", got " .. actualType
              end
            end
          end

          return true
        end
      }
    end)

    it("should have valid module paths that can be loaded and instantiated", function()
      -- **Validates: Requirements 1.1, 1.2**

      -- Property: For any ability with a module path, the module should be loadable
      -- and the class should be instantiable (should have a 'new' method)

      property "All ability modules are loadable and instantiable" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Check all abilities in the registry
          for abilityId, abilityDef in pairs(ability_registry.abilities) do
            -- Verify module path exists
            if not abilityDef.module then
              return false, "Ability '" .. abilityId .. "' has no module path"
            end

            -- Try to load the module (should not throw error)
            local success, abilityClass = pcall(require, abilityDef.module)
            
            if not success then
              return false, "Ability '" .. abilityId .. "' module cannot be loaded: " .. tostring(abilityClass)
            end

            -- Verify class has a 'new' method (middleclass convention)
            if type(abilityClass.new) ~= "function" then
              return false, "Ability '" .. abilityId .. "' class has no 'new' method"
            end

            -- Try to instantiate the class (should not throw error)
            local instanceSuccess, instance = pcall(function()
              return abilityClass:new()
            end)

            if not instanceSuccess then
              return false, "Ability '" .. abilityId .. "' class cannot be instantiated: " .. tostring(instance)
            end

            -- Verify instance is not nil
            if not instance then
              return false, "Ability '" .. abilityId .. "' class instantiation returned nil"
            end
          end

          return true
        end
      }
    end)
  end)

  -- Feature: ability-selection, Property 2: Ability Retrieval by ID
  describe("Property 2: Ability Retrieval by ID", function()
    it("should return the corresponding ability definition with all required fields intact for any valid ability id", function()
      -- **Validates: Requirements 1.3**

      -- Property: For any valid ability id in the registry, calling getAbility(id)
      -- should return the corresponding ability definition with all required fields intact.

      -- Get all ability IDs from the registry
      local abilityIds = {}
      for id, _ in pairs(ability_registry.abilities) do
        table.insert(abilityIds, id)
      end

      -- Ensure we have at least one ability to test
      assert.is_true(#abilityIds > 0, "Registry should have at least one ability")

      -- Test retrieval for each ability 100 times (randomized order)
      property "getAbility returns correct definition for valid IDs" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Randomly select an ability ID to test
          local randomIndex = math.random(1, #abilityIds)
          local abilityId = abilityIds[randomIndex]

          -- Get the ability definition via getAbility method
          local retrievedDef = ability_registry.getAbility(abilityId)

          -- Verify definition was retrieved
          if not retrievedDef then
            return false, "getAbility('" .. abilityId .. "') returned nil for valid ID"
          end

          -- Get the original definition from the registry
          local originalDef = ability_registry.abilities[abilityId]

          -- Verify the retrieved definition matches the original
          if retrievedDef ~= originalDef then
            return false, "getAbility('" .. abilityId .. "') returned different reference than registry entry"
          end

          -- Verify all required fields are present and intact
          if retrievedDef.class == nil then
            return false, "Retrieved definition for '" .. abilityId .. "' missing 'class' field"
          end

          if retrievedDef.unlocked == nil then
            return false, "Retrieved definition for '" .. abilityId .. "' missing 'unlocked' field"
          end

          if retrievedDef.maxTier == nil then
            return false, "Retrieved definition for '" .. abilityId .. "' missing 'maxTier' field"
          end

          -- Verify field types are correct
          if type(retrievedDef.class) ~= "table" then
            return false, "Retrieved definition for '" .. abilityId .. "' has invalid 'class' type"
          end

          if type(retrievedDef.unlocked) ~= "boolean" then
            return false, "Retrieved definition for '" .. abilityId .. "' has invalid 'unlocked' type"
          end

          if type(retrievedDef.maxTier) ~= "number" then
            return false, "Retrieved definition for '" .. abilityId .. "' has invalid 'maxTier' type"
          end

          return true
        end
      }
    end)

    it("should return nil for invalid or non-existent ability IDs", function()
      -- **Validates: Requirements 1.3**

      -- Property: For any invalid ability id, calling getAbility(id) should return nil

      property "getAbility returns nil for invalid IDs" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Generate random invalid ability IDs
          local invalidIds = {
            "invalid_ability_" .. math.random(1000, 9999),
            "nonexistent_" .. math.random(1000, 9999),
            "",
            "   ",
            "ability_that_does_not_exist",
            "test_" .. math.random(1000, 9999)
          }

          -- Randomly select an invalid ID
          local randomIndex = math.random(1, #invalidIds)
          local invalidId = invalidIds[randomIndex]

          -- Ensure the ID is not actually in the registry
          if ability_registry.abilities[invalidId] then
            -- Skip this iteration if we accidentally generated a valid ID
            return true
          end

          -- Get the ability definition via getAbility method
          local retrievedDef = ability_registry.getAbility(invalidId)

          -- Verify nil is returned for invalid ID
          if retrievedDef ~= nil then
            return false, "getAbility('" .. invalidId .. "') should return nil for invalid ID, got: " .. type(retrievedDef)
          end

          return true
        end
      }
    end)

    it("should maintain referential integrity (same reference for multiple calls)", function()
      -- **Validates: Requirements 1.3**

      -- Property: Multiple calls to getAbility with the same ID should return
      -- the same reference (not a copy)

      property "getAbility returns same reference for multiple calls" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Get all ability IDs from the registry
          local abilityIds = {}
          for id, _ in pairs(ability_registry.abilities) do
            table.insert(abilityIds, id)
          end

          if #abilityIds == 0 then
            return false, "No abilities in registry to test"
          end

          -- Randomly select an ability ID to test
          local randomIndex = math.random(1, #abilityIds)
          local abilityId = abilityIds[randomIndex]

          -- Call getAbility multiple times
          local def1 = ability_registry.getAbility(abilityId)
          local def2 = ability_registry.getAbility(abilityId)
          local def3 = ability_registry.getAbility(abilityId)

          -- Verify all calls return the same reference
          if def1 ~= def2 then
            return false, "getAbility('" .. abilityId .. "') returned different references on consecutive calls (call 1 vs 2)"
          end

          if def1 ~= def3 then
            return false, "getAbility('" .. abilityId .. "') returned different references on consecutive calls (call 1 vs 3)"
          end

          if def2 ~= def3 then
            return false, "getAbility('" .. abilityId .. "') returned different references on consecutive calls (call 2 vs 3)"
          end

          return true
        end
      }
    end)
  end)

  -- Feature: ability-selection, Property 4: Instance Creation Uniqueness
  describe("Property 4: Instance Creation Uniqueness", function()
    it("should return distinct instances (different object references) with the same initial properties for any unlocked ability", function()
      -- **Validates: Requirements 1.5**

      -- Property: For any unlocked ability, calling createInstance(id) multiple times
      -- should return distinct instances (different object references) with the same initial properties.

      -- Get all unlocked ability IDs from the registry
      local unlockedAbilityIds = {}
      for id, def in pairs(ability_registry.abilities) do
        if def.unlocked == true then
          table.insert(unlockedAbilityIds, id)
        end
      end

      -- Ensure we have at least one unlocked ability to test
      assert.is_true(#unlockedAbilityIds > 0, "Registry should have at least one unlocked ability")

      -- Test instance creation uniqueness 100 times (randomized order)
      property "createInstance returns distinct instances for multiple calls" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Randomly select an unlocked ability ID to test
          local randomIndex = math.random(1, #unlockedAbilityIds)
          local abilityId = unlockedAbilityIds[randomIndex]

          -- Create multiple instances of the same ability
          local instance1 = ability_registry.createInstance(abilityId)
          local instance2 = ability_registry.createInstance(abilityId)
          local instance3 = ability_registry.createInstance(abilityId)

          -- Verify all instances were created successfully
          if not instance1 then
            return false, "createInstance('" .. abilityId .. "') returned nil for unlocked ability (instance 1)"
          end

          if not instance2 then
            return false, "createInstance('" .. abilityId .. "') returned nil for unlocked ability (instance 2)"
          end

          if not instance3 then
            return false, "createInstance('" .. abilityId .. "') returned nil for unlocked ability (instance 3)"
          end

          -- Verify instances are distinct (different object references)
          if instance1 == instance2 then
            return false, "createInstance('" .. abilityId .. "') returned same reference for instance 1 and 2 (should be distinct)"
          end

          if instance1 == instance3 then
            return false, "createInstance('" .. abilityId .. "') returned same reference for instance 1 and 3 (should be distinct)"
          end

          if instance2 == instance3 then
            return false, "createInstance('" .. abilityId .. "') returned same reference for instance 2 and 3 (should be distinct)"
          end

          -- Verify instances have the same initial properties
          -- Check that all instances have the same id
          if instance1.id ~= instance2.id or instance1.id ~= instance3.id then
            return false, "Instances of '" .. abilityId .. "' have different id properties: " .. tostring(instance1.id) .. ", " .. tostring(instance2.id) .. ", " .. tostring(instance3.id)
          end

          -- Check that all instances have the same tier (should be 1 for new instances)
          if instance1.tier ~= instance2.tier or instance1.tier ~= instance3.tier then
            return false, "Instances of '" .. abilityId .. "' have different tier properties: " .. tostring(instance1.tier) .. ", " .. tostring(instance2.tier) .. ", " .. tostring(instance3.tier)
          end

          -- Check that all instances have the same cooldown
          if instance1.cooldown ~= instance2.cooldown or instance1.cooldown ~= instance3.cooldown then
            return false, "Instances of '" .. abilityId .. "' have different cooldown properties: " .. tostring(instance1.cooldown) .. ", " .. tostring(instance2.cooldown) .. ", " .. tostring(instance3.cooldown)
          end

          -- Verify instances are tables (objects)
          if type(instance1) ~= "table" or type(instance2) ~= "table" or type(instance3) ~= "table" then
            return false, "createInstance('" .. abilityId .. "') returned non-table type"
          end

          return true
        end
      }
    end)

    it("should return nil for invalid or non-existent ability IDs", function()
      -- **Validates: Requirements 1.5**

      -- Property: For any invalid ability id, calling createInstance(id) should return nil

      property "createInstance returns nil for invalid IDs" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Generate random invalid ability IDs
          local invalidIds = {
            "invalid_ability_" .. math.random(1000, 9999),
            "nonexistent_" .. math.random(1000, 9999),
            "",
            "   ",
            "ability_that_does_not_exist",
            "test_" .. math.random(1000, 9999),
            "fake_ability_" .. math.random(1000, 9999)
          }

          -- Randomly select an invalid ID
          local randomIndex = math.random(1, #invalidIds)
          local invalidId = invalidIds[randomIndex]

          -- Ensure the ID is not actually in the registry
          if ability_registry.abilities[invalidId] then
            -- Skip this iteration if we accidentally generated a valid ID
            return true
          end

          -- Try to create an instance with invalid ID
          local instance = ability_registry.createInstance(invalidId)

          -- Verify nil is returned for invalid ID
          if instance ~= nil then
            return false, "createInstance('" .. invalidId .. "') should return nil for invalid ID, got: " .. type(instance)
          end

          return true
        end
      }
    end)

    it("should create instances that are independent (modifying one does not affect others)", function()
      -- **Validates: Requirements 1.5**

      -- Property: Instances created from the same ability should be independent
      -- (modifying one instance should not affect other instances)

      property "Instances are independent and do not share state" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Get all unlocked ability IDs from the registry
          local unlockedAbilityIds = {}
          for id, def in pairs(ability_registry.abilities) do
            if def.unlocked == true then
              table.insert(unlockedAbilityIds, id)
            end
          end

          if #unlockedAbilityIds == 0 then
            return false, "No unlocked abilities in registry to test"
          end

          -- Randomly select an unlocked ability ID to test
          local randomIndex = math.random(1, #unlockedAbilityIds)
          local abilityId = unlockedAbilityIds[randomIndex]

          -- Create two instances
          local instance1 = ability_registry.createInstance(abilityId)
          local instance2 = ability_registry.createInstance(abilityId)

          if not instance1 or not instance2 then
            return false, "Failed to create instances for '" .. abilityId .. "'"
          end

          -- Store original values
          local originalTier1 = instance1.tier
          local originalTier2 = instance2.tier

          -- Modify instance1
          instance1.tier = 999
          instance1.cooldown = 12345

          -- Verify instance2 is unaffected
          if instance2.tier ~= originalTier2 then
            return false, "Modifying instance1.tier affected instance2.tier (instances share state)"
          end

          -- Verify instance1 was actually modified
          if instance1.tier ~= 999 then
            return false, "Failed to modify instance1.tier"
          end

          -- Restore instance1 for cleanliness
          instance1.tier = originalTier1

          return true
        end
      }
    end)
  end)

  -- Feature: ability-selection, Property 3: Unlock Status Query
  describe("Property 3: Unlock Status Query", function()
    it("should return a boolean value that matches the definition's unlocked field for any ability", function()
      -- **Validates: Requirements 1.4, 7.2**

      -- Property: For any ability definition in the registry, calling isUnlocked(id)
      -- should return a boolean value that matches the definition's unlocked field.

      -- Get all ability IDs from the registry
      local abilityIds = {}
      for id, _ in pairs(ability_registry.abilities) do
        table.insert(abilityIds, id)
      end

      -- Ensure we have at least one ability to test
      assert.is_true(#abilityIds > 0, "Registry should have at least one ability")

      -- Test unlock status for each ability 100 times (randomized order)
      property "isUnlocked returns correct boolean matching definition's unlocked field" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Randomly select an ability ID to test
          local randomIndex = math.random(1, #abilityIds)
          local abilityId = abilityIds[randomIndex]

          -- Get the ability definition directly from registry
          local abilityDef = ability_registry.abilities[abilityId]

          -- Verify definition exists
          if not abilityDef then
            return false, "Ability definition for '" .. abilityId .. "' is nil"
          end

          -- Get the unlock status via isUnlocked method
          local unlockStatus = ability_registry.isUnlocked(abilityId)

          -- Verify isUnlocked returns a boolean
          if type(unlockStatus) ~= "boolean" then
            return false, "isUnlocked('" .. abilityId .. "') returned non-boolean type: " .. type(unlockStatus)
          end

          -- Verify the returned value matches the definition's unlocked field
          local expectedUnlocked = (abilityDef.unlocked == true)
          if unlockStatus ~= expectedUnlocked then
            return false, "isUnlocked('" .. abilityId .. "') returned " .. tostring(unlockStatus) .. " but definition.unlocked is " .. tostring(abilityDef.unlocked)
          end

          return true
        end
      }
    end)

    it("should return nil for invalid or non-existent ability IDs", function()
      -- **Validates: Requirements 1.3**

      -- Property: For any invalid ability id, calling getAbility(id) should return nil

      property "getAbility returns nil for invalid IDs" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Generate random invalid ability IDs
          local invalidIds = {
            "invalid_ability_" .. math.random(1000, 9999),
            "nonexistent_" .. math.random(1000, 9999),
            "",
            "   ",
            "ability_that_does_not_exist",
            "test_" .. math.random(1000, 9999)
          }

          -- Randomly select an invalid ID
          local randomIndex = math.random(1, #invalidIds)
          local invalidId = invalidIds[randomIndex]

          -- Ensure the ID is not actually in the registry
          if ability_registry.abilities[invalidId] then
            -- Skip this iteration if we accidentally generated a valid ID
            return true
          end

          -- Get the ability definition via getAbility method
          local retrievedDef = ability_registry.getAbility(invalidId)

          -- Verify nil is returned for invalid ID
          if retrievedDef ~= nil then
            return false, "getAbility('" .. invalidId .. "') should return nil for invalid ID, got: " .. type(retrievedDef)
          end

          return true
        end
      }
    end)

    it("should maintain referential integrity (same reference for multiple calls)", function()
      -- **Validates: Requirements 1.3**

      -- Property: Multiple calls to getAbility with the same ID should return
      -- the same reference (not a copy)

      property "getAbility returns same reference for multiple calls" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Get all ability IDs from the registry
          local abilityIds = {}
          for id, _ in pairs(ability_registry.abilities) do
            table.insert(abilityIds, id)
          end

          if #abilityIds == 0 then
            return false, "No abilities in registry to test"
          end

          -- Randomly select an ability ID to test
          local randomIndex = math.random(1, #abilityIds)
          local abilityId = abilityIds[randomIndex]

          -- Call getAbility multiple times
          local def1 = ability_registry.getAbility(abilityId)
          local def2 = ability_registry.getAbility(abilityId)
          local def3 = ability_registry.getAbility(abilityId)

          -- Verify all calls return the same reference
          if def1 ~= def2 then
            return false, "getAbility('" .. abilityId .. "') returned different references on consecutive calls (call 1 vs 2)"
          end

          if def1 ~= def3 then
            return false, "getAbility('" .. abilityId .. "') returned different references on consecutive calls (call 1 vs 3)"
          end

          if def2 ~= def3 then
            return false, "getAbility('" .. abilityId .. "') returned different references on consecutive calls (call 2 vs 3)"
          end

          return true
        end
      }
    end)

    it("should return false for invalid or non-existent ability IDs", function()
      -- **Validates: Requirements 1.4, 7.2**

      -- Property: For any invalid ability id, calling isUnlocked(id) should return false

      property "isUnlocked returns false for invalid IDs" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Generate random invalid ability IDs
          local invalidIds = {
            "invalid_ability_" .. math.random(1000, 9999),
            "nonexistent_" .. math.random(1000, 9999),
            "",
            "   ",
            "ability_that_does_not_exist",
            "test_" .. math.random(1000, 9999),
            "locked_ability_" .. math.random(1000, 9999)
          }

          -- Randomly select an invalid ID
          local randomIndex = math.random(1, #invalidIds)
          local invalidId = invalidIds[randomIndex]

          -- Ensure the ID is not actually in the registry
          if ability_registry.abilities[invalidId] then
            -- Skip this iteration if we accidentally generated a valid ID
            return true
          end

          -- Get the unlock status via isUnlocked method
          local unlockStatus = ability_registry.isUnlocked(invalidId)

          -- Verify false is returned for invalid ID
          if unlockStatus ~= false then
            return false, "isUnlocked('" .. invalidId .. "') should return false for invalid ID, got: " .. tostring(unlockStatus)
          end

          -- Verify the return type is boolean
          if type(unlockStatus) ~= "boolean" then
            return false, "isUnlocked('" .. invalidId .. "') should return boolean, got: " .. type(unlockStatus)
          end

          return true
        end
      }
    end)

    it("should maintain consistency across multiple calls for the same ability", function()
      -- **Validates: Requirements 1.4, 7.2**

      -- Property: Multiple calls to isUnlocked with the same ID should return
      -- the same boolean value (consistent results)

      property "isUnlocked returns consistent results for multiple calls" {
        generators = {
          lqc_gen.choose(1, 100)  -- Iteration counter
        },
        check = function(iteration)
          -- Get all ability IDs from the registry
          local abilityIds = {}
          for id, _ in pairs(ability_registry.abilities) do
            table.insert(abilityIds, id)
          end

          if #abilityIds == 0 then
            return false, "No abilities in registry to test"
          end

          -- Randomly select an ability ID to test
          local randomIndex = math.random(1, #abilityIds)
          local abilityId = abilityIds[randomIndex]

          -- Call isUnlocked multiple times
          local status1 = ability_registry.isUnlocked(abilityId)
          local status2 = ability_registry.isUnlocked(abilityId)
          local status3 = ability_registry.isUnlocked(abilityId)

          -- Verify all calls return the same value
          if status1 ~= status2 then
            return false, "isUnlocked('" .. abilityId .. "') returned different values on consecutive calls (call 1 vs 2): " .. tostring(status1) .. " vs " .. tostring(status2)
          end

          if status1 ~= status3 then
            return false, "isUnlocked('" .. abilityId .. "') returned different values on consecutive calls (call 1 vs 3): " .. tostring(status1) .. " vs " .. tostring(status3)
          end

          if status2 ~= status3 then
            return false, "isUnlocked('" .. abilityId .. "') returned different values on consecutive calls (call 2 vs 3): " .. tostring(status2) .. " vs " .. tostring(status3)
          end

          return true
        end
      }
    end)
  end)
end)
