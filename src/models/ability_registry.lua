-- Ability Registry
-- Central registry for all abilities in the game
-- Loads ability definitions from external JSON and manages instantiation

local json = require("json")

local M = {}

-- Cached ability definitions (loaded from JSON)
M.abilities = {}

-- Cached ability class references (lazy-loaded)
local _classCache = {}

-- Initialize the registry by loading ability definitions
-- @param filePath string Optional path to abilities JSON (defaults to data/abilities.json)
-- @return boolean Success status
function M.initialize(filePath)
  filePath = filePath or "data/abilities.json"
  
  local path = system.pathForFile(filePath, system.ResourceDirectory)
  if not path then
    print("Error: Ability definitions file not found:", filePath)
    return false
  end
  
  local file = io.open(path, "r")
  if not file then
    print("Error: Could not open ability definitions file:", filePath)
    return false
  end
  
  local contents = file:read("*a")
  io.close(file)
  
  local success, decoded = pcall(json.decode, contents)
  if not success then
    print("Error: Failed to parse ability definitions JSON:", decoded)
    return false
  end
  
  M.abilities = decoded
  return true
end

-- Get ability definition by ID
-- @param id string The unique ability identifier
-- @return table|nil The ability definition or nil if not found
function M.getAbility(id)
  return M.abilities[id]
end

-- Get or load the ability class (lazy loading with caching)
-- @param id string The unique ability identifier
-- @return class|nil The ability class or nil if not found
local function _getAbilityClass(id)
  -- Return cached class if available
  if _classCache[id] then
    return _classCache[id]
  end
  
  local abilityDef = M.getAbility(id)
  if not abilityDef or not abilityDef.module then
    return nil
  end
  
  -- Lazy load the class module
  local success, abilityClass = pcall(require, abilityDef.module)
  if not success then
    print("Error: Failed to load ability module:", abilityDef.module, abilityClass)
    return nil
  end
  
  -- Cache for future use
  _classCache[id] = abilityClass
  return abilityClass
end

-- Create a new instance of an ability
-- @param id string The unique ability identifier
-- @return object|nil A new instance of the ability class or nil if not found
function M.createInstance(id)
  local abilityClass = _getAbilityClass(id)
  
  if not abilityClass then
    print("Warning: Could not create instance for ability:", id)
    return nil
  end
  
  -- Instantiate the ability class
  return abilityClass:new()
end

-- Check if an ability is unlocked
-- @param id string The unique ability identifier
-- @return boolean True if the ability is unlocked, false otherwise
function M.isUnlocked(id)
  local abilityDef = M.getAbility(id)
  
  if not abilityDef then
    return false
  end
  
  return abilityDef.unlocked == true
end

-- Get all ability IDs
-- @return table Array of ability IDs
function M.getAllAbilityIds()
  local ids = {}
  for id, _ in pairs(M.abilities) do
    table.insert(ids, id)
  end
  return ids
end

-- Get all unlocked ability IDs
-- @return table Array of unlocked ability IDs
function M.getUnlockedAbilityIds()
  local ids = {}
  for id, def in pairs(M.abilities) do
    if def.unlocked then
      table.insert(ids, id)
    end
  end
  return ids
end

return M
