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

-- Enemies spawn between these X positions (avoiding screen edges)
local SPAWN_MIN_X = 50
local SPAWN_MAX_X = 670

-- Bosses spawn at the top center
local BOSS_SPAWN_X = 360

---Read spawner.elites from game_config.json (elites are off without it)
---@return table { minLevel, chance, healthMultiplier, damageMultiplier, xpMultiplier }
local function loadEliteSettings()
    local configured = config_loader.get("spawner.elites")
    if type(configured) ~= "table" then
        return { minLevel = math.huge, chance = 0, healthMultiplier = 1, damageMultiplier = 1, xpMultiplier = 1, abilities = {} }
    end
    
    -- Elite abilities: each elite gets one at random from this list
    local abilities = {}
    if type(configured.abilities) == "table" then
        for _, ability in ipairs(configured.abilities) do
            if type(ability) == "string" then
                table.insert(abilities, ability)
            end
        end
    end
    
    return {
        minLevel = config_loader.positiveNumber(configured.minLevel, 1),
        chance = math.min(1, config_loader.positiveNumber(configured.chance, 0)),
        healthMultiplier = config_loader.positiveNumber(configured.healthMultiplier, 1),
        damageMultiplier = config_loader.positiveNumber(configured.damageMultiplier, 1),
        xpMultiplier = config_loader.positiveNumber(configured.xpMultiplier, 1),
        abilities = abilities,
    }
end

---Read the boss schedule: the stage's bosses, else spawner.bosses from
---game_config.json (no bosses without either)
---@param stage table|nil Stage definition from data/stages.json
---@return table Array of { level, type }
local function loadBossSchedule(stage)
    local configured = stage and stage.bosses or config_loader.get("spawner.bosses")
    local schedule = {}
    if type(configured) == "table" then
        for _, entry in ipairs(configured) do
            if type(entry) == "table" and type(entry.type) == "string" and type(entry.level) == "number" then
                table.insert(schedule, { level = entry.level, type = entry.type })
            end
        end
    end
    return schedule
end

---Read the enemy table: the stage's table, else spawner.enemyTable from
---game_config.json
---Each entry: { type, weight, minLevel, groupSize }. Invalid entries are skipped.
---@param stage table|nil Stage definition from data/stages.json
---@return table Array of spawn table entries
local function loadEnemyTable(stage)
    local configured = stage and stage.enemyTable or config_loader.get("spawner.enemyTable")
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
M.elites = nil          -- set in initialize()
M.bossSchedule = {}     -- set in initialize()
M.spawnedBossLevels = {}
M.enemyMultiplier = 1   -- stage multiplier for enemy health and damage

-- Called with the boss enemy when a boss spawns (set by game_controller)
M.onBossSpawned = nil
M.heroLevel = 1
M.gameStartTime = nil
M.hasSpawnedInitial = false
M.initialSpawnCount = 0

---Initialize the spawner system
---@param walkerPool table Object pool for walker entities
---@param heroLevel number Initial hero level
---@param stage table|nil Stage definition (enemy table, bosses, enemyMultiplier)
function M.initialize(walkerPool, heroLevel, stage)
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
    M.enemyTable = loadEnemyTable(stage)
    M.elites = loadEliteSettings()
    M.bossSchedule = loadBossSchedule(stage)
    M.enemyMultiplier = (stage and type(stage.enemyMultiplier) == "number" and stage.enemyMultiplier > 0)
        and stage.enemyMultiplier or 1
    M.spawnedBossLevels = {}
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
    
    -- Spawn any boss whose level the hero has reached
    M.checkBossSpawns()
    
    -- Spawn minions requested by summoner elites
    M.spawnSummons()
    
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
---@param ignoreLimit boolean|nil Spawn even at the concurrent limit (bosses)
---@param options table|nil { y = spawn Y (default top edge), noElite = true to skip the elite roll }
---@return table|nil The spawned enemy
function M.spawnWalker(enemyType, spawnX, ignoreLimit, options)
    options = options or {}
    -- Error handling: Check maximum concurrent limit (enforce 50 limit)
    if #M.activeWalkers >= M.maxConcurrent and not ignoreLimit then
        return
    end
    
    -- Error handling: Validate walker pool exists
    if not M.walkerPool then
        print("Warning: spawner_system.spawnWalker() - walker pool is nil")
        return
    end
    
    -- Spawn along the top edge (random X unless given), avoiding screen edges
    spawnX = spawnX or math.random(SPAWN_MIN_X, SPAWN_MAX_X)
    local spawnY = options.y or 0
    
    -- Error handling: Clamp spawn X position to valid range [50, 670]
    spawnX = math.max(SPAWN_MIN_X, math.min(SPAWN_MAX_X, spawnX))
    
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
    
    -- Later stages make every enemy tougher
    if M.enemyMultiplier ~= 1 then
        walker.maxHealth = walker.maxHealth * M.enemyMultiplier
        walker.health = walker.maxHealth
        walker.damage = walker.damage * M.enemyMultiplier
        walker.explodeDamage = (walker.explodeDamage or 0) * M.enemyMultiplier
        if walker.healthBar then
            walker.healthBar:update(walker.health, walker.maxHealth)
        end
    end
    
    -- Some normal enemies spawn as elites once the hero is strong enough
    local elites = M.elites
    if elites and not walker.isBoss and not options.noElite
       and M.heroLevel >= elites.minLevel and math.random() < elites.chance then
        local ability = nil
        if #elites.abilities > 0 then
            ability = elites.abilities[math.random(1, #elites.abilities)]
        end
        walker:makeElite(elites.healthMultiplier, elites.damageMultiplier, elites.xpMultiplier, ability)
    end
    
    -- Add to active walkers
    table.insert(M.activeWalkers, walker)
    return walker
end

-- Summoned minions: type, and horizontal offset from the summoner
local SUMMON_TYPE = "swarmling"
local SUMMON_OFFSET = 30

---Spawn the minions that summoner elites have asked for
---Minions appear beside the summoner, never as elites, and respect the
---concurrent limit.
function M.spawnSummons()
    -- Copy first: spawning adds to activeWalkers while we iterate
    local summoners = {}
    for _, walker in ipairs(M.activeWalkers) do
        if walker.isActive and (walker.pendingSummons or 0) > 0 then
            table.insert(summoners, walker)
        end
    end
    
    for _, summoner in ipairs(summoners) do
        for i = 1, summoner.pendingSummons do
            local side = (i % 2 == 1) and -1 or 1
            M.spawnWalker(summoner.summonType or SUMMON_TYPE, summoner.x + side * SUMMON_OFFSET, false,
                { y = summoner.y, noElite = true })
        end
        summoner.pendingSummons = 0
    end
end

-- Split enemies appear this far to either side of the one that died
local SPLIT_OFFSET = 25

---Spawn the smaller enemies a splitter breaks into when it dies
---@param enemy table The enemy that died
function M.spawnSplit(enemy)
    if not enemy or not enemy.splitInto or (enemy.splitCount or 0) <= 0 then
        return
    end
    for i = 1, enemy.splitCount do
        local side = (i % 2 == 1) and -1 or 1
        M.spawnWalker(enemy.splitInto, enemy.x + side * SPLIT_OFFSET, false,
            { y = enemy.y, noElite = true })
    end
end

---Spawn each scheduled boss once, when the hero reaches its level
function M.checkBossSpawns()
    for _, boss in ipairs(M.bossSchedule) do
        if M.heroLevel >= boss.level and not M.spawnedBossLevels[boss.level] then
            M.spawnedBossLevels[boss.level] = true
            local spawned = M.spawnWalker(boss.type, BOSS_SPAWN_X, true)
            if spawned and M.onBossSpawned then
                M.onBossSpawned(spawned)
            end
        end
    end
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
---Group members spawn side by side around a random X position, chosen so the
---whole group fits inside the spawn range (otherwise edge members would be
---clamped onto each other).
function M.spawnEnemyGroup()
    local entry = M.chooseEnemyEntry()
    local halfWidth = math.ceil((entry.groupSize - 1) / 2 * GROUP_SPACING)
    local minCenter = SPAWN_MIN_X + halfWidth
    local maxCenter = SPAWN_MAX_X - halfWidth
    local centerX = math.random(minCenter, math.max(minCenter, maxCenter))
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
    M.spawnedBossLevels = {}
    M.onBossSpawned = nil
end

return M
