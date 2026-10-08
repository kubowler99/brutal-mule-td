-- Meta Progression
-- Gold earned between runs, permanent upgrades bought with it, and heroes.
-- Definitions come from data/meta.json; the player's progress is saved
-- through src.models.data under the "meta" key:
--   meta.gold, meta.upgrades.<id> (level), meta.heroes.<id> (unlocked),
--   meta.selectedHero

local data = require("src.models.data")

local json = _G.json or require("json")

local M = {}

-- Cached definitions from data/meta.json
local _definitions = nil

local EMPTY_DEFINITIONS = { gold = {}, upgrades = {}, heroes = {} }

--- Load (once) and return the definitions from data/meta.json
-- @return table { gold, upgrades, heroes }
function M.getDefinitions()
  if _definitions then
    return _definitions
  end

  local success, decoded = pcall(function()
    local path = system.pathForFile("data/meta.json", system.ResourceDirectory)
    if not path then return nil end
    local file = io.open(path, "r")
    if not file then return nil end
    local contents = file:read("*a")
    file:close()
    return json.decode(contents)
  end)

  if success and type(decoded) == "table" then
    _definitions = {
      gold = type(decoded.gold) == "table" and decoded.gold or {},
      upgrades = type(decoded.upgrades) == "table" and decoded.upgrades or {},
      heroes = type(decoded.heroes) == "table" and decoded.heroes or {},
    }
  else
    _definitions = EMPTY_DEFINITIONS
  end
  return _definitions
end

--- Replace the definitions (used by tests)
-- @param definitions table|nil New definitions, or nil to reload from disk
function M.setDefinitions(definitions)
  _definitions = definitions
end

-- Gold ------------------------------------------------------------------------

function M.getGold()
  return data.get("meta.gold") or 0
end

--- Add gold and save
-- @param amount number Gold to add (may be negative)
function M.addGold(amount)
  data.set("meta.gold", math.max(0, M.getGold() + amount), true)
end

--- Spend gold if there is enough, and save
-- @param amount number Gold to spend (non-negative)
-- @return boolean True if the gold was spent
function M.spendGold(amount)
  if type(amount) ~= "number" or amount < 0 or M.getGold() < amount then
    return false
  end
  M.addGold(-amount)
  return true
end

--- Gold earned by a finished run
-- @param stats table Run statistics (enemiesDefeated, finalLevel, victoryCondition)
-- @return number Gold earned
function M.goldForRun(stats)
  local rates = M.getDefinitions().gold
  local gold = (stats.enemiesDefeated or 0) * (rates.perKill or 0)
    + (stats.finalLevel or 1) * (rates.perLevel or 0)
  if stats.victoryCondition then
    gold = gold + (rates.victoryBonus or 0) + (stats.victoryBonusGold or 0)
  end
  -- Card gold from kills (Gold Pouch bosses, Bounty Hunter elites)
  gold = gold + (stats.bonusGold or 0)
  -- Gold Pouch and similar cards raise the whole run's gold
  return math.floor(gold * (stats.goldMultiplier or 1))
end

-- Upgrades --------------------------------------------------------------------

--- Find an upgrade definition by id
function M.getUpgrade(id)
  for _, upgrade in ipairs(M.getDefinitions().upgrades) do
    if upgrade.id == id then
      return upgrade
    end
  end
  return nil
end

function M.getUpgrades()
  return M.getDefinitions().upgrades
end

function M.getUpgradeLevel(id)
  return data.get("meta.upgrades." .. id) or 0
end

--- Cost of the next level, or nil when the upgrade is maxed or unknown
function M.getUpgradeCost(id)
  local upgrade = M.getUpgrade(id)
  if not upgrade or type(upgrade.costs) ~= "table" then
    return nil
  end
  return upgrade.costs[M.getUpgradeLevel(id) + 1]
end

--- Buy the next level of an upgrade
-- @param id string Upgrade id
-- @return boolean success
-- @return string|nil reason on failure: "unknown", "maxed", "gold"
function M.purchaseUpgrade(id)
  if not M.getUpgrade(id) then
    return false, "unknown"
  end
  local cost = M.getUpgradeCost(id)
  if not cost then
    return false, "maxed"
  end
  if not M.spendGold(cost) then
    return false, "gold"
  end

  data.set("meta.upgrades." .. id, M.getUpgradeLevel(id) + 1, true)
  return true
end

-- Heroes ----------------------------------------------------------------------

function M.getHeroes()
  return M.getDefinitions().heroes
end

--- Find a hero definition by id
function M.getHero(id)
  for _, hero in ipairs(M.getHeroes()) do
    if hero.id == id then
      return hero
    end
  end
  return nil
end

--- Free heroes are always unlocked; others once bought
function M.isHeroUnlocked(id)
  local hero = M.getHero(id)
  if not hero then
    return false
  end
  return (hero.cost or 0) <= 0 or data.get("meta.heroes." .. id) == true
end

--- Spend gold to unlock a hero
-- @return boolean success
-- @return string|nil reason on failure: "unknown", "unlocked", "gold"
function M.unlockHero(id)
  local hero = M.getHero(id)
  if not hero then
    return false, "unknown"
  end
  if M.isHeroUnlocked(id) then
    return false, "unlocked"
  end
  if not M.spendGold(hero.cost) then
    return false, "gold"
  end

  data.set("meta.heroes." .. id, true, true)
  return true
end

--- The hero picked last time, or the first unlocked hero
function M.getSelectedHeroId()
  local selected = data.get("meta.selectedHero")
  if selected and M.isHeroUnlocked(selected) then
    return selected
  end
  local first = M.getHeroes()[1]
  return first and first.id or nil
end

function M.setSelectedHeroId(id)
  data.set("meta.selectedHero", id, true)
end

-- Run bonuses -----------------------------------------------------------------

--- Bonuses for a run: permanent upgrades, the hero's bonuses, and the
--- equipped cards' passive stats
-- @param heroId string|nil Hero for this run
-- @param cardStats table|nil Passive card stats (card_collection.getRunEffects().stats);
--   only stats listed below are added here
-- @return table { wallHealth, damageMultiplier, cooldownMultiplier, xpMultiplier,
--   lowWallDamageMultiplier, goldMultiplier, startXP, extraProjectiles,
--   extraProjectilePenaltyReduction, extraProjectilePierce, extraAbilitySlots }
function M.getRunBonuses(heroId, cardStats)
  local bonuses = {
    wallHealth = 0,
    damageMultiplier = 1,
    cooldownMultiplier = 1,
    xpMultiplier = 1,
    lowWallDamageMultiplier = 0,  -- extra damage while the wall is below half health
    goldMultiplier = 1,
    startXP = 0,
    extraProjectiles = 0,
    extraProjectilePenaltyReduction = 0,
    extraProjectilePierce = 0,
    extraAbilitySlots = 0,
  }

  for _, upgrade in ipairs(M.getUpgrades()) do
    local level = M.getUpgradeLevel(upgrade.id)
    if level > 0 and type(bonuses[upgrade.stat]) == "number" and type(upgrade.perLevel) == "number" then
      bonuses[upgrade.stat] = bonuses[upgrade.stat] + upgrade.perLevel * level
    end
  end

  local hero = heroId and M.getHero(heroId)
  if hero and type(hero.bonuses) == "table" then
    for stat, amount in pairs(hero.bonuses) do
      if type(bonuses[stat]) == "number" and type(amount) == "number" then
        bonuses[stat] = bonuses[stat] + amount
      end
    end
  end

  for stat, amount in pairs(cardStats or {}) do
    if type(bonuses[stat]) == "number" and type(amount) == "number" then
      bonuses[stat] = bonuses[stat] + amount
    end
  end

  return bonuses
end

return M
