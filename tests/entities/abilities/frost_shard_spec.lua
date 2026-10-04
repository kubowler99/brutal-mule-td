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
        assert.are.equal("frost_shard", projectile.visual)
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

    describe("fan", function()
        local function angleTo(aim)
            return math.atan2(aim.y - 1200, aim.x - 360)
        end

        it("fires a single shard straight at the target", function()
            local aims = shard:getAimPoints(360, 1200, { { x = 360, y = 500, isActive = true } })
            assert.are.equal(1, #aims)
            assert.is_true(math.abs(aims[1].x - 360) < 1e-9)
            assert.is_true(math.abs(aims[1].y - 500) < 1e-9)
        end)

        it("spreads extra shards 12 degrees apart, centered on the target", function()
            shard.projectileCount = 3
            local aims = shard:getAimPoints(360, 1200, { { x = 360, y = 500, isActive = true } })

            assert.are.equal(3, #aims)
            local straightUp = math.atan2(-700, 0)
            assert.is_true(math.abs(angleTo(aims[2]) - straightUp) < 1e-9)
            assert.is_true(math.abs(angleTo(aims[1]) - (straightUp - math.rad(12))) < 1e-9)
            assert.is_true(math.abs(angleTo(aims[3]) - (straightUp + math.rad(12))) < 1e-9)
        end)

        it("centers an even count between the two middle shards", function()
            shard.projectileCount = 2
            local aims = shard:getAimPoints(360, 1200, { { x = 360, y = 500, isActive = true } })
            local straightUp = math.atan2(-700, 0)
            assert.is_true(math.abs(angleTo(aims[1]) - (straightUp - math.rad(6))) < 1e-9)
            assert.is_true(math.abs(angleTo(aims[2]) - (straightUp + math.rad(6))) < 1e-9)
        end)

        it("lowers each shard's damage 20% per extra shard", function()
            shard.projectileCount = 2
            local pool = capturePool()
            shard:canActivate(10)
            shard:activate(360, 1200, { { x = 360, y = 500, isActive = true } }, pool)
            for _, projectile in ipairs(pool.fired) do
                assert.is_true(math.abs(projectile.damage - 7 * 0.8) < 1e-9)
            end
        end)

        it("fires a fan even with a single enemy", function()
            shard.projectileCount = 3
            local pool = capturePool()
            shard:canActivate(10)
            shard:activate(360, 1200, { { x = 360, y = 500, isActive = true } }, pool)
            assert.are.equal(3, #pool.fired)
            assert.is_true(pool.fired[1].vx < 0 and pool.fired[3].vx > 0)
        end)
    end)

    describe("ricochet", function()
        it("turns a spent projectile into a ricochet instead of stopping it", function()
            local projectile = Projectile:new(nil)
            projectile:activate(0, 0, 0, -100, 900, 7, 0)
            projectile.ricochetsLeft = 1

            projectile:onHit({ x = 0, y = -50 })

            assert.is_true(projectile.isActive)
            assert.is_true(projectile.needsRicochet)
            assert.are.equal(0, projectile.ricochetsLeft)
        end)

        it("redirects toward the nearest enemy it has not hit, at the same speed", function()
            local first = { x = 360, y = 500, isActive = true }
            local near = { x = 420, y = 500, isActive = true }
            local far = { x = 360, y = 100, isActive = true }
            local projectile = Projectile:new(nil)
            projectile:activate(360, 600, 360, 500, 900, 7, 0)
            projectile.x, projectile.y = 360, 500
            projectile.ricochetsLeft = 1
            projectile:onHit(first)

            game_controller.ricochet(projectile, { first, near, far })

            assert.is_true(projectile.isActive)
            assert.is_false(projectile.needsRicochet)
            assert.is_true(math.abs(projectile.vx - 900) < 1e-6)
            assert.is_true(math.abs(projectile.vy) < 1e-6)
        end)

        it("stops when no unhit enemy is in range", function()
            local first = { x = 360, y = 500, isActive = true }
            local tooFar = { x = 360, y = 0, isActive = true }
            local projectile = Projectile:new(nil)
            projectile:activate(360, 600, 360, 500, 900, 7, 0)
            projectile.x, projectile.y = 360, 500
            projectile.ricochetsLeft = 1
            projectile:onHit(first)

            game_controller.ricochet(projectile, { first, tooFar })

            assert.is_false(projectile.isActive)
        end)

        it("gives fired shards the ricochet count and freeze chance from upgrades", function()
            shard:upgrade("ricochet")
            shard:upgrade("freeze_chance")
            local pool = capturePool()
            shard:canActivate(10)
            shard:activate(45, 1200, { { x = 360, y = 500, isActive = true } }, pool)

            local projectile = pool.fired[1]
            assert.are.equal(1, projectile.ricochetsLeft)
            assert.is_true(math.abs(projectile.freezeChance - 0.15) < 1e-9)
            assert.are.equal(0.8, projectile.freezeDuration)
        end)

        it("caps ricochets at 3 and freeze chance at 60%", function()
            for _ = 1, 5 do
                shard:upgrade("ricochet")
                shard:upgrade("freeze_chance")
            end
            assert.are.equal(3, shard.ricochets)
            assert.are.equal(0.6, shard.freezeChance)
        end)

        it("clears ricochets and freeze when a pooled projectile is reused", function()
            local projectile = Projectile:new(nil)
            projectile:activate(0, 0, 10, 10, 100, 5, 0)
            projectile.ricochetsLeft = 2
            projectile.freezeChance = 0.5
            projectile:activate(0, 0, 10, 10, 100, 5, 0)
            assert.are.equal(0, projectile.ricochetsLeft)
            assert.is_nil(projectile.freezeChance)
        end)
    end)

    describe("freeze", function()
        it("stops an enemy hit by a freezing shard", function()
            local restore = snapshotModule(collision_system)
            local originalRandom = math.random
            game_controller.initialize({ insert = function() end, numChildren = 0 })
            game_controller.start()

            local walker = Walker:new(nil)
            walker:activate(360, 300, 360)
            walker.health = 100
            local projectile = Projectile:new(nil)
            projectile:activate(360, 1200, 360, 300, 900, 7, 1)
            projectile.freezeChance = 0.5
            projectile.freezeDuration = 0.8
            collision_system.checkProjectileCollisions = function()
                return { { projectile = projectile, enemy = walker } }
            end
            math.random = function(...)
                if select("#", ...) == 0 then return 0.1 end
                return originalRandom(...)
            end

            game_controller.update({ time = 16 })

            math.random = originalRandom
            restore()
            game_controller.cleanup()
            assert.are.equal(0, walker:getCurrentSpeed())
            assert.are.equal(0.8, walker.slowRemaining)
        end)
    end)
end)
