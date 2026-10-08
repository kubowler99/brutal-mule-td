require("tests.spec_helper")

local data = require("src.models.data")
local meta = require("src.models.meta_progression")
local cards = require("src.models.card_collection")

local json = _G.json or require("json")

--- Deterministic random function returning [0, 1)
local function seededRng(seed)
    local state = seed
    return function()
        state = (state * 1103515245 + 12345) % 2147483648
        return state / 2147483648
    end
end

--- Random function that returns the given values in order, then repeats the last
local function fixedRng(values)
    local i = 0
    return function()
        i = math.min(i + 1, #values)
        return values[i]
    end
end

--- Add copies of cards straight to the collection
-- @return table uids
local function give(cardId, count)
    local saved = data.get("meta.cards") or {}
    saved.nextUid = saved.nextUid or 1
    saved.instances = saved.instances or {}
    saved.loadout = saved.loadout or {}
    saved.pity = saved.pity or {}
    local uids = {}
    for _ = 1, count do
        local uid = "c" .. saved.nextUid
        saved.nextUid = saved.nextUid + 1
        saved.instances[uid] = { cardId = cardId, level = 1 }
        table.insert(uids, uid)
    end
    data.set("meta.cards", saved)
    return uids
end

local function setLevel(uid, level)
    data.get("meta.cards").instances[uid].level = level
end

describe("Card collection", function()
    before_each(function()
        cards.setDefinitions(nil)
        meta.setDefinitions(nil)
        data.startSandbox()
        data.set("meta", {})
    end)

    after_each(function()
        data.stopSandbox(false)
    end)

    describe("definitions", function()
        it("loads 26 unique cards split 8/6/5/4/3 across the tiers", function()
            local defs = cards.getDefinitions()
            assert.are.equal(26, #defs.cards)
            local ids = {}
            for _, card in ipairs(defs.cards) do
                assert.is_nil(ids[card.id], "duplicate card " .. card.id)
                ids[card.id] = true
                assert.is_not_nil(cards.tierRank(card.tier), card.id .. " has an unknown tier")
                assert.is_true(card.kind == "passive" or card.kind == "active", card.id)
            end
            assert.are.equal(8, #cards.getCardsOfTier("common"))
            assert.are.equal(6, #cards.getCardsOfTier("uncommon"))
            assert.are.equal(5, #cards.getCardsOfTier("rare"))
            assert.are.equal(4, #cards.getCardsOfTier("legendary"))
            assert.are.equal(3, #cards.getCardsOfTier("mythic"))
        end)

        it("has tier odds that add up to 1", function()
            local total = 0
            for _, tier in ipairs(cards.getDefinitions().tiers) do
                total = total + tier.odds
            end
            assert.is_true(math.abs(total - 1) < 1e-9)
        end)

        it("orders tiers from common to mythic", function()
            assert.are.equal("uncommon", cards.nextTier("common"))
            assert.are.equal("mythic", cards.nextTier("legendary"))
            assert.is_nil(cards.nextTier("mythic"))
        end)
    end)

    describe("buying packs", function()
        it("costs 150 gold and adds 3 cards", function()
            meta.addGold(200)
            local opened = cards.buyPack(seededRng(1))
            assert.are.equal(3, #opened)
            assert.are.equal(50, meta.getGold())
            assert.are.equal(3, #cards.getInstances())
            for _, card in ipairs(opened) do
                assert.are.equal(1, cards.getInstance(card.uid).level)
                assert.are.equal(cards.getCard(card.cardId).tier, card.tier)
            end
        end)

        it("refuses without enough gold and keeps the gold", function()
            meta.addGold(149)
            local opened, reason = cards.buyPack(seededRng(1))
            assert.is_nil(opened)
            assert.are.equal("gold", reason)
            assert.are.equal(149, meta.getGold())
            assert.are.equal(0, #cards.getInstances())
        end)

        it("rolls tiers at the configured odds", function()
            local rng = seededRng(42)
            local counts = { common = 0, uncommon = 0, rare = 0, legendary = 0, mythic = 0 }
            local total = 0
            for _ = 1, 40000 do
                for _, tier in ipairs(cards.rollPackTiers(rng)) do
                    counts[tier] = counts[tier] + 1
                    total = total + 1
                end
            end
            local function near(tier, expected, tolerance)
                local actual = counts[tier] / total
                assert.is_true(math.abs(actual - expected) < tolerance,
                    string.format("%s: expected %.4f, got %.4f", tier, expected, actual))
            end
            near("common", 0.75, 0.008)
            near("uncommon", 0.15, 0.006)
            near("rare", 0.07, 0.004)
            near("legendary", 0.029, 0.003)
            near("mythic", 0.001, 0.0006)
        end)
    end)

    describe("pity", function()
        -- Always rolls common
        local allCommon = fixedRng({ 0 })

        it("guarantees a rare-or-better card in the 10th pack without one", function()
            meta.addGold(150 * 10)
            for _ = 1, 9 do
                for _, card in ipairs(cards.buyPack(allCommon)) do
                    assert.are.equal("common", card.tier)
                end
            end
            assert.are.equal(9, cards.getPityCount("rare"))

            local tenth = cards.buyPack(allCommon)
            local tiers = {}
            for _, card in ipairs(tenth) do tiers[card.tier] = (tiers[card.tier] or 0) + 1 end
            assert.are.equal(1, tiers.rare)
            assert.are.equal(2, tiers.common)
            assert.are.equal(0, cards.getPityCount("rare"))
        end)

        it("guarantees a legendary-or-better card in the 50th pack without one", function()
            meta.addGold(150 * 50)
            local legendaries = 0
            for pack = 1, 50 do
                for _, card in ipairs(cards.buyPack(allCommon)) do
                    if card.tier == "legendary" then
                        legendaries = legendaries + 1
                        assert.are.equal(50, pack)
                    end
                end
            end
            assert.are.equal(1, legendaries)
            assert.are.equal(0, cards.getPityCount("legendary"))
        end)

        it("resets a counter when a pack already has that tier or better", function()
            meta.addGold(300)
            cards.buyPack(allCommon)
            assert.are.equal(1, cards.getPityCount("rare"))
            -- First card rolls legendary (0.75 + 0.15 + 0.07 = 0.97 <= 0.98 < 0.999)
            cards.buyPack(fixedRng({ 0.98, 0, 0, 0, 0, 0 }))
            assert.are.equal(0, cards.getPityCount("rare"))
            assert.are.equal(0, cards.getPityCount("legendary"))
        end)
    end)

    describe("merging", function()
        it("costs 5 cards to reach levels 2-5, 10 for 6-10, and 20 for 11-15", function()
            for level = 1, 4 do assert.are.equal(5, cards.mergeCost(level)) end
            for level = 5, 9 do assert.are.equal(10, cards.mergeCost(level)) end
            for level = 10, 14 do assert.are.equal(20, cards.mergeCost(level)) end
            assert.is_nil(cards.mergeCost(15))
        end)

        it("needs 170 cards to take a card from level 1 to 15", function()
            local total = 0
            for level = 1, 14 do total = total + cards.mergeCost(level) end
            assert.are.equal(170, total)
        end)

        it("levels up a card with any cards of the same tier", function()
            local target = give("sharpened_focus", 1)[1]
            local sacrifices = give("stone_mortar", 3)
            for _, uid in ipairs(give("sharpened_focus", 2)) do table.insert(sacrifices, uid) end

            assert.is_true(cards.merge(target, sacrifices))
            assert.are.equal(2, cards.getInstance(target).level)
            assert.are.equal(1, #cards.getInstances())
        end)

        it("rejects the wrong count, another tier, duplicates, the target, and equipped cards", function()
            local target = give("sharpened_focus", 1)[1]
            local commons = give("stone_mortar", 5)
            local rare = give("purge", 1)[1]

            local four = { commons[1], commons[2], commons[3], commons[4] }
            assert.are.same({ false, "count" }, { cards.merge(target, four) })

            local mixed = { commons[1], commons[2], commons[3], commons[4], rare }
            assert.are.same({ false, "tier" }, { cards.merge(target, mixed) })

            local repeated = { commons[1], commons[1], commons[2], commons[3], commons[4] }
            assert.are.same({ false, "duplicate" }, { cards.merge(target, repeated) })

            local withTarget = { commons[1], commons[2], commons[3], commons[4], target }
            assert.are.same({ false, "duplicate" }, { cards.merge(target, withTarget) })

            cards.equip(1, commons[5])
            assert.are.same({ false, "equipped" }, { cards.merge(target, commons) })

            assert.are.equal(1, cards.getInstance(target).level)
            assert.are.equal(7, #cards.getInstances())
        end)

        it("rejects sacrifices of a different tier from the target", function()
            local target = give("purge", 1)[1]
            assert.are.same({ false, "tier" }, { cards.merge(target, give("stone_mortar", 5)) })
        end)

        it("stops at level 15", function()
            local target = give("sharpened_focus", 1)[1]
            setLevel(target, 15)
            assert.are.same({ false, "maxed" }, { cards.merge(target, give("stone_mortar", 20)) })
        end)
    end)

    describe("fusion", function()
        it("fuses 5 commons into a level 1 uncommon", function()
            local fused = cards.fuse(give("stone_mortar", 5), seededRng(3))
            assert.are.equal("uncommon", fused.tier)
            assert.are.equal("uncommon", cards.getCard(fused.cardId).tier)
            assert.are.equal(1, cards.getInstance(fused.uid).level)
            assert.are.equal(1, #cards.getInstances())
        end)

        it("fuses 10 legendaries into a mythic", function()
            assert.are.equal(10, cards.fusionCost("legendary"))
            local fused = cards.fuse(give("twin_cast", 10), seededRng(3))
            assert.are.equal("mythic", fused.tier)
        end)

        it("rejects mythics, mixed tiers, and the wrong count", function()
            assert.are.same({ nil, "maxTier" }, { cards.fuse(give("time_stop", 5)) })
            local mixed = give("stone_mortar", 4)
            table.insert(mixed, give("purge", 1)[1])
            assert.are.same({ nil, "tier" }, { cards.fuse(mixed) })
            assert.are.same({ nil, "count" }, { cards.fuse(give("stone_mortar", 4)) })
        end)
    end)

    describe("loadout", function()
        it("has 3 slots", function()
            assert.are.equal(3, cards.getLoadoutSlots())
        end)

        it("equips cards, moves a card between slots, and unequips", function()
            local uids = give("sharpened_focus", 2)
            assert.is_true(cards.equip(1, uids[1]))
            assert.is_true(cards.equip(2, uids[2]))
            assert.are.equal(uids[1], cards.getLoadout()[1])

            assert.is_true(cards.equip(3, uids[1]))
            assert.is_nil(cards.getLoadout()[1])
            assert.are.equal(uids[1], cards.getLoadout()[3])

            cards.unequip(3)
            assert.is_nil(cards.getLoadout()[3])
            assert.is_false(cards.isEquipped(uids[1]))
        end)

        it("rejects bad slots and unknown cards", function()
            local uid = give("sharpened_focus", 1)[1]
            assert.are.same({ false, "slot" }, { cards.equip(0, uid) })
            assert.are.same({ false, "slot" }, { cards.equip(4, uid) })
            assert.are.same({ false, "unknown" }, { cards.equip(1, "c999") })
        end)
    end)

    describe("run effects", function()
        it("is empty with nothing equipped", function()
            local effects = cards.getRunEffects()
            assert.are.same({}, effects.stats)
            assert.are.same({}, effects.actives)
        end)

        it("scales passive stats with level and sums them", function()
            local focus = give("sharpened_focus", 1)[1]
            local swift = give("swift_casting", 1)[1]
            setLevel(focus, 3)
            cards.equip(1, focus)
            cards.equip(2, swift)

            local stats = cards.getRunEffects().stats
            assert.is_true(math.abs(stats.damageMultiplier - (0.04 + 0.005 * 2)) < 1e-9)
            assert.is_true(math.abs(stats.cooldownMultiplier - (-0.06)) < 1e-9)
        end)

        it("adds the level 1 value again at level 10, except where turned off", function()
            local mortar = give("stone_mortar", 1)[1]
            local wind = give("second_wind", 1)[1]
            setLevel(mortar, 10)
            setLevel(wind, 10)
            cards.equip(1, mortar)
            cards.equip(2, wind)

            local stats = cards.getRunEffects().stats
            -- level value + level 10 bonus + Stone Mortar's level 5 milestone (+5)
            assert.are.equal(10 + 2 * 9 + 10 + 5, stats.wallHealth)
            assert.is_true(math.abs(stats.reviveWallPercent - (0.5 + 0.02 * 9)) < 1e-9)
        end)

        it("lists active cards with scaled params and +1 charge at level 10", function()
            local spark = give("spark", 1)[1]
            setLevel(spark, 10)
            cards.equip(1, spark)

            local active = cards.getRunEffects().actives[1]
            assert.are.equal("strikeNearest", active.action)
            assert.are.equal(3, active.charges)
            assert.are.equal(30 + 4 * 9, active.params.damage)
            -- 3 targets + Spark's level 5 milestone (+1)
            assert.are.equal(4, active.params.targets)
        end)

        it("applies milestone stats, params, charges, and replaced stats", function()
            local focus = give("sharpened_focus", 1)[1]
            local purge = give("purge", 1)[1]
            local ascend = give("ascendance", 1)[1]
            setLevel(focus, 15)
            setLevel(purge, 15)
            setLevel(ascend, 5)
            cards.equip(1, focus)
            cards.equip(2, purge)
            cards.equip(3, ascend)

            local effects = cards.getRunEffects()
            assert.is_true(math.abs(effects.stats.bossDamageMultiplier - 0.05) < 1e-9)
            assert.is_true(math.abs(effects.stats.critChance - 0.02) < 1e-9)
            assert.are.equal(4, effects.stats.ascendanceInterval)
            local active = effects.actives[1]
            -- 1 charge + level 5 milestone + level 10 bonus
            assert.are.equal(3, active.charges)
            assert.is_true(math.abs(active.params.healPerKill - 0.01) < 1e-9)
        end)

        it("does not apply milestones below their level", function()
            local spark = give("spark", 1)[1]
            setLevel(spark, 4)
            cards.equip(1, spark)
            local active = cards.getRunEffects().actives[1]
            assert.are.equal(3, active.params.targets)
            assert.is_nil(active.params.stunDuration)
        end)

        it("replaces Ascendance's interval at level 15", function()
            local ascend = give("ascendance", 1)[1]
            setLevel(ascend, 15)
            cards.equip(1, ascend)
            assert.are.equal(3, cards.getRunEffects().stats.ascendanceInterval)
        end)

        it("describes milestones for the card screen", function()
            assert.are.equal("Strikes 4 enemies", cards.milestoneText(cards.getCard("spark"), 5))
            assert.are.equal("-", cards.milestoneText(cards.getCard("spark"), 7))
        end)

        it("lists reached milestones", function()
            local spark = give("spark", 1)[1]
            setLevel(spark, 12)
            cards.equip(1, spark)
            local levels = {}
            for _, milestone in ipairs(cards.getRunEffects().milestones) do
                table.insert(levels, milestone.level)
            end
            assert.are.same({ 5, 10 }, levels)
        end)
    end)

    describe("saving", function()
        it("survives a JSON round trip of the save data", function()
            meta.addGold(150)
            local opened = cards.buyPack(seededRng(9))
            cards.equip(2, opened[1].uid)

            local reloaded = json.decode(json.encode(data.get("meta.cards")))
            data.set("meta.cards", reloaded)

            assert.are.equal(3, #cards.getInstances())
            assert.are.equal(opened[1].uid, cards.getLoadout()[2])
            local hadRare = false
            for _, card in ipairs(opened) do
                if cards.tierRank(card.tier) >= cards.tierRank("rare") then hadRare = true end
            end
            assert.are.equal(hadRare and 0 or 1, cards.getPityCount("rare"))

            -- New cards keep getting unique uids after a reload
            meta.addGold(150)
            local more = cards.buyPack(seededRng(10))
            for _, card in ipairs(more) do
                for _, old in ipairs(opened) do
                    assert.are_not.equal(old.uid, card.uid)
                end
            end
            assert.are.equal(6, #cards.getInstances())
        end)
    end)
end)
