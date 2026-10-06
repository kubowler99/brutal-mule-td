-- Property tests for the card collection: random sequences of buying,
-- merging, fusing, and equipping never leave a card with an unknown card id,
-- an unknown tier, or a level outside 1..15, and never lose gold.

require("tests.spec_helper")

local data = require("src.models.data")
local meta = require("src.models.meta_progression")
local cards = require("src.models.card_collection")

local function seededRng(seed)
    local state = seed
    return function()
        state = (state * 1103515245 + 12345) % 2147483648
        return state / 2147483648
    end
end

--- Uids of unequipped cards in a tier, excluding one uid
local function spare(tier, exclude)
    local uids = {}
    for _, instance in ipairs(cards.getInstances()) do
        if instance.tier == tier and instance.uid ~= exclude and not cards.isEquipped(instance.uid) then
            table.insert(uids, instance.uid)
        end
    end
    return uids
end

local function take(list, count)
    local taken = {}
    for i = 1, count do taken[i] = list[i] end
    return taken
end

describe("Card collection properties", function()
    before_each(function()
        cards.setDefinitions(nil)
        meta.setDefinitions(nil)
        data.startSandbox()
        data.set("meta", {})
    end)

    after_each(function()
        data.stopSandbox(false)
    end)

    it("keeps every card valid through random buys, merges, fusions, and equips", function()
        for seed = 1, 30 do
            data.set("meta", {})
            local rng = seededRng(seed)
            meta.addGold(150 * 60)
            local tiers = { "common", "uncommon", "rare", "legendary", "mythic" }

            for _ = 1, 120 do
                local action = math.floor(rng() * 4)
                local tier = tiers[math.floor(rng() * #tiers) + 1]
                if action == 0 then
                    local goldBefore = meta.getGold()
                    local opened = cards.buyPack(rng)
                    if opened then
                        assert.are.equal(goldBefore - cards.getPackPrice(), meta.getGold())
                    else
                        assert.are.equal(goldBefore, meta.getGold())
                    end
                elseif action == 1 then
                    local candidates = spare(tier)
                    local target = candidates[1]
                    local cost = target and cards.mergeCost(cards.getInstance(target).level)
                    local sacrifices = cost and spare(tier, target)
                    if sacrifices and #sacrifices >= cost then
                        local before = cards.getInstance(target).level
                        assert.is_true(cards.merge(target, take(sacrifices, cost)))
                        assert.are.equal(before + 1, cards.getInstance(target).level)
                    end
                elseif action == 2 then
                    local cost = cards.fusionCost(tier)
                    local uids = spare(tier)
                    if cost and #uids >= cost then
                        local count = #cards.getInstances()
                        local fused = cards.fuse(take(uids, cost), rng)
                        assert.are.equal(cards.nextTier(tier), fused.tier)
                        assert.are.equal(count - cost + 1, #cards.getInstances())
                    end
                else
                    local instances = cards.getInstances()
                    if #instances > 0 then
                        local pick = instances[math.floor(rng() * #instances) + 1]
                        local slot = math.floor(rng() * cards.getLoadoutSlots()) + 1
                        assert.is_true(cards.equip(slot, pick.uid))
                    end
                end

                for _, instance in ipairs(cards.getInstances()) do
                    local card = cards.getCard(instance.cardId)
                    assert.is_not_nil(card, "unknown card " .. tostring(instance.cardId))
                    assert.are.equal(card.tier, instance.tier)
                    assert.is_true(instance.level >= 1 and instance.level <= cards.getMaxLevel())
                end
                local equipped = {}
                for _, uid in pairs(cards.getLoadout()) do
                    assert.is_nil(equipped[uid], "card equipped twice")
                    equipped[uid] = true
                    assert.is_not_nil(cards.getInstance(uid))
                end
                assert.is_true(meta.getGold() >= 0)
            end
        end
    end)
end)
