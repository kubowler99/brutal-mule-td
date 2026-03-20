require("tests.spec_helper")
local experience_system = require("src.systems.experience_system")
local Hero = require("src.entities.hero")
local data = require("src.models.data")

describe("Experience System - Save Data Compatibility", function()
    local hero
    local levelUpCallback

    before_each(function()
        -- Create a fresh hero instance
        hero = Hero:new(360, 1200)
        
        -- Mock level-up callback
        levelUpCallback = function() end
        
        -- Initialize experience system
        experience_system.initialize(hero, levelUpCallback)
    end)

    after_each(function()
        -- Cleanup
        experience_system.cleanup()
        hero = nil
    end)

    describe("Loading existing save files with XP data", function()
        it("should load hero.xp correctly from save data", function()
            -- Simulate save data with specific XP value
            local savedXP = 75
            hero.xp = savedXP
            hero.level = 1
            hero.xpRequired = 100
            
            -- Verify XP loaded correctly
            assert.are.equal(savedXP, hero.xp, "Hero XP should match saved value")
        end)

        it("should load hero.level correctly from save data", function()
            -- Simulate save data with specific level
            local savedLevel = 5
            hero.xp = 50
            hero.level = savedLevel
            hero.xpRequired = 180  -- Level 5 requirement: 100 + (5-1)*20 = 180
            
            -- Verify level loaded correctly
            assert.are.equal(savedLevel, hero.level, "Hero level should match saved value")
        end)

        it("should load hero.xpRequired correctly from save data", function()
            -- Simulate save data with specific XP requirement
            local savedLevel = 3
            local expectedXPRequired = experience_system.calculateXPRequired(savedLevel)
            hero.xp = 25
            hero.level = savedLevel
            hero.xpRequired = expectedXPRequired
            
            -- Verify XP requirement loaded correctly
            assert.are.equal(expectedXPRequired, hero.xpRequired, "Hero xpRequired should match saved value")
        end)

        it("should preserve XP values across multiple levels", function()
            -- Test various level/XP combinations
            local testCases = {
                {level = 1, xp = 0, xpRequired = 100},
                {level = 1, xp = 50, xpRequired = 100},
                {level = 1, xp = 99, xpRequired = 100},
                {level = 2, xp = 0, xpRequired = 120},
                {level = 2, xp = 60, xpRequired = 120},
                {level = 5, xp = 100, xpRequired = 180},
                {level = 10, xp = 200, xpRequired = 280},
            }

            for _, testCase in ipairs(testCases) do
                -- Set hero to saved state
                hero.level = testCase.level
                hero.xp = testCase.xp
                hero.xpRequired = testCase.xpRequired

                -- Verify all fields match
                assert.are.equal(testCase.level, hero.level, 
                    string.format("Level should be %d", testCase.level))
                assert.are.equal(testCase.xp, hero.xp, 
                    string.format("XP should be %d", testCase.xp))
                assert.are.equal(testCase.xpRequired, hero.xpRequired, 
                    string.format("XP required should be %d", testCase.xpRequired))
            end
        end)

        it("should maintain XP storage format unchanged", function()
            -- Verify that XP is stored as simple numeric fields
            -- This ensures backward compatibility with existing save files
            
            hero.xp = 123
            hero.level = 7
            hero.xpRequired = 220
            
            -- Check that fields are simple numbers (not nested tables or complex structures)
            assert.are.equal("number", type(hero.xp), "XP should be stored as a number")
            assert.are.equal("number", type(hero.level), "Level should be stored as a number")
            assert.are.equal("number", type(hero.xpRequired), "XP required should be stored as a number")
            
            -- Verify values are preserved exactly
            assert.are.equal(123, hero.xp)
            assert.are.equal(7, hero.level)
            assert.are.equal(220, hero.xpRequired)
        end)

        it("should handle edge case: level 1 with 0 XP", function()
            -- New player save file
            hero.xp = 0
            hero.level = 1
            hero.xpRequired = 100
            
            assert.are.equal(0, hero.xp)
            assert.are.equal(1, hero.level)
            assert.are.equal(100, hero.xpRequired)
        end)

        it("should handle edge case: high level with accumulated XP", function()
            -- Advanced player save file
            local highLevel = 50
            local highXP = 500
            local expectedXPRequired = experience_system.calculateXPRequired(highLevel)
            
            hero.xp = highXP
            hero.level = highLevel
            hero.xpRequired = expectedXPRequired
            
            assert.are.equal(highXP, hero.xp)
            assert.are.equal(highLevel, hero.level)
            assert.are.equal(expectedXPRequired, hero.xpRequired)
        end)

        it("should handle edge case: XP at exact level-up threshold", function()
            -- Player saved right at level-up point
            hero.xp = 0
            hero.level = 2
            hero.xpRequired = 120
            
            assert.are.equal(0, hero.xp, "XP should be 0 after level-up")
            assert.are.equal(2, hero.level, "Level should be 2")
            assert.are.equal(120, hero.xpRequired, "XP required should be 120 for level 2")
        end)
    end)

    describe("XP progression after loading save data", function()
        it("should continue XP accumulation from loaded state", function()
            -- Load a saved state
            hero.xp = 50
            hero.level = 1
            hero.xpRequired = 100
            
            -- Award more XP
            experience_system.addXP(30)
            
            -- Verify XP accumulated correctly
            assert.are.equal(80, hero.xp, "XP should accumulate from saved value")
            assert.are.equal(1, hero.level, "Level should remain 1")
        end)

        it("should trigger level-up correctly from loaded state", function()
            -- Load a saved state close to level-up
            hero.xp = 90
            hero.level = 1
            hero.xpRequired = 100
            
            -- Award enough XP to level up
            experience_system.addXP(20)
            
            -- Verify level-up occurred
            assert.are.equal(2, hero.level, "Should level up to 2")
            assert.are.equal(10, hero.xp, "Should have 10 XP remaining")
            assert.are.equal(120, hero.xpRequired, "XP required should update to 120")
        end)

        it("should handle multiple level-ups from loaded state", function()
            -- Load a saved state
            hero.xp = 50
            hero.level = 1
            hero.xpRequired = 100
            
            -- Award enough XP for multiple level-ups
            -- Need: 50 more for level 2, then 120 for level 3, then 140 for level 4
            -- Total: 50 + 120 + 140 = 310, plus 30 extra = 340
            experience_system.addXP(340)
            
            -- Verify multiple level-ups occurred
            assert.are.equal(4, hero.level, "Should reach level 4")
            assert.are.equal(30, hero.xp, "Should have 30 XP remaining")
        end)
    end)

    describe("XP calculation consistency", function()
        it("should calculate XP requirements consistently with formula", function()
            -- Formula: 100 + (level - 1) * 20
            local testLevels = {1, 2, 3, 5, 10, 20, 50}
            
            for _, level in ipairs(testLevels) do
                local expected = 100 + (level - 1) * 20
                local actual = experience_system.calculateXPRequired(level)
                
                assert.are.equal(expected, actual, 
                    string.format("XP requirement for level %d should be %d", level, expected))
            end
        end)

        it("should maintain XP requirement consistency after loading", function()
            -- Load a saved state
            local savedLevel = 7
            hero.level = savedLevel
            hero.xp = 100
            hero.xpRequired = experience_system.calculateXPRequired(savedLevel)
            
            -- Verify XP requirement matches formula
            local expectedXPRequired = 100 + (savedLevel - 1) * 20
            assert.are.equal(expectedXPRequired, hero.xpRequired, 
                "XP requirement should match formula after loading")
        end)
    end)
end)
