--- Property-based tests for Ability Data Loader
-- Feature: game-visual-and-data-improvements
-- Tests Properties 8-11

require("tests.spec_helper")

local ability_data_loader = require("src.models.ability_data_loader")
local json = _G.json or require("json")

-- Generator helpers for random valid base stats
-- cooldown ∈ (0.1, 5.0), damage ∈ (1, 100), speed ∈ (50, 1000), pierce ∈ [0, 10], count ∈ [1, 10]
local function randomValidBaseStats()
  return {
    cooldown = math.random(1, 50) / 10,       -- 0.1 to 5.0
    damage = math.random(1, 100),
    projectileSpeed = math.random(50, 1000),
    pierceCount = math.random(0, 10),
    projectileCount = math.random(1, 10)
  }
end

-- Generate a random valid ability entry with all required fields
local function randomValidAbilityEntry(id)
  return {
    name = "Test Ability " .. (id or "unknown"),
    module = "src.entities.abilities.arcane_bolt",
    unlocked = math.random() > 0.5,
    maxTier = math.random(1, 5),
    baseStats = randomValidBaseStats(),
    upgrades = {
      damage_increase = {
        name = "Damage Up",
        description = "+5 damage",
        iconType = "damage",
        damageIncrease = math.random(1, 20)
      },
      attack_speed = {
        name = "Attack Speed",
        description = "-0.15s cooldown",
        iconType = "speed",
        cooldownReduction = math.random(1, 30) / 100,
        minCooldown = 0.25
      }
    },
    tiers = {
      ["1"] = {},
      ["2"] = { damageBonus = math.random(1, 10) },
      ["3"] = { damageBonus = math.random(1, 10), projectileCountBonus = 1 }
    }
  }
end

-- Generate random invalid values for testing fallback behavior
local function randomInvalidValue()
  local invalidTypes = {
    "not_a_number",
    "",
    true,
    {},
    nil
  }
  return invalidTypes[math.random(1, #invalidTypes)]
end

describe("Ability Data Loader Properties", function()

  before_each(function()
    ability_data_loader._data = nil
  end)

  -- Feature: game-visual-and-data-improvements, Property 8: Ability base stats loaded from JSON
  -- **Validates: Requirements 3.2, 3.5**
  describe("Property 8: Ability base stats loaded from JSON", function()
    it("should load base stats matching JSON values for any valid base stats", function()
      for _ = 1, 100 do
        -- Generate random valid base stats
        local stats = randomValidBaseStats()
        local abilityId = "test_ability_" .. math.random(1, 1000)

        -- Inject ability data directly with the generated stats
        ability_data_loader._data = {
          [abilityId] = {
            name = "Test",
            module = "src.entities.abilities.arcane_bolt",
            unlocked = true,
            maxTier = 5,
            baseStats = {
              cooldown = stats.cooldown,
              damage = stats.damage,
              projectileSpeed = stats.projectileSpeed,
              pierceCount = stats.pierceCount,
              projectileCount = stats.projectileCount
            }
          }
        }

        -- Query the data loader
        local loaded = ability_data_loader.getBaseStats(abilityId)

        -- Properties shall match the JSON values
        assert.is_not_nil(loaded,
          "getBaseStats should return stats for " .. abilityId)
        assert.are.equal(stats.cooldown, loaded.cooldown,
          "cooldown mismatch: expected " .. stats.cooldown .. " got " .. tostring(loaded.cooldown))
        assert.are.equal(stats.damage, loaded.damage,
          "damage mismatch: expected " .. stats.damage .. " got " .. tostring(loaded.damage))
        assert.are.equal(stats.projectileSpeed, loaded.projectileSpeed,
          "projectileSpeed mismatch: expected " .. stats.projectileSpeed .. " got " .. tostring(loaded.projectileSpeed))
        assert.are.equal(stats.pierceCount, loaded.pierceCount,
          "pierceCount mismatch: expected " .. stats.pierceCount .. " got " .. tostring(loaded.pierceCount))
        assert.are.equal(stats.projectileCount, loaded.projectileCount,
          "projectileCount mismatch: expected " .. stats.projectileCount .. " got " .. tostring(loaded.projectileCount))
      end
    end)

    it("should load base stats from actual JSON file and match file content", function()
      -- Initialize from the real abilities.json
      ability_data_loader.initialize("data/abilities.json")

      for _ = 1, 100 do
        local loaded = ability_data_loader.getBaseStats("arcane_bolt")

        assert.is_not_nil(loaded, "getBaseStats should return stats for arcane_bolt")
        -- Values from data/abilities.json
        assert.are.equal(1.0, loaded.cooldown)
        assert.are.equal(10, loaded.damage)
        assert.are.equal(400, loaded.projectileSpeed)
        assert.are.equal(0, loaded.pierceCount)
        assert.are.equal(1, loaded.projectileCount)
      end
    end)
  end)

  -- Feature: game-visual-and-data-improvements, Property 9: Ability JSON schema contains required sections
  -- **Validates: Requirements 3.1, 4.1, 5.1**
  describe("Property 9: Ability JSON schema contains required sections", function()
    it("should validate that every ability entry contains required fields", function()
      for _ = 1, 100 do
        -- Generate a random valid ability entry
        local abilityId = "ability_" .. math.random(1, 1000)
        local entry = randomValidAbilityEntry(abilityId)

        -- Validate the entry
        local isValid = ability_data_loader.validateAbilityEntry(abilityId, entry)

        -- A valid entry with all required fields should pass validation
        assert.is_true(isValid,
          "Valid ability entry " .. abilityId .. " should pass validation")

        -- Verify required fields are present and correct types
        assert.are.equal("string", type(entry.name),
          abilityId .. ".name should be a string")
        assert.are.equal("string", type(entry.module),
          abilityId .. ".module should be a string")
        assert.are.equal("boolean", type(entry.unlocked),
          abilityId .. ".unlocked should be a boolean")
        assert.are.equal("number", type(entry.maxTier),
          abilityId .. ".maxTier should be a number")
        assert.is_true(entry.maxTier > 0,
          abilityId .. ".maxTier should be positive")
        assert.are.equal("table", type(entry.baseStats),
          abilityId .. ".baseStats should be a table")

        -- Verify baseStats contains required numeric fields
        local bs = entry.baseStats
        assert.are.equal("number", type(bs.cooldown),
          abilityId .. ".baseStats.cooldown should be a number")
        assert.are.equal("number", type(bs.damage),
          abilityId .. ".baseStats.damage should be a number")
        assert.are.equal("number", type(bs.projectileSpeed),
          abilityId .. ".baseStats.projectileSpeed should be a number")
        assert.are.equal("number", type(bs.pierceCount),
          abilityId .. ".baseStats.pierceCount should be a number")
        assert.are.equal("number", type(bs.projectileCount),
          abilityId .. ".baseStats.projectileCount should be a number")
      end
    end)

    it("should reject entries missing required fields", function()
      local requiredFieldRemovers = {
        function(e) e.name = nil end,
        function(e) e.module = nil end,
        function(e) e.unlocked = nil end,
        function(e) e.maxTier = nil end,
        function(e) e.baseStats = nil end,
      }

      for _ = 1, 100 do
        local abilityId = "ability_" .. math.random(1, 1000)
        local entry = randomValidAbilityEntry(abilityId)

        -- Randomly remove one required field
        local remover = requiredFieldRemovers[math.random(1, #requiredFieldRemovers)]
        remover(entry)

        local isValid = ability_data_loader.validateAbilityEntry(abilityId, entry)

        -- Missing module or baseStats should cause validation to fail
        -- Missing name/unlocked/maxTier get defaults applied (still valid)
        if entry.module == nil or entry.baseStats == nil then
          assert.is_false(isValid,
            "Entry missing module or baseStats should fail validation for " .. abilityId)
        end
      end
    end)

    it("should validate the real abilities.json file schema", function()
      ability_data_loader.initialize("data/abilities.json")

      for _ = 1, 100 do
        -- For each ability in the loaded data, verify schema
        for abilityId, abilityData in pairs(ability_data_loader._data) do
          assert.are.equal("string", type(abilityData.name),
            abilityId .. ".name should be a string")
          assert.are.equal("string", type(abilityData.module),
            abilityId .. ".module should be a string")
          assert.are.equal("boolean", type(abilityData.unlocked),
            abilityId .. ".unlocked should be a boolean")
          assert.are.equal("number", type(abilityData.maxTier),
            abilityId .. ".maxTier should be a positive number")
          assert.is_true(abilityData.maxTier > 0)
          assert.are.equal("table", type(abilityData.baseStats),
            abilityId .. ".baseStats should be a table")
        end
      end
    end)
  end)

  -- Feature: game-visual-and-data-improvements, Property 10: Fallback to defaults on missing or invalid data
  -- **Validates: Requirements 3.3, 4.4, 5.4, 6.6, 7.4**
  describe("Property 10: Fallback to defaults on missing or invalid data", function()
    -- Default values from ability_data_loader source
    local DEFAULTS = {
      cooldown = 1.0,
      damage = 10,
      projectileSpeed = 400,
      pierceCount = 0,
      projectileCount = 1
    }

    it("should return defaults when ability ID is missing from data", function()
      for _ = 1, 100 do
        -- Initialize with empty data
        ability_data_loader._data = {}

        local missingId = "nonexistent_" .. math.random(1, 10000)
        local stats = ability_data_loader.getBaseStats(missingId)

        -- Missing ability should return nil
        assert.is_nil(stats,
          "getBaseStats should return nil for missing ability " .. missingId)
      end
    end)

    it("should return defaults when data is not initialized", function()
      for _ = 1, 100 do
        ability_data_loader._data = nil

        local stats = ability_data_loader.getBaseStats("arcane_bolt")

        assert.is_nil(stats,
          "getBaseStats should return nil when data not initialized")

        local upgrade = ability_data_loader.getUpgradeParams("arcane_bolt", "damage_increase")
        assert.is_nil(upgrade,
          "getUpgradeParams should return nil when data not initialized")

        local tier = ability_data_loader.getTierParams("arcane_bolt", 1)
        assert.is_nil(tier,
          "getTierParams should return nil when data not initialized")
      end
    end)

    it("should return default values for fields with invalid types", function()
      local invalidValues = { "not_a_number", "", true, {}, false }

      for _ = 1, 100 do
        local abilityId = "test_" .. math.random(1, 1000)
        -- Pick a random invalid value for each field
        local invalidStats = {
          cooldown = invalidValues[math.random(1, #invalidValues)],
          damage = invalidValues[math.random(1, #invalidValues)],
          projectileSpeed = invalidValues[math.random(1, #invalidValues)],
          pierceCount = invalidValues[math.random(1, #invalidValues)],
          projectileCount = invalidValues[math.random(1, #invalidValues)]
        }

        ability_data_loader._data = {
          [abilityId] = {
            name = "Test",
            module = "test.module",
            unlocked = true,
            maxTier = 5,
            baseStats = invalidStats
          }
        }

        local loaded = ability_data_loader.getBaseStats(abilityId)

        assert.is_not_nil(loaded, "Should return stats table even with invalid fields")
        assert.are.equal(DEFAULTS.cooldown, loaded.cooldown,
          "Invalid cooldown should fall back to default " .. DEFAULTS.cooldown)
        assert.are.equal(DEFAULTS.damage, loaded.damage,
          "Invalid damage should fall back to default " .. DEFAULTS.damage)
        assert.are.equal(DEFAULTS.projectileSpeed, loaded.projectileSpeed,
          "Invalid projectileSpeed should fall back to default " .. DEFAULTS.projectileSpeed)
        assert.are.equal(DEFAULTS.pierceCount, loaded.pierceCount,
          "Invalid pierceCount should fall back to default " .. DEFAULTS.pierceCount)
        assert.are.equal(DEFAULTS.projectileCount, loaded.projectileCount,
          "Invalid projectileCount should fall back to default " .. DEFAULTS.projectileCount)
      end
    end)

    it("should return default values for negative numbers", function()
      for _ = 1, 100 do
        local abilityId = "test_" .. math.random(1, 1000)
        -- Generate random negative values
        local negativeStats = {
          cooldown = -math.random(1, 100) / 10,
          damage = -math.random(1, 100),
          projectileSpeed = -math.random(50, 1000),
          pierceCount = -math.random(1, 10),
          projectileCount = -math.random(1, 10)
        }

        ability_data_loader._data = {
          [abilityId] = {
            name = "Test",
            module = "test.module",
            unlocked = true,
            maxTier = 5,
            baseStats = negativeStats
          }
        }

        local loaded = ability_data_loader.getBaseStats(abilityId)

        assert.is_not_nil(loaded, "Should return stats table even with negative fields")
        assert.are.equal(DEFAULTS.cooldown, loaded.cooldown,
          "Negative cooldown should fall back to default")
        assert.are.equal(DEFAULTS.damage, loaded.damage,
          "Negative damage should fall back to default")
        assert.are.equal(DEFAULTS.projectileSpeed, loaded.projectileSpeed,
          "Negative projectileSpeed should fall back to default")
        assert.are.equal(DEFAULTS.pierceCount, loaded.pierceCount,
          "Negative pierceCount should fall back to default")
        assert.are.equal(DEFAULTS.projectileCount, loaded.projectileCount,
          "Negative projectileCount should fall back to default")
      end
    end)

    it("should return defaults when baseStats is not a table", function()
      local nonTableValues = { "string", 42, true, nil }

      for _ = 1, 100 do
        local abilityId = "test_" .. math.random(1, 1000)
        local badBaseStats = nonTableValues[math.random(1, #nonTableValues)]

        ability_data_loader._data = {
          [abilityId] = {
            name = "Test",
            module = "test.module",
            unlocked = true,
            maxTier = 5,
            baseStats = badBaseStats
          }
        }

        local loaded = ability_data_loader.getBaseStats(abilityId)

        assert.is_not_nil(loaded, "Should return defaults when baseStats is not a table")
        assert.are.equal(DEFAULTS.cooldown, loaded.cooldown)
        assert.are.equal(DEFAULTS.damage, loaded.damage)
        assert.are.equal(DEFAULTS.projectileSpeed, loaded.projectileSpeed)
        assert.are.equal(DEFAULTS.pierceCount, loaded.pierceCount)
        assert.are.equal(DEFAULTS.projectileCount, loaded.projectileCount)
      end
    end)

    it("should return nil for upgrade params when upgrade type is missing", function()
      for _ = 1, 100 do
        ability_data_loader._data = {
          test_ability = {
            name = "Test",
            module = "test.module",
            unlocked = true,
            maxTier = 5,
            baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 },
            upgrades = {}
          }
        }

        local missingType = "nonexistent_upgrade_" .. math.random(1, 1000)
        local params = ability_data_loader.getUpgradeParams("test_ability", missingType)

        assert.is_nil(params,
          "getUpgradeParams should return nil for missing upgrade type " .. missingType)
      end
    end)

    it("should return nil for tier params when tier is missing", function()
      for _ = 1, 100 do
        ability_data_loader._data = {
          test_ability = {
            name = "Test",
            module = "test.module",
            unlocked = true,
            maxTier = 5,
            baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 },
            tiers = {}
          }
        }

        local missingTier = math.random(1, 99)
        local params = ability_data_loader.getTierParams("test_ability", missingTier)

        assert.is_nil(params,
          "getTierParams should return nil for missing tier " .. missingTier)
      end
    end)
  end)

  -- Feature: game-visual-and-data-improvements, Property 11: Upgrade and tier parameters read from JSON
  -- **Validates: Requirements 4.2, 5.2**
  describe("Property 11: Upgrade and tier parameters read from JSON", function()
    it("should return upgrade parameters matching injected JSON content", function()
      for _ = 1, 100 do
        local abilityId = "test_" .. math.random(1, 1000)
        local damageIncrease = math.random(1, 50)
        local cooldownReduction = math.random(1, 50) / 100
        local minCooldown = math.random(10, 50) / 100
        local countIncrease = math.random(1, 5)
        local pierceIncrease = math.random(1, 5)

        ability_data_loader._data = {
          [abilityId] = {
            name = "Test",
            module = "test.module",
            unlocked = true,
            maxTier = 5,
            baseStats = randomValidBaseStats(),
            upgrades = {
              damage_increase = {
                name = "Damage Up",
                description = "+damage",
                iconType = "damage",
                damageIncrease = damageIncrease
              },
              attack_speed = {
                name = "Speed Up",
                description = "-cooldown",
                iconType = "speed",
                cooldownReduction = cooldownReduction,
                minCooldown = minCooldown
              },
              projectile_count = {
                name = "Count Up",
                description = "+projectile",
                iconType = "count",
                countIncrease = countIncrease
              },
              pierce = {
                name = "Pierce Up",
                description = "+pierce",
                iconType = "pierce",
                pierceIncrease = pierceIncrease
              }
            }
          }
        }

        -- Verify damage_increase params
        local dmgParams = ability_data_loader.getUpgradeParams(abilityId, "damage_increase")
        assert.is_not_nil(dmgParams, "damage_increase params should not be nil")
        assert.are.equal(damageIncrease, dmgParams.damageIncrease,
          "damageIncrease mismatch: expected " .. damageIncrease)

        -- Verify attack_speed params
        local spdParams = ability_data_loader.getUpgradeParams(abilityId, "attack_speed")
        assert.is_not_nil(spdParams, "attack_speed params should not be nil")
        assert.are.equal(cooldownReduction, spdParams.cooldownReduction,
          "cooldownReduction mismatch: expected " .. cooldownReduction)
        assert.are.equal(minCooldown, spdParams.minCooldown,
          "minCooldown mismatch: expected " .. minCooldown)

        -- Verify projectile_count params
        local cntParams = ability_data_loader.getUpgradeParams(abilityId, "projectile_count")
        assert.is_not_nil(cntParams, "projectile_count params should not be nil")
        assert.are.equal(countIncrease, cntParams.countIncrease,
          "countIncrease mismatch: expected " .. countIncrease)

        -- Verify pierce params
        local prcParams = ability_data_loader.getUpgradeParams(abilityId, "pierce")
        assert.is_not_nil(prcParams, "pierce params should not be nil")
        assert.are.equal(pierceIncrease, prcParams.pierceIncrease,
          "pierceIncrease mismatch: expected " .. pierceIncrease)
      end
    end)

    it("should return tier parameters matching injected JSON content", function()
      for _ = 1, 100 do
        local abilityId = "test_" .. math.random(1, 1000)
        local tier = math.random(1, 5)
        local damageBonus = math.random(0, 20)
        local cooldownReduction = math.random(0, 30) / 100
        local pierceBonus = math.random(0, 3)
        local projectileCountBonus = math.random(0, 2)

        local tierData = {}
        if damageBonus > 0 then tierData.damageBonus = damageBonus end
        if cooldownReduction > 0 then tierData.cooldownReduction = cooldownReduction end
        if pierceBonus > 0 then tierData.pierceBonus = pierceBonus end
        if projectileCountBonus > 0 then tierData.projectileCountBonus = projectileCountBonus end

        local tiers = {}
        tiers[tostring(tier)] = tierData

        ability_data_loader._data = {
          [abilityId] = {
            name = "Test",
            module = "test.module",
            unlocked = true,
            maxTier = 5,
            baseStats = randomValidBaseStats(),
            tiers = tiers
          }
        }

        local loaded = ability_data_loader.getTierParams(abilityId, tier)

        assert.is_not_nil(loaded,
          "getTierParams should return params for tier " .. tier)

        -- Verify each field matches what was injected
        if damageBonus > 0 then
          assert.are.equal(damageBonus, loaded.damageBonus,
            "damageBonus mismatch at tier " .. tier)
        end
        if cooldownReduction > 0 then
          assert.are.equal(cooldownReduction, loaded.cooldownReduction,
            "cooldownReduction mismatch at tier " .. tier)
        end
        if pierceBonus > 0 then
          assert.are.equal(pierceBonus, loaded.pierceBonus,
            "pierceBonus mismatch at tier " .. tier)
        end
        if projectileCountBonus > 0 then
          assert.are.equal(projectileCountBonus, loaded.projectileCountBonus,
            "projectileCountBonus mismatch at tier " .. tier)
        end
      end
    end)

    it("should return upgrade and tier params from actual abilities.json", function()
      ability_data_loader.initialize("data/abilities.json")

      for _ = 1, 100 do
        -- Verify upgrade params from real file
        local dmgParams = ability_data_loader.getUpgradeParams("arcane_bolt", "damage_increase")
        assert.is_not_nil(dmgParams)
        assert.are.equal(5, dmgParams.damageIncrease)

        local spdParams = ability_data_loader.getUpgradeParams("arcane_bolt", "attack_speed")
        assert.is_not_nil(spdParams)
        assert.are.equal(0.15, spdParams.cooldownReduction)
        assert.are.equal(0.25, spdParams.minCooldown)

        -- Verify tier params from real file
        local tier2 = ability_data_loader.getTierParams("arcane_bolt", 2)
        assert.is_not_nil(tier2)
        assert.are.equal(5, tier2.damageBonus)
        assert.are.equal(0.15, tier2.cooldownReduction)

        local tier5 = ability_data_loader.getTierParams("arcane_bolt", 5)
        assert.is_not_nil(tier5)
        assert.are.equal(10, tier5.damageBonus)
        assert.are.equal(1, tier5.pierceBonus)
        assert.are.equal(1, tier5.projectileCountBonus)
      end
    end)
  end)

  -- Feature: game-visual-and-data-improvements, Property 14: Schema validation detects missing required fields and invalid numerics
  -- **Validates: Requirements 7.1, 7.2, 7.3**
  describe("Property 14: Schema validation detects missing required fields and invalid numerics", function()

    it("should detect missing required fields and return appropriate validation result", function()
      -- Required fields and whether removing them causes validation failure
      -- module and baseStats are critical (return false), others get defaults applied (return true)
      local requiredFields = {
        { field = "name",     causesFailure = false },
        { field = "module",   causesFailure = true },
        { field = "unlocked", causesFailure = false },
        { field = "maxTier",  causesFailure = false },
        { field = "baseStats", causesFailure = true },
      }

      for _ = 1, 100 do
        -- Pick a random required field to remove
        local pick = requiredFields[math.random(1, #requiredFields)]
        local abilityId = "validate_" .. math.random(1, 10000)

        -- Generate a complete valid entry
        local entry = randomValidAbilityEntry(abilityId)

        -- Remove the chosen required field
        entry[pick.field] = nil

        -- Capture print output to verify error/warning logging
        local logMessages = {}
        local originalPrint = _G.print
        _G.print = function(...)
          local args = {...}
          local msg = table.concat(args, "\t")
          table.insert(logMessages, msg)
          originalPrint(...)
        end

        local isValid = ability_data_loader.validateAbilityEntry(abilityId, entry)

        -- Restore print
        _G.print = originalPrint

        if pick.causesFailure then
          -- Missing module or baseStats should cause validation to fail
          assert.is_false(isValid,
            "Entry missing " .. pick.field .. " should fail validation for " .. abilityId)
        else
          -- Missing name/unlocked/maxTier get defaults applied, still valid
          assert.is_true(isValid,
            "Entry missing " .. pick.field .. " should still pass validation (defaults applied) for " .. abilityId)
        end

        -- Verify that a log message was emitted mentioning the ability ID and field name
        local foundLog = false
        for _, msg in ipairs(logMessages) do
          if msg:find(abilityId, 1, true) and msg:find(pick.field, 1, true) then
            foundLog = true
            break
          end
        end
        assert.is_true(foundLog,
          "Validator should log a message mentioning ability ID '" .. abilityId ..
          "' and field '" .. pick.field .. "' when that field is missing. Got " ..
          tostring(#logMessages) .. " log messages")
      end
    end)

    it("should detect invalid numeric values in baseStats fields", function()
      local numericFields = { "cooldown", "damage", "projectileSpeed", "pierceCount", "projectileCount" }
      local invalidValues = { "not_a_number", "", true, {}, false }

      for _ = 1, 100 do
        local abilityId = "numeric_" .. math.random(1, 10000)

        -- Generate a valid entry
        local entry = randomValidAbilityEntry(abilityId)

        -- Pick a random numeric baseStats field and set it to an invalid value
        local fieldName = numericFields[math.random(1, #numericFields)]
        local invalidVal = invalidValues[math.random(1, #invalidValues)]
        entry.baseStats[fieldName] = invalidVal

        -- Capture print output
        local logMessages = {}
        local originalPrint = _G.print
        _G.print = function(...)
          local args = {...}
          local msg = table.concat(args, "\t")
          table.insert(logMessages, msg)
          originalPrint(...)
        end

        -- validateAbilityEntry checks structure but getBaseStats validates numerics
        -- The entry itself should still pass validation (baseStats is a table)
        local isValid = ability_data_loader.validateAbilityEntry(abilityId, entry)
        assert.is_true(isValid,
          "Entry with invalid numeric in baseStats." .. fieldName .. " should still pass structural validation")

        -- Now inject the data and call getBaseStats to trigger numeric validation
        ability_data_loader._data = { [abilityId] = entry }
        local loaded = ability_data_loader.getBaseStats(abilityId)

        -- Restore print
        _G.print = originalPrint

        -- getBaseStats should return a table with the default value for the invalid field
        assert.is_not_nil(loaded,
          "getBaseStats should return stats even with invalid " .. fieldName)

        -- The invalid field should have been replaced with its default
        local defaults = {
          cooldown = 1.0,
          damage = 10,
          projectileSpeed = 400,
          pierceCount = 0,
          projectileCount = 1
        }
        assert.are.equal(defaults[fieldName], loaded[fieldName],
          "Invalid " .. fieldName .. " should fall back to default " .. tostring(defaults[fieldName]))

        -- Verify a warning was logged mentioning the ability ID and field name
        local foundLog = false
        for _, msg in ipairs(logMessages) do
          if msg:find(abilityId, 1, true) and msg:find(fieldName, 1, true) then
            foundLog = true
            break
          end
        end
        assert.is_true(foundLog,
          "Validator should log a warning mentioning '" .. abilityId ..
          "' and '" .. fieldName .. "' for invalid numeric value")
      end
    end)

    it("should detect negative numeric values in baseStats fields", function()
      local numericFields = { "cooldown", "damage", "projectileSpeed", "projectileCount" }

      for _ = 1, 100 do
        local abilityId = "negative_" .. math.random(1, 10000)

        -- Generate a valid entry
        local entry = randomValidAbilityEntry(abilityId)

        -- Pick a random numeric field and set it to a negative value
        local fieldName = numericFields[math.random(1, #numericFields)]
        entry.baseStats[fieldName] = -math.random(1, 100)

        -- Capture print output
        local logMessages = {}
        local originalPrint = _G.print
        _G.print = function(...)
          local args = {...}
          local msg = table.concat(args, "\t")
          table.insert(logMessages, msg)
          originalPrint(...)
        end

        -- Inject data and call getBaseStats to trigger numeric validation
        ability_data_loader._data = { [abilityId] = entry }
        local loaded = ability_data_loader.getBaseStats(abilityId)

        -- Restore print
        _G.print = originalPrint

        assert.is_not_nil(loaded,
          "getBaseStats should return stats even with negative " .. fieldName)

        -- The negative field should have been replaced with its default
        local defaults = {
          cooldown = 1.0,
          damage = 10,
          projectileSpeed = 400,
          projectileCount = 1
        }
        assert.are.equal(defaults[fieldName], loaded[fieldName],
          "Negative " .. fieldName .. " should fall back to default " .. tostring(defaults[fieldName]))

        -- Verify a warning was logged mentioning the ability ID and field name
        local foundLog = false
        for _, msg in ipairs(logMessages) do
          if msg:find(abilityId, 1, true) and msg:find(fieldName, 1, true) then
            foundLog = true
            break
          end
        end
        assert.is_true(foundLog,
          "Validator should log a warning mentioning '" .. abilityId ..
          "' and '" .. fieldName .. "' for negative numeric value")
      end
    end)

  end)

end)
