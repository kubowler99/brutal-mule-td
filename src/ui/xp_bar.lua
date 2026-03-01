--- XPBar UI Component
-- Displays hero XP progress as a filled bar with background and foreground rectangles
-- @class XPBar

local XPBar = Class("XPBar")

--- Initialize the XP bar
-- @param x X position of the XP bar
-- @param y Y position of the XP bar
-- @param width Width of the XP bar
-- @param height Height of the XP bar
-- @param group Parent display group for memory management
function XPBar:initialize(x, y, width, height, group)
  self.x = x
  self.y = y
  self.width = width
  self.height = height
  
  -- Create display group for all XP bar elements
  self.group = display.newGroup()
  if group then
    group:insert(self.group)
  end
  
  -- Background rectangle (empty XP)
  self.background = display.newRect(self.group, x, y, width, height)
  self.background:setFillColor(0.2, 0.2, 0.2)
  self.background.strokeWidth = 2
  self.background:setStrokeColor(0.5, 0.5, 0.5)
  
  -- Foreground rectangle (current XP)
  self.foreground = display.newRect(self.group, x, y, width, height)
  self.foreground:setFillColor(0.2, 0.6, 0.9) -- Blue color for XP
  self.foreground.anchorX = 0
  self.foreground.x = x - width / 2
end

--- Update the XP bar fill ratio
-- @param current Current XP value
-- @param required XP required for next level
function XPBar:update(current, required)
  if not current or not required or required <= 0 then
    return
  end
  
  -- Clamp current XP to valid range
  current = math.max(0, math.min(current, required))
  
  -- Calculate fill ratio
  local ratio = current / required
  
  -- Update foreground width
  self.foreground.width = self.width * ratio
end

--- Destroy the XP bar and clean up resources
function XPBar:destroy()
  if self.group then
    self.group:removeSelf()
    self.group = nil
  end
  self.background = nil
  self.foreground = nil
end

return XPBar
