-- Config Loader
-- Reads game configuration values from game_config.json
-- Provides validated data with dot-notation path lookup and fallback defaults

local json = _G.json or require("json")

local M = {}

-- Cached config data (loaded from JSON)
M._data = nil

--- Load and cache game configuration from JSON
-- @param filePath string Optional path (defaults to "data/game_config.json")
-- @return boolean Success status
function M.initialize(filePath)
  filePath = filePath or "data/game_config.json"

  local path = system.pathForFile(filePath, system.ResourceDirectory)
  if not path then
    print("Error: config_loader - Config file not found: " .. tostring(filePath))
    M._data = {}
    return false
  end

  local file = io.open(path, "r")
  if not file then
    print("Error: config_loader - Could not open config file: " .. tostring(filePath))
    M._data = {}
    return false
  end

  local contents = file:read("*a")
  io.close(file)

  local success, decoded = pcall(json.decode, contents)
  if not success or type(decoded) ~= "table" then
    print("Error: config_loader - Failed to parse config JSON: " .. tostring(decoded))
    M._data = {}
    return false
  end

  M._data = decoded
  return true
end

--- Get a config value by dot-notation path with fallback default
-- @param path string e.g. "wall.health", "spawner.spawnInterval"
-- @param default any Fallback value if path not found or invalid
-- @return any The config value or default
function M.get(path, default)
  if not M._data then
    return default
  end

  local current = M._data
  for segment in string.gmatch(path, "[^%.]+") do
    if type(current) ~= "table" then
      return default
    end
    current = current[segment]
    if current == nil then
      return default
    end
  end

  return current
end

--- Validate that a value is a positive number, return default if not
-- @param value any
-- @param default number
-- @return number
function M.positiveNumber(value, default)
  if type(value) ~= "number" or value <= 0 then
    return default
  end
  return value
end

return M
