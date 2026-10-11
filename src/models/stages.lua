-- Stages
-- The battlefields a run can take place in, from data/stages.json. Each
-- stage has its own enemy table, boss pair, background, and enemy and gold
-- multipliers. Winning a stage unlocks the stages listed with it as their
-- unlockedBy. Progress is saved through src.models.data:
--   meta.stages.<id> (true once unlocked), meta.selectedStage

local data = require("src.models.data")

local json = _G.json or require("json")

local M = {}

local _definitions = nil

--- Load (once) and return the stage list from data/stages.json
-- @return table Array of stage definitions, in order
function M.getStages()
  if _definitions then
    return _definitions
  end

  local success, decoded = pcall(function()
    local path = system.pathForFile("data/stages.json", system.ResourceDirectory)
    if not path then return nil end
    local file = io.open(path, "r")
    if not file then return nil end
    local contents = file:read("*a")
    file:close()
    return json.decode(contents)
  end)

  _definitions = (success and type(decoded) == "table" and type(decoded.stages) == "table") and decoded.stages or {}
  return _definitions
end

--- Replace the stage list (used by tests)
-- @param stages table|nil New stage list, or nil to reload from disk
function M.setStages(stages)
  _definitions = stages
end

--- Find a stage by id
function M.getStage(id)
  for _, stage in ipairs(M.getStages()) do
    if stage.id == id then
      return stage
    end
  end
  return nil
end

--- The first stage, which is always unlocked
function M.getFirstStage()
  return M.getStages()[1]
end

--- Whether a stage can be played
function M.isUnlocked(id)
  local stage = M.getStage(id)
  if not stage then
    return false
  end
  return stage.unlockedBy == nil or data.get("meta.stages." .. id) == true
end

--- Unlock the stages that follow a won stage
-- @param id string The stage that was won
-- @return table List of stages that were newly unlocked
function M.unlockAfterVictory(id)
  local unlocked = {}
  for _, stage in ipairs(M.getStages()) do
    if stage.unlockedBy == id and not M.isUnlocked(stage.id) then
      data.set("meta.stages." .. stage.id, true, true)
      table.insert(unlocked, stage)
    end
  end
  return unlocked
end

--- The stage picked last time if still unlocked, otherwise the first stage
function M.getSelectedStageId()
  local selected = data.get("meta.selectedStage")
  if selected and M.isUnlocked(selected) then
    return selected
  end
  local first = M.getFirstStage()
  return first and first.id or nil
end

function M.setSelectedStageId(id)
  data.set("meta.selectedStage", id, true)
end

local _enemyNames = nil

--- Display names of a stage's bosses, from data/enemies.json, in boss order
-- @param stage table Stage definition
-- @return table List of names (the enemy type when it has no name)
function M.getBossNames(stage)
  if not _enemyNames then
    local success, decoded = pcall(function()
      local path = system.pathForFile("data/enemies.json", system.ResourceDirectory)
      if not path then return nil end
      local file = io.open(path, "r")
      if not file then return nil end
      local contents = file:read("*a")
      file:close()
      return json.decode(contents)
    end)
    _enemyNames = {}
    if success and type(decoded) == "table" then
      for enemyType, entry in pairs(decoded) do
        if type(entry) == "table" and type(entry.name) == "string" then
          _enemyNames[enemyType] = entry.name
        end
      end
    end
  end
  local names = {}
  for _, boss in ipairs(stage and stage.bosses or {}) do
    table.insert(names, _enemyNames[boss.type] or boss.type)
  end
  return names
end

return M
