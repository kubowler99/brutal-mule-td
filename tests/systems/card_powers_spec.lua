require("tests.spec_helper")

local card_powers = require("src.systems.card_powers")

--- Fake enemy with the fields card powers read
local function enemy(fields)
    local e = {
        x = 360, y = 500, health = 50, maxHealth = 50, isActive = true,
        slows = {}, burns = {},
    }
    for k, v in pairs(fields or {}) do e[k] = v end
    function e:applySlow(factor, duration) table.insert(self.slows, { factor, duration }) end
    function e:applyBurn(dps, duration) table.insert(self.burns, { dps, duration }) end
    return e
end

--- Run context that records damage and kills enemies at 0 health
local function context(enemies, wall, rngValue)
    local hits = {}
    return {
        wall = wall,
        getEnemies = function() return enemies end,
        applyDamage = function(target, amount)
            table.insert(hits, { target = target, amount = amount })
            target.health = target.health - amount
            if target.health <= 0 then
                target.isActive = false
                return true
            end
            return false
        end,
        rng = function() return rngValue or 0 end,
        hits = hits,
    }
end

local function start(stats, actives, ctx)
    card_powers.start({ stats = stats or {}, actives = actives or {} }, ctx or context({}))
end

describe("Card powers", function()
    after_each(function()
        card_powers.cleanup()
    end)

    describe("passive hooks", function()
        it("raises damage to elites and bosses only (Executioner)", function()
            start({ bossDamageMultiplier = 0.25 })
            assert.are.equal(125, card_powers.modifyEnemyDamage({ isBoss = true }, 100))
            assert.are.equal(125, card_powers.modifyEnemyDamage({ isElite = true }, 100))
            assert.are.equal(100, card_powers.modifyEnemyDamage({}, 100))
        end)

        it("reduces wall damage, capped at 90% (Bulwark)", function()
            start({ wallDamageReduction = 0.08 })
            assert.is_true(math.abs(card_powers.modifyWallDamage(100) - 92) < 1e-9)
            start({ wallDamageReduction = 2 })
            assert.is_true(math.abs(card_powers.modifyWallDamage(100) - 10) < 1e-9)
        end)

        it("hits back enemies that hit the wall (Iron Spikes)", function()
            local foe = enemy()
            local ctx = context({ foe })
            start({ thornsDamage = 2.5 }, nil, ctx)
            card_powers.onWallHit(foe)
            assert.are.equal(2.5, ctx.hits[1].amount)
        end)

        it("sets hit enemies on fire, but not from burn damage or kills (Ember Brand)", function()
            local foe = enemy()
            start({ burnChance = 0.1 }, nil, context({ foe }, nil, 0.05))
            card_powers.onEnemyDamaged(foe, 10, false)
            assert.are.equal(1, #foe.burns)
            card_powers.onEnemyDamaged(foe, 10, true)
            card_powers.applyBurnDamage(function() card_powers.onEnemyDamaged(foe, 4, false) end)
            assert.are.equal(1, #foe.burns)
        end)

        it("does not burn when the roll misses", function()
            local foe = enemy()
            start({ burnChance = 0.1 }, nil, context({ foe }, nil, 0.5))
            card_powers.onEnemyDamaged(foe, 10, false)
            assert.are.equal(0, #foe.burns)
        end)

        it("explodes kills into nearby enemies without chaining (Chain Reaction)", function()
            local dead = enemy({ x = 100, y = 100, isActive = false })
            local near = enemy({ x = 150, y = 100, health = 5 })
            local nearer = enemy({ x = 110, y = 110 })
            local far = enemy({ x = 400, y = 400 })
            local ctx = context({ dead, near, nearer, far })
            start({ killExplosionChance = 0.15, killExplosionDamage = 20 }, nil, ctx)
            card_powers.onEnemyKilled(dead)
            -- near dies from the explosion, but its death does not explode again
            assert.are.equal(2, #ctx.hits)
            assert.is_false(near.isActive)
            assert.are.equal(50, far.health)
        end)

        it("boosts XP from elites (Bounty Hunter)", function()
            start({ eliteXPMultiplier = 0.5 })
            assert.are.equal(1.5, card_powers.xpMultiplierFor({ isElite = true }))
            assert.are.equal(1, card_powers.xpMultiplierFor({}))
        end)

        it("revives the wall once (Second Wind)", function()
            local wall = { health = 0, maxHealth = 200 }
            start({ reviveWallPercent = 0.5 })
            assert.is_true(card_powers.tryReviveWall(wall))
            assert.are.equal(100, wall.health)
            wall.health = 0
            assert.is_false(card_powers.tryReviveWall(wall))
        end)

        it("never revives without the card", function()
            start({})
            assert.is_false(card_powers.tryReviveWall({ health = 0, maxHealth = 100 }))
        end)

        it("rolls twin casts at the card's chance (Twin Cast)", function()
            start({ twinCastChance = 0.15 }, nil, context({}, nil, 0.1))
            assert.is_true(card_powers.rollTwinCast())
            start({ twinCastChance = 0.15 }, nil, context({}, nil, 0.2))
            assert.is_false(card_powers.rollTwinCast())
            start({})
            assert.is_false(card_powers.rollTwinCast())
        end)

        it("gives an extra pick every Nth level-up (Ascendance)", function()
            start({ ascendanceInterval = 5 })
            local picks = {}
            for i = 1, 10 do picks[i] = card_powers.onLevelUp() end
            assert.are.same({ 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }, picks)
            start({})
            assert.are.equal(0, card_powers.onLevelUp())
        end)
    end)

    describe("active cards", function()
        it("heals the wall without overhealing (Wall Patch)", function()
            local wall = { health = 50, maxHealth = 100 }
            start({}, { { cardId = "wall_patch", action = "healWall", charges = 2, params = { healPercent = 0.1 } } },
                context({}, wall))
            assert.is_true(card_powers.use(1))
            assert.are.equal(60, wall.health)
            wall.health = 95
            assert.is_true(card_powers.use(1))
            assert.are.equal(100, wall.health)
            assert.is_false(card_powers.use(1))
        end)

        it("strikes the enemies closest to the wall (Spark)", function()
            local high = enemy({ y = 200 })
            local low = enemy({ y = 900 })
            local mid = enemy({ y = 600 })
            local ctx = context({ high, low, mid })
            start({}, { { cardId = "spark", action = "strikeNearest", charges = 2, params = { targets = 2, damage = 30 } } }, ctx)
            assert.is_true(card_powers.use(1))
            assert.are.equal(low, ctx.hits[1].target)
            assert.are.equal(mid, ctx.hits[2].target)
            assert.are.equal(2, #ctx.hits)
        end)

        it("keeps the charge when there is nothing to hit", function()
            start({}, { { cardId = "spark", action = "strikeNearest", charges = 1, params = { targets = 3, damage = 30 } } },
                context({}))
            assert.is_false(card_powers.use(1))
            assert.are.equal(1, card_powers.getHudActives()[1].chargesLeft)
        end)

        it("slows and freezes every enemy (Frost Pulse, Time Stop)", function()
            local a, b = enemy(), enemy({ isBoss = true })
            start({}, {
                { cardId = "frost_pulse", action = "slowAll", charges = 1, params = { slowFactor = 0.6, duration = 4 } },
                { cardId = "time_stop", action = "freezeAll", charges = 1, params = { duration = 5 } },
            }, context({ a, b }))
            card_powers.use(1)
            card_powers.use(2)
            assert.are.same({ { 0.6, 4 }, { 0, 5 } }, a.slows)
            assert.are.same({ { 0.6, 4 }, { 0, 5 } }, b.slows)
        end)

        it("destroys non-boss enemies and chips bosses (Purge)", function()
            local grunt = enemy({ health = 40 })
            local boss = enemy({ isBoss = true, health = 1000, maxHealth = 1000 })
            local ctx = context({ grunt, boss })
            start({}, { { cardId = "purge", action = "purge", charges = 1, params = { bossDamagePercent = 0.04 } } }, ctx)
            card_powers.use(1)
            assert.is_false(grunt.isActive)
            assert.are.equal(960, boss.health)
        end)

        it("blocks all wall damage for a while (Bastion)", function()
            start({ wallDamageReduction = 0.5 },
                { { cardId = "bastion", action = "wallInvulnerable", charges = 1, params = { duration = 6 } } })
            card_powers.use(1)
            assert.are.equal(0, card_powers.modifyWallDamage(100))
            card_powers.update(5.9)
            assert.are.equal(0, card_powers.modifyWallDamage(100))
            card_powers.update(0.2)
            assert.are.equal(50, card_powers.modifyWallDamage(100))
        end)

        it("drops meteors on random enemies (Meteor Storm)", function()
            local a = enemy({ health = 1000 })
            local ctx = context({ a })
            start({}, { { cardId = "meteor_storm", action = "meteorStorm", charges = 1, params = { count = 8, damage = 150 } } }, ctx)
            card_powers.use(1)
            -- 7 meteors kill it (7 x 150 >= 1000); the 8th has no target left
            assert.are.equal(7, #ctx.hits)
            assert.is_false(a.isActive)
        end)

        it("pulls non-boss enemies together and damages them (Arcane Singularity)", function()
            local a = enemy({ x = 100, y = 100, health = 1000 })
            local b = enemy({ x = 300, y = 300, health = 1000 })
            local boss = enemy({ x = 600, y = 600, isBoss = true, health = 5000 })
            local ctx = context({ a, b, boss }, nil, 0.5)
            start({}, { { cardId = "arcane_singularity", action = "singularity", charges = 1, params = { damage = 500 } } }, ctx)
            card_powers.use(1)
            assert.are.equal(200, a.x)
            assert.are.equal(200, b.y)
            assert.are.equal(500, a.health)
            assert.are.equal(5000, boss.health)
            assert.are.equal(600, boss.x)
        end)

        it("keeps Second Opinion out of the HUD and spends it on rerolls", function()
            start({}, {
                { cardId = "second_opinion", action = "rerollDraft", charges = 2, params = {} },
                { cardId = "spark", action = "strikeNearest", charges = 1, params = {} },
            })
            local hud = card_powers.getHudActives()
            assert.are.equal(1, #hud)
            assert.are.equal("spark", hud[1].cardId)
            assert.are.equal(2, hud[1].index)
            assert.are.equal(2, card_powers.chargesLeft("rerollDraft"))
            assert.is_true(card_powers.useReroll())
            assert.is_true(card_powers.useReroll())
            assert.is_false(card_powers.useReroll())
        end)
    end)
end)
