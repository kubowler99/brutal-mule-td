---
-- Placeholder Graphics Generator
-- Creates simple visual placeholders for game entities using Solar2D vector graphics
-- This module provides functions to create temporary visual assets for prototyping
---

local M = {}

---
-- Creates a hero sprite (blue circle with white border)
-- @param x number X position
-- @param y number Y position
-- @return DisplayObject The created hero sprite
function M.createHeroSprite(x, y)
    local group = display.newGroup()
    
    -- Main body (blue circle)
    local body = display.newCircle(group, 0, 0, 25)
    body:setFillColor(0.2, 0.4, 0.9)  -- Blue
    
    -- Border (white outline)
    local border = display.newCircle(group, 0, 0, 25)
    border:setFillColor(0, 0, 0, 0)
    border.strokeWidth = 3
    border:setStrokeColor(1, 1, 1)  -- White
    
    -- Glow effect (semi-transparent outer circle)
    local glow = display.newCircle(group, 0, 0, 30)
    glow:setFillColor(0.4, 0.6, 1, 0.3)  -- Light blue, transparent
    glow:toBack()
    
    group.x = x
    group.y = y
    
    return group
end

---
-- Creates a walker sprite (red square with dark border)
-- @param x number X position
-- @param y number Y position
-- @return DisplayObject The created walker sprite
function M.createWalkerSprite(x, y)
    local group = display.newGroup()
    
    -- Main body (red square)
    local body = display.newRect(group, 0, 0, 30, 30)
    body:setFillColor(0.9, 0.2, 0.2)  -- Red
    
    -- Border (dark outline)
    local border = display.newRect(group, 0, 0, 30, 30)
    border:setFillColor(0, 0, 0, 0)
    border.strokeWidth = 2
    border:setStrokeColor(0.3, 0, 0)  -- Dark red
    
    group.x = x
    group.y = y
    
    return group
end

---
-- Creates a projectile sprite (small cyan circle)
-- @param x number X position
-- @param y number Y position
-- @return DisplayObject The created projectile sprite
function M.createProjectileSprite(x, y)
    local group = display.newGroup()
    
    -- Main body (cyan circle)
    local body = display.newCircle(group, 0, 0, 8)
    body:setFillColor(0.2, 0.9, 0.9)  -- Cyan
    
    -- Glow effect
    local glow = display.newCircle(group, 0, 0, 12)
    glow:setFillColor(0.4, 1, 1, 0.4)  -- Light cyan, transparent
    glow:toBack()
    
    group.x = x
    group.y = y
    
    return group
end

---
-- Creates an XP orb sprite (yellow/gold glowing circle)
-- @param x number X position
-- @param y number Y position
-- @return DisplayObject The created XP orb sprite
function M.createXPOrbSprite(x, y)
    local group = display.newGroup()
    
    -- Outer glow (large, very transparent)
    local outerGlow = display.newCircle(group, 0, 0, 20)
    outerGlow:setFillColor(1, 0.9, 0.3, 0.2)  -- Gold, very transparent
    
    -- Inner glow (medium, semi-transparent)
    local innerGlow = display.newCircle(group, 0, 0, 12)
    innerGlow:setFillColor(1, 0.9, 0.3, 0.5)  -- Gold, semi-transparent
    
    -- Core (small, bright)
    local core = display.newCircle(group, 0, 0, 6)
    core:setFillColor(1, 1, 0.5)  -- Bright yellow
    
    group.x = x
    group.y = y
    
    return group
end

---
-- Creates a simple gradient background
-- @param width number Background width
-- @param height number Background height
-- @return DisplayObject The created background
function M.createBackground(width, height)
    local group = display.newGroup()
    
    -- Create a dark gradient effect using multiple rectangles
    local numStripes = 10
    local stripeHeight = height / numStripes
    
    for i = 1, numStripes do
        local stripe = display.newRect(group, width / 2, (i - 0.5) * stripeHeight, width, stripeHeight)
        local brightness = 0.05 + (i / numStripes) * 0.1  -- Gradient from dark to slightly less dark
        stripe:setFillColor(brightness, brightness * 0.8, brightness * 1.2)  -- Slight blue tint
    end
    
    return group
end

---
-- Creates an upgrade icon placeholder
-- @param upgradeType string Type of upgrade ("damage", "speed", "count", "pierce", "radius")
-- @return DisplayObject The created icon
function M.createUpgradeIcon(upgradeType)
    local group = display.newGroup()
    
    -- Background circle
    local bg = display.newCircle(group, 0, 0, 30)
    bg:setFillColor(0.2, 0.2, 0.3)
    bg.strokeWidth = 2
    bg:setStrokeColor(0.6, 0.6, 0.7)
    
    -- Icon symbol based on type
    if upgradeType == "damage" then
        -- Sword/strike symbol (diagonal line)
        local line = display.newLine(group, -15, 15, 15, -15)
        line.strokeWidth = 4
        line:setStrokeColor(1, 0.3, 0.3)
    elseif upgradeType == "speed" then
        -- Lightning bolt (zigzag)
        local bolt = display.newLine(group, -10, -15, 0, 0, -10, 0, 0, 15)
        bolt.strokeWidth = 3
        bolt:setStrokeColor(1, 1, 0.3)
    elseif upgradeType == "count" then
        -- Multiple dots
        for i = -1, 1 do
            local dot = display.newCircle(group, i * 12, 0, 5)
            dot:setFillColor(0.3, 1, 0.3)
        end
    elseif upgradeType == "pierce" then
        -- Arrow through target
        local arrow = display.newLine(group, -15, 0, 15, 0)
        arrow.strokeWidth = 3
        arrow:setStrokeColor(0.9, 0.5, 0.2)
        local tip = display.newPolygon(group, 15, 0, {0, -5, 10, 0, 0, 5})
        tip:setFillColor(0.9, 0.5, 0.2)
    elseif upgradeType == "radius" then
        -- Expanding circles
        for i = 1, 3 do
            local circle = display.newCircle(group, 0, 0, i * 8)
            circle:setFillColor(0, 0, 0, 0)
            circle.strokeWidth = 2
            circle:setStrokeColor(0.5, 0.5, 1, 1 - (i * 0.25))
        end
    else
        -- Default: question mark
        local text = display.newText({
            parent = group,
            text = "?",
            x = 0,
            y = 0,
            font = native.systemFontBold,
            fontSize = 32
        })
        text:setFillColor(0.8, 0.8, 0.8)
    end
    
    return group
end

return M
