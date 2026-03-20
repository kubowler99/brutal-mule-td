--- Property-based tests for Upgrade System Data Loading
-- Feature: game-visual-and-data-improvements
-- Tests Property 13: Upgrade pool definitions loaded from JSON

require("tests.spec_helper")

local ability_data_loader = require("src.models.ability_data_loader")
local upgrade_system = require("src.systems.upgrade_system")
local Hero = require("src.entities.hero")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")

-- Generator: random valid upgrade definition with name, description, iconType
local function randomUpgradeDefinition(upgradeType)
  local names = {
    "Power Strike", "Quick Cast", "Multi Shot", "Pierce Through",
    "Flame Burst", "Ice Shard", "Thunder Bolt", "Shadow Step"
  }
  local descriptions = {
    "+5 damage per bolt", "-0.15s cooldown", "+1 projectile",
    "+1 pierce count", "+10% crit chance", "+20 range"
  }
  local iconTypes = { "damage", "speed", "count", "pierce", "fire", "ice", "lightning" }

  return {
    name = names[math.random(1, #names)] .. " " .. math.random(1, 100),
    description = descriptions[math.random(1, #descriptions)],
    iconType = iconTypes[math.random(1, #iconTypes)],
    damageIncrease = math.random(1, 20)
  }
end

-- Generator: random valid ability data with upgrades section
local function randomAbilityData(abilityId)
  local upgradeTypes = { "damage_increase", "attack_speed", "projectile_count", "pierce" }
  local upgrades = {}

  -- Include a random subset of upgrade types (at least 1)
  local count = math.random(1, #upgradeTypes)
  for i = 1, count do
    upgrades[upgradeTypes[i]] = randomUpgradeDefinition(upgradeTypes[i])
  end

  return {
    name = "Test Ability " .. (abilityId or "unknown"),
    module = "src.entities.abilities.arcane_bolt",
    unlocked = true,
    maxTier = 5,
    baseStats = {
      cooldown = 1.0,
      damage = 10,
      projectileSpeed = 400,
      pierceCount = 0,
      projectileCount = 1
    },
    upgrades = upgrades
  }
end

describe("Upgrade System Data Properties", function()

  before_each(function()
    ability_data_loader._data = nil
    upgrade_system.cleanup()
  end)

  after_each(function()
    ability_data_loader._data = nil
    upgrade_system.cleanup()
  end)

  -- Feature: game-visual-and-data-improvements, Property 13: Upgrade pool definitions loaded from JSON
  -- **Validates: Requirements 6.7**
  describe("Property 13: Upgrade pool definitions loaded from JSON", function()

    it("for any valid upgrade definitions in abilities.json, generated cards shall have names matching JSON data", function()
      for _ = 1, 100 do
        -- Generate random ability data with upgrades
        local abilityId = "test_ability_" .. math.random(1, 1000)
        local abilityData = randomAbilityData(abilityId)

        -- Inject into ability_data_loader
        ability_data_loader._data = { [abilityId] = abilityData }

        -- Create hero with matching ability
        local hero = Hero:new(360, 1180)
        local ability = ArcaneBolt:new()
        ability.id = abilityId
        hero:addAbility(ability)

        -- Initialize upgrade system (should read from ability_data_loader)
        upgrade_system.initialize(hero, function() end)

        -- Verify each upgrade in the pool matches JSON data
        for upgradeType, upgradeDef in pairs(abilityData.upgrades) do
          local expectedId = abilityId .. "_" .. upgradeType
          local found = false

          for _, poolEntry in ipairs(upgrade_system.upgradePool) do
            if poolEntry.id == expectedId then
              found = true
              assert.are.equal(upgradeDef.name, poolEntry.name,
                "Upgrade name should match JSON for " .. expectedId)
              assert.are.equal(upgradeDef.description, poolEntry.description,
                "Upgrade description should match JSON for " .. expectedId)
              assert.are.equal(upgradeDef.iconType, poolEntry.iconType,
                "Upgrade iconType should match JSON for " .. expectedId)
              break
            end
          end

          assert.is_true(found,
            "Upgrade pool should contain entry for " .. expectedId)
        end

        upgrade_system.cleanup()
      end
    end)

    it("for any valid upgrade definitions, generated cards shall have descriptions matching JSON data", function()
      for _ = 1, 100 do
        local abilityId = "ability_" .. math.random(1, 500)
        local abilityData = randomAbilityData(abilityId)

        ability_data_loader._data = { [abilityId] = abilityData }

        local hero = Hero:new(360, 1180)
        local ability = ArcaneBolt:new()
        ability.id = abilityId
        hero:addAbility(ability)

        upgrade_system.initialize(hero, function() end)

        -- Count how many tier_upgrade entries match our ability
        local tierUpgradeCount = 0
        for _, poolEntry in ipairs(upgrade_system.upgradePool) do
          if poolEntry.type == "tier_upgrade" and poolEntry.abilityId == abilityId then
            tierUpgradeCount = tierUpgradeCount + 1

            -- Find matching upgrade definition
            local upgradeType = string.sub(poolEntry.id, #abilityId + 2) -- strip "abilityId_"
            local upgradeDef = abilityData.upgrades[upgradeType]

            assert.is_not_nil(upgradeDef,
              "Pool entry " .. poolEntry.id .. " should correspond to a JSON upgrade type")
            assert.are.equal(upgradeDef.description, poolEntry.description,
              "Description should match JSON for " .. poolEntry.id)
          end
        end

        -- Should have as many tier_upgrade entries as upgrade definitions
        local expectedCount = 0
        for _ in pairs(abilityData.upgrades) do
          expectedCount = expectedCount + 1
        end
        assert.are.equal(expectedCount, tierUpgradeCount,
          "Number of tier_upgrade entries should match number of upgrade definitions")

        upgrade_system.cleanup()
      end
    end)

    it("for any valid upgrade definitions, generated cards shall have icon types matching JSON data", function()
      for _ = 1, 100 do
        local abilityId = "icon_test_" .. math.random(1, 500)
        local abilityData = randomAbilityData(abilityId)

        ability_data_loader._data = { [abilityId] = abilityData }

        local hero = Hero:new(360, 1180)
        local ability = ArcaneBolt:new()
        ability.id = abilityId
        hero:addAbility(ability)

        upgrade_system.initialize(hero, function() end)

        for upgradeType, upgradeDef in pairs(abilityData.upgrades) do
          local expectedId = abilityId .. "_" .. upgradeType

          for _, poolEntry in ipairs(upgrade_system.upgradePool) do
            if poolEntry.id == expectedId then
              assert.are.equal(upgradeDef.iconType, poolEntry.iconType,
                "iconType should match JSON for " .. expectedId)
            end
          end
        end

        upgrade_system.cleanup()
      end
    end)

    it("should fall back to hard-coded pool when ability_data_loader has no data", function()
      for _ = 1, 100 do
        -- Ensure ability_data_loader has no data
        ability_data_loader._data = nil

        local hero = Hero:new(360, 1180)
        local arcaneBolt = ArcaneBolt:new()
        hero:addAbility(arcaneBolt)

        upgrade_system.initialize(hero, function() end)

        -- Should have the hard-coded pool entries
        local hasDamage = false
        local hasSpeed = false
        local hasCount = false
        local hasPierce = false
        local hasXpRadius = false

        for _, poolEntry in ipairs(upgrade_system.upgradePool) do
          if poolEntry.id == "arcane_bolt_damage" then hasDamage = true end
          if poolEntry.id == "arcane_bolt_attack_speed" then hasSpeed = true end
          if poolEntry.id == "arcane_bolt_projectile_count" then hasCount = true end
          if poolEntry.id == "arcane_bolt_pierce" then hasPierce = true end
          if poolEntry.id == "xp_pickup_radius" then hasXpRadius = true end
        end

        assert.is_true(hasDamage, "Fallback pool should have arcane_bolt_damage")
        assert.is_true(hasSpeed, "Fallback pool should have arcane_bolt_attack_speed")
        assert.is_true(hasCount, "Fallback pool should have arcane_bolt_projectile_count")
        assert.is_true(hasPierce, "Fallback pool should have arcane_bolt_pierce")
        assert.is_true(hasXpRadius, "Fallback pool should have xp_pickup_radius")

        upgrade_system.cleanup()
      end
    end)

    it("should fall back to hard-coded pool when ability_data_loader has empty data", function()
      for _ = 1, 100 do
        ability_data_loader._data = {}

        local hero = Hero:new(360, 1180)
        local arcaneBolt = ArcaneBolt:new()
        hero:addAbility(arcaneBolt)

        upgrade_system.initialize(hero, function() end)

        -- Should have the hard-coded fallback entries
        local hasFallbackEntries = false
        for _, poolEntry in ipairs(upgrade_system.upgradePool) do
          if poolEntry.id == "arcane_bolt_damage" then
            hasFallbackEntries = true
            break
          end
        end

        assert.is_true(hasFallbackEntries,
          "Empty data should trigger fallback to hard-coded pool")

        upgrade_system.cleanup()
      end
    end)

    it("should always include stat upgrades (xp_pickup_radius) regardless of data source", function()
      for _ = 1, 100 do
        -- Randomly choose between data-driven and fallback
        if math.random() > 0.5 then
          local abilityId = "stat_test_" .. math.random(1, 500)
          ability_data_loader._data = { [abilityId] = randomAbilityData(abilityId) }
        else
          ability_data_loader._data = nil
        end

        local hero = Hero:new(360, 1180)
        local arcaneBolt = ArcaneBolt:new()
        hero:addAbility(arcaneBolt)

        upgrade_system.initialize(hero, function() end)

        local hasXpRadius = false
        for _, poolEntry in ipairs(upgrade_system.upgradePool) do
          if poolEntry.id == "xp_pickup_radius" then
            hasXpRadius = true
            break
          end
        end

        assert.is_true(hasXpRadius,
          "xp_pickup_radius stat upgrade should always be present")

        upgrade_system.cleanup()
      end
    end)
  end)
end)
