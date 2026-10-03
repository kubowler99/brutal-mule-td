--- Upgrades Scene
-- Spend gold on permanent upgrades from data/meta.json. Each upgrade has
-- levels with rising costs; bonuses apply at the start of every run.

local composer = require("composer")
local helpers = require("src.utils.helpers")
local meta_progression = require("src.models.meta_progression")

local scene = composer.newScene()

-- Layout
local FIRST_ROW_Y = 300
local ROW_SPACING = 200

-- Scene variables
local goldText
local upgradeRows = {}  -- { upgradeId, nameText, button }

--- Name line with the current level, e.g. "Thick Walls  Lv 2/5"
local function upgradeNameLine(upgrade)
  local maxLevel = type(upgrade.costs) == "table" and #upgrade.costs or 0
  return (upgrade.name or upgrade.id) .. "  Lv " .. tostring(meta_progression.getUpgradeLevel(upgrade.id))
    .. "/" .. tostring(maxLevel)
end

--- Button label: the next level's price, or MAXED
local function upgradeButtonLabel(upgrade)
  local cost = meta_progression.getUpgradeCost(upgrade.id)
  if not cost then
    return "MAXED"
  end
  return "BUY (" .. tostring(cost) .. " gold)"
end

--- Update gold, levels, and prices after a purchase
function scene.refresh()
  if goldText then
    goldText.text = "Gold: " .. tostring(meta_progression.getGold())
  end
  for _, row in ipairs(upgradeRows) do
    local upgrade = meta_progression.getUpgrade(row.upgradeId)
    if upgrade then
      row.nameText.text = upgradeNameLine(upgrade)
      if row.button and row.button.label then
        row.button.label.text = upgradeButtonLabel(upgrade)
      end
    end
  end
end

--- Buy the next level of an upgrade and refresh the screen
-- @param upgradeId string Upgrade id
-- @return boolean True if the purchase went through
function scene.buyUpgrade(upgradeId)
  local bought = meta_progression.purchaseUpgrade(upgradeId)
  scene.refresh()
  return bought
end

function scene:create(event)
  local sceneGroup = self.view

  local background = display.newRect(sceneGroup, helpers.centerX, helpers.centerY, helpers.width, helpers.height)
  background:setFillColor(0.1, 0.1, 0.2)

  local title = display.newText({
    parent = sceneGroup,
    text = "UPGRADES",
    x = helpers.centerX,
    y = 150,
    font = native.systemFontBold,
    fontSize = 44
  })
  title:setFillColor(1, 1, 1)

  goldText = display.newText({
    parent = sceneGroup,
    text = "",
    x = helpers.centerX,
    y = 210,
    font = native.systemFontBold,
    fontSize = 24
  })
  goldText:setFillColor(1, 0.85, 0.3)

  upgradeRows = {}
  for i, upgrade in ipairs(meta_progression.getUpgrades()) do
    local rowY = FIRST_ROW_Y + (i - 1) * ROW_SPACING

    local nameText = display.newText({
      parent = sceneGroup,
      text = upgradeNameLine(upgrade),
      x = helpers.centerX,
      y = rowY,
      font = native.systemFontBold,
      fontSize = 28
    })

    local descriptionText = display.newText({
      parent = sceneGroup,
      text = upgrade.description or "",
      x = helpers.centerX,
      y = rowY + 40,
      font = native.systemFont,
      fontSize = 20
    })
    descriptionText:setFillColor(0.85, 0.85, 0.9)

    local upgradeId = upgrade.id
    local button = helpers.newButton({
      x = helpers.centerX,
      y = rowY + 105,
      width = 260,
      height = 52,
      label = upgradeButtonLabel(upgrade),
      fontSize = 22,
      onRelease = function()
        scene.buyUpgrade(upgradeId)
      end
    })
    sceneGroup:insert(button)
    sceneGroup:insert(button.label)

    table.insert(upgradeRows, { upgradeId = upgradeId, nameText = nameText, button = button })
  end

  local backButton = helpers.newButton({
    x = helpers.centerX,
    y = helpers.height - 100,
    width = 200,
    height = 56,
    label = "BACK",
    fontSize = 22,
    fillColor = {0.5, 0.5, 0.6},
    onRelease = function()
      composer.gotoScene("src.scenes.menu", { effect = "fade", time = 300 })
    end
  })
  sceneGroup:insert(backButton)
  sceneGroup:insert(backButton.label)
end

function scene:show(event)
  if event.phase == "will" then
    scene.refresh()
  end
end

function scene:destroy(event)
  goldText = nil
  upgradeRows = {}
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("destroy", scene)

return scene
