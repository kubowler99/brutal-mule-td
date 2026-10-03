-- Passive Ability
-- Takes an ability slot and modifies hero stats instead of attacking.
-- One class serves every passive; abilities.json sets which stat it changes:
--   "passive": { "stat": "damageMultiplier", "perTier": 0.1 }
-- Each tier adds perTier to the stat (use a negative value to reduce it).

local ability_data_loader = require("src.models.ability_data_loader")

local Passive = Class("Passive")

local MAX_TIER = 5

--- Create a passive from its abilities.json entry
-- @param id string Ability id in abilities.json
function Passive:initialize(id)
  self.id = id
  self.isPassive = true
  self.tier = 1

  local entry = ability_data_loader._data and ability_data_loader._data[id]
  local passive = entry and entry.passive

  self.name = (entry and entry.name) or id
  self.stat = passive and passive.stat
  self.perTier = (passive and type(passive.perTier) == "number") and passive.perTier or 0
end

--- Passives never fire
function Passive:canActivate()
  return false
end

--- Add this passive's bonus to a hero stats table
-- @param stats table Hero stats from Hero:getStats()
function Passive:applyStats(stats)
  if self.stat and type(stats[self.stat]) == "number" then
    stats[self.stat] = stats[self.stat] + self.perTier * self.tier
  end
end

--- Every upgrade card raises the tier by one
function Passive:upgrade()
  self.tier = math.min(self.tier + 1, MAX_TIER)
end

return Passive
