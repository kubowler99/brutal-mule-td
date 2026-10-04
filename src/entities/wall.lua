-- Wall Entity
-- Defensive structure that serves as the primary damage target

local config_loader = require("src.models.config_loader")

local Wall = Class("Wall")

-- Wall height on screen and the stone wall texture tiled across it
local WALL_HEIGHT = 80
local TEXTURE_PATH = "assets/images/wall/wall.png"
local TEXTURE_WIDTH = 383
local TEXTURE_HEIGHT = 214

-- Tint applied briefly when the wall takes damage
local FLASH_TINT = {1, 0.55, 0.55}
local FLASH_MS = 120

--- Tile the wall texture across the wall width. Every other tile is
--- mirrored so the edges always line up.
-- @return table Display group, or nil if the texture fails to load
local function createTiledWall(x, y, width)
  local tileWidth = WALL_HEIGHT * TEXTURE_WIDTH / TEXTURE_HEIGHT
  local tileCount = math.ceil(width / tileWidth)
  local group = display.newGroup()
  local left = -width / 2
  for i = 1, tileCount do
    local tile = display.newImageRect(group, TEXTURE_PATH, tileWidth, WALL_HEIGHT)
    if not tile then
      group:removeSelf()
      return nil
    end
    tile.x = left + (i - 0.5) * tileWidth
    tile.y = 0
    if i % 2 == 0 then
      tile.xScale = -1
    end
  end
  group.x = x
  group.y = y
  return group
end

function Wall:initialize(x, y, width)
  -- Position properties
  self.x = x
  self.y = y or 1200
  self.width = width
  
  -- Health properties (read from config_loader with hard-coded fallbacks)
  self.health = config_loader.positiveNumber(config_loader.get("wall.health"), 100)
  self.maxHealth = config_loader.positiveNumber(config_loader.get("wall.maxHealth"), 100)
  
  -- Visual representation: stone texture tiled across the screen width,
  -- or a plain rectangle if the texture fails to load
  self.displayObject = createTiledWall(self.x, self.y, self.width)
  if not self.displayObject then
    self.displayObject = display.newRect(self.x, self.y, self.width, WALL_HEIGHT)
    self.displayObject:setFillColor(0.4, 0.3, 0.2)  -- Brown/stone color
    self.displayObject.strokeWidth = 3
    self.displayObject:setStrokeColor(0.2, 0.15, 0.1)  -- Darker border
    self.isPlaceholder = true
  end
end

function Wall:takeDamage(amount)
  -- Clamp damage to non-negative values
  if amount < 0 then
    amount = 0
  end
  
  -- Reduce health by damage amount
  self.health = self.health - amount
  
  -- Clamp health to minimum 0
  if self.health < 0 then
    self.health = 0
  end
  
  -- Trigger visual feedback
  self:flashDamage()
end

function Wall:isDead()
  return self.health <= 0
end

function Wall:flashDamage()
  if not self.displayObject then
    return
  end
  
  if self.isPlaceholder then
    -- Flash to lighter color
    transition.to(self.displayObject, {
      time = 100,
      fillColor = {0.8, 0.6, 0.4},
      onComplete = function()
        -- Return to normal color
        transition.to(self.displayObject, {
          time = 100,
          fillColor = {0.4, 0.3, 0.2}
        })
      end
    })
    return
  end
  
  -- Tint every tile red, then clear the tint
  local group = self.displayObject
  for i = 1, group.numChildren or 0 do
    group[i]:setFillColor(FLASH_TINT[1], FLASH_TINT[2], FLASH_TINT[3])
  end
  timer.performWithDelay(FLASH_MS, function()
    if self.displayObject ~= group then
      return
    end
    for i = 1, group.numChildren or 0 do
      group[i]:setFillColor(1, 1, 1)
    end
  end)
end

function Wall:destroy()
  if self.displayObject then
    self.displayObject:removeSelf()
    self.displayObject = nil
  end
end

return Wall
