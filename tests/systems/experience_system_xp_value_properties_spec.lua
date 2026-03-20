--- Property-based tests for Experience System XP Value Calculation
-- Feature: automatic-xp-on-defeat
-- Tests Property 3 and Property 4

require("tests.spec_helper")

local experience_system = require("src.systems.experience_system")
local Hero = require("src.entities.hero")

-- **Validates: Requirements 1.3, 3.1, 3.2**
-- Property 3: Configuration-Driven XP Values
describe("Property 3: Configuration-Driven XP Values", function()
  local hero

  before_each(function()
    -- Create hero for initialization
    hero = Hero:new(360, 1180)
    experience_system.initialize(hero, function() end)
  end)

  after_each(function()
    experience_system.cleanup()
    hero = nil
  end)

  it("should return configured XP value for any configured enemy type", function()
    -- Run property test with 100 iterations
    for _ = 1, 100 do
      -- Create test configuration with random enemy types and XP values
      local enemyTypes = {"walker", "runner", "boss", "elite", "minion"}
      local testConfig = {}
      local expectedValues = {}

      -- Generate random XP values for each enemy type
      for _, enemyType in ipairs(enemyTypes) do
        local xpValue = math.random(1, 200)
        testConfig[enemyType] = {
          health = math.random(10, 100),
          speed = math.random(50, 150),
          damage = math.random(5, 50),
          xpValue = xpValue
        }
        expectedValues[enemyType] = xpValue
      end

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Property: For any configured enemy type, getEnemyXPValue should return the configured value
      for _, enemyType in ipairs(enemyTypes) do
        local actualXP = experience_system.getEnemyXPValue(enemyType)
        assert.are.equal(expectedValues[enemyType], actualXP,
          string.format("Enemy type '%s' should return configured XP value %d", enemyType, expectedValues[enemyType]))
      end

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should return different XP values for different enemy types", function()
    -- Run property test with 100 iterations
    for _ = 1, 100 do
      -- Create two enemy types with guaranteed different XP values
      local xpValue1 = math.random(1, 100)
      local xpValue2 = math.random(101, 200)  -- Ensure different from xpValue1

      local testConfig = {
        enemy_type_1 = {
          health = 20,
          speed = 80,
          xpValue = xpValue1
        },
        enemy_type_2 = {
          health = 50,
          speed = 60,
          xpValue = xpValue2
        }
      }

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Property: Different enemy types with different configured XP should return different values
      local actualXP1 = experience_system.getEnemyXPValue("enemy_type_1")
      local actualXP2 = experience_system.getEnemyXPValue("enemy_type_2")

      assert.are.equal(xpValue1, actualXP1, "First enemy type should return its configured XP")
      assert.are.equal(xpValue2, actualXP2, "Second enemy type should return its configured XP")
      assert.are_not.equal(actualXP1, actualXP2, "Different enemy types should return different XP values")

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should consistently return the same XP value for the same enemy type", function()
    -- Run property test with 100 iterations
    for _ = 1, 100 do
      -- Create configuration with random XP value
      local xpValue = math.random(1, 500)
      local testConfig = {
        test_enemy = {
          health = 30,
          speed = 70,
          xpValue = xpValue
        }
      }

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Property: Multiple calls for the same enemy type should return the same value
      local call1 = experience_system.getEnemyXPValue("test_enemy")
      local call2 = experience_system.getEnemyXPValue("test_enemy")
      local call3 = experience_system.getEnemyXPValue("test_enemy")

      assert.are.equal(xpValue, call1, "First call should return configured XP")
      assert.are.equal(call1, call2, "Second call should return same value as first")
      assert.are.equal(call2, call3, "Third call should return same value as second")

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should handle configuration updates correctly", function()
    -- Run property test with 100 iterations
    for _ = 1, 100 do
      -- Create initial configuration
      local initialXP = math.random(1, 100)
      local updatedXP = math.random(101, 200)

      local testConfig = {
        dynamic_enemy = {
          health = 40,
          speed = 90,
          xpValue = initialXP
        }
      }

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Get initial XP value
      local xpBefore = experience_system.getEnemyXPValue("dynamic_enemy")
      assert.are.equal(initialXP, xpBefore, "Should return initial configured XP")

      -- Update configuration
      testConfig.dynamic_enemy.xpValue = updatedXP

      -- Property: After configuration update, should return new value without code changes
      local xpAfter = experience_system.getEnemyXPValue("dynamic_enemy")
      assert.are.equal(updatedXP, xpAfter, "Should return updated configured XP")
      assert.are_not.equal(xpBefore, xpAfter, "XP value should change after configuration update")

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)
end)

-- **Validates: Requirements 3.3**
-- Property 4: Default XP for Unconfigured Enemies
describe("Property 4: Default XP for Unconfigured Enemies", function()
  local hero
  local DEFAULT_XP = 10

  before_each(function()
    -- Create hero for initialization
    hero = Hero:new(360, 1180)
    experience_system.initialize(hero, function() end)
  end)

  after_each(function()
    experience_system.cleanup()
    hero = nil
  end)

  it("should return default XP (10) for any unconfigured enemy type", function()
    -- Run property test with 100 iterations
    for _ = 1, 100 do
      -- Generate random unconfigured enemy type names
      local randomSuffixes = {"_unknown", "_new", "_test", "_random", "_invalid"}
      local randomPrefix = math.random(1, 1000)
      local randomSuffix = randomSuffixes[math.random(1, #randomSuffixes)]
      local unconfiguredType = "enemy_" .. randomPrefix .. randomSuffix

      -- Ensure this type is not in configuration
      local originalConfig = experience_system.enemyConfig
      local testConfig = {}
      for k, v in pairs(originalConfig) do
        if k ~= unconfiguredType and k ~= "_schema" then
          testConfig[k] = v
        end
      end
      experience_system.enemyConfig = testConfig

      -- Property: Any unconfigured enemy type should return default XP (10)
      local actualXP = experience_system.getEnemyXPValue(unconfiguredType)
      assert.are.equal(DEFAULT_XP, actualXP,
        string.format("Unconfigured enemy type '%s' should return default XP %d", unconfiguredType, DEFAULT_XP))

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should return default XP (10) for invalid enemy type parameters", function()
    -- Run property test with 100 iterations
    for _ = 1, 100 do
      -- Generate various invalid parameters
      local invalidParams = {
        nil,
        "",
        123,
        true,
        false,
        {},
        function() end
      }

      local randomInvalid = invalidParams[math.random(1, #invalidParams)]

      -- Property: Any invalid parameter should return default XP (10)
      local actualXP = experience_system.getEnemyXPValue(randomInvalid)
      assert.are.equal(DEFAULT_XP, actualXP,
        string.format("Invalid parameter type should return default XP %d", DEFAULT_XP))
    end
  end)

  it("should return default XP (10) when configuration is missing", function()
    -- Run property test with 100 iterations
    for _ = 1, 100 do
      -- Generate random enemy type name
      local enemyType = "test_enemy_" .. math.random(1, 1000)

      -- Temporarily clear configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = nil

      -- Property: When configuration is missing, should return default XP (10)
      local actualXP = experience_system.getEnemyXPValue(enemyType)
      assert.are.equal(DEFAULT_XP, actualXP,
        "Should return default XP when configuration is missing")

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should return default XP (10) when enemy has invalid xpValue field", function()
    -- Run property test with 100 iterations
    for _ = 1, 100 do
      -- Generate random invalid xpValue types
      local invalidXPValues = {
        "not_a_number",
        "invalid",
        true,
        false,
        {},
        function() end
      }

      local randomInvalidXP = invalidXPValues[math.random(1, #invalidXPValues)]

      local testConfig = {
        invalid_xp_enemy = {
          health = 30,
          speed = 70,
          xpValue = randomInvalidXP
        }
      }

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Property: Enemy with invalid xpValue field should return default XP (10)
      local actualXP = experience_system.getEnemyXPValue("invalid_xp_enemy")
      assert.are.equal(DEFAULT_XP, actualXP,
        "Enemy with invalid xpValue should return default XP")

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should return default XP (10) when enemy has missing xpValue field", function()
    -- Run property test with 100 iterations
    for _ = 1, 100 do
      -- Create configuration without xpValue field
      local testConfig = {
        no_xp_enemy = {
          health = math.random(10, 100),
          speed = math.random(50, 150),
          damage = math.random(5, 50)
          -- xpValue intentionally missing
        }
      }

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Property: Enemy without xpValue field should return default XP (10)
      local actualXP = experience_system.getEnemyXPValue("no_xp_enemy")
      assert.are.equal(DEFAULT_XP, actualXP,
        "Enemy without xpValue field should return default XP")

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should return default XP (10) when enemy has non-positive xpValue", function()
    -- Run property test with 100 iterations
    for _ = 1, 100 do
      -- Generate random non-positive XP value (0 or negative)
      local nonPositiveXP = math.random(-100, 0)

      local testConfig = {
        non_positive_xp_enemy = {
          health = 30,
          speed = 70,
          xpValue = nonPositiveXP
        }
      }

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Property: Enemy with non-positive xpValue should return default XP (10)
      local actualXP = experience_system.getEnemyXPValue("non_positive_xp_enemy")
      assert.are.equal(DEFAULT_XP, actualXP,
        string.format("Enemy with non-positive xpValue %d should return default XP", nonPositiveXP))

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should consistently return default XP (10) across multiple calls for unconfigured types", function()
    -- Run property test with 100 iterations
    for _ = 1, 100 do
      -- Generate random unconfigured enemy type
      local unconfiguredType = "unconfigured_" .. math.random(1, 10000)

      -- Ensure type is not configured
      local originalConfig = experience_system.enemyConfig
      local testConfig = {}
      for k, v in pairs(originalConfig) do
        if k ~= unconfiguredType and k ~= "_schema" then
          testConfig[k] = v
        end
      end
      experience_system.enemyConfig = testConfig

      -- Property: Multiple calls should consistently return default XP (10)
      local call1 = experience_system.getEnemyXPValue(unconfiguredType)
      local call2 = experience_system.getEnemyXPValue(unconfiguredType)
      local call3 = experience_system.getEnemyXPValue(unconfiguredType)

      assert.are.equal(DEFAULT_XP, call1, "First call should return default XP")
      assert.are.equal(DEFAULT_XP, call2, "Second call should return default XP")
      assert.are.equal(DEFAULT_XP, call3, "Third call should return default XP")
      assert.are.equal(call1, call2, "All calls should return the same value")
      assert.are.equal(call2, call3, "All calls should return the same value")

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)
end)
