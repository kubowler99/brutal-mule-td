-- Tests for telegraphed boss attacks and elite abilities (slam, charge, summon)

require("tests.spec_helper")

local data = require("src.models.data")
local config_loader = require("src.models.config_loader")
local Walker = require("src.entities.walker")
local pool = require("src.utils.pool")
local spawner_system = require("src.systems.spawner_system")
local game_controller = require("src.controllers.game_controller")

describe("Boss and elite mechanics", function()
    describe("in the game loop", function()
        local wall
        local restoreSpawner

        -- Runs game_controller.update at the given times (milliseconds)
        local function frames(times)
            for _, t in ipairs(times) do
                game_controller.update({ time = t })
            end
        end

        before_each(function()
            data.startSandbox()
            game_controller.initialize({ insert = function() end, numChildren = 0 })
            game_controller.start()
            -- Keep the test about one enemy: no abilities firing, no new spawns
            game_controller.getHero().abilities = {}
            restoreSpawner = snapshotModule(spawner_system)
            spawner_system.update = function() end
            wall = game_controller.getWall()
            wall.maxHealth, wall.health = 10000, 10000
        end)

        after_each(function()
            restoreSpawner()
            game_controller.cleanup()
            data.stopSandbox(false)
        end)

        it("telegraphs a boss attack before it lands", function()
            local boss = Walker:new(nil)
            boss:activate(360, 1140, 360, "boss")
            table.insert(spawner_system.getActiveWalkers(), boss)

            -- First frame at the wall: winding up, no damage yet
            frames({ 1000 })
            assert.is_true(boss.isTelegraphing)
            assert.are.equal(10000, wall.health)

            -- 0.6s later the attack lands and the wind-up ends
            frames({ 1100, 1200, 1300, 1400, 1500, 1600, 1700 })
            assert.are.equal(10000 - boss.damage, wall.health)
            assert.is_false(boss.isTelegraphing)
        end)

        it("does not telegraph ordinary enemies", function()
            local walker = Walker:new(nil)
            walker:activate(360, 1140, 360, "walker")
            table.insert(spawner_system.getActiveWalkers(), walker)

            frames({ 1000 })

            assert.is_falsy(walker.isTelegraphing)
            assert.are.equal(10000 - walker.damage, wall.health)
        end)

        it("makes slam elites telegraph and hit twice as hard", function()
            local elite = Walker:new(nil)
            elite:activate(360, 1140, 360, "walker")
            elite:makeElite(1, 1, 1, "slam")
            table.insert(spawner_system.getActiveWalkers(), elite)

            frames({ 1000 })
            assert.is_true(elite.isTelegraphing)

            frames({ 1100, 1200, 1300, 1400, 1500, 1600, 1700 })
            assert.are.equal(10000 - elite.damage * 2, wall.health)
        end)
    end)

    describe("charge", function()
        it("charges once at triple speed when close to the wall", function()
            local elite = Walker:new(nil)
            elite:activate(300, 0, 300, "walker")
            elite:makeElite(1, 1, 1, "charge")

            -- Far from the wall: normal speed
            elite:update(0.1, 1140)
            assert.are.equal(80, elite:getCurrentSpeed())

            -- Within 400px of the stop point: the charge starts
            elite.y = 800
            elite:update(0.1, 1140)
            assert.are.equal(240, elite:getCurrentSpeed())

            -- The charge ends after 1s and does not repeat
            elite:update(1.0, 1140)
            elite:update(0.1, 1140)
            assert.are.equal(80, elite:getCurrentSpeed())
            assert.is_true(elite.hasCharged)
        end)

        it("is still slowed by frost while charging", function()
            local elite = Walker:new(nil)
            elite:activate(300, 800, 300, "walker")
            elite:makeElite(1, 1, 1, "charge")
            elite:update(0.01, 1140)
            elite:applySlow(0.5, 2)
            assert.are.equal(120, elite:getCurrentSpeed())
        end)
    end)

    describe("summon", function()
        local savedConfig

        before_each(function()
            savedConfig = config_loader._data
            config_loader._data = { spawner = { elites = { minLevel = 1, chance = 1 } } }
            spawner_system.initialize(pool.new(function() return Walker:new(nil) end), 1)
        end)

        after_each(function()
            config_loader._data = savedConfig
            spawner_system.cleanup()
        end)

        it("asks for two minions every 5 seconds", function()
            local elite = Walker:new(nil)
            elite:activate(300, 200, 300, "walker")
            elite:makeElite(1, 1, 1, "summon")

            elite:update(4.9, 1140)
            assert.are.equal(0, elite.pendingSummons)
            elite:update(0.2, 1140)
            assert.are.equal(2, elite.pendingSummons)
        end)

        it("spawns the minions beside the summoner, never as elites", function()
            local summoner = spawner_system.spawnWalker("walker", 300, false, { noElite = true })
            summoner.y = 500
            summoner.pendingSummons = 2

            spawner_system.spawnSummons()

            local active = spawner_system.activeWalkers
            assert.are.equal(3, #active)
            for i = 2, 3 do
                assert.are.equal("swarmling", active[i].type)
                assert.are.equal(500, active[i].y)
                assert.is_false(active[i].isElite)
            end
            assert.are.same({ 270, 330 }, { active[2].x, active[3].x })
            assert.are.equal(0, summoner.pendingSummons)
        end)
    end)

    describe("spawner", function()
        local savedConfig
        local originalRandom

        before_each(function()
            savedConfig = config_loader._data
            originalRandom = math.random
        end)

        after_each(function()
            math.random = originalRandom
            config_loader._data = savedConfig
            spawner_system.cleanup()
        end)

        it("gives each elite one ability from the configured list", function()
            config_loader._data = { spawner = { elites = { minLevel = 1, chance = 1, abilities = { "slam", "charge", "summon" } } } }
            spawner_system.initialize(pool.new(function() return Walker:new(nil) end), 1)
            math.random = function(low, high)
                if low == nil then return 0 end
                return high  -- pick the last ability
            end

            local elite = spawner_system.spawnWalker("walker", 300)

            assert.is_true(elite.isElite)
            assert.are.equal("summon", elite.eliteAbility)
        end)

        it("clears the elite ability when the enemy is reused", function()
            local walker = Walker:new(nil)
            walker:activate(300, 0, 300)
            walker:makeElite(2, 2, 2, "charge")
            walker:deactivate()
            walker:activate(300, 0, 300)
            assert.is_nil(walker.eliteAbility)
            assert.is_false(walker.hasCharged)
        end)
    end)
end)
