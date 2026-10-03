-- Tests for the run arc: Spitter, elites, bosses, and victory

require("tests.spec_helper")

local composer = require("composer")
local Walker = require("src.entities.walker")
local pool = require("src.utils.pool")
local config_loader = require("src.models.config_loader")
local collision_system = require("src.systems.collision_system")
local spawner_system = require("src.systems.spawner_system")
local experience_system = require("src.systems.experience_system")
local game_controller = require("src.controllers.game_controller")
local game_state = require("src.models.game_state")

describe("Run arc", function()
    describe("Spitter", function()
        it("stops attackRange short of the wall and attacks from there", function()
            local spitter = Walker:new(nil)
            spitter:activate(300, 800, 300, "spitter")
            assert.are.equal(260, spitter.attackRange)

            spitter:update(5.0, 1140)

            assert.are.equal(880, spitter.y)
            assert.is_true(spitter.isAttackingWall)
            assert.are.same({ spitter }, collision_system.checkWallCollisions({ spitter }, 1140))
        end)

        it("leaves melee enemies attacking at the wall", function()
            local walker = Walker:new(nil)
            walker:activate(300, 1000, 300, "walker")
            walker:update(5.0, 1140)
            assert.are.equal(1140, walker.y)
        end)

        it("is not a wall collision before reaching its range", function()
            local spitter = Walker:new(nil)
            spitter:activate(300, 700, 300, "spitter")
            assert.are.same({}, collision_system.checkWallCollisions({ spitter }, 1140))
        end)
    end)

    describe("elites", function()
        it("multiplies health, damage, and XP and grows the enemy", function()
            local walker = Walker:new(nil)
            walker:activate(300, 0, 300, "walker")
            walker:makeElite(4, 2, 5)

            assert.is_true(walker.isElite)
            assert.are.equal(80, walker.maxHealth)
            assert.are.equal(80, walker.health)
            assert.are.equal(10, walker.damage)
            assert.are.equal(5, walker.xpMultiplier)
            assert.are.equal(1.5 * 1.3, walker.displayObject.xScale)
        end)

        it("drops the elite bonus when the enemy is reused from the pool", function()
            local walker = Walker:new(nil)
            walker:activate(300, 0, 300, "walker")
            walker:makeElite(4, 2, 5)
            walker:deactivate()

            walker:activate(300, 0, 300)

            assert.is_false(walker.isElite)
            assert.are.equal(20, walker.maxHealth)
            assert.are.equal(5, walker.damage)
            assert.are.equal(1, walker.xpMultiplier)
        end)
    end)

    describe("spawner", function()
        local savedConfig
        local originalRandom

        local function initSpawner(level, spawnerConfig)
            config_loader._data = { spawner = spawnerConfig }
            spawner_system.initialize(pool.new(function() return Walker:new(nil) end), level)
        end

        before_each(function()
            savedConfig = config_loader._data
            originalRandom = math.random
        end)

        after_each(function()
            math.random = originalRandom
            config_loader._data = savedConfig
            spawner_system.cleanup()
        end)

        local ELITES = { minLevel = 8, chance = 0.1, healthMultiplier = 4, damageMultiplier = 2, xpMultiplier = 5 }

        local function rollAlways(value)
            math.random = function(...)
                if select("#", ...) == 0 then return value end
                return originalRandom(...)
            end
        end

        it("spawns elites only from the elite level, at the elite chance", function()
            initSpawner(7, { elites = ELITES })
            rollAlways(0.05)
            assert.is_false(spawner_system.spawnWalker("walker", 100).isElite)

            spawner_system.updateDifficulty(8)
            assert.is_true(spawner_system.spawnWalker("walker", 100).isElite)

            rollAlways(0.5)
            assert.is_false(spawner_system.spawnWalker("walker", 100).isElite)
        end)

        it("spawns no elites without elite settings", function()
            initSpawner(20, {})
            rollAlways(0)
            assert.is_false(spawner_system.spawnWalker("walker", 100).isElite)
        end)

        it("spawns each boss once when the hero reaches its level", function()
            local announced = {}
            initSpawner(1, { bosses = { { level = 10, type = "boss" }, { level = 20, type = "final_boss" } } })
            spawner_system.onBossSpawned = function(boss) table.insert(announced, boss) end

            spawner_system.updateDifficulty(9)
            spawner_system.checkBossSpawns()
            assert.are.equal(0, #announced)

            spawner_system.updateDifficulty(10)
            spawner_system.checkBossSpawns()
            spawner_system.checkBossSpawns()
            assert.are.equal(1, #announced)
            assert.are.equal("boss", announced[1].type)
            assert.is_true(announced[1].isBoss)
            assert.are.equal(360, announced[1].x)

            spawner_system.updateDifficulty(20)
            spawner_system.checkBossSpawns()
            assert.are.equal(2, #announced)
            assert.is_true(announced[2].isFinalBoss)
        end)

        it("spawns a boss even at the concurrent limit", function()
            initSpawner(10, { maxConcurrent = 1, bosses = { { level = 10, type = "boss" } } })
            spawner_system.spawnWalker("walker", 100)
            assert.are.equal(1, #spawner_system.activeWalkers)

            spawner_system.checkBossSpawns()

            assert.are.equal(2, #spawner_system.activeWalkers)
        end)

        it("never makes a boss elite", function()
            initSpawner(10, { elites = { minLevel = 1, chance = 1 }, bosses = { { level = 10, type = "boss" } } })
            spawner_system.checkBossSpawns()
            assert.is_false(spawner_system.activeWalkers[1].isElite)
        end)
    end)

    describe("game controller", function()
        local mockGroup = { insert = function() end, numChildren = 0 }
        local restoreController

        before_each(function()
            restoreController = snapshotModule(game_controller)
            game_state.initialize()
            game_controller.initialize(mockGroup)
            game_controller.start()
        end)

        after_each(function()
            game_controller.cleanup()
            restoreController()
            game_controller.onGameOverCallback = nil
            game_controller.onBossSpawnedCallback = nil
        end)

        it("wins the run when the final boss is killed", function()
            local finalStats
            game_controller.onGameOverCallback = function(stats) finalStats = stats end
            local boss = Walker:new(nil)
            boss:activate(360, 500, 360, "final_boss")
            boss:deactivate()

            game_controller.onEnemyKilled(boss)

            assert.are.equal("game_over", game_state.state)
            assert.is_true(finalStats.victoryCondition)
        end)

        it("does not end the run for a normal boss", function()
            local boss = Walker:new(nil)
            boss:activate(360, 500, 360, "boss")
            boss:deactivate()

            game_controller.onEnemyKilled(boss)

            -- The boss's XP may trigger a level-up pause, but the run goes on
            assert.are_not.equal("game_over", game_state.state)
            assert.is_false(game_state.victoryCondition)
        end)

        it("awards elite XP with the elite multiplier", function()
            local hero = game_controller.getHero()
            -- Remove the starting hero's XP bonus so only the elite multiplier applies
            hero.xpMultiplier = 1
            local elite = Walker:new(nil)
            elite:activate(360, 500, 360, "walker")
            elite:makeElite(4, 2, 5)

            game_controller.onEnemyKilled(elite)

            assert.are.equal(50, hero.xp)
        end)

        it("finds the active boss", function()
            assert.is_nil(game_controller.getActiveBoss())
            local boss = spawner_system.spawnWalker("boss", 360, true)
            assert.are.equal(boss, game_controller.getActiveBoss())
        end)

        it("passes boss spawns to the scene callback", function()
            local announced
            game_controller.onBossSpawnedCallback = function(boss) announced = boss end
            local boss = spawner_system.spawnWalker("boss", 360, true)

            spawner_system.onBossSpawned(boss)

            assert.are.equal(boss, announced)
        end)
    end)

    describe("scenes", function()
        it("shows the final boss banner text", function()
            package.loaded["src.scenes.game"] = nil
            local gameScene = require("src.scenes.game")
            gameScene:create({ name = "create" })

            gameScene.showBossBanner({ isFinalBoss = true })

            local banner
            for i = 1, gameScene.view.numChildren do
                local child = gameScene.view[i]
                if child.text == "FINAL BOSS" then banner = child end
            end
            assert.is_not_nil(banner)
            assert.is_true(banner.isVisible)
            gameScene:destroy({ name = "destroy" })
            package.loaded["src.scenes.game"] = nil
        end)

        it("titles the game over screen VICTORY! after a win", function()
            local data = require("src.models.data")
            data.startSandbox()
            local scene = composer.newScene()
            local gameover = require("src.scenes.gameover")
            scene.create, scene.show, scene.destroy = gameover.create, gameover.show, gameover.destroy

            scene:create({ name = "create" })
            scene:show({ name = "show", phase = "will", params = { victoryCondition = true, finalLevel = 20 } })

            local title
            for i = 1, scene.view.numChildren do
                local child = scene.view[i]
                if child.text == "VICTORY!" then title = child end
            end
            data.stopSandbox(false)
            scene:destroy({ name = "destroy" })
            assert.is_not_nil(title)
        end)
    end)
end)
