--- Property-based tests for Experience System awardXP function
-- Feature: automatic-xp-on-defeat
-- Tests Property 1: XP Award Equals Enemy Value

require("tests.spec_helper")

local experience_system = require("src.systems.experience_system")
local Hero = require("src.entities.hero")

-- **Validates: Requirements 1.1, 1.3, 1.5, 3.1, 3.2**
-- Property 1: XP Award Equals Enemy Value
describe("Property 1: XP Award Equals Enemy Value", function()
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

  it("should award XP equal to configured enemy value for any enemy type", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random enemy type and XP value
      local enemyTypes = {"walker", "runner", "boss", "elite", "minion", "tank", "flyer"}
      local enemyType = enemyTypes[math.random(1, #enemyTypes)]
      local configuredXP = math.random(1, 200)

      -- Create test configuration
      local testConfig = {}
      testConfig[enemyType] = {
        health = math.random(10, 100),
        speed = math.random(50, 150),
        damage = math.random(5, 50),
        xpValue = configuredXP
      }

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Reset hero XP to random initial value
      local initialXP = math.random(0, 500)
      hero.xp = initialXP
      hero.level = 1
      hero.xpRequired = 1000  -- Set high to avoid level-ups during test

      -- Generate random position for enemy defeat
      local enemyX = math.random(0, 720)
      local enemyY = math.random(0, 1280)

      -- Award XP for defeating the enemy
      experience_system.awardXP(enemyType, enemyX, enemyY)

      -- Property: Hero XP should increase by exactly the configured XP value
      local expectedXP = initialXP + configuredXP
      assert.are.equal(expectedXP, hero.xp,
        string.format("Iteration %d: Defeating %s (XP=%d) should increase hero XP from %d to %d, got %d",
          iteration, enemyType, configuredXP, initialXP, expectedXP, hero.xp))

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should award correct XP for multiple consecutive enemy defeats", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random number of enemies to defeat (1-10)
      local numEnemies = math.random(1, 10)

      -- Create test configuration with multiple enemy types
      local enemyTypes = {"type_a", "type_b", "type_c", "type_d"}
      local testConfig = {}
      local xpValues = {}

      for _, enemyType in ipairs(enemyTypes) do
        local xpValue = math.random(5, 50)
        testConfig[enemyType] = {
          health = 20,
          speed = 80,
          xpValue = xpValue
        }
        xpValues[enemyType] = xpValue
      end

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Reset hero XP
      local initialXP = math.random(0, 100)
      hero.xp = initialXP
      hero.level = 1
      hero.xpRequired = 10000  -- Set very high to avoid level-ups

      -- Defeat multiple enemies and track expected XP
      local expectedTotalXP = initialXP
      for i = 1, numEnemies do
        local enemyType = enemyTypes[math.random(1, #enemyTypes)]
        local enemyX = math.random(0, 720)
        local enemyY = math.random(0, 1280)

        experience_system.awardXP(enemyType, enemyX, enemyY)
        expectedTotalXP = expectedTotalXP + xpValues[enemyType]
      end

      -- Property: Total XP should equal initial XP plus sum of all awarded XP
      assert.are.equal(expectedTotalXP, hero.xp,
        string.format("Iteration %d: After defeating %d enemies, hero XP should be %d, got %d",
          iteration, numEnemies, expectedTotalXP, hero.xp))

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should award XP correctly regardless of enemy position", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random enemy type and XP value
      local configuredXP = math.random(10, 100)
      local testConfig = {
        position_test_enemy = {
          health = 30,
          speed = 70,
          xpValue = configuredXP
        }
      }

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Reset hero XP
      local initialXP = math.random(0, 200)
      hero.xp = initialXP
      hero.level = 1
      hero.xpRequired = 5000

      -- Generate random position (including edge cases)
      local positions = {
        {0, 0},                    -- Top-left corner
        {720, 0},                  -- Top-right corner
        {0, 1280},                 -- Bottom-left corner
        {720, 1280},               -- Bottom-right corner
        {360, 640},                -- Center
        {math.random(0, 720), math.random(0, 1280)}  -- Random position
      }
      local pos = positions[math.random(1, #positions)]

      -- Award XP at the position
      experience_system.awardXP("position_test_enemy", pos[1], pos[2])

      -- Property: XP award should be independent of position
      local expectedXP = initialXP + configuredXP
      assert.are.equal(expectedXP, hero.xp,
        string.format("Iteration %d: XP award at position (%d, %d) should be %d, got %d",
          iteration, pos[1], pos[2], configuredXP, hero.xp - initialXP))

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should award XP correctly with varying initial hero XP values", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random XP configuration
      local configuredXP = math.random(1, 150)
      local testConfig = {
        xp_test_enemy = {
          health = 25,
          speed = 75,
          xpValue = configuredXP
        }
      }

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Test with various initial XP values
      local initialXPValues = {
        0,                           -- Zero XP
        math.random(1, 50),         -- Low XP
        math.random(51, 200),       -- Medium XP
        math.random(201, 1000),     -- High XP
        math.random(1001, 5000)     -- Very high XP
      }
      local initialXP = initialXPValues[math.random(1, #initialXPValues)]

      hero.xp = initialXP
      hero.level = math.max(1, math.floor(initialXP / 100))
      hero.xpRequired = 10000  -- Set high to avoid level-ups

      -- Award XP
      experience_system.awardXP("xp_test_enemy", 360, 640)

      -- Property: XP increase should be exactly the configured amount, regardless of initial XP
      local expectedXP = initialXP + configuredXP
      assert.are.equal(expectedXP, hero.xp,
        string.format("Iteration %d: Starting with %d XP, adding %d XP should result in %d XP, got %d",
          iteration, initialXP, configuredXP, expectedXP, hero.xp))

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should award default XP (10) for unconfigured enemy types", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random unconfigured enemy type
      local unconfiguredType = "unconfigured_enemy_" .. math.random(1, 10000)

      -- Ensure configuration doesn't contain this type
      local testConfig = {
        walker = { xpValue = 15 },
        runner = { xpValue = 20 }
      }

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Reset hero XP
      local initialXP = math.random(0, 300)
      hero.xp = initialXP
      hero.level = 1
      hero.xpRequired = 5000

      -- Award XP for unconfigured enemy type
      experience_system.awardXP(unconfiguredType, 360, 640)

      -- Property: Unconfigured enemy types should award default XP (10)
      local DEFAULT_XP = 10
      local expectedXP = initialXP + DEFAULT_XP
      assert.are.equal(expectedXP, hero.xp,
        string.format("Iteration %d: Unconfigured enemy '%s' should award default XP %d, got %d",
          iteration, unconfiguredType, DEFAULT_XP, hero.xp - initialXP))

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should award XP correctly across different hero levels", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random XP configuration
      local configuredXP = math.random(5, 75)
      local testConfig = {
        level_test_enemy = {
          health = 30,
          speed = 80,
          xpValue = configuredXP
        }
      }

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Test with random hero level
      local heroLevel = math.random(1, 20)
      hero.level = heroLevel
      hero.xp = math.random(0, 100)
      hero.xpRequired = 10000  -- Set high to avoid level-ups
      local initialXP = hero.xp

      -- Award XP
      experience_system.awardXP("level_test_enemy", 360, 640)

      -- Property: XP award should be independent of hero level
      local expectedXP = initialXP + configuredXP
      assert.are.equal(expectedXP, hero.xp,
        string.format("Iteration %d: At level %d, XP award should be %d, got %d",
          iteration, heroLevel, configuredXP, hero.xp - initialXP))

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)

  it("should maintain XP award accuracy with extreme XP values", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Test with extreme XP values (very small and very large)
      local extremeXPValues = {
        1,                          -- Minimum positive XP
        math.random(1, 5),         -- Very small XP
        math.random(100, 500),     -- Large XP
        math.random(500, 1000)     -- Very large XP
      }
      local configuredXP = extremeXPValues[math.random(1, #extremeXPValues)]

      local testConfig = {
        extreme_enemy = {
          health = 50,
          speed = 60,
          xpValue = configuredXP
        }
      }

      -- Temporarily replace configuration
      local originalConfig = experience_system.enemyConfig
      experience_system.enemyConfig = testConfig

      -- Reset hero XP
      local initialXP = math.random(0, 500)
      hero.xp = initialXP
      hero.level = 1
      hero.xpRequired = 100000  -- Set very high to avoid level-ups

      -- Award XP
      experience_system.awardXP("extreme_enemy", 360, 640)

      -- Property: XP award should be exact even with extreme values
      local expectedXP = initialXP + configuredXP
      assert.are.equal(expectedXP, hero.xp,
        string.format("Iteration %d: Extreme XP value %d should be awarded exactly, expected %d, got %d",
          iteration, configuredXP, expectedXP, hero.xp))

      -- Restore original configuration
      experience_system.enemyConfig = originalConfig
    end
  end)
end)
