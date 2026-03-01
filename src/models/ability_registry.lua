-- Ability Registry
-- Central registry for all abilities in the game
-- Manages ability definitions, instantiation, and unlock status

local ArcaneBolt = require("src.entities.abilities.arcane_bolt")

local M = {}

-- Ability definitions registry
-- Each entry contains metadata about an ability
M.abilities = {
  arcane_bolt = {
    class = ArcaneBolt,
    unlocked = true,  -- Arcane Bolt is unlocked by default (starting ability)
    maxTier = 5
  }
  -- Future abilities can be added here
}

-- Get ability definition by ID
-- @param id string The unique ability identifier
-- @return table|nil The ability definition or nil if not found
function M.getAbility(id)
  return M.abilities[id]
end

-- Create a new instance of an ability
-- @param id string The unique ability identifier
-- @return object|nil A new instance of the ability class or nil if not found
function M.createInstance(id)
  local abilityDef = M.getAbility(id)
  
  if not abilityDef then
    return nil
  end
  
  -- Instantiate the ability class
  return abilityDef.class:new()
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

return M
