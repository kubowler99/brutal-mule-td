--- Game State Model
-- Manages the overall game state including play state, timing, and statistics
-- @module game_state

local M = {}

-- Game state properties
M.state = "playing"              -- Current state: "playing", "paused", "game_over"
M.startTime = 0                  -- Game session start timestamp
M.elapsedTime = 0                -- Total elapsed seconds
M.enemiesDefeated = 0            -- Kill count
M.finalLevel = 0                 -- Level at game over
M.victoryCondition = false       -- true if boss defeated

--- Initialize game state with default values
-- Sets up a new game session with initial state
function M.initialize()
    M.state = "playing"
    M.startTime = system.getTimer() / 1000  -- Convert to seconds
    M.elapsedTime = 0
    M.enemiesDefeated = 0
    M.finalLevel = 0
    M.victoryCondition = false
end

--- Pause the game
-- Changes state to "paused"
function M.pause()
    M.state = "paused"
end

--- Resume the game
-- Changes state back to "playing"
function M.resume()
    M.state = "playing"
end

--- Update elapsed time
-- Should be called each frame to track game time
-- @param dt number Delta time in seconds (optional, will calculate from startTime if not provided)
function M.update(dt)
    if M.state == "playing" then
        if dt then
            M.elapsedTime = M.elapsedTime + dt
        else
            -- Calculate elapsed time from start
            local currentTime = system.getTimer() / 1000
            M.elapsedTime = currentTime - M.startTime
        end
    end
end

--- End the game and set final statistics
-- @param victory boolean True if player won (boss defeated), false if defeated
function M.endGame(victory)
    M.state = "game_over"
    M.victoryCondition = victory
end

--- Get game statistics
-- @return table Statistics including survival time, enemies defeated, final level, and victory condition
function M.getStatistics()
    return {
        survivalTime = M.elapsedTime,
        enemiesDefeated = M.enemiesDefeated,
        finalLevel = M.finalLevel,
        victoryCondition = M.victoryCondition
    }
end

return M
