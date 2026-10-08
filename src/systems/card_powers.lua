-- Card Powers
-- Applies the equipped cards' effects during a run. The game controller
-- calls start() with card_collection.getRunEffects() and hooks the functions
-- below into the game loop:
--   * passive stats that change damage, wall damage, burns, kills, XP,
--     wall revives, twin casts, and extra level-up picks
--   * active cards with charges, used from HUD buttons (use()) or the
--     level-up panel (useReroll())
--
-- Passive stats that the run's starting bonuses already cover (damage,
-- cooldown, wall health, XP, gold, projectiles, ability slots, start XP) are
-- read by the game controller and meta progression, not here.

local M = {}

-- Burn applied by Ember Brand
M.BURN_DAMAGE_PER_SECOND = 4
M.BURN_DURATION = 3

-- Chain Reaction explosion radius (pixels)
M.EXPLOSION_RADIUS = 90

-- Bulwark can never block more than this share of wall damage
M.MAX_WALL_DAMAGE_REDUCTION = 0.9

-- Arcane Singularity pulls enemies this close together (pixels of jitter)
M.SINGULARITY_SPREAD = 20

-- Run state
local stats = {}
local actives = {}
local context = {}
local revivesLeft = 0
local invulnerableTime = 0
local levelUps = 0
local resolvingBurn = false
local resolvingExplosion = false

--- A passive stat total, or 0
function M.stat(name)
  return stats[name] or 0
end

--- Start a run
-- @param effects table From card_collection.getRunEffects()
-- @param runContext table {
--   wall = Wall, hero = Hero,
--   getEnemies = function() -> active enemies list,
--   applyDamage = function(enemy, amount) -> killed,
--   rng = function|nil  -- random [0, 1), default math.random
-- }
function M.start(effects, runContext)
  effects = effects or {}
  stats = effects.stats or {}
  context = runContext or {}
  actives = {}
  for _, active in ipairs(effects.actives or {}) do
    table.insert(actives, {
      uid = active.uid,
      cardId = active.cardId,
      action = active.action,
      charges = active.charges or 0,
      chargesLeft = active.charges or 0,
      params = active.params or {},
    })
  end
  revivesLeft = M.stat("reviveWallPercent") > 0 and 1 or 0
  invulnerableTime = 0
  levelUps = 0
  resolvingBurn = false
  resolvingExplosion = false
end

--- End the run and forget everything
function M.cleanup()
  M.start(nil, nil)
end

local function random()
  return (context.rng or math.random)()
end

local function activeEnemies()
  local list = {}
  for _, enemy in ipairs(context.getEnemies and context.getEnemies() or {}) do
    if enemy.isActive then
      table.insert(list, enemy)
    end
  end
  return list
end

local function damage(enemy, amount)
  if context.applyDamage and amount > 0 then
    return context.applyDamage(enemy, amount)
  end
  return false
end

--- Count down timed effects
function M.update(dt)
  invulnerableTime = math.max(0, invulnerableTime - (dt or 0))
end

function M.isWallInvulnerable()
  return invulnerableTime > 0
end

-- Hooks -------------------------------------------------------------------

--- Damage dealt to an enemy, after Executioner's bonus vs elites and bosses
function M.modifyEnemyDamage(enemy, amount)
  if enemy and (enemy.isBoss or enemy.isElite) then
    return amount * (1 + M.stat("bossDamageMultiplier"))
  end
  return amount
end

--- Damage the wall takes from an enemy hit, after Bastion and Bulwark
function M.modifyWallDamage(amount)
  if M.isWallInvulnerable() then
    return 0
  end
  local reduction = math.min(M.MAX_WALL_DAMAGE_REDUCTION, M.stat("wallDamageReduction"))
  return amount * (1 - reduction)
end

--- An enemy hit the wall: Iron Spikes hit it back
function M.onWallHit(enemy)
  local thorns = M.stat("thornsDamage")
  if enemy and enemy.isActive and thorns > 0 then
    damage(enemy, thorns)
  end
end

--- Run burn damage through this so burn ticks cannot start new burns
function M.applyBurnDamage(fn)
  resolvingBurn = true
  local ok, result = pcall(fn)
  resolvingBurn = false
  if not ok then
    error(result)
  end
  return result
end

--- An enemy took a hit: Ember Brand may set it on fire
function M.onEnemyDamaged(enemy, amount, killed)
  if resolvingBurn or killed or not enemy or not enemy.applyBurn then
    return
  end
  local chance = M.stat("burnChance")
  if chance > 0 and random() < chance then
    enemy:applyBurn(M.BURN_DAMAGE_PER_SECOND, M.BURN_DURATION)
  end
end

--- An enemy died: Chain Reaction may explode (explosions do not chain)
function M.onEnemyKilled(enemy)
  if resolvingExplosion or not enemy then
    return
  end
  local chance = M.stat("killExplosionChance")
  local explosionDamage = M.stat("killExplosionDamage")
  if chance <= 0 or explosionDamage <= 0 or random() >= chance then
    return
  end
  resolvingExplosion = true
  local radiusSq = M.EXPLOSION_RADIUS * M.EXPLOSION_RADIUS
  for _, other in ipairs(activeEnemies()) do
    local dx, dy = other.x - enemy.x, other.y - enemy.y
    if dx * dx + dy * dy <= radiusSq then
      damage(other, explosionDamage)
    end
  end
  resolvingExplosion = false
end

--- Extra XP factor for a kill (Bounty Hunter boosts elites)
function M.xpMultiplierFor(enemy)
  if enemy and enemy.isElite then
    return 1 + M.stat("eliteXPMultiplier")
  end
  return 1
end

--- The wall just fell: Second Wind brings it back once
-- @return boolean True if the wall was revived
function M.tryReviveWall(wall)
  local percent = M.stat("reviveWallPercent")
  if revivesLeft <= 0 or percent <= 0 or not wall then
    return false
  end
  revivesLeft = revivesLeft - 1
  wall.health = math.max(1, math.floor(wall.maxHealth * math.min(1, percent)))
  return true
end

--- An ability just fired: Twin Cast may fire it again
function M.rollTwinCast()
  local chance = M.stat("twinCastChance")
  return chance > 0 and random() < chance
end

--- The hero leveled up: Ascendance gives an extra pick every Nth level-up
-- @return number Extra picks for this level-up (0 or 1)
function M.onLevelUp()
  levelUps = levelUps + 1
  local interval = math.floor(M.stat("ascendanceInterval"))
  if interval > 0 and levelUps % interval == 0 then
    return 1
  end
  return 0
end

-- Active cards ------------------------------------------------------------

--- Active cards for the HUD: { cardId, action, charges, chargesLeft, params }
-- (Second Opinion is used from the level-up panel, so it is left out)
function M.getHudActives()
  local list = {}
  for i, active in ipairs(actives) do
    if active.action ~= "rerollDraft" then
      table.insert(list, { index = i, cardId = active.cardId, action = active.action,
        charges = active.charges, chargesLeft = active.chargesLeft })
    end
  end
  return list
end

--- Charges left across all active cards with this action
function M.chargesLeft(action)
  local total = 0
  for _, active in ipairs(actives) do
    if active.action == action then
      total = total + active.chargesLeft
    end
  end
  return total
end

local ACTIONS = {}

function ACTIONS.healWall(params)
  local wall = context.wall
  if not wall then return false end
  wall.health = math.min(wall.maxHealth, wall.health + wall.maxHealth * (params.healPercent or 0))
  return true
end

function ACTIONS.strikeNearest(params)
  local enemies = activeEnemies()
  if #enemies == 0 then return false end
  -- Nearest to the wall first (the wall is at the bottom of the screen)
  table.sort(enemies, function(a, b) return a.y > b.y end)
  for i = 1, math.min(math.floor(params.targets or 0), #enemies) do
    damage(enemies[i], params.damage or 0)
  end
  return true
end

function ACTIONS.slowAll(params)
  local enemies = activeEnemies()
  if #enemies == 0 then return false end
  for _, enemy in ipairs(enemies) do
    if enemy.applySlow then
      enemy:applySlow(params.slowFactor or 1, params.duration or 0)
    end
  end
  return true
end

function ACTIONS.freezeAll(params)
  return ACTIONS.slowAll({ slowFactor = 0, duration = params.duration })
end

function ACTIONS.purge(params)
  local enemies = activeEnemies()
  if #enemies == 0 then return false end
  for _, enemy in ipairs(enemies) do
    if enemy.isBoss then
      damage(enemy, (enemy.maxHealth or 0) * (params.bossDamagePercent or 0))
    else
      damage(enemy, enemy.health or 0)
    end
  end
  return true
end

function ACTIONS.wallInvulnerable(params)
  invulnerableTime = math.max(invulnerableTime, params.duration or 0)
  return true
end

function ACTIONS.meteorStorm(params)
  local enemies = activeEnemies()
  if #enemies == 0 then return false end
  for _ = 1, math.floor(params.count or 0) do
    local targets = activeEnemies()
    if #targets == 0 then break end
    local target = targets[math.min(#targets, math.floor(random() * #targets) + 1)]
    damage(target, params.damage or 0)
  end
  return true
end

function ACTIONS.singularity(params)
  local pulled = {}
  for _, enemy in ipairs(activeEnemies()) do
    if not enemy.isBoss then
      table.insert(pulled, enemy)
    end
  end
  if #pulled == 0 then return false end
  local centerX, centerY = 0, 0
  for _, enemy in ipairs(pulled) do
    centerX, centerY = centerX + enemy.x, centerY + enemy.y
  end
  centerX, centerY = centerX / #pulled, centerY / #pulled
  for _, enemy in ipairs(pulled) do
    enemy.x = centerX + (random() - 0.5) * M.SINGULARITY_SPREAD
    enemy.y = centerY + (random() - 0.5) * M.SINGULARITY_SPREAD
    damage(enemy, params.damage or 0)
  end
  return true
end

--- Use an active card from the full actives list
-- @param index number Position in the actives list (getHudActives().index)
-- @return boolean True if a charge was spent
function M.use(index)
  local active = actives[index]
  local action = active and ACTIONS[active.action]
  if not action or active.chargesLeft <= 0 then
    return false
  end
  if not action(active.params) then
    return false  -- nothing to hit; keep the charge
  end
  active.chargesLeft = active.chargesLeft - 1
  return true
end

--- Spend a Second Opinion charge to reroll the level-up draft
-- @return boolean True if a charge was spent
function M.useReroll()
  for _, active in ipairs(actives) do
    if active.action == "rerollDraft" and active.chargesLeft > 0 then
      active.chargesLeft = active.chargesLeft - 1
      return true
    end
  end
  return false
end

return M
