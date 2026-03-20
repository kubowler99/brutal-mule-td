require("tests.spec_helper")
local experience_system = require("src.systems.experience_system")
local Hero = require("src.entities.hero")

describe("Level System", function()
    local hero
    local levelUpCallback
    local levelUpCalled

    before_each(function()
        -- Create hero
        hero = Hero:new(360, 1180)
        
        -- Create level-up callback
        levelUpCalled = false
        levelUpCallback = function(level)
            levelUpCalled = true
        end
        
        -- Initialize level system
        experience_system.initialize(hero, levelUpCallback)
    end)

    after_each(function()
        experience_system.cleanup()
        hero = nil
        levelUpCallback = nil
    end)

    describe("getEnemyXPValue", function()
        it("should return configured XP value for walker enemy type", function()
            local xpValue = experience_system.getEnemyXPValue("walker")
            assert.are.equal(10, xpValue)
        end)

        it("should return default XP (10) for unconfigured enemy type", function()
            local xpValue = experience_system.getEnemyXPValue("unknown_enemy")
            assert.are.equal(10, xpValue)
        end)

        it("should return default XP (10) for nil enemy type", function()
            local xpValue = experience_system.getEnemyXPValue(nil)
            assert.are.equal(10, xpValue)
        end)

        it("should return default XP (10) for empty string enemy type", function()
            local xpValue = experience_system.getEnemyXPValue("")
            assert.are.equal(10, xpValue)
        end)

        it("should return default XP (10) for non-string enemy type", function()
            local xpValue = experience_system.getEnemyXPValue(123)
            assert.are.equal(10, xpValue)
        end)

        it("should return default XP when configuration is not loaded", function()
            -- Temporarily clear configuration
            local originalConfig = experience_system.enemyConfig
            experience_system.enemyConfig = nil

            local xpValue = experience_system.getEnemyXPValue("walker")
            assert.are.equal(10, xpValue)

            -- Restore configuration
            experience_system.enemyConfig = originalConfig
        end)

        it("should return default XP when enemy has invalid xpValue field", function()
            -- Temporarily modify configuration
            local originalConfig = experience_system.enemyConfig
            experience_system.enemyConfig = {
                invalid_enemy = {
                    health = 20,
                    speed = 80,
                    xpValue = "not_a_number"
                }
            }

            local xpValue = experience_system.getEnemyXPValue("invalid_enemy")
            assert.are.equal(10, xpValue)

            -- Restore configuration
            experience_system.enemyConfig = originalConfig
        end)

        it("should return default XP when enemy has missing xpValue field", function()
            -- Temporarily modify configuration
            local originalConfig = experience_system.enemyConfig
            experience_system.enemyConfig = {
                no_xp_enemy = {
                    health = 20,
                    speed = 80
                }
            }

            local xpValue = experience_system.getEnemyXPValue("no_xp_enemy")
            assert.are.equal(10, xpValue)

            -- Restore configuration
            experience_system.enemyConfig = originalConfig
        end)

        it("should return default XP when enemy has non-positive xpValue", function()
            -- Temporarily modify configuration
            local originalConfig = experience_system.enemyConfig
            experience_system.enemyConfig = {
                zero_xp_enemy = {
                    health = 20,
                    speed = 80,
                    xpValue = 0
                },
                negative_xp_enemy = {
                    health = 20,
                    speed = 80,
                    xpValue = -10
                }
            }

            local xpValue1 = experience_system.getEnemyXPValue("zero_xp_enemy")
            assert.are.equal(10, xpValue1)

            local xpValue2 = experience_system.getEnemyXPValue("negative_xp_enemy")
            assert.are.equal(10, xpValue2)

            -- Restore configuration
            experience_system.enemyConfig = originalConfig
        end)

        it("should return correct XP for multiple different enemy types", function()
            -- Temporarily add more enemy types to configuration
            local originalConfig = experience_system.enemyConfig
            experience_system.enemyConfig = {
                walker = { xpValue = 10 },
                runner = { xpValue = 15 },
                boss = { xpValue = 100 }
            }

            assert.are.equal(10, experience_system.getEnemyXPValue("walker"))
            assert.are.equal(15, experience_system.getEnemyXPValue("runner"))
            assert.are.equal(100, experience_system.getEnemyXPValue("boss"))

            -- Restore configuration
            experience_system.enemyConfig = originalConfig
        end)
    end)

    describe("initialization", function()
        it("should initialize with hero reference", function()
            assert.are.equal(hero, experience_system.hero)
        end)

        it("should initialize with level-up callback", function()
            assert.are.equal(levelUpCallback, experience_system.onLevelUp)
        end)

        it("should load enemy configuration from data/enemies.json", function()
            assert.is_not_nil(experience_system.enemyConfig)
        end)

        it("should load walker configuration with xpValue", function()
            assert.is_not_nil(experience_system.enemyConfig.walker)
            assert.are.equal(10, experience_system.enemyConfig.walker.xpValue)
        end)

        it("should handle missing configuration file gracefully", function()
            -- Cleanup and reinitialize with mocked missing file
            experience_system.cleanup()
            
            -- Mock system.pathForFile to return nil
            local originalPathForFile = _G.system.pathForFile
            _G.system.pathForFile = function() return nil end
            
            -- Should not crash, should use empty config
            experience_system.initialize(hero, levelUpCallback)
            
            assert.is_not_nil(experience_system.enemyConfig)
            assert.are.equal("table", type(experience_system.enemyConfig))
            
            -- Restore mock
            _G.system.pathForFile = originalPathForFile
            
            -- Reinitialize for other tests
            experience_system.initialize(hero, levelUpCallback)
        end)

        it("should handle malformed JSON gracefully", function()
            -- Cleanup and reinitialize with mocked malformed JSON
            experience_system.cleanup()
            
            -- Mock io.open to return file with invalid JSON
            local originalOpen = _G.io.open
            _G.io.open = function()
                return {
                    read = function() return "{invalid json" end,
                    close = function() end
                }
            end
            
            -- Should not crash, should use empty config
            experience_system.initialize(hero, levelUpCallback)
            
            assert.is_not_nil(experience_system.enemyConfig)
            assert.are.equal("table", type(experience_system.enemyConfig))
            
            -- Restore mock
            _G.io.open = originalOpen
            
            -- Reinitialize for other tests
            experience_system.initialize(hero, levelUpCallback)
        end)

        it("should handle empty configuration file gracefully", function()
            -- Cleanup and reinitialize with mocked empty file
            experience_system.cleanup()
            
            -- Mock io.open to return empty file
            local originalOpen = _G.io.open
            _G.io.open = function()
                return {
                    read = function() return "" end,
                    close = function() end
                }
            end
            
            -- Should not crash, should use empty config
            experience_system.initialize(hero, levelUpCallback)
            
            assert.is_not_nil(experience_system.enemyConfig)
            assert.are.equal("table", type(experience_system.enemyConfig))
            
            -- Restore mock
            _G.io.open = originalOpen
            
            -- Reinitialize for other tests
            experience_system.initialize(hero, levelUpCallback)
        end)
    end)

    -- **Validates: Requirements 5.4**
    -- Test XP requirement calculation
    describe("XP requirement calculation", function()
        it("should calculate 100 XP for level 1", function()
            local required = experience_system.calculateXPRequired(1)
            assert.are.equal(100, required)
        end)

        it("should calculate 120 XP for level 2", function()
            local required = experience_system.calculateXPRequired(2)
            assert.are.equal(120, required)
        end)

        it("should calculate 140 XP for level 3", function()
            local required = experience_system.calculateXPRequired(3)
            assert.are.equal(140, required)
        end)

        it("should calculate 200 XP for level 6", function()
            local required = experience_system.calculateXPRequired(6)
            assert.are.equal(200, required)
        end)

        it("should calculate 480 XP for level 20", function()
            local required = experience_system.calculateXPRequired(20)
            assert.are.equal(480, required)
        end)

        it("should follow formula: 100 + (level - 1) * 20", function()
            for level = 1, 20 do
                local expected = 100 + (level - 1) * 20
                local actual = experience_system.calculateXPRequired(level)
                assert.are.equal(expected, actual)
            end
        end)
    end)

    -- **Validates: Requirements 5.5, 5.6**
    -- Test level-up trigger and callback
    describe("level-up trigger and callback", function()
        it("should trigger level-up when XP reaches requirement", function()
            experience_system.addXP(100)
            
            assert.are.equal(2, hero.level)
        end)

        it("should call level-up callback when leveling up", function()
            experience_system.addXP(100)
            
            assert.is_true(levelUpCalled)
        end)

        it("should update XP requirement after level-up", function()
            experience_system.addXP(100)
            
            assert.are.equal(120, hero.xpRequired)
        end)

        it("should carry over excess XP to next level", function()
            experience_system.addXP(110)  -- 10 XP over requirement
            
            assert.are.equal(2, hero.level)
            assert.are.equal(10, hero.xp)
        end)

        it("should handle multiple level-ups from single XP gain", function()
            experience_system.addXP(250)  -- Enough for level 2 (100) and level 3 (120)
            
            assert.are.equal(3, hero.level)
            assert.are.equal(30, hero.xp)  -- 250 - 100 - 120 = 30
        end)

        it("should not level up when XP is below requirement", function()
            experience_system.addXP(50)
            
            assert.are.equal(1, hero.level)
            assert.are.equal(50, hero.xp)
        end)

        it("should handle level-up at exact XP requirement", function()
            experience_system.addXP(100)
            
            assert.are.equal(2, hero.level)
            assert.are.equal(0, hero.xp)
        end)
    end)

    describe("cleanup", function()
        it("should clear hero reference", function()
            experience_system.cleanup()
            
            assert.is_nil(experience_system.hero)
        end)

        it("should clear level-up callback", function()
            experience_system.cleanup()
            
            assert.is_nil(experience_system.onLevelUp)
        end)
    end)
end)

-- **Validates: Requirements 5.4**
-- Property 18: XP Requirement Formula
describe("Property 18: XP Requirement Formula", function()
    local generators = require("tests.generators.game_generators")

    it("should calculate XP requirement as 100 + (level - 1) * 20 for any level", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Generate random level (1-20)
            local level = generators.heroLevel()()
            
            -- Calculate expected XP requirement using formula
            local expected = 100 + (level - 1) * 20
            
            -- Get actual XP requirement from level system
            local actual = experience_system.calculateXPRequired(level)
            
            -- Property: XP requirement should match formula for any level
            assert.are.equal(expected, actual, 
                string.format("XP requirement for level %d should be %d", level, expected))
        end
    end)

    it("should have increasing XP requirements for consecutive levels", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Generate random starting level (1-19)
            local level = math.random(1, 19)
            
            -- Calculate XP requirements for this level and next
            local currentRequired = experience_system.calculateXPRequired(level)
            local nextRequired = experience_system.calculateXPRequired(level + 1)
            
            -- Property: Next level should require exactly 20 more XP
            assert.are.equal(currentRequired + 20, nextRequired,
                string.format("Level %d should require 20 more XP than level %d", level + 1, level))
        end
    end)

    it("should calculate correct XP requirements for edge case levels", function()
        -- Test level 1 (minimum)
        assert.are.equal(100, experience_system.calculateXPRequired(1))
        
        -- Test level 2 (first increment)
        assert.are.equal(120, experience_system.calculateXPRequired(2))
        
        -- Test level 20 (typical max in design)
        assert.are.equal(480, experience_system.calculateXPRequired(20))
        
        -- Test very high level (100)
        assert.are.equal(2080, experience_system.calculateXPRequired(100))
    end)

    it("should maintain formula consistency across multiple calculations", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Generate random level
            local level = generators.heroLevel()()
            
            -- Calculate XP requirement multiple times
            local result1 = experience_system.calculateXPRequired(level)
            local result2 = experience_system.calculateXPRequired(level)
            local result3 = experience_system.calculateXPRequired(level)
            
            -- Property: Same level should always return same XP requirement (pure function)
            assert.are.equal(result1, result2, "Formula should be deterministic")
            assert.are.equal(result2, result3, "Formula should be deterministic")
        end
    end)
end)

-- **Validates: Requirements 5.5, 5.6**
-- Property 19: Level-Up Trigger
describe("Property 19: Level-Up Trigger", function()
    local generators = require("tests.generators.game_generators")

    it("should trigger level-up when accumulated XP reaches or exceeds requirement", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero and level system
            local testHero = Hero:new(360, 1180)
            
            local levelUpTriggered = false
            local levelUpCallback = function(newLevel)
                levelUpTriggered = true
            end
            
            experience_system.initialize(testHero, levelUpCallback)
            
            -- Generate random XP amount (0-300)
            local xpAmount = math.random(0, 300)
            
            -- Calculate expected level after adding XP
            local expectedLevel = testHero.level
            local remainingXP = testHero.xp + xpAmount
            
            while remainingXP >= experience_system.calculateXPRequired(expectedLevel) do
                remainingXP = remainingXP - experience_system.calculateXPRequired(expectedLevel)
                expectedLevel = expectedLevel + 1
            end
            
            -- Add XP
            experience_system.addXP(xpAmount)
            
            -- Property: Hero level should match expected level
            assert.are.equal(expectedLevel, testHero.level,
                string.format("Adding %d XP should result in level %d", xpAmount, expectedLevel))
            
            -- Property: Remaining XP should be correct
            assert.are.equal(remainingXP, testHero.xp,
                string.format("Remaining XP should be %d", remainingXP))
            
            -- Property: Callback should be triggered if level increased
            if expectedLevel > 1 then
                assert.is_true(levelUpTriggered, "Level-up callback should be triggered")
            end
            
            -- Cleanup
            experience_system.cleanup()
        end
    end)

    it("should update XP requirement after each level-up", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero and level system
            local testHero = Hero:new(360, 1180)
            experience_system.initialize(testHero, function() end)
            
            -- Generate random XP amount that will cause at least one level-up
            local xpAmount = math.random(100, 500)
            
            -- Add XP
            experience_system.addXP(xpAmount)
            
            -- Property: XP requirement should match formula for current level
            local expectedRequirement = experience_system.calculateXPRequired(testHero.level)
            assert.are.equal(expectedRequirement, testHero.xpRequired,
                string.format("XP requirement should be %d for level %d", expectedRequirement, testHero.level))
            
            -- Cleanup
            experience_system.cleanup()
        end
    end)

    it("should handle multiple level-ups from single XP gain", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero and level system
            local testHero = Hero:new(360, 1180)
            
            local levelUpCount = 0
            local levelUpCallback = function(newLevel)
                levelUpCount = levelUpCount + 1
            end
            
            experience_system.initialize(testHero, levelUpCallback)
            
            -- Add enough XP for multiple level-ups (500-1000 XP)
            local xpAmount = math.random(500, 1000)
            local initialLevel = testHero.level
            
            experience_system.addXP(xpAmount)
            
            -- Property: Level-up callback should be called once per level gained
            local levelsGained = testHero.level - initialLevel
            assert.are.equal(levelsGained, levelUpCount,
                string.format("Callback should be called %d times for %d levels gained", levelsGained, levelsGained))
            
            -- Property: Hero should be at a valid level
            assert.is_true(testHero.level > initialLevel, "Level should increase")
            
            -- Property: Remaining XP should be less than next requirement
            assert.is_true(testHero.xp < testHero.xpRequired,
                "Remaining XP should be less than requirement for next level")
            
            -- Cleanup
            experience_system.cleanup()
        end
    end)

    it("should not trigger level-up when XP is below requirement", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero and level system
            local testHero = Hero:new(360, 1180)
            
            local levelUpTriggered = false
            local levelUpCallback = function(newLevel)
                levelUpTriggered = true
            end
            
            experience_system.initialize(testHero, levelUpCallback)
            
            -- Add XP less than requirement (1-99)
            local xpAmount = math.random(1, 99)
            local initialLevel = testHero.level
            
            experience_system.addXP(xpAmount)
            
            -- Property: Level should not change
            assert.are.equal(initialLevel, testHero.level, "Level should not change")
            
            -- Property: XP should accumulate
            assert.are.equal(xpAmount, testHero.xp, "XP should accumulate")
            
            -- Property: Callback should not be triggered
            assert.is_false(levelUpTriggered, "Level-up callback should not be triggered")
            
            -- Cleanup
            experience_system.cleanup()
        end
    end)

    it("should handle exact XP requirement amounts", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero and level system
            local testHero = Hero:new(360, 1180)
            
            local levelUpTriggered = false
            local levelUpCallback = function(newLevel)
                levelUpTriggered = true
            end
            
            experience_system.initialize(testHero, levelUpCallback)
            
            -- Add exactly the XP requirement
            local xpAmount = testHero.xpRequired
            
            experience_system.addXP(xpAmount)
            
            -- Property: Should level up to exactly level 2
            assert.are.equal(2, testHero.level, "Should level up to level 2")
            
            -- Property: Remaining XP should be exactly 0
            assert.are.equal(0, testHero.xp, "Remaining XP should be 0")
            
            -- Property: Callback should be triggered
            assert.is_true(levelUpTriggered, "Level-up callback should be triggered")
            
            -- Cleanup
            experience_system.cleanup()
        end
    end)
end)

-- Error Handling Tests
describe("Error Handling", function()
    local hero
    local levelUpCallback

    before_each(function()
        hero = Hero:new(360, 1180)
        levelUpCallback = function(level) end
        experience_system.initialize(hero, levelUpCallback)
    end)

    after_each(function()
        experience_system.cleanup()
    end)

    describe("addXP validation", function()
        it("should reject negative XP amounts", function()
            local initialXP = hero.xp
            experience_system.addXP(-10)
            
            assert.are.equal(initialXP, hero.xp, "XP should not change with negative amount")
        end)

        it("should reject zero XP amounts", function()
            local initialXP = hero.xp
            experience_system.addXP(0)
            
            assert.are.equal(initialXP, hero.xp, "XP should not change with zero amount")
        end)

        it("should reject non-number XP amounts", function()
            local initialXP = hero.xp
            experience_system.addXP("100")
            
            assert.are.equal(initialXP, hero.xp, "XP should not change with string amount")
        end)

        it("should reject nil XP amounts", function()
            local initialXP = hero.xp
            experience_system.addXP(nil)
            
            assert.are.equal(initialXP, hero.xp, "XP should not change with nil amount")
        end)

        it("should clamp XP to maximum of 999999", function()
            experience_system.addXP(1000000)
            
            -- Should add 999999 instead of 1000000
            -- Hero starts at level 1 with 0 XP, requirement is 100
            -- After adding 999999, hero should level up many times
            assert.is_true(hero.xp < 999999, "XP should be clamped to 999999")
        end)

        it("should accept valid positive XP amounts", function()
            local initialXP = hero.xp
            experience_system.addXP(50)
            
            assert.are.equal(initialXP + 50, hero.xp, "Valid XP should be added")
        end)
    end)

    describe("calculateXPRequired validation", function()
        it("should handle invalid level parameter", function()
            local result = experience_system.calculateXPRequired("invalid")
            
            assert.are.equal(100, result, "Should return base XP for invalid level")
        end)

        it("should handle negative level", function()
            local result = experience_system.calculateXPRequired(-5)
            
            assert.are.equal(100, result, "Should return base XP for negative level")
        end)

        it("should handle zero level", function()
            local result = experience_system.calculateXPRequired(0)
            
            assert.are.equal(100, result, "Should return base XP for zero level")
        end)

        it("should handle nil level", function()
            local result = experience_system.calculateXPRequired(nil)
            
            assert.are.equal(100, result, "Should return base XP for nil level")
        end)

        it("should handle valid level 1", function()
            local result = experience_system.calculateXPRequired(1)
            
            assert.are.equal(100, result, "Should return correct XP for level 1")
        end)
    end)
end)

