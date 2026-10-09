-- Tests for the expansion abilities: Chain Lightning, Meteor, Poison Cloud,
-- Spirit Turret, Keen Eye, and Mending Wards

require("tests.spec_helper")

local ability_data_loader = require("src.models.ability_data_loader")
local ability_registry = require("src.models.ability_registry")
local combat_system = require("src.systems.combat_system")
local card_powers = require("src.systems.card_powers")
local Walker = require("src.entities.walker")
local Hero = require("src.entities.hero")
local ChainLightning = require("src.entities.abilities.chain_lightning")
local Meteor = require("src.entities.abilities.meteor")
local PoisonCloud = require("src.entities.abilities.poison_cloud")
local SpiritTurret = require("src.entities.abilities.spirit_turret")

local WALL_Y = 1200

local function newEnemy(x, y, health)
    local enemy = Walker:new(nil)
    enemy:activate(x, y, x)
    enemy.health = health or 1000
    enemy.maxHealth = health or 1000
    return enemy
end

local function fire(ability, enemies, heroStats, pool)
    ability:canActivate(100, heroStats)
    return ability:activate(360, WALL_Y, enemies, pool, nil, heroStats)
end

describe("New abilities", function()
    before_each(function()
        ability_data_loader.initialize()
        ability_registry.initialize()
        combat_system.onEnemyKilled = nil
        combat_system.onEnemyDamaged = nil
        card_powers.cleanup()
    end)

    it("are unlocked and can be created through the registry", function()
        for _, id in ipairs({ "chain_lightning", "meteor", "poison_cloud", "spirit_turret", "keen_eye", "mending_wards" }) do
            assert.is_true(ability_registry.isUnlocked(id), id)
            local ability = ability_registry.createInstance(id)
            assert.is_not_nil(ability, id)
            assert.are.equal(id, ability.id)
            assert.is_not_nil(ability_data_loader.getIconPath(id), id)
        end
    end)

    describe("Chain Lightning", function()
        it("hits the nearest enemy and jumps to 2 more with falling damage", function()
            local lightning = ChainLightning:new()
            local first = newEnemy(360, 1000)
            local second = newEnemy(460, 1000)
            local third = newEnemy(560, 1000)
            local far = newEnemy(360, 200)
            assert.is_true(fire(lightning, { far, third, second, first }))
            assert.are.equal(1000 - 18, first.health)
            assert.is_true(math.abs(second.health - (1000 - 18 * 0.7)) < 1e-9)
            assert.is_true(math.abs(third.health - (1000 - 18 * 0.49)) < 1e-9)
            assert.are.equal(1000, far.health)
        end)

        it("does not fire without targets", function()
            assert.is_false(fire(ChainLightning:new(), {}))
        end)

        it("upgrades jumps, damage, falloff, and stun", function()
            local lightning = ChainLightning:new()
            lightning:upgrade("jump_count")
            lightning:upgrade("damage_increase")
            lightning:upgrade("no_falloff")
            lightning:upgrade("stun")
            assert.are.equal(3, lightning.jumps)
            assert.is_true(math.abs(lightning.damage - 21.6) < 1e-9)
            assert.are.equal(1, lightning.falloff)
            assert.are.equal(0.2, lightning.stunChance)
            assert.are.equal(5, lightning.tier)

            lightning.stunChance = 1
            local a, b = newEnemy(360, 1000), newEnemy(460, 1000)
            fire(lightning, { a, b })
            assert.is_true(math.abs(b.health - (1000 - 21.6)) < 1e-9)
            assert.are.equal(0, a.slowFactor)
        end)
    end)

    describe("Meteor", function()
        it("lands on the densest group after its delay and burns survivors", function()
            local meteor = Meteor:new()
            local lone = newEnemy(100, 300)
            local a, b, c = newEnemy(500, 600), newEnemy(540, 610), newEnemy(520, 650)
            assert.is_true(fire(meteor, { lone, a, b, c }))
            meteor:update(1.0, 360, WALL_Y, { lone, a, b, c })
            assert.are.equal(1000, a.health)
            meteor:update(0.3, 360, WALL_Y, { lone, a, b, c })
            assert.are.equal(960, a.health)
            assert.are.equal(960, c.health)
            assert.are.equal(1000, lone.health)
            assert.is_true(a.burnRemaining > 0)
        end)

        it("drops a smaller second meteor on another group (upgrade)", function()
            local meteor = Meteor:new()
            meteor:upgrade("second_meteor")
            local a, b = newEnemy(500, 600), newEnemy(530, 600)
            local other = newEnemy(150, 400)
            fire(meteor, { a, b, other })
            assert.are.equal(2, #meteor.impacts)
            meteor:update(1.3, 360, WALL_Y, { a, b, other })
            assert.are.equal(1000 - 40 * 0.6, other.health)
        end)

        it("upgrades radius, cooldown, and burn", function()
            local meteor = Meteor:new()
            meteor:upgrade("radius_increase")
            meteor:upgrade("attack_speed")
            meteor:upgrade("burn_duration")
            assert.are.equal(112.5, meteor.radius)
            assert.are.equal(3, meteor.cooldown)
            assert.are.equal(4, meteor.burnDuration)
        end)
    end)

    describe("Poison Cloud", function()
        it("drops a cloud near the wall that poisons enemies inside it in ticks", function()
            local cloud = PoisonCloud:new()
            local near = newEnemy(400, 1000)
            local far = newEnemy(400, 300)
            assert.is_true(fire(cloud, { near, far }))
            assert.are.equal(1, #cloud.clouds)
            cloud:update(1.0, 360, WALL_Y, { near, far })
            assert.are.equal(1000 - 6, near.health)
            assert.are.equal(1000, far.health)
        end)

        it("ignores enemies far from the wall", function()
            assert.is_false(fire(PoisonCloud:new(), { newEnemy(400, 300) }))
        end)

        it("expires after its duration", function()
            local cloud = PoisonCloud:new()
            local near = newEnemy(400, 1000)
            fire(cloud, { near })
            cloud:update(4.1, 360, WALL_Y, { near })
            assert.are.equal(0, #cloud.clouds)
        end)

        it("stacks, makes enemies vulnerable, and bursts on death (upgrades)", function()
            local cloud = PoisonCloud:new()
            cloud:upgrade("stack_increase")
            cloud:upgrade("vulnerability")
            cloud:upgrade("burst")
            local tough = newEnemy(400, 1000)
            local weak = newEnemy(420, 1000, 5)
            fire(cloud, { tough, weak })
            cloud:update(0.5, 360, WALL_Y, { tough, weak })
            -- 6 dps x 0.5s x 2 stacks, +10% because the cloud's own hit counts as poisoned
            assert.is_true(math.abs(tough.health - (1000 - 6.6)) < 1e-9)
            assert.is_true(tough.vulnerableRemaining > 0)
            assert.is_false(weak.isActive)
            assert.are.equal(2, #cloud.clouds)

            local before = tough.health
            combat_system.applyDamage(tough, 10)
            assert.is_true(math.abs(tough.health - (before - 11)) < 1e-9)
        end)
    end)

    describe("Spirit Turret", function()
        local function projectilePool()
            local fired = {}
            return {
                fired = fired,
                get = function()
                    local projectile = require("src.entities.projectile"):new(nil)
                    table.insert(fired, projectile)
                    return projectile
                end,
                release = function() end,
            }
        end

        it("fires one shot per turret from its own position", function()
            local turret = SpiritTurret:new()
            turret:upgrade("turret_count")
            local pool = projectilePool()
            assert.is_true(fire(turret, { newEnemy(200, 900), newEnemy(500, 900) }, nil, pool))
            assert.are.equal(2, #pool.fired)
            assert.are.equal(240, pool.fired[1].x)
            assert.are.equal(480, pool.fired[2].x)
            assert.are.equal(WALL_Y - 40, pool.fired[1].y)
        end)

        it("does not fire without targets", function()
            assert.is_false(fire(SpiritTurret:new(), {}, nil, projectilePool()))
        end)

        it("caps turrets at 4 and adds pierce, fire rate, and elemental shots", function()
            local turret = SpiritTurret:new()
            for _ = 1, 5 do turret:upgrade("turret_count") end
            assert.are.equal(4, turret.turretCount)
            turret:upgrade("fire_rate")
            assert.is_true(math.abs(turret.cooldown - 1.2 / 1.3) < 1e-9)
            turret:upgrade("pierce")
            turret:upgrade("elemental_shots")
            local pool = projectilePool()
            fire(turret, { newEnemy(300, 900) }, nil, pool)
            assert.are.equal(1, pool.fired[1].pierceCount)
            assert.is_not_nil(pool.fired[1].burnDps)
            assert.is_not_nil(pool.fired[1].slowFactor)
        end)
    end)

    describe("passives", function()
        it("Keen Eye adds crit chance per tier and crit damage at tier 5", function()
            local hero = Hero:new(45, 1200)
            local eye = ability_registry.createInstance("keen_eye")
            hero:addAbility(eye)
            assert.is_true(math.abs(hero:getStats().critChance - 0.04) < 1e-9)
            assert.are.equal(0, hero:getStats().critDamageBonus)
            for _ = 1, 4 do eye:upgrade() end
            assert.is_true(math.abs(hero:getStats().critChance - 0.2) < 1e-9)
            assert.are.equal(0.5, hero:getStats().critDamageBonus)
            hero:destroy()
        end)

        it("Keen Eye crits through combat damage", function()
            local hero = Hero:new(45, 1200)
            local eye = ability_registry.createInstance("keen_eye")
            for _ = 1, 4 do eye:upgrade() end
            hero:addAbility(eye)
            card_powers.start({}, { hero = hero, rng = function() return 0.1 end })
            local enemy = newEnemy(300, 500)
            combat_system.applyDamage(enemy, 10)
            -- 10 x (2 + 0.5)
            assert.are.equal(1000 - 25, enemy.health)
            card_powers.cleanup()
            hero:destroy()
        end)

        it("Mending Wards regenerates the wall and adds a shield at tier 5", function()
            local game_controller = require("src.controllers.game_controller")
            game_controller.initialize(display.newGroup())
            local hero = game_controller.getHero()
            local wall = game_controller.getWall()
            local wards = ability_registry.createInstance("mending_wards")
            hero:addAbility(wards)
            wall.health = 50
            game_controller.updateWallSustain(2)
            assert.are.equal(51, wall.health)
            assert.is_nil(wall.shield)

            for _ = 1, 4 do wards:upgrade() end
            game_controller.updateWallSustain(1)
            assert.are.equal(wall.maxHealth * 0.1, wall.shield)

            local before = wall.health
            game_controller.damageWall(wall.maxHealth * 0.1 + 5)
            assert.are.equal(0, wall.shield)
            assert.are.equal(before - 5, wall.health)
            game_controller.cleanup()
        end)
    end)
end)
