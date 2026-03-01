-- tests/systems/spawner_system_error_handling_spec.lua
-- Tests for spawner system error handling

require("tests.spec_helper")

describe("Spawner System Error Handling", function()
    local spawner_system
    local Walker
    local pool
    
    before_each(function()
        -- Reset modules
        package.loaded["src.systems.spawner_system"] = nil
        package.loaded["src.entities.walker"] = nil
        package.loaded["src.utils.pool"] = nil
        
        spawner_system = require("src.systems.spawner_system")
        Walker = require("src.entities.walker")
        pool = require("src.utils.pool")
    end)
    
    after_each(function()
        if spawner_system then
            spawner_system.cleanup()
        end
    end)
    
    -- Helper function to create a walker pool
    local function createWalkerPool()
        return pool.new(
            function() return Walker:new() end,
            function(walker, x, y, lane) walker:activate(x, y, lane) end
        )
    end
    
    describe("initialize", function()
        it("should return false when walkerPool is nil", function()
            local result = spawner_system.initialize(nil, 1)
            assert.is_false(result)
        end)
        
        it("should return false when walkerPool missing get method", function()
            local badPool = { release = function() end }
            local result = spawner_system.initialize(badPool, 1)
            assert.is_false(result)
        end)
        
        it("should return false when walkerPool missing release method", function()
            local badPool = { get = function() end }
            local result = spawner_system.initialize(badPool, 1)
            assert.is_false(result)
        end)
        
        it("should handle invalid heroLevel gracefully", function()
            local walkerPool = createWalkerPool()
            local result = spawner_system.initialize(walkerPool, "invalid")
            assert.is_true(result)
            assert.equals(1, spawner_system.heroLevel)
        end)
        
        it("should clamp negative heroLevel to 1", function()
            local walkerPool = createWalkerPool()
            local result = spawner_system.initialize(walkerPool, -5)
            assert.is_true(result)
            assert.equals(1, spawner_system.heroLevel)
        end)
        
        it("should floor decimal heroLevel", function()
            local walkerPool = createWalkerPool()
            local result = spawner_system.initialize(walkerPool, 3.7)
            assert.is_true(result)
            assert.equals(3, spawner_system.heroLevel)
        end)
    end)
    
    describe("update", function()
        it("should handle invalid dt gracefully", function()
            local walkerPool = createWalkerPool()
            spawner_system.initialize(walkerPool, 1)
            
            -- Should not crash with invalid dt
            spawner_system.update("invalid", 1.0)
            spawner_system.update(-1, 1.0)
            spawner_system.update(nil, 1.0)
        end)
        
        it("should handle invalid currentTime gracefully", function()
            local walkerPool = createWalkerPool()
            spawner_system.initialize(walkerPool, 1)
            
            -- Should not crash with invalid currentTime
            spawner_system.update(0.016, "invalid")
            spawner_system.update(0.016, -1)
            spawner_system.update(0.016, nil)
        end)
        
        it("should remove invalid walkers from activeWalkers", function()
            local walkerPool = createWalkerPool()
            spawner_system.initialize(walkerPool, 1)
            
            -- Force past initial spawn phase by updating with time > 2 seconds
            spawner_system.update(0.016, 0.0)  -- Start game time
            spawner_system.update(2.5, 2.5)    -- Move past initial spawn phase
            
            -- Now manually inject invalid walkers
            table.insert(spawner_system.activeWalkers, nil)
            table.insert(spawner_system.activeWalkers, {})  -- Missing isActive property
            
            -- Update should clean them up
            spawner_system.update(0.016, 2.516)
            
            -- All invalid walkers should be removed (only valid spawned walkers remain)
            for _, walker in ipairs(spawner_system.activeWalkers) do
                assert.is_not_nil(walker)
                assert.is_not_nil(walker.isActive)
            end
        end)
    end)
    
    describe("spawnWalker", function()
        it("should enforce maximum concurrent limit", function()
            local walkerPool = createWalkerPool()
            spawner_system.initialize(walkerPool, 1)
            
            -- Spawn 50 walkers (the limit)
            for i = 1, 50 do
                spawner_system.spawnWalker()
            end
            
            assert.equals(50, #spawner_system.activeWalkers)
            
            -- Try to spawn one more - should be blocked
            spawner_system.spawnWalker()
            assert.equals(50, #spawner_system.activeWalkers)
        end)
        
        it("should handle nil walker pool gracefully", function()
            local walkerPool = createWalkerPool()
            spawner_system.initialize(walkerPool, 1)
            
            -- Manually set pool to nil
            spawner_system.walkerPool = nil
            
            -- Should not crash
            spawner_system.spawnWalker()
            assert.equals(0, #spawner_system.activeWalkers)
        end)
        
        it("should handle pool exhaustion gracefully", function()
            -- Create a mock pool that returns nil
            local mockPool = {
                get = function() return nil end,
                release = function() end
            }
            
            spawner_system.initialize(mockPool, 1)
            
            -- Should not crash when pool is exhausted
            spawner_system.spawnWalker()
            assert.equals(0, #spawner_system.activeWalkers)
        end)
        
        it("should clamp spawn X position to valid range", function()
            local walkerPool = createWalkerPool()
            spawner_system.initialize(walkerPool, 1)
            
            -- Spawn a walker
            spawner_system.spawnWalker()
            
            -- Check that spawn position is within valid range
            if #spawner_system.activeWalkers > 0 then
                local walker = spawner_system.activeWalkers[1]
                assert.is_true(walker.x >= 50)
                assert.is_true(walker.x <= 670)
            end
        end)
        
        it("should handle walker missing activate method", function()
            -- Create a mock pool that returns invalid walker
            local mockPool = {
                get = function() return {} end,  -- No activate method
                release = function() end
            }
            
            spawner_system.initialize(mockPool, 1)
            
            -- Should not crash
            spawner_system.spawnWalker()
            assert.equals(0, #spawner_system.activeWalkers)
        end)
        
        it("should handle walker activation failure", function()
            -- Create a mock pool with walker that throws error on activate
            local mockWalker = {
                activate = function() error("Activation failed") end
            }
            local mockPool = {
                get = function() return mockWalker end,
                release = function() end
            }
            
            spawner_system.initialize(mockPool, 1)
            
            -- Should not crash
            spawner_system.spawnWalker()
            assert.equals(0, #spawner_system.activeWalkers)
        end)
    end)
    
    describe("updateDifficulty", function()
        it("should handle invalid heroLevel gracefully", function()
            local walkerPool = createWalkerPool()
            spawner_system.initialize(walkerPool, 1)
            
            -- Should not crash with invalid heroLevel
            spawner_system.updateDifficulty("invalid")
            spawner_system.updateDifficulty(nil)
            spawner_system.updateDifficulty({})
        end)
        
        it("should clamp negative heroLevel", function()
            local walkerPool = createWalkerPool()
            spawner_system.initialize(walkerPool, 5)
            
            spawner_system.updateDifficulty(-10)
            assert.equals(1, spawner_system.heroLevel)
        end)
        
        it("should floor decimal heroLevel", function()
            local walkerPool = createWalkerPool()
            spawner_system.initialize(walkerPool, 1)
            
            spawner_system.updateDifficulty(7.9)
            assert.equals(7, spawner_system.heroLevel)
        end)
    end)
    
    describe("cleanup", function()
        it("should handle walker deactivation failure gracefully", function()
            local walkerPool = createWalkerPool()
            spawner_system.initialize(walkerPool, 1)
            
            -- Create a mock walker that throws error on deactivate
            local mockWalker = {
                isActive = true,
                deactivate = function() error("Deactivation failed") end
            }
            table.insert(spawner_system.activeWalkers, mockWalker)
            
            -- Should not crash
            spawner_system.cleanup()
        end)
        
        it("should handle walker release failure gracefully", function()
            local walkerPool = createWalkerPool()
            spawner_system.initialize(walkerPool, 1)
            
            -- Spawn a walker
            spawner_system.spawnWalker()
            
            -- Replace pool with one that throws error on release
            spawner_system.walkerPool = {
                release = function() error("Release failed") end
            }
            
            -- Should not crash
            spawner_system.cleanup()
        end)
        
        it("should handle nil walkers in activeWalkers", function()
            local walkerPool = createWalkerPool()
            spawner_system.initialize(walkerPool, 1)
            
            -- Manually inject nil walker
            table.insert(spawner_system.activeWalkers, nil)
            
            -- Should not crash
            spawner_system.cleanup()
        end)
    end)
end)
