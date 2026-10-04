require("tests.spec_helper")

local ability_data_loader = require("src.models.ability_data_loader")
local ability_registry = require("src.models.ability_registry")
local combat_system = require("src.systems.combat_system")
local game_controller = require("src.controllers.game_controller")
local data = require("src.models.data")
local Hero = require("src.entities.hero")
local Walker = require("src.entities.walker")
local FlameSlash = require("src.entities.abilities.flame_slash")

describe("Flame Slash and burn", function()
    local ORIGIN_X, ORIGIN_Y = 360, 1200
    local slash

    local function walkerAt(x, y, health)
        local walker = Walker:new(nil)
        walker:activate(x, y, x)
        walker.health = health or 100
        walker.maxHealth = health or 100
        return walker
    end

    before_each(function()
        ability_data_loader.initialize()
        slash = FlameSlash:new()
    end)

    after_each(function()
        combat_system.onEnemyKilled = nil
    end)

    describe("Flame Slash", function()
        it("loads base stats from abilities.json", function()
            assert.are.equal(1.5, slash.cooldown)
            assert.are.equal(14, slash.damage)
            assert.are.equal(220, slash.range)
            assert.are.equal(0, slash.burnDps)
        end)

        it("can be created through the ability registry", function()
            ability_registry.initialize()
            assert.are.equal("flame_slash", ability_registry.createInstance("flame_slash").id)
        end)

        it("damages every enemy in range and nothing beyond it", function()
            local close = walkerAt(ORIGIN_X, ORIGIN_Y - 100)
            local edge = walkerAt(ORIGIN_X + 220, ORIGIN_Y)
            local far = walkerAt(ORIGIN_X, ORIGIN_Y - 300)

            slash:canActivate(10)
            assert.is_true(slash:activate(ORIGIN_X, ORIGIN_Y, { close, edge, far }))

            assert.are.equal(86, close.health)
            assert.are.equal(86, edge.health)
            assert.are.equal(100, far.health)
            assert.are.equal(10, slash.lastActivation)
        end)

        it("does not use its cooldown when nothing is in range", function()
            slash:canActivate(10)
            assert.is_false(slash:activate(ORIGIN_X, ORIGIN_Y, { walkerAt(ORIGIN_X, 100) }))
            assert.are.equal(0, slash.lastActivation)
        end)

        it("sets enemies on fire once the burn upgrade is taken", function()
            slash:upgrade("burn")
            local target = walkerAt(ORIGIN_X, ORIGIN_Y - 100)

            slash:canActivate(10)
            slash:activate(ORIGIN_X, ORIGIN_Y, { target })

            assert.are.equal(4, target.burnDps)
            assert.are.equal(3, target.burnRemaining)
        end)

        it("applies each upgrade", function()
            slash:upgrade("damage_increase")
            assert.are.equal(20, slash.damage)
            slash:upgrade("range_increase")
            assert.are.equal(260, slash.range)
            slash:upgrade("attack_speed")
            assert.is_true(math.abs(slash.cooldown - 1.3) < 1e-9)
            slash:upgrade("burn")
            assert.are.equal(4, slash.burnDps)
            assert.are.equal(5, slash.tier)
        end)
    end)

    describe("burn", function()
        it("collects damage in 0.5s ticks for the burn duration", function()
            local walker = walkerAt(300, 0)
            walker:applyBurn(4, 1.0)

            walker:update(0.4, 1140)
            assert.are.equal(0, walker:takePendingBurnDamage())

            walker:update(0.1, 1140)
            assert.are.equal(2, walker:takePendingBurnDamage())

            walker:update(1.0, 1140)
            assert.are.equal(2, walker:takePendingBurnDamage())
            assert.are.equal(0, walker.burnRemaining)
        end)

        it("keeps the strongest burn and the longest duration", function()
            local walker = walkerAt(300, 0)
            walker:applyBurn(6, 1)
            walker:applyBurn(2, 4)
            assert.are.equal(6, walker.burnDps)
            assert.are.equal(4, walker.burnRemaining)
        end)

        it("is cleared when the enemy is reused from the pool", function()
            local walker = walkerAt(300, 0)
            walker:applyBurn(6, 3)
            walker:deactivate()
            walker:activate(300, 0, 300)
            assert.are.equal(0, walker.burnRemaining)
            assert.are.equal(0, walker.burnDps)
        end)

        it("deals burn damage in the game loop and rewards burn kills", function()
            data.startSandbox()
            game_controller.initialize({ insert = function() end, numChildren = 0 })
            local killed = {}
            local originalKilled = combat_system.onEnemyKilled
            combat_system.onEnemyKilled = function(enemy) table.insert(killed, enemy) end

            local walker = require("src.systems.spawner_system").spawnWalker("walker", 300)
            walker.health = 3
            walker:applyBurn(10, 2)

            game_controller.update({ time = 0 })
            game_controller.update({ time = 100 })
            for i = 1, 6 do
                game_controller.update({ time = 100 + i * 100 })
            end

            combat_system.onEnemyKilled = originalKilled
            game_controller.cleanup()
            data.stopSandbox(false)
            assert.is_false(walker.isActive)
            assert.are.same({ walker }, killed)
        end)
    end)

    describe("Ember Knight", function()
        it("gets +20% damage only while the wall is below half health", function()
            local hero = Hero:new(45, 1200)
            hero.baseStats.lowWallDamageBonus = 0.2

            hero.wallHealthRatio = 0.6
            assert.are.equal(1, hero:getStats().damageMultiplier)

            hero.wallHealthRatio = 0.4
            assert.is_true(math.abs(hero:getStats().damageMultiplier - 1.2) < 1e-9)
        end)

        it("starts with Flame Slash and the low-wall bonus", function()
            data.startSandbox()
            game_controller.initialize({ insert = function() end, numChildren = 0 }, "ember_knight")
            local hero = game_controller.getHero()

            assert.are.equal("flame_slash", hero.abilities[1].id)
            assert.are.equal(0.2, hero.baseStats.lowWallDamageBonus)

            game_controller.cleanup()
            data.stopSandbox(false)
        end)

        it("tracks the wall health ratio every frame", function()
            data.startSandbox()
            game_controller.initialize({ insert = function() end, numChildren = 0 }, "ember_knight")
            game_controller.start()
            local wall = game_controller.getWall()
            wall.health = wall.maxHealth / 4

            game_controller.update({ time = 16 })

            assert.are.equal(0.25, game_controller.getHero().wallHealthRatio)
            game_controller.cleanup()
            data.stopSandbox(false)
        end)
    end)
end)
