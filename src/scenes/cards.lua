--- Cards Scene
-- Shop: buy card packs with gold and see the 3 cards each pack gives.
-- Collection: browse cards by tier, then open a card to level it up
-- (merge), fuse spare cards into a higher tier, or equip it in the loadout.

local composer = require("composer")
local helpers = require("src.utils.helpers")
local meta_progression = require("src.models.meta_progression")
local card_collection = require("src.models.card_collection")
local card_face = require("src.ui.card_face")

local scene = composer.newScene()

-- Layout
local TAB_Y = 230
local GRID_COLUMNS = 3
local GRID_SPACING_X = 225
local GRID_FIRST_ROW_Y = 470
local GRID_ROW_SPACING = 245
local GRID_CARD_SIZE = 170
local REVEAL_Y = 640
local REVEAL_CARD_SIZE = 200

-- Messages shown when an action fails
local REASON_MESSAGES = {
  gold = "Not enough gold.",
  spare = "Not enough spare cards of this tier.",
  maxed = "This card is already at the maximum level.",
  maxTier = "Mythic cards cannot be fused.",
}

-- Scene state
scene.tab = "shop"          -- "shop" or "collection"
scene.tier = "common"       -- tier shown in the collection
scene.lastPack = nil        -- cards from the last pack bought
scene.detailCardId = nil    -- card open in the detail panel
scene.message = ""          -- feedback line under the shop or detail panel

local goldText
local contentGroup

local function addButton(group, options)
  local button = helpers.newButton(options)
  group:insert(button)
  group:insert(button.label)
  return button
end

local function addText(group, text, x, y, fontSize, color, width)
  local label = display.newText({
    parent = group,
    text = text,
    x = x,
    y = y,
    width = width,
    align = width and "center" or nil,
    font = native.systemFont,
    fontSize = fontSize
  })
  local c = color or {1, 1, 1}
  label:setFillColor(c[1], c[2], c[3])
  return label
end

-- Shop ---------------------------------------------------------------------

--- Odds line, e.g. "Common 75% · Uncommon 15% · ..."
local function oddsLine()
  local parts = {}
  for _, tier in ipairs(card_collection.getDefinitions().tiers) do
    local percent = (tier.odds or 0) * 100
    local text = (percent == math.floor(percent)) and string.format("%d%%", percent)
      or string.format("%.1f%%", percent)
    table.insert(parts, tier.name .. " " .. text)
  end
  return table.concat(parts, "  ")
end

--- Pity line, e.g. "Rare or better within 10 packs"
local function pityLine()
  local parts = {}
  for _, rule in ipairs(card_collection.getDefinitions().pack.pity or {}) do
    local left = rule.packs - card_collection.getPityCount(rule.minTier)
    table.insert(parts, card_face.tierName(rule.minTier) .. "+ within " .. tostring(left) .. " packs")
  end
  return table.concat(parts, "   ")
end

local function buildShop(group)
  local defs = card_collection.getDefinitions()
  addText(group, string.format("Pack: %d cards for %d gold",
    defs.pack.cardsPerPack or 0, card_collection.getPackPrice()), helpers.centerX, 320, 26)
  addText(group, oddsLine(), helpers.centerX, 365, 16, {0.85, 0.85, 0.9}, helpers.width - 40)
  addText(group, pityLine(), helpers.centerX, 400, 16, {1, 0.85, 0.3}, helpers.width - 40)

  if scene.lastPack then
    local count = #scene.lastPack
    for i, opened in ipairs(scene.lastPack) do
      local x = helpers.centerX + (i - (count + 1) / 2) * (REVEAL_CARD_SIZE + 25)
      local face = card_face.new(group, x, REVEAL_Y, { cardId = opened.cardId, size = REVEAL_CARD_SIZE })
      addText(group, card_face.tierName(opened.tier), x, REVEAL_Y + REVEAL_CARD_SIZE / 2 + 20, 18,
        card_face.tierColor(opened.tier))
      face.alpha = 0
      transition.to(face, { alpha = 1, time = 250, delay = (i - 1) * 200 })
    end
  else
    addText(group, "Buy a pack to reveal 3 cards.", helpers.centerX, REVEAL_Y, 22, {0.8, 0.8, 0.85})
  end

  addButton(group, {
    x = helpers.centerX,
    y = 940,
    width = 300,
    height = 64,
    label = "BUY PACK (" .. tostring(card_collection.getPackPrice()) .. ")",
    fontSize = 24,
    fillColor = {0.6, 0.45, 0.15},
    onRelease = function()
      scene.buyPack()
    end
  })
end

--- Buy a pack and show its cards
-- @param rng function|nil Random function (tests pass a seeded one)
-- @return table|nil The opened cards
function scene.buyPack(rng)
  local opened, reason = card_collection.buyPack(rng)
  if opened then
    scene.lastPack = opened
    scene.message = ""
  else
    scene.message = REASON_MESSAGES[reason] or ""
  end
  scene.refresh()
  return opened
end

-- Collection ---------------------------------------------------------------

local function buildTierTabs(group)
  local tiers = card_collection.getDefinitions().tiers
  local width = (helpers.width - 40) / math.max(1, #tiers)
  for i, tier in ipairs(tiers) do
    local tierId = tier.id
    local color = tier.color or {0.5, 0.5, 0.5}
    local selected = tierId == scene.tier
    addButton(group, {
      x = 20 + (i - 0.5) * width,
      y = 310,
      width = width - 8,
      height = 48,
      label = tier.name,
      fontSize = 16,
      fillColor = selected and color or {color[1] * 0.4, color[2] * 0.4, color[3] * 0.4},
      onRelease = function()
        scene.showTier(tierId)
      end
    })
  end
end

local function buildGrid(group)
  for i, card in ipairs(card_collection.getCardsOfTier(scene.tier)) do
    local column = (i - 1) % GRID_COLUMNS
    local row = math.floor((i - 1) / GRID_COLUMNS)
    local x = helpers.centerX + (column - (GRID_COLUMNS - 1) / 2) * GRID_SPACING_X
    local y = GRID_FIRST_ROW_Y + row * GRID_ROW_SPACING
    local owned = card_collection.countOwned(card.id)
    local best = card_collection.bestInstance(card.id)
    local face = card_face.new(group, x, y, {
      cardId = card.id,
      size = GRID_CARD_SIZE,
      level = best and best.level or nil,
      count = owned,
      dimmed = owned == 0,
    })
    local cardId = card.id
    face.frame:addEventListener("tap", function()
      scene.openDetail(cardId)
      return true
    end)
  end
end

local function buildDetail(group)
  local card = card_collection.getCard(scene.detailCardId)
  if not card then
    return
  end
  local best = card_collection.bestInstance(card.id)

  local shade = display.newRect(group, helpers.centerX, helpers.centerY, helpers.width, helpers.height)
  shade:setFillColor(0, 0, 0, 0.85)
  shade:addEventListener("tap", function() return true end)
  shade:addEventListener("touch", function() return true end)

  card_face.new(group, helpers.centerX, 300, { cardId = card.id, size = 220, level = best and best.level })
  addText(group, card_face.tierName(card.tier) .. "  ·  " .. (card.kind == "active" and "Active" or "Passive"),
    helpers.centerX, 445, 20, card_face.tierColor(card.tier))
  addText(group, card.description or "", helpers.centerX, 490, 22, {1, 1, 1}, helpers.width - 80)

  local milestones = card.milestones or {}
  addText(group, "Lv 5: " .. (milestones["5"] or "-"), helpers.centerX, 550, 18, {0.85, 0.85, 0.9}, helpers.width - 80)
  addText(group, "Lv 10: " .. (card.kind == "active" and "+1 charge" or "Level 1 bonus added again"),
    helpers.centerX, 585, 18, {0.85, 0.85, 0.9}, helpers.width - 80)
  addText(group, "Lv 15: " .. (milestones["15"] or "-"), helpers.centerX, 620, 18, {0.85, 0.85, 0.9}, helpers.width - 80)

  local spareForMerge = best and #card_collection.spareCards(card.tier, best.uid) or 0
  local cost = best and card_collection.mergeCost(best.level)
  local ownedLine = "Owned: " .. tostring(card_collection.countOwned(card.id))
  if cost then
    ownedLine = ownedLine .. "   Next level: " .. tostring(cost) .. " " .. card_face.tierName(card.tier)
      .. " cards (" .. tostring(spareForMerge) .. " spare)"
  elseif best then
    ownedLine = ownedLine .. "   Max level"
  end
  addText(group, ownedLine, helpers.centerX, 675, 18, {1, 0.9, 0.5}, helpers.width - 60)

  if best then
    addButton(group, {
      x = helpers.centerX - 150, y = 750, width = 260, height = 56,
      label = "LEVEL UP", fontSize = 22, fillColor = {0.2, 0.55, 0.3},
      onRelease = function() scene.mergeSelected() end
    })
  end

  local fusionCost = card_collection.fusionCost(card.tier)
  if fusionCost then
    addButton(group, {
      x = helpers.centerX + 150, y = 750, width = 260, height = 56,
      label = "FUSE " .. tostring(fusionCost), fontSize = 22, fillColor = {0.45, 0.3, 0.6},
      onRelease = function() scene.fuseSelected() end
    })
  end

  if best then
    addText(group, "Equip in slot:", helpers.centerX, 830, 18, {0.85, 0.85, 0.9})
    local loadout = card_collection.getLoadout()
    for slot = 1, card_collection.getLoadoutSlots() do
      local equippedHere = loadout[slot] == best.uid
      addButton(group, {
        x = helpers.centerX + (slot - 2) * 170, y = 885, width = 150, height = 52,
        label = equippedHere and ("SLOT " .. slot .. " ✓") or ("SLOT " .. slot), fontSize = 20,
        fillColor = equippedHere and {0.2, 0.55, 0.3} or {0.3, 0.35, 0.5},
        onRelease = function() scene.equipSelected(slot) end
      })
    end
  end

  addText(group, scene.message, helpers.centerX, 960, 20, {1, 0.5, 0.4}, helpers.width - 60)

  addButton(group, {
    x = helpers.centerX, y = 1040, width = 200, height = 56,
    label = "CLOSE", fontSize = 22, fillColor = {0.5, 0.5, 0.6},
    onRelease = function() scene.closeDetail() end
  })
end

local function buildCollection(group)
  buildTierTabs(group)
  buildGrid(group)
  if scene.detailCardId then
    buildDetail(group)
  end
end

--- Show the cards of a tier in the collection
function scene.showTier(tierId)
  scene.tier = tierId
  scene.refresh()
end

--- Open the detail panel for a card
function scene.openDetail(cardId)
  scene.detailCardId = cardId
  scene.message = ""
  scene.refresh()
end

function scene.closeDetail()
  scene.detailCardId = nil
  scene.message = ""
  scene.refresh()
end

--- Level up the open card using the lowest-level spare cards of its tier
-- @return boolean success
function scene.mergeSelected()
  local best = card_collection.bestInstance(scene.detailCardId)
  if not best then
    return false
  end
  local ok, reason = card_collection.autoMerge(best.uid)
  scene.message = ok and ("Leveled up to " .. tostring(card_collection.getInstance(best.uid).level) .. "!")
    or (REASON_MESSAGES[reason] or "")
  scene.refresh()
  return ok
end

--- Fuse spare cards of the open card's tier, keeping the open card itself
-- @param rng function|nil Random function (tests pass a seeded one)
-- @return table|nil The new card
function scene.fuseSelected(rng)
  local card = card_collection.getCard(scene.detailCardId)
  if not card then
    return nil
  end
  local best = card_collection.bestInstance(card.id)
  local fused, reason = card_collection.autoFuse(card.tier, best and best.uid, rng)
  if fused then
    scene.message = "Fused into " .. card_collection.getCard(fused.cardId).name .. " ("
      .. card_face.tierName(fused.tier) .. ")!"
  else
    scene.message = REASON_MESSAGES[reason] or ""
  end
  scene.refresh()
  return fused
end

--- Equip the open card (its highest-level copy) in a loadout slot
function scene.equipSelected(slot)
  local best = card_collection.bestInstance(scene.detailCardId)
  if not best then
    return false
  end
  local ok = card_collection.equip(slot, best.uid)
  scene.message = ok and ("Equipped in slot " .. tostring(slot) .. ".") or ""
  scene.refresh()
  return ok
end

-- Scene --------------------------------------------------------------------

--- Switch between "shop" and "collection"
function scene.showTab(tab)
  scene.tab = tab
  scene.detailCardId = nil
  scene.message = ""
  scene.refresh()
end

--- Rebuild the tab content and the gold line
function scene.refresh()
  if goldText then
    goldText.text = "Gold: " .. tostring(meta_progression.getGold())
  end
  if not contentGroup then
    return
  end
  while contentGroup.numChildren > 0 do
    local child = contentGroup[1]
    contentGroup:remove(1)
    if child and child.removeSelf then
      child:removeSelf()
    end
  end
  if scene.tab == "collection" then
    buildCollection(contentGroup)
  else
    buildShop(contentGroup)
    if scene.message ~= "" then
      addText(contentGroup, scene.message, helpers.centerX, 1020, 20, {1, 0.5, 0.4})
    end
  end
end

function scene:create(event)
  local sceneGroup = self.view

  helpers.newBackground(sceneGroup, "cards")

  local title = display.newText({
    parent = sceneGroup,
    text = "CARDS",
    x = helpers.centerX,
    y = 110,
    font = native.systemFontBold,
    fontSize = 44
  })
  title:setFillColor(1, 1, 1)

  goldText = display.newText({
    parent = sceneGroup,
    text = "",
    x = helpers.centerX,
    y = 165,
    font = native.systemFontBold,
    fontSize = 24
  })
  goldText:setFillColor(1, 0.85, 0.3)

  addButton(sceneGroup, {
    x = helpers.centerX - 130, y = TAB_Y, width = 240, height = 56,
    label = "SHOP", fontSize = 22, fillColor = {0.6, 0.45, 0.15},
    onRelease = function() scene.showTab("shop") end
  })
  addButton(sceneGroup, {
    x = helpers.centerX + 130, y = TAB_Y, width = 240, height = 56,
    label = "COLLECTION", fontSize = 22, fillColor = {0.3, 0.35, 0.6},
    onRelease = function() scene.showTab("collection") end
  })

  contentGroup = display.newGroup()
  sceneGroup:insert(contentGroup)

  addButton(sceneGroup, {
    x = helpers.centerX, y = helpers.height - 100, width = 200, height = 56,
    label = "BACK", fontSize = 22, fillColor = {0.5, 0.5, 0.6},
    onRelease = function()
      composer.gotoScene(scene.returnScene or "src.scenes.menu", { effect = "fade", time = 300 })
    end
  })
end

function scene:show(event)
  if event.phase == "will" then
    local params = event.params or {}
    scene.returnScene = params.returnScene
    if params.tab then
      scene.tab = params.tab
    end
    scene.detailCardId = nil
    scene.message = ""
    scene.refresh()
  end
end

function scene:destroy(event)
  goldText = nil
  contentGroup = nil
  scene.lastPack = nil
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("destroy", scene)

return scene
