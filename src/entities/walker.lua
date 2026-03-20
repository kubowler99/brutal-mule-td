-- Walker Entity
-- Basic melee enemy that advances toward the defensive wall

local placeholder_graphics = require("src.utils.placeholder_graphics")
local HealthBar = require("src.ui.health_bar")

local json = _G.json or require("json")

local Walker = Class("Walker")

-- Load walker stats from enemies.json with hard-coded fallbacks
local _walkerConfig = nil
local function _loadWalkerConfig()
  if _walkerConfig then return _walkerConfig end
  
  local success, config = pcall(function()
    local path = system.pathForFile("data/enemies.json", system.ResourceDirectory)
    if not path then return nil end
    local file = io.open(path, "r")
    if not file then return nil end
    local contents = file:read("*a")
    file:close()
    if not contents or contents == "" then return nil end
    local decoded = json.decode(contents)
    if type(decoded) ~= "table" then return nil end
    return decoded.walker
  end)
  
  if success and type(config) == "table" then
    _walkerConfig = config
  else
    _walkerConfig = {}
  end
  return _walkerConfig
end

local function _getWalkerStat(key, default)
  local config = _loadWalkerConfig()
  local value = config[key]
  if type(value) == "number" and value > 0 then
    return value
  end
  return default
end

function Walker:initialize(parentGroup)
  -- Parent display group for health bars and other display objects
  self.parentGroup = parentGroup
  
  -- Position properties
  self.x = 0
  self.y = 0
  self.lane = 0  -- Assigned lane (X coordinate)
  
  -- Health properties (read from enemies.json with hard-coded fallbacks)
  local configHealth = _getWalkerStat("health", 20)
  self.health = configHealth
  self.maxHealth = configHealth
  
  -- Movement and combat properties (read from enemies.json with hard-coded fallbacks)
  self.speed = _getWalkerStat("speed", 80)
  self.damage = _getWalkerStat("damage", 5)
  self.attackCooldown = _getWalkerStat("attackCooldown", 1.0)
  self.lastAttackTime = 0  -- Timestamp of last attack
  
  -- Wall targeting properties
  self.wallTarget = nil  -- Reference to wall entity
  self.isAttackingWall = false  -- Attack state flag
  
  -- XP properties
  self.type = "walker"  -- Enemy type for XP configuration lookup
  self.xpValue = nil  -- Optional runtime XP override (defaults to config value)
  
  -- Pool state
  self.isActive = false
  
  -- Visual representation (placeholder circle for now)
  self.displayObject = nil
  
  -- Health bar
  self.healthBar = nil
end

function Walker:activate(x, y, lane)
  -- Set spawn position and lane
  self.x = x
  self.y = y
  self.lane = lane
  
  -- Reset health
  self.health = self.maxHealth
  
  -- Reset attack timer
  self.lastAttackTime = 0
  
  -- Reset wall targeting
  self.wallTarget = nil
  self.isAttackingWall = false
  
  -- Mark as active
  self.isActive = true
  
  -- Create or update display object
  if not self.displayObject then
    self.displayObject = placeholder_graphics.createWalkerSprite(self.x, self.y)
    if self.parentGroup and self.displayObject then
      self.parentGroup:insert(self.displayObject)
    end
  else
    self.displayObject.x = self.x
    self.displayObject.y = self.y
    self.displayObject.isVisible = true
  end
  
  -- Create or show health bar (30px wide, 4px tall, 25px above walker center)
  if self.healthBar then
    self.healthBar:destroy()
  end
  self.healthBar = HealthBar:new(self.x, self.y - 25, 30, 4, self.parentGroup)
  self.healthBar:update(self.health, self.maxHealth)
end

function Walker:update(dt, wallThreshold)
  if not self.isActive then
    return
  end
  
  -- Check if walker has reached the wall threshold
  if self.y >= wallThreshold then
    -- Stop moving and set attacking state
    self.isAttackingWall = true
  else
    -- Continue moving downward toward the wall
    self.y = self.y + (self.speed * dt)
    
    -- Check again after movement to ensure we don't overshoot
    if self.y >= wallThreshold then
      self.y = wallThreshold
      self.isAttackingWall = true
    end
  end
  
  -- Update display object position (always sync with logical position)
  if self.displayObject then
    self.displayObject.y = self.y
  end
  
  -- Sync health bar position with walker y
  if self.healthBar then
    local newBarY = self.y - 25
    if self.healthBar.background then
      self.healthBar.background.y = newBarY
    end
    if self.healthBar.foreground then
      self.healthBar.foreground.y = newBarY
    end
    self.healthBar.y = newBarY
  end
end

function Walker:takeDamage(amount)
  if not self.isActive then
    return
  end
  
  self.health = self.health - amount
  
  if self.health <= 0 then
    self.health = 0
    self:deactivate()
    return
  end
  
  -- Update health bar fill ratio
  if self.healthBar then
    self.healthBar:update(self.health, self.maxHealth)
  end
end

function Walker:deactivate()
  self.isActive = false
  
  -- Reset wall targeting
  self.wallTarget = nil
  self.isAttackingWall = false
  
  -- Hide display object
  if self.displayObject then
    self.displayObject.isVisible = false
  end
  
  -- Hide health bar
  if self.healthBar and self.healthBar.group then
    self.healthBar.group.isVisible = false
  end
end

function Walker:destroy()
  if self.healthBar then
    self.healthBar:destroy()
    self.healthBar = nil
  end
  if self.displayObject then
    self.displayObject:removeSelf()
    self.displayObject = nil
  end
end

return Walker
