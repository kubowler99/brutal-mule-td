require("tests.spec_helper")

local ability_data_loader = require("src.models.ability_data_loader")
local ability_registry = require("src.models.ability_registry")
local combat_system = require("src.systems.combat_system")
local Walker = require("src.entities.walker")
local Hero = require("src.entities.hero")
local PatrolBlades = require("src.entities.abilities.patrol_blades")

describe("Patrol Blades", function()
    local WALL_Y = 1200
    local PATROL_Y = 1140  -- 60px in front of the wall line
    local blades

    local function walkerAt(x, y, health)
        local walker = Walker:new(nil)
        walker:activate(x, y, x)
        walker.health = health or 100
        walker.maxHealth = health or 100
        return walker
    end

    -- Move the blades so the first one sits at x (heading right)
    local function placeFirstBladeAt(x)
        local minX = blades:getPatrolRange()
        blades.travelled = x - minX
    end

    before_each(function()
        ability_data_loader.initialize()
        blades = PatrolBlades:new()
    end)

    after_each(function()
        combat_system.onEnemyKilled = nil
    end)

    it("loads base stats from abilities.json", function()
        assert.are.equal("patrol_blades", blades.id)
        assert.are.equal(2, blades.bladeCount)
        assert.are.equal(6, blades.damage)
        assert.are.equal(260, blades.patrolSpeed)
        assert.are.equal(24, blades.hitRadius)
    end)

    it("can be created through the ability registry", function()
        ability_registry.initialize()
        assert.is_true(ability_registry.isUnlocked("patrol_blades"))
        assert.are.equal("patrol_blades", ability_registry.createInstance("patrol_blades").id)
    end)

    it("never fires on a cooldown", function()
        assert.is_false(blades:canActivate(1000))
    end)

    describe("patrol path", function()
        it("spans the screen width minus the margins, in front of the wall", function()
            local minX, maxX = blades:getPatrolRange()
            assert.are.equal(40, minX)
            assert.are.equal(680, maxX)

            local positions = blades:getBladePositions(WALL_Y)
            for _, position in ipairs(positions) do
                assert.are.equal(PATROL_Y, position.y)
            end
        end)

        it("moves right, turns at the edge, and comes back", function()
            blades.bladeCount = 1
            local minX, maxX = blades:getPatrolRange()
            local length = maxX - minX

            blades.travelled = 100
            assert.are.equal(minX + 100, blades:getBladePositions(WALL_Y)[1].x)

            blades.travelled = length
            assert.are.equal(maxX, blades:getBladePositions(WALL_Y)[1].x)

            blades.travelled = length + 100
            assert.are.equal(maxX - 100, blades:getBladePositions(WALL_Y)[1].x)

            blades.travelled = 2 * length
            assert.are.equal(minX, blades:getBladePositions(WALL_Y)[1].x)
        end)

        it("advances by patrolSpeed per second", function()
            blades:update(0.5, 360, WALL_Y, {}, nil, nil)
            assert.are.equal(130, blades.travelled)
        end)

        it("spaces blades evenly around the round trip", function()
            local minX, maxX = blades:getPatrolRange()
            -- Two blades: one at the left end, one at the right end
            local positions = blades:getBladePositions(WALL_Y)
            assert.are.equal(minX, positions[1].x)
            assert.are.equal(maxX, positions[2].x)

            -- Four blades, a quarter of the round trip apart: left end, middle
            -- heading right, right end, middle heading left
            blades.bladeCount = 4
            local middle = (minX + maxX) / 2
            positions = blades:getBladePositions(WALL_Y)
            assert.are.equal(minX, positions[1].x)
            assert.are.equal(middle, positions[2].x)
            assert.are.equal(maxX, positions[3].x)
            assert.are.equal(middle, positions[4].x)
        end)
    end)

    describe("hits", function()
        it("damages enemies touching a blade and ignores others", function()
            placeFirstBladeAt(200)
            local touched = walkerAt(200, PATROL_Y)
            local farAhead = walkerAt(200, 600)

            blades:update(0, 360, WALL_Y, { touched, farAhead }, nil, nil)

            assert.are.equal(94, touched.health)
            assert.are.equal(100, farAhead.health)
        end)

        it("reaches enemies anywhere along the wall", function()
            local leftEdge = walkerAt(50, PATROL_Y)
            local rightEdge = walkerAt(670, PATROL_Y)

            -- One full round trip in small steps
            for _ = 1, 100 do
                blades:update(0.05, 360, WALL_Y, { leftEdge, rightEdge }, nil, nil)
            end

            assert.is_true(leftEdge.health < 100)
            assert.is_true(rightEdge.health < 100)
        end)

        it("hits the same enemy at most once per hit cooldown", function()
            blades.patrolSpeed = 0
            placeFirstBladeAt(200)
            local touched = walkerAt(200, PATROL_Y)

            blades:update(0.1, 360, WALL_Y, { touched }, nil, nil)
            blades:update(0.1, 360, WALL_Y, { touched }, nil, nil)
            assert.are.equal(94, touched.health)

            blades:update(0.4, 360, WALL_Y, { touched }, nil, nil)
            assert.are.equal(88, touched.health)
        end)

        it("scales damage by the hero damage multiplier", function()
            placeFirstBladeAt(200)
            local touched = walkerAt(200, PATROL_Y)
            blades:update(0, 360, WALL_Y, { touched }, nil, { damageMultiplier = 2 })
            assert.are.equal(88, touched.health)
        end)

        it("rewards kills through combat_system.onEnemyKilled", function()
            local killed = {}
            combat_system.onEnemyKilled = function(enemy) table.insert(killed, enemy) end
            placeFirstBladeAt(300)
            local weak = walkerAt(300, PATROL_Y, 5)

            blades:update(0, 360, WALL_Y, { weak }, nil, nil)

            assert.are.same({ weak }, killed)
        end)
    end)

    describe("visuals", function()
        it("draws one blade per blade count and removes them on destroy", function()
            local group = display.newGroup()
            blades:update(0.016, 360, WALL_Y, {}, group, nil)
            assert.are.equal(2, group.numChildren)

            blades:upgrade("blade_count")
            blades:update(0.016, 360, WALL_Y, {}, group, nil)
            assert.are.equal(3, #blades.bladeObjects)

            blades:destroy()
            assert.are.equal(0, #blades.bladeObjects)
        end)

        it("grows the drawn blades with the size upgrade", function()
            local group = display.newGroup()
            blades:upgrade("blade_size")
            blades:update(0.016, 360, WALL_Y, {}, group, nil)
            assert.are.equal(30 / 24, blades.bladeObjects[1].xScale)
        end)
    end)

    describe("upgrade", function()
        it("applies each card effect", function()
            blades:upgrade("blade_count")
            assert.are.equal(3, blades.bladeCount)

            blades:upgrade("patrol_speed")
            assert.are.equal(325, blades.patrolSpeed)

            blades:upgrade("damage_increase")
            assert.are.equal(9, blades.damage)

            blades:upgrade("blade_size")
            assert.are.equal(30, blades.hitRadius)

            assert.are.equal(5, blades.tier)
        end)

        it("caps the blade count at 6", function()
            blades.bladeCount = 6
            blades:upgrade("blade_count")
            assert.are.equal(6, blades.bladeCount)
        end)
    end)

    describe("combat system hook", function()
        it("runs every frame and patrols regardless of its slot", function()
            local hero = Hero:new(45, 1200)
            blades.patrolSpeed = 0
            placeFirstBladeAt(600)
            hero:addAbility(blades)
            local touched = walkerAt(600, PATROL_Y)
            combat_system.initialize(hero, { get = function() end }, { touched }, nil)
            combat_system.setIndicatorPositions({ { x = 120, y = 1200 } })

            combat_system.updateAbilities(0.016)

            assert.are.equal(94, touched.health)
            combat_system.cleanup()
        end)

        it("removes blade visuals when the hero is destroyed", function()
            local hero = Hero:new(45, 1200)
            hero:addAbility(blades)
            blades:update(0.016, 360, WALL_Y, {}, display.newGroup(), nil)

            hero:destroy()

            assert.are.equal(0, #blades.bladeObjects)
        end)
    end)
end)
