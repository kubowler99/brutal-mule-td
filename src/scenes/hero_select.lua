--- Hero Select Scene
-- Lists heroes from data/meta.json. Unlocked heroes start a run; locked
-- heroes can be bought with gold.

local composer = require("composer")
local helpers = require("src.utils.helpers")
local meta_progression = require("src.models.meta_progression")

local scene = composer.newScene()

-- Layout
local FIRST_ROW_Y = 330
local ROW_SPACING = 230

-- Scene variables
local goldText
local heroRows = {}  -- { heroId, nameText, button }

--- Button label for a hero: PLAY when unlocked, otherwise its price
local function heroButtonLabel(hero)
  if meta_progression.isHeroUnlocked(hero.id) then
    return "PLAY"
  end
  return "UNLOCK (" .. tostring(hero.cost) .. " gold)"
end

--- Update gold and every hero button after a purchase
function scene.refresh()
  if goldText then
    goldText.text = "Gold: " .. tostring(meta_progression.getGold())
  end
  for _, row in ipairs(heroRows) do
    local hero = meta_progression.getHero(row.heroId)
    if hero and row.button and row.button.label then
      row.button.label.text = heroButtonLabel(hero)
    end
  end
end

--- Start a run with an unlocked hero, or try to buy a locked one
-- @param heroId string Hero id
-- @return boolean True if a run started
function scene.selectHero(heroId)
  if meta_progression.isHeroUnlocked(heroId) then
    meta_progression.setSelectedHeroId(heroId)
    composer.gotoScene("src.scenes.game", {
      effect = "fade",
      time = 300,
      params = { heroId = heroId }
    })
    return true
  end

  meta_progression.unlockHero(heroId)
  scene.refresh()
  return false
end

function scene:create(event)
  local sceneGroup = self.view

  local background = display.newRect(sceneGroup, helpers.centerX, helpers.centerY, helpers.width, helpers.height)
  background:setFillColor(0.1, 0.1, 0.2)

  local title = display.newText({
    parent = sceneGroup,
    text = "CHOOSE YOUR HERO",
    x = helpers.centerX,
    y = 150,
    font = native.systemFontBold,
    fontSize = 40
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

  heroRows = {}
  for i, hero in ipairs(meta_progression.getHeroes()) do
    local rowY = FIRST_ROW_Y + (i - 1) * ROW_SPACING

    local nameText = display.newText({
      parent = sceneGroup,
      text = hero.name or hero.id,
      x = helpers.centerX,
      y = rowY,
      font = native.systemFontBold,
      fontSize = 30
    })
    if type(hero.color) == "table" then
      nameText:setFillColor(hero.color[1], hero.color[2], hero.color[3])
    end

    local descriptionText = display.newText({
      parent = sceneGroup,
      text = hero.description or "",
      x = helpers.centerX,
      y = rowY + 45,
      width = helpers.width - 80,
      align = "center",
      font = native.systemFont,
      fontSize = 20
    })
    descriptionText:setFillColor(0.85, 0.85, 0.9)

    local heroId = hero.id
    local button = helpers.newButton({
      x = helpers.centerX,
      y = rowY + 120,
      width = 300,
      height = 56,
      label = heroButtonLabel(hero),
      fontSize = 22,
      onRelease = function()
        scene.selectHero(heroId)
      end
    })
    sceneGroup:insert(button)
    sceneGroup:insert(button.label)

    table.insert(heroRows, { heroId = heroId, nameText = nameText, button = button })
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
  heroRows = {}
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("destroy", scene)

return scene
