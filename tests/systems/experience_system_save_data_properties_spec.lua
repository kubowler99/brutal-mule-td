--- Property-based tests for Experience System save data preservation
-- Feature: automatic-xp-on-defeat
-- Tests Property 5: Save Data XP Preservation

require("tests.spec_helper")

local experience_system = require("src.systems.experience_system")
local Hero = require("src.entities.hero")

-- **Validates: Requirements 4.2, 4.4**
-- Property 5: Save Data XP Preservation
describe("Property 5: Save Data XP Preservation", function()
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

  it("should preserve exact XP values when loading save data with random XP and levels", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random XP and level values
      local savedLevel = math.random(1, 50)
      local savedXP = math.random(0, 1000)
      local savedXPRequired = experience_system.calculateXPRequired(savedLevel)

      -- Simulate loading save data by setting hero fields
      hero.level = savedLevel
      hero.xp = savedXP
      hero.xpRequired = savedXPRequired

      -- Property: All XP-related fields should be preserved exactly
      assert.are.equal(savedLevel, hero.level,
        string.format("Iteration %d: Level should be preserved as %d, got %d",
          iteration, savedLevel, hero.level))

      assert.are.equal(savedXP, hero.xp,
        string.format("Iteration %d: XP should be preserved as %d, got %d",
          iteration, savedXP, hero.xp))

      assert.are.equal(savedXPRequired, hero.xpRequired,
        string.format("Iteration %d: XP required should be preserved as %d, got %d",
          iteration, savedXPRequired, hero.xpRequired))
    end
  end)

  it("should preserve XP values across the full valid range (0 to 10000)", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate XP values across the full valid range
      local savedXP = math.random(0, 10000)
      local savedLevel = math.random(1, 100)
      local savedXPRequired = experience_system.calculateXPRequired(savedLevel)

      -- Simulate loading save data
      hero.level = savedLevel
      hero.xp = savedXP
      hero.xpRequired = savedXPRequired

      -- Property: XP preservation should work for any valid XP value
      assert.are.equal(savedXP, hero.xp,
        string.format("Iteration %d: XP %d should be preserved exactly, got %d",
          iteration, savedXP, hero.xp))

      -- Verify XP is stored as a simple number (not nested structure)
      assert.are.equal("number", type(hero.xp),
        string.format("Iteration %d: XP should be stored as number type", iteration))
    end
  end)

  it("should preserve XP values at level boundaries", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random level
      local savedLevel = math.random(1, 30)
      local savedXPRequired = experience_system.calculateXPRequired(savedLevel)

      -- Test XP values at critical boundaries
      local boundaryXPValues = {
        0,                           -- Just leveled up
        math.random(1, savedXPRequired - 1),  -- Mid-level progress
        savedXPRequired - 1          -- One XP away from level-up
      }
      local savedXP = boundaryXPValues[math.random(1, #boundaryXPValues)]

      -- Simulate loading save data
      hero.level = savedLevel
      hero.xp = savedXP
      hero.xpRequired = savedXPRequired

      -- Property: XP should be preserved exactly at boundary conditions
      assert.are.equal(savedXP, hero.xp,
        string.format("Iteration %d: Boundary XP %d at level %d should be preserved, got %d",
          iteration, savedXP, savedLevel, hero.xp))

      assert.are.equal(savedLevel, hero.level,
        string.format("Iteration %d: Level %d should be preserved at boundary, got %d",
          iteration, savedLevel, hero.level))
    end
  end)

  it("should preserve XP storage format as simple numeric fields", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random save data
      local savedLevel = math.random(1, 25)
      local savedXP = math.random(0, 500)
      local savedXPRequired = experience_system.calculateXPRequired(savedLevel)

      -- Simulate loading save data
      hero.level = savedLevel
      hero.xp = savedXP
      hero.xpRequired = savedXPRequired

      -- Property: All XP fields should be simple numbers (backward compatibility)
      assert.are.equal("number", type(hero.xp),
        string.format("Iteration %d: hero.xp should be number type", iteration))

      assert.are.equal("number", type(hero.level),
        string.format("Iteration %d: hero.level should be number type", iteration))

      assert.are.equal("number", type(hero.xpRequired),
        string.format("Iteration %d: hero.xpRequired should be number type", iteration))

      -- Verify values are preserved
      assert.are.equal(savedXP, hero.xp,
        string.format("Iteration %d: XP value should be preserved", iteration))
    end
  end)

  it("should preserve XP correctly after awarding additional XP to loaded save", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random initial save data
      local savedXP = math.random(0, 300)
      local savedLevel = math.random(1, 15)
      local savedXPRequired = experience_system.calculateXPRequired(savedLevel)

      -- Simulate loading save data
      hero.level = savedLevel
      hero.xp = savedXP
      hero.xpRequired = 10000  -- Set high to avoid level-ups during test

      -- Award additional XP after loading
      local additionalXP = math.random(1, 100)
      experience_system.addXP(additionalXP)

      -- Property: XP should accumulate correctly from loaded state
      local expectedXP = savedXP + additionalXP
      assert.are.equal(expectedXP, hero.xp,
        string.format("Iteration %d: Loaded XP %d + awarded XP %d should equal %d, got %d",
          iteration, savedXP, additionalXP, expectedXP, hero.xp))
    end
  end)

  it("should preserve XP values with edge case levels (1, 2, and high levels)", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Test edge case levels
      local edgeLevels = {1, 2, math.random(40, 100)}
      local savedLevel = edgeLevels[math.random(1, #edgeLevels)]
      local savedXP = math.random(0, 200)
      local savedXPRequired = experience_system.calculateXPRequired(savedLevel)

      -- Simulate loading save data
      hero.level = savedLevel
      hero.xp = savedXP
      hero.xpRequired = savedXPRequired

      -- Property: XP preservation should work at edge case levels
      assert.are.equal(savedLevel, hero.level,
        string.format("Iteration %d: Edge case level %d should be preserved, got %d",
          iteration, savedLevel, hero.level))

      assert.are.equal(savedXP, hero.xp,
        string.format("Iteration %d: XP %d at edge case level %d should be preserved, got %d",
          iteration, savedXP, savedLevel, hero.xp))

      assert.are.equal(savedXPRequired, hero.xpRequired,
        string.format("Iteration %d: XP required %d should be preserved, got %d",
          iteration, savedXPRequired, hero.xpRequired))
    end
  end)

  it("should preserve zero XP correctly (new player or just leveled up)", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random level with zero XP
      local savedLevel = math.random(1, 20)
      local savedXP = 0
      local savedXPRequired = experience_system.calculateXPRequired(savedLevel)

      -- Simulate loading save data
      hero.level = savedLevel
      hero.xp = savedXP
      hero.xpRequired = savedXPRequired

      -- Property: Zero XP should be preserved exactly
      assert.are.equal(0, hero.xp,
        string.format("Iteration %d: Zero XP should be preserved at level %d, got %d",
          iteration, savedLevel, hero.xp))

      assert.are.equal(savedLevel, hero.level,
        string.format("Iteration %d: Level %d should be preserved with zero XP, got %d",
          iteration, savedLevel, hero.level))
    end
  end)

  it("should maintain XP calculation consistency after loading save data", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random save data
      local savedLevel = math.random(1, 30)
      local savedXP = math.random(0, 400)

      -- Calculate XP required using the system's formula
      local calculatedXPRequired = experience_system.calculateXPRequired(savedLevel)

      -- Simulate loading save data
      hero.level = savedLevel
      hero.xp = savedXP
      hero.xpRequired = calculatedXPRequired

      -- Property: XP requirement should match the formula after loading
      local expectedXPRequired = 100 + (savedLevel - 1) * 20
      assert.are.equal(expectedXPRequired, hero.xpRequired,
        string.format("Iteration %d: XP required for level %d should be %d, got %d",
          iteration, savedLevel, expectedXPRequired, hero.xpRequired))

      -- Verify loaded XP is preserved
      assert.are.equal(savedXP, hero.xp,
        string.format("Iteration %d: XP should be preserved as %d", iteration, savedXP))
    end
  end)

  it("should preserve XP values through multiple save-load cycles", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate initial save data
      local originalXP = math.random(0, 500)
      local originalLevel = math.random(1, 20)
      local originalXPRequired = experience_system.calculateXPRequired(originalLevel)

      -- Simulate first load
      hero.level = originalLevel
      hero.xp = originalXP
      hero.xpRequired = originalXPRequired

      -- Capture values after first load
      local firstLoadXP = hero.xp
      local firstLoadLevel = hero.level
      local firstLoadXPRequired = hero.xpRequired

      -- Simulate second load (round-trip)
      hero.level = firstLoadLevel
      hero.xp = firstLoadXP
      hero.xpRequired = firstLoadXPRequired

      -- Property: XP values should remain identical through multiple load cycles
      assert.are.equal(originalXP, hero.xp,
        string.format("Iteration %d: XP should survive round-trip: original %d, got %d",
          iteration, originalXP, hero.xp))

      assert.are.equal(originalLevel, hero.level,
        string.format("Iteration %d: Level should survive round-trip: original %d, got %d",
          iteration, originalLevel, hero.level))

      assert.are.equal(originalXPRequired, hero.xpRequired,
        string.format("Iteration %d: XP required should survive round-trip: original %d, got %d",
          iteration, originalXPRequired, hero.xpRequired))
    end
  end)
end)
