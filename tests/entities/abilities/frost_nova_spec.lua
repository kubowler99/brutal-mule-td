require("tests.spec_helper")

local ability_data_loader = require("src.models.ability_data_loader")
local ability_registry = require("src.models.ability_registry")
local combat_system = require("src.systems.combat_system")
local Walker = require("src.entities.walker")
local FrostNova = require("src.entities.abilities.frost_nova")

describe("FrostNova Ability", function()
    local WALL_Y = 1200
    local nova

    local function newWalker(y, health)
        local walker = Walker:new(nil)
        walker:activate(360, y, 360)
        if health then
            walker.health = health
            walker.maxHealth = health
        end
        return walker
    end

    before_each(function()
        ability_data_loader.initialize()
        nova = FrostNova:new()
        combat_system.onEnemyKilled = nil
    end)

    after_each(function()
        combat_system.onEnemyKilled = nil
    end)

    describe("initialization", function()
        it("loads base stats from abilities.json", function()
            assert.are.equal("frost_nova", nova.id)
            assert.are.equal(4.0, nova.cooldown)
            assert.are.equal(8, nova.damage)
            assert.are.equal(250, nova.range)
            assert.are.equal(0.5, nova.slowFactor)
            assert.are.equal(2.0, nova.slowDuration)
            assert.are.equal(1, nova.tier)
        end)

        it("falls back to defaults without data", function()
            ability_data_loader._data = nil
            local fallback = FrostNova:new()
            assert.are.equal(4.0, fallback.cooldown)
            assert.are.equal(250, fallback.range)
        end)

        it("can be created through the ability registry", function()
            ability_registry.initialize()
            assert.is_true(ability_registry.isUnlocked("frost_nova"))
            local instance = ability_registry.createInstance("frost_nova")
            assert.is_not_nil(instance)
            assert.are.equal("frost_nova", instance.id)
        end)
    end)

    describe("findTargets", function()
        it("only targets active enemies within range of the wall", function()
            local near = newWalker(WALL_Y - 100)
            local edge = newWalker(WALL_Y - 250)
            local far = newWalker(WALL_Y - 251)
            local dead = newWalker(WALL_Y - 50)
            dead:deactivate()

            local targets = nova:findTargets(WALL_Y, {near, edge, far, dead})

            assert.are.equal(2, #targets)
            assert.are.equal(near, targets[1])
            assert.are.equal(edge, targets[2])
        end)
    end)

    describe("activate", function()
        it("damages and slows every enemy in range", function()
            local first = newWalker(WALL_Y - 60, 30)
            local second = newWalker(WALL_Y - 200, 30)
            local far = newWalker(100, 30)

            nova:canActivate(10)
            assert.is_true(nova:activate(45, WALL_Y, {first, second, far}, nil, nil))

            assert.are.equal(22, first.health)
            assert.are.equal(22, second.health)
            assert.are.equal(30, far.health)
            assert.are.equal(first.speed * 0.5, first:getCurrentSpeed())
            assert.are.equal(far.speed, far:getCurrentSpeed())
            assert.are.equal(10, nova.lastActivation)
        end)

        it("does not fire or use its cooldown when nothing is in range", function()
            local far = newWalker(100, 30)

            nova:canActivate(10)
            assert.is_false(nova:activate(45, WALL_Y, {far}, nil, nil))
            assert.are.equal(0, nova.lastActivation)
        end)

        it("rewards kills through combat_system.onEnemyKilled", function()
            local killed = {}
            combat_system.onEnemyKilled = function(enemy)
                table.insert(killed, enemy)
            end
            local weak = newWalker(WALL_Y - 60, 5)
            local strong = newWalker(WALL_Y - 60, 50)

            nova:canActivate(10)
            nova:activate(45, WALL_Y, {weak, strong}, nil, nil)

            assert.are.same({weak}, killed)
            assert.is_false(weak.isActive)
        end)

        it("draws a pulse into the display group when one is given", function()
            local group = display.newGroup()
            nova:canActivate(10)
            nova:activate(45, WALL_Y, {newWalker(WALL_Y - 60, 30)}, nil, group)
            assert.are.equal(1, group.numChildren)
        end)
    end)

    describe("upgrade", function()
        it("applies only the card effect for each upgrade", function()
            nova:upgrade("damage_increase")
            assert.are.equal(12, nova.damage)
            assert.are.equal(250, nova.range)

            nova:upgrade("range_increase")
            assert.are.equal(300, nova.range)

            nova:upgrade("attack_speed")
            assert.are.equal(3.5, nova.cooldown)

            nova:upgrade("slow_increase")
            assert.is_true(math.abs(nova.slowFactor - 0.4) < 1e-9)

            assert.are.equal(5, nova.tier)
        end)

        it("respects the minimum cooldown and slow factor", function()
            nova.cooldown = 1.6
            nova:upgrade("attack_speed")
            assert.are.equal(1.5, nova.cooldown)

            nova.slowFactor = 0.25
            nova:upgrade("slow_increase")
            assert.are.equal(0.2, nova.slowFactor)
        end)

        it("does not exceed tier 5", function()
            nova.tier = 5
            nova:upgrade("damage_increase")
            assert.are.equal(5, nova.tier)
        end)
    end)
end)
