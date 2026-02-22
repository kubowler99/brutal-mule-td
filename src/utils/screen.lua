---@class Screen
---Screen dimension utilities for Solar2D
local M = {
    width         = display.actualContentWidth,
    height        = display.actualContentHeight,
    contentWidth  = display.contentWidth,
    contentHeight = display.contentHeight,
    centerX       = display.contentCenterX,
    centerY       = display.contentCenterY,
    originX       = display.screenOriginX,
    originY       = display.screenOriginY,
    edgeX         = display.screenOriginX + display.actualContentWidth,
    edgeY         = display.screenOriginY + display.actualContentHeight,
    safeOriginX   = display.safeOriginX,
    safeOriginY   = display.safeOriginY,
    safeActualWidth = display.safeActualContentWidth,
    safeActualHeight = display.safeActualContentHeight
}

return M
