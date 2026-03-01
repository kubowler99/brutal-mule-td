local composer = require("composer")
local helpers = require("src.utils.helpers")

local scene = composer.newScene()

-- Scene variables
local background
local titleText
local playButton
local settingsButton

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
    
    -- Settings button (placeholder, no functionality)
    settingsButton = helpers.newButton({
        x = helpers.centerX,
        y = helpers.centerY + 80,
        width = 200,
        height = 60,
        label = "SETTINGS",
        fontSize = 24,
        fillColor = {0.5, 0.5, 0.5}
    })
    sceneGroup:insert(settingsButton)
    sceneGroup:insert(settingsButton.label)
end

function scene:show(event)
    local phase = event.phase
    
    if phase == "will" then
        -- Code here runs when scene is still off screen
    elseif phase == "did" then
        -- Add button tap handler when scene is fully visible
        local function onPlayTap(event)
            composer.gotoScene("src.scenes.game", {
                effect = "fade",
                time = 300
            })
            return true
        end
        
        -- Store listener reference for cleanup
        playButton._tapListener = onPlayTap
        playButton:addEventListener("tap", onPlayTap)
    end
end

function scene:hide(event)
    local phase = event.phase
    
    if phase == "will" then
        -- Remove button listeners before scene transitions
        if playButton and playButton._tapListener then
            playButton:removeEventListener("tap", playButton._tapListener)
            playButton._tapListener = nil
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
    playButton = nil
    settingsButton = nil
end

-- Scene event listeners
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
