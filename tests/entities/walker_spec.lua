require("tests.spec_helper")
local Walker = require("src.entities.walker")

describe("Walker Entity", function()
    local walker

    before_each(function()
        walker = Walker:new()
    end)

    after_each(function()
        if walker and walker.destroy then
            walker:destroy()
        end
        walker = nil
    end)

    describe("initialization", function()
        it("should initialize with default position at origin", function()
            assert.is.equal(0, walker.x)
            assert.is.equal(0, walker.y)
        end)

        it("should initialize with lane set to 0", function()
            assert.is.equal(0, walker.lane)
        end)

        it("should initialize with 20 health", function()
            assert.is.equal(20, walker.health)
            assert.is.equal(20, walker.maxHealth)
        end)

        it("should initialize with speed of 80 pixels per second", function()
            assert.is.equal(80, walker.speed)
        end)

        it("should initialize with damage of 5", function()
            assert.is.equal(5, walker.damage)
        end)

        it("should initialize with attack cooldown of 1.0 seconds", function()
            assert.is.equal(1.0, walker.attackCooldown)
        end)

        it("should initialize with lastAttackTime of 0", function()
            assert.is.equal(0, walker.lastAttackTime)
        end)

        it("should initialize with wallTarget as nil", function()
            assert.is_nil(walker.wallTarget)
        end)

        it("should initialize with isAttackingWall as false", function()
            assert.is_false(walker.isAttackingWall)
        end)

        it("should initialize as inactive", function()
            assert.is_false(walker.isActive)
        end)

        it("should initialize with nil display object", function()
            assert.is_nil(walker.displayObject)
        end)

        it("should initialize with type set to 'walker'", function()
            assert.is.equal("walker", walker.type)
        end)

        it("should initialize with xpValue as nil", function()
            assert.is_nil(walker.xpValue)
        end)
    end)

    -- **Validates: Requirements 4.1, 4.3, 4.4**
    -- Test activate/deactivate for pooling
    describe("activate and deactivate for pooling", function()
        it("should activate walker with position and lane", function()
            walker:activate(200, 100, 200)
            assert.is.equal(200, walker.x)
            assert.is.equal(100, walker.y)
            assert.is.equal(200, walker.lane)
            assert.is_true(walker.isActive)
        end)

        it("should reset health to max on activation", function()
            walker:activate(100, 50, 100)
            walker.health = 10
            walker:activate(200, 100, 200)
            assert.is.equal(20, walker.health)
        end)

        it("should reset lastAttackTime on activation", function()
            walker:activate(100, 50, 100)
            walker.lastAttackTime = 5.0
            walker:activate(200, 100, 200)
            assert.is.equal(0, walker.lastAttackTime)
        end)

        it("should reset wallTarget on activation", function()
            walker:activate(100, 50, 100)
            walker.wallTarget = {health = 100}
            walker:activate(200, 100, 200)
            assert.is_nil(walker.wallTarget)
        end)

        it("should reset isAttackingWall on activation", function()
            walker:activate(100, 50, 100)
            walker.isAttackingWall = true
            walker:activate(200, 100, 200)
            assert.is_false(walker.isAttackingWall)
        end)

        it("should create display object on first activation", function()
            walker:activate(150, 75, 150)
            assert.is_not_nil(walker.displayObject)
            assert.is.equal(150, walker.displayObject.x)
            assert.is.equal(75, walker.displayObject.y)
        end)

        it("should reuse display object on subsequent activations", function()
            walker:activate(100, 50, 100)
            local firstDisplayObj = walker.displayObject
            walker:deactivate()
            walker:activate(200, 100, 200)
            assert.is.equal(firstDisplayObj, walker.displayObject)
            assert.is.equal(200, walker.displayObject.x)
            assert.is.equal(100, walker.displayObject.y)
        end)

        it("should make display object visible on activation", function()
            walker:activate(100, 50, 100)
            walker:deactivate()
            walker:activate(200, 100, 200)
            assert.is_true(walker.displayObject.isVisible)
        end)

        it("should deactivate walker and set isActive to false", function()
            walker:activate(100, 50, 100)
            walker:deactivate()
            assert.is_false(walker.isActive)
        end)

        it("should hide display object on deactivation", function()
            walker:activate(100, 50, 100)
            walker:deactivate()
            assert.is_false(walker.displayObject.isVisible)
        end)

        it("should reset wallTarget on deactivation", function()
            walker:activate(100, 50, 100)
            walker.wallTarget = {health = 100}
            walker:deactivate()
            assert.is_nil(walker.wallTarget)
        end)

        it("should reset isAttackingWall on deactivation", function()
            walker:activate(100, 50, 100)
            walker.isAttackingWall = true
            walker:deactivate()
            assert.is_false(walker.isAttackingWall)
        end)

        it("should handle deactivation when display object is nil", function()
            walker:deactivate()
            assert.is_false(walker.isActive)
        end)
    end)

    -- **Validates: Requirements 3.1, 3.2, 3.3, 3.4**
    -- Test Y-threshold based movement
    describe("Y-threshold based movement", function()
        local wallThreshold = 1180

        it("should move down by speed * dt when above wall threshold", function()
            walker:activate(200, 100, 200)
            local initialY = walker.y
            local dt = 1.0
            walker:update(dt, wallThreshold)
            assert.is.equal(initialY + (walker.speed * dt), walker.y)
            assert.is.equal(180, walker.y)
        end)

        it("should stop moving when Y reaches wall threshold", function()
            walker:activate(200, 1180, 200)
            local initialY = walker.y
            walker:update(1.0, wallThreshold)
            assert.is.equal(initialY, walker.y)
            assert.is.equal(1180, walker.y)
        end)

        it("should stop moving when Y exceeds wall threshold", function()
            walker:activate(200, 1200, 200)
            local initialY = walker.y
            walker:update(1.0, wallThreshold)
            assert.is.equal(initialY, walker.y)
        end)

        it("should set isAttackingWall to true when at threshold", function()
            walker:activate(200, 1180, 200)
            walker:update(0.016, wallThreshold)
            assert.is_true(walker.isAttackingWall)
        end)

        it("should set isAttackingWall to true when past threshold", function()
            walker:activate(200, 1200, 200)
            walker:update(0.016, wallThreshold)
            assert.is_true(walker.isAttackingWall)
        end)

        it("should not set isAttackingWall when above threshold", function()
            walker:activate(200, 1100, 200)
            walker:update(0.016, wallThreshold)
            assert.is_false(walker.isAttackingWall)
        end)

        it("should keep X position constant during movement", function()
            walker:activate(200, 100, 200)
            local initialX = walker.x
            walker:update(1.0, wallThreshold)
            assert.is.equal(initialX, walker.x)
            assert.is.equal(200, walker.x)
        end)

        it("should update display object Y position during movement", function()
            walker:activate(200, 100, 200)
            walker:update(0.5, wallThreshold)
            assert.is.equal(walker.y, walker.displayObject.y)
            assert.is.equal(140, walker.displayObject.y)
        end)

        it("should not move when inactive", function()
            walker:activate(200, 100, 200)
            walker:deactivate()
            local initialY = walker.y
            walker:update(1.0, wallThreshold)
            assert.is.equal(initialY, walker.y)
        end)

        it("should move correctly with small dt values", function()
            walker:activate(200, 100, 200)
            local dt = 0.016
            walker:update(dt, wallThreshold)
            assert.is.equal(100 + (80 * 0.016), walker.y)
        end)

        it("should accumulate movement over multiple updates until threshold", function()
            walker:activate(200, 1100, 200)
            walker:update(0.5, wallThreshold)
            walker:update(0.5, wallThreshold)
            -- After 1 second at 80px/s, should be at 1180 (threshold)
            assert.is.equal(1180, walker.y)
            assert.is_true(walker.isAttackingWall)
        end)

        it("should maintain lane (X) across multiple updates", function()
            walker:activate(300, 50, 300)
            for i = 1, 10 do
                walker:update(0.1, wallThreshold)
            end
            assert.is.equal(300, walker.x)
            assert.is.equal(300, walker.lane)
        end)
    end)

    -- **Validates: Requirements 4.3, 4.4**
    -- Test takeDamage and defeat behavior
    describe("takeDamage and defeat behavior", function()
        it("should reduce health by damage amount", function()
            walker:activate(200, 100, 200)
            walker:takeDamage(5)
            assert.is.equal(15, walker.health)
        end)

        it("should reduce health correctly with multiple damage calls", function()
            walker:activate(200, 100, 200)
            walker:takeDamage(3)
            walker:takeDamage(7)
            walker:takeDamage(2)
            assert.is.equal(8, walker.health)
        end)

        it("should set health to zero when damage equals health", function()
            walker:activate(200, 100, 200)
            walker:takeDamage(20)
            assert.is.equal(0, walker.health)
        end)

        it("should set health to zero when damage exceeds health", function()
            walker:activate(200, 100, 200)
            walker:takeDamage(25)
            assert.is.equal(0, walker.health)
        end)

        it("should deactivate when health reaches zero", function()
            walker:activate(200, 100, 200)
            walker:takeDamage(20)
            assert.is_false(walker.isActive)
        end)

        it("should deactivate when health goes below zero", function()
            walker:activate(200, 100, 200)
            walker:takeDamage(30)
            assert.is_false(walker.isActive)
            assert.is.equal(0, walker.health)
        end)

        it("should not take damage when inactive", function()
            walker:activate(200, 100, 200)
            walker:deactivate()
            local currentHealth = walker.health
            walker:takeDamage(10)
            assert.is.equal(currentHealth, walker.health)
        end)

        it("should handle zero damage", function()
            walker:activate(200, 100, 200)
            walker:takeDamage(0)
            assert.is.equal(20, walker.health)
            assert.is_true(walker.isActive)
        end)

        it("should hide display object when defeated", function()
            walker:activate(200, 100, 200)
            walker:takeDamage(20)
            assert.is_false(walker.displayObject.isVisible)
        end)
    end)

    describe("destroy", function()
        it("should remove display object", function()
            walker:activate(100, 50, 100)
            walker:destroy()
            assert.is_nil(walker.displayObject)
        end)

        it("should handle destroy when display object is nil", function()
            walker:destroy()
            assert.is_nil(walker.displayObject)
        end)

        it("should handle multiple destroy calls safely", function()
            walker:activate(100, 50, 100)
            walker:destroy()
            walker:destroy()
            assert.is_nil(walker.displayObject)
        end)
    end)

    -- **Validates: Requirements 3.8**
    -- Property 10: Lane Assignment
    describe("Property 10: Lane Assignment", function()
        local lqc = require("lqc.quickcheck")
        local lqc_gen = require("lqc.lqc_gen")
        local generators = require("tests.generators.game_generators")

        it("should assign lane equal to spawn X coordinate for any spawned walker", function()
            -- Run property test with 100 iterations
            for _ = 1, 100 do
                local walkerConfig = generators.walker()()
                
                -- Create a fresh walker for each test
                local testWalker = Walker:new()
                
                -- Activate walker with spawn position
                testWalker:activate(walkerConfig.x, walkerConfig.y, walkerConfig.x)
                
                -- Property: lane should equal spawn X coordinate
                assert.are.equal(walkerConfig.x, testWalker.lane)
                
                -- Cleanup
                testWalker:destroy()
            end
        end)
    end)

    -- **Validates: Requirements 3.1, 3.3**
    -- Property 11: Walker Vertical Movement
    describe("Property 11: Walker Vertical Movement", function()
        local generators = require("tests.generators.game_generators")

        it("should move down by 80 * dt pixels while X remains constant for any walker and time interval", function()
            local wallThreshold = 1180
            
            -- Run property test with 100 iterations
            for _ = 1, 100 do
                local walkerConfig = generators.walker()()
                
                -- Generate random time interval (0.001 to 2.0 seconds)
                local dt = math.random(1, 2000) / 1000.0
                
                -- Create a fresh walker for each test
                local testWalker = Walker:new()
                
                -- Activate walker with spawn position (ensure it's above threshold)
                local spawnY = math.min(walkerConfig.y, wallThreshold - 200)
                testWalker:activate(walkerConfig.x, spawnY, walkerConfig.x)
                
                -- Store initial positions
                local initialX = testWalker.x
                local initialY = testWalker.y
                
                -- Update walker with wall threshold
                testWalker:update(dt, wallThreshold)
                
                -- Calculate expected Y (clamped at threshold)
                local expectedY = math.min(initialY + (80 * dt), wallThreshold)
                
                -- Property 1: Y position should increase by 80 * dt pixels (or stop at threshold)
                assert.are.equal(expectedY, testWalker.y)
                
                -- Property 2: X position should remain constant
                assert.are.equal(initialX, testWalker.x)
                
                -- Cleanup
                testWalker:destroy()
            end
        end)
    end)
end)
