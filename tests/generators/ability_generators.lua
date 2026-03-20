-- ability_generators.lua
-- Test generators for ability selection property-based testing
-- These generators create random test data for ability-related property tests

local Hero = require("src.entities.hero")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")

local generators = {}

-- Mock ability class for testing
-- Used when we need a simple ability without full implementation
local MockAbility = Class("MockAbility")

function MockAbility:initialize()
  self.id = "mock_ability"
  self.name = "Mock Ability"
  self.tier = 1
  self.cooldown = 1.0
  self.lastActivation = 0
  self.damage = 10
end

function MockAbility:canActivate(currentTime)
  return (currentTime - self.lastActivation) >= self.cooldown
end

function MockAbility:activate(heroX, heroY, enemies, projectilePool)
  self.lastActivation = system.getTimer() / 1000
  return true
end

function MockAbility:upgrade(upgradeType)
  if self.tier < 5 then
    self.tier = self.tier + 1
    return true
  end
  return false
end

generators.MockAbility = MockAbility

-- Generate random ability definition with valid structure
-- Returns: { class = Class, unlocked = boolean, maxTier = number }
function generators.randomAbilityDefinition()
  return function()
    return {
      class = MockAbility,
      unlocked = math.random() > 0.5,
      maxTier = math.random(3, 5)
    }
  end
end

-- Generate hero with specified number of abilities (0-5)
-- Parameters:
--   abilityCount: number of abilities to add (0-5)
-- Returns: Hero instance with specified number of abilities
function generators.randomHeroState(abilityCount)
  return function()
    local hero = Hero:new(360, 1200)
    
    -- Add specified number of abilities
    for i = 1, math.min(abilityCount or 0, 5) do
      local ability = MockAbility:new()
      ability.id = "ability_" .. i
      ability.name = "Test Ability " .. i
      hero:addAbility(ability)
    end
    
    return hero
  end
end

-- Generate random upgrade card of specified type
-- Parameters:
--   cardType: "new_ability", "tier_upgrade", or "stat_upgrade"
-- Returns: upgrade card structure with all required fields
function generators.randomUpgradeCard(cardType)
  return function()
    if cardType == "new_ability" then
      local abilityId = "test_ability_" .. math.random(100)
      return {
        id = "new_ability_" .. math.random(1000),
        type = "new_ability",
        abilityId = abilityId,
        name = "Test Ability",
        description = "Test description for ability",
        iconType = "test_icon",
        apply = function(hero)
          -- Simple mock apply function
          if #hero.abilities >= 5 then
            return false
          end
          local ability = MockAbility:new()
          ability.id = abilityId
          return hero:addAbility(ability)
        end
      }
    elseif cardType == "tier_upgrade" then
      return {
        id = "tier_upgrade_" .. math.random(1000),
        type = "tier_upgrade",
        abilityId = "arcane_bolt",
        name = "Upgrade Arcane Bolt",
        description = "Increase tier",
        iconType = "upgrade_icon",
        apply = function(hero)
          if #hero.abilities > 0 then
            return hero.abilities[1]:upgrade("tier")
          end
          return false
        end
      }
    elseif cardType == "stat_upgrade" then
      return {
        id = "stat_upgrade_" .. math.random(1000),
        type = "stat_upgrade",
        stat = "xpRadius",
        name = "XP Pickup Radius",
        description = "Increase XP pickup radius",
        iconType = "stat_icon",
        apply = function(hero)
          hero.xpPickupRadius = (hero.xpPickupRadius or 100) + 10
          return true
        end
      }
    end
    
    -- Default: return new_ability card
    return generators.randomUpgradeCard("new_ability")()
  end
end

-- Generate random ability count (0-5)
-- Used for testing slot availability logic
-- Returns: number between 0 and 5
function generators.randomAbilityCount()
  return function()
    return math.random(0, 5)
  end
end

-- Generate random ability ID
-- Used for testing ability registry lookups
-- Returns: string ability ID
function generators.randomAbilityId()
  return function()
    local ids = {
      "arcane_bolt",
      "fireball",
      "ice_shard",
      "lightning_bolt",
      "poison_cloud",
      "unknown_ability_" .. math.random(100)
    }
    return ids[math.random(#ids)]
  end
end

-- Generate random unlock status
-- Returns: boolean
function generators.randomUnlockStatus()
  return function()
    return math.random() > 0.5
  end
end

-- Generate random tier value (1-5)
-- Used for testing tier-based mechanics
-- Returns: number between 1 and 5
function generators.randomTier()
  return function()
    return math.random(1, 5)
  end
end

-- Generate hero with random ability count (0-5)
-- Returns: Hero instance with random number of abilities
function generators.randomHero()
  return function()
    local abilityCount = math.random(0, 5)
    return generators.randomHeroState(abilityCount)()
  end
end

-- Generate hero with available slots (0-4 abilities)
-- Used for testing new ability addition
-- Returns: Hero instance with < 5 abilities
function generators.heroWithAvailableSlots()
  return function()
    local abilityCount = math.random(0, 4)
    return generators.randomHeroState(abilityCount)()
  end
end

-- Generate hero with full slots (5 abilities)
-- Used for testing slot limit enforcement
-- Returns: Hero instance with 5 abilities
function generators.heroWithFullSlots()
  return function()
    return generators.randomHeroState(5)()
  end
end

return generators
