require("tests.spec_helper")
local XPOrb = require("src.entities.xp_orb")

describe("XP Orb Entity", function()
    local orb

    before_each(function()
        orb = XPOrb:new()
    end)

    after_each(function()
        if orb and orb.destroy then
            orb:destroy()
        end
        orb = nil
    end)

    describe("initialization", function()
        it("should initialize with position at origin", function()
            assert.is.equal(0, orb.x)
            assert.is.equal(0, orb.y)
        end)

        it("should initialize with XP value of 10", function()
            assert.is.equal(10, orb.xpValue)
        end)

        it("should initialize with lifetime of 30 seconds", function()
            assert.is.equal(30, orb.lifetime)
        end)

        it("should initialize with spawn time of 0", function()
            assert.is.equal(0, orb.spawnTime)
        end)

        it("should initialize as inactive", function()
            assert.is_false(orb.isActive)
        end)

        it("should initialize with nil display object", function()
            assert.is_nil(orb.displayObject)
        end)
    end)

    -- **Validates: Requirements 5.1, 5.2**
    -- Test activate sets position and spawn time
    describe("activate", function()
        it("should set position to provided coordinates", function()
            orb:activate(200, 300)
            assert.is.equal(200, orb.x)
            assert.is.equal(300, orb.y)
        end)

        it("should set isActive to true", function()
            orb:activate(100, 150)
            assert.is_true(orb.isActive)
        end)

        it("should record spawn time", function()
            -- Mock system.getTimer to return a known value
            local originalGetTimer = system.getTimer
            system.getTimer = function() return 5000 end  -- 5 seconds in milliseconds
            
            orb:activate(100, 150)
            assert.is.equal(5, orb.spawnTime)  -- Should be 5 seconds
            
            -- Restore original function
            system.getTimer = originalGetTimer
        end)

        it("should create display object on first activation", function()
            orb:activate(150, 200)
            assert.is_not_nil(orb.displayObject)
            assert.is.equal(150, orb.displayObject.x)
            assert.is.equal(200, orb.displayObject.y)
        end)

        it("should reuse display object on subsequent activations", function()
            orb:activate(100, 150)
            local firstDisplayObj = orb.displayObject
            orb:deactivate()
            orb:activate(200, 250)
            assert.is.equal(firstDisplayObj, orb.displayObject)
            assert.is.equal(200, orb.displayObject.x)
            assert.is.equal(250, orb.displayObject.y)
        end)

        it("should make display object visible on activation", function()
            orb:activate(100, 150)
            orb:deactivate()
            orb:activate(200, 250)
            assert.is_true(orb.displayObject.isVisible)
        end)
    end)

    -- **Validates: Requirements 5.1**
    -- Test lifetime expiration after 30 seconds
    describe("update and lifetime expiration", function()
        it("should not deactivate before 30 seconds have elapsed", function()
            orb:activate(100, 150)
            orb.spawnTime = 0
            
            -- Update at 29 seconds
            orb:update(29)
            assert.is_true(orb.isActive)
        end)

        it("should deactivate exactly at 30 seconds", function()
            orb:activate(100, 150)
            orb.spawnTime = 0
            
            -- Update at 30 seconds
            orb:update(30)
            assert.is_false(orb.isActive)
        end)

        it("should deactivate after 30 seconds have elapsed", function()
            orb:activate(100, 150)
            orb.spawnTime = 0
            
            -- Update at 31 seconds
            orb:update(31)
            assert.is_false(orb.isActive)
        end)

        it("should hide display object when lifetime expires", function()
            orb:activate(100, 150)
            orb.spawnTime = 0
            
            orb:update(30)
            assert.is_false(orb.displayObject.isVisible)
        end)

        it("should not update when inactive", function()
            orb:activate(100, 150)
            orb:deactivate()
            local wasActive = orb.isActive
            
            orb:update(50)
            assert.is.equal(wasActive, orb.isActive)
        end)

        it("should handle multiple updates before expiration", function()
            orb:activate(100, 150)
            orb.spawnTime = 0
            
            orb:update(10)
            assert.is_true(orb.isActive)
            
            orb:update(20)
            assert.is_true(orb.isActive)
            
            orb:update(29.9)
            assert.is_true(orb.isActive)
            
            orb:update(30.1)
            assert.is_false(orb.isActive)
        end)
    end)

    -- **Validates: Requirements 5.2**
    -- Test collect behavior
    describe("collect", function()
        it("should return true when collecting an active orb", function()
            orb:activate(100, 150)
            local result = orb:collect()
            assert.is_true(result)
        end)

        it("should deactivate the orb when collected", function()
            orb:activate(100, 150)
            orb:collect()
            assert.is_false(orb.isActive)
        end)

        it("should return false when collecting an inactive orb", function()
            local result = orb:collect()
            assert.is_false(result)
        end)

        it("should hide display object when collected", function()
            orb:activate(100, 150)
            orb:collect()
            assert.is_false(orb.displayObject.isVisible)
        end)

        it("should not allow collecting the same orb twice", function()
            orb:activate(100, 150)
            local firstCollect = orb:collect()
            local secondCollect = orb:collect()
            
            assert.is_true(firstCollect)
            assert.is_false(secondCollect)
        end)
    end)

    describe("deactivate", function()
        it("should set isActive to false", function()
            orb:activate(100, 150)
            orb:deactivate()
            assert.is_false(orb.isActive)
        end)

        it("should hide display object", function()
            orb:activate(100, 150)
            orb:deactivate()
            assert.is_false(orb.displayObject.isVisible)
        end)

        it("should handle deactivation when display object is nil", function()
            orb:deactivate()
            assert.is_false(orb.isActive)
        end)

        it("should handle multiple deactivate calls safely", function()
            orb:activate(100, 150)
            orb:deactivate()
            orb:deactivate()
            assert.is_false(orb.isActive)
        end)
    end)

    describe("destroy", function()
        it("should remove display object", function()
            orb:activate(100, 150)
            orb:destroy()
            assert.is_nil(orb.displayObject)
        end)

        it("should handle destroy when display object is nil", function()
            orb:destroy()
            assert.is_nil(orb.displayObject)
        end)

        it("should handle multiple destroy calls safely", function()
            orb:activate(100, 150)
            orb:destroy()
            orb:destroy()
            assert.is_nil(orb.displayObject)
        end)
    end)

    -- **Validates: Requirements 5.1**
    -- Property 16: XP Orb Lifetime
    describe("Property 16: XP Orb Lifetime", function()
        local generators = require("tests.generators.game_generators")

        it("should despawn and be removed if not collected within 30 seconds of spawn time", function()
            -- Run property test with 100 iterations
            for _ = 1, 100 do
                -- Generate random spawn position
                local spawnPos = generators.position()()
                
                -- Generate random time after 30 seconds (30.0 to 60.0 seconds)
                local currentTime = 30.0 + (math.random(0, 30000) / 1000.0)
                
                -- Create a fresh orb for each test
                local testOrb = XPOrb:new()
                
                -- Activate orb at spawn position
                testOrb:activate(spawnPos.x, spawnPos.y)
                
                -- Set spawn time to 0 for consistent testing
                testOrb.spawnTime = 0
                
                -- Verify orb is active before update
                assert.is_true(testOrb.isActive)
                
                -- Update orb with time >= 30 seconds
                testOrb:update(currentTime)
                
                -- Property: orb should be deactivated (despawned) after 30 seconds
                assert.is_false(testOrb.isActive, 
                    string.format("XP Orb should despawn at time %.2f (>= 30s)", currentTime))
                
                -- Verify display object is hidden
                if testOrb.displayObject then
                    assert.is_false(testOrb.displayObject.isVisible,
                        "Display object should be hidden after despawn")
                end
                
                -- Cleanup
                testOrb:destroy()
            end
        end)

        it("should remain active if checked before 30 seconds have elapsed", function()
            -- Run property test with 100 iterations
            for _ = 1, 100 do
                -- Generate random spawn position
                local spawnPos = generators.position()()
                
                -- Generate random time before 30 seconds (0.0 to 29.999 seconds)
                local currentTime = math.random(0, 29999) / 1000.0
                
                -- Create a fresh orb for each test
                local testOrb = XPOrb:new()
                
                -- Activate orb at spawn position
                testOrb:activate(spawnPos.x, spawnPos.y)
                
                -- Set spawn time to 0 for consistent testing
                testOrb.spawnTime = 0
                
                -- Update orb with time < 30 seconds
                testOrb:update(currentTime)
                
                -- Property: orb should remain active before 30 seconds
                assert.is_true(testOrb.isActive,
                    string.format("XP Orb should remain active at time %.2f (< 30s)", currentTime))
                
                -- Verify display object is still visible
                if testOrb.displayObject then
                    assert.is_true(testOrb.displayObject.isVisible,
                        "Display object should be visible before despawn")
                end
                
                -- Cleanup
                testOrb:destroy()
            end
        end)

        it("should despawn exactly at 30 seconds", function()
            -- Test the boundary condition multiple times
            for _ = 1, 100 do
                -- Generate random spawn position
                local spawnPos = generators.position()()
                
                -- Create a fresh orb for each test
                local testOrb = XPOrb:new()
                
                -- Activate orb at spawn position
                testOrb:activate(spawnPos.x, spawnPos.y)
                
                -- Set spawn time to 0 for consistent testing
                testOrb.spawnTime = 0
                
                -- Update orb exactly at 30 seconds
                testOrb:update(30.0)
                
                -- Property: orb should despawn exactly at 30 seconds
                assert.is_false(testOrb.isActive,
                    "XP Orb should despawn exactly at 30 seconds")
                
                -- Cleanup
                testOrb:destroy()
            end
        end)
    end)
end)
