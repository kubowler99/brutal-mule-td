require("tests.spec_helper")

local ability_data_loader = require("src.models.ability_data_loader")
local ability_registry = require("src.models.ability_registry")
local combat_system = require("src.systems.combat_system")
local Walker = require("src.entities.walker")
local Hero = require("src.entities.hero")
local OrbitingBlades = require("src.entities.abilities.orbiting_blades")

describe("Orbiting Blades", function()
    local ORIGIN_X, ORIGIN_Y = 360, 1200
    local blades

    local function walkerAt(x, y, health)
        local walker = Walker:new(nil)
        walker:activate(x, y, x)
        walker.health = health or 100
        walker.maxHealth = health or 100
        return walker
    end

    before_each(function()
        ability_data_loader.initialize()
        blades = OrbitingBlades:new()
        -- Freeze rotation so blade positions are predictable
        blades.rotationSpeed = 0
    end)

    after_each(function()
        combat_system.onEnemyKilled = nil
    end)

    it("loads base stats from abilities.json", function()
        local fresh = OrbitingBlades:new()
        assert.are.equal(2, fresh.bladeCount)
        assert.are.equal(6, fresh.damage)
        assert.are.equal(80, fresh.orbitRadius)
        assert.are.equal(2.5, fresh.rotationSpeed)
    end)

    it("can be created through the ability registry", function()
        ability_registry.initialize()
        assert.is_true(ability_registry.isUnlocked("orbiting_blades"))
        assert.are.equal("orbiting_blades", ability_registry.createInstance("orbiting_blades").id)
    end)

    it("never fires on a cooldown", function()
        assert.is_false(blades:canActivate(1000))
    end)

    it("spaces blades evenly around the origin", function()
        local positions = blades:getBladePositions(ORIGIN_X, ORIGIN_Y)
        assert.are.equal(2, #positions)
        -- angle 0 and pi: right of and left of the origin
        assert.is_true(math.abs(positions[1].x - (ORIGIN_X + 80)) < 1e-9)
        assert.is_true(math.abs(positions[2].x - (ORIGIN_X - 80)) < 1e-9)
    end)

    it("rotates by rotationSpeed per second", function()
        blades.rotationSpeed = math.pi / 2
        blades:update(1.0, ORIGIN_X, ORIGIN_Y, {}, nil, nil)
        local positions = blades:getBladePositions(ORIGIN_X, ORIGIN_Y)
        -- After a quarter turn the first blade sits below the origin
        assert.is_true(math.abs(positions[1].x - ORIGIN_X) < 1e-9)
        assert.is_true(math.abs(positions[1].y - (ORIGIN_Y + 80)) < 1e-9)
    end)

    it("damages enemies touching a blade and ignores others", function()
        local touched = walkerAt(ORIGIN_X + 80, ORIGIN_Y)
        local far = walkerAt(ORIGIN_X, ORIGIN_Y - 300)

        blades:update(0.016, ORIGIN_X, ORIGIN_Y, { touched, far }, nil, nil)

        assert.are.equal(94, touched.health)
        assert.are.equal(100, far.health)
    end)

    it("hits the same enemy at most once per hit cooldown", function()
        local touched = walkerAt(ORIGIN_X + 80, ORIGIN_Y)

        blades:update(0.1, ORIGIN_X, ORIGIN_Y, { touched }, nil, nil)
        blades:update(0.1, ORIGIN_X, ORIGIN_Y, { touched }, nil, nil)
        assert.are.equal(94, touched.health)

        blades:update(0.4, ORIGIN_X, ORIGIN_Y, { touched }, nil, nil)
        assert.are.equal(88, touched.health)
    end)

    it("scales damage by the hero damage multiplier", function()
        local touched = walkerAt(ORIGIN_X + 80, ORIGIN_Y)
        blades:update(0.016, ORIGIN_X, ORIGIN_Y, { touched }, nil, { damageMultiplier = 2 })
        assert.are.equal(88, touched.health)
    end)

    it("rewards kills through combat_system.onEnemyKilled", function()
        local killed = {}
        combat_system.onEnemyKilled = function(enemy) table.insert(killed, enemy) end
        local weak = walkerAt(ORIGIN_X - 80, ORIGIN_Y, 5)

        blades:update(0.016, ORIGIN_X, ORIGIN_Y, { weak }, nil, nil)

        assert.are.same({ weak }, killed)
    end)

    it("draws one blade per blade count and removes them on destroy", function()
        local group = display.newGroup()
        blades:update(0.016, ORIGIN_X, ORIGIN_Y, {}, group, nil)
        assert.are.equal(2, group.numChildren)

        blades:upgrade("blade_count")
        blades:update(0.016, ORIGIN_X, ORIGIN_Y, {}, group, nil)
        assert.are.equal(3, #blades.bladeObjects)

        blades:destroy()
        assert.are.equal(0, #blades.bladeObjects)
    end)

    describe("upgrade", function()
        it("applies each card effect", function()
            blades:upgrade("blade_count")
            assert.are.equal(3, blades.bladeCount)

            blades.rotationSpeed = 2
            blades:upgrade("rotation_speed")
            assert.are.equal(2.5, blades.rotationSpeed)

            blades:upgrade("damage_increase")
            assert.are.equal(9, blades.damage)

            blades:upgrade("blade_size")
            assert.are.equal(24, blades.hitRadius)

            assert.are.equal(5, blades.tier)
        end)

        it("caps the blade count at 6", function()
            blades.bladeCount = 6
            blades:upgrade("blade_count")
            assert.are.equal(6, blades.bladeCount)
        end)
    end)

    describe("combat system hook", function()
        it("updates blades every frame from the ability's slot", function()
            local hero = Hero:new(45, 1200)
            blades.rotationSpeed = 0
            hero:addAbility(blades)
            local touched = walkerAt(120 + 80, 1200)
            combat_system.initialize(hero, { get = function() end }, { touched }, nil)
            combat_system.setIndicatorPositions({ { x = 120, y = 1200 } })

            combat_system.updateAbilities(0.016)

            assert.are.equal(94, touched.health)
            combat_system.cleanup()
        end)

        it("removes blade visuals when the hero is destroyed", function()
            local hero = Hero:new(45, 1200)
            hero:addAbility(blades)
            blades:update(0.016, ORIGIN_X, ORIGIN_Y, {}, display.newGroup(), nil)

            hero:destroy()

            assert.are.equal(0, #blades.bladeObjects)
        end)
    end)
end)
