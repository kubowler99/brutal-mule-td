-- Ability Data Loader
-- Reads ability base stats, upgrade parameters, and tier-based scaling from abilities.json
-- Provides validated data with fallback defaults when data is missing or invalid

local json = _G.json or require("json")

local M = {}

-- Cached ability data (loaded from JSON)
M._data = nil

-- Default fallback values for base stats
local BASE_STAT_DEFAULTS = {
  cooldown = 1.0,
  damage = 10,
  projectileSpeed = 400,
  pierceCount = 0,
  projectileCount = 1
}

-- Default fallback values for ability entry fields
local ENTRY_DEFAULTS = {
  unlocked = false,
  maxTier = 5
}

--- Validate a single numeric field with a constraint
-- @param value any The value to validate
-- @param fieldName string Field name for error logging
-- @param abilityId string Ability ID for error logging
-- @param constraint string "positive" (> 0) or "non_negative" (>= 0)
-- @param default number The fallback default
-- @return number The validated value or default
local function _validateNumeric(value, fieldName, abilityId, constraint, default)
  if type(value) ~= "number" then
    if value ~= nil then
      print("Warning: ability_data_loader - " .. abilityId .. "." .. fieldName .. " is not a number, using default " .. tostring(default))
    end
    return default
  end

  if constraint == "positive" and value <= 0 then
    print("Warning: ability_data_loader - " .. abilityId .. "." .. fieldName .. " must be positive, got " .. tostring(value) .. ", using default " .. tostring(default))
    return default
  end

  if constraint == "non_negative" and value < 0 then
    print("Warning: ability_data_loader - " .. abilityId .. "." .. fieldName .. " must be non-negative, got " .. tostring(value) .. ", using default " .. tostring(default))
    return default
  end

  return value
end

--- Validate base stats table, applying defaults for missing/invalid fields
-- @param abilityId string The ability ID for error logging
-- @param baseStats table The raw baseStats table from JSON
-- @return table Validated base stats with defaults applied
local function _validateBaseStats(abilityId, baseStats)
  if type(baseStats) ~= "table" then
    print("Warning: ability_data_loader - " .. abilityId .. ".baseStats is not a table, using all defaults")
    return {
      cooldown = BASE_STAT_DEFAULTS.cooldown,
      damage = BASE_STAT_DEFAULTS.damage,
      projectileSpeed = BASE_STAT_DEFAULTS.projectileSpeed,
      pierceCount = BASE_STAT_DEFAULTS.pierceCount,
      projectileCount = BASE_STAT_DEFAULTS.projectileCount
    }
  end

  return {
    cooldown = _validateNumeric(baseStats.cooldown, "baseStats.cooldown", abilityId, "positive", BASE_STAT_DEFAULTS.cooldown),
    damage = _validateNumeric(baseStats.damage, "baseStats.damage", abilityId, "positive", BASE_STAT_DEFAULTS.damage),
    projectileSpeed = _validateNumeric(baseStats.projectileSpeed, "baseStats.projectileSpeed", abilityId, "positive", BASE_STAT_DEFAULTS.projectileSpeed),
    pierceCount = _validateNumeric(baseStats.pierceCount, "baseStats.pierceCount", abilityId, "non_negative", BASE_STAT_DEFAULTS.pierceCount),
    projectileCount = _validateNumeric(baseStats.projectileCount, "baseStats.projectileCount", abilityId, "positive", BASE_STAT_DEFAULTS.projectileCount)
  }
end

--- Validate ability entry structure, log errors for missing/invalid fields
-- @param abilityId string The ability identifier
-- @param abilityData table The raw ability data from JSON
-- @return boolean True if the entry is valid enough to use (has module field)
function M.validateAbilityEntry(abilityId, abilityData)
  if type(abilityData) ~= "table" then
    print("Error: ability_data_loader - " .. abilityId .. " entry is not a table, skipping")
    return false
  end

  local valid = true

  -- Validate name (string, non-empty, default = ability ID)
  if type(abilityData.name) ~= "string" or abilityData.name == "" then
    print("Warning: ability_data_loader - " .. abilityId .. ".name is missing or empty, using ability ID as default")
    abilityData.name = abilityId
  end

  -- Validate module (string, non-empty, REQUIRED - skip ability if missing)
  if type(abilityData.module) ~= "string" or abilityData.module == "" then
    print("Error: ability_data_loader - " .. abilityId .. ".module is missing or empty, skipping ability")
    return false
  end

  -- Validate unlocked (boolean, default = false)
  if type(abilityData.unlocked) ~= "boolean" then
    print("Warning: ability_data_loader - " .. abilityId .. ".unlocked is not a boolean, using default false")
    abilityData.unlocked = ENTRY_DEFAULTS.unlocked
  end

  -- Validate maxTier (number, positive integer, default = 5)
  if type(abilityData.maxTier) ~= "number" or abilityData.maxTier <= 0 or math.floor(abilityData.maxTier) ~= abilityData.maxTier then
    print("Warning: ability_data_loader - " .. abilityId .. ".maxTier is invalid, using default " .. tostring(ENTRY_DEFAULTS.maxTier))
    abilityData.maxTier = ENTRY_DEFAULTS.maxTier
  end

  -- Validate baseStats (table with numeric fields)
  if type(abilityData.baseStats) ~= "table" then
    print("Error: ability_data_loader - " .. abilityId .. ".baseStats is missing or not a table")
    valid = false
  end

  return valid
end

--- Load and cache ability data from JSON
-- @param filePath string Optional path (defaults to "data/abilities.json")
-- @return boolean Success status
function M.initialize(filePath)
  filePath = filePath or "data/abilities.json"

  local path = system.pathForFile(filePath, system.ResourceDirectory)
  if not path then
    print("Error: ability_data_loader - Ability data file not found: " .. tostring(filePath))
    M._data = {}
    return false
  end

  local file = io.open(path, "r")
  if not file then
    print("Error: ability_data_loader - Could not open ability data file: " .. tostring(filePath))
    M._data = {}
    return false
  end

  local contents = file:read("*a")
  io.close(file)

  local success, decoded = pcall(json.decode, contents)
  if not success or type(decoded) ~= "table" then
    print("Error: ability_data_loader - Failed to parse ability data JSON: " .. tostring(decoded))
    M._data = {}
    return false
  end

  -- Validate each ability entry
  local validData = {}
  for abilityId, abilityData in pairs(decoded) do
    if M.validateAbilityEntry(abilityId, abilityData) then
      validData[abilityId] = abilityData
    end
  end

  M._data = validData
  return true
end

--- Get base stats for an ability
-- @param abilityId string e.g. "arcane_bolt"
-- @return table {cooldown, damage, projectileSpeed, pierceCount, projectileCount} or nil
function M.getBaseStats(abilityId)
  if not M._data then
    return nil
  end

  local abilityData = M._data[abilityId]
  if not abilityData then
    return nil
  end

  return _validateBaseStats(abilityId, abilityData.baseStats)
end

--- Get upgrade parameters for an ability and upgrade type
-- @param abilityId string
-- @param upgradeType string e.g. "damage_increase"
-- @return table Upgrade params or nil
function M.getUpgradeParams(abilityId, upgradeType)
  if not M._data then
    return nil
  end

  local abilityData = M._data[abilityId]
  if not abilityData or type(abilityData.upgrades) ~= "table" then
    return nil
  end

  local upgradeData = abilityData.upgrades[upgradeType]
  if type(upgradeData) ~= "table" then
    return nil
  end

  return upgradeData
end

--- Get tier parameters for an ability at a specific tier
-- @param abilityId string
-- @param tier number 1-5
-- @return table Tier delta params or nil
function M.getTierParams(abilityId, tier)
  if not M._data then
    return nil
  end

  local abilityData = M._data[abilityId]
  if not abilityData or type(abilityData.tiers) ~= "table" then
    return nil
  end

  -- Tiers are stored with string keys in JSON ("1", "2", etc.)
  local tierKey = tostring(tier)
  local tierData = abilityData.tiers[tierKey]
  if type(tierData) ~= "table" then
    return nil
  end

  return tierData
end

return M
