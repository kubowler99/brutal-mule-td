-- Hero Entity
-- The stationary player character positioned at the defensive wall

local placeholder_graphics = require("src.utils.placeholder_graphics")
local synergy = require("src.models.synergy")

local Hero = Class("Hero")

function Hero:initialize(x, y)
  -- Fixed position (default to bottom center if not provided)
  self.x = x or 360
  self.y = y or 1200
  
  -- Level and XP properties
  self.level = 1
  self.xp = 0
  self.xpRequired = 100
  
  -- Abilities array (max 5 slots)
  self.abilities = {}
  
  -- Stats before passives (set from permanent upgrades and the hero choice).
  -- lowWallDamageBonus is extra damage while the wall is below half health.
  self.baseStats = { damageMultiplier = 1, cooldownMultiplier = 1, lowWallDamageBonus = 0 }
  
  -- Wall health / max health, kept current by the game controller
  self.wallHealthRatio = 1
  
  -- Alive state
  self.isAlive = true
  
  -- Visual representation using placeholder graphics
  self.displayObject = placeholder_graphics.createHeroSprite(self.x, self.y)
end

function Hero:addAbility(ability)
  -- Check if we have room for more abilities (5, or more with Sixth Seal)
  if #self.abilities >= self:getMaxAbilities() then
    return false
  end
  
  table.insert(self.abilities, ability)
  return true
end

-- Ability slots before cards add more
local BASE_ABILITY_SLOTS = 5

--- How many abilities the hero can hold
function Hero:getMaxAbilities()
  return BASE_ABILITY_SLOTS + (self.extraAbilitySlots or 0)
end

-- Lowest cooldown multiplier passives can reach
local MIN_COOLDOWN_MULTIPLIER = 0.4

-- Below this wall health ratio, lowWallDamageBonus applies
local LOW_WALL_RATIO = 0.5

--- Combined stats from base stats, passive abilities, and synergies
-- Abilities read these when they activate.
-- @return table { damageMultiplier, cooldownMultiplier }
function Hero:getStats()
  local stats = {
    damageMultiplier = self.baseStats.damageMultiplier,
    cooldownMultiplier = self.baseStats.cooldownMultiplier,
    extraProjectiles = self.baseStats.extraProjectiles or 0,
    extraProjectilePenaltyReduction = self.baseStats.extraProjectilePenaltyReduction or 0,
    extraProjectilePierce = self.baseStats.extraProjectilePierce or 0,
    -- Raised by passives such as Keen Eye and Mending Wards
    critChance = 0,
    critDamageBonus = 0,
    wallRegen = 0,
    wallShieldPercent = 0,
  }
  for _, ability in ipairs(self.abilities) do
    if ability.applyStats then
      ability:applyStats(stats)
    end
  end
  -- Each tag shared by two or more abilities adds a damage bonus
  stats.damageMultiplier = stats.damageMultiplier + synergy.getDamageBonus(self.abilities)
  -- Some heroes hit harder while the wall is below half health
  if self.wallHealthRatio < LOW_WALL_RATIO then
    stats.damageMultiplier = stats.damageMultiplier + (self.baseStats.lowWallDamageBonus or 0)
  end
  stats.cooldownMultiplier = math.max(stats.cooldownMultiplier, MIN_COOLDOWN_MULTIPLIER)
  return stats
end

-- Size of the hero sprite image
local SPRITE_SIZE = 64

--- Show the hero's sprite image, or tint the placeholder if it has none
-- Call before the display object is inserted into the scene group.
-- @param definition table Hero definition from meta.json { sprite, color }
function Hero:setAppearance(definition)
  if type(definition) ~= "table" then
    return
  end

  if type(definition.sprite) == "string" and definition.sprite ~= "" then
    local image = display.newImageRect(definition.sprite, SPRITE_SIZE, SPRITE_SIZE)
    if image then
      image.x = self.x
      image.y = self.y
      if self.displayObject then
        self.displayObject:removeSelf()
      end
      self.displayObject = image
      return
    end
  end

  if type(definition.color) == "table" then
    self:setColor(definition.color)
  end
end

--- Tint the hero's body
-- @param color table { r, g, b }
function Hero:setColor(color)
  local body = self.displayObject and self.displayObject[1]
  if body and body.setFillColor then
    body:setFillColor(color[1], color[2], color[3])
  end
end

function Hero:addXP(amount)
  self.xp = self.xp + amount
  -- Note: Level-up logic is handled externally by experience_system
end

function Hero:destroy()
  -- Abilities may own display objects (e.g. patrol blades)
  for _, ability in ipairs(self.abilities) do
    if ability.destroy then
      ability:destroy()
    end
  end
  
  if self.displayObject then
    self.displayObject:removeSelf()
    self.displayObject = nil
  end
end

return Hero
