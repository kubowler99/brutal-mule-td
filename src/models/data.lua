local json = _G.json or require("json")
local M = {}

M.filename = "gamedata.json"
M.defaultData = {
    settings = {
        soundOn = true,
        musicOn = true,
    },
    score = 0,
    highScore = 0,
    sessions = 0,
    firstRun = os.time(),
    stats = {
        gamesPlayed = 0,
        highestLevel = 1,
        longestSurvival = 0,
        totalEnemiesDefeated = 0,
    },
}

M.data = {}
local isSandboxMode = false
local sandboxData = nil

-- Helper to deep copy table
local function deepCopy(t)
    if type(t) ~= 'table' then return t end
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function M.load()
    local path = system.pathForFile(M.filename, system.DocumentsDirectory)
    local file = io.open(path, "r")
    
    if file then
        local contents = file:read("*a")
        io.close(file)
        
        local success, data = pcall(json.decode, contents)
        if success and data then
            M.data = data
        else
            print("[ERROR] Failed to decode game data. Using defaults.")
            M.data = deepCopy(M.defaultData)
        end
    else
        print("[INFO] No save file found. Initializing defaults.")
        M.data = deepCopy(M.defaultData)
    end
    
    -- Update session count
    M.data.sessions = (M.data.sessions or 0) + 1
    M.save()
end

function M.save()
    if isSandboxMode then
        print("[INFO] Sandbox mode active. Data not saved to disk.")
        return
    end

    local path = system.pathForFile(M.filename, system.DocumentsDirectory)
    local file, errorString = io.open(path, "w")
    
    if file then
        local success, contents = pcall(json.encode, M.data)
        if success then
            file:write(contents)
            io.close(file)
        else
            print("[ERROR] Failed to encode game data: " .. tostring(contents))
            io.close(file)
        end
    else
        print("[ERROR] Could not open file for saving: " .. tostring(errorString))
    end
end

-- Dot notation getter
function M.get(path)
    local target = isSandboxMode and sandboxData or M.data
    if not path then return target end
    
    local keys = {}
    for key in path:gmatch("([^%.]+)") do
        keys[#keys+1] = key
    end

    local value = target
    for i = 1, #keys do
        if type(value) ~= "table" then return nil end
        value = value[keys[i]]
    end
    return value
end

-- Dot notation setter
function M.set(path, value, shouldSave)
    local target = isSandboxMode and sandboxData or M.data
    
    local keys = {}
    for key in path:gmatch("([^%.]+)") do
        keys[#keys+1] = key
    end

    local current = target
    
    for i = 1, #keys - 1 do
        local key = keys[i]
        if not current[key] or type(current[key]) ~= "table" then
            current[key] = {}
        end
        current = current[key]
    end
    
    current[keys[#keys]] = value
    
    if shouldSave then
        M.save()
    end
end

-- Sandbox mode for testing
function M.startSandbox()
    isSandboxMode = true
    sandboxData = deepCopy(M.data)
    print("[INFO] Sandbox mode started.")
end

function M.stopSandbox(applyChanges)
    if applyChanges then
        M.data = sandboxData
    end
    isSandboxMode = false
    sandboxData = nil
    print("[INFO] Sandbox mode stopped. Applied changes: " .. tostring(applyChanges))
end

return M
