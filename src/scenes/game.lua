local composer = require("composer")
local helpers = require("src.utils.helpers")
local scene = composer.newScene()

function scene:create(event)
    local sceneGroup = self.view
    
    local background = display.newRect(
        sceneGroup,
        helpers.centerX,
        helpers.centerY,
        helpers.width,
        helpers.height
    )
    background:setFillColor(0.2, 0.4, 0.2)
    
    local titleText = display.newText({
        parent = sceneGroup,
        text = "Game Scene",
        x = helpers.centerX,
        y = 100,
        font = native.systemFontBold,
        fontSize = 48
    })

    local backButton = helpers.newButton({
        x = helpers.centerX,
        y = helpers.centerY,
        width = 200,
        height = 60,
        label = "BACK",
        fontSize = 24,
        onRelease = function()
            composer.gotoScene("src.scenes.menu", {
                effect = "fade",
                time = 300
            })
        end
    })
    sceneGroup:insert(backButton)
    sceneGroup:insert(backButton.label)
end

scene:addEventListener("create", scene)
return scene
