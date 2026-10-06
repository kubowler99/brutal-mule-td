-- Card Collection
-- Card packs, the player's card collection, merging, fusion, and the
-- loadout equipped before a run. Definitions come from data/cards.json; the
-- player's cards are saved through src.models.data under "meta.cards":
--   nextUid    number used to build the next card uid ("c1", "c2", ...)
--   instances  uid -> { cardId, level }  (a player can own several copies)
--   loadout    slot ("1".."3") -> uid
--   pity       { rare = packs since a rare-or-better card,
--                legendary = packs since a legendary-or-better card }
--
-- Functions that roll random numbers take an optional rng: a function that
-- returns a number in [0, 1), like math.random(). Tests pass a seeded one.

local data = require("src.models.data")
local meta_progression = require("src.models.meta_progression")

local json = _G.json or require("json")

local M = {}

local SAVE_KEY = "meta.cards"

-- Cached definitions from data/cards.json
local _definitions = nil

local EMPTY_DEFINITIONS = {
  tiers = {}, pack = {}, levels = {}, fusion = {}, loadoutSlots = 0, cards = {},
}

-- Definitions --------------------------------------------------------------

--- Load (once) and return the definitions from data/cards.json
-- @return table { tiers, pack, levels, fusion, loadoutSlots, cards }
function M.getDefinitions()
  if _definitions then
    return _definitions
  end

  local success, decoded = pcall(function()
    local path = system.pathForFile("data/cards.json", system.ResourceDirectory)
    if not path then return nil end
    local file = io.open(path, "r")
    if not file then return nil end
    local contents = file:read("*a")
    file:close()
    return json.decode(contents)
  end)

  if success and type(decoded) == "table" then
    _definitions = {
      tiers = type(decoded.tiers) == "table" and decoded.tiers or {},
      pack = type(decoded.pack) == "table" and decoded.pack or {},
      levels = type(decoded.levels) == "table" and decoded.levels or {},
      fusion = type(decoded.fusion) == "table" and decoded.fusion or {},
      loadoutSlots = type(decoded.loadoutSlots) == "number" and decoded.loadoutSlots or 0,
      cards = type(decoded.cards) == "table" and decoded.cards or {},
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

--- Find a card definition by id
function M.getCard(cardId)
  for _, card in ipairs(M.getDefinitions().cards) do
    if card.id == cardId then
      return card
    end
  end
  return nil
end

--- Card definitions of one tier, in catalog order
function M.getCardsOfTier(tierId)
  local cards = {}
  for _, card in ipairs(M.getDefinitions().cards) do
    if card.tier == tierId then
      table.insert(cards, card)
    end
  end
  return cards
end

--- Position of a tier from lowest (1) to highest, or nil if unknown
function M.tierRank(tierId)
  for i, tier in ipairs(M.getDefinitions().tiers) do
    if tier.id == tierId then
      return i
    end
  end
  return nil
end

--- The tier one step above, or nil for the highest tier
function M.nextTier(tierId)
  local rank = M.tierRank(tierId)
  local tier = rank and M.getDefinitions().tiers[rank + 1]
  return tier and tier.id or nil
end

function M.getPackPrice()
  return M.getDefinitions().pack.price or 0
end

function M.getMaxLevel()
  return M.getDefinitions().levels.max or 1
end

-- Saved state --------------------------------------------------------------

--- The saved card state, created on first use
local function state()
  local saved = data.get(SAVE_KEY)
  if type(saved) ~= "table" then
    saved = {}
    data.set(SAVE_KEY, saved)
  end
  saved.nextUid = saved.nextUid or 1
  saved.instances = saved.instances or {}
  saved.loadout = saved.loadout or {}
  saved.pity = saved.pity or {}
  return saved
end

local function save()
  data.set(SAVE_KEY, state(), true)
end

--- Add a level 1 copy of a card to the collection (does not save)
-- @return string uid
local function addInstance(cardId)
  local saved = state()
  local uid = "c" .. tostring(saved.nextUid)
  saved.nextUid = saved.nextUid + 1
  saved.instances[uid] = { cardId = cardId, level = 1 }
  return uid
end

--- Every owned card as { uid, cardId, level, tier }
function M.getInstances()
  local list = {}
  for uid, instance in pairs(state().instances) do
    local card = M.getCard(instance.cardId)
    table.insert(list, {
      uid = uid, cardId = instance.cardId, level = instance.level, tier = card and card.tier,
    })
  end
  table.sort(list, function(a, b)
    return tonumber(a.uid:sub(2)) < tonumber(b.uid:sub(2))
  end)
  return list
end

--- One owned card as { uid, cardId, level, tier }, or nil
function M.getInstance(uid)
  local instance = uid and state().instances[uid]
  if not instance then
    return nil
  end
  local card = M.getCard(instance.cardId)
  return { uid = uid, cardId = instance.cardId, level = instance.level, tier = card and card.tier }
end

--- Whether a card is in a loadout slot
function M.isEquipped(uid)
  for _, equipped in pairs(state().loadout) do
    if equipped == uid then
      return true
    end
  end
  return false
end

--- How many copies of a card the player owns
function M.countOwned(cardId)
  local count = 0
  for _, instance in pairs(state().instances) do
    if instance.cardId == cardId then
      count = count + 1
    end
  end
  return count
end

--- The owned copy of a card with the highest level (equipped copy wins a tie),
--- or nil if the player owns none
function M.bestInstance(cardId)
  local best = nil
  for _, instance in ipairs(M.getInstances()) do
    if instance.cardId == cardId then
      if not best or instance.level > best.level
        or (instance.level == best.level and M.isEquipped(instance.uid) and not M.isEquipped(best.uid)) then
        best = instance
      end
    end
  end
  return best
end

--- Unequipped cards of a tier that can be sacrificed, lowest level first
-- @param tierId string Tier of the cards
-- @param excludeUid string|nil A card to leave out (the merge target)
-- @return table List of uids
function M.spareCards(tierId, excludeUid)
  local spare = {}
  for _, instance in ipairs(M.getInstances()) do
    if instance.tier == tierId and instance.uid ~= excludeUid and not M.isEquipped(instance.uid) then
      table.insert(spare, instance)
    end
  end
  -- getInstances is in uid order, so a stable sort keeps older cards first
  for i = 2, #spare do
    local current = spare[i]
    local j = i - 1
    while j >= 1 and spare[j].level > current.level do
      spare[j + 1] = spare[j]
      j = j - 1
    end
    spare[j + 1] = current
  end
  local uids = {}
  for i, instance in ipairs(spare) do
    uids[i] = instance.uid
  end
  return uids
end

-- Packs --------------------------------------------------------------------

--- Roll one tier from the tier odds
local function rollTier(rng)
  local roll = rng()
  local cumulative = 0
  local tiers = M.getDefinitions().tiers
  for _, tier in ipairs(tiers) do
    cumulative = cumulative + (tier.odds or 0)
    if roll < cumulative then
      return tier.id
    end
  end
  return tiers[1] and tiers[1].id
end

--- Pick a random card id from a tier
local function rollCard(tierId, rng)
  local cards = M.getCardsOfTier(tierId)
  if #cards == 0 then
    return nil
  end
  return cards[math.min(#cards, math.floor(rng() * #cards) + 1)].id
end

--- Packs opened since the last card of a tier or better (pity counter)
function M.getPityCount(tierId)
  return state().pity[tierId] or 0
end

--- Roll the tiers for one pack, applying pity guarantees
-- @return table List of tier ids
function M.rollPackTiers(rng)
  rng = rng or math.random
  local defs = M.getDefinitions()
  local tiers = {}
  for i = 1, defs.pack.cardsPerPack or 0 do
    tiers[i] = rollTier(rng)
  end

  -- Pity: if this pack ends a dry streak, raise the lowest card to the
  -- guaranteed tier. Check the highest guarantee first.
  local pity = defs.pack.pity or {}
  local ordered = {}
  for _, rule in ipairs(pity) do
    table.insert(ordered, rule)
  end
  table.sort(ordered, function(a, b)
    return (M.tierRank(a.minTier) or 0) > (M.tierRank(b.minTier) or 0)
  end)
  for _, rule in ipairs(ordered) do
    local minRank = M.tierRank(rule.minTier)
    if minRank and #tiers > 0 and M.getPityCount(rule.minTier) >= rule.packs - 1 then
      local best, lowestIndex = 0, 1
      for i, tierId in ipairs(tiers) do
        local rank = M.tierRank(tierId) or 0
        best = math.max(best, rank)
        if rank < (M.tierRank(tiers[lowestIndex]) or 0) then
          lowestIndex = i
        end
      end
      if best < minRank then
        tiers[lowestIndex] = rule.minTier
      end
    end
  end
  return tiers
end

--- Update the pity counters after a pack with these tiers
local function updatePity(tiers)
  local saved = state()
  for _, rule in ipairs(M.getDefinitions().pack.pity or {}) do
    local minRank = M.tierRank(rule.minTier) or math.huge
    local hit = false
    for _, tierId in ipairs(tiers) do
      if (M.tierRank(tierId) or 0) >= minRank then
        hit = true
      end
    end
    saved.pity[rule.minTier] = hit and 0 or M.getPityCount(rule.minTier) + 1
  end
end

--- Spend gold on a pack and add its cards to the collection
-- @param rng function|nil Random function returning [0, 1)
-- @return table|nil List of { uid, cardId, tier } on success
-- @return string|nil Reason on failure: "gold"
function M.buyPack(rng)
  rng = rng or math.random
  if not meta_progression.spendGold(M.getPackPrice()) then
    return nil, "gold"
  end

  local tiers = M.rollPackTiers(rng)
  local opened = {}
  for _, tierId in ipairs(tiers) do
    local cardId = rollCard(tierId, rng)
    if cardId then
      table.insert(opened, { uid = addInstance(cardId), cardId = cardId, tier = tierId })
    end
  end
  updatePity(tiers)
  save()
  return opened
end

-- Merging ------------------------------------------------------------------

--- Cards needed to raise a card from this level to the next, or nil at max
function M.mergeCost(level)
  if type(level) ~= "number" or level < 1 or level >= M.getMaxLevel() then
    return nil
  end
  local target = level + 1
  for _, band in ipairs(M.getDefinitions().levels.mergeCosts or {}) do
    if target <= band.upToLevel then
      return band.cards
    end
  end
  return nil
end

--- Check that a list of uids can be sacrificed together
-- @return boolean ok, string|nil reason, string|nil tier of the cards
local function checkSacrifices(uids, excludeUid)
  local seen = {}
  local tier = nil
  for _, uid in ipairs(uids) do
    local instance = M.getInstance(uid)
    if not instance then
      return false, "unknown"
    end
    if seen[uid] or uid == excludeUid then
      return false, "duplicate"
    end
    if M.isEquipped(uid) then
      return false, "equipped"
    end
    if tier and instance.tier ~= tier then
      return false, "tier"
    end
    tier = instance.tier
    seen[uid] = true
  end
  return true, nil, tier
end

--- Level up a card by sacrificing other cards of the same tier
-- @param targetUid string The card to level up
-- @param sacrificeUids table Exactly mergeCost(level) uids of the same tier
-- @return boolean success
-- @return string|nil reason: "unknown", "maxed", "count", "duplicate",
--   "equipped", "tier"
function M.merge(targetUid, sacrificeUids)
  local target = M.getInstance(targetUid)
  if not target then
    return false, "unknown"
  end
  local cost = M.mergeCost(target.level)
  if not cost then
    return false, "maxed"
  end
  if type(sacrificeUids) ~= "table" or #sacrificeUids ~= cost then
    return false, "count"
  end
  local ok, reason, tier = checkSacrifices(sacrificeUids, targetUid)
  if not ok then
    return false, reason
  end
  if tier ~= target.tier then
    return false, "tier"
  end

  local saved = state()
  for _, uid in ipairs(sacrificeUids) do
    saved.instances[uid] = nil
  end
  saved.instances[targetUid].level = target.level + 1
  save()
  return true
end

--- Level up a card using the lowest-level spare cards of its tier
-- @return boolean success, string|nil reason (as merge, plus "spare")
function M.autoMerge(targetUid)
  local target = M.getInstance(targetUid)
  if not target then
    return false, "unknown"
  end
  local cost = M.mergeCost(target.level)
  if not cost then
    return false, "maxed"
  end
  local spare = M.spareCards(target.tier, targetUid)
  if #spare < cost then
    return false, "spare"
  end
  local sacrifices = {}
  for i = 1, cost do
    sacrifices[i] = spare[i]
  end
  return M.merge(targetUid, sacrifices)
end

-- Fusion -------------------------------------------------------------------

--- Cards of a tier needed for one fusion, or nil if the tier cannot fuse
function M.fusionCost(tierId)
  if not M.nextTier(tierId) then
    return nil
  end
  return M.getDefinitions().fusion[tierId]
end

--- Fuse cards of one tier into a random level 1 card of the next tier
-- @param uids table Exactly fusionCost(tier) uids of the same tier
-- @param rng function|nil Random function returning [0, 1)
-- @return table|nil { uid, cardId, tier } of the new card
-- @return string|nil reason: "unknown", "count", "duplicate", "equipped",
--   "tier", "maxTier"
function M.fuse(uids, rng)
  rng = rng or math.random
  if type(uids) ~= "table" or #uids == 0 then
    return nil, "count"
  end
  local ok, reason, tier = checkSacrifices(uids)
  if not ok then
    return nil, reason
  end
  local cost = M.fusionCost(tier)
  if not cost then
    return nil, "maxTier"
  end
  if #uids ~= cost then
    return nil, "count"
  end
  local nextTier = M.nextTier(tier)
  local cardId = rollCard(nextTier, rng)
  if not cardId then
    return nil, "maxTier"
  end

  local saved = state()
  for _, uid in ipairs(uids) do
    saved.instances[uid] = nil
  end
  local uid = addInstance(cardId)
  save()
  return { uid = uid, cardId = cardId, tier = nextTier }
end

--- Fuse the lowest-level spare cards of a tier
-- @param tierId string Tier to fuse
-- @param excludeUid string|nil A card to keep out of the fusion
-- @param rng function|nil Random function returning [0, 1)
-- @return table|nil new card, string|nil reason (as fuse, plus "spare")
function M.autoFuse(tierId, excludeUid, rng)
  local cost = M.fusionCost(tierId)
  if not cost then
    return nil, "maxTier"
  end
  local spare = M.spareCards(tierId, excludeUid)
  if #spare < cost then
    return nil, "spare"
  end
  local uids = {}
  for i = 1, cost do
    uids[i] = spare[i]
  end
  return M.fuse(uids, rng)
end

-- Loadout ------------------------------------------------------------------

function M.getLoadoutSlots()
  return M.getDefinitions().loadoutSlots or 0
end

--- Equipped uids by slot number (missing entries are empty slots)
function M.getLoadout()
  local loadout = {}
  for slot = 1, M.getLoadoutSlots() do
    local uid = state().loadout[tostring(slot)]
    if uid and state().instances[uid] then
      loadout[slot] = uid
    end
  end
  return loadout
end

--- Equip a card in a slot. A card already in another slot moves.
-- @return boolean success
-- @return string|nil reason: "slot", "unknown"
function M.equip(slot, uid)
  if type(slot) ~= "number" or slot < 1 or slot > M.getLoadoutSlots() or slot % 1 ~= 0 then
    return false, "slot"
  end
  if not M.getInstance(uid) then
    return false, "unknown"
  end
  local saved = state()
  for key, equipped in pairs(saved.loadout) do
    if equipped == uid then
      saved.loadout[key] = nil
    end
  end
  saved.loadout[tostring(slot)] = uid
  save()
  return true
end

--- Empty a loadout slot
function M.unequip(slot)
  state().loadout[tostring(slot)] = nil
  save()
end

-- Run effects --------------------------------------------------------------

--- A scaled value at a card level: base + perLevel * (level - 1)
local function scaled(value, level)
  if type(value) == "number" then
    return value
  end
  if type(value) ~= "table" then
    return 0
  end
  return (value.base or 0) + (value.perLevel or 0) * (level - 1)
end

--- Effects of the equipped cards for a run
-- @return table {
--   stats = { [stat] = total },  -- passive card bonuses, summed
--   actives = { { uid, cardId, action, charges, params } },
--   milestones = { { cardId, level } }  -- reached milestone levels, for run code
-- }
function M.getRunEffects()
  local levels = M.getDefinitions().levels
  local effects = { stats = {}, actives = {}, milestones = {} }

  for slot = 1, M.getLoadoutSlots() do
    local uid = M.getLoadout()[slot]
    local instance = uid and M.getInstance(uid)
    local card = instance and M.getCard(instance.cardId)
    if card then
      local level = instance.level
      local reachedTen = level >= 10

      if card.kind == "passive" then
        for _, effect in ipairs(card.effects or {}) do
          local value = scaled(effect, level)
          -- Level 10 milestone: passive values get their level 1 value again
          if reachedTen and effect.doubleAtLevel10 ~= false then
            value = value + (effect.base or 0)
          end
          effects.stats[effect.stat] = (effects.stats[effect.stat] or 0) + value
        end
      elseif card.kind == "active" then
        local params = {}
        for name, value in pairs(card.params or {}) do
          params[name] = scaled(value, level)
        end
        -- Level 10 milestone: active cards get extra charges
        local charges = (card.charges or 0) + (reachedTen and (levels.level10ExtraCharges or 0) or 0)
        table.insert(effects.actives, {
          uid = uid, cardId = card.id, action = card.action, charges = charges, params = params,
        })
      end

      for _, milestone in ipairs(levels.milestones or {}) do
        if level >= milestone then
          table.insert(effects.milestones, { cardId = card.id, level = milestone })
        end
      end
    end
  end

  return effects
end

return M
