require("tests.spec_helper")

local ability_data_loader = require("src.models.ability_data_loader")
local ability_registry = require("src.models.ability_registry")
local game_controller = require("src.controllers.game_controller")
local collision_system = require("src.systems.collision_system")
local Walker = require("src.entities.walker")
local Projectile = require("src.entities.projectile")
local FrostShard = require("src.entities.abilities.frost_shard")

describe("Frost Shard", function()
    local shard

    local function capturePool()
        local pool = { fired = {} }
        function pool:get()
            local projectile = Projectile:new(nil)
            table.insert(self.fired, projectile)
            return projectile
        end
        function pool:release() end
        return pool
    end

    before_each(function()
        ability_data_loader.initialize()
        shard = FrostShard:new()
    end)

    it("loads base stats from abilities.json", function()
        assert.are.equal("frost_shard", shard.id)
        assert.are.equal(1.2, shard.cooldown)
        assert.are.equal(7, shard.damage)
        assert.are.equal(1, shard.pierceCount)
        assert.are.equal(0.7, shard.slowFactor)
        assert.are.equal(1.5, shard.slowDuration)
    end)

    it("can be created through the ability registry", function()
        ability_registry.initialize()
        assert.are.equal("frost_shard", ability_registry.createInstance("frost_shard").id)
    end)

    it("fires piercing shards that carry the slow", function()
        local pool = capturePool()
        shard:canActivate(10)

        assert.is_true(shard:activate(45, 1200, { { x = 360, y = 500, isActive = true } }, pool))

        assert.are.equal(1, #pool.fired)
        local projectile = pool.fired[1]
        assert.are.equal(7, projectile.damage)
        assert.are.equal(1, projectile.pierceCount)
        assert.are.equal(0.7, projectile.slowFactor)
        assert.are.equal(1.5, projectile.slowDuration)
    end)

    it("clears the slow when a pooled projectile is reused by another ability", function()
        local projectile = Projectile:new(nil)
        projectile:activate(0, 0, 10, 10, 100, 5, 0)
        projectile.slowFactor = 0.5
        projectile:activate(0, 0, 10, 10, 100, 5, 0)
        assert.is_nil(projectile.slowFactor)
    end)

    it("slows enemies it hits in the game loop", function()
        local restore = snapshotModule(collision_system)
        game_controller.initialize({ insert = function() end, numChildren = 0 })
        game_controller.start()

        local walker = Walker:new(nil)
        walker:activate(360, 300, 360)
        walker.health = 100
        local projectile = Projectile:new(nil)
        projectile:activate(360, 1200, 360, 300, 900, 7, 1)
        projectile.slowFactor = 0.7
        projectile.slowDuration = 1.5
        collision_system.checkProjectileCollisions = function()
            return { { projectile = projectile, enemy = walker } }
        end

        game_controller.update({ time = 16 })

        restore()
        game_controller.cleanup()
        assert.are.equal(93, walker.health)
        assert.are.equal(0.7, walker.slowFactor)
        assert.are.equal(1.5, walker.slowRemaining)
    end)

    describe("upgrade", function()
        it("applies each card effect", function()
            shard:upgrade("damage_increase")
            assert.are.equal(11, shard.damage)
            shard:upgrade("shard_count")
            assert.are.equal(2, shard.projectileCount)
            shard:upgrade("pierce")
            assert.are.equal(2, shard.pierceCount)
            shard:upgrade("slow_increase")
            assert.is_true(math.abs(shard.slowFactor - 0.6) < 1e-9)
            assert.are.equal(5, shard.tier)
        end)

        it("never slows below the minimum factor", function()
            shard.slowFactor = 0.35
            shard:upgrade("slow_increase")
            assert.are.equal(0.3, shard.slowFactor)
        end)
    end)
end)
