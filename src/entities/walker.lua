-- Walker Entity
-- Basic melee enemy that advances toward the defensive wall

local HealthBar = require("src.ui.health_bar")

local json = _G.json or require("json")

-- Sprite sheet data for walker animations
local runSheetInfo = require("assets.images.sprites.zombie_run_with_shadow_down")
local attackSheetInfo = require("assets.images.sprites.zombie_attack_with_shadow_down")

-- Pre-create image sheets (shared across all walker instances)
local _runSheet = nil
local _attackSheet = nil
local _sequenceData = nil

local function _ensureSheets()
  if _runSheet then return end
  _runSheet = graphics.newImageSheet(
    "assets/images/sprites/zombie_run_with_shadow_down.png",
    runSheetInfo:getSheet()
  )
  _attackSheet = graphics.newImageSheet(
    "assets/images/sprites/zombie_attack_with_shadow_down.png",
    attackSheetInfo:getSheet()
  )
  _sequenceData = {
    { name = "run",    sheet = _runSheet,    frames = runSheetInfo:getAnimation("Zombie1-run-with-shadow-down"),       time = 800, loopCount = 0 },
    { name = "attack", sheet = _attackSheet, frames = attackSheetInfo:getAnimation("Zombie1-Attack-With-Shadow-down"), time = 800, loopCount = 0 },
  }
end

local Walker = Class("Walker")

-- Hard-coded fallback stats per enemy type (used when enemies.json is missing a value)
local DEFAULT_STATS = {
  walker = { health = 20, speed = 80, damage = 5, attackCooldown = 1.0 },
  runner = { health = 10, speed = 160, damage = 3, attackCooldown = 0.8 },
  brute = { health = 80, speed = 40, damage = 12, attackCooldown = 1.5 },
  swarmling = { health = 4, speed = 110, damage = 1, attackCooldown = 0.6 },
}

-- Scale applied to the 64x64 zombie sprite frames
local SPRITE_SCALE = 96 / 64

-- Sprite tint and size multiplier per enemy type
local TYPE_STYLES = {
  walker = { tint = {1.0, 1.0, 1.0}, scale = 1.0 },
  runner = { tint = {1.0, 0.65, 0.3}, scale = 0.75 },
  brute = { tint = {0.75, 0.45, 1.0}, scale = 1.35 },
  swarmling = { tint = {0.55, 1.0, 0.45}, scale = 0.5 },
}

-- Sprite tint while slowed
local SLOWED_TINT = {0.5, 0.8, 1.0}

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
  
  -- Visual representation
  self.displayObject = nil
  self._currentAnim = nil
  
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
  self.displayObject.xScale = SPRITE_SCALE * style.scale
  self.displayObject.yScale = SPRITE_SCALE * style.scale
  
  if self.displayObject.setFillColor then
    local tint = self.slowRemaining > 0 and SLOWED_TINT or style.tint
    self.displayObject:setFillColor(tint[1], tint[2], tint[3])
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
  
  -- Create or update display object (animated sprite)
  if not self.displayObject then
    _ensureSheets()
    self.displayObject = display.newSprite(_runSheet, _sequenceData)
    -- Scale and tint are set per enemy type in refreshStyle()
    self.displayObject.x = self.x
    self.displayObject.y = self.y
    self.displayObject:setSequence("run")
    self.displayObject:play()
    if self.parentGroup and self.displayObject then
      self.parentGroup:insert(self.displayObject)
    end
  else
    self.displayObject.x = self.x
    self.displayObject.y = self.y
    self.displayObject.isVisible = true
    self.displayObject:setSequence("run")
    self.displayObject:play()
  end
  self._currentAnim = "run"
  
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
  
  -- Switch to attack animation when attacking wall
  if self.isAttackingWall and self._currentAnim ~= "attack" then
    if self.displayObject and self.displayObject.setSequence then
      self.displayObject:setSequence("attack")
      self.displayObject:play()
      self._currentAnim = "attack"
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
  
  -- Hide display object and stop animation
  if self.displayObject then
    self.displayObject.isVisible = false
    if self.displayObject.pause then
      self.displayObject:pause()
    end
  end
  self._currentAnim = nil
  
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
