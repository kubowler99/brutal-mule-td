-- spawner_system.lua
-- Manages enemy wave generation with difficulty scaling based on hero level
-- Spawns walkers at intervals from the top edge of the screen

local config_loader = require("src.models.config_loader")

local M = {}

-- State
M.walkerPool = nil
M.activeWalkers = {}
M.spawnTimer = 0
M.spawnInterval = 3.0
M.spawnCount = 1
M.maxConcurrent = 50
M.heroLevel = 1
M.gameStartTime = nil
M.hasSpawnedInitial = false
M.initialSpawnCount = 0

---Initialize the spawner system
---@param walkerPool table Object pool for walker entities
---@param heroLevel number Initial hero level
function M.initialize(walkerPool, heroLevel)
    -- Error handling: Validate walker pool
    if not walkerPool then
        print("Error: spawner_system.initialize() - walkerPool is nil")
        return false
    end
    
    if type(walkerPool.get) ~= "function" or type(walkerPool.release) ~= "function" then
        print("Error: spawner_system.initialize() - walkerPool missing required methods (get, release)")
        return false
    end
    
    M.walkerPool = walkerPool
    M.activeWalkers = {}
    M.spawnTimer = 0
    M.spawnInterval = config_loader.positiveNumber(config_loader.get("spawner.spawnInterval"), 3.0)
    M.spawnCount = config_loader.positiveNumber(config_loader.get("spawner.spawnCount"), 1)
    M.maxConcurrent = config_loader.positiveNumber(config_loader.get("spawner.maxConcurrent"), 50)
    M.heroLevel = heroLevel or 1
    M.gameStartTime = nil
    M.hasSpawnedInitial = false
    M.initialSpawnCount = 0
    
    -- Error handling: Validate and clamp hero level
    if type(M.heroLevel) ~= "number" then
        print("Warning: spawner_system.initialize() - invalid heroLevel, defaulting to 1")
        M.heroLevel = 1
    else
        M.heroLevel = math.max(1, math.floor(M.heroLevel))
    end
    
    -- Set initial difficulty based on hero level
    M.updateDifficulty(M.heroLevel)
    
    return true
end

---Update the spawner system
---@param dt number Delta time in seconds
---@param currentTime number Current game time in seconds
function M.update(dt, currentTime)
    -- Error handling: Validate parameters
    if type(dt) ~= "number" or dt < 0 then
        print("Warning: spawner_system.update() - invalid dt:", dt)
        return
    end
    
    if type(currentTime) ~= "number" or currentTime < 0 then
        print("Warning: spawner_system.update() - invalid currentTime:", currentTime)
        return
    end
    
    -- Update active walkers (remove inactive ones) - do this first
    local i = 1
    while i <= #M.activeWalkers do
        local walker = M.activeWalkers[i]
        -- Error handling: Validate walker exists and has isActive property
        if not walker or walker.isActive == nil then
            print("Warning: spawner_system.update() - invalid walker in activeWalkers, removing")
            table.remove(M.activeWalkers, i)
        elseif not walker.isActive then
            table.remove(M.activeWalkers, i)
        else
            i = i + 1
        end
    end
    
    -- Handle initial spawn burst (3 walkers within 2 seconds)
    if not M.hasSpawnedInitial then
        if M.gameStartTime == nil then
            M.gameStartTime = currentTime
        end
        
        local timeSinceStart = currentTime - M.gameStartTime
        if timeSinceStart <= 2.0 then
            -- Spawn 3 walkers spread over 2 seconds at t=0, t=0.7, t=1.4
            local spawnTimes = {0, 0.7, 1.4}
            local targetCount = 0
            local epsilon = 0.001  -- Small epsilon for floating point comparison
            
            -- Determine how many walkers should have spawned by now
            for _, spawnTime in ipairs(spawnTimes) do
                if timeSinceStart >= (spawnTime - epsilon) then
                    targetCount = targetCount + 1
                end
            end
            
            -- Spawn walkers to reach target count
            while M.initialSpawnCount < targetCount do
                M.spawnWalker()
                M.initialSpawnCount = M.initialSpawnCount + 1
            end
        else
            M.hasSpawnedInitial = true
            M.spawnTimer = 0
        end
        return
    end
    
    -- Regular spawning after initial burst
    M.spawnTimer = M.spawnTimer + dt
    
    -- Handle multiple spawn intervals in one update
    while M.spawnTimer >= M.spawnInterval do
        M.spawnTimer = M.spawnTimer - M.spawnInterval
        
        -- Spawn multiple walkers based on spawn count
        for i = 1, M.spawnCount do
            M.spawnWalker()
        end
    end
end

---Spawn a single walker at a random position along the top edge
function M.spawnWalker()
    -- Error handling: Check maximum concurrent limit (enforce 50 limit)
    if #M.activeWalkers >= M.maxConcurrent then
        return
    end
    
    -- Error handling: Validate walker pool exists
    if not M.walkerPool then
        print("Warning: spawner_system.spawnWalker() - walker pool is nil")
        return
    end
    
    -- Random spawn position along top edge (avoid screen edges)
    local spawnX = math.random(50, 670)
    local spawnY = 0
    
    -- Error handling: Clamp spawn X position to valid range [50, 670]
    spawnX = math.max(50, math.min(670, spawnX))
    
    -- Get walker from pool
    local walker = M.walkerPool:get()
    
    -- Error handling: Handle pool exhaustion gracefully
    if not walker then
        print("Warning: spawner_system.spawnWalker() - pool exhausted, cannot spawn walker")
        return
    end
    
    -- Error handling: Validate walker has activate method
    if type(walker.activate) ~= "function" then
        print("Warning: spawner_system.spawnWalker() - walker missing activate method")
        M.walkerPool:release(walker)
        return
    end
    
    -- Activate walker with spawn position and lane
    local success, err = pcall(function()
        walker:activate(spawnX, spawnY, spawnX)
    end)
    
    -- Error handling: Handle activation failure
    if not success then
        print("Error: spawner_system.spawnWalker() - walker activation failed:", err)
        M.walkerPool:release(walker)
        return
    end
    
    -- Add to active walkers
    table.insert(M.activeWalkers, walker)
end

---Update difficulty scaling based on hero level
---@param heroLevel number Current hero level
function M.updateDifficulty(heroLevel)
    -- Error handling: Validate hero level
    if type(heroLevel) ~= "number" then
        print("Warning: spawner_system.updateDifficulty() - invalid heroLevel:", heroLevel)
        return
    end
    
    -- Error handling: Clamp hero level to reasonable range
    heroLevel = math.max(1, math.floor(heroLevel))
    M.heroLevel = heroLevel
    
    -- Difficulty curve based on requirements
    if heroLevel < 5 then
        M.spawnInterval = 3.0
        M.spawnCount = 1
    elseif heroLevel < 10 then
        M.spawnInterval = 3.0
        M.spawnCount = 2
    elseif heroLevel < 15 then
        M.spawnInterval = 2.0
        M.spawnCount = 3
    else
        M.spawnInterval = 2.0
        M.spawnCount = 4
    end
end

---Get array of active walkers
---@return table Array of active walker entities
function M.getActiveWalkers()
    return M.activeWalkers
end

---Cleanup the spawner system
function M.cleanup()
    -- Return all active walkers to pool
    for _, walker in ipairs(M.activeWalkers) do
        -- Error handling: Validate walker before cleanup
        if walker then
            -- Safely deactivate walker
            if walker.isActive and type(walker.deactivate) == "function" then
                local success, err = pcall(function()
                    walker:deactivate()
                end)
                if not success then
                    print("Warning: spawner_system.cleanup() - walker deactivation failed:", err)
                end
            end
            
            -- Safely return to pool
            if M.walkerPool and type(M.walkerPool.release) == "function" then
                local success, err = pcall(function()
                    M.walkerPool:release(walker)
                end)
                if not success then
                    print("Warning: spawner_system.cleanup() - walker release failed:", err)
                end
            end
        end
    end
    
    M.activeWalkers = {}
    M.walkerPool = nil
    M.spawnTimer = 0
    M.hasSpawnedInitial = false
    M.initialSpawnCount = 0
end

return M
