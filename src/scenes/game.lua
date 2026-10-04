--- Game Scene
-- Main gameplay scene where all game action happens
-- Manages game controller, UI elements, and upgrade selection

local composer = require("composer")
local helpers = require("src.utils.helpers")
local game_controller = require("src.controllers.game_controller")
local game_state = require("src.models.game_state")
local HealthBar = require("src.ui.health_bar")
local XPBar = require("src.ui.xp_bar")
local AbilityIndicator = require("src.ui.ability_indicator")
local UpgradeCard = require("src.ui.upgrade_card")
local stringUtils = require("src.utils.string")
local combat_system = require("src.systems.combat_system")

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
local pauseButton = nil
local pausePanel = nil
local bossBar = nil
local bossLabel = nil
local bossBanner = nil
local isPausedByPlayer = false
-- Set when the session ends (game over or quit) so scene:hide() cleans up entities
local endSessionOnHide = false
-- Hero for the current run; kept so Play Again reuses it
local currentHeroId = nil

local formatTime = stringUtils.formatTime

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
  
  -- Boss health bar, shown while a boss is alive
  if bossBar then
    local boss = game_controller.getActiveBoss()
    bossBar.group.isVisible = boss ~= nil
    if bossLabel then
      bossLabel.isVisible = boss ~= nil
    end
    if boss then
      bossBar:update(boss.health, boss.maxHealth)
    end
  end
  
  -- Update ability indicators
  local currentTime = system.getTimer() / 1000
  local cooldownMultiplier = hero.getStats and hero:getStats().cooldownMultiplier or 1
  for i, indicator in ipairs(abilityIndicators) do
    local ability = hero.abilities[i]
    -- Abilities picked from level-up cards appear here after the scene shows
    if indicator.ability ~= ability then
      indicator:setAbility(ability)
    end
    -- Passive abilities have no cooldown to show
    if ability and ability.cooldown then
      -- Calculate remaining cooldown
      local cooldown = ability.cooldown * cooldownMultiplier
      local timeSinceActivation = currentTime - (ability.lastActivation or 0)
      local remaining = math.max(0, cooldown - timeSinceActivation)
      indicator:updateCooldown(remaining, cooldown)
    end
  end
end

--- Show upgrade panel with upgrade cards
-- @param cards table Array of upgrade card data
local function showUpgradePanel(cards)
  if not upgradePanel then
    return
  end
  
  -- Hide the game layer so no entities (including free-floating health bars)
  -- render above the upgrade overlay. Game is paused during level-up anyway.
  if scene.gameLayer then
    scene.gameLayer.isVisible = false
  end
  
  -- Show upgrade panel and bring to front so it renders above all game entities
  upgradePanel.isVisible = true
  upgradePanel:toFront()
  
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
  
  -- Restore game layer visibility
  if scene.gameLayer then
    scene.gameLayer.isVisible = true
  end
  
  -- Clear upgrade cards
  for _, card in ipairs(upgradeCards) do
    card:destroy()
  end
  upgradeCards = {}
end

--- Show or hide the pause overlay
-- The game layer is hidden while paused so entities never render above the overlay.
-- @param visible boolean Whether the overlay should be shown
local function setPausePanelVisible(visible)
  if pausePanel then
    pausePanel.isVisible = visible
    if visible then
      pausePanel:toFront()
    end
  end
  if scene.gameLayer then
    scene.gameLayer.isVisible = not visible
  end
end

--- Announce a boss with a banner that fades out
-- @param boss table The boss enemy that spawned
function scene.showBossBanner(boss)
  if not bossBanner then
    return
  end
  bossBanner.text = (boss and boss.isFinalBoss) and "FINAL BOSS" or "BOSS INCOMING"
  bossBanner.alpha = 1
  bossBanner.isVisible = true
  bossBanner:toFront()
  transition.to(bossBanner, { delay = 1500, time = 1000, alpha = 0 })
end

--- Pause the game from the pause button
-- Ignored while the level-up panel is open, since the game is already paused there.
-- @return boolean True if the game was paused
function scene.pauseGame()
  if isPausedByPlayer or not hero then
    return false
  end
  if upgradePanel and upgradePanel.isVisible then
    return false
  end
  
  isPausedByPlayer = true
  game_controller.pause()
  setPausePanelVisible(true)
  return true
end

--- Resume the game from the pause overlay
-- @return boolean True if the game was resumed
function scene.resumeGame()
  if not isPausedByPlayer then
    return false
  end
  
  isPausedByPlayer = false
  setPausePanelVisible(false)
  game_controller.resume()
  return true
end

--- Abandon the current run and return to the main menu
-- The run is not recorded in saved stats.
-- @return boolean True if the transition started
function scene.quitToMenu()
  if not isPausedByPlayer then
    return false
  end
  
  isPausedByPlayer = false
  setPausePanelVisible(false)
  endSessionOnHide = true
  composer.gotoScene("src.scenes.menu", {
    effect = "fade",
    time = 300
  })
  return true
end

--- Pause when the app is suspended (home button, incoming call)
-- The player returns to the pause overlay instead of a running game.
-- @param event table Runtime "system" event
function scene.onSystemEvent(event)
  if event.type == "applicationSuspend" then
    scene.pauseGame()
  end
end

--- Scene create event
function scene:create(event)
  local sceneGroup = self.view
  
  -- Battlefield background image
  helpers.newBackground(sceneGroup, "game")
  
  -- Create a game layer for entities (walkers, projectiles, hero, wall)
  -- This layer is inserted BEFORE the UI overlay layer so entities always render behind UI
  scene.gameLayer = display.newGroup()
  sceneGroup:insert(scene.gameLayer)
  
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
  
  -- Boss health bar and label (hidden until a boss spawns)
  bossLabel = display.newText({
    parent = sceneGroup,
    text = "BOSS",
    x = helpers.centerX,
    y = 108,
    fontSize = 16,
    font = native.systemFontBold
  })
  bossLabel:setFillColor(1, 0.4, 0.4)
  bossLabel.isVisible = false
  bossBar = HealthBar:new(helpers.centerX, 125, 400, 14, sceneGroup)
  bossBar.group.isVisible = false
  
  -- Boss announcement banner (hidden until a boss spawns)
  bossBanner = display.newText({
    parent = sceneGroup,
    text = "BOSS INCOMING",
    x = helpers.centerX,
    y = helpers.centerY - 200,
    fontSize = 44,
    font = native.systemFontBold
  })
  bossBanner:setFillColor(1, 0.3, 0.3)
  bossBanner.isVisible = false
  
  -- Pause button (top center, below the level display)
  pauseButton = helpers.newButton({
    x = helpers.centerX,
    y = 75,
    width = 60,
    height = 36,
    label = "II",
    fontSize = 20,
    fillColor = {0.3, 0.3, 0.4},
    onRelease = function()
      scene.pauseGame()
    end
  })
  sceneGroup:insert(pauseButton)
  sceneGroup:insert(pauseButton.label)
  
  -- Pause panel (hidden by default)
  pausePanel = display.newGroup()
  sceneGroup:insert(pausePanel)
  pausePanel.isVisible = false
  
  local pauseOverlay = display.newRect(
    pausePanel,
    helpers.centerX,
    helpers.centerY,
    helpers.width,
    helpers.height
  )
  pauseOverlay:setFillColor(0, 0, 0, 0.8)
  -- Swallow touches so taps do not reach the pause button underneath
  pauseOverlay:addEventListener("touch", function() return true end)
  
  local pauseTitle = display.newText({
    parent = pausePanel,
    text = "PAUSED",
    x = helpers.centerX,
    y = helpers.centerY - 150,
    fontSize = 48,
    font = native.systemFontBold
  })
  pauseTitle:setFillColor(1, 1, 1)
  
  local resumeButton = helpers.newButton({
    x = helpers.centerX,
    y = helpers.centerY,
    width = 220,
    height = 60,
    label = "RESUME",
    fontSize = 24,
    onRelease = function()
      scene.resumeGame()
    end
  })
  pausePanel:insert(resumeButton)
  pausePanel:insert(resumeButton.label)
  
  local quitButton = helpers.newButton({
    x = helpers.centerX,
    y = helpers.centerY + 80,
    width = 220,
    height = 60,
    label = "QUIT TO MENU",
    fontSize = 24,
    fillColor = {0.5, 0.5, 0.6},
    onRelease = function()
      scene.quitToMenu()
    end
  })
  pausePanel:insert(quitButton)
  pausePanel:insert(quitButton.label)
  
  -- Set game controller callbacks
  game_controller.onLevelUpCallback = showUpgradePanel
  game_controller.onBossSpawnedCallback = scene.showBossBanner
  game_controller.onGameOverCallback = function(stats)
    -- End the session so scene:hide() cleans up entities
    endSessionOnHide = true
    
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
    -- Hero select passes the hero; Play Again keeps the last one
    if event.params and event.params.heroId then
      currentHeroId = event.params.heroId
    end
    game_controller.initialize(scene.gameLayer, currentHeroId)
    
    -- A new session never starts paused
    isPausedByPlayer = false
    setPausePanelVisible(false)
    
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
        local indicator = AbilityIndicator:new(indicatorX, indicatorY, i, scene.gameLayer)
        table.insert(abilityIndicators, indicator)
      end
    end

    -- Pass indicator positions to combat system for fire origin resolution
    combat_system.setIndicatorPositions(abilityIndicators)
    
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
    
    -- Auto-pause when the app is suspended
    Runtime:addEventListener("system", scene.onSystemEvent)
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
    Runtime:removeEventListener("system", scene.onSystemEvent)
    
    -- Check if the session ended (game over or quit to menu)
    if endSessionOnHide then
      -- Cleanup ability indicators before game controller cleanup
      for _, indicator in ipairs(abilityIndicators) do
        indicator:destroy()
      end
      abilityIndicators = {}
      
      -- Game over: cleanup all entities before transition
      game_controller.cleanup()
      
      -- Reset flag for next game session
      endSessionOnHide = false
    else
      -- Session continues (e.g., an overlay scene): preserve entities
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
  if bossBar then
    bossBar:destroy()
    bossBar = nil
  end
  bossLabel = nil
  bossBanner = nil
  pauseButton = nil
  pausePanel = nil
  isPausedByPlayer = false
  
  -- Remove UI update listener (if still active)
  if uiUpdateListener then
    Runtime:removeEventListener("enterFrame", updateUI)
    uiUpdateListener = nil
  end
  Runtime:removeEventListener("system", scene.onSystemEvent)
end

-- Add scene event listeners
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
