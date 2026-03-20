-- Tests for Ability Data Loader
-- Validates loading, validation, base stats, upgrades, tiers, and fallback behavior

require("tests.spec_helper")

local ability_data_loader = require("src.models.ability_data_loader")

describe("Ability Data Loader", function()

  before_each(function()
    -- Reset cached data before each test
    ability_data_loader._data = nil
  end)

  describe("initialize", function()
    it("loads ability data from valid JSON file", function()
      local success = ability_data_loader.initialize("data/abilities.json")

      assert.is_true(success)
      assert.is_not_nil(ability_data_loader._data)
      assert.is_not_nil(ability_data_loader._data.arcane_bolt)
    end)

    it("returns false and sets empty data when file not found", function()
      -- Make pathForFile return nil for missing files
      local origPathForFile = system.pathForFile
      system.pathForFile = function() return nil end

      local success = ability_data_loader.initialize("data/nonexistent.json")

      assert.is_false(success)
      assert.is_table(ability_data_loader._data)

      system.pathForFile = origPathForFile
    end)

    it("returns false when file cannot be opened", function()
      -- Make io.open return nil
      local origOpen = io.open
      io.open = function() return nil end

      local success = ability_data_loader.initialize("data/abilities.json")

      assert.is_false(success)
      assert.is_table(ability_data_loader._data)

      io.open = origOpen
    end)

    it("returns false when JSON is invalid", function()
      -- Create a temp file with invalid JSON
      local tmpPath = os.tmpname()
      local f = io.open(tmpPath, "w")
      f:write("not valid json {{{")
      f:close()

      local origPathForFile = system.pathForFile
      system.pathForFile = function() return tmpPath end

      local success = ability_data_loader.initialize(tmpPath)

      assert.is_false(success)
      assert.is_table(ability_data_loader._data)

      system.pathForFile = origPathForFile
      os.remove(tmpPath)
    end)

    it("defaults to data/abilities.json when no path provided", function()
      local success = ability_data_loader.initialize()

      assert.is_true(success)
      assert.is_not_nil(ability_data_loader._data.arcane_bolt)
    end)

    it("skips abilities with missing module field", function()
      local tmpPath = os.tmpname()
      local json = _G.json or require("json")
      local f = io.open(tmpPath, "w")
      f:write(json.encode({
        good_ability = {
          name = "Good",
          module = "src.entities.abilities.arcane_bolt",
          unlocked = true,
          maxTier = 5,
          baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 }
        },
        bad_ability = {
          name = "Bad",
          unlocked = true,
          maxTier = 5,
          baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 }
        }
      }))
      f:close()

      local origPathForFile = system.pathForFile
      system.pathForFile = function() return tmpPath end

      local success = ability_data_loader.initialize(tmpPath)

      assert.is_true(success)
      assert.is_not_nil(ability_data_loader._data.good_ability)
      assert.is_nil(ability_data_loader._data.bad_ability)

      system.pathForFile = origPathForFile
      os.remove(tmpPath)
    end)
  end)

  describe("getBaseStats", function()
    before_each(function()
      ability_data_loader.initialize("data/abilities.json")
    end)

    it("returns base stats for a valid ability", function()
      local stats = ability_data_loader.getBaseStats("arcane_bolt")

      assert.is_not_nil(stats)
      assert.are.equal(1.0, stats.cooldown)
      assert.are.equal(10, stats.damage)
      assert.are.equal(400, stats.projectileSpeed)
      assert.are.equal(0, stats.pierceCount)
      assert.are.equal(1, stats.projectileCount)
    end)

    it("returns nil for unknown ability", function()
      local stats = ability_data_loader.getBaseStats("unknown_ability")

      assert.is_nil(stats)
    end)

    it("returns nil when data not initialized", function()
      ability_data_loader._data = nil

      local stats = ability_data_loader.getBaseStats("arcane_bolt")

      assert.is_nil(stats)
    end)

    it("returns defaults for missing baseStats fields", function()
      -- Inject ability with partial baseStats
      ability_data_loader._data = {
        test_ability = {
          name = "Test",
          module = "test.module",
          unlocked = true,
          maxTier = 5,
          baseStats = { cooldown = 2.0 }
        }
      }

      local stats = ability_data_loader.getBaseStats("test_ability")

      assert.is_not_nil(stats)
      assert.are.equal(2.0, stats.cooldown)
      assert.are.equal(10, stats.damage)       -- default
      assert.are.equal(400, stats.projectileSpeed) -- default
      assert.are.equal(0, stats.pierceCount)    -- default
      assert.are.equal(1, stats.projectileCount) -- default
    end)

    it("returns defaults for invalid numeric baseStats fields", function()
      ability_data_loader._data = {
        test_ability = {
          name = "Test",
          module = "test.module",
          unlocked = true,
          maxTier = 5,
          baseStats = { cooldown = -1, damage = "bad", projectileSpeed = 0, pierceCount = -5, projectileCount = 0 }
        }
      }

      local stats = ability_data_loader.getBaseStats("test_ability")

      assert.is_not_nil(stats)
      assert.are.equal(1.0, stats.cooldown)       -- default (was negative)
      assert.are.equal(10, stats.damage)           -- default (was string)
      assert.are.equal(400, stats.projectileSpeed) -- default (was zero)
      assert.are.equal(0, stats.pierceCount)       -- default (was negative)
      assert.are.equal(1, stats.projectileCount)   -- default (was zero)
    end)

    it("returns all defaults when baseStats is not a table", function()
      ability_data_loader._data = {
        test_ability = {
          name = "Test",
          module = "test.module",
          unlocked = true,
          maxTier = 5,
          baseStats = "not a table"
        }
      }

      local stats = ability_data_loader.getBaseStats("test_ability")

      assert.is_not_nil(stats)
      assert.are.equal(1.0, stats.cooldown)
      assert.are.equal(10, stats.damage)
      assert.are.equal(400, stats.projectileSpeed)
      assert.are.equal(0, stats.pierceCount)
      assert.are.equal(1, stats.projectileCount)
    end)
  end)

  describe("getUpgradeParams", function()
    before_each(function()
      ability_data_loader.initialize("data/abilities.json")
    end)

    it("returns upgrade params for valid ability and upgrade type", function()
      local params = ability_data_loader.getUpgradeParams("arcane_bolt", "damage_increase")

      assert.is_not_nil(params)
      assert.are.equal(5, params.damageIncrease)
      assert.are.equal("Arcane Bolt Damage", params.name)
    end)

    it("returns attack_speed upgrade params", function()
      local params = ability_data_loader.getUpgradeParams("arcane_bolt", "attack_speed")

      assert.is_not_nil(params)
      assert.are.equal(0.15, params.cooldownReduction)
      assert.are.equal(0.25, params.minCooldown)
    end)

    it("returns nil for unknown upgrade type", function()
      local params = ability_data_loader.getUpgradeParams("arcane_bolt", "nonexistent_upgrade")

      assert.is_nil(params)
    end)

    it("returns nil for unknown ability", function()
      local params = ability_data_loader.getUpgradeParams("unknown_ability", "damage_increase")

      assert.is_nil(params)
    end)

    it("returns nil when data not initialized", function()
      ability_data_loader._data = nil

      local params = ability_data_loader.getUpgradeParams("arcane_bolt", "damage_increase")

      assert.is_nil(params)
    end)

    it("returns nil when ability has no upgrades section", function()
      ability_data_loader._data = {
        test_ability = {
          name = "Test",
          module = "test.module",
          unlocked = true,
          maxTier = 5,
          baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 }
        }
      }

      local params = ability_data_loader.getUpgradeParams("test_ability", "damage_increase")

      assert.is_nil(params)
    end)
  end)

  describe("getTierParams", function()
    before_each(function()
      ability_data_loader.initialize("data/abilities.json")
    end)

    it("returns tier params for valid ability and tier", function()
      local params = ability_data_loader.getTierParams("arcane_bolt", 2)

      assert.is_not_nil(params)
      assert.are.equal(5, params.damageBonus)
      assert.are.equal(0.15, params.cooldownReduction)
    end)

    it("returns empty table for tier 1 (no bonuses)", function()
      local params = ability_data_loader.getTierParams("arcane_bolt", 1)

      assert.is_not_nil(params)
      assert.is_table(params)
    end)

    it("returns tier 5 params with multiple bonuses", function()
      local params = ability_data_loader.getTierParams("arcane_bolt", 5)

      assert.is_not_nil(params)
      assert.are.equal(10, params.damageBonus)
      assert.are.equal(1, params.pierceBonus)
      assert.are.equal(1, params.projectileCountBonus)
    end)

    it("returns nil for unknown tier", function()
      local params = ability_data_loader.getTierParams("arcane_bolt", 99)

      assert.is_nil(params)
    end)

    it("returns nil for unknown ability", function()
      local params = ability_data_loader.getTierParams("unknown_ability", 1)

      assert.is_nil(params)
    end)

    it("returns nil when data not initialized", function()
      ability_data_loader._data = nil

      local params = ability_data_loader.getTierParams("arcane_bolt", 1)

      assert.is_nil(params)
    end)

    it("returns nil when ability has no tiers section", function()
      ability_data_loader._data = {
        test_ability = {
          name = "Test",
          module = "test.module",
          unlocked = true,
          maxTier = 5,
          baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 }
        }
      }

      local params = ability_data_loader.getTierParams("test_ability", 1)

      assert.is_nil(params)
    end)
  end)

  describe("validateAbilityEntry", function()
    it("returns true for a fully valid entry", function()
      local data = {
        name = "Arcane Bolt",
        module = "src.entities.abilities.arcane_bolt",
        unlocked = true,
        maxTier = 5,
        baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 }
      }

      assert.is_true(ability_data_loader.validateAbilityEntry("arcane_bolt", data))
    end)

    it("returns false when entry is not a table", function()
      assert.is_false(ability_data_loader.validateAbilityEntry("bad", "not a table"))
      assert.is_false(ability_data_loader.validateAbilityEntry("bad", nil))
      assert.is_false(ability_data_loader.validateAbilityEntry("bad", 42))
    end)

    it("returns false when module is missing", function()
      local data = {
        name = "Test",
        unlocked = true,
        maxTier = 5,
        baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 }
      }

      assert.is_false(ability_data_loader.validateAbilityEntry("test", data))
    end)

    it("returns false when module is empty string", function()
      local data = {
        name = "Test",
        module = "",
        unlocked = true,
        maxTier = 5,
        baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 }
      }

      assert.is_false(ability_data_loader.validateAbilityEntry("test", data))
    end)

    it("defaults name to ability ID when missing", function()
      local data = {
        module = "test.module",
        unlocked = true,
        maxTier = 5,
        baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 }
      }

      ability_data_loader.validateAbilityEntry("my_ability", data)

      assert.are.equal("my_ability", data.name)
    end)

    it("defaults unlocked to false when not boolean", function()
      local data = {
        name = "Test",
        module = "test.module",
        unlocked = "yes",
        maxTier = 5,
        baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 }
      }

      ability_data_loader.validateAbilityEntry("test", data)

      assert.is_false(data.unlocked)
    end)

    it("defaults maxTier to 5 when invalid", function()
      local data = {
        name = "Test",
        module = "test.module",
        unlocked = true,
        maxTier = -1,
        baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 }
      }

      ability_data_loader.validateAbilityEntry("test", data)

      assert.are.equal(5, data.maxTier)
    end)

    it("defaults maxTier to 5 when non-integer", function()
      local data = {
        name = "Test",
        module = "test.module",
        unlocked = true,
        maxTier = 3.5,
        baseStats = { cooldown = 1.0, damage = 10, projectileSpeed = 400, pierceCount = 0, projectileCount = 1 }
      }

      ability_data_loader.validateAbilityEntry("test", data)

      assert.are.equal(5, data.maxTier)
    end)

    it("returns false when baseStats is missing", function()
      local data = {
        name = "Test",
        module = "test.module",
        unlocked = true,
        maxTier = 5
      }

      assert.is_false(ability_data_loader.validateAbilityEntry("test", data))
    end)
  end)

end)
