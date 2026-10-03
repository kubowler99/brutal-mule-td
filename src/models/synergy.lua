-- Synergy
-- Abilities carry tags in abilities.json (e.g. "projectile", "frost").
-- Each tag shared by two or more of the hero's abilities adds a damage bonus,
-- and level-up cards that share a tag with the hero's abilities are drawn
-- more often. Amounts come from the "synergy" section of game_config.json.

local ability_data_loader = require("src.models.ability_data_loader")
local config_loader = require("src.models.config_loader")

local M = {}

local DEFAULT_DAMAGE_PER_SHARED_TAG = 0.1
local DEFAULT_DRAFT_WEIGHT = 2

--- Tags of an ability from abilities.json
-- @param abilityId string|nil Ability id
-- @return table Array of tag strings (empty when none)
function M.getTags(abilityId)
  local entry = abilityId and ability_data_loader._data and ability_data_loader._data[abilityId]
  if entry and type(entry.tags) == "table" then
    return entry.tags
  end
  return {}
end

--- Tags held by two or more of the given abilities
-- @param abilities table Array of ability instances (each with an id)
-- @return table Sorted array of shared tags
function M.getSharedTags(abilities)
  local counts = {}
  for _, ability in ipairs(abilities or {}) do
    -- Count each tag once per ability
    local seen = {}
    for _, tag in ipairs(M.getTags(ability.id)) do
      if not seen[tag] then
        seen[tag] = true
        counts[tag] = (counts[tag] or 0) + 1
      end
    end
  end

  local shared = {}
  for tag, count in pairs(counts) do
    if count >= 2 then
      table.insert(shared, tag)
    end
  end
  table.sort(shared)
  return shared
end

--- Damage multiplier bonus from shared tags (added to damageMultiplier)
-- @param abilities table Array of ability instances
-- @return number Bonus, e.g. 0.2 for two shared tags
function M.getDamageBonus(abilities)
  local perTag = config_loader.positiveNumber(
    config_loader.get("synergy.damagePerSharedTag"), DEFAULT_DAMAGE_PER_SHARED_TAG)
  return perTag * #M.getSharedTags(abilities)
end

--- Whether an ability shares any tag with the given abilities
-- @param abilityId string|nil Ability id of a card
-- @param abilities table Array of ability instances
-- @return boolean
function M.sharesTag(abilityId, abilities)
  local heroTags = {}
  for _, ability in ipairs(abilities or {}) do
    for _, tag in ipairs(M.getTags(ability.id)) do
      heroTags[tag] = true
    end
  end
  for _, tag in ipairs(M.getTags(abilityId)) do
    if heroTags[tag] then
      return true
    end
  end
  return false
end

--- Draft weight of a level-up card: higher when it shares a tag
-- @param card table Upgrade card (abilityId may be nil for stat cards)
-- @param abilities table The hero's abilities
-- @return number Relative weight
function M.getDraftWeight(card, abilities)
  if card and M.sharesTag(card.abilityId, abilities) then
    return config_loader.positiveNumber(config_loader.get("synergy.draftWeight"), DEFAULT_DRAFT_WEIGHT)
  end
  return 1
end

return M
