-- Tests for Config Loader
-- Validates loading, dot-notation path lookup, positiveNumber validation, and fallback behavior

require("tests.spec_helper")

local config_loader = require("src.models.config_loader")

describe("Config Loader", function()

  before_each(function()
    -- Reset cached data before each test
    config_loader._data = nil
  end)

  describe("initialize", function()
    it("loads config data from valid JSON file", function()
      local success = config_loader.initialize("data/game_config.json")

      assert.is_true(success)
      assert.is_not_nil(config_loader._data)
      assert.is_not_nil(config_loader._data.wall)
    end)

    it("returns false and sets empty data when file not found", function()
      local origPathForFile = system.pathForFile
      system.pathForFile = function() return nil end

      local success = config_loader.initialize("data/nonexistent.json")

      assert.is_false(success)
      assert.is_table(config_loader._data)

      system.pathForFile = origPathForFile
    end)

    it("returns false when file cannot be opened", function()
      local origOpen = io.open
      io.open = function() return nil end

      local success = config_loader.initialize("data/game_config.json")

      assert.is_false(success)
      assert.is_table(config_loader._data)

      io.open = origOpen
    end)

    it("returns false when JSON is invalid", function()
      local tmpPath = os.tmpname()
      local f = io.open(tmpPath, "w")
      f:write("not valid json {{{")
      f:close()

      local origPathForFile = system.pathForFile
      system.pathForFile = function() return tmpPath end

      local success = config_loader.initialize(tmpPath)

      assert.is_false(success)
      assert.is_table(config_loader._data)

      system.pathForFile = origPathForFile
      os.remove(tmpPath)
    end)

    it("defaults to data/game_config.json when no path provided", function()
      local success = config_loader.initialize()

      assert.is_true(success)
      assert.is_not_nil(config_loader._data.wall)
    end)
  end)

  describe("get", function()
    before_each(function()
      config_loader.initialize("data/game_config.json")
    end)

    it("returns top-level value", function()
      local wall = config_loader.get("wall")

      assert.is_table(wall)
      assert.are.equal(100, wall.health)
    end)

    it("returns nested value with dot notation", function()
      local health = config_loader.get("wall.health")

      assert.are.equal(100, health)
    end)

    it("returns deeply nested value", function()
      local interval = config_loader.get("spawner.spawnInterval")

      assert.are.equal(3.0, interval)
    end)

    it("returns default when path not found", function()
      local result = config_loader.get("nonexistent.path", 42)

      assert.are.equal(42, result)
    end)

    it("returns default when intermediate path segment not found", function()
      local result = config_loader.get("wall.nonexistent.deep", "fallback")

      assert.are.equal("fallback", result)
    end)

    it("returns default when data not initialized", function()
      config_loader._data = nil

      local result = config_loader.get("wall.health", 999)

      assert.are.equal(999, result)
    end)

    it("returns default when path traverses a non-table value", function()
      local result = config_loader.get("wall.health.deeper", 50)

      assert.are.equal(50, result)
    end)

    it("returns all known config values correctly", function()
      assert.are.equal(100, config_loader.get("wall.health"))
      assert.are.equal(100, config_loader.get("wall.maxHealth"))
      assert.are.equal(3.0, config_loader.get("spawner.spawnInterval"))
      assert.are.equal(1, config_loader.get("spawner.spawnCount"))
      assert.are.equal(50, config_loader.get("spawner.maxConcurrent"))
      assert.are.equal(20, config_loader.get("collision.projectileEnemyThreshold"))
      assert.are.equal(30, config_loader.get("collision.heroEnemyMeleeThreshold"))
      assert.are.equal(100, config_loader.get("experience.baseXPRequired"))
      assert.are.equal(20, config_loader.get("experience.xpPerLevelIncrement"))
    end)

    it("returns nil default when no default provided and path missing", function()
      local result = config_loader.get("nonexistent")

      assert.is_nil(result)
    end)
  end)

  describe("positiveNumber", function()
    it("returns value when it is a positive number", function()
      assert.are.equal(42, config_loader.positiveNumber(42, 10))
      assert.are.equal(0.5, config_loader.positiveNumber(0.5, 10))
      assert.are.equal(1, config_loader.positiveNumber(1, 10))
    end)

    it("returns default when value is zero", function()
      assert.are.equal(10, config_loader.positiveNumber(0, 10))
    end)

    it("returns default when value is negative", function()
      assert.are.equal(10, config_loader.positiveNumber(-5, 10))
    end)

    it("returns default when value is not a number", function()
      assert.are.equal(10, config_loader.positiveNumber("hello", 10))
      assert.are.equal(10, config_loader.positiveNumber(true, 10))
      assert.are.equal(10, config_loader.positiveNumber({}, 10))
    end)

    it("returns default when value is nil", function()
      assert.are.equal(10, config_loader.positiveNumber(nil, 10))
    end)
  end)

end)
