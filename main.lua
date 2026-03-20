-- Global modules
_G.Class = require("lib.middleclass")
_G.Stateful = require("lib.stateful")
local composer = require("composer")
local state = require("src.models.data")
local abilityRegistry = require("src.models.ability_registry")

-- Hide status bar
display.setStatusBar(display.HiddenStatusBar)

-- Seed random
math.randomseed(os.time())

-- Global Error Handler
local function onUnhandledError(event)
    print("[ERROR] Unhandled Error: " .. tostring(event.errorMessage))
    -- Log to analytics or file
    return true -- Prevents app from crashing in some environments
end
Runtime:addEventListener("unhandledError", onUnhandledError)

-- Android Back Button Handler
local function onKeyEvent(event)
    if event.keyName == "back" and event.phase == "up" then
        local currentScene = composer.getSceneName("current")
        if currentScene == "src.scenes.menu" then
            native.requestExit()
        else
            composer.gotoScene("src.scenes.menu", { effect = "fade", time = 300 })
        end
        return true
    end
    return false
end

-- Only add the key listener on Android and Simulator (excluding iOS skins) to avoid warnings
local device = require("src.utils.device")
if (device.isAndroid) or (device.isSimulator and not device.isIos) then
    Runtime:addEventListener("key", onKeyEvent)
end

-- Initialize and Load Game Data
state.load()

-- Initialize Ability Registry
abilityRegistry.initialize()

-- Go to menu scene
composer.gotoScene("src.scenes.menu")
