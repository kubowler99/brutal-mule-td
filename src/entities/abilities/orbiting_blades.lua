-- Orbiting Blades Ability
-- Blades circle the ability's slot on the wall and cut enemies they touch.
-- Always active: it runs every frame through update() instead of a cooldown.

local ability_data_loader = require("src.models.ability_data_loader")
local combat_system = require("src.systems.combat_system")

local OrbitingBlades = Class("OrbitingBlades")

-- Hard-coded fallback defaults (used when ability_data_loader has no data)
local DEFAULT_BLADE_COUNT = 2
local DEFAULT_DAMAGE = 6
local DEFAULT_ORBIT_RADIUS = 80
local DEFAULT_ROTATION_SPEED = 2.5  -- radians per second
local DEFAULT_HIT_RADIUS = 18
local DEFAULT_HIT_COOLDOWN = 0.5    -- seconds before the same enemy can be hit again

-- Upgrade fallback defaults
local DEFAULT_COUNT_INCREASE = 1
local DEFAULT_MAX_BLADES = 6
local DEFAULT_SPEED_MULTIPLIER = 1.25
local DEFAULT_DAMAGE_INCREASE = 3
local DEFAULT_SIZE_INCREASE = 6

-- Blade visual
local BLADE_COLOR = {0.85, 0.9, 1.0}
local BLADE_VISUAL_SCALE = 0.5  -- drawn radius relative to hit radius

function OrbitingBlades:initialize()
  self.id = "orbiting_blades"
  self.name = "Orbiting Blades"

  local baseStats = ability_data_loader.getBaseStats("orbiting_blades")

  self.bladeCount = (baseStats and baseStats.bladeCount) or DEFAULT_BLADE_COUNT
  self.damage = (baseStats and baseStats.damage) or DEFAULT_DAMAGE
  self.orbitRadius = (baseStats and baseStats.orbitRadius) or DEFAULT_ORBIT_RADIUS
  self.rotationSpeed = (baseStats and baseStats.rotationSpeed) or DEFAULT_ROTATION_SPEED
  self.hitRadius = (baseStats and baseStats.hitRadius) or DEFAULT_HIT_RADIUS
  self.hitCooldown = (baseStats and baseStats.hitCooldown) or DEFAULT_HIT_COOLDOWN
  self.baseHitRadius = self.hitRadius  -- blades are drawn scaled to hitRadius / baseHitRadius

  self.tier = 1
  self.angle = 0
  self.elapsed = 0

  -- Time each enemy was last hit; weak keys so pooled enemies are not kept alive
  self.lastHitTime = setmetatable({}, { __mode = "k" })

  -- Blade display objects, created on the first update with a display group
  self.bladeObjects = {}
end

--- Blades never fire on a cooldown; they act in update()
function OrbitingBlades:canActivate()
  return false
end

--- Current position of each blade around the origin
-- @param originX number Orbit center X
-- @param originY number Orbit center Y
-- @return table Array of { x, y }
function OrbitingBlades:getBladePositions(originX, originY)
  local positions = {}
  for i = 1, self.bladeCount do
    local bladeAngle = self.angle + (i - 1) * (2 * math.pi / self.bladeCount)
    positions[i] = {
      x = originX + math.cos(bladeAngle) * self.orbitRadius,
      y = originY + math.sin(bladeAngle) * self.orbitRadius,
    }
  end
  return positions
end

--- Keep one display object per blade and move them to the blade positions
local function syncBladeObjects(self, positions, displayGroup)
  if not displayGroup then
    return
  end

  -- Create missing blades (blade count can grow through upgrades)
  while #self.bladeObjects < #positions do
    local blade = display.newCircle(displayGroup, 0, 0, self.baseHitRadius * BLADE_VISUAL_SCALE)
    blade:setFillColor(BLADE_COLOR[1], BLADE_COLOR[2], BLADE_COLOR[3])
    table.insert(self.bladeObjects, blade)
  end

  -- Blade size upgrades grow the drawn blades with the hit radius
  local scale = self.hitRadius / self.baseHitRadius
  for i, blade in ipairs(self.bladeObjects) do
    blade.x = positions[i].x
    blade.y = positions[i].y
    blade.xScale = scale
    blade.yScale = scale
  end
end

--- Rotate the blades and damage enemies they touch
-- @param dt number Delta time in seconds
-- @param originX number Orbit center X (the ability's slot on the wall)
-- @param originY number Orbit center Y
-- @param enemies table Array of enemies
-- @param displayGroup table|nil Group to draw blades into
-- @param heroStats table|nil Hero stats; damageMultiplier scales damage
function OrbitingBlades:update(dt, originX, originY, enemies, displayGroup, heroStats)
  self.elapsed = self.elapsed + dt
  self.angle = (self.angle + self.rotationSpeed * dt) % (2 * math.pi)

  local positions = self:getBladePositions(originX, originY)
  syncBladeObjects(self, positions, displayGroup)

  if not enemies then
    return
  end

  local damage = self.damage * ((heroStats and heroStats.damageMultiplier) or 1)
  local hitRadiusSq = self.hitRadius * self.hitRadius

  for _, enemy in ipairs(enemies) do
    if enemy.isActive then
      local lastHit = self.lastHitTime[enemy]
      if not lastHit or self.elapsed - lastHit >= self.hitCooldown then
        for _, blade in ipairs(positions) do
          local dx = enemy.x - blade.x
          local dy = enemy.y - blade.y
          if dx * dx + dy * dy <= hitRadiusSq then
            self.lastHitTime[enemy] = self.elapsed
            combat_system.applyDamage(enemy, damage)
            break
          end
        end
      end
    end
  end
end

function OrbitingBlades:upgrade(upgradeType)
  local params = ability_data_loader.getUpgradeParams("orbiting_blades", upgradeType)

  if upgradeType == "blade_count" then
    local increase = (params and params.countIncrease) or DEFAULT_COUNT_INCREASE
    local maxBlades = (params and params.maxBlades) or DEFAULT_MAX_BLADES
    self.bladeCount = math.min(self.bladeCount + increase, maxBlades)
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "rotation_speed" then
    local multiplier = (params and params.speedMultiplier) or DEFAULT_SPEED_MULTIPLIER
    self.rotationSpeed = self.rotationSpeed * multiplier
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "damage_increase" then
    local increase = (params and params.damageIncrease) or DEFAULT_DAMAGE_INCREASE
    self.damage = self.damage + increase
    self.tier = math.min(self.tier + 1, 5)

  elseif upgradeType == "blade_size" then
    local increase = (params and params.sizeIncrease) or DEFAULT_SIZE_INCREASE
    self.hitRadius = self.hitRadius + increase
    self.tier = math.min(self.tier + 1, 5)
  end
end

--- Remove blade display objects
function OrbitingBlades:destroy()
  for _, blade in ipairs(self.bladeObjects) do
    if blade.removeSelf then
      blade:removeSelf()
    end
  end
  self.bladeObjects = {}
end

return OrbitingBlades
