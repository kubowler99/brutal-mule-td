-- spec_helper.lua
-- This file is used to mock Solar2D globals for unit testing with Busted.
-- It allows the logic modules to be required without crashing.

-- Mock Solar2D Globals
_G.display = {
    newGroup = function() 
        return { 
            insert = function() end, 
            remove = function() end,
            numChildren = 0,
            x = 0,
            y = 0
        } 
    end,
    newRect = function(x, y, w, h) 
        return { 
            x = x or 0,
            y = y or 0,
            width = w or 0,
            height = h or 0,
            setFillColor = function() end, 
            setStrokeColor = function() end,
            removeSelf = function() end
        } 
    end,
    newCircle = function(x, y, r) 
        return { 
            x = x or 0,
            y = y or 0,
            radius = r or 0,
            setFillColor = function() end,
            removeSelf = function() end
        } 
    end,
    newImageRect = function(parent, filename, w, h)
        return {
            x = 0,
            y = 0,
            width = w or 0,
            height = h or 0,
            setFillColor = function() end,
            removeSelf = function() end
        }
    end,
    newText = function(options) 
        return {
            x = 0,
            y = 0,
            text = options and options.text or "",
            setFillColor = function() end,
            removeSelf = function() end
        } 
    end,
    remove = function(obj) end,
    contentCenterX = 360,
    contentCenterY = 640,
    contentWidth = 720,
    contentHeight = 1280,
    actualContentWidth = 720,
    actualContentHeight = 1280,
    screenOriginX = 0,
    screenOriginY = 0,
    setStatusBar = function() end,
    getCurrentStage = function() return { setFocus = function() end } end
}

_G.system = {
    getInfo = function(key)
        if key == "platform" then return "macos" end
        if key == "environment" then return "simulator" end
        return "unknown"
    end,
    pathForFile = function(name, dir) return name end,
    DocumentsDirectory = "docs",
    TemporaryDirectory = "tmp",
    CachesDirectory = "cache"
}

_G.Runtime = {
    addEventListener = function() end,
    removeEventListener = function() end,
    dispatchEvent = function() end
}

_G.transition = {
    to = function() end,
    cancel = function() end,
    pause = function() end,
    resume = function() end
}

_G.timer = {
    performWithDelay = function() end,
    cancel = function() end,
    pause = function() end,
    resume = function() end
}

_G.audio = {
    loadSound = function() end,
    loadStream = function() end,
    play = function() end,
    stop = function() end,
    dispose = function() end,
    setVolume = function() end
}

_G.native = {
    requestExit = function() end,
    showAlert = function() end,
    systemFontBold = "bold",
    systemFont = "normal"
}

_G.composer = {
    gotoScene = function() end,
    newScene = function() return { addEventListener = function() end } end,
    getSceneName = function() return "menu" end,
    removeScene = function() end,
    hideOverlay = function() end,
    showOverlay = function() end
}

_G.network = {
    request = function() end
}

-- MiddleClass and Stateful (Already in project, but let's make sure they are accessible)
_G.Class = require("lib.middleclass")
_G.Stateful = require("lib.stateful")

-- Any other global mocks needed for the specific project logic
