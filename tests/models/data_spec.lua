require("tests.spec_helper")
local data = require("src.models.data")

describe("Data Model", function()
    -- Mock the json module since we don't have it in standard Lua environment for tests
    -- although we could try to require "json" if we have a pure lua version or if Busted
    -- is running in an environment that has it.
    -- For now, let's assume we might need to mock it if tests fail.

    before_each(function()
        -- Reset data to defaults before each test
        -- We can't easily call data.load() because it uses system.pathForFile and io.open
        -- but our spec_helper mocks system.pathForFile.
        -- However, io.open might still fail or do weird things.
        -- Let's manually set data.data to defaults for testing get/set.
        data.data = {
            settings = {
                soundOn = true,
                musicOn = true,
            },
            score = 100,
            highScore = 500,
        }
    end)

    describe("get", function()
        it("should retrieve values using dot notation", function()
            assert.is.equal(100, data.get("score"))
            assert.is_true(data.get("settings.soundOn"))
            assert.is_nil(data.get("nonexistent.key"))
        end)

        it("should return the entire data table if no path is provided", function()
            local allData = data.get()
            assert.is.equal(data.data, allData)
        end)
    end)

    describe("set", function()
        it("should set values using dot notation", function()
            data.set("score", 200)
            assert.is.equal(200, data.data.score)

            data.set("settings.musicOn", false)
            assert.is_false(data.data.settings.musicOn)
        end)

        it("should create nested tables if they don't exist", function()
            data.set("stats.gamesPlayed", 5)
            assert.is.equal(5, data.data.stats.gamesPlayed)
        end)
    end)

    describe("Sandbox Mode", function()
        it("should not affect original data when in sandbox mode", function()
            data.startSandbox()
            data.set("score", 999)
            
            assert.is.equal(999, data.get("score"))
            assert.is.equal(100, data.data.score) -- Original data remains 100
            
            data.stopSandbox(false)
            assert.is.equal(100, data.get("score"))
        end)

        it("should apply changes when stopping sandbox with applyChanges = true", function()
            data.startSandbox()
            data.set("score", 999)
            data.stopSandbox(true)
            
            assert.is.equal(999, data.get("score"))
            assert.is.equal(999, data.data.score)
        end)
    end)
end)
