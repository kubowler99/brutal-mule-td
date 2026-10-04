local screen = require("src.utils.screen")
local M = {}

-- Display shortcuts (delegated to screen module)
M.centerX = screen.centerX
M.centerY = screen.centerY
M.width = screen.contentWidth
M.height = screen.contentHeight
M.screenOriginX = screen.originX
M.screenOriginY = screen.originY
M.actualWidth = screen.width
M.actualHeight = screen.height
M.safeOriginX = screen.safeOriginX
M.safeOriginY = screen.safeOriginY

-- Create a simple button
function M.newButton(options)
    local btn = display.newRect(
        options.x or 0,
        options.y or 0,
        options.width or 100,
        options.height or 40
    )
    btn:setFillColor(unpack(options.fillColor or {0.2, 0.5, 1}))
    btn.strokeWidth = 2
    btn:setStrokeColor(1, 1, 1)
    
    local label = display.newText({
        text = options.label or "Button",
        x = btn.x,
        y = btn.y,
        font = native.systemFontBold,
        fontSize = options.fontSize or 18
    })
    
    local function touch(event)
        local phase = event.phase
        if phase == "began" then
            display.getCurrentStage():setFocus(btn)
            btn.isFocus = true
            btn:setFillColor(0.1, 0.3, 0.8)
        elseif btn.isFocus then
            if phase == "moved" then
                -- Optional: change color if finger moves out of bounds
                local bounds = btn.contentBounds
                local x, y = event.x, event.y
                if (x < bounds.xMin or x > bounds.xMax or y < bounds.yMin or y > bounds.yMax) then
                    btn:setFillColor(unpack(options.fillColor or {0.2, 0.5, 1}))
                else
                    btn:setFillColor(0.1, 0.3, 0.8)
                end
            elseif phase == "ended" or phase == "cancelled" then
                display.getCurrentStage():setFocus(nil)
                btn.isFocus = false
                btn:setFillColor(unpack(options.fillColor or {0.2, 0.5, 1}))
                
                if phase == "ended" then
                    local bounds = btn.contentBounds
                    local x, y = event.x, event.y
                    if (x >= bounds.xMin and x <= bounds.xMax and y >= bounds.yMin and y <= bounds.yMax) then
                        if options.onRelease then
                            options.onRelease(event)
                        end
                    end
                end
            end
        end
        return true
    end
    
    btn:addEventListener("touch", touch)
    
    btn.label = label
    return btn
end

-- Full-screen background images and their pixel sizes
M.BACKGROUNDS = {
    game = { path = "assets/images/backgrounds/game.png", width = 288, height = 512 },
    menu = { path = "assets/images/backgrounds/menu.png", width = 286, height = 509 },
    settings = { path = "assets/images/backgrounds/settings.png", width = 288, height = 512 },
}

-- Fill color used when a background image fails to load
local BACKGROUND_FALLBACK_COLOR = {0.1, 0.1, 0.2}

-- Create a full-screen background from M.BACKGROUNDS. The image is scaled
-- to cover the whole screen, keeping its aspect ratio, so any extra width
-- or height is cut off evenly at the edges.
-- @param parent table Display group to insert into
-- @param name string Key in M.BACKGROUNDS
-- @return table The background display object
function M.newBackground(parent, name)
    local background = M.BACKGROUNDS[name]
    if background then
        local scale = math.max(M.width / background.width, M.height / background.height)
        local image = display.newImageRect(parent, background.path, background.width * scale, background.height * scale)
        if image then
            image.x = M.centerX
            image.y = M.centerY
            return image
        end
    end

    local rect = display.newRect(parent, M.centerX, M.centerY, M.width, M.height)
    rect:setFillColor(unpack(BACKGROUND_FALLBACK_COLOR))
    return rect
end

-- Clean up display group
function M.cleanGroup(group)
    if group then
        while group.numChildren > 0 do
            display.remove(group[1])
        end
    end
end

-- Print table contents (debug)
function M.printTable(t, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)
    
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(spacing .. tostring(k) .. ":")
            M.printTable(v, indent + 1)
        else
            print(spacing .. tostring(k) .. ": " .. tostring(v))
        end
    end
end

return M
