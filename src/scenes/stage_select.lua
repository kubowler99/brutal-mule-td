--- Stage Select Scene
-- Lists the stages from data/stages.json. Unlocked stages go on to hero
-- select; locked ones say which stage to win first.

local composer = require("composer")
local helpers = require("src.utils.helpers")
local stages = require("src.models.stages")

local scene = composer.newScene()

-- Layout
local FIRST_ROW_Y = 270
local ROW_SPACING = 165

-- Scene variables
local stageRows = {}  -- { stageId, button }

--- Multiplier text, e.g. "x1.25"
local function multiplier(value)
  local text = string.format("%.2f", value or 1):gsub("0+$", ""):gsub("%.$", "")
  return "x" .. text
end

--- Info line under a stage name
function scene.infoLine(stage)
  return "Enemies " .. multiplier(stage.enemyMultiplier) .. "   Gold " .. multiplier(stage.goldMultiplier)
    .. "   Bosses: " .. table.concat(stages.getBossNames(stage), ", ")
end

--- Button label: PLAY when unlocked, otherwise which stage to win first
function scene.buttonLabel(stage)
  if stages.isUnlocked(stage.id) then
    return "PLAY"
  end
  local required = stage.unlockedBy and stages.getStage(stage.unlockedBy)
  return "Win " .. (required and required.name or "the previous stage")
end

--- Pick a stage and go on to hero select
-- @return boolean True if the stage is unlocked
function scene.selectStage(stageId)
  if not stages.isUnlocked(stageId) then
    return false
  end
  stages.setSelectedStageId(stageId)
  composer.gotoScene("src.scenes.hero_select", {
    effect = "fade",
    time = 300,
    params = { stageId = stageId }
  })
  return true
end

--- Update every button after a stage is unlocked
function scene.refresh()
  for _, row in ipairs(stageRows) do
    local stage = stages.getStage(row.stageId)
    if stage and row.button then
      local unlocked = stages.isUnlocked(stage.id)
      row.button.label.text = scene.buttonLabel(stage)
      row.button:setFillColor(unpack(unlocked and {0.2, 0.5, 1} or {0.35, 0.35, 0.4}))
    end
  end
end

function scene:create(event)
  local sceneGroup = self.view

  helpers.newBackground(sceneGroup, "menu")
  local shade = display.newRect(sceneGroup, helpers.centerX, helpers.centerY, helpers.width, helpers.height)
  shade:setFillColor(0, 0, 0, 0.55)

  local title = display.newText({
    parent = sceneGroup,
    text = "CHOOSE A STAGE",
    x = helpers.centerX,
    y = 150,
    font = native.systemFontBold,
    fontSize = 40
  })
  title:setFillColor(1, 1, 1)

  stageRows = {}
  for i, stage in ipairs(stages.getStages()) do
    local rowY = FIRST_ROW_Y + (i - 1) * ROW_SPACING

    local nameText = display.newText({
      parent = sceneGroup,
      text = tostring(i) .. ". " .. (stage.name or stage.id),
      x = helpers.centerX,
      y = rowY,
      font = native.systemFontBold,
      fontSize = 28
    })
    nameText:setFillColor(1, 1, 1)

    local infoText = display.newText({
      parent = sceneGroup,
      text = scene.infoLine(stage),
      x = helpers.centerX,
      y = rowY + 38,
      width = helpers.width - 60,
      align = "center",
      font = native.systemFont,
      fontSize = 17
    })
    infoText:setFillColor(0.85, 0.85, 0.9)

    local stageId = stage.id
    local unlocked = stages.isUnlocked(stageId)
    local button = helpers.newButton({
      x = helpers.centerX,
      y = rowY + 95,
      width = 300,
      height = 50,
      label = scene.buttonLabel(stage),
      fontSize = 20,
      fillColor = unlocked and {0.2, 0.5, 1} or {0.35, 0.35, 0.4},
      onRelease = function()
        scene.selectStage(stageId)
      end
    })
    sceneGroup:insert(button)
    sceneGroup:insert(button.label)

    table.insert(stageRows, { stageId = stageId, button = button })
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
  stageRows = {}
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("destroy", scene)

return scene
