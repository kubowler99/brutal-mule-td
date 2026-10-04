--- AbilityIndicator UI Component
-- Displays an ability icon and cooldown overlay for a single ability slot
-- @class AbilityIndicator

local ability_data_loader = require("src.models.ability_data_loader")

local AbilityIndicator = Class("AbilityIndicator")

local ICON_SIZE = 40

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
  
  -- Icon layer keeps the icon below the cooldown overlay when the icon is swapped
  self.iconLayer = display.newGroup()
  self.group:insert(self.iconLayer)

  -- Ability icon (empty slot placeholder until an ability is set)
  self.icon = display.newCircle(self.iconLayer, x, y, 20)
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
    self:_replaceIcon(ability)
    self.icon.isVisible = true
  else
    -- Hide icon if no ability
    self.icon.isVisible = false
    self.cooldownOverlay.isVisible = false
  end
end

--- Swap the icon for the ability's image, or a colored circle if it has no image
-- @param ability The ability object to display
function AbilityIndicator:_replaceIcon(ability)
  if self.icon then
    self.icon:removeSelf()
    self.icon = nil
  end

  local iconPath = ability_data_loader.getIconPath(ability.id)
  if iconPath then
    self.icon = display.newImageRect(self.iconLayer, iconPath, ICON_SIZE, ICON_SIZE)
  end
  if self.icon then
    self.icon.x = self.x
    self.icon.y = self.y
    return
  end

  -- Fallback when the ability has no icon or the image failed to load
  self.icon = display.newCircle(self.iconLayer, self.x, self.y, 20)
  if ability.id == "arcane_bolt" then
    self.icon:setFillColor(0.5, 0.3, 0.9) -- Purple for arcane
  elseif ability.id == "frost_nova" or ability.id == "frost_shard" then
    self.icon:setFillColor(0.5, 0.8, 1.0) -- Light blue for frost
  elseif ability.id == "flame_slash" then
    self.icon:setFillColor(1.0, 0.45, 0.2) -- Orange-red for fire
  elseif ability.id == "patrol_blades" then
    self.icon:setFillColor(0.85, 0.9, 1.0) -- Silver for blades
  elseif ability.isPassive then
    self.icon:setFillColor(1.0, 0.85, 0.3) -- Gold for passives
  else
    self.icon:setFillColor(0.9, 0.5, 0.2) -- Orange for other abilities
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
  self.iconLayer = nil
  self.cooldownOverlay = nil
  self.slotText = nil
  self.ability = nil
end

return AbilityIndicator
