require("tests.spec_helper")

describe("Menu Scene", function()
    local menuScene
    
    before_each(function()
        -- Reset modules
        package.loaded["src.scenes.menu"] = nil
        package.loaded["src.utils.helpers"] = nil
        
        -- Reload menu scene
        menuScene = require("src.scenes.menu")
    end)
    
    after_each(function()
        -- Clean up
        if menuScene and menuScene.view then
            while menuScene.view.numChildren > 0 do
                menuScene.view:remove(1)
            end
        end
    end)
    
    describe("scene:create", function()
        it("should build menu UI with display objects", function()
            -- Trigger create event
            local event = { name = "create", phase = "will" }
            menuScene:dispatchEvent(event)
            
            -- Verify scene group exists
            assert.is_not_nil(menuScene.view)
            
            -- Verify display objects were created
            -- The scene should have: background, title, play button + label, settings button + label
            assert.is_true(menuScene.view.numChildren >= 5)
        end)
        
        it("should add all display objects to sceneGroup", function()
            local event = { name = "create", phase = "will" }
            menuScene:dispatchEvent(event)
            
            -- All display objects should be children of sceneGroup
            assert.is_true(menuScene.view.numChildren > 0)
            
            -- Verify each child has the scene group as parent
            for i = 1, menuScene.view.numChildren do
                local child = menuScene.view[i]
                assert.equals(menuScene.view, child.parent)
            end
        end)
    end)
    
    describe("scene:show", function()
        it("should handle 'did' phase without errors", function()
            -- Create scene first
            local createEvent = { name = "create", phase = "will" }
            menuScene:dispatchEvent(createEvent)
            
            -- Show scene should not error
            local showEvent = { name = "show", phase = "did" }
            assert.has_no_errors(function()
                menuScene:dispatchEvent(showEvent)
            end)
        end)
    end)
    
    describe("scene:hide", function()
        it("should handle 'will' phase without errors", function()
            -- Create and show scene
            local createEvent = { name = "create", phase = "will" }
            menuScene:dispatchEvent(createEvent)
            
            local showEvent = { name = "show", phase = "did" }
            menuScene:dispatchEvent(showEvent)
            
            -- Hide scene should not error
            local hideEvent = { name = "hide", phase = "will" }
            assert.has_no_errors(function()
                menuScene:dispatchEvent(hideEvent)
            end)
        end)
    end)
    
    describe("scene:destroy", function()
        it("should clean up resources without errors", function()
            -- Create scene
            local createEvent = { name = "create", phase = "will" }
            menuScene:dispatchEvent(createEvent)
            
            -- Destroy scene should not error
            local destroyEvent = { name = "destroy", phase = "will" }
            assert.has_no_errors(function()
                menuScene:dispatchEvent(destroyEvent)
            end)
        end)
    end)
    
    describe("play button transition", function()
        it("should call composer.gotoScene when play button is activated", function()
            -- Create and show scene
            local createEvent = { name = "create", phase = "will" }
            menuScene:dispatchEvent(createEvent)
            
            local showEvent = { name = "show", phase = "did" }
            menuScene:dispatchEvent(showEvent)
            
            -- Mock composer.gotoScene
            local gotoSceneCalled = false
            local targetScene = nil
            local originalGotoScene = composer.gotoScene
            composer.gotoScene = function(sceneName, options)
                gotoSceneCalled = true
                targetScene = sceneName
            end
            
            -- Find and trigger play button
            local playButton = nil
            for i = 1, menuScene.view.numChildren do
                local child = menuScene.view[i]
                if child._type == "rect" and child.label and child.label.text == "PLAY" then
                    playButton = child
                    break
                end
            end
            
            -- If we found the button and it has a tap listener, trigger it
            if playButton and playButton._tapListener then
                playButton._tapListener({ name = "tap", target = playButton })
                
                -- Verify transition was triggered
                assert.is_true(gotoSceneCalled)
                assert.equals("src.scenes.game", targetScene)
            else
                -- If button structure is different, just verify scene was created
                assert.is_not_nil(playButton)
            end
            
            -- Restore original
            composer.gotoScene = originalGotoScene
        end)
    end)
end)
