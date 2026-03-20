-- Unit tests for experience_system.awardXP() function
require("tests.spec_helper")

local experience_system = require("src.systems.experience_system")
local Hero = require("src.entities.hero")

describe("experience_system.awardXP()", function()
  local hero

  before_each(function()
    -- Create a hero instance
    hero = Hero:new(360, 640)
    hero.level = 1
    hero.xp = 0
    hero.xpRequired = 100

    -- Initialize experience system with test configuration
    experience_system.initialize(hero, function() end)

    -- Set up test enemy configuration
    experience_system.enemyConfig = {
      walker = { xpValue = 10 },
      strong_enemy = { xpValue = 25 },
      boss = { xpValue = 100 }
    }
  end)

  after_each(function()
    experience_system.cleanup()
    hero = nil
  end)

  describe("basic functionality", function()
    it("should award XP for a configured enemy type", function()
      local initialXP = hero.xp

      experience_system.awardXP("walker", 100, 200)

      assert.are.equal(initialXP + 10, hero.xp, "Hero should gain 10 XP from walker")
    end)

    it("should award correct XP for different enemy types", function()
      -- Test walker
      experience_system.awardXP("walker", 100, 200)
      assert.are.equal(10, hero.xp, "Walker should award 10 XP")
      assert.are.equal(1, hero.level, "Should still be level 1")

      -- Test strong_enemy
      experience_system.awardXP("strong_enemy", 100, 200)
      assert.are.equal(35, hero.xp, "Strong enemy should award 25 XP (total 35)")
      assert.are.equal(1, hero.level, "Should still be level 1")

      -- Test boss (this will cause level-up: 35 + 100 = 135, which is >= 100)
      -- After level-up: 135 - 100 = 35 XP remaining at level 2
      experience_system.awardXP("boss", 100, 200)
      
      assert.are.equal(35, hero.xp, "Boss should award 100 XP, causing level-up with 35 XP remaining")
      assert.are.equal(2, hero.level, "Should be level 2 after gaining 135 total XP")
    end)

    it("should award default XP for unconfigured enemy type", function()
      experience_system.awardXP("unknown_enemy", 100, 200)

      assert.are.equal(10, hero.xp, "Unknown enemy should award default 10 XP")
    end)
  end)

  describe("error handling", function()
    it("should handle nil hero reference gracefully", function()
      experience_system.hero = nil

      -- Should not crash
      assert.has_no.errors(function()
        experience_system.awardXP("walker", 100, 200)
      end)
    end)

    it("should handle invalid enemy type by using default", function()
      experience_system.awardXP("", 100, 200)
      assert.are.equal(10, hero.xp, "Empty string should use default XP")

      hero.xp = 0
      experience_system.awardXP(nil, 100, 200)
      assert.are.equal(10, hero.xp, "Nil enemy type should use default XP")
    end)

    it("should handle invalid position coordinates", function()
      -- Should not crash with invalid coordinates
      assert.has_no.errors(function()
        experience_system.awardXP("walker", nil, nil)
      end)

      -- XP should still be awarded
      assert.are.equal(10, hero.xp, "XP should be awarded despite invalid coordinates")
    end)

    it("should handle invalid position by using hero position as fallback", function()
      -- This should not crash and should use hero position for feedback
      assert.has_no.errors(function()
        experience_system.awardXP("walker", "invalid", "invalid")
      end)

      assert.are.equal(10, hero.xp, "XP should be awarded with fallback position")
    end)
  end)

  describe("integration with addXP", function()
    it("should trigger level-up when XP threshold is reached", function()
      local levelUpCalled = false
      local levelUpLevel = nil

      -- Reinitialize with level-up callback
      experience_system.initialize(hero, function(level)
        levelUpCalled = true
        levelUpLevel = level
      end)

      -- Set up test configuration
      experience_system.enemyConfig = {
        boss = { xpValue = 100 }
      }

      -- Hero needs 100 XP to level up
      hero.xp = 0
      hero.xpRequired = 100

      -- Award 100 XP (should trigger level-up)
      experience_system.awardXP("boss", 100, 200)

      assert.is_true(levelUpCalled, "Level-up callback should be called")
      assert.are.equal(2, levelUpLevel, "Hero should be level 2")
      assert.are.equal(2, hero.level, "Hero level should be 2")
    end)

    it("should accumulate XP from multiple enemy defeats", function()
      experience_system.awardXP("walker", 100, 200)
      experience_system.awardXP("walker", 150, 250)
      experience_system.awardXP("walker", 200, 300)

      assert.are.equal(30, hero.xp, "Hero should have 30 XP from 3 walkers")
    end)
  end)

  describe("XP value lookup", function()
    it("should use getEnemyXPValue to determine XP amount", function()
      -- This test verifies that awardXP correctly uses getEnemyXPValue
      local testConfig = {
        custom_enemy = { xpValue = 42 }
      }
      experience_system.enemyConfig = testConfig

      experience_system.awardXP("custom_enemy", 100, 200)

      assert.are.equal(42, hero.xp, "Should award custom XP value from configuration")
    end)
  end)
end)
