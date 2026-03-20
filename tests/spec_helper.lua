-- spec_helper.lua
-- This file is used to mock Solar2D globals for unit testing with Busted.
-- It allows the logic modules to be required without crashing.

-- Mock Solar2D Globals
_G.display = {
    newGroup = function() 
        local children = {}
        local group = {
            numChildren = 0,
            x = 0,
            y = 0,
            isVisible = true,
            _type = "group",
            insert = function(self, obj)
                if obj then
                    table.insert(children, obj)
                    obj.parent = self
                    self.numChildren = #children
                end
            end, 
            remove = function(self, indexOrObj)
                if type(indexOrObj) == "number" then
                    table.remove(children, indexOrObj)
                else
                    for i, child in ipairs(children) do
                        if child == indexOrObj then
                            table.remove(children, i)
                            break
                        end
                    end
                end
                self.numChildren = #children
            end,
            removeSelf = function() end,
            toFront = function() end,
            toBack = function() end
        }
        -- Create metatable for array-like access
        setmetatable(group, {
            __index = function(t, k)
                if type(k) == "number" then
                    return children[k]
                end
                return rawget(t, k)
            end
        })
        return group
    end,
    newRect = function(parent, x, y, w, h)
        -- Handle both forms: newRect(x, y, w, h) and newRect(parent, x, y, w, h)
        if type(parent) == "number" then
            -- First form: newRect(x, y, w, h)
            w, h = y, w
            y = x
            x = parent
            parent = nil
        end
        local rect = { 
            x = x or 0,
            y = y or 0,
            width = w or 0,
            height = h or 0,
            anchorX = 0.5,
            anchorY = 0.5,
            strokeWidth = 0,
            isVisible = true,
            _type = "rect",
            parent = parent,
            setFillColor = function() end, 
            setStrokeColor = function() end,
            removeSelf = function() end,
            toFront = function() end,
            toBack = function() end,
            contentBounds = {
                xMin = (x or 0) - (w or 0) / 2,
                xMax = (x or 0) + (w or 0) / 2,
                yMin = (y or 0) - (h or 0) / 2,
                yMax = (y or 0) + (h or 0) / 2
            },
            addEventListener = function() end,
            removeEventListener = function() end
        }
        -- Add to parent group if provided
        if parent and parent.insert then
            parent:insert(rect)
        end
        return rect
    end,
    newRoundedRect = function(parent, x, y, w, h, cornerRadius)
        -- Handle both forms
        if type(parent) == "number" then
            cornerRadius = h
            h = w
            w = y
            y = x
            x = parent
            parent = nil
        end
        return { 
            x = x or 0,
            y = y or 0,
            width = w or 0,
            height = h or 0,
            cornerRadius = cornerRadius or 0,
            anchorX = 0.5,
            anchorY = 0.5,
            strokeWidth = 0,
            isVisible = true,
            setFillColor = function() end, 
            setStrokeColor = function() end,
            removeSelf = function() end,
            toFront = function() end,
            toBack = function() end,
            contentBounds = {
                xMin = (x or 0) - (w or 0) / 2,
                xMax = (x or 0) + (w or 0) / 2,
                yMin = (y or 0) - (h or 0) / 2,
                yMax = (y or 0) + (h or 0) / 2
            },
            addEventListener = function() end,
            removeEventListener = function() end
        } 
    end,
    newCircle = function(parent, x, y, r) 
        -- Handle both forms: newCircle(x, y, r) and newCircle(parent, x, y, r)
        if type(parent) == "number" then
            r = y
            y = x
            x = parent
            parent = nil
        end
        local circle = { 
            x = x or 0,
            y = y or 0,
            radius = r or 0,
            strokeWidth = 0,
            isVisible = true,
            _type = "circle",
            parent = parent,
            setFillColor = function() end,
            setStrokeColor = function() end,
            removeSelf = function() end,
            toFront = function() end,
            toBack = function() end
        }
        -- Add to parent group if provided
        if parent and parent.insert then
            parent:insert(circle)
        end
        return circle
    end,
    newImageRect = function(parent, filename, w, h)
        return {
            x = 0,
            y = 0,
            width = w or 0,
            height = h or 0,
            isVisible = true,
            setFillColor = function() end,
            removeSelf = function() end,
            toFront = function() end,
            toBack = function() end
        }
    end,
    newLine = function(parent, ...)
        -- Handle both forms: newLine(x1, y1, x2, y2, ...) and newLine(parent, x1, y1, x2, y2, ...)
        local args = {...}
        if type(parent) == "number" then
            table.insert(args, 1, parent)
            parent = nil
        end
        local line = {
            x = 0,
            y = 0,
            strokeWidth = 1,
            isVisible = true,
            _type = "line",
            parent = parent,
            setStrokeColor = function() end,
            removeSelf = function() end,
            toFront = function() end,
            toBack = function() end
        }
        -- Add to parent group if provided
        if parent and parent.insert then
            parent:insert(line)
        end
        return line
    end,
    newPolygon = function(parent, x, y, vertices)
        -- Handle both forms
        if type(parent) == "number" then
            vertices = y
            y = x
            x = parent
            parent = nil
        end
        local polygon = {
            x = x or 0,
            y = y or 0,
            isVisible = true,
            _type = "polygon",
            parent = parent,
            setFillColor = function() end,
            setStrokeColor = function() end,
            removeSelf = function() end,
            toFront = function() end,
            toBack = function() end
        }
        -- Add to parent group if provided
        if parent and parent.insert then
            parent:insert(polygon)
        end
        return polygon
    end,
    newText = function(options) 
        local text = {
            x = options and options.x or 0,
            y = options and options.y or 0,
            text = options and options.text or "",
            isVisible = true,
            _type = "text",
            parent = options and options.parent,
            setFillColor = function() end,
            removeSelf = function() end,
            toFront = function() end,
            toBack = function() end
        }
        -- Add to parent group if provided
        if options and options.parent and options.parent.insert then
            options.parent:insert(text)
        end
        return text
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
    getTimer = function() return 0 end,  -- Mock timer for testing
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
    newScene = function() 
        local scene = {
            view = display.newGroup(),
            addEventListener = function(self, eventName, listener)
                -- Store listeners for testing
                self._listeners = self._listeners or {}
                self._listeners[eventName] = listener
            end,
            dispatchEvent = function(self, event)
                -- Dispatch to the appropriate listener
                if self._listeners and self._listeners[event.name] then
                    local listener = self._listeners[event.name]
                    if type(listener) == "function" then
                        listener(event)
                    elseif type(listener) == "table" and listener[event.name] then
                        listener[event.name](listener, event)
                    end
                end
            end,
            _listeners = {}
        }
        -- Add _type to display group for identification
        scene.view._type = "group"
        return scene
    end,
    getSceneName = function() return "menu" end,
    getScene = function(sceneName) 
        -- Return nil if scene not loaded (for testing)
        return nil
    end,
    loadScene = function(sceneName)
        -- Load and return a scene for testing
        local success, scene = pcall(require, sceneName)
        if success then
            return scene
        end
        return nil
    end,
    removeScene = function() end,
    hideOverlay = function() end,
    showOverlay = function() end
}

_G.network = {
    request = function() end
}

-- Mock JSON library (Solar2D built-in)
_G.json = {
    encode = function(t) 
        -- Use Lua's built-in JSON encoding if available, otherwise simple mock
        local success, dkjson = pcall(require, "dkjson")
        if success then
            return dkjson.encode(t)
        end
        -- Fallback: Simple JSON encoding for testing
        if type(t) ~= "table" then return tostring(t) end
        return "{}" -- Simplified for testing
    end,
    decode = function(str) 
        -- Use Lua's built-in JSON decoding if available, otherwise simple mock
        local success, dkjson = pcall(require, "dkjson")
        if success then
            return dkjson.decode(str)
        end
        -- Fallback: Simple JSON decoding for testing
        if str == "{}" or str == "" then return {} end
        return {} -- Simplified for testing
    end
}

-- Make composer available as a module via package.preload
package.preload["composer"] = function()
    return _G.composer
end

-- MiddleClass and Stateful (Already in project, but let's make sure they are accessible)
_G.Class = require("lib.middleclass")
_G.Stateful = require("lib.stateful")

-- Any other global mocks needed for the specific project logic
