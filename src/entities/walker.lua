-- Walker Entity
-- Basic melee enemy that advances toward the defensive wall

local placeholder_graphics = require("src.utils.placeholder_graphics")
local HealthBar = require("src.ui.health_bar")

local json = _G.json or require("json")

local Walker = Class("Walker")

-- Hard-coded fallback stats per enemy type (used when enemies.json is missing a value)
local DEFAULT_STATS = {
  walker = { health = 20, speed = 80, damage = 5, attackCooldown = 1.0 },
  runner = { health = 10, speed = 160, damage = 3, attackCooldown = 0.8 },
}

-- Placeholder look per enemy type
local TYPE_STYLES = {
  walker = { color = {0.9, 0.2, 0.2}, scale = 1.0 },
  runner = { color = {1.0, 0.6, 0.1}, scale = 0.75 },
}

-- Body tint while slowed
local SLOWED_COLOR = {0.5, 0.8, 1.0}

-- Load enemy stats from enemies.json (all types) with hard-coded fallbacks
local _enemiesConfig = nil
local function _loadEnemiesConfig()
  if _enemiesConfig then return _enemiesConfig end
  
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
    return decoded
  end)
  
  if success and type(config) == "table" then
    _enemiesConfig = config
  else
    _enemiesConfig = {}
  end
  return _enemiesConfig
end

local function _getEnemyStat(enemyType, key)
  local defaults = DEFAULT_STATS[enemyType] or DEFAULT_STATS.walker
  local typeConfig = _loadEnemiesConfig()[enemyType]
  if type(typeConfig) == "table" then
    local value = typeConfig[key]
    if type(value) == "number" and value > 0 then
      return value
    end
  end
  return defaults[key]
end

function Walker:initialize(parentGroup, enemyType)
  -- Parent display group for health bars and other display objects
  self.parentGroup = parentGroup
  
  -- Position properties
  self.x = 0
  self.y = 0
  self.lane = 0  -- Assigned lane (X coordinate)
  
  -- Enemy type sets health, speed, damage, and attack cooldown
  -- (read from enemies.json with hard-coded fallbacks)
  self:setType(enemyType or "walker")
  self.health = self.maxHealth
  self.lastAttackTime = 0  -- Timestamp of last attack
  
  -- Slow effect (from Frost Nova)
  self.slowFactor = 1.0
  self.slowRemaining = 0
  
  -- Wall targeting properties
  self.wallTarget = nil  -- Reference to wall entity
  self.isAttackingWall = false  -- Attack state flag
  
  -- XP properties (self.type also selects the XP value in enemies.json)
  self.xpValue = nil  -- Optional runtime XP override (defaults to config value)
  
  -- Pool state
  self.isActive = false
  
  -- Visual representation (placeholder circle for now)
  self.displayObject = nil
  
  -- Health bar
  self.healthBar = nil
end

--- Set the enemy type and load its stats
-- @param enemyType string Enemy type key in enemies.json ("walker", "runner")
function Walker:setType(enemyType)
  self.type = enemyType
  self.maxHealth = _getEnemyStat(enemyType, "health")
  self.speed = _getEnemyStat(enemyType, "speed")
  self.damage = _getEnemyStat(enemyType, "damage")
  self.attackCooldown = _getEnemyStat(enemyType, "attackCooldown")
end

--- Apply the body color and size for the current type and slow state
function Walker:refreshStyle()
  if not self.displayObject then
    return
  end
  
  local style = TYPE_STYLES[self.type] or TYPE_STYLES.walker
  self.displayObject.xScale = style.scale
  self.displayObject.yScale = style.scale
  
  local body = self.displayObject[1]
  if body and body.setFillColor then
    local color = self.slowRemaining > 0 and SLOWED_COLOR or style.color
    body:setFillColor(color[1], color[2], color[3])
  end
end

--- Slow this enemy for a duration
-- The strongest active slow wins; the duration extends to the longest one.
-- @param factor number Speed multiplier while slowed (0-1, lower is slower)
-- @param duration number Seconds the slow lasts
function Walker:applySlow(factor, duration)
  if not self.isActive then
    return
  end
  
  if self.slowRemaining <= 0 or factor < self.slowFactor then
    self.slowFactor = factor
  end
  self.slowRemaining = math.max(self.slowRemaining, duration)
  self:refreshStyle()
end

--- Current movement speed after slow effects
-- @return number Pixels per second
function Walker:getCurrentSpeed()
  if self.slowRemaining > 0 then
    return self.speed * self.slowFactor
  end
  return self.speed
end

function Walker:activate(x, y, lane, enemyType)
  -- Set spawn position and lane
  self.x = x
  self.y = y
  self.lane = lane
  
  -- Pooled walkers can come back as a different type
  if enemyType and enemyType ~= self.type then
    self:setType(enemyType)
  end
  
  -- Reset health
  self.health = self.maxHealth
  
  -- Clear any slow left over from the previous life
  self.slowFactor = 1.0
  self.slowRemaining = 0
  
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
  
  self:refreshStyle()
end

function Walker:update(dt, wallThreshold)
  if not self.isActive then
    return
  end
  
  -- Speed for this frame, taken before the slow ticks down
  local speed = self:getCurrentSpeed()
  
  -- Tick down the slow effect
  if self.slowRemaining > 0 then
    self.slowRemaining = self.slowRemaining - dt
    if self.slowRemaining <= 0 then
      self.slowRemaining = 0
      self.slowFactor = 1.0
      self:refreshStyle()
    end
  end
  
  -- Check if walker has reached the wall threshold
  if self.y >= wallThreshold then
    -- Stop moving and set attacking state
    self.isAttackingWall = true
  else
    -- Continue moving downward toward the wall
    self.y = self.y + (speed * dt)
    
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
