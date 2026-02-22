require("tests.spec_helper")
local Hero = require("src.entities.hero")

describe("Hero Entity", function()
    local hero

    before_each(function()
        hero = Hero:new()
    end)

    after_each(function()
        if hero and hero.destroy then
            hero:destroy()
        end
        hero = nil
    end)

    describe("initialization", function()
        it("should initialize with default position at bottom center", function()
            assert.is.equal(360, hero.x)
            assert.is.equal(1180, hero.y)
        end)

        it("should initialize with custom position when provided", function()
            local customHero = Hero:new(100, 200)
            assert.is.equal(100, customHero.x)
            assert.is.equal(200, customHero.y)
            customHero:destroy()
        end)

        it("should initialize at level 1", function()
            assert.is.equal(1, hero.level)
        end)

        it("should initialize with 100 health", function()
            assert.is.equal(100, hero.health)
            assert.is.equal(100, hero.maxHealth)
        end)

        it("should initialize with empty abilities array", function()
            assert.is_not_nil(hero.abilities)
            assert.is.equal(0, #hero.abilities)
        end)

        it("should initialize with zero XP", function()
            assert.is.equal(0, hero.xp)
        end)

        it("should initialize with 100 XP required for next level", function()
            assert.is.equal(100, hero.xpRequired)
        end)

        it("should initialize with pickup radius of 40", function()
            assert.is.equal(40, hero.pickupRadius)
        end)

        it("should initialize as alive", function()
            assert.is_true(hero.isAlive)
        end)

        it("should create a display object", function()
            assert.is_not_nil(hero.displayObject)
        end)
    end)

    describe("takeDamage", function()
        it("should reduce health by damage amount", function()
            hero:takeDamage(30)
            assert.is.equal(70, hero.health)
        end)

        it("should reduce health correctly with multiple damage calls", function()
            hero:takeDamage(20)
            hero:takeDamage(15)
            assert.is.equal(65, hero.health)
        end)

        it("should set health to zero when damage exceeds current health", function()
            hero:takeDamage(150)
            assert.is.equal(0, hero.health)
        end)

        it("should set isAlive to false when health reaches zero", function()
            hero:takeDamage(100)
            assert.is.equal(0, hero.health)
            assert.is_false(hero.isAlive)
        end)

        it("should set isAlive to false when health goes below zero", function()
            hero:takeDamage(120)
            assert.is.equal(0, hero.health)
            assert.is_false(hero.isAlive)
        end)

        it("should not reduce health when already dead", function()
            hero:takeDamage(100)
            assert.is_false(hero.isAlive)
            hero:takeDamage(50)
            assert.is.equal(0, hero.health)
        end)

        it("should handle zero damage", function()
            hero:takeDamage(0)
            assert.is.equal(100, hero.health)
            assert.is_true(hero.isAlive)
        end)
    end)

    describe("addAbility", function()
        it("should add ability to empty abilities array", function()
            local ability = { id = "test_ability" }
            local result = hero:addAbility(ability)
            assert.is_true(result)
            assert.is.equal(1, #hero.abilities)
            assert.is.equal(ability, hero.abilities[1])
        end)

        it("should add multiple abilities up to 5", function()
            for i = 1, 5 do
                local ability = { id = "ability_" .. i }
                local result = hero:addAbility(ability)
                assert.is_true(result)
            end
            assert.is.equal(5, #hero.abilities)
        end)

        it("should return false when trying to add 6th ability", function()
            for i = 1, 5 do
                hero:addAbility({ id = "ability_" .. i })
            end
            local result = hero:addAbility({ id = "ability_6" })
            assert.is_false(result)
            assert.is.equal(5, #hero.abilities)
        end)

        it("should maintain ability order", function()
            local ability1 = { id = "first" }
            local ability2 = { id = "second" }
            local ability3 = { id = "third" }
            hero:addAbility(ability1)
            hero:addAbility(ability2)
            hero:addAbility(ability3)
            assert.is.equal("first", hero.abilities[1].id)
            assert.is.equal("second", hero.abilities[2].id)
            assert.is.equal("third", hero.abilities[3].id)
        end)
    end)

    describe("addXP", function()
        it("should increase XP by the given amount", function()
            hero:addXP(50)
            assert.is.equal(50, hero.xp)
        end)

        it("should accumulate XP from multiple calls", function()
            hero:addXP(30)
            hero:addXP(20)
            hero:addXP(10)
            assert.is.equal(60, hero.xp)
        end)

        it("should handle zero XP addition", function()
            hero:addXP(0)
            assert.is.equal(0, hero.xp)
        end)
    end)

    describe("destroy", function()
        it("should remove display object", function()
            local displayObj = hero.displayObject
            hero:destroy()
            assert.is_nil(hero.displayObject)
        end)

        it("should handle multiple destroy calls safely", function()
            hero:destroy()
            hero:destroy()
            assert.is_nil(hero.displayObject)
        end)
    end)

    -- **Validates: Requirements 1.4**
    -- Property 3: Hero Position Immutability
    describe("Property Test: Hero Position Immutability", function()
        it("should maintain fixed position regardless of game operations", function()
            -- Test with default position
            local testHero = Hero:new()
            local initialX = testHero.x
            local initialY = testHero.y
            
            -- Expected default position (bottom center)
            assert.is.equal(360, initialX)
            assert.is.equal(1180, initialY)
            
            -- Run 100 iterations with random game operations
            for i = 1, 100 do
                -- Generate random operations
                local operationType = math.random(1, 4)
                
                if operationType == 1 then
                    -- Take random damage (0-50)
                    local damage = math.random(0, 50)
                    testHero:takeDamage(damage)
                elseif operationType == 2 then
                    -- Add random ability (if slots available)
                    local ability = { id = "test_ability_" .. i }
                    testHero:addAbility(ability)
                elseif operationType == 3 then
                    -- Add random XP (0-100)
                    local xp = math.random(0, 100)
                    testHero:addXP(xp)
                else
                    -- Combination: damage + XP
                    testHero:takeDamage(math.random(1, 20))
                    testHero:addXP(math.random(10, 50))
                end
                
                -- Property: Position must remain unchanged
                assert.is.equal(initialX, testHero.x, 
                    "Hero X position changed after operation " .. i)
                assert.is.equal(initialY, testHero.y, 
                    "Hero Y position changed after operation " .. i)
            end
            
            testHero:destroy()
        end)
        
        it("should maintain custom position regardless of game operations", function()
            -- Test with custom position
            local customX = math.random(100, 600)
            local customY = math.random(500, 1200)
            local testHero = Hero:new(customX, customY)
            
            local initialX = testHero.x
            local initialY = testHero.y
            
            assert.is.equal(customX, initialX)
            assert.is.equal(customY, initialY)
            
            -- Run 50 iterations with various operations
            for i = 1, 50 do
                -- Perform multiple operations in sequence
                testHero:takeDamage(math.random(1, 15))
                testHero:addXP(math.random(5, 30))
                
                if #testHero.abilities < 5 then
                    testHero:addAbility({ id = "ability_" .. i })
                end
                
                -- Property: Position must remain unchanged
                assert.is.equal(initialX, testHero.x,
                    "Hero X position changed at iteration " .. i)
                assert.is.equal(initialY, testHero.y,
                    "Hero Y position changed at iteration " .. i)
            end
            
            testHero:destroy()
        end)
        
        it("should maintain position even when hero dies", function()
            local testHero = Hero:new()
            local initialX = testHero.x
            local initialY = testHero.y
            
            -- Kill the hero with massive damage
            testHero:takeDamage(200)
            
            -- Property: Position must remain unchanged even after death
            assert.is.equal(initialX, testHero.x,
                "Hero X position changed after death")
            assert.is.equal(initialY, testHero.y,
                "Hero Y position changed after death")
            assert.is_false(testHero.isAlive)
            
            -- Try more operations on dead hero
            testHero:takeDamage(50)
            testHero:addXP(100)
            
            -- Position still unchanged
            assert.is.equal(initialX, testHero.x)
            assert.is.equal(initialY, testHero.y)
            
            testHero:destroy()
        end)
    end)
end)
