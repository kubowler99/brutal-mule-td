--- Game Over Scene
-- Displays final statistics after hero death
-- Shows survival time, enemies defeated, and final level
-- Provides options to play again or return to main menu

local composer = require("composer")
local helpers = require("src.utils.helpers")
local data = require("src.models.data")

local scene = composer.newScene()

-- Scene variables
local background
local titleText
local survivalTimeText
local enemiesDefeatedText
local finalLevelText
local playAgainButton
local mainMenuButton

-- Statistics received from game scene
local stats = nil

--- Format time as MM:SS
-- @param seconds number Total seconds
-- @return string Formatted time string
local function formatTime(seconds)
  local minutes = math.floor(seconds / 60)
  local secs = math.floor(seconds % 60)
  return string.format("%02d:%02d", minutes, secs)
end

--- Scene create event
function scene:create(event)
  local sceneGroup = self.view
  
  -- Background
  background = display.newRect(
    sceneGroup,
    helpers.centerX,
    helpers.centerY,
    helpers.width,
    helpers.height
  )
  background:setFillColor(0.1, 0.1, 0.15)
  
  -- Title
  titleText = display.newText({
    parent = sceneGroup,
    text = "GAME OVER",
    x = helpers.centerX,
    y = 150,
    font = native.systemFontBold,
    fontSize = 56
  })
  titleText:setFillColor(1, 0.3, 0.3)
  
  -- Statistics display area
  local statsY = 300
  local statsSpacing = 60
  
  -- Survival time
  survivalTimeText = display.newText({
    parent = sceneGroup,
    text = "Survival Time: 00:00",
    x = helpers.centerX,
    y = statsY,
    font = native.systemFont,
    fontSize = 28
  })
  survivalTimeText:setFillColor(1, 1, 1)
  
  -- Enemies defeated
  enemiesDefeatedText = display.newText({
    parent = sceneGroup,
    text = "Enemies Defeated: 0",
    x = helpers.centerX,
    y = statsY + statsSpacing,
    font = native.systemFont,
    fontSize = 28
  })
  enemiesDefeatedText:setFillColor(1, 1, 1)
  
  -- Final level
  finalLevelText = display.newText({
    parent = sceneGroup,
    text = "Final Level: 1",
    x = helpers.centerX,
    y = statsY + statsSpacing * 2,
    font = native.systemFont,
    fontSize = 28
  })
  finalLevelText:setFillColor(1, 1, 1)
  
  -- Play Again button (handler will be added in show phase)
  playAgainButton = helpers.newButton({
    x = helpers.centerX,
    y = helpers.centerY + 200,
    width = 220,
    height = 60,
    label = "PLAY AGAIN",
    fontSize = 24
  })
  sceneGroup:insert(playAgainButton)
  sceneGroup:insert(playAgainButton.label)
  
  -- Main Menu button (handler will be added in show phase)
  mainMenuButton = helpers.newButton({
    x = helpers.centerX,
    y = helpers.centerY + 280,
    width = 220,
    height = 60,
    label = "MAIN MENU",
    fontSize = 24,
    fillColor = {0.5, 0.5, 0.6}
  })
  sceneGroup:insert(mainMenuButton)
  sceneGroup:insert(mainMenuButton.label)
end

--- Scene show event
function scene:show(event)
  local phase = event.phase
  
  if phase == "will" then
    -- Receive statistics from event.params
    stats = event.params or {}
    
    -- Update statistics display
    if survivalTimeText then
      local survivalTime = stats.survivalTime or stats.elapsedTime or 0
      survivalTimeText.text = "Survival Time: " .. formatTime(survivalTime)
    end
    
    if enemiesDefeatedText then
      local enemiesDefeated = stats.enemiesDefeated or 0
      enemiesDefeatedText.text = "Enemies Defeated: " .. tostring(enemiesDefeated)
    end
    
    if finalLevelText then
      local finalLevel = stats.finalLevel or stats.level or 1
      finalLevelText.text = "Final Level: " .. tostring(finalLevel)
    end
    
    -- Save statistics to persistent data
    local survivalTime = stats.survivalTime or stats.elapsedTime or 0
    local enemiesDefeated = stats.enemiesDefeated or 0
    local finalLevel = stats.finalLevel or stats.level or 1
    
    -- Increment games played
    local gamesPlayed = (data.get("stats.gamesPlayed") or 0) + 1
    data.set("stats.gamesPlayed", gamesPlayed)
    
    -- Update highest level if current is higher
    local highestLevel = data.get("stats.highestLevel") or 1
    if finalLevel > highestLevel then
      data.set("stats.highestLevel", finalLevel)
    end
    
    -- Update longest survival if current is longer
    local longestSurvival = data.get("stats.longestSurvival") or 0
    if survivalTime > longestSurvival then
      data.set("stats.longestSurvival", survivalTime)
    end
    
    -- Add to total enemies defeated
    local totalEnemiesDefeated = (data.get("stats.totalEnemiesDefeated") or 0) + enemiesDefeated
    data.set("stats.totalEnemiesDefeated", totalEnemiesDefeated)
    
    -- Persist all changes
    data.save()
    
  elseif phase == "did" then
    -- Add button tap handlers when scene is fully visible
    local function onPlayAgainTap(event)
      composer.gotoScene("src.scenes.game", {
        effect = "fade",
        time = 300
      })
      return true
    end
    
    local function onMainMenuTap(event)
      composer.gotoScene("src.scenes.menu", {
        effect = "fade",
        time = 300
      })
      return true
    end
    
    -- Store listener references for cleanup
    playAgainButton._tapListener = onPlayAgainTap
    mainMenuButton._tapListener = onMainMenuTap
    
    playAgainButton:addEventListener("tap", onPlayAgainTap)
    mainMenuButton:addEventListener("tap", onMainMenuTap)
  end
end

--- Scene hide event
function scene:hide(event)
  local phase = event.phase
  
  if phase == "will" then
    -- Remove button listeners before scene transitions
    if playAgainButton and playAgainButton._tapListener then
      playAgainButton:removeEventListener("tap", playAgainButton._tapListener)
      playAgainButton._tapListener = nil
    end
    
    if mainMenuButton and mainMenuButton._tapListener then
      mainMenuButton:removeEventListener("tap", mainMenuButton._tapListener)
      mainMenuButton._tapListener = nil
    end
  elseif phase == "did" then
    -- Code here runs when scene is off screen
  end
end

--- Scene destroy event
function scene:destroy(event)
  -- Clean up scene resources
  -- Display objects are automatically cleaned up by Composer when in sceneGroup
  -- Nil out references
  background = nil
  titleText = nil
  survivalTimeText = nil
  enemiesDefeatedText = nil
  finalLevelText = nil
  playAgainButton = nil
  mainMenuButton = nil
  stats = nil
end

-- Scene event listeners
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
