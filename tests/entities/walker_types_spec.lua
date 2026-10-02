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

        it("shrinks runners and keeps walkers full size", function()
            local runner = Walker:new(nil)
            runner:activate(100, 0, 100, "runner")
            local walker = Walker:new(nil)
            walker:activate(100, 0, 100, "walker")

            assert.are.equal(0.75, runner.displayObject.xScale)
            assert.are.equal(1.0, walker.displayObject.xScale)
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

    describe("spawner mix", function()
        local originalRandom

        before_each(function()
            originalRandom = math.random
            spawner_system.initialize(pool.new(function() return Walker:new(nil) end), 1)
        end)

        after_each(function()
            math.random = originalRandom
            spawner_system.cleanup()
        end)

        it("spawns only walkers below the runner level", function()
            math.random = function(...)
                if select("#", ...) == 0 then return 0 end
                return originalRandom(...)
            end
            spawner_system.updateDifficulty(2)

            assert.are.equal("walker", spawner_system.chooseEnemyType())
        end)

        it("mixes in runners from the runner level", function()
            spawner_system.updateDifficulty(3)

            math.random = function(...)
                if select("#", ...) == 0 then return 0.1 end
                return originalRandom(...)
            end
            assert.are.equal("runner", spawner_system.chooseEnemyType())

            math.random = function(...)
                if select("#", ...) == 0 then return 0.9 end
                return originalRandom(...)
            end
            assert.are.equal("walker", spawner_system.chooseEnemyType())
        end)

        it("activates spawned enemies with the chosen type", function()
            spawner_system.updateDifficulty(3)
            local originalChoose = spawner_system.chooseEnemyType
            spawner_system.chooseEnemyType = function() return "runner" end

            spawner_system.spawnWalker()

            spawner_system.chooseEnemyType = originalChoose
            local spawned = spawner_system.activeWalkers[1]
            assert.are.equal("runner", spawned.type)
            assert.are.equal(160, spawned.speed)
        end)
    end)
end)
