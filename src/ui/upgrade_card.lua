--- UpgradeCard UI Component
-- Displays an upgrade option with name, description, and icon
-- Handles tap selection with visual feedback
-- @class UpgradeCard

local placeholder_graphics = require("src.utils.placeholder_graphics")

local UpgradeCard = Class("UpgradeCard")

--- Initialize the upgrade card
-- @param x X position of the card
-- @param y Y position of the card
-- @param upgradeData The upgrade data object {id, name, description, icon}
-- @param group Parent display group for memory management
function UpgradeCard:initialize(x, y, upgradeData, group)
  self.x = x
  self.y = y
  self.upgradeData = upgradeData
  self.callback = nil
  self.isPressed = false
  
  -- Create display group for all card elements
  self.group = display.newGroup()
  if group then
    group:insert(self.group)
  end
  
  -- Card background
  self.background = display.newRoundedRect(self.group, x, y, 200, 120, 10)
  self.background:setFillColor(0.2, 0.2, 0.3)
  self.background.strokeWidth = 3
  self.background:setStrokeColor(0.5, 0.5, 0.6)
  
  -- Icon using placeholder_graphics
  if upgradeData.iconType then
    self.icon = placeholder_graphics.createUpgradeIcon(upgradeData.iconType)
    self.icon.x = x
    self.icon.y = y - 30
    self.group:insert(self.icon)
  else
    -- Fallback to simple circle if no iconType specified
    self.icon = display.newCircle(self.group, x, y - 30, 20)
    if upgradeData.type == "new_ability" then
      self.icon:setFillColor(0.3, 0.7, 0.3) -- Green for new abilities
    else
      self.icon:setFillColor(0.7, 0.5, 0.2) -- Orange for upgrades
    end
  end
  
  -- Name text
  self.nameText = display.newText({
    parent = self.group,
    text = upgradeData.name or "Unknown",
    x = x,
    y = y,
    width = 180,
    fontSize = 16,
    align = "center"
  })
  self.nameText:setFillColor(1, 1, 1)
  
  -- Description text
  self.descriptionText = display.newText({
    parent = self.group,
    text = upgradeData.description or "",
    x = x,
    y = y + 25,
    width = 180,
    fontSize = 12,
    align = "center"
  })
  self.descriptionText:setFillColor(0.8, 0.8, 0.8)
end

--- Set the tap callback for card selection
-- @param callback Function to call when card is tapped
function UpgradeCard:onTap(callback)
  self.callback = callback
  
  -- Add touch listener to background
  self.background:addEventListener("touch", function(event)
    return self:_handleTouch(event)
  end)
end

--- Internal touch handler with visual feedback
-- @param event The touch event
-- @return true to indicate event was handled
function UpgradeCard:_handleTouch(event)
  if event.phase == "began" then
    -- Visual feedback: darken card
    self.isPressed = true
    self.background:setFillColor(0.15, 0.15, 0.25)
    display.getCurrentStage():setFocus(event.target)
    
  elseif event.phase == "moved" then
    -- Check if touch moved outside card bounds
    local bounds = self.background.contentBounds
    if event.x < bounds.xMin or event.x > bounds.xMax or
       event.y < bounds.yMin or event.y > bounds.yMax then
      -- Touch moved outside, cancel
      if self.isPressed then
        self.background:setFillColor(0.2, 0.2, 0.3)
        self.isPressed = false
      end
    else
      -- Touch still inside, ensure pressed state
      if not self.isPressed then
        self.background:setFillColor(0.15, 0.15, 0.25)
        self.isPressed = true
      end
    end
    
  elseif event.phase == "ended" or event.phase == "cancelled" then
    display.getCurrentStage():setFocus(nil)
    
    -- Restore normal appearance
    self.background:setFillColor(0.2, 0.2, 0.3)
    
    -- Call callback if touch ended inside card
    if self.isPressed and event.phase == "ended" then
      -- Add brief highlight effect
      self.background:setFillColor(0.3, 0.3, 0.4)
      timer.performWithDelay(100, function()
        if self.background then
          self.background:setFillColor(0.2, 0.2, 0.3)
        end
      end)
      
      -- Invoke callback
      if self.callback then
        self.callback(self.upgradeData)
      end
    end
    
    self.isPressed = false
  end
  
  return true
end

--- Destroy the upgrade card and clean up resources
function UpgradeCard:destroy()
  -- Remove touch listener
  if self.background then
    self.background:removeEventListener("touch")
  end
  
  if self.group then
    self.group:removeSelf()
    self.group = nil
  end
  
  self.background = nil
  self.icon = nil
  self.nameText = nil
  self.descriptionText = nil
  self.upgradeData = nil
  self.callback = nil
end

return UpgradeCard
