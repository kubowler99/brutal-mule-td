--- Game Scene
-- Main gameplay scene where all game action happens
-- Manages game controller, UI elements, and upgrade selection

local composer = require("composer")
local helpers = require("src.utils.helpers")
local placeholder_graphics = require("src.utils.placeholder_graphics")
local game_controller = require("src.controllers.game_controller")
local game_state = require("src.models.game_state")
local HealthBar = require("src.ui.health_bar")
local XPBar = require("src.ui.xp_bar")
local AbilityIndicator = require("src.ui.ability_indicator")
local UpgradeCard = require("src.ui.upgrade_card")

local scene = composer.newScene()

-- Scene-local variables
local hero = nil
local wall = nil
local healthBar = nil
local xpBar = nil
local levelText = nil
local timeText = nil
local enemyCountText = nil
local abilityIndicators = {}
local upgradePanel = nil
local upgradeCards = {}
local uiUpdateListener = nil
local isGameOver = false

--- Format time as MM:SS
-- @param seconds number Total seconds
-- @return string Formatted time string
local function formatTime(seconds)
  local minutes = math.floor(seconds / 60)
  local secs = math.floor(seconds % 60)
  return string.format("%02d:%02d", minutes, secs)
end

--- Update all UI elements based on current game state
local function updateUI()
  if not hero then
    return
  end
  
  -- Update health bar (wall health)
  if healthBar and wall then
    healthBar:update(wall.health, wall.maxHealth)
  end
  
  -- Update XP bar
  if xpBar then
    xpBar:update(hero.xp, hero.xpRequired)
  end
  
  -- Update level display
  if levelText then
    levelText.text = "Level: " .. tostring(hero.level)
  end
  
  -- Update time display
  if timeText then
    timeText.text = "Time: " .. formatTime(game_state.elapsedTime)
  end
  
  -- Update enemy count
  if enemyCountText then
    enemyCountText.text = "Enemies: " .. tostring(game_state.enemiesDefeated)
  end
  
  -- Update ability indicators
  local currentTime = system.getTimer() / 1000
  for i, indicator in ipairs(abilityIndicators) do
    local ability = hero.abilities[i]
    if ability then
      -- Calculate remaining cooldown
      local timeSinceActivation = currentTime - (ability.lastActivation or 0)
      local remaining = math.max(0, ability.cooldown - timeSinceActivation)
      indicator:updateCooldown(remaining, ability.cooldown)
    end
  end
end

--- Show upgrade panel with upgrade cards
-- @param cards table Array of upgrade card data
local function showUpgradePanel(cards)
  if not upgradePanel then
    return
  end
  
  -- Show upgrade panel
  upgradePanel.isVisible = true
  
  -- Clear existing upgrade cards
  for _, card in ipairs(upgradeCards) do
    card:destroy()
  end
  upgradeCards = {}
  
  -- Create upgrade cards
  local cardWidth = 180
  local cardSpacing = 20
  local startX = helpers.centerX - (cardWidth + cardSpacing)
  local cardY = helpers.centerY
  
  for i, cardData in ipairs(cards) do
    local cardX = startX + (i - 1) * (cardWidth + cardSpacing)
    local card = UpgradeCard:new(cardX, cardY, cardData)
    
    -- Add card to upgrade panel group
    if card.group and upgradePanel then
      upgradePanel:insert(card.group)
    end
    
    -- Set tap handler
    card:onTap(function()
      -- Apply upgrade and hide panel
      game_controller.onUpgradeSelected(cardData)
      hideUpgradePanel()
    end)
    
    table.insert(upgradeCards, card)
  end
end

--- Hide upgrade panel
function hideUpgradePanel()
  if upgradePanel then
    upgradePanel.isVisible = false
  end
  
  -- Clear upgrade cards
  for _, card in ipairs(upgradeCards) do
    card:destroy()
  end
  upgradeCards = {}
end

--- Scene create event
function scene:create(event)
  local sceneGroup = self.view
  
  -- Create background using placeholder graphics
  local background = placeholder_graphics.createBackground(helpers.width, helpers.height)
  sceneGroup:insert(background)
  
  -- NOTE: Game controller initialization moved to scene:show(phase="will")
  -- to support "Play Again" functionality. UI elements are created here once,
  -- but game entities (hero, wall, enemies) are initialized every time the scene appears.
  
  -- Create UI layer
  -- Health bar (top left)
  healthBar = HealthBar:new(100, 30, 180, 20, sceneGroup)
  
  -- XP bar (below health bar)
  xpBar = XPBar:new(100, 60, 180, 15, sceneGroup)
  
  -- Level display (top center)
  levelText = display.newText({
    parent = sceneGroup,
    text = "Level: 1",
    x = helpers.centerX,
    y = 30,
    fontSize = 24,
    font = native.systemFontBold
  })
  levelText:setFillColor(1, 1, 1)
  
  -- Time display (top right)
  timeText = display.newText({
    parent = sceneGroup,
    text = "Time: 00:00",
    x = helpers.width - 100,
    y = 30,
    fontSize = 20
  })
  timeText:setFillColor(1, 1, 1)
  
  -- Enemy count display (below time)
  enemyCountText = display.newText({
    parent = sceneGroup,
    text = "Enemies: 0",
    x = helpers.width - 100,
    y = 60,
    fontSize = 18
  })
  enemyCountText:setFillColor(0.9, 0.9, 0.9)
  
  -- NOTE: Ability indicators are now created in scene:show(phase="did")
  -- after game_controller.initialize() to ensure proper display order
  
  -- Create upgrade panel (hidden by default)
  upgradePanel = display.newGroup()
  sceneGroup:insert(upgradePanel)
  upgradePanel.isVisible = false
  
  -- Upgrade panel background overlay
  local overlay = display.newRect(
    upgradePanel,
    helpers.centerX,
    helpers.centerY,
    helpers.width,
    helpers.height
  )
  overlay:setFillColor(0, 0, 0, 0.8)
  
  -- Upgrade panel title
  local upgradeTitle = display.newText({
    parent = upgradePanel,
    text = "LEVEL UP! Choose an Upgrade",
    x = helpers.centerX,
    y = helpers.centerY - 150,
    fontSize = 32,
    font = native.systemFontBold
  })
  upgradeTitle:setFillColor(1, 1, 0)
  
  -- Set game controller callbacks
  game_controller.onLevelUpCallback = showUpgradePanel
  game_controller.onGameOverCallback = function(stats)
    -- Set game over flag to trigger cleanup in scene:hide()
    isGameOver = true
    
    -- Transition to game over scene with statistics
    composer.gotoScene("src.scenes.gameover", {
      effect = "fade",
      time = 500,
      params = stats
    })
  end
end

--- Scene show event
function scene:show(event)
  local phase = event.phase
  
  if phase == "will" then
    -- Scene is about to appear (still off-screen)
    
    -- CRITICAL FIX: Initialize game controller every time scene appears
    -- This handles the "Play Again" scenario where scene:create() doesn't run
    -- because Composer caches scenes by default
    game_controller.initialize(self.view)
    
    -- Reset hero and wall references
    hero = nil
    wall = nil
    
  elseif phase == "did" then
    -- Scene is fully on-screen
    -- Start game controller
    game_controller.start()
    
    -- Get hero and wall references from game controller
    hero = game_controller.getHero()
    wall = game_controller.getWall()
    
    -- Create ability indicators AFTER game_controller.initialize()
    -- This ensures they are inserted after the wall and render on top
    if #abilityIndicators == 0 then
      -- Position indicators on the wall center (wall spans Y=1160 to Y=1240)
      local indicatorY = 1200  -- Wall center Y-coordinate
      local indicatorSpacing = 120  -- Wider spacing across wall width
      local startX = helpers.centerX - 240  -- Center 5 indicators (480px total width)
      
      for i = 1, 5 do
        local indicatorX = startX + (i - 1) * indicatorSpacing
        local indicator = AbilityIndicator:new(indicatorX, indicatorY, i, self.view)
        table.insert(abilityIndicators, indicator)
      end
    end
    
    -- Set abilities on indicators
    if hero then
      for i, indicator in ipairs(abilityIndicators) do
        local ability = hero.abilities[i]
        if ability then
          indicator:setAbility(ability)
        end
      end
    end
    
    -- Start UI update loop
    uiUpdateListener = Runtime:addEventListener("enterFrame", updateUI)
  end
end

--- Scene hide event
function scene:hide(event)
  local phase = event.phase
  
  if phase == "will" then
    -- Scene is about to disappear (still on-screen)
    
    -- Remove UI update listener first to prevent accessing destroyed entities
    if uiUpdateListener then
      Runtime:removeEventListener("enterFrame", updateUI)
      uiUpdateListener = nil
    end
    
    -- Check if this is a game over transition
    if isGameOver then
      -- Cleanup ability indicators before game controller cleanup
      for _, indicator in ipairs(abilityIndicators) do
        indicator:destroy()
      end
      abilityIndicators = {}
      
      -- Game over: cleanup all entities before transition
      game_controller.cleanup()
      
      -- Reset flag for next game session
      isGameOver = false
    else
      -- Non-game-over transition (e.g., pause): preserve entities
      game_controller.pause()
    end
    
  elseif phase == "did" then
    -- Scene is fully off-screen
    -- Additional cleanup if needed
  end
end

--- Scene destroy event
function scene:destroy(event)
  -- Cleanup game controller
  game_controller.cleanup()
  
  -- Cleanup UI components
  if healthBar then
    healthBar:destroy()
    healthBar = nil
  end
  
  if xpBar then
    xpBar:destroy()
    xpBar = nil
  end
  
  for _, indicator in ipairs(abilityIndicators) do
    indicator:destroy()
  end
  abilityIndicators = {}
  
  for _, card in ipairs(upgradeCards) do
    card:destroy()
  end
  upgradeCards = {}
  
  -- Clear references
  hero = nil
  wall = nil
  levelText = nil
  timeText = nil
  enemyCountText = nil
  upgradePanel = nil
  
  -- Remove UI update listener (if still active)
  if uiUpdateListener then
    Runtime:removeEventListener("enterFrame", updateUI)
    uiUpdateListener = nil
  end
end

-- Add scene event listeners
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
