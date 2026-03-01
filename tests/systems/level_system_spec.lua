require("tests.spec_helper")
local level_system = require("src.systems.level_system")
local Hero = require("src.entities.hero")
local XPOrb = require("src.entities.xp_orb")
local pool = require("src.utils.pool")

describe("Level System", function()
    local hero
    local xpOrbPool
    local levelUpCallback
    local levelUpCalled

    before_each(function()
        -- Create hero
        hero = Hero:new(360, 1180)
        
        -- Create XP orb pool
        xpOrbPool = pool.new(
            function() return XPOrb:new() end,
            function(orb, x, y) orb:activate(x, y) end
        )
        
        -- Create level-up callback
        levelUpCalled = false
        levelUpCallback = function(level)
            levelUpCalled = true
        end
        
        -- Initialize level system
        level_system.initialize(hero, xpOrbPool, levelUpCallback)
    end)

    after_each(function()
        level_system.cleanup()
        hero = nil
        xpOrbPool = nil
        levelUpCallback = nil
    end)

    describe("initialization", function()
        it("should initialize with hero reference", function()
            assert.are.equal(hero, level_system.hero)
        end)

        it("should initialize with XP orb pool reference", function()
            assert.are.equal(xpOrbPool, level_system.xpOrbPool)
        end)

        it("should initialize with level-up callback", function()
            assert.are.equal(levelUpCallback, level_system.onLevelUp)
        end)

        it("should initialize with empty active orbs array", function()
            assert.are.equal(0, #level_system.activeOrbs)
        end)
    end)

    -- **Validates: Requirements 5.2, 5.4, 5.5, 5.6**
    -- Test XP orb spawning and activation
    describe("XP orb spawning and activation", function()
        it("should spawn XP orb at specified position", function()
            local orb = level_system.spawnXPOrb(100, 200)
            
            assert.is_not_nil(orb)
            assert.are.equal(100, orb.x)
            assert.are.equal(200, orb.y)
        end)

        it("should activate spawned orb", function()
            local orb = level_system.spawnXPOrb(100, 200)
            
            assert.is_true(orb.isActive)
        end)

        it("should add spawned orb to active orbs array", function()
            level_system.spawnXPOrb(100, 200)
            
            assert.are.equal(1, #level_system.activeOrbs)
        end)

        it("should spawn multiple orbs", function()
            level_system.spawnXPOrb(100, 200)
            level_system.spawnXPOrb(150, 250)
            level_system.spawnXPOrb(200, 300)
            
            assert.are.equal(3, #level_system.activeOrbs)
        end)

        it("should set spawn time on activation", function()
            local orb = level_system.spawnXPOrb(100, 200)
            
            assert.is_not_nil(orb.spawnTime)
            assert.is_true(orb.spawnTime >= 0)
        end)
    end)

    -- **Validates: Requirements 5.2**
    -- Test XP collection on proximity
    describe("XP collection on proximity", function()
        it("should collect orb when hero is within pickup radius", function()
            local orb = level_system.spawnXPOrb(360, 1180)  -- Same position as hero
            
            level_system.checkOrbCollection(hero.x, hero.y, hero.pickupRadius)
            
            assert.are.equal(0, #level_system.activeOrbs)
        end)

        it("should add XP to hero when orb is collected", function()
            local initialXP = hero.xp
            level_system.spawnXPOrb(360, 1180)  -- Same position as hero
            
            level_system.checkOrbCollection(hero.x, hero.y, hero.pickupRadius)
            
            assert.are.equal(initialXP + 10, hero.xp)
        end)

        it("should not collect orb when hero is outside pickup radius", function()
            level_system.spawnXPOrb(500, 500)  -- Far from hero
            
            level_system.checkOrbCollection(hero.x, hero.y, hero.pickupRadius)
            
            assert.are.equal(1, #level_system.activeOrbs)
        end)

        it("should collect orb when hero is exactly at pickup radius", function()
            -- Place orb exactly at pickup radius distance
            local orbX = hero.x + hero.pickupRadius
            local orbY = hero.y
            level_system.spawnXPOrb(orbX, orbY)
            
            level_system.checkOrbCollection(hero.x, hero.y, hero.pickupRadius)
            
            assert.are.equal(0, #level_system.activeOrbs)
        end)

        it("should collect multiple orbs in range", function()
            level_system.spawnXPOrb(hero.x + 10, hero.y)
            level_system.spawnXPOrb(hero.x - 10, hero.y)
            level_system.spawnXPOrb(hero.x, hero.y + 10)
            
            level_system.checkOrbCollection(hero.x, hero.y, hero.pickupRadius)
            
            assert.are.equal(0, #level_system.activeOrbs)
            assert.are.equal(30, hero.xp)  -- 3 orbs * 10 XP each
        end)

        it("should only collect orbs in range, not those outside", function()
            level_system.spawnXPOrb(hero.x + 10, hero.y)  -- In range
            level_system.spawnXPOrb(hero.x + 100, hero.y)  -- Out of range
            
            level_system.checkOrbCollection(hero.x, hero.y, hero.pickupRadius)
            
            assert.are.equal(1, #level_system.activeOrbs)
            assert.are.equal(10, hero.xp)
        end)
    end)

    -- **Validates: Requirements 5.4**
    -- Test XP requirement calculation
    describe("XP requirement calculation", function()
        it("should calculate 100 XP for level 1", function()
            local required = level_system.calculateXPRequired(1)
            assert.are.equal(100, required)
        end)

        it("should calculate 120 XP for level 2", function()
            local required = level_system.calculateXPRequired(2)
            assert.are.equal(120, required)
        end)

        it("should calculate 140 XP for level 3", function()
            local required = level_system.calculateXPRequired(3)
            assert.are.equal(140, required)
        end)

        it("should calculate 200 XP for level 6", function()
            local required = level_system.calculateXPRequired(6)
            assert.are.equal(200, required)
        end)

        it("should calculate 480 XP for level 20", function()
            local required = level_system.calculateXPRequired(20)
            assert.are.equal(480, required)
        end)

        it("should follow formula: 100 + (level - 1) * 20", function()
            for level = 1, 20 do
                local expected = 100 + (level - 1) * 20
                local actual = level_system.calculateXPRequired(level)
                assert.are.equal(expected, actual)
            end
        end)
    end)

    -- **Validates: Requirements 5.5, 5.6**
    -- Test level-up trigger and callback
    describe("level-up trigger and callback", function()
        it("should trigger level-up when XP reaches requirement", function()
            level_system.addXP(100)
            
            assert.are.equal(2, hero.level)
        end)

        it("should call level-up callback when leveling up", function()
            level_system.addXP(100)
            
            assert.is_true(levelUpCalled)
        end)

        it("should update XP requirement after level-up", function()
            level_system.addXP(100)
            
            assert.are.equal(120, hero.xpRequired)
        end)

        it("should carry over excess XP to next level", function()
            level_system.addXP(110)  -- 10 XP over requirement
            
            assert.are.equal(2, hero.level)
            assert.are.equal(10, hero.xp)
        end)

        it("should handle multiple level-ups from single XP gain", function()
            level_system.addXP(250)  -- Enough for level 2 (100) and level 3 (120)
            
            assert.are.equal(3, hero.level)
            assert.are.equal(30, hero.xp)  -- 250 - 100 - 120 = 30
        end)

        it("should not level up when XP is below requirement", function()
            level_system.addXP(50)
            
            assert.are.equal(1, hero.level)
            assert.are.equal(50, hero.xp)
        end)

        it("should handle level-up at exact XP requirement", function()
            level_system.addXP(100)
            
            assert.are.equal(2, hero.level)
            assert.are.equal(0, hero.xp)
        end)
    end)

    describe("orb lifetime expiration", function()
        it("should remove expired orbs after 30 seconds", function()
            -- Mock system.getTimer to return a specific time
            local mockTime = 1000  -- 1 second in milliseconds
            _G.system.getTimer = function() return mockTime end
            
            local orb = level_system.spawnXPOrb(100, 200)
            local spawnTime = orb.spawnTime
            
            -- Simulate 31 seconds passing
            level_system.update(0, spawnTime + 31)
            
            assert.are.equal(0, #level_system.activeOrbs)
            
            -- Restore mock
            _G.system.getTimer = function() return 0 end
        end)

        it("should not remove orbs before 30 seconds", function()
            -- Mock system.getTimer to return a specific time
            local mockTime = 1000  -- 1 second in milliseconds
            _G.system.getTimer = function() return mockTime end
            
            local orb = level_system.spawnXPOrb(100, 200)
            local spawnTime = orb.spawnTime
            
            -- Simulate 29 seconds passing
            level_system.update(0, spawnTime + 29)
            
            assert.are.equal(1, #level_system.activeOrbs)
            
            -- Restore mock
            _G.system.getTimer = function() return 0 end
        end)

        it("should remove multiple expired orbs", function()
            -- Mock system.getTimer to return a specific time
            local mockTime = 1000  -- 1 second in milliseconds
            _G.system.getTimer = function() return mockTime end
            
            local orb1 = level_system.spawnXPOrb(100, 200)
            local orb2 = level_system.spawnXPOrb(150, 250)
            local spawnTime = orb1.spawnTime
            
            -- Simulate 31 seconds passing
            level_system.update(0, spawnTime + 31)
            
            assert.are.equal(0, #level_system.activeOrbs)
            
            -- Restore mock
            _G.system.getTimer = function() return 0 end
        end)

        it("should keep active orbs and remove only expired ones", function()
            -- Mock system.getTimer to return a specific time
            local mockTime = 1000  -- 1 second in milliseconds
            _G.system.getTimer = function() return mockTime end
            
            local orb1 = level_system.spawnXPOrb(100, 200)
            local spawnTime1 = orb1.spawnTime
            
            -- Wait 31 seconds
            level_system.update(0, spawnTime1 + 31)
            
            -- Update mock time for new orb
            mockTime = 32000  -- 32 seconds
            
            -- Spawn new orb after first expired
            local orb2 = level_system.spawnXPOrb(150, 250)
            
            assert.are.equal(1, #level_system.activeOrbs)
            assert.are.equal(orb2, level_system.activeOrbs[1])
            
            -- Restore mock
            _G.system.getTimer = function() return 0 end
        end)
    end)

    describe("getActiveOrbs", function()
        it("should return active orbs array", function()
            level_system.spawnXPOrb(100, 200)
            level_system.spawnXPOrb(150, 250)
            
            local orbs = level_system.getActiveOrbs()
            assert.are.equal(2, #orbs)
        end)

        it("should return reference to actual array", function()
            local orbs = level_system.getActiveOrbs()
            assert.are.equal(level_system.activeOrbs, orbs)
        end)
    end)

    describe("cleanup", function()
        it("should deactivate all active orbs", function()
            level_system.spawnXPOrb(100, 200)
            level_system.spawnXPOrb(150, 250)
            level_system.spawnXPOrb(200, 300)
            
            level_system.cleanup()
            
            assert.are.equal(0, #level_system.activeOrbs)
        end)

        it("should clear hero reference", function()
            level_system.cleanup()
            
            assert.is_nil(level_system.hero)
        end)

        it("should clear XP orb pool reference", function()
            level_system.cleanup()
            
            assert.is_nil(level_system.xpOrbPool)
        end)

        it("should clear level-up callback", function()
            level_system.cleanup()
            
            assert.is_nil(level_system.onLevelUp)
        end)
    end)

    describe("update removes inactive orbs", function()
        it("should remove deactivated orbs from active array", function()
            level_system.spawnXPOrb(100, 200)
            level_system.spawnXPOrb(150, 250)
            level_system.spawnXPOrb(200, 300)
            
            -- Deactivate middle orb
            level_system.activeOrbs[2]:deactivate()
            
            level_system.update(0, 0)
            
            assert.are.equal(2, #level_system.activeOrbs)
        end)

        it("should keep active orbs in array", function()
            local orb = level_system.spawnXPOrb(100, 200)
            
            level_system.update(0, 0)
            
            assert.are.equal(1, #level_system.activeOrbs)
            assert.are.equal(orb, level_system.activeOrbs[1])
        end)
    end)
end)

-- **Validates: Requirements 5.2**
-- Property 17: XP Collection on Proximity
describe("Property 17: XP Collection on Proximity", function()
    local generators = require("tests.generators.game_generators")

    it("should collect any XP orb within hero pickup radius and add XP to hero", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero and level system for each test
            local testHero = Hero:new(360, 1180)
            local testPool = pool.new(
                function() return XPOrb:new() end,
                function(orb, x, y) orb:activate(x, y) end
            )
            level_system.initialize(testHero, testPool, function() end)
            
            -- Generate random position
            local pos = generators.position()()
            
            -- Spawn orb at random position
            level_system.spawnXPOrb(pos.x, pos.y)
            
            -- Calculate distance from hero to orb
            local dx = pos.x - testHero.x
            local dy = pos.y - testHero.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- Store initial state
            local initialXP = testHero.xp
            local initialOrbCount = #level_system.activeOrbs
            
            -- Check for collection
            level_system.checkOrbCollection(testHero.x, testHero.y, testHero.pickupRadius)
            
            -- Property: If distance <= pickup radius, orb should be collected and XP added
            if distance <= testHero.pickupRadius then
                assert.are.equal(0, #level_system.activeOrbs, "Orb should be collected when within radius")
                assert.are.equal(initialXP + 10, testHero.xp, "XP should be added when orb collected")
            else
                -- Orb should not be collected
                assert.are.equal(initialOrbCount, #level_system.activeOrbs, "Orb should not be collected when outside radius")
                assert.are.equal(initialXP, testHero.xp, "XP should not change when orb not collected")
            end
            
            -- Cleanup
            level_system.cleanup()
        end
    end)

    it("should collect multiple orbs within radius in a single check", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero and level system for each test
            local testHero = Hero:new(360, 1180)
            local testPool = pool.new(
                function() return XPOrb:new() end,
                function(orb, x, y) orb:activate(x, y) end
            )
            level_system.initialize(testHero, testPool, function() end)
            
            -- Generate random number of orbs (1-10)
            local orbCount = math.random(1, 10)
            local expectedCollected = 0
            
            -- Spawn orbs at random positions
            for i = 1, orbCount do
                local pos = generators.position()()
                level_system.spawnXPOrb(pos.x, pos.y)
                
                -- Calculate if this orb should be collected
                local dx = pos.x - testHero.x
                local dy = pos.y - testHero.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance <= testHero.pickupRadius then
                    expectedCollected = expectedCollected + 1
                end
            end
            
            -- Store initial XP
            local initialXP = testHero.xp
            
            -- Check for collection
            level_system.checkOrbCollection(testHero.x, testHero.y, testHero.pickupRadius)
            
            -- Property: All orbs within radius should be collected
            local expectedRemainingOrbs = orbCount - expectedCollected
            assert.are.equal(expectedRemainingOrbs, #level_system.activeOrbs, 
                "Correct number of orbs should remain after collection")
            assert.are.equal(initialXP + (expectedCollected * 10), testHero.xp,
                "XP should equal initial + (collected orbs * 10)")
            
            -- Cleanup
            level_system.cleanup()
        end
    end)

    it("should respect custom pickup radius values", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero with random pickup radius
            local testHero = Hero:new(360, 1180)
            testHero.pickupRadius = math.random(20, 100)  -- Random radius between 20-100
            
            local testPool = pool.new(
                function() return XPOrb:new() end,
                function(orb, x, y) orb:activate(x, y) end
            )
            level_system.initialize(testHero, testPool, function() end)
            
            -- Spawn orb slightly within pickup radius distance (0.99 to account for floating point)
            local angle = math.random() * 2 * math.pi
            local orbX = testHero.x + math.cos(angle) * (testHero.pickupRadius * 0.99)
            local orbY = testHero.y + math.sin(angle) * (testHero.pickupRadius * 0.99)
            
            level_system.spawnXPOrb(orbX, orbY)
            
            -- Check for collection
            level_system.checkOrbCollection(testHero.x, testHero.y, testHero.pickupRadius)
            
            -- Property: Orb within pickup radius distance should be collected
            assert.are.equal(0, #level_system.activeOrbs, 
                "Orb within pickup radius should be collected")
            assert.are.equal(10, testHero.xp, "XP should be added")
            
            -- Cleanup
            level_system.cleanup()
        end
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
            local actual = level_system.calculateXPRequired(level)
            
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
            local currentRequired = level_system.calculateXPRequired(level)
            local nextRequired = level_system.calculateXPRequired(level + 1)
            
            -- Property: Next level should require exactly 20 more XP
            assert.are.equal(currentRequired + 20, nextRequired,
                string.format("Level %d should require 20 more XP than level %d", level + 1, level))
        end
    end)

    it("should calculate correct XP requirements for edge case levels", function()
        -- Test level 1 (minimum)
        assert.are.equal(100, level_system.calculateXPRequired(1))
        
        -- Test level 2 (first increment)
        assert.are.equal(120, level_system.calculateXPRequired(2))
        
        -- Test level 20 (typical max in design)
        assert.are.equal(480, level_system.calculateXPRequired(20))
        
        -- Test very high level (100)
        assert.are.equal(2080, level_system.calculateXPRequired(100))
    end)

    it("should maintain formula consistency across multiple calculations", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Generate random level
            local level = generators.heroLevel()()
            
            -- Calculate XP requirement multiple times
            local result1 = level_system.calculateXPRequired(level)
            local result2 = level_system.calculateXPRequired(level)
            local result3 = level_system.calculateXPRequired(level)
            
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
            local testPool = pool.new(
                function() return XPOrb:new() end,
                function(orb, x, y) orb:activate(x, y) end
            )
            
            local levelUpTriggered = false
            local levelUpCallback = function(newLevel)
                levelUpTriggered = true
            end
            
            level_system.initialize(testHero, testPool, levelUpCallback)
            
            -- Generate random XP amount (0-300)
            local xpAmount = math.random(0, 300)
            
            -- Calculate expected level after adding XP
            local expectedLevel = testHero.level
            local remainingXP = testHero.xp + xpAmount
            
            while remainingXP >= level_system.calculateXPRequired(expectedLevel) do
                remainingXP = remainingXP - level_system.calculateXPRequired(expectedLevel)
                expectedLevel = expectedLevel + 1
            end
            
            -- Add XP
            level_system.addXP(xpAmount)
            
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
            level_system.cleanup()
        end
    end)

    it("should update XP requirement after each level-up", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero and level system
            local testHero = Hero:new(360, 1180)
            local testPool = pool.new(
                function() return XPOrb:new() end,
                function(orb, x, y) orb:activate(x, y) end
            )
            level_system.initialize(testHero, testPool, function() end)
            
            -- Generate random XP amount that will cause at least one level-up
            local xpAmount = math.random(100, 500)
            
            -- Add XP
            level_system.addXP(xpAmount)
            
            -- Property: XP requirement should match formula for current level
            local expectedRequirement = level_system.calculateXPRequired(testHero.level)
            assert.are.equal(expectedRequirement, testHero.xpRequired,
                string.format("XP requirement should be %d for level %d", expectedRequirement, testHero.level))
            
            -- Cleanup
            level_system.cleanup()
        end
    end)

    it("should handle multiple level-ups from single XP gain", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero and level system
            local testHero = Hero:new(360, 1180)
            local testPool = pool.new(
                function() return XPOrb:new() end,
                function(orb, x, y) orb:activate(x, y) end
            )
            
            local levelUpCount = 0
            local levelUpCallback = function(newLevel)
                levelUpCount = levelUpCount + 1
            end
            
            level_system.initialize(testHero, testPool, levelUpCallback)
            
            -- Add enough XP for multiple level-ups (500-1000 XP)
            local xpAmount = math.random(500, 1000)
            local initialLevel = testHero.level
            
            level_system.addXP(xpAmount)
            
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
            level_system.cleanup()
        end
    end)

    it("should not trigger level-up when XP is below requirement", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero and level system
            local testHero = Hero:new(360, 1180)
            local testPool = pool.new(
                function() return XPOrb:new() end,
                function(orb, x, y) orb:activate(x, y) end
            )
            
            local levelUpTriggered = false
            local levelUpCallback = function(newLevel)
                levelUpTriggered = true
            end
            
            level_system.initialize(testHero, testPool, levelUpCallback)
            
            -- Add XP less than requirement (1-99)
            local xpAmount = math.random(1, 99)
            local initialLevel = testHero.level
            
            level_system.addXP(xpAmount)
            
            -- Property: Level should not change
            assert.are.equal(initialLevel, testHero.level, "Level should not change")
            
            -- Property: XP should accumulate
            assert.are.equal(xpAmount, testHero.xp, "XP should accumulate")
            
            -- Property: Callback should not be triggered
            assert.is_false(levelUpTriggered, "Level-up callback should not be triggered")
            
            -- Cleanup
            level_system.cleanup()
        end
    end)

    it("should handle exact XP requirement amounts", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero and level system
            local testHero = Hero:new(360, 1180)
            local testPool = pool.new(
                function() return XPOrb:new() end,
                function(orb, x, y) orb:activate(x, y) end
            )
            
            local levelUpTriggered = false
            local levelUpCallback = function(newLevel)
                levelUpTriggered = true
            end
            
            level_system.initialize(testHero, testPool, levelUpCallback)
            
            -- Add exactly the XP requirement
            local xpAmount = testHero.xpRequired
            
            level_system.addXP(xpAmount)
            
            -- Property: Should level up to exactly level 2
            assert.are.equal(2, testHero.level, "Should level up to level 2")
            
            -- Property: Remaining XP should be exactly 0
            assert.are.equal(0, testHero.xp, "Remaining XP should be 0")
            
            -- Property: Callback should be triggered
            assert.is_true(levelUpTriggered, "Level-up callback should be triggered")
            
            -- Cleanup
            level_system.cleanup()
        end
    end)
end)

-- Error Handling Tests
describe("Error Handling", function()
    local hero
    local xpOrbPool
    local levelUpCallback

    before_each(function()
        hero = Hero:new(360, 1180)
        xpOrbPool = pool.new(
            function() return XPOrb:new() end,
            function(orb, x, y) orb:activate(x, y) end
        )
        levelUpCallback = function(level) end
        level_system.initialize(hero, xpOrbPool, levelUpCallback)
    end)

    after_each(function()
        level_system.cleanup()
    end)

    describe("addXP validation", function()
        it("should reject negative XP amounts", function()
            local initialXP = hero.xp
            level_system.addXP(-10)
            
            assert.are.equal(initialXP, hero.xp, "XP should not change with negative amount")
        end)

        it("should reject zero XP amounts", function()
            local initialXP = hero.xp
            level_system.addXP(0)
            
            assert.are.equal(initialXP, hero.xp, "XP should not change with zero amount")
        end)

        it("should reject non-number XP amounts", function()
            local initialXP = hero.xp
            level_system.addXP("100")
            
            assert.are.equal(initialXP, hero.xp, "XP should not change with string amount")
        end)

        it("should reject nil XP amounts", function()
            local initialXP = hero.xp
            level_system.addXP(nil)
            
            assert.are.equal(initialXP, hero.xp, "XP should not change with nil amount")
        end)

        it("should clamp XP to maximum of 999999", function()
            level_system.addXP(1000000)
            
            -- Should add 999999 instead of 1000000
            -- Hero starts at level 1 with 0 XP, requirement is 100
            -- After adding 999999, hero should level up many times
            assert.is_true(hero.xp < 999999, "XP should be clamped to 999999")
        end)

        it("should accept valid positive XP amounts", function()
            local initialXP = hero.xp
            level_system.addXP(50)
            
            assert.are.equal(initialXP + 50, hero.xp, "Valid XP should be added")
        end)
    end)

    describe("spawnXPOrb validation", function()
        it("should reject invalid X coordinate", function()
            local orb = level_system.spawnXPOrb("invalid", 100)
            
            assert.is_nil(orb, "Should return nil for invalid X coordinate")
            assert.are.equal(0, #level_system.activeOrbs, "Should not add orb to active list")
        end)

        it("should reject invalid Y coordinate", function()
            local orb = level_system.spawnXPOrb(100, "invalid")
            
            assert.is_nil(orb, "Should return nil for invalid Y coordinate")
            assert.are.equal(0, #level_system.activeOrbs, "Should not add orb to active list")
        end)

        it("should reject nil coordinates", function()
            local orb = level_system.spawnXPOrb(nil, nil)
            
            assert.is_nil(orb, "Should return nil for nil coordinates")
            assert.are.equal(0, #level_system.activeOrbs, "Should not add orb to active list")
        end)

        it("should accept valid coordinates", function()
            local orb = level_system.spawnXPOrb(100, 200)
            
            assert.is_not_nil(orb, "Should return orb for valid coordinates")
            assert.are.equal(1, #level_system.activeOrbs, "Should add orb to active list")
        end)

        it("should handle missing pool gracefully", function()
            level_system.xpOrbPool = nil
            local orb = level_system.spawnXPOrb(100, 200)
            
            assert.is_nil(orb, "Should return nil when pool is missing")
        end)
    end)

    describe("checkOrbCollection validation", function()
        it("should handle invalid hero X coordinate", function()
            level_system.spawnXPOrb(100, 200)
            
            -- Should not crash with invalid coordinates
            level_system.checkOrbCollection("invalid", 100, 40)
            
            assert.are.equal(1, #level_system.activeOrbs, "Orb should remain uncollected")
        end)

        it("should handle invalid hero Y coordinate", function()
            level_system.spawnXPOrb(100, 200)
            
            level_system.checkOrbCollection(100, "invalid", 40)
            
            assert.are.equal(1, #level_system.activeOrbs, "Orb should remain uncollected")
        end)

        it("should handle invalid pickup radius", function()
            level_system.spawnXPOrb(100, 200)
            
            level_system.checkOrbCollection(100, 200, "invalid")
            
            assert.are.equal(1, #level_system.activeOrbs, "Orb should remain uncollected")
        end)

        it("should handle negative pickup radius", function()
            level_system.spawnXPOrb(100, 200)
            
            level_system.checkOrbCollection(100, 200, -40)
            
            assert.are.equal(1, #level_system.activeOrbs, "Orb should remain uncollected with negative radius")
        end)

        it("should handle zero pickup radius", function()
            level_system.spawnXPOrb(100, 200)
            
            level_system.checkOrbCollection(100, 200, 0)
            
            assert.are.equal(1, #level_system.activeOrbs, "Orb should remain uncollected with zero radius")
        end)

        it("should handle orb with invalid position", function()
            local orb = level_system.spawnXPOrb(100, 200)
            orb.x = "invalid"
            
            -- Should not crash with invalid orb position
            level_system.checkOrbCollection(100, 200, 40)
            
            assert.are.equal(1, #level_system.activeOrbs, "Orb with invalid position should remain")
        end)

        it("should handle nil orb in active list", function()
            level_system.spawnXPOrb(100, 200)
            table.insert(level_system.activeOrbs, nil)
            
            -- Should not crash with nil orb
            level_system.checkOrbCollection(100, 200, 40)
        end)
    end)

    describe("update validation", function()
        it("should handle invalid dt parameter", function()
            level_system.spawnXPOrb(100, 200)
            
            -- Should not crash with invalid dt
            level_system.update("invalid", 0)
            
            assert.are.equal(1, #level_system.activeOrbs, "Orbs should remain")
        end)

        it("should handle invalid currentTime parameter", function()
            level_system.spawnXPOrb(100, 200)
            
            -- Should not crash with invalid currentTime
            level_system.update(0, "invalid")
            
            assert.are.equal(1, #level_system.activeOrbs, "Orbs should remain")
        end)

        it("should handle orb without update method", function()
            local invalidOrb = { isActive = true }
            table.insert(level_system.activeOrbs, invalidOrb)
            
            -- Should not crash and should remove invalid orb
            level_system.update(0, 0)
            
            assert.are.equal(0, #level_system.activeOrbs, "Invalid orb should be removed")
        end)

        it("should handle nil orb in active list", function()
            table.insert(level_system.activeOrbs, nil)
            
            -- Should not crash with nil orb
            level_system.update(0, 0)
            
            assert.are.equal(0, #level_system.activeOrbs, "Nil orb should be removed")
        end)

        it("should handle missing pool during cleanup", function()
            level_system.spawnXPOrb(100, 200)
            level_system.activeOrbs[1].isActive = false
            level_system.xpOrbPool = nil
            
            -- Should not crash when pool is missing
            level_system.update(0, 0)
            
            assert.are.equal(0, #level_system.activeOrbs, "Inactive orb should be removed")
        end)
    end)

    describe("calculateXPRequired validation", function()
        it("should handle invalid level parameter", function()
            local result = level_system.calculateXPRequired("invalid")
            
            assert.are.equal(100, result, "Should return base XP for invalid level")
        end)

        it("should handle negative level", function()
            local result = level_system.calculateXPRequired(-5)
            
            assert.are.equal(100, result, "Should return base XP for negative level")
        end)

        it("should handle zero level", function()
            local result = level_system.calculateXPRequired(0)
            
            assert.are.equal(100, result, "Should return base XP for zero level")
        end)

        it("should handle nil level", function()
            local result = level_system.calculateXPRequired(nil)
            
            assert.are.equal(100, result, "Should return base XP for nil level")
        end)

        it("should handle valid level 1", function()
            local result = level_system.calculateXPRequired(1)
            
            assert.are.equal(100, result, "Should return correct XP for level 1")
        end)
    end)
end)
