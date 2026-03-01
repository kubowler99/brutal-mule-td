-- Upgrade System
-- Manages upgrade card generation, ability unlocking, tier upgrades, and slot management

local upgrade_system = {}

-- State
upgrade_system.hero = nil
upgrade_system.upgradePool = {}
upgrade_system.onUpgradeSelected = nil

-- Initialize the upgrade system
function upgrade_system.initialize(hero, onUpgradeSelectedCallback)
  upgrade_system.hero = hero
  upgrade_system.onUpgradeSelected = onUpgradeSelectedCallback
  
  -- Define the MVP upgrade pool
  upgrade_system.upgradePool = {
    -- Arcane Bolt Damage upgrade
    {
      id = "arcane_bolt_damage",
      type = "tier_upgrade",
      abilityId = "arcane_bolt",
      name = "Arcane Bolt Damage",
      description = "+5 damage per bolt",
      iconType = "damage",
      apply = function(hero)
        for _, ability in ipairs(hero.abilities) do
          if ability.id == "arcane_bolt" then
            ability:upgrade("damage_increase")
            return true
          end
        end
        return false
      end
    },
    
    -- Arcane Bolt Attack Speed upgrade
    {
      id = "arcane_bolt_attack_speed",
      type = "tier_upgrade",
      abilityId = "arcane_bolt",
      name = "Arcane Bolt Attack Speed",
      description = "-0.15s cooldown",
      iconType = "speed",
      apply = function(hero)
        for _, ability in ipairs(hero.abilities) do
          if ability.id == "arcane_bolt" then
            ability:upgrade("attack_speed")
            return true
          end
        end
        return false
      end
    },
    
    -- Arcane Bolt Projectile Count upgrade
    {
      id = "arcane_bolt_projectile_count",
      type = "tier_upgrade",
      abilityId = "arcane_bolt",
      name = "Arcane Bolt Projectile Count",
      description = "+1 projectile",
      iconType = "count",
      apply = function(hero)
        for _, ability in ipairs(hero.abilities) do
          if ability.id == "arcane_bolt" then
            ability:upgrade("projectile_count")
            return true
          end
        end
        return false
      end
    },
    
    -- Arcane Bolt Pierce upgrade
    {
      id = "arcane_bolt_pierce",
      type = "tier_upgrade",
      abilityId = "arcane_bolt",
      name = "Arcane Bolt Pierce",
      description = "+1 pierce count",
      iconType = "pierce",
      apply = function(hero)
        for _, ability in ipairs(hero.abilities) do
          if ability.id == "arcane_bolt" then
            ability:upgrade("pierce")
            return true
          end
        end
        return false
      end
    },
    
    -- XP Pickup Radius upgrade
    {
      id = "xp_pickup_radius",
      type = "stat_upgrade",
      abilityId = nil,
      name = "XP Pickup Radius",
      description = "+20 pixels pickup range",
      iconType = "radius",
      apply = function(hero)
        hero.pickupRadius = hero.pickupRadius + 20
        return true
      end
    }
  }
end

-- Generate random upgrade cards
-- Returns an array of upgrade card objects
function upgrade_system.generateCards(count)
  if not upgrade_system.hero then
    print("Warning: upgrade_system.generateCards called with no hero")
    return {}
  end
  
  -- Validate count parameter
  count = count or 3
  if type(count) ~= "number" or count < 0 then
    print("Warning: Invalid count parameter in generateCards: " .. tostring(count))
    count = 3
  end
  
  local availableUpgrades = upgrade_system.getAvailableUpgrades()
  
  -- If no upgrades available, provide fallback
  if #availableUpgrades == 0 then
    print("Warning: No upgrades available in pool, returning empty array")
    return {}
  end
  
  local cards = {}
  local usedIndices = {}
  
  -- Generate unique random cards
  for i = 1, count do
    if #availableUpgrades == 0 then
      break
    end
    
    -- Select random upgrade from available pool
    local randomIndex = math.random(1, #availableUpgrades)
    local upgrade = availableUpgrades[randomIndex]
    
    table.insert(cards, upgrade)
    
    -- Remove selected upgrade from available pool to avoid duplicates
    table.remove(availableUpgrades, randomIndex)
  end
  
  -- Fallback: If we couldn't generate enough cards, log warning
  if #cards < count and #cards < #upgrade_system.upgradePool then
    print(string.format("Warning: Only generated %d cards out of requested %d", #cards, count))
  end
  
  return cards
end

-- Get available upgrades based on hero state
-- Filters upgrades based on ability slots and tier limits
function upgrade_system.getAvailableUpgrades()
  if not upgrade_system.hero then
    print("Warning: upgrade_system.getAvailableUpgrades called with no hero")
    return {}
  end
  
  -- Validate hero abilities array
  if not upgrade_system.hero.abilities or type(upgrade_system.hero.abilities) ~= "table" then
    print("Warning: Hero has invalid abilities array")
    return {}
  end
  
  local available = {}
  local hasAbilities = #upgrade_system.hero.abilities > 0
  local hasAvailableSlots = #upgrade_system.hero.abilities < 5
  
  -- Check each upgrade in the pool
  for _, upgrade in ipairs(upgrade_system.upgradePool) do
    local canOffer = false
    
    if upgrade.type == "tier_upgrade" then
      -- Check if hero has this ability and it's not at max tier
      for _, ability in ipairs(upgrade_system.hero.abilities) do
        if ability and ability.id == upgrade.abilityId then
          -- Validate tier value
          local tier = ability.tier or 1
          if type(tier) ~= "number" then
            print("Warning: Invalid tier value for ability " .. tostring(ability.id))
            tier = 1
          end
          
          -- Only offer upgrade if tier < 5
          if tier < 5 then
            canOffer = true
            break
          end
        end
      end
    elseif upgrade.type == "stat_upgrade" then
      -- Stat upgrades are always available
      canOffer = true
    elseif upgrade.type == "new_ability" then
      -- New abilities only available if slots available (< 5)
      canOffer = hasAvailableSlots
    end
    
    if canOffer then
      table.insert(available, upgrade)
    end
  end
  
  return available
end

-- Check if new ability can be offered
function upgrade_system.canOfferNewAbility()
  if not upgrade_system.hero then
    print("Warning: upgrade_system.canOfferNewAbility called with no hero")
    return false
  end
  
  -- Validate abilities array
  if not upgrade_system.hero.abilities or type(upgrade_system.hero.abilities) ~= "table" then
    print("Warning: Hero has invalid abilities array in canOfferNewAbility")
    return false
  end
  
  -- Check if hero has fewer than 5 abilities
  local abilityCount = #upgrade_system.hero.abilities
  if type(abilityCount) ~= "number" or abilityCount < 0 then
    print("Warning: Invalid ability count: " .. tostring(abilityCount))
    return false
  end
  
  return abilityCount < 5
end

-- Apply selected upgrade to hero
function upgrade_system.applyUpgrade(upgradeCard)
  if not upgrade_system.hero then
    print("Error: upgrade_system.applyUpgrade called with no hero")
    return false
  end
  
  if not upgradeCard then
    print("Error: upgrade_system.applyUpgrade called with nil upgradeCard")
    return false
  end
  
  -- Validate upgrade card structure
  if type(upgradeCard) ~= "table" then
    print("Error: upgradeCard is not a table")
    return false
  end
  
  if not upgradeCard.apply or type(upgradeCard.apply) ~= "function" then
    print("Error: upgradeCard has no valid apply function")
    return false
  end
  
  -- Additional validation for tier upgrades
  if upgradeCard.type == "tier_upgrade" then
    -- Check if the ability exists and is below max tier
    local abilityFound = false
    local abilityAtMaxTier = false
    
    for _, ability in ipairs(upgrade_system.hero.abilities) do
      if ability and ability.id == upgradeCard.abilityId then
        abilityFound = true
        local tier = ability.tier or 1
        
        if type(tier) ~= "number" then
          print("Warning: Invalid tier type for ability " .. tostring(ability.id))
          tier = 1
        end
        
        if tier >= 5 then
          abilityAtMaxTier = true
          print("Warning: Attempting to upgrade ability at max tier (tier " .. tostring(tier) .. ")")
        end
        break
      end
    end
    
    if not abilityFound then
      print("Warning: Attempting to upgrade ability that hero doesn't have: " .. tostring(upgradeCard.abilityId))
      return false
    end
    
    if abilityAtMaxTier then
      print("Warning: Cannot upgrade ability beyond tier 5")
      return false
    end
  end
  
  -- Additional validation for new ability upgrades
  if upgradeCard.type == "new_ability" then
    -- Check if hero has available slots
    if not upgrade_system.hero.abilities or type(upgrade_system.hero.abilities) ~= "table" then
      print("Error: Hero has invalid abilities array")
      return false
    end
    
    if #upgrade_system.hero.abilities >= 5 then
      print("Warning: Cannot add new ability - all 5 slots are full")
      return false
    end
  end
  
  -- Apply the upgrade using its apply function with error handling
  local success, result = pcall(upgradeCard.apply, upgrade_system.hero)
  
  if not success then
    print("Error: Failed to apply upgrade: " .. tostring(result))
    return false
  end
  
  if not result then
    print("Warning: Upgrade apply function returned false")
    return false
  end
  
  -- Call the upgrade selected callback to resume game
  if upgrade_system.onUpgradeSelected then
    local callbackSuccess, callbackError = pcall(upgrade_system.onUpgradeSelected)
    if not callbackSuccess then
      print("Error: Upgrade callback failed: " .. tostring(callbackError))
    end
  end
  
  return true
end

-- Cleanup the upgrade system
function upgrade_system.cleanup()
  upgrade_system.hero = nil
  upgrade_system.upgradePool = {}
  upgrade_system.onUpgradeSelected = nil
end

return upgrade_system
