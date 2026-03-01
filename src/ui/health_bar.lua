--- HealthBar UI Component
-- Displays hero health as a filled bar with background and foreground rectangles
-- @class HealthBar

local HealthBar = Class("HealthBar")

--- Initialize the health bar
-- @param x X position of the health bar
-- @param y Y position of the health bar
-- @param width Width of the health bar
-- @param height Height of the health bar
-- @param group Parent display group for memory management
function HealthBar:initialize(x, y, width, height, group)
  self.x = x
  self.y = y
  self.width = width
  self.height = height
  
  -- Create display group for all health bar elements
  self.group = display.newGroup()
  if group then
    group:insert(self.group)
  end
  
  -- Background rectangle (dark/empty health)
  self.background = display.newRect(self.group, x, y, width, height)
  self.background:setFillColor(0.2, 0.2, 0.2)
  self.background.strokeWidth = 2
  self.background:setStrokeColor(0.5, 0.5, 0.5)
  
  -- Foreground rectangle (current health)
  self.foreground = display.newRect(self.group, x, y, width, height)
  self.foreground:setFillColor(0.8, 0.2, 0.2) -- Red color for health
  self.foreground.anchorX = 0
  self.foreground.x = x - width / 2
end

--- Update the health bar fill ratio
-- @param current Current health value
-- @param max Maximum health value
function HealthBar:update(current, max)
  if not current or not max or max <= 0 then
    return
  end
  
  -- Clamp current health to valid range
  current = math.max(0, math.min(current, max))
  
  -- Calculate fill ratio
  local ratio = current / max
  
  -- Update foreground width
  self.foreground.width = self.width * ratio
end

--- Destroy the health bar and clean up resources
function HealthBar:destroy()
  if self.group then
    self.group:removeSelf()
    self.group = nil
  end
  self.background = nil
  self.foreground = nil
end

return HealthBar
