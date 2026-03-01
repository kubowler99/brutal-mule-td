require("tests.spec_helper")
local spawner_system = require("src.systems.spawner_system")
local Walker = require("src.entities.walker")
local pool = require("src.utils.pool")

describe("Spawner System", function()
    local walkerPool

    before_each(function()
        -- Create walker pool
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

    describe("initialization", function()
        it("should initialize with default spawn interval of 3.0 seconds", function()
            assert.are.equal(3.0, spawner_system.spawnInterval)
        end)

        it("should initialize with spawn count of 1", function()
            assert.are.equal(1, spawner_system.spawnCount)
        end)

        it("should initialize with maximum concurrent limit of 50", function()
            assert.are.equal(50, spawner_system.maxConcurrent)
        end)

        it("should initialize with empty active walkers array", function()
            assert.are.equal(0, #spawner_system.activeWalkers)
        end)

        it("should initialize with spawn timer at 0", function()
            assert.are.equal(0, spawner_system.spawnTimer)
        end)

        it("should initialize with hero level", function()
            spawner_system.initialize(walkerPool, 5)
            assert.are.equal(5, spawner_system.heroLevel)
        end)

        it("should set difficulty based on initial hero level", function()
            spawner_system.initialize(walkerPool, 7)
            assert.are.equal(3.0, spawner_system.spawnInterval)
            assert.are.equal(2, spawner_system.spawnCount)
        end)
    end)

    -- **Validates: Requirements 3.1, 3.3, 3.9**
    -- Test spawn timer accumulation
    describe("spawn timer accumulation", function()
        it("should accumulate spawn timer with dt", function()
            spawner_system.hasSpawnedInitial = true
            spawner_system.update(1.0, 3.0)
            assert.are.equal(1.0, spawner_system.spawnTimer)
        end)

        it("should accumulate spawn timer over multiple updates", function()
            spawner_system.hasSpawnedInitial = true
            spawner_system.update(0.5, 3.0)
            spawner_system.update(0.5, 3.5)
            spawner_system.update(0.5, 4.0)
            assert.are.equal(1.5, spawner_system.spawnTimer)
        end)

        it("should reset spawn timer after spawning", function()
            spawner_system.hasSpawnedInitial = true
            spawner_system.update(3.0, 5.0)
            assert.is_true(spawner_system.spawnTimer < 3.0)
        end)

        it("should spawn walker when timer reaches interval", function()
            spawner_system.hasSpawnedInitial = true
            spawner_system.update(3.0, 5.0)
            assert.are.equal(1, #spawner_system.activeWalkers)
        end)

        it("should spawn multiple times if dt exceeds interval", function()
            spawner_system.hasSpawnedInitial = true
            spawner_system.update(6.5, 10.0)
            -- Should spawn twice (at 3s and 6s)
            assert.are.equal(2, #spawner_system.activeWalkers)
        end)
    end)

    -- **Validates: Requirements 3.1, 3.3, 3.9**
    -- Test walker activation with correct lane
    describe("walker activation with correct lane", function()
        it("should activate walker with spawn position", function()
            spawner_system.spawnWalker()
            assert.are.equal(1, #spawner_system.activeWalkers)
            
            local walker = spawner_system.activeWalkers[1]
            assert.is_true(walker.isActive)
        end)

        it("should spawn walker at top edge (y = 0)", function()
            spawner_system.spawnWalker()
            local walker = spawner_system.activeWalkers[1]
            assert.are.equal(0, walker.y)
        end)

        it("should spawn walker within playable bounds (x: 50-670)", function()
            for i = 1, 20 do
                spawner_system.spawnWalker()
                local walker = spawner_system.activeWalkers[i]
                assert.is_true(walker.x >= 50 and walker.x <= 670)
            end
        end)

        it("should assign lane equal to spawn X coordinate", function()
            spawner_system.spawnWalker()
            local walker = spawner_system.activeWalkers[1]
            assert.are.equal(walker.x, walker.lane)
        end)

        it("should add walker to active walkers array", function()
            local initialCount = #spawner_system.activeWalkers
            spawner_system.spawnWalker()
            assert.are.equal(initialCount + 1, #spawner_system.activeWalkers)
        end)
    end)

    -- **Validates: Requirements 3.9**
    -- Test maximum concurrent limit enforcement
    describe("maximum concurrent limit enforcement", function()
        it("should not spawn walker when at maximum limit", function()
            -- Fill to maximum
            for i = 1, 50 do
                spawner_system.spawnWalker()
            end
            
            assert.are.equal(50, #spawner_system.activeWalkers)
            
            -- Try to spawn one more
            spawner_system.spawnWalker()
            
            -- Should still be 50
            assert.are.equal(50, #spawner_system.activeWalkers)
        end)

        it("should allow spawning after walkers are deactivated", function()
            spawner_system.hasSpawnedInitial = true  -- Skip initial spawn logic
            
            -- Fill to maximum
            for i = 1, 50 do
                spawner_system.spawnWalker()
            end
            
            -- Deactivate some walkers
            for i = 1, 10 do
                spawner_system.activeWalkers[i]:deactivate()
            end
            
            -- Update to clean up inactive walkers
            spawner_system.update(0, 0)
            
            assert.are.equal(40, #spawner_system.activeWalkers)
            
            -- Should be able to spawn again
            spawner_system.spawnWalker()
            assert.are.equal(41, #spawner_system.activeWalkers)
        end)

        it("should respect limit during regular update spawning", function()
            -- Fill to 49
            for i = 1, 49 do
                spawner_system.spawnWalker()
            end
            
            spawner_system.hasSpawnedInitial = true
            spawner_system.spawnCount = 5
            
            -- Try to spawn 5 more (should only spawn 1)
            spawner_system.update(3.0, 5.0)
            
            assert.are.equal(50, #spawner_system.activeWalkers)
        end)
    end)

    -- **Validates: Requirements 3.3, 3.4, 3.5, 3.6**
    -- Test difficulty scaling at different levels
    describe("difficulty scaling at different levels", function()
        it("should use 1 walker every 3s for level < 5", function()
            spawner_system.updateDifficulty(1)
            assert.are.equal(3.0, spawner_system.spawnInterval)
            assert.are.equal(1, spawner_system.spawnCount)
            
            spawner_system.updateDifficulty(4)
            assert.are.equal(3.0, spawner_system.spawnInterval)
            assert.are.equal(1, spawner_system.spawnCount)
        end)

        it("should use 2 walkers every 3s for level 5-9", function()
            spawner_system.updateDifficulty(5)
            assert.are.equal(3.0, spawner_system.spawnInterval)
            assert.are.equal(2, spawner_system.spawnCount)
            
            spawner_system.updateDifficulty(9)
            assert.are.equal(3.0, spawner_system.spawnInterval)
            assert.are.equal(2, spawner_system.spawnCount)
        end)

        it("should use 3 walkers every 2s for level 10-14", function()
            spawner_system.updateDifficulty(10)
            assert.are.equal(2.0, spawner_system.spawnInterval)
            assert.are.equal(3, spawner_system.spawnCount)
            
            spawner_system.updateDifficulty(14)
            assert.are.equal(2.0, spawner_system.spawnInterval)
            assert.are.equal(3, spawner_system.spawnCount)
        end)

        it("should use 4 walkers every 2s for level 15+", function()
            spawner_system.updateDifficulty(15)
            assert.are.equal(2.0, spawner_system.spawnInterval)
            assert.are.equal(4, spawner_system.spawnCount)
            
            spawner_system.updateDifficulty(20)
            assert.are.equal(2.0, spawner_system.spawnInterval)
            assert.are.equal(4, spawner_system.spawnCount)
        end)

        it("should spawn correct count based on difficulty", function()
            spawner_system.hasSpawnedInitial = true
            
            -- Level 5-9: spawn 2 walkers
            spawner_system.updateDifficulty(7)
            spawner_system.update(3.0, 5.0)
            assert.are.equal(2, #spawner_system.activeWalkers)
        end)
    end)

    describe("initial spawn burst", function()
        it("should spawn 3 walkers within 2 seconds of game start", function()
            local currentTime = 0
            
            -- First update at t=0
            spawner_system.update(0, currentTime)
            assert.are.equal(1, #spawner_system.activeWalkers)
            
            -- Update at t=0.7
            currentTime = 0.7
            spawner_system.update(0.7, currentTime)
            assert.are.equal(2, #spawner_system.activeWalkers)
            
            -- Update at t=1.4
            currentTime = 1.4
            spawner_system.update(0.7, currentTime)
            assert.are.equal(3, #spawner_system.activeWalkers)
        end)

        it("should transition to regular spawning after 2 seconds", function()
            -- Complete initial burst
            spawner_system.update(0, 0)
            spawner_system.update(0.7, 0.7)
            spawner_system.update(0.7, 1.4)
            spawner_system.update(0.7, 2.1)
            
            assert.is_true(spawner_system.hasSpawnedInitial)
        end)
    end)

    describe("getActiveWalkers", function()
        it("should return active walkers array", function()
            spawner_system.spawnWalker()
            spawner_system.spawnWalker()
            
            local walkers = spawner_system.getActiveWalkers()
            assert.are.equal(2, #walkers)
        end)

        it("should return reference to actual array", function()
            local walkers = spawner_system.getActiveWalkers()
            assert.are.equal(spawner_system.activeWalkers, walkers)
        end)
    end)

    describe("cleanup", function()
        it("should deactivate all active walkers", function()
            spawner_system.spawnWalker()
            spawner_system.spawnWalker()
            spawner_system.spawnWalker()
            
            spawner_system.cleanup()
            
            assert.are.equal(0, #spawner_system.activeWalkers)
        end)

        it("should reset spawn timer", function()
            spawner_system.spawnTimer = 2.5
            spawner_system.cleanup()
            assert.are.equal(0, spawner_system.spawnTimer)
        end)

        it("should reset hasSpawnedInitial flag", function()
            spawner_system.hasSpawnedInitial = true
            spawner_system.cleanup()
            assert.is_false(spawner_system.hasSpawnedInitial)
        end)
    end)

    describe("update removes inactive walkers", function()
        it("should remove deactivated walkers from active array", function()
            spawner_system.hasSpawnedInitial = true  -- Skip initial spawn logic
            spawner_system.spawnWalker()
            spawner_system.spawnWalker()
            spawner_system.spawnWalker()
            
            -- Deactivate middle walker
            spawner_system.activeWalkers[2]:deactivate()
            
            spawner_system.update(0, 0)
            
            assert.are.equal(2, #spawner_system.activeWalkers)
        end)

        it("should keep active walkers in array", function()
            spawner_system.hasSpawnedInitial = true  -- Skip initial spawn logic
            spawner_system.spawnWalker()
            local walker = spawner_system.activeWalkers[1]
            
            spawner_system.update(0, 0)
            
            assert.are.equal(1, #spawner_system.activeWalkers)
            assert.are.equal(walker, spawner_system.activeWalkers[1])
        end)
    end)
end)

    -- **Validates: Requirements 3.3, 3.4, 3.5, 3.6**
    -- Property 7: Spawn Rate Scaling
    describe("Property 7: Spawn Rate Scaling", function()
        local generators = require("tests.generators.game_generators")

        it("should adjust spawn rate and count based on hero level for any level", function()
            -- Run property test with 100 iterations
            for _ = 1, 100 do
                local level = generators.heroLevel()()
                
                -- Create fresh spawner for each test
                local testPool = pool.new(
                    function() return Walker:new() end,
                    function(walker, x, y, lane) walker:activate(x, y, lane) end
                )
                spawner_system.initialize(testPool, level)
                
                -- Determine expected values based on level
                local expectedInterval, expectedCount
                if level < 5 then
                    expectedInterval, expectedCount = 3.0, 1
                elseif level < 10 then
                    expectedInterval, expectedCount = 3.0, 2
                elseif level < 15 then
                    expectedInterval, expectedCount = 2.0, 3
                else
                    expectedInterval, expectedCount = 2.0, 4
                end
                
                -- Property: spawn interval and count should match difficulty curve
                assert.are.equal(expectedInterval, spawner_system.spawnInterval)
                assert.are.equal(expectedCount, spawner_system.spawnCount)
                
                -- Cleanup
                spawner_system.cleanup()
            end
        end)
    end)

    -- **Validates: Requirements 3.9, 12.2**
    -- Property 8: Maximum Concurrent Enemies
    describe("Property 8: Maximum Concurrent Enemies", function()
        local generators = require("tests.generators.game_generators")

        it("should never exceed 50 active walkers at any point in time", function()
            -- Run property test with 100 iterations
            for _ = 1, 100 do
                -- Create fresh spawner for each test
                local testPool = pool.new(
                    function() return Walker:new() end,
                    function(walker, x, y, lane) walker:activate(x, y, lane) end
                )
                spawner_system.initialize(testPool, 1)
                spawner_system.hasSpawnedInitial = true  -- Skip initial spawn logic
                
                -- Generate random number of spawn attempts (50-100)
                local spawnAttempts = math.random(50, 100)
                
                -- Try to spawn many walkers
                for i = 1, spawnAttempts do
                    spawner_system.spawnWalker()
                    
                    -- Property: active walkers should never exceed 50
                    assert.is_true(#spawner_system.activeWalkers <= 50)
                end
                
                -- Final check
                assert.is_true(#spawner_system.activeWalkers <= 50)
                
                -- Cleanup
                spawner_system.cleanup()
            end
        end)

        it("should enforce limit during update spawning for any spawn count", function()
            -- Run property test with 100 iterations
            for _ = 1, 100 do
                -- Create fresh spawner for each test
                local testPool = pool.new(
                    function() return Walker:new() end,
                    function(walker, x, y, lane) walker:activate(x, y, lane) end
                )
                
                -- Random level to get different spawn counts
                local level = generators.heroLevel()()
                spawner_system.initialize(testPool, level)
                spawner_system.hasSpawnedInitial = true
                
                -- Fill to near maximum (45-49)
                local fillCount = math.random(45, 49)
                for i = 1, fillCount do
                    spawner_system.spawnWalker()
                end
                
                -- Trigger spawn via update
                spawner_system.update(spawner_system.spawnInterval, 10.0)
                
                -- Property: should not exceed 50 even after update spawn
                assert.is_true(#spawner_system.activeWalkers <= 50)
                
                -- Cleanup
                spawner_system.cleanup()
            end
        end)
    end)

    -- **Validates: Requirements 3.7**
    -- Property 9: Walker Spawn Position
    describe("Property 9: Walker Spawn Position", function()
        it("should spawn walkers at top edge (y ≈ 0) within playable bounds (x: 50-670) for any spawn", function()
            -- Run property test with 100 iterations
            for _ = 1, 100 do
                -- Create fresh spawner for each test
                local testPool = pool.new(
                    function() return Walker:new() end,
                    function(walker, x, y, lane) walker:activate(x, y, lane) end
                )
                spawner_system.initialize(testPool, 1)
                spawner_system.hasSpawnedInitial = true  -- Skip initial spawn logic
                
                -- Spawn multiple walkers to test randomness
                local spawnCount = math.random(5, 20)
                for i = 1, spawnCount do
                    spawner_system.spawnWalker()
                    
                    local walker = spawner_system.activeWalkers[#spawner_system.activeWalkers]
                    
                    -- Property 1: Y coordinate should be at top edge (y = 0)
                    assert.are.equal(0, walker.y)
                    
                    -- Property 2: X coordinate should be within playable bounds
                    assert.is_true(walker.x >= 50 and walker.x <= 670)
                end
                
                -- Cleanup
                spawner_system.cleanup()
            end
        end)
    end)
