-- Upgrade System
-- Manages upgrade card generation, ability unlocking, tier upgrades, and slot management

local ability_data_loader = nil

-- Safely load ability_data_loader (may not be available in all test environments)
local _adl_load_success, _adl_module = pcall(require, "src.models.ability_data_loader")
if _adl_load_success then
  ability_data_loader = _adl_module
end

local upgrade_system = {}

-- State
upgrade_system.hero = nil
upgrade_system.upgradePool = {}
upgrade_system.onUpgradeSelected = nil

-- Build upgrade pool entries from ability_data_loader JSON data
-- Returns a table of upgrade pool entries, or nil if data is not available
local function _buildUpgradePoolFromData()
  if not ability_data_loader then
    return nil
  end

  if not ability_data_loader._data or type(ability_data_loader._data) ~= "table" then
    return nil
  end

  -- Check if there's any data at all
  local hasData = false
  for _ in pairs(ability_data_loader._data) do
    hasData = true
    break
  end
  if not hasData then
    return nil
  end

  local pool = {}

  -- Iterate over all abilities in the data loader
  for abilityId, abilityData in pairs(ability_data_loader._data) do
    if type(abilityData) == "table" and type(abilityData.upgrades) == "table" then
      -- Create an upgrade pool entry for each upgrade type
      for upgradeType, upgradeData in pairs(abilityData.upgrades) do
        if type(upgradeData) == "table" then
          local name = type(upgradeData.name) == "string" and upgradeData.name or (abilityId .. " " .. upgradeType)
          local description = type(upgradeData.description) == "string" and upgradeData.description or ""
          local iconType = type(upgradeData.iconType) == "string" and upgradeData.iconType or upgradeType

          -- Capture abilityId and upgradeType in closure
          local capturedAbilityId = abilityId
          local capturedUpgradeType = upgradeType

          table.insert(pool, {
            id = capturedAbilityId .. "_" .. capturedUpgradeType,
            type = "tier_upgrade",
            abilityId = capturedAbilityId,
            name = name,
            description = description,
            iconType = iconType,
            apply = function(hero)
              for _, ability in ipairs(hero.abilities) do
                if ability.id == capturedAbilityId then
                  ability:upgrade(capturedUpgradeType)
                  return true
                end
              end
              return false
            end
          })
        end
      end
    end
  end

  return pool
end

-- Hard-coded fallback upgrade pool (used when ability_data_loader is not initialized)
local function _buildHardCodedPool()
  return {
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
    }
  }
end

-- Initialize the upgrade system
function upgrade_system.initialize(hero, onUpgradeSelectedCallback)
  upgrade_system.hero = hero
  upgrade_system.onUpgradeSelected = onUpgradeSelectedCallback

  -- Try to build upgrade pool from abilities.json data
  local dataPool = _buildUpgradePoolFromData()

  if dataPool and #dataPool > 0 then
    upgrade_system.upgradePool = dataPool
  else
    -- Fall back to hard-coded pool if ability_data_loader is not initialized
    upgrade_system.upgradePool = _buildHardCodedPool()
  end

  -- Always add stat upgrades (not ability-specific, not in abilities.json)
  table.insert(upgrade_system.upgradePool, {
    id = "wall_repair",
    type = "stat_upgrade",
    abilityId = nil,
    name = "Wall Repair",
    description = "Restore 25% wall health",
    iconType = "damage",
    apply = function(hero)
      local gc = require("src.controllers.game_controller")
      local wall = gc.getWall()
      if wall then
        local heal = math.floor(wall.maxHealth * 0.25)
        wall.health = math.min(wall.health + heal, wall.maxHealth)
      end
      return true
    end
  })

  table.insert(upgrade_system.upgradePool, {
    id = "wall_fortify",
    type = "stat_upgrade",
    abilityId = nil,
    name = "Fortify Wall",
    description = "+50 max wall health",
    iconType = "pierce",
    apply = function(hero)
      local gc = require("src.controllers.game_controller")
      local wall = gc.getWall()
      if wall then
        wall.maxHealth = wall.maxHealth + 50
        wall.health = wall.health + 50
      end
      return true
    end
  })

  table.insert(upgrade_system.upgradePool, {
    id = "xp_boost",
    type = "stat_upgrade",
    abilityId = nil,
    name = "XP Boost",
    description = "+25% XP from enemies",
    iconType = "speed",
    apply = function(hero)
      hero.xpMultiplier = (hero.xpMultiplier or 1.0) + 0.25
      return true
    end
  })
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
  
  -- Debug: log pool and available counts
  print(string.format("Upgrade system: pool=%d, available=%d, requested=%d", 
    #upgrade_system.upgradePool, #availableUpgrades, count))
  
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
  
  -- Add new ability options from ability registry if slots available
  if hasAvailableSlots then
    -- Load ability registry with error handling
    local registryLoadSuccess, ability_registry = pcall(require, "src.models.ability_registry")
    if not registryLoadSuccess then
      print("Error: Failed to load ability_registry in getAvailableUpgrades: " .. tostring(ability_registry))
      return available
    end
    
    -- Validate ability_registry has required structure
    if not ability_registry.abilities or type(ability_registry.abilities) ~= "table" then
      print("Error: ability_registry missing abilities table")
      return available
    end
    
    -- Build set of abilities hero already has
    local heroAbilityIds = {}
    for _, ability in ipairs(upgrade_system.hero.abilities) do
      if ability and ability.id then
        heroAbilityIds[ability.id] = true
      end
    end
    
    -- Query ability registry for unlocked abilities
    for abilityId, abilityDef in pairs(ability_registry.abilities) do
      -- Validate abilityId is a string
      local shouldProcess = true
      if type(abilityId) ~= "string" then
        print("Warning: Invalid abilityId type in registry: " .. tostring(abilityId))
        shouldProcess = false
      end
      
      -- Only offer abilities that are:
      -- 1. Unlocked in the registry
      -- 2. Not already equipped by the hero
      if shouldProcess and ability_registry.isUnlocked(abilityId) and not heroAbilityIds[abilityId] then
        -- Create instance to get ability metadata with error handling
        local instanceSuccess, abilityInstance = pcall(ability_registry.createInstance, abilityId)
        
        if not instanceSuccess then
          print("Error: Failed to create instance for ability " .. tostring(abilityId) .. ": " .. tostring(abilityInstance))
          shouldProcess = false
        end
        
        if shouldProcess and abilityInstance then
          -- Create upgrade card for this ability
          local newAbilityCard = {
            id = "new_ability_" .. abilityId,
            type = "new_ability",
            abilityId = abilityId,
            name = abilityInstance.name or "Unknown Ability",
            description = abilityInstance.description or "No description available",
            iconType = abilityInstance.iconType or abilityId,
            apply = function(hero)
              -- Validate hero reference
              if not hero then
                print("Error: apply function called with nil hero")
                return false
              end
              
              -- Validate hero abilities array
              if not hero.abilities or type(hero.abilities) ~= "table" then
                print("Error: Hero has invalid abilities array in apply function")
                return false
              end
              
              -- Validate ability is still unlocked
              if not ability_registry.isUnlocked(abilityId) then
                print("Warning: Attempting to add locked ability: " .. tostring(abilityId))
                return false
              end
              
              -- Validate slot availability
              if #hero.abilities >= 5 then
                print("Warning: Cannot add ability - all 5 slots full")
                return false
              end
              
              -- Create new instance and add to hero with error handling
              local ability = ability_registry.createInstance(abilityId)
              if not ability then
                print("Error: Failed to create ability instance: " .. tostring(abilityId))
                return false
              end
              
              -- Use pcall to safely add ability to hero
              local success, result = pcall(function()
                return hero:addAbility(ability)
              end)
              
              if not success then
                print("Error: Failed to add ability to hero: " .. tostring(result))
                return false
              end
              
              return result
            end
          }
          
          table.insert(available, newAbilityCard)
        end
      end
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
    
    -- Validate abilityId is present
    if not upgradeCard.abilityId or type(upgradeCard.abilityId) ~= "string" then
      print("Error: new_ability card missing or has invalid abilityId")
      return false
    end
    
    -- Load ability registry with error handling
    local success, ability_registry = pcall(require, "src.models.ability_registry")
    if not success then
      print("Error: Failed to load ability_registry: " .. tostring(ability_registry))
      return false
    end
    
    -- Validate ability registry has required methods
    if not ability_registry.isUnlocked or type(ability_registry.isUnlocked) ~= "function" then
      print("Error: ability_registry missing isUnlocked method")
      return false
    end
    
    if not ability_registry.createInstance or type(ability_registry.createInstance) ~= "function" then
      print("Error: ability_registry missing createInstance method")
      return false
    end
    
    -- Validate ability is unlocked
    if not ability_registry.isUnlocked(upgradeCard.abilityId) then
      print("Warning: Attempting to add locked ability: " .. tostring(upgradeCard.abilityId))
      return false
    end
    
    -- Create ability instance
    local ability = ability_registry.createInstance(upgradeCard.abilityId)
    if not ability then
      print("Warning: Failed to create instance of ability: " .. tostring(upgradeCard.abilityId))
      return false
    end
    
    -- Validate ability has required properties
    if not ability.id then
      print("Error: Created ability instance missing id property")
      return false
    end
    
    -- Add ability to hero with error handling
    local addSuccess, addResult = pcall(function()
      return upgrade_system.hero:addAbility(ability)
    end)
    
    if not addSuccess then
      print("Error: Exception while adding ability to hero: " .. tostring(addResult))
      return false
    end
    
    if not addResult then
      print("Warning: Failed to add ability to hero: " .. tostring(upgradeCard.abilityId))
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
