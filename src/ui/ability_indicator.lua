--- AbilityIndicator UI Component
-- Displays an ability icon and cooldown overlay for a single ability slot
-- @class AbilityIndicator

local AbilityIndicator = Class("AbilityIndicator")

--- Initialize the ability indicator
-- @param x X position of the indicator
-- @param y Y position of the indicator
-- @param slotIndex The ability slot index (1-5)
-- @param group Parent display group for memory management
function AbilityIndicator:initialize(x, y, slotIndex, group)
  self.x = x
  self.y = y
  self.slotIndex = slotIndex
  self.ability = nil
  
  -- Create display group for all indicator elements
  self.group = display.newGroup()
  if group then
    group:insert(self.group)
  end
  
  -- Background/slot rectangle
  self.background = display.newRect(self.group, x, y, 50, 50)
  self.background:setFillColor(0.3, 0.3, 0.3)
  self.background.strokeWidth = 2
  self.background:setStrokeColor(0.6, 0.6, 0.6)
  
  -- Ability icon (placeholder circle, will be replaced with actual icon)
  self.icon = display.newCircle(self.group, x, y, 20)
  self.icon:setFillColor(0.5, 0.5, 0.5)
  self.icon.isVisible = false
  
  -- Cooldown overlay (semi-transparent rectangle)
  self.cooldownOverlay = display.newRect(self.group, x, y, 50, 50)
  self.cooldownOverlay:setFillColor(0, 0, 0, 0.7)
  self.cooldownOverlay.anchorY = 1
  self.cooldownOverlay.y = y + 25
  self.cooldownOverlay.isVisible = false
  
  -- Slot number text
  self.slotText = display.newText({
    parent = self.group,
    text = tostring(slotIndex),
    x = x,
    y = y + 30,
    fontSize = 12
  })
  self.slotText:setFillColor(0.8, 0.8, 0.8)
end

--- Set the ability for this indicator
-- @param ability The ability object to display
function AbilityIndicator:setAbility(ability)
  self.ability = ability
  
  if ability then
    -- Show icon
    self.icon.isVisible = true
    -- Set icon color based on ability (placeholder logic)
    if ability.id == "arcane_bolt" then
      self.icon:setFillColor(0.5, 0.3, 0.9) -- Purple for arcane
    else
      self.icon:setFillColor(0.9, 0.5, 0.2) -- Orange for other abilities
    end
  else
    -- Hide icon if no ability
    self.icon.isVisible = false
    self.cooldownOverlay.isVisible = false
  end
end

--- Update the cooldown overlay
-- @param remaining Remaining cooldown time in seconds
-- @param total Total cooldown time in seconds
function AbilityIndicator:updateCooldown(remaining, total)
  if not self.ability or not remaining or not total or total <= 0 then
    self.cooldownOverlay.isVisible = false
    return
  end
  
  -- Clamp remaining to valid range
  remaining = math.max(0, math.min(remaining, total))
  
  if remaining > 0 then
    -- Show cooldown overlay
    self.cooldownOverlay.isVisible = true
    
    -- Calculate fill ratio (overlay fills from bottom to top)
    local ratio = remaining / total
    self.cooldownOverlay.height = 50 * ratio
  else
    -- Hide overlay when cooldown is complete
    self.cooldownOverlay.isVisible = false
  end
end

--- Destroy the ability indicator and clean up resources
function AbilityIndicator:destroy()
  if self.group then
    self.group:removeSelf()
    self.group = nil
  end
  self.background = nil
  self.icon = nil
  self.cooldownOverlay = nil
  self.slotText = nil
  self.ability = nil
end

return AbilityIndicator
