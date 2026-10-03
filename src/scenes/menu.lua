local composer = require("composer")
local helpers = require("src.utils.helpers")
local data = require("src.models.data")
local stringUtils = require("src.utils.string")
local meta_progression = require("src.models.meta_progression")

local scene = composer.newScene()

-- Scene variables
local background
local titleText
local bestRunText
local goldText
local playButton
local upgradesButton

-- Scene lifecycle functions

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
    background:setFillColor(0.1, 0.1, 0.2)
    
    -- Title
    titleText = display.newText({
        parent = sceneGroup,
        text = "Arcane Survivor",
        x = helpers.centerX,
        y = 200,
        font = native.systemFontBold,
        fontSize = 48
    })
    
    -- Best run from saved stats (filled in on show so it updates after each game)
    bestRunText = display.newText({
        parent = sceneGroup,
        text = "",
        x = helpers.centerX,
        y = 280,
        font = native.systemFont,
        fontSize = 24
    })
    bestRunText:setFillColor(0.8, 0.8, 0.9)
    
    -- Gold for permanent upgrades and heroes (filled in on show)
    goldText = display.newText({
        parent = sceneGroup,
        text = "",
        x = helpers.centerX,
        y = 320,
        font = native.systemFontBold,
        fontSize = 24
    })
    goldText:setFillColor(1, 0.85, 0.3)
    
    -- Play button (handler will be added in show phase)
    playButton = helpers.newButton({
        x = helpers.centerX,
        y = helpers.centerY,
        width = 200,
        height = 60,
        label = "PLAY",
        fontSize = 24
    })
    sceneGroup:insert(playButton)
    sceneGroup:insert(playButton.label)
    
    -- Upgrades button: spend gold on permanent upgrades
    upgradesButton = helpers.newButton({
        x = helpers.centerX,
        y = helpers.centerY + 80,
        width = 200,
        height = 60,
        label = "UPGRADES",
        fontSize = 24,
        fillColor = {0.6, 0.5, 0.2}
    })
    sceneGroup:insert(upgradesButton)
    sceneGroup:insert(upgradesButton.label)
end

function scene:show(event)
    local phase = event.phase
    
    if phase == "will" then
        -- Show the best run once at least one game has been played
        if bestRunText then
            local gamesPlayed = data.get("stats.gamesPlayed") or 0
            if gamesPlayed > 0 then
                local highestLevel = data.get("stats.highestLevel") or 1
                local longestSurvival = data.get("stats.longestSurvival") or 0
                bestRunText.text = "Best: Level " .. tostring(highestLevel) ..
                    "  |  " .. stringUtils.formatTime(longestSurvival)
            else
                bestRunText.text = ""
            end
        end
        
        if goldText then
            goldText.text = "Gold: " .. tostring(meta_progression.getGold())
        end
    elseif phase == "did" then
        -- Add button tap handlers when scene is fully visible
        -- PLAY opens hero select, which starts the run
        local function onPlayTap(event)
            composer.gotoScene("src.scenes.hero_select", {
                effect = "fade",
                time = 300
            })
            return true
        end
        
        local function onUpgradesTap(event)
            composer.gotoScene("src.scenes.upgrades", {
                effect = "fade",
                time = 300
            })
            return true
        end
        
        -- Store listener references for cleanup
        playButton._tapListener = onPlayTap
        playButton:addEventListener("tap", onPlayTap)
        upgradesButton._tapListener = onUpgradesTap
        upgradesButton:addEventListener("tap", onUpgradesTap)
    end
end

function scene:hide(event)
    local phase = event.phase
    
    if phase == "will" then
        -- Remove button listeners before scene transitions
        for _, button in ipairs({ playButton, upgradesButton }) do
            if button and button._tapListener then
                button:removeEventListener("tap", button._tapListener)
                button._tapListener = nil
            end
        end
    elseif phase == "did" then
        -- Code here runs when scene is off screen
    end
end

function scene:destroy(event)
    -- Clean up scene resources
    -- Display objects are automatically cleaned up by Composer when in sceneGroup
    -- Nil out references
    background = nil
    titleText = nil
    bestRunText = nil
    goldText = nil
    playButton = nil
    upgradesButton = nil
end

-- Scene event listeners
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
