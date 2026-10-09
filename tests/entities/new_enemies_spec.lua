-- Tests for the expansion enemies: shielder, frost golem, bomber, splitter,
-- wraith, necromancer, and burrower

require("tests.spec_helper")

local Walker = require("src.entities.walker")
local spawner_system = require("src.systems.spawner_system")
local collision_system = require("src.systems.collision_system")
local experience_system = require("src.systems.experience_system")
local game_controller = require("src.controllers.game_controller")
local pool = require("src.utils.pool")

local WALL_STOP_Y = 1140

local function spawn(enemyType, x, y)
    local enemy = Walker:new(nil)
    enemy:activate(x or 100, y or 0, x or 100, enemyType)
    return enemy
end

describe("New enemies", function()
    describe("stats from enemies.json", function()
        local expected = {
            shielder = { health = 30, speed = 60, xp = 12 },
            frost_golem = { health = 120, speed = 35, xp = 30 },
            bomber = { health = 12, speed = 140, xp = 10 },
            splitter = { health = 40, speed = 70, xp = 15 },
            splitling = { health = 8, speed = 110, xp = 3 },
            wraith = { health = 25, speed = 90, xp = 14 },
            necromancer = { health = 35, speed = 50, xp = 25 },
            burrower = { health = 30, speed = 120, xp = 18 },
        }
        for enemyType, stats in pairs(expected) do
            it("loads " .. enemyType, function()
                local enemy = spawn(enemyType)
                assert.are.equal(stats.health, enemy.maxHealth)
                assert.are.equal(stats.speed, enemy.speed)
                experience_system.initialize({ xp = 0, level = 1 }, function() end)
                assert.are.equal(stats.xp, experience_system.getEnemyXPValue(enemyType))
                experience_system.cleanup()
            end)
        end

        it("keeps the old types free of new behaviors", function()
            local walker = spawn("walker")
            assert.is_false(walker.hasShield)
            assert.is_false(walker.slowImmune)
            assert.are.equal(0, walker.explodeDamage)
            assert.is_nil(walker.splitInto)
            assert.is_false(walker:isUntargetable())
        end)
    end)

    describe("frost golem", function()
        it("ignores slows and freezes", function()
            local golem = spawn("frost_golem")
            golem:applySlow(0, 5)
            assert.are.equal(0, golem.slowRemaining)
            assert.are.equal(35, golem:getCurrentSpeed())
        end)
    end)

    describe("wraith", function()
        it("phases out for 1.5s at the end of every 4s and cannot be hurt then", function()
            local wraith = spawn("wraith")
            wraith:update(2.4, WALL_STOP_Y)
            assert.is_false(wraith:isUntargetable())
            wraith:update(0.2, WALL_STOP_Y)
            assert.is_true(wraith:isUntargetable())
            wraith:takeDamage(100)
            assert.is_true(wraith.isActive)
            assert.are.equal(25, wraith.health)
            assert.are.equal(0.35, wraith.displayObject.alpha)

            wraith:update(1.5, WALL_STOP_Y)
            assert.is_false(wraith:isUntargetable())
            wraith:takeDamage(10)
            assert.are.equal(15, wraith.health)
        end)

        it("lets projectiles pass through while phased", function()
            local wraith = spawn("wraith", 100, 500)
            wraith.isPhased = true
            local projectile = { isActive = true, x = 100, y = 500 }
            assert.are.equal(0, #collision_system.checkProjectileCollisions({ projectile }, { wraith }))
            wraith.isPhased = false
            assert.are.equal(1, #collision_system.checkProjectileCollisions({ projectile }, { wraith }))
        end)
    end)

    describe("burrower", function()
        it("is underground until 160px short of the wall", function()
            local burrower = spawn("burrower", 100, 0)
            assert.is_true(burrower:isUntargetable())
            burrower.y = WALL_STOP_Y - 200
            burrower:update(0.01, WALL_STOP_Y)
            assert.is_true(burrower:isUntargetable())
            burrower.y = WALL_STOP_Y - 150
            burrower:update(0.01, WALL_STOP_Y)
            assert.is_false(burrower:isUntargetable())
        end)

        it("starts underground again when reused from the pool", function()
            local burrower = spawn("burrower", 100, 1100)
            burrower:update(0.01, WALL_STOP_Y)
            burrower:deactivate()
            burrower:activate(100, 0, 100, "burrower")
            assert.is_true(burrower:isUntargetable())
        end)
    end)

    describe("necromancer", function()
        it("stays at range and raises 2 walkers every 6s", function()
            local walkerPool = pool.new(function() return Walker:new(nil) end)
            spawner_system.initialize(walkerPool, 1)
            local necromancer = spawner_system.spawnWalker("necromancer", 300, true, { noElite = true })
            assert.are.equal(320, necromancer.attackRange)

            necromancer:update(6, WALL_STOP_Y)
            assert.are.equal(2, necromancer.pendingSummons)
            spawner_system.spawnSummons()
            local raised = 0
            for _, enemy in ipairs(spawner_system.getActiveWalkers()) do
                if enemy ~= necromancer and enemy.type == "walker" then raised = raised + 1 end
            end
            assert.are.equal(2, raised)
            spawner_system.cleanup()
        end)
    end)

    describe("splitter", function()
        it("splits into 2 splitlings beside it when killed", function()
            local walkerPool = pool.new(function() return Walker:new(nil) end)
            spawner_system.initialize(walkerPool, 1)
            local splitter = spawner_system.spawnWalker("splitter", 300, true, { noElite = true })
            splitter.y = 600
            splitter:takeDamage(999)
            spawner_system.spawnSplit(splitter)

            local splitlings = {}
            for _, enemy in ipairs(spawner_system.getActiveWalkers()) do
                if enemy.isActive and enemy.type == "splitling" then table.insert(splitlings, enemy) end
            end
            assert.are.equal(2, #splitlings)
            assert.are.equal(600, splitlings[1].y)
            assert.is_nil(splitlings[1].splitInto)
            spawner_system.cleanup()
        end)
    end)

    describe("in the game loop", function()
        local sceneGroup

        before_each(function()
            sceneGroup = display.newGroup()
            game_controller.initialize(sceneGroup)
            game_controller.start()
            -- No hero abilities, so only the test's projectiles hit
            game_controller.getHero().abilities = {}
        end)

        after_each(function()
            game_controller.cleanup()
        end)

        local function frame(time)
            game_controller.update({ time = time })
        end

        it("blocks plain projectiles with a shield", function()
            local shielder = spawner_system.spawnWalker("shielder", 360, true, { y = 500, noElite = true })
            local projectile = require("src.entities.projectile"):new(nil)
            projectile:activate(360, 520, 360, 0, 1, 10, 0)
            table.insert(require("src.systems.combat_system").getActiveProjectiles(), projectile)
            frame(0)
            frame(16)
            assert.are.equal(30, shielder.health)
            assert.is_false(projectile.isActive)
            assert.is_false(shielder.shieldBroken)
        end)

        it("breaks the shield with a piercing projectile, then takes damage", function()
            local shielder = spawner_system.spawnWalker("shielder", 360, true, { y = 500, noElite = true })
            local Projectile = require("src.entities.projectile")
            local combat_system = require("src.systems.combat_system")
            local first = Projectile:new(nil)
            first:activate(360, 520, 360, 0, 1, 10, 1)
            table.insert(combat_system.getActiveProjectiles(), first)
            frame(0)
            frame(16)
            assert.is_true(shielder.shieldBroken)
            assert.are.equal(30, shielder.health)

            -- The first projectile still overlaps but already hit the shielder
            frame(24)
            assert.are.equal(30, shielder.health)

            local second = Projectile:new(nil)
            second:activate(360, shielder.y + 5, 360, 0, 1, 10, 0)
            table.insert(combat_system.getActiveProjectiles(), second)
            frame(40)
            assert.are.equal(20, shielder.health)
        end)

        it("hits an enemy once even while a piercing projectile still overlaps it", function()
            local walker = spawner_system.spawnWalker("brute", 360, true, { y = 500, noElite = true })
            local projectile = require("src.entities.projectile"):new(nil)
            projectile:activate(360, 505, 360, 0, 1, 10, 2)
            table.insert(require("src.systems.combat_system").getActiveProjectiles(), projectile)
            frame(0)
            frame(16)
            frame(32)
            assert.are.equal(walker.maxHealth - 10, walker.health)
        end)

        it("explodes bombers at the wall without a kill reward", function()
            local wall = game_controller.getWall()
            local before = wall.health
            local game_state = require("src.models.game_state")
            local kills = game_state.enemiesDefeated
            local bomber = spawner_system.spawnWalker("bomber", 360, true, { y = WALL_STOP_Y, noElite = true })
            frame(0)
            frame(16)
            assert.is_false(bomber.isActive)
            assert.are.equal(before - 25, wall.health)
            assert.are.equal(kills, game_state.enemiesDefeated)
        end)

        it("spawns splitlings when a splitter dies in the game", function()
            local splitter = spawner_system.spawnWalker("splitter", 360, true, { y = 500, noElite = true })
            require("src.systems.combat_system").applyDamage(splitter, 999)
            local splitlings = 0
            for _, enemy in ipairs(spawner_system.getActiveWalkers()) do
                if enemy.isActive and enemy.type == "splitling" then splitlings = splitlings + 1 end
            end
            assert.are.equal(2, splitlings)
        end)
    end)

    describe("display", function()
        it("moves the sprite and health bar when an enemy is moved sideways", function()
            local enemy = spawn("walker", 100, 100)
            enemy.x = 250
            enemy:update(0.01, WALL_STOP_Y)
            assert.are.equal(250, enemy.displayObject.x)
            assert.are.equal(250, enemy.healthBar.background.x)
            assert.are.equal(250 - 15, enemy.healthBar.foreground.x)
        end)
    end)
end)
