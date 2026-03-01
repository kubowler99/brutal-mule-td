--- Unit tests for game_state module
-- Tests initial state, pause/resume, endGame, and getStatistics

require("tests.spec_helper")
local game_state = require("src.models.game_state")
local property = require("lqc.property")
local lqc = require("lqc.quickcheck")
local lqc_gen = require("lqc.lqc_gen")

describe("Game State Model", function()
    before_each(function()
        -- Reset game state before each test
        game_state.initialize()
    end)

    describe("initialize", function()
        it("sets initial state to playing", function()
            assert.are.equal("playing", game_state.state)
        end)

        it("sets startTime to current time", function()
            assert.is_not_nil(game_state.startTime)
            assert.is_number(game_state.startTime)
        end)

        it("sets elapsedTime to 0", function()
            assert.are.equal(0, game_state.elapsedTime)
        end)

        it("sets enemiesDefeated to 0", function()
            assert.are.equal(0, game_state.enemiesDefeated)
        end)

        it("sets finalLevel to 0", function()
            assert.are.equal(0, game_state.finalLevel)
        end)

        it("sets victoryCondition to false", function()
            assert.is_false(game_state.victoryCondition)
        end)
    end)

    describe("pause", function()
        it("changes state to paused", function()
            game_state.pause()
            assert.are.equal("paused", game_state.state)
        end)

        it("can be called multiple times", function()
            game_state.pause()
            game_state.pause()
            assert.are.equal("paused", game_state.state)
        end)
    end)

    describe("resume", function()
        it("changes state back to playing", function()
            game_state.pause()
            game_state.resume()
            assert.are.equal("playing", game_state.state)
        end)

        it("can be called when already playing", function()
            game_state.resume()
            assert.are.equal("playing", game_state.state)
        end)
    end)

    describe("update", function()
        it("increases elapsedTime when state is playing", function()
            game_state.elapsedTime = 0
            game_state.update(1.0)
            assert.are.equal(1.0, game_state.elapsedTime)
        end)

        it("accumulates elapsed time over multiple updates", function()
            game_state.elapsedTime = 0
            game_state.update(0.5)
            game_state.update(0.3)
            game_state.update(0.2)
            assert.are.equal(1.0, game_state.elapsedTime)
        end)

        it("does not increase elapsedTime when paused", function()
            game_state.pause()
            game_state.elapsedTime = 5.0
            game_state.update(1.0)
            assert.are.equal(5.0, game_state.elapsedTime)
        end)

        it("does not increase elapsedTime when game is over", function()
            game_state.endGame(false)
            game_state.elapsedTime = 10.0
            game_state.update(1.0)
            assert.are.equal(10.0, game_state.elapsedTime)
        end)

        it("resumes time tracking after unpause", function()
            game_state.elapsedTime = 5.0
            game_state.pause()
            game_state.update(1.0)  -- Should not increase
            game_state.resume()
            game_state.update(2.0)  -- Should increase
            assert.are.equal(7.0, game_state.elapsedTime)
        end)
    end)

    describe("endGame", function()
        it("sets state to game_over", function()
            game_state.endGame(false)
            assert.are.equal("game_over", game_state.state)
        end)

        it("sets victoryCondition to true when victory is true", function()
            game_state.endGame(true)
            assert.is_true(game_state.victoryCondition)
        end)

        it("sets victoryCondition to false when victory is false", function()
            game_state.endGame(false)
            assert.is_false(game_state.victoryCondition)
        end)

        it("preserves other statistics", function()
            game_state.elapsedTime = 120
            game_state.enemiesDefeated = 50
            game_state.finalLevel = 10
            
            game_state.endGame(true)
            
            assert.are.equal(120, game_state.elapsedTime)
            assert.are.equal(50, game_state.enemiesDefeated)
            assert.are.equal(10, game_state.finalLevel)
        end)
    end)

    describe("getStatistics", function()
        it("returns a table with all statistics", function()
            local stats = game_state.getStatistics()
            
            assert.is_not_nil(stats)
            assert.is_not_nil(stats.survivalTime)
            assert.is_not_nil(stats.enemiesDefeated)
            assert.is_not_nil(stats.finalLevel)
            assert.is_not_nil(stats.victoryCondition)
        end)

        it("returns correct values after initialization", function()
            local stats = game_state.getStatistics()
            
            assert.are.equal(0, stats.survivalTime)
            assert.are.equal(0, stats.enemiesDefeated)
            assert.are.equal(0, stats.finalLevel)
            assert.is_false(stats.victoryCondition)
        end)

        it("returns correct values after game progression", function()
            game_state.elapsedTime = 300
            game_state.enemiesDefeated = 75
            game_state.finalLevel = 15
            game_state.endGame(true)
            
            local stats = game_state.getStatistics()
            
            assert.are.equal(300, stats.survivalTime)
            assert.are.equal(75, stats.enemiesDefeated)
            assert.are.equal(15, stats.finalLevel)
            assert.is_true(stats.victoryCondition)
        end)
    end)

    describe("state transitions", function()
        it("supports playing -> paused -> playing cycle", function()
            assert.are.equal("playing", game_state.state)
            
            game_state.pause()
            assert.are.equal("paused", game_state.state)
            
            game_state.resume()
            assert.are.equal("playing", game_state.state)
        end)

        it("supports playing -> game_over transition", function()
            assert.are.equal("playing", game_state.state)
            
            game_state.endGame(false)
            assert.are.equal("game_over", game_state.state)
        end)

        it("supports paused -> game_over transition", function()
            game_state.pause()
            assert.are.equal("paused", game_state.state)
            
            game_state.endGame(true)
            assert.are.equal("game_over", game_state.state)
        end)
    end)

    -- Feature: arcane-survivor-mvp, Property 33: Elapsed Time Increases
    describe("Property 33: Elapsed Time Increases", function()
        before_each(function()
            -- Initialize lua-quickcheck
            lqc.init(100, 100)  -- 100 tests, 100 shrinks
        end)
        
        it("increases elapsed time at rate of 1 second per real-time second", function()
            -- **Validates: Requirements 7.2**
            
            -- Define property: For any active game session, the elapsed time should
            -- continuously increase at a rate of 1 second per real-time second
            property "Elapsed time increases correctly during gameplay" {
                generators = {
                    lqc_gen.choose(1, 100)  -- Number of update iterations (1-100)
                },
                check = function(numUpdates)
                    -- Setup: Initialize game state
                    game_state.initialize()
                    game_state.state = "playing"
                    game_state.elapsedTime = 0
                    
                    -- Simulate game updates with fixed delta time
                    local dt = 1.0 / 60.0  -- 60 FPS (approximately 0.0167 seconds per frame)
                    local expectedElapsed = 0
                    
                    for _ = 1, numUpdates do
                        game_state.update(dt)
                        expectedElapsed = expectedElapsed + dt
                    end
                    
                    -- Verify: Elapsed time matches expected accumulation
                    -- Allow small floating point tolerance
                    local tolerance = 0.0001
                    local difference = math.abs(game_state.elapsedTime - expectedElapsed)
                    
                    -- Property holds if elapsed time increased correctly
                    return difference < tolerance
                end
            }
            
            -- Run all registered properties
            lqc.check()
            
            -- Verify no failures
            assert.is_false(lqc.failed)
        end)
        
        it("does not increase elapsed time when paused", function()
            -- **Validates: Requirements 7.2**
            
            property "Elapsed time does not increase when game is paused" {
                generators = {
                    lqc_gen.choose(1, 50),   -- Number of updates while paused
                    lqc_gen.choose(0, 100)   -- Initial elapsed time
                },
                check = function(numUpdates, initialTime)
                    -- Setup: Initialize game state and pause
                    game_state.initialize()
                    game_state.elapsedTime = initialTime
                    game_state.pause()
                    
                    -- Simulate updates while paused
                    local dt = 1.0 / 60.0
                    for _ = 1, numUpdates do
                        game_state.update(dt)
                    end
                    
                    -- Verify: Elapsed time unchanged
                    return game_state.elapsedTime == initialTime
                end
            }
            
            -- Run all registered properties
            lqc.check()
            
            -- Verify no failures
            assert.is_false(lqc.failed)
        end)
        
        it("resumes time tracking after unpause", function()
            -- **Validates: Requirements 7.2**
            
            property "Elapsed time resumes correctly after unpause" {
                generators = {
                    lqc_gen.choose(1, 50),   -- Updates before pause
                    lqc_gen.choose(1, 50),   -- Updates while paused
                    lqc_gen.choose(1, 50)    -- Updates after resume
                },
                check = function(updatesBefore, updatesDuringPause, updatesAfter)
                    -- Setup: Initialize game state
                    game_state.initialize()
                    game_state.elapsedTime = 0
                    
                    local dt = 1.0 / 60.0
                    
                    -- Phase 1: Update while playing
                    for _ = 1, updatesBefore do
                        game_state.update(dt)
                    end
                    local timeBeforePause = game_state.elapsedTime
                    
                    -- Phase 2: Pause and update (should not increase)
                    game_state.pause()
                    for _ = 1, updatesDuringPause do
                        game_state.update(dt)
                    end
                    
                    -- Phase 3: Resume and update
                    game_state.resume()
                    for _ = 1, updatesAfter do
                        game_state.update(dt)
                    end
                    
                    -- Verify: Time increased only during playing phases
                    local expectedTime = (updatesBefore + updatesAfter) * dt
                    local tolerance = 0.0001
                    local difference = math.abs(game_state.elapsedTime - expectedTime)
                    
                    return difference < tolerance
                end
            }
            
            -- Run all registered properties
            lqc.check()
            
            -- Verify no failures
            assert.is_false(lqc.failed)
        end)
    end)
end)
