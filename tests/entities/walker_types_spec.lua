-- Tests for enemy types (walker, runner) and the slow effect

require("tests.spec_helper")

local Walker = require("src.entities.walker")
local spawner_system = require("src.systems.spawner_system")
local experience_system = require("src.systems.experience_system")
local pool = require("src.utils.pool")

describe("Enemy types", function()
    describe("stats", function()
        it("defaults to walker stats from enemies.json", function()
            local walker = Walker:new(nil)
            walker:activate(100, 0, 100)

            assert.are.equal("walker", walker.type)
            assert.are.equal(20, walker.maxHealth)
            assert.are.equal(20, walker.health)
            assert.are.equal(80, walker.speed)
            assert.are.equal(5, walker.damage)
        end)

        it("loads runner stats from enemies.json", function()
            local runner = Walker:new(nil)
            runner:activate(100, 0, 100, "runner")

            assert.are.equal("runner", runner.type)
            assert.are.equal(10, runner.maxHealth)
            assert.are.equal(10, runner.health)
            assert.are.equal(160, runner.speed)
            assert.are.equal(3, runner.damage)
            assert.are.equal(0.8, runner.attackCooldown)
        end)

        it("switches stats when a pooled enemy comes back as another type", function()
            local enemy = Walker:new(nil)
            enemy:activate(100, 0, 100, "runner")
            enemy:deactivate()

            enemy:activate(100, 0, 100, "walker")

            assert.are.equal("walker", enemy.type)
            assert.are.equal(20, enemy.health)
            assert.are.equal(80, enemy.speed)
        end)

        it("shrinks runners and keeps walkers at full sprite size", function()
            local runner = Walker:new(nil)
            runner:activate(100, 0, 100, "runner")
            local walker = Walker:new(nil)
            walker:activate(100, 0, 100, "walker")

            assert.are.equal(1.5 * 0.75, runner.displayObject.xScale)
            assert.are.equal(1.5, walker.displayObject.xScale)
        end)

        it("tints runners orange, slowed enemies blue, and walkers not at all", function()
            local enemy = Walker:new(nil)
            enemy:activate(100, 0, 100, "walker")
            local tints = {}
            enemy.displayObject.setFillColor = function(self, r, g, b)
                table.insert(tints, {r, g, b})
            end

            enemy:refreshStyle()
            enemy:applySlow(0.5, 1.0)
            enemy:deactivate()
            enemy:activate(100, 0, 100, "runner")

            assert.are.same({1.0, 1.0, 1.0}, tints[1])
            assert.are.same({0.5, 0.8, 1.0}, tints[2])
            assert.are.same({1.0, 0.65, 0.3}, tints[#tints])
        end)

        it("awards runner XP from enemies.json", function()
            experience_system.initialize({ xp = 0, level = 1 }, function() end)
            assert.are.equal(8, experience_system.getEnemyXPValue("runner"))
            assert.are.equal(10, experience_system.getEnemyXPValue("walker"))
            experience_system.cleanup()
        end)
    end)

    describe("slow", function()
        local walker

        before_each(function()
            walker = Walker:new(nil)
            walker:activate(100, 0, 100)
        end)

        it("reduces movement while active", function()
            walker:applySlow(0.5, 2.0)
            walker:update(1.0, 1140)

            assert.are.equal(40, walker.y)
        end)

        it("expires after its duration", function()
            walker:applySlow(0.5, 1.0)
            walker:update(1.0, 1140)
            assert.are.equal(80, walker:getCurrentSpeed())

            walker:update(1.0, 1140)
            assert.are.equal(40 + 80, walker.y)
        end)

        it("keeps the strongest slow and the longest duration", function()
            walker:applySlow(0.3, 1.0)
            walker:applySlow(0.6, 3.0)

            assert.are.equal(0.3, walker.slowFactor)
            assert.are.equal(3.0, walker.slowRemaining)
        end)

        it("is cleared when the enemy is reused from the pool", function()
            walker:applySlow(0.5, 2.0)
            walker:deactivate()
            walker:activate(100, 0, 100)

            assert.are.equal(80, walker:getCurrentSpeed())
        end)

        it("is ignored by inactive enemies", function()
            walker:deactivate()
            walker:applySlow(0.5, 2.0)

            assert.are.equal(0, walker.slowRemaining)
        end)
    end)

    describe("spawn table", function()
        local config_loader = require("src.models.config_loader")
        local originalRandom
        local savedConfig

        local TEST_TABLE = {
            { type = "walker", weight = 7, minLevel = 1, groupSize = 1 },
            { type = "runner", weight = 3, minLevel = 3, groupSize = 1 },
            { type = "swarmling", weight = 2, minLevel = 4, groupSize = 4 },
        }

        local function randomReturning(value)
            return function(...)
                if select("#", ...) == 0 then return value end
                return originalRandom(...)
            end
        end

        before_each(function()
            originalRandom = math.random
            savedConfig = config_loader._data
            config_loader._data = { spawner = { enemyTable = TEST_TABLE } }
            spawner_system.initialize(pool.new(function() return Walker:new(nil) end), 1)
        end)

        after_each(function()
            math.random = originalRandom
            config_loader._data = savedConfig
            spawner_system.cleanup()
        end)

        it("loads the spawn table from game_config.json", function()
            assert.are.equal(3, #spawner_system.enemyTable)
            assert.are.equal("swarmling", spawner_system.enemyTable[3].type)
            assert.are.equal(4, spawner_system.enemyTable[3].groupSize)
        end)

        it("falls back to walkers only without a spawn table", function()
            config_loader._data = {}
            spawner_system.initialize(pool.new(function() return Walker:new(nil) end), 10)
            assert.are.equal(1, #spawner_system.enemyTable)
            assert.are.equal("walker", spawner_system.chooseEnemyEntry().type)
        end)

        it("only picks entries the hero level has unlocked", function()
            spawner_system.updateDifficulty(2)
            for _, roll in ipairs({0, 0.5, 0.99}) do
                math.random = randomReturning(roll)
                assert.are.equal("walker", spawner_system.chooseEnemyEntry().type)
            end
        end)

        it("picks by weight among unlocked entries", function()
            -- Level 3: walker 7, runner 3 (swarmling still locked)
            spawner_system.updateDifficulty(3)

            math.random = randomReturning(0.65)
            assert.are.equal("walker", spawner_system.chooseEnemyEntry().type)

            math.random = randomReturning(0.75)
            assert.are.equal("runner", spawner_system.chooseEnemyEntry().type)
        end)

        it("spawns a whole group side by side", function()
            spawner_system.updateDifficulty(4)
            local originalChoose = spawner_system.chooseEnemyEntry
            spawner_system.chooseEnemyEntry = function() return TEST_TABLE[3] end

            spawner_system.spawnEnemyGroup()

            spawner_system.chooseEnemyEntry = originalChoose
            local spawned = spawner_system.activeWalkers
            assert.are.equal(4, #spawned)
            for i = 1, 4 do
                assert.are.equal("swarmling", spawned[i].type)
            end
            assert.are.equal(30, spawned[2].x - spawned[1].x)
        end)

        it("keeps a group's spacing when its center lands at either edge", function()
            spawner_system.updateDifficulty(4)
            local originalChoose = spawner_system.chooseEnemyEntry
            spawner_system.chooseEnemyEntry = function() return TEST_TABLE[3] end

            for _, pickLow in ipairs({ true, false }) do
                spawner_system.activeWalkers = {}
                -- Force the group center to the lowest or highest allowed value
                math.random = function(low, high)
                    if low == nil then return originalRandom() end
                    return pickLow and low or high
                end

                spawner_system.spawnEnemyGroup()

                local spawned = spawner_system.activeWalkers
                assert.are.equal(4, #spawned)
                for i = 2, 4 do
                    assert.are.equal(30, spawned[i].x - spawned[i - 1].x)
                end
                assert.is_true(spawned[1].x >= 50 and spawned[4].x <= 670)
            end

            spawner_system.chooseEnemyEntry = originalChoose
        end)

        it("activates spawned enemies with the given type", function()
            spawner_system.spawnWalker("runner", 200)

            local spawned = spawner_system.activeWalkers[1]
            assert.are.equal("runner", spawned.type)
            assert.are.equal(160, spawned.speed)
            assert.are.equal(200, spawned.x)
        end)

        it("does not exceed the concurrent limit when spawning a group", function()
            spawner_system.maxConcurrent = 2
            local originalChoose = spawner_system.chooseEnemyEntry
            spawner_system.chooseEnemyEntry = function() return TEST_TABLE[3] end

            spawner_system.spawnEnemyGroup()

            spawner_system.chooseEnemyEntry = originalChoose
            assert.are.equal(2, #spawner_system.activeWalkers)
        end)
    end)

    describe("brute and swarmling stats", function()
        it("loads brute stats from enemies.json", function()
            local brute = Walker:new(nil)
            brute:activate(100, 0, 100, "brute")
            assert.are.equal(80, brute.maxHealth)
            assert.are.equal(40, brute.speed)
            assert.are.equal(12, brute.damage)
            assert.are.equal(1.5 * 1.35, brute.displayObject.xScale)
        end)

        it("loads swarmling stats from enemies.json", function()
            local swarmling = Walker:new(nil)
            swarmling:activate(100, 0, 100, "swarmling")
            assert.are.equal(4, swarmling.maxHealth)
            assert.are.equal(110, swarmling.speed)
            assert.are.equal(1, swarmling.damage)
        end)

        it("awards brute and swarmling XP from enemies.json", function()
            experience_system.initialize({ xp = 0, level = 1 }, function() end)
            assert.are.equal(30, experience_system.getEnemyXPValue("brute"))
            assert.are.equal(3, experience_system.getEnemyXPValue("swarmling"))
            experience_system.cleanup()
        end)
    end)
end)
