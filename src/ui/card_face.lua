--- CardFace UI Component
-- Draws one card: a tier frame, the card's power icon, its name, and an
-- optional level and copy count. Falls back to a tier-colored rectangle when
-- the frame or icon image is missing.

local card_collection = require("src.models.card_collection")

local M = {}

M.FRAME_PATH = "assets/images/cards/frame_%s.png"
M.ICON_PATH = "assets/images/cards/icons/%s.png"

-- Fallback colors when a tier has no color in data/cards.json
local DEFAULT_TIER_COLOR = {0.7, 0.7, 0.7}

--- Color of a tier from data/cards.json
-- @param tierId string
-- @return table { r, g, b }
function M.tierColor(tierId)
  for _, tier in ipairs(card_collection.getDefinitions().tiers) do
    if tier.id == tierId and type(tier.color) == "table" then
      return tier.color
    end
  end
  return DEFAULT_TIER_COLOR
end

--- Display name of a tier
function M.tierName(tierId)
  for _, tier in ipairs(card_collection.getDefinitions().tiers) do
    if tier.id == tierId then
      return tier.name or tierId
    end
  end
  return tierId or ""
end

--- Create a card face
-- @param parent table Display group to insert into
-- @param x number Center x
-- @param y number Center y (center of the frame; the name sits below it)
-- @param options table {
--   cardId = string,      -- card to draw
--   size = number,        -- frame width and height (default 170)
--   level = number|nil,   -- shows "Lv N" when set
--   count = number|nil,   -- shows "xN" when set
--   dimmed = boolean|nil  -- draws an unowned card faded
-- }
-- @return table Display group with fields frame, icon, nameText, levelText, countText
function M.new(parent, x, y, options)
  options = options or {}
  local size = options.size or 170
  local card = card_collection.getCard(options.cardId)
  local tierId = card and card.tier or "common"

  local group = display.newGroup()
  if parent then
    parent:insert(group)
  end
  group.x = x
  group.y = y
  group.cardId = options.cardId

  group.frame = display.newImageRect(group, string.format(M.FRAME_PATH, tierId), size, size)
  if not group.frame then
    local color = M.tierColor(tierId)
    group.frame = display.newRoundedRect(group, 0, 0, size, size, 10)
    group.frame:setFillColor(0.12, 0.12, 0.16)
    group.frame.strokeWidth = 4
    group.frame:setStrokeColor(color[1], color[2], color[3])
  end

  -- The frame image is a portrait card centered in a square: the art window
  -- is the upper part and the name plaque the lower part
  local iconSize = size * 0.42
  group.icon = display.newImageRect(group, string.format(M.ICON_PATH, options.cardId or ""), iconSize, iconSize)
  if group.icon then
    group.icon.x = 0
    group.icon.y = -size * 0.14
  end

  group.nameText = display.newText({
    parent = group,
    text = card and card.name or "?",
    x = 0,
    y = size * 0.29,
    width = size * 0.56,
    align = "center",
    font = native.systemFontBold,
    fontSize = math.max(12, math.floor(size * 0.09))
  })
  group.nameText:setFillColor(1, 1, 1)

  if options.level then
    group.levelText = display.newText({
      parent = group,
      text = "Lv " .. tostring(options.level),
      x = options.count and -size * 0.2 or 0,
      y = size * 0.5 + 10,
      font = native.systemFontBold,
      fontSize = math.max(11, math.floor(size * 0.08))
    })
    group.levelText:setFillColor(1, 0.9, 0.5)
  end

  if options.count then
    group.countText = display.newText({
      parent = group,
      text = "x" .. tostring(options.count),
      x = options.level and size * 0.2 or 0,
      y = size * 0.5 + 10,
      font = native.systemFontBold,
      fontSize = math.max(11, math.floor(size * 0.08))
    })
    group.countText:setFillColor(1, 1, 1)
  end

  if options.dimmed then
    group.alpha = 0.35
  end

  return group
end

return M
