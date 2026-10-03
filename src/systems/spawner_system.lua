-- spawner_system.lua
-- Manages enemy wave generation with difficulty scaling based on hero level
-- Spawns walkers at intervals from the top edge of the screen

local config_loader = require("src.models.config_loader")

local M = {}

-- Fallbacks when game_config.json has no spawner values (match the shipped config)
local DEFAULT_SPAWN_INTERVAL = 3.0
local DEFAULT_SPAWN_COUNT = 2

-- Spawn table used when game_config.json has none: walkers only
local DEFAULT_ENEMY_TABLE = {
    { type = "walker", weight = 1, minLevel = 1, groupSize = 1 },
}

-- Horizontal gap between members of a spawned group
local GROUP_SPACING = 30

---Read spawner.enemyTable from game_config.json
---Each entry: { type, weight, minLevel, groupSize }. Invalid entries are skipped.
---@return table Array of spawn table entries
local function loadEnemyTable()
    local configured = config_loader.get("spawner.enemyTable")
    if type(configured) ~= "table" then
        return DEFAULT_ENEMY_TABLE
    end
    
    local entries = {}
    for _, entry in ipairs(configured) do
        if type(entry) == "table" and type(entry.type) == "string" then
            table.insert(entries, {
                type = entry.type,
                weight = config_loader.positiveNumber(entry.weight, 1),
                minLevel = config_loader.positiveNumber(entry.minLevel, 1),
                groupSize = math.floor(config_loader.positiveNumber(entry.groupSize, 1)),
            })
        end
    end
    
    if #entries == 0 then
        return DEFAULT_ENEMY_TABLE
    end
    return entries
end

-- State
M.walkerPool = nil
M.activeWalkers = {}
M.spawnTimer = 0
M.spawnInterval = DEFAULT_SPAWN_INTERVAL
M.spawnCount = DEFAULT_SPAWN_COUNT
M.maxConcurrent = 50
M.enemyTable = DEFAULT_ENEMY_TABLE
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
    M.spawnInterval = config_loader.positiveNumber(config_loader.get("spawner.spawnInterval"), DEFAULT_SPAWN_INTERVAL)
    M.spawnCount = config_loader.positiveNumber(config_loader.get("spawner.spawnCount"), DEFAULT_SPAWN_COUNT)
    M.maxConcurrent = config_loader.positiveNumber(config_loader.get("spawner.maxConcurrent"), 50)
    M.enemyTable = loadEnemyTable()
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
        
        -- Spawn one group per spawn count, picked from the spawn table
        for i = 1, M.spawnCount do
            M.spawnEnemyGroup()
        end
    end
end

---Spawn a single enemy along the top edge
---@param enemyType string|nil Enemy type (default "walker")
---@param spawnX number|nil Spawn X position (default random)
function M.spawnWalker(enemyType, spawnX)
    -- Error handling: Check maximum concurrent limit (enforce 50 limit)
    if #M.activeWalkers >= M.maxConcurrent then
        return
    end
    
    -- Error handling: Validate walker pool exists
    if not M.walkerPool then
        print("Warning: spawner_system.spawnWalker() - walker pool is nil")
        return
    end
    
    -- Spawn along the top edge (random X unless given), avoiding screen edges
    spawnX = spawnX or math.random(50, 670)
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
        walker:activate(spawnX, spawnY, spawnX, enemyType or "walker")
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

---Pick a spawn table entry for the next spawn
---Only entries whose minLevel the hero has reached can be picked, weighted by
---their weight. Falls back to the first entry when none are unlocked.
---@return table Entry with type, weight, minLevel, groupSize
function M.chooseEnemyEntry()
    local totalWeight = 0
    for _, entry in ipairs(M.enemyTable) do
        if M.heroLevel >= entry.minLevel then
            totalWeight = totalWeight + entry.weight
        end
    end
    if totalWeight <= 0 then
        return M.enemyTable[1]
    end
    
    local roll = math.random() * totalWeight
    local lastUnlocked = M.enemyTable[1]
    for _, entry in ipairs(M.enemyTable) do
        if M.heroLevel >= entry.minLevel then
            lastUnlocked = entry
            roll = roll - entry.weight
            if roll < 0 then
                return entry
            end
        end
    end
    return lastUnlocked
end

---Spawn one group from the spawn table
---Group members spawn side by side around a random X position.
function M.spawnEnemyGroup()
    local entry = M.chooseEnemyEntry()
    local centerX = math.random(50, 670)
    for i = 1, entry.groupSize do
        local offset = (i - (entry.groupSize + 1) / 2) * GROUP_SPACING
        M.spawnWalker(entry.type, centerX + offset)
    end
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
    
    -- Read base values from config
    local baseInterval = config_loader.positiveNumber(config_loader.get("spawner.spawnInterval"), DEFAULT_SPAWN_INTERVAL)
    local baseCount = config_loader.positiveNumber(config_loader.get("spawner.spawnCount"), DEFAULT_SPAWN_COUNT)
    
    -- Difficulty scales on top of config values
    if heroLevel < 5 then
        M.spawnInterval = baseInterval
        M.spawnCount = baseCount
    elseif heroLevel < 10 then
        M.spawnInterval = baseInterval
        M.spawnCount = baseCount + 1
    elseif heroLevel < 15 then
        M.spawnInterval = math.max(1.0, baseInterval - 0.5)
        M.spawnCount = baseCount + 2
    else
        M.spawnInterval = math.max(1.0, baseInterval - 1.0)
        M.spawnCount = baseCount + 3
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
