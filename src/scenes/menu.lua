local composer = require("composer")
local helpers = require("src.utils.helpers")
local state = require("src.models.data")

local scene = composer.newScene()

-- Scene variables
local background
local titleText
local playButton

-- Scene lifecycle functions

function scene:create(event)
    local sceneGroup = self.view
    local params = event.params or {} -- Access passed parameters
    
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
        text = "My Game",
        x = helpers.centerX,
        y = 100,
        font = native.systemFontBold,
        fontSize = 48
    })
    
    -- Play button
    playButton = helpers.newButton({
        x = helpers.centerX,
        y = helpers.centerY,
        width = 200,
        height = 60,
        label = "PLAY",
        fontSize = 24,
        onRelease = function()
            composer.gotoScene("src.scenes.game", {
                effect = "fade",
                time = 300,
                params = { difficulty = "easy" } -- Example parameter passing
            })
        end
    })
    sceneGroup:insert(playButton)
    sceneGroup:insert(playButton.label)
end

function scene:show(event)
    local sceneGroup = self.view
    local phase = event.phase
    
    if phase == "will" then
        -- Code here runs when scene is still off screen
    elseif phase == "did" then
        -- Code here runs when scene is on screen
        -- Start timers, music, or physics
    end
end

function scene:hide(event)
    local sceneGroup = self.view
    local phase = event.phase
    
    if phase == "will" then
        -- Code here runs when scene is still on screen
        -- Stop timers, music, or physics
    elseif phase == "did" then
        -- Code here runs when scene is off screen
    end
end

function scene:destroy(event)
    local sceneGroup = self.view
    -- Clean up scene resources, remove listeners
    if playButton then
        -- The label is not a child of playButton but was inserted into sceneGroup separately
        -- so it will be cleaned up by composer, but it's good practice to nil references.
        playButton = nil
    end
end

-- Scene event listeners
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
