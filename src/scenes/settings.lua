--- Settings Scene
-- Turn sound effects and music on or off. Each setting is saved in the
-- save data under settings.<key>, where the sound system reads it.

local composer = require("composer")
local helpers = require("src.utils.helpers")
local data = require("src.models.data")
local sound = require("src.systems.sound")

local scene = composer.newScene()

-- Settings shown on this screen, in order
scene.TOGGLES = {
  { key = "soundOn", label = "Sound Effects" },
  { key = "musicOn", label = "Music" },
}

-- Layout
local FIRST_ROW_Y = 420
local ROW_SPACING = 140

-- Toggle button colors
local ON_COLOR = {0.2, 0.6, 0.3}
local OFF_COLOR = {0.45, 0.2, 0.2}

-- Scene variables
local toggleRows = {}  -- { key, button }

--- Whether a setting is on (settings are on unless saved as false)
-- @param key string Setting key, e.g. "soundOn"
-- @return boolean
function scene.isOn(key)
  return data.get("settings." .. key) ~= false
end

--- Update every toggle button's label and color from the save data
function scene.refresh()
  for _, row in ipairs(toggleRows) do
    local on = scene.isOn(row.key)
    if row.button then
      if row.button.label then
        row.button.label.text = on and "ON" or "OFF"
      end
      row.button:setFillColor(unpack(on and ON_COLOR or OFF_COLOR))
    end
  end
end

--- Flip a setting, save it, and refresh the screen
-- @param key string Setting key, e.g. "musicOn"
-- @return boolean The new value
function scene.toggle(key)
  local on = not scene.isOn(key)
  data.set("settings." .. key, on, true)
  if key == "musicOn" and not on then
    sound.stopMusic()
  end
  scene.refresh()
  return on
end

function scene:create(event)
  local sceneGroup = self.view

  helpers.newBackground(sceneGroup, "settings")

  local title = display.newText({
    parent = sceneGroup,
    text = "SETTINGS",
    x = helpers.centerX,
    y = 260,
    font = native.systemFontBold,
    fontSize = 44
  })
  title:setFillColor(1, 1, 1)

  toggleRows = {}
  for i, toggle in ipairs(scene.TOGGLES) do
    local rowY = FIRST_ROW_Y + (i - 1) * ROW_SPACING

    local labelText = display.newText({
      parent = sceneGroup,
      text = toggle.label,
      x = helpers.centerX,
      y = rowY,
      font = native.systemFontBold,
      fontSize = 28
    })
    labelText:setFillColor(1, 1, 1)

    local key = toggle.key
    local button = helpers.newButton({
      x = helpers.centerX,
      y = rowY + 55,
      width = 160,
      height = 52,
      label = "ON",
      fontSize = 22,
      fillColor = ON_COLOR,
      onRelease = function()
        scene.toggle(key)
      end
    })
    sceneGroup:insert(button)
    sceneGroup:insert(button.label)

    table.insert(toggleRows, { key = key, button = button })
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
  toggleRows = {}
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("destroy", scene)

return scene
