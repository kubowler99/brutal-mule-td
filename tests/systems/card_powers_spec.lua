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

    describe("milestone bonuses", function()
        it("adds burning, slowed, and crit bonuses to enemy damage", function()
            start({ burningDamageBonus = 0.1, slowedDamageBonus = 0.1 }, nil, context({}, nil, 0.99))
            assert.is_true(math.abs(card_powers.modifyEnemyDamage({ burnRemaining = 1 }, 100) - 110) < 1e-9)
            assert.is_true(math.abs(card_powers.modifyEnemyDamage({ burnRemaining = 1, slowRemaining = 1 }, 100) - 120) < 1e-9)

            start({ critChance = 0.02, critDamageBonus = 0.1 }, nil, context({}, nil, 0.01))
            assert.is_true(math.abs(card_powers.modifyEnemyDamage({}, 100) - 210) < 1e-9)
            start({ critChance = 0.02 }, nil, context({}, nil, 0.5))
            assert.are.equal(100, card_powers.modifyEnemyDamage({}, 100))
        end)

        it("finishes off non-boss enemies left below the threshold (Executioner 15)", function()
            start({ executeThreshold = 0.1 })
            assert.are.equal(50, card_powers.modifyEnemyDamage({ health = 50, maxHealth = 100 }, 45))
            assert.are.equal(30, card_powers.modifyEnemyDamage({ health = 50, maxHealth = 100 }, 30))
            assert.are.equal(45, card_powers.modifyEnemyDamage({ health = 50, maxHealth = 100, isBoss = true }, 45))
        end)

        it("cuts boss hits and ignores a hit every interval (Bulwark 5 and 15)", function()
            start({ wallDamageReduction = 0.1, bossWallDamageReduction = 0.1 })
            assert.is_true(math.abs(card_powers.modifyWallDamage(100, { isBoss = true }) - 80) < 1e-9)
            assert.is_true(math.abs(card_powers.modifyWallDamage(100, {}) - 90) < 1e-9)

            start({ wallBlockInterval = 20 })
            assert.are.equal(0, card_powers.modifyWallDamage(100, {}))
            assert.are.equal(100, card_powers.modifyWallDamage(100, {}))
            card_powers.update(20)
            assert.are.equal(0, card_powers.modifyWallDamage(100, {}))
        end)

        it("doubles spikes on elites and slows attackers (Iron Spikes 5 and 15)", function()
            local elite = enemy({ isElite = true })
            local ctx = context({ elite })
            start({ thornsDamage = 2, thornsEliteMultiplier = 1, thornsSlowDuration = 1 }, nil, ctx)
            card_powers.onWallHit(elite)
            assert.are.equal(4, ctx.hits[1].amount)
            assert.are.same({ { card_powers.THORNS_SLOW_FACTOR, 1 } }, elite.slows)
        end)

        it("makes burns last longer (Ember Brand 5)", function()
            local foe = enemy()
            start({ burnChance = 1, burnDurationBonus = 1 }, nil, context({ foe }, nil, 0))
            card_powers.onEnemyDamaged(foe, 5, false)
            assert.are.same({ { card_powers.BURN_DAMAGE_PER_SECOND, card_powers.BURN_DURATION + 1 } }, foe.burns)
        end)

        it("lets explosions burn and chain once (Chain Reaction 5 and 15)", function()
            local first = enemy({ x = 100, y = 100, isActive = false })
            local second = enemy({ x = 150, y = 100, health = 5 })
            local third = enemy({ x = 220, y = 100, health = 5 })
            local fourth = enemy({ x = 290, y = 100, health = 5 })
            local ctx = context({ first, second, third, fourth })
            -- Kills report to the controller, which calls onEnemyKilled again
            local applyDamage = ctx.applyDamage
            ctx.applyDamage = function(target, amount)
                local killed = applyDamage(target, amount)
                if killed then card_powers.onEnemyKilled(target) end
                return killed
            end
            start({ killExplosionChance = 1, killExplosionDamage = 20, explosionChains = 1, explosionBurn = 1 }, nil, ctx)
            card_powers.onEnemyKilled(first)
            assert.is_false(second.isActive)
            assert.is_false(third.isActive)
            -- The second chain would be a third explosion: not allowed
            assert.is_true(fourth.isActive)
        end)

        it("adds boss XP, early XP, and kill gold", function()
            local ctx = context({})
            ctx.getElapsed = function() return 60 end
            start({ bossXPMultiplier = 0.25, earlyXPMultiplier = 0.05, bossGold = 10, eliteGold = 5 }, nil, ctx)
            assert.is_true(math.abs(card_powers.xpMultiplierFor({ isBoss = true }) - 1.3) < 1e-9)
            assert.are.equal(10, card_powers.goldForKill({ isBoss = true }))
            assert.are.equal(5, card_powers.goldForKill({ isElite = true }))
            ctx.getElapsed = function() return 121 end
            assert.is_true(math.abs(card_powers.xpMultiplierFor({}) - 1) < 1e-9)
        end)

        it("revives twice and pushes enemies back (Second Wind 5 and 15)", function()
            local foe = enemy({ y = 1140, wallTarget = {}, isAttackingWall = true })
            start({ reviveWallPercent = 0.5, extraRevives = 1, reviveKnockback = 150 }, nil, context({ foe }))
            local wall = { health = 0, maxHealth = 100 }
            assert.is_true(card_powers.tryReviveWall(wall))
            assert.are.equal(990, foe.y)
            assert.is_nil(foe.wallTarget)
            wall.health = 0
            assert.is_true(card_powers.tryReviveWall(wall))
            wall.health = 0
            assert.is_false(card_powers.tryReviveWall(wall))
        end)

        it("regenerates the wall (Stone Mortar 15)", function()
            local wall = { health = 50, maxHealth = 100 }
            start({ wallRegen = 1 }, nil, context({}, wall))
            card_powers.update(2.5)
            assert.are.equal(52.5, wall.health)
        end)

        it("boosts the sixth slot and twin casts", function()
            start({ sixthAbilityDamage = 0.1, twinCastDamageBonus = 0.1 })
            local stats = { damageMultiplier = 1 }
            assert.are.equal(stats, card_powers.statsFor(stats, 5))
            assert.is_true(math.abs(card_powers.statsFor(stats, 6).damageMultiplier - 1.1) < 1e-9)
            assert.is_true(math.abs(card_powers.statsFor(stats, 6, true).damageMultiplier - 1.2) < 1e-9)
            assert.are.equal(1, stats.damageMultiplier)
        end)

        it("allows a third cast only with Twin Cast 15", function()
            start({ twinCastChance = 0.1 })
            assert.is_false(card_powers.canTripleCast())
            start({ twinCastChance = 0.1, twinCastExtraRoll = 1 })
            assert.is_true(card_powers.canTripleCast())
        end)

        it("adds cards to the first draft only (Scholar's Notes 15)", function()
            start({ firstDraftExtraCards = 1 })
            local _, first = card_powers.onLevelUp()
            local _, second = card_powers.onLevelUp()
            assert.are.equal(1, first)
            assert.are.equal(0, second)
        end)

        it("resets cooldowns after a pick (Swift Casting 15)", function()
            local ability = { lastActivation = 12 }
            local ctx = context({})
            ctx.hero = { abilities = { ability } }
            start({ resetCooldownsOnLevelUp = 1 }, nil, ctx)
            card_powers.onUpgradePicked()
            assert.are.equal(-math.huge, ability.lastActivation)
        end)

        it("shields the wall after a patch (Wall Patch 15)", function()
            local wall = { health = 50, maxHealth = 100 }
            start({}, { { cardId = "wall_patch", action = "healWall", charges = 1, params = { healPercent = 0.15, shieldDuration = 5 } } },
                context({}, wall))
            card_powers.use(1)
            assert.are.equal(65, wall.health)
            assert.are.equal(0, card_powers.modifyWallDamage(10, {}))
            card_powers.update(5.1)
            assert.are.equal(10, card_powers.modifyWallDamage(10, {}))
        end)

        it("stuns struck enemies (Spark 15)", function()
            local foe = enemy({ health = 100 })
            start({}, { { cardId = "spark", action = "strikeNearest", charges = 1, params = { targets = 1, damage = 10, stunDuration = 0.5 } } },
                context({ foe }))
            card_powers.use(1)
            assert.are.same({ { 0, 0.5 } }, foe.slows)
        end)

        it("freezes first, then slows (Frost Pulse 15)", function()
            local foe = enemy()
            start({}, { { cardId = "frost_pulse", action = "slowAll", charges = 1, params = { slowFactor = 0.6, duration = 4, freezeDuration = 1 } } },
                context({ foe }))
            card_powers.use(1)
            assert.are.same({ { 0, 1 } }, foe.slows)
            card_powers.update(1)
            assert.are.same({ { 0, 1 }, { 0.6, 4 } }, foe.slows)
        end)

        it("heals the wall per enemy destroyed (Purge 15)", function()
            local wall = { health = 50, maxHealth = 100 }
            start({}, { { cardId = "purge", action = "purge", charges = 1, params = { bossDamagePercent = 0, healPerKill = 0.01 } } },
                context({ enemy(), enemy(), enemy() }, wall))
            card_powers.use(1)
            assert.are.equal(53, wall.health)
        end)

        it("reflects and knocks back during Bastion (Bastion 5 and 15)", function()
            local foe = enemy({ y = 1140, health = 100 })
            local ctx = context({ foe })
            start({}, { { cardId = "bastion", action = "wallInvulnerable", charges = 1, params = { duration = 6, knockback = 120, reflect = 0.5 } } }, ctx)
            card_powers.use(1)
            assert.are.equal(0, card_powers.modifyWallDamage(20, foe))
            assert.are.equal(10, ctx.hits[1].amount)
            assert.are.equal(1020, foe.y)
        end)

        it("sets meteor targets on fire (Meteor Storm 15)", function()
            local foe = enemy({ health = 10000 })
            start({}, { { cardId = "meteor_storm", action = "meteorStorm", charges = 1, params = { count = 1, damage = 10, burnDps = 10 } } },
                context({ foe }))
            card_powers.use(1)
            assert.are.same({ { 10, card_powers.METEOR_BURN_DURATION } }, foe.burns)
        end)

        it("boosts damage to frozen enemies and refreshes cooldowns after (Time Stop 5 and 15)", function()
            local foe = enemy()
            local ability = { lastActivation = 3 }
            local ctx = context({ foe })
            ctx.hero = { abilities = { ability } }
            start({}, { { cardId = "time_stop", action = "freezeAll", charges = 1, params = { duration = 5, damageBonus = 0.1, refreshCooldowns = 1 } } }, ctx)
            card_powers.use(1)
            foe.slowRemaining, foe.slowFactor = 5, 0
            assert.is_true(math.abs(card_powers.modifyEnemyDamage(foe, 100) - 110) < 1e-9)
            card_powers.update(5)
            assert.are.equal(-math.huge, ability.lastActivation)
            assert.is_false(card_powers.isTimeStopped())
        end)

        it("hits bosses and leaves a damaging rift (Arcane Singularity 5 and 15)", function()
            local foe = enemy({ x = 100, y = 100, health = 10000 })
            local boss = enemy({ x = 600, y = 600, isBoss = true, health = 10000 })
            local ctx = context({ foe, boss }, nil, 0.5)
            start({}, { { cardId = "arcane_singularity", action = "singularity", charges = 1,
                params = { damage = 500, bossDamageFraction = 0.1, riftDuration = 5 } } }, ctx)
            card_powers.use(1)
            assert.are.equal(9950, boss.health)
            assert.are.equal(9500, foe.health)
            card_powers.update(1)
            -- Rift: 10% of 500 per second, in 0.5s ticks
            assert.are.equal(9450, foe.health)
            assert.are.equal(9950, boss.health)
        end)

        it("offers extra cards on rerolls (Second Opinion 15)", function()
            start({}, { { cardId = "second_opinion", action = "rerollDraft", charges = 1, params = { extraCards = 1 } } })
            local used, extra = card_powers.useReroll()
            assert.is_true(used)
            assert.are.equal(1, extra)
        end)
    end)
end)
