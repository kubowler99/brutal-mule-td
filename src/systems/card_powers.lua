-- Card Powers
-- Applies the equipped cards' effects during a run, including their level 5
-- and 15 milestone bonuses. The game controller calls start() with
-- card_collection.getRunEffects() and hooks the functions below into the
-- game loop:
--   * passive stats that change damage, wall damage, burns, kills, XP, gold,
--     wall revives and regeneration, twin casts, and level-up drafts
--   * active cards with charges, used from HUD buttons (use()) or the
--     level-up panel (useReroll())
--
-- Passive stats that the run's starting bonuses already cover (damage,
-- cooldown, wall health, XP, gold multiplier, projectiles, ability slots,
-- start XP) are read by the game controller and meta progression, not here.

local M = {}

-- Burn applied by Ember Brand and Chain Reaction explosions
M.BURN_DAMAGE_PER_SECOND = 4
M.BURN_DURATION = 3

-- Chain Reaction explosion radius (pixels)
M.EXPLOSION_RADIUS = 90

-- Bulwark can never block more than this share of wall damage
M.MAX_WALL_DAMAGE_REDUCTION = 0.9

-- Crits deal this many times normal damage before crit damage bonuses
M.CRIT_MULTIPLIER = 2

-- Iron Spikes slow (speed multiplier while slowed)
M.THORNS_SLOW_FACTOR = 0.6

-- Head Start's early XP bonus lasts this long (seconds)
M.EARLY_XP_TIME = 120

-- Arcane Singularity pulls enemies this close together (pixels of jitter)
M.SINGULARITY_SPREAD = 20

-- Arcane Singularity's rift: radius, damage per second as a share of the
-- pull damage, and seconds between damage ticks
M.RIFT_RADIUS = 120
M.RIFT_DAMAGE_SHARE = 0.1
M.RIFT_TICK = 0.5

-- Meteor Storm's burn lasts this long (seconds)
M.METEOR_BURN_DURATION = 3

-- Run state
local stats = {}
local actives = {}
local context = {}
local revivesLeft = 0
local shieldTime = 0          -- Wall Patch shield
local bastionTime = 0         -- Bastion
local bastionParams = {}
local timeStopTime = 0
local timeStopParams = {}
local wallBlockCooldown = 0   -- Bulwark: time until the next hit is ignored
local pendingSlows = {}       -- Frost Pulse: slows that start after a freeze
local rifts = {}              -- Arcane Singularity rifts
local levelUps = 0
local resolvingBurn = false
local explosionDepth = 0

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
--   getElapsed = function() -> seconds since the run started (optional),
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
  revivesLeft = 0
  if M.stat("reviveWallPercent") > 0 then
    revivesLeft = 1 + math.floor(M.stat("extraRevives"))
  end
  shieldTime, bastionTime, timeStopTime = 0, 0, 0
  bastionParams, timeStopParams = {}, {}
  wallBlockCooldown = 0
  pendingSlows, rifts = {}, {}
  levelUps = 0
  resolvingBurn = false
  explosionDepth = 0
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

local function healWall(amount)
  local wall = context.wall
  if wall and amount > 0 then
    wall.health = math.min(wall.maxHealth, wall.health + amount)
  end
end

--- Push an enemy away from the wall and make it walk back
local function knockBack(enemy, distance)
  if enemy and distance > 0 then
    enemy.y = enemy.y - distance
    enemy.wallTarget = nil
    enemy.isAttackingWall = false
  end
end

--- Let every hero ability fire again right away
function M.resetCooldowns()
  local hero = context.hero
  for _, ability in ipairs(hero and hero.abilities or {}) do
    if ability.lastActivation then
      ability.lastActivation = -math.huge
    end
  end
end

local function isFrozen(enemy)
  return (enemy.slowRemaining or 0) > 0 and enemy.slowFactor == 0
end

--- Count down timed effects and run rifts, delayed slows, and regeneration
function M.update(dt)
  dt = dt or 0
  shieldTime = math.max(0, shieldTime - dt)
  bastionTime = math.max(0, bastionTime - dt)
  wallBlockCooldown = math.max(0, wallBlockCooldown - dt)

  if timeStopTime > 0 then
    timeStopTime = timeStopTime - dt
    if timeStopTime <= 0 then
      timeStopTime = 0
      -- Time Stop level 15: cooldowns refresh when it ends
      if (timeStopParams.refreshCooldowns or 0) > 0 then
        M.resetCooldowns()
      end
    end
  end

  -- Stone Mortar level 15: wall regeneration
  local regen = M.stat("wallRegen")
  if regen > 0 then
    healWall(regen * dt)
  end

  -- Frost Pulse level 15: the slow starts once the freeze ends
  for i = #pendingSlows, 1, -1 do
    local pending = pendingSlows[i]
    pending.delay = pending.delay - dt
    if pending.delay <= 0 then
      for _, enemy in ipairs(pending.enemies) do
        if enemy.isActive and enemy.applySlow then
          if isFrozen(enemy) then
            enemy.slowRemaining = 0
          end
          enemy:applySlow(pending.factor, pending.duration)
        end
      end
      table.remove(pendingSlows, i)
    end
  end

  -- Arcane Singularity level 15: rifts damage enemies near them
  for i = #rifts, 1, -1 do
    local rift = rifts[i]
    rift.remaining = rift.remaining - dt
    rift.tickTimer = rift.tickTimer + dt
    while rift.tickTimer >= M.RIFT_TICK do
      rift.tickTimer = rift.tickTimer - M.RIFT_TICK
      local radiusSq = M.RIFT_RADIUS * M.RIFT_RADIUS
      for _, enemy in ipairs(activeEnemies()) do
        local dx, dy = enemy.x - rift.x, enemy.y - rift.y
        if dx * dx + dy * dy <= radiusSq then
          damage(enemy, rift.damagePerSecond * M.RIFT_TICK)
        end
      end
    end
    if rift.remaining <= 0 then
      table.remove(rifts, i)
    end
  end
end

function M.isWallInvulnerable()
  return shieldTime > 0 or bastionTime > 0
end

function M.isTimeStopped()
  return timeStopTime > 0
end

-- Hooks -------------------------------------------------------------------

--- Damage dealt to an enemy after card bonuses: Executioner vs elites and
--- bosses, burning, slowed, and frozen bonuses, crits, and executes
function M.modifyEnemyDamage(enemy, amount)
  if not enemy then
    return amount
  end
  local bonus = 0
  if enemy.isBoss or enemy.isElite then
    bonus = bonus + M.stat("bossDamageMultiplier")
  end
  if (enemy.burnRemaining or 0) > 0 then
    bonus = bonus + M.stat("burningDamageBonus")
  end
  if (enemy.slowRemaining or 0) > 0 then
    bonus = bonus + M.stat("slowedDamageBonus")
  end
  if M.isTimeStopped() and isFrozen(enemy) then
    bonus = bonus + (timeStopParams.damageBonus or 0)
  end
  amount = amount * (1 + bonus)

  -- Crits come from cards and from the hero's passives (Keen Eye)
  local heroStats = context.hero and context.hero.getStats and context.hero:getStats() or {}
  local critChance = M.stat("critChance") + (heroStats.critChance or 0)
  if critChance > 0 and random() < critChance then
    amount = amount * (M.CRIT_MULTIPLIER + M.stat("critDamageBonus") + (heroStats.critDamageBonus or 0))
  end

  -- Executioner level 15: finish off enemies left below the threshold
  local threshold = M.stat("executeThreshold")
  if threshold > 0 and not enemy.isBoss and enemy.health and enemy.maxHealth then
    if enemy.health - amount < enemy.maxHealth * threshold then
      amount = math.max(amount, enemy.health)
    end
  end
  return amount
end

--- Damage the wall takes from an enemy hit, after Wall Patch's shield,
--- Bastion, Bulwark, and Bulwark's milestones
-- @param amount number Damage before cards
-- @param enemy table|nil The attacking enemy
function M.modifyWallDamage(amount, enemy)
  if bastionTime > 0 then
    -- Bastion milestones: reflect blocked damage and knock the attacker back
    if enemy and enemy.isActive then
      damage(enemy, amount * (bastionParams.reflect or 0))
      knockBack(enemy, bastionParams.knockback or 0)
    end
    return 0
  end
  if shieldTime > 0 then
    return 0
  end

  -- Bulwark level 15: ignore one hit every few seconds
  local blockInterval = M.stat("wallBlockInterval")
  if blockInterval > 0 and wallBlockCooldown <= 0 then
    wallBlockCooldown = blockInterval
    return 0
  end

  local reduction = M.stat("wallDamageReduction")
  if enemy and enemy.isBoss then
    reduction = reduction + M.stat("bossWallDamageReduction")
  end
  reduction = math.min(M.MAX_WALL_DAMAGE_REDUCTION, reduction)
  return amount * (1 - reduction)
end

--- An enemy hit the wall: Iron Spikes hit it back (and its milestones)
function M.onWallHit(enemy)
  local thorns = M.stat("thornsDamage")
  if not enemy or not enemy.isActive or thorns <= 0 then
    return
  end
  if enemy.isElite then
    thorns = thorns * (1 + M.stat("thornsEliteMultiplier"))
  end
  damage(enemy, thorns)
  local slowDuration = M.stat("thornsSlowDuration")
  if slowDuration > 0 and enemy.isActive and enemy.applySlow then
    enemy:applySlow(M.THORNS_SLOW_FACTOR, slowDuration)
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

local function burnDuration()
  return M.BURN_DURATION + M.stat("burnDurationBonus")
end

--- An enemy took a hit: Ember Brand may set it on fire
function M.onEnemyDamaged(enemy, amount, killed)
  if resolvingBurn or killed or not enemy or not enemy.applyBurn then
    return
  end
  local chance = M.stat("burnChance")
  if chance > 0 and random() < chance then
    enemy:applyBurn(M.BURN_DAMAGE_PER_SECOND, burnDuration())
  end
end

--- An enemy died: Chain Reaction may explode. Explosions chain only as many
--- times as the card's level 15 milestone allows.
function M.onEnemyKilled(enemy)
  if not enemy or explosionDepth > math.floor(M.stat("explosionChains")) then
    return
  end
  local chance = M.stat("killExplosionChance")
  local explosionDamage = M.stat("killExplosionDamage")
  if chance <= 0 or explosionDamage <= 0 or random() >= chance then
    return
  end
  explosionDepth = explosionDepth + 1
  local radiusSq = M.EXPLOSION_RADIUS * M.EXPLOSION_RADIUS
  local burns = M.stat("explosionBurn") > 0
  for _, other in ipairs(activeEnemies()) do
    local dx, dy = other.x - enemy.x, other.y - enemy.y
    if dx * dx + dy * dy <= radiusSq then
      local killed = damage(other, explosionDamage)
      if burns and not killed and other.isActive and other.applyBurn then
        other:applyBurn(M.BURN_DAMAGE_PER_SECOND, burnDuration())
      end
    end
  end
  explosionDepth = explosionDepth - 1
end

--- Extra XP factor for a kill: Bounty Hunter (elites), Scholar's Notes
--- (bosses), and Head Start's early bonus
function M.xpMultiplierFor(enemy)
  local multiplier = 1
  if enemy and enemy.isElite then
    multiplier = multiplier + M.stat("eliteXPMultiplier")
  end
  if enemy and enemy.isBoss then
    multiplier = multiplier + M.stat("bossXPMultiplier")
  end
  local elapsed = context.getElapsed and context.getElapsed()
  if elapsed and elapsed < M.EARLY_XP_TIME then
    multiplier = multiplier + M.stat("earlyXPMultiplier")
  end
  return multiplier
end

--- Extra gold for a kill: Gold Pouch (bosses) and Bounty Hunter (elites)
function M.goldForKill(enemy)
  local gold = 0
  if enemy and enemy.isBoss then
    gold = gold + M.stat("bossGold")
  end
  if enemy and enemy.isElite then
    gold = gold + M.stat("eliteGold")
  end
  return gold
end

--- The wall just fell: Second Wind brings it back (once, or twice at
--- level 15) and can push every enemy back (level 5)
-- @return boolean True if the wall was revived
function M.tryReviveWall(wall)
  local percent = M.stat("reviveWallPercent")
  if revivesLeft <= 0 or percent <= 0 or not wall then
    return false
  end
  revivesLeft = revivesLeft - 1
  wall.health = math.max(1, math.floor(wall.maxHealth * math.min(1, percent)))
  local push = M.stat("reviveKnockback")
  if push > 0 then
    for _, enemy in ipairs(activeEnemies()) do
      knockBack(enemy, push)
    end
  end
  return true
end

--- An ability just fired: Twin Cast may fire it again
function M.rollTwinCast()
  local chance = M.stat("twinCastChance")
  return chance > 0 and random() < chance
end

--- Whether a twin cast may roll for a third cast (Twin Cast level 15)
function M.canTripleCast()
  return M.stat("twinCastExtraRoll") > 0
end

--- Stats for one ability slot: the sixth slot and beyond get Sixth Seal's
--- damage bonus, and twin casts get Twin Cast's damage bonus
-- @param heroStats table|nil Hero stats
-- @param slot number Ability slot
-- @param twin boolean|nil True for a twin cast
-- @return table|nil Stats to pass to the ability
function M.statsFor(heroStats, slot, twin)
  local bonus = 0
  if slot and slot >= 6 then
    bonus = bonus + M.stat("sixthAbilityDamage")
  end
  if twin then
    bonus = bonus + M.stat("twinCastDamageBonus")
  end
  if bonus == 0 or not heroStats then
    return heroStats
  end
  local copy = {}
  for key, value in pairs(heroStats) do
    copy[key] = value
  end
  copy.damageMultiplier = (copy.damageMultiplier or 1) * (1 + bonus)
  return copy
end

--- The hero leveled up
-- @return number Extra picks for this level-up (Ascendance: 0 or 1)
-- @return number Extra cards in this draft (Scholar's Notes: first draft only)
function M.onLevelUp()
  levelUps = levelUps + 1
  local extraPicks = 0
  local interval = math.floor(M.stat("ascendanceInterval"))
  if interval > 0 and levelUps % interval == 0 then
    extraPicks = 1
  end
  local extraCards = 0
  if levelUps == 1 then
    extraCards = math.floor(M.stat("firstDraftExtraCards"))
  end
  return extraPicks, extraCards
end

--- A level-up pick was applied: Swift Casting level 15 resets cooldowns
function M.onUpgradePicked()
  if M.stat("resetCooldownsOnLevelUp") > 0 then
    M.resetCooldowns()
  end
end

-- Active cards ------------------------------------------------------------

--- Active cards for the HUD: { index, cardId, action, charges, chargesLeft }
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
  healWall(wall.maxHealth * (params.healPercent or 0))
  shieldTime = math.max(shieldTime, params.shieldDuration or 0)
  return true
end

function ACTIONS.strikeNearest(params)
  local enemies = activeEnemies()
  if #enemies == 0 then return false end
  -- Nearest to the wall first (the wall is at the bottom of the screen)
  table.sort(enemies, function(a, b) return a.y > b.y end)
  for i = 1, math.min(math.floor(params.targets or 0), #enemies) do
    local target = enemies[i]
    damage(target, params.damage or 0)
    if (params.stunDuration or 0) > 0 and target.isActive and target.applySlow then
      target:applySlow(0, params.stunDuration)
    end
  end
  return true
end

function ACTIONS.slowAll(params)
  local enemies = activeEnemies()
  if #enemies == 0 then return false end
  local freeze = params.freezeDuration or 0
  for _, enemy in ipairs(enemies) do
    if enemy.applySlow then
      if freeze > 0 then
        enemy:applySlow(0, freeze)
      else
        enemy:applySlow(params.slowFactor or 1, params.duration or 0)
      end
    end
  end
  if freeze > 0 then
    table.insert(pendingSlows, {
      enemies = enemies, delay = freeze,
      factor = params.slowFactor or 1, duration = params.duration or 0,
    })
  end
  return true
end

function ACTIONS.freezeAll(params)
  if not ACTIONS.slowAll({ slowFactor = 0, duration = params.duration }) then
    return false
  end
  timeStopTime = params.duration or 0
  timeStopParams = params
  return true
end

function ACTIONS.purge(params)
  local enemies = activeEnemies()
  if #enemies == 0 then return false end
  local destroyed = 0
  for _, enemy in ipairs(enemies) do
    if enemy.isBoss then
      damage(enemy, (enemy.maxHealth or 0) * (params.bossDamagePercent or 0))
    elseif damage(enemy, enemy.health or 0) then
      destroyed = destroyed + 1
    end
  end
  local wall = context.wall
  if wall and (params.healPerKill or 0) > 0 then
    healWall(wall.maxHealth * params.healPerKill * destroyed)
  end
  return true
end

function ACTIONS.wallInvulnerable(params)
  bastionTime = math.max(bastionTime, params.duration or 0)
  bastionParams = params
  return true
end

function ACTIONS.meteorStorm(params)
  local enemies = activeEnemies()
  if #enemies == 0 then return false end
  for _ = 1, math.floor(params.count or 0) do
    local targets = activeEnemies()
    if #targets == 0 then break end
    local target = targets[math.min(#targets, math.floor(random() * #targets) + 1)]
    local killed = damage(target, params.damage or 0)
    if (params.burnDps or 0) > 0 and not killed and target.isActive and target.applyBurn then
      target:applyBurn(params.burnDps, M.METEOR_BURN_DURATION)
    end
  end
  return true
end

function ACTIONS.singularity(params)
  local pulled, bosses = {}, {}
  for _, enemy in ipairs(activeEnemies()) do
    table.insert(enemy.isBoss and bosses or pulled, enemy)
  end
  if #pulled == 0 and #bosses == 0 then return false end
  local pullDamage = params.damage or 0

  if #pulled > 0 then
    local centerX, centerY = 0, 0
    for _, enemy in ipairs(pulled) do
      centerX, centerY = centerX + enemy.x, centerY + enemy.y
    end
    centerX, centerY = centerX / #pulled, centerY / #pulled
    for _, enemy in ipairs(pulled) do
      enemy.x = centerX + (random() - 0.5) * M.SINGULARITY_SPREAD
      enemy.y = centerY + (random() - 0.5) * M.SINGULARITY_SPREAD
      damage(enemy, pullDamage)
    end
    -- Level 15: a rift stays behind and keeps damaging
    if (params.riftDuration or 0) > 0 then
      table.insert(rifts, {
        x = centerX, y = centerY, remaining = params.riftDuration, tickTimer = 0,
        damagePerSecond = pullDamage * M.RIFT_DAMAGE_SHARE,
      })
    end
  end

  -- Level 5: bosses take part of the damage without being pulled
  for _, boss in ipairs(bosses) do
    damage(boss, pullDamage * (params.bossDamageFraction or 0))
  end
  return #pulled > 0 or (params.bossDamageFraction or 0) > 0
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
-- @return number Extra cards for the new draft (Second Opinion level 15)
function M.useReroll()
  for _, active in ipairs(actives) do
    if active.action == "rerollDraft" and active.chargesLeft > 0 then
      active.chargesLeft = active.chargesLeft - 1
      return true, math.floor(active.params.extraCards or 0)
    end
  end
  return false, 0
end

return M
