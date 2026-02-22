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
