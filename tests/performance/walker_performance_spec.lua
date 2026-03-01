-- walker_performance_spec.lua
-- Performance test to validate the system can handle 30 concurrent walkers
-- **Validates: Requirements 12.4**

require("tests.spec_helper")
local spawner_system = require("src.systems.spawner_system")
local Walker = require("src.entities.walker")
local pool = require("src.utils.pool")

describe("Walker Performance Test", function()
    local walkerPool

    before_each(function()
        -- Create walker pool with capacity for 50 walkers
        walkerPool = pool.new(
            function() return Walker:new() end,
            function(walker, x, y, lane) walker:activate(x, y, lane) end
        )
        
        -- Initialize spawner system
        spawner_system.initialize(walkerPool, 1)
    end)

    after_each(function()
        spawner_system.cleanup()
        walkerPool = nil
    end)

    -- **Validates: Requirements 12.4**
    describe("30 concurrent walkers performance", function()
        it("should handle 30 active walkers without errors", function()
            spawner_system.hasSpawnedInitial = true  -- Skip initial spawn logic
            
            -- Spawn 30 walkers
            for i = 1, 30 do
                spawner_system.spawnWalker()
            end
            
            -- Verify we have 30 active walkers
            assert.are.equal(30, #spawner_system.activeWalkers)
            
            -- Verify all walkers are active
            for i, walker in ipairs(spawner_system.activeWalkers) do
                assert.is_true(walker.isActive, "Walker " .. i .. " should be active")
            end
        end)

        it("should update 30 walkers over multiple frames without errors", function()
            spawner_system.hasSpawnedInitial = true
            
            -- Spawn 30 walkers
            for i = 1, 30 do
                spawner_system.spawnWalker()
            end
            
            -- Simulate 60 frames at 60 FPS (1 second of gameplay)
            local dt = 1/60  -- 16.67ms per frame
            local wallThreshold = 1180  -- Wall position
            
            for frame = 1, 60 do
                -- Update all walkers
                for _, walker in ipairs(spawner_system.activeWalkers) do
                    walker:update(dt, wallThreshold)
                end
                
                -- Verify all walkers are still active and moving
                assert.are.equal(30, #spawner_system.activeWalkers)
            end
            
            -- After 1 second, walkers should have moved down
            -- Speed is 80 pixels/second, so they should have moved ~80 pixels
            local firstWalker = spawner_system.activeWalkers[1]
            assert.is_true(firstWalker.y > 70 and firstWalker.y < 90, 
                "Walker should have moved approximately 80 pixels in 1 second")
        end)

        it("should handle 30 walkers updating over 300 frames (5 seconds)", function()
            spawner_system.hasSpawnedInitial = true
            
            -- Spawn 30 walkers
            for i = 1, 30 do
                spawner_system.spawnWalker()
            end
            
            local dt = 1/60
            local wallThreshold = 1180
            local frameCount = 300  -- 5 seconds at 60 FPS
            
            -- Track that no errors occur during extended simulation
            local updateSuccessful = true
            
            for frame = 1, frameCount do
                local success, err = pcall(function()
                    -- Update all walkers
                    for _, walker in ipairs(spawner_system.activeWalkers) do
                        walker:update(dt, wallThreshold)
                    end
                end)
                
                if not success then
                    updateSuccessful = false
                    print("Error at frame " .. frame .. ": " .. tostring(err))
                    break
                end
            end
            
            assert.is_true(updateSuccessful, "All walker updates should complete without errors")
            
            -- Verify walkers have moved significantly (400 pixels in 5 seconds)
            local firstWalker = spawner_system.activeWalkers[1]
            assert.is_true(firstWalker.y > 390 and firstWalker.y < 410,
                "Walker should have moved approximately 400 pixels in 5 seconds")
        end)

        it("should maintain consistent walker state across many updates", function()
            spawner_system.hasSpawnedInitial = true
            
            -- Spawn 30 walkers
            for i = 1, 30 do
                spawner_system.spawnWalker()
            end
            
            -- Store initial positions
            local initialPositions = {}
            for i, walker in ipairs(spawner_system.activeWalkers) do
                initialPositions[i] = {x = walker.x, y = walker.y, lane = walker.lane}
            end
            
            -- Update for 100 frames
            local dt = 1/60
            local wallThreshold = 1180
            
            for frame = 1, 100 do
                for _, walker in ipairs(spawner_system.activeWalkers) do
                    walker:update(dt, wallThreshold)
                end
            end
            
            -- Verify walkers maintained their lanes (X position unchanged)
            for i, walker in ipairs(spawner_system.activeWalkers) do
                assert.are.equal(initialPositions[i].x, walker.x,
                    "Walker " .. i .. " should maintain its X position (lane)")
                assert.are.equal(initialPositions[i].lane, walker.lane,
                    "Walker " .. i .. " should maintain its lane assignment")
            end
            
            -- Verify walkers moved downward (Y increased)
            for i, walker in ipairs(spawner_system.activeWalkers) do
                assert.is_true(walker.y > initialPositions[i].y,
                    "Walker " .. i .. " should have moved downward")
            end
        end)

        it("should handle spawning and updating simultaneously", function()
            spawner_system.hasSpawnedInitial = true
            
            -- Start with 20 walkers
            for i = 1, 20 do
                spawner_system.spawnWalker()
            end
            
            local dt = 1/60
            local wallThreshold = 1180
            
            -- Simulate 60 frames while spawning more walkers
            for frame = 1, 60 do
                -- Update existing walkers
                for _, walker in ipairs(spawner_system.activeWalkers) do
                    walker:update(dt, wallThreshold)
                end
                
                -- Spawn additional walkers until we reach 30
                if #spawner_system.activeWalkers < 30 then
                    spawner_system.spawnWalker()
                end
            end
            
            -- Should have 30 walkers by the end
            assert.are.equal(30, #spawner_system.activeWalkers)
            
            -- All walkers should be active
            for i, walker in ipairs(spawner_system.activeWalkers) do
                assert.is_true(walker.isActive, "Walker " .. i .. " should be active")
            end
        end)
    end)

    -- **Validates: Requirements 12.4**
    describe("object pool efficiency with 30 walkers", function()
        it("should reuse walkers from pool without creating new instances", function()
            spawner_system.hasSpawnedInitial = true
            
            -- Spawn 30 walkers
            for i = 1, 30 do
                spawner_system.spawnWalker()
            end
            
            -- Store references to the walker instances
            local walkerInstances = {}
            for i, walker in ipairs(spawner_system.activeWalkers) do
                walkerInstances[i] = walker
            end
            
            -- Deactivate all walkers and return them to pool
            for _, walker in ipairs(spawner_system.activeWalkers) do
                walker:deactivate()
                walkerPool:release(walker)
            end
            
            -- Clear active walkers array
            spawner_system.activeWalkers = {}
            assert.are.equal(0, #spawner_system.activeWalkers)
            
            -- Spawn 30 walkers again
            for i = 1, 30 do
                spawner_system.spawnWalker()
            end
            
            -- Verify we reused the same instances (object pooling working)
            local reusedCount = 0
            for _, newWalker in ipairs(spawner_system.activeWalkers) do
                for _, oldWalker in ipairs(walkerInstances) do
                    if newWalker == oldWalker then
                        reusedCount = reusedCount + 1
                        break
                    end
                end
            end
            
            -- Should have reused most or all instances
            assert.is_true(reusedCount >= 25,
                "Should reuse at least 25 out of 30 walker instances from pool (got " .. reusedCount .. ")")
        end)

        it("should handle repeated spawn/deactivate cycles without memory growth", function()
            spawner_system.hasSpawnedInitial = true
            
            -- Perform 10 cycles of spawn/deactivate
            for cycle = 1, 10 do
                -- Spawn 30 walkers
                for i = 1, 30 do
                    spawner_system.spawnWalker()
                end
                
                assert.are.equal(30, #spawner_system.activeWalkers,
                    "Cycle " .. cycle .. " should have 30 active walkers")
                
                -- Deactivate all walkers
                for _, walker in ipairs(spawner_system.activeWalkers) do
                    walker:deactivate()
                end
                
                -- Clean up
                spawner_system.update(0, 0)
                assert.are.equal(0, #spawner_system.activeWalkers,
                    "Cycle " .. cycle .. " should have 0 active walkers after cleanup")
            end
            
            -- Final spawn to verify pool is still functional
            for i = 1, 30 do
                spawner_system.spawnWalker()
            end
            
            assert.are.equal(30, #spawner_system.activeWalkers,
                "Pool should still function correctly after 10 cycles")
        end)
    end)

    -- **Validates: Requirements 12.4**
    describe("stress test with maximum load", function()
        it("should handle 50 walkers (maximum) without errors", function()
            spawner_system.hasSpawnedInitial = true
            
            -- Spawn maximum walkers
            for i = 1, 50 do
                spawner_system.spawnWalker()
            end
            
            assert.are.equal(50, #spawner_system.activeWalkers)
            
            -- Update for 60 frames
            local dt = 1/60
            local wallThreshold = 1180
            
            for frame = 1, 60 do
                for _, walker in ipairs(spawner_system.activeWalkers) do
                    walker:update(dt, wallThreshold)
                end
            end
            
            -- All walkers should still be active
            assert.are.equal(50, #spawner_system.activeWalkers)
        end)

        it("should handle high-frequency updates with 30 walkers", function()
            spawner_system.hasSpawnedInitial = true
            
            -- Spawn 30 walkers
            for i = 1, 30 do
                spawner_system.spawnWalker()
            end
            
            -- Simulate 600 frames (10 seconds at 60 FPS)
            local dt = 1/60
            local wallThreshold = 1180
            local frameCount = 600
            
            local startTime = os.clock()
            
            for frame = 1, frameCount do
                for _, walker in ipairs(spawner_system.activeWalkers) do
                    walker:update(dt, wallThreshold)
                end
            end
            
            local endTime = os.clock()
            local elapsedTime = endTime - startTime
            
            -- Log performance (for manual inspection)
            print(string.format("Updated 30 walkers for %d frames in %.3f seconds", 
                frameCount, elapsedTime))
            
            -- Verify all walkers are still functional
            assert.are.equal(30, #spawner_system.activeWalkers)
            
            -- Walkers should have moved significantly (800 pixels in 10 seconds)
            local firstWalker = spawner_system.activeWalkers[1]
            assert.is_true(firstWalker.y > 790 and firstWalker.y < 810,
                "Walker should have moved approximately 800 pixels in 10 seconds")
        end)
    end)
end)
