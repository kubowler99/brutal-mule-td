require("tests.spec_helper")

local ability_data_loader = require("src.models.ability_data_loader")
local ability_registry = require("src.models.ability_registry")
local config_loader = require("src.models.config_loader")
local synergy = require("src.models.synergy")
local upgrade_system = require("src.systems.upgrade_system")
local Hero = require("src.entities.hero")
local UpgradeCard = require("src.ui.upgrade_card")

describe("Synergy", function()
    local function ability(id)
        return { id = id }
    end

    before_each(function()
        ability_data_loader.initialize()
        ability_registry.initialize()
        config_loader.initialize()
    end)

    after_each(function()
        upgrade_system.cleanup()
    end)

    it("reads ability tags from abilities.json", function()
        assert.are.same({ "projectile", "frost" }, synergy.getTags("frost_shard"))
        assert.are.same({}, synergy.getTags("unknown"))
        assert.are.same({}, synergy.getTags(nil))
    end)

    it("finds tags shared by two or more abilities", function()
        local abilities = { ability("arcane_bolt"), ability("frost_shard"), ability("frost_nova") }
        assert.are.same({ "frost", "projectile" }, synergy.getSharedTags(abilities))
    end)

    it("gives no bonus to a single ability", function()
        assert.are.equal(0, synergy.getDamageBonus({ ability("arcane_bolt") }))
    end)

    it("adds 10% damage per shared tag to hero stats", function()
        local hero = Hero:new(45, 1200)
        hero:addAbility(ability("arcane_bolt"))
        hero:addAbility(ability("frost_shard"))
        hero:addAbility(ability("frost_nova"))

        -- Shared: projectile (bolt, shard) and frost (shard, nova)
        assert.is_true(math.abs(hero:getStats().damageMultiplier - 1.2) < 1e-9)
    end)

    it("counts a tag once however many abilities share it", function()
        local abilities = { ability("arcane_bolt"), ability("arcane_might"), ability("quickening") }
        assert.are.same({ "arcane" }, synergy.getSharedTags(abilities))
        assert.is_true(math.abs(synergy.getDamageBonus(abilities) - 0.1) < 1e-9)
    end)

    it("doubles the draft weight of cards that share a tag", function()
        local abilities = { ability("arcane_bolt") }
        assert.are.equal(2, synergy.getDraftWeight({ abilityId = "frost_shard" }, abilities))
        assert.are.equal(1, synergy.getDraftWeight({ abilityId = "frost_nova" }, abilities))
        assert.are.equal(1, synergy.getDraftWeight({ id = "wall_repair" }, abilities))
    end)

    describe("level-up cards", function()
        local originalRandom

        before_each(function()
            originalRandom = math.random
        end)

        after_each(function()
            math.random = originalRandom
        end)

        it("carries tags and marks cards that share one", function()
            local hero = Hero:new(45, 1200)
            hero:addAbility(ability_registry.createInstance("arcane_bolt"))
            upgrade_system.initialize(hero, function() end)

            local cards = upgrade_system.generateCards(#upgrade_system.getAvailableUpgrades())
            local byId = {}
            for _, card in ipairs(cards) do byId[card.id] = card end

            assert.are.same({ "projectile", "frost" }, byId.new_ability_frost_shard.tags)
            assert.is_true(byId.new_ability_frost_shard.sharesTag)
            assert.is_false(byId.new_ability_frost_nova.sharesTag)
            assert.is_false(byId.wall_repair.sharesTag)
        end)

        it("draws cards in proportion to their draft weight", function()
            local hero = Hero:new(45, 1200)
            hero:addAbility(ability_registry.createInstance("arcane_bolt"))
            upgrade_system.initialize(hero, function() end)

            local available = upgrade_system.getAvailableUpgrades()
            local totalWeight = 0
            for _, card in ipairs(available) do
                totalWeight = totalWeight + synergy.getDraftWeight(card, hero.abilities)
            end

            -- A roll just under 1 picks the last card; just over 0 the first
            math.random = function(...)
                if select("#", ...) == 0 then return 0.999999 end
                return originalRandom(...)
            end
            assert.are.equal(available[#available].id, upgrade_system.generateCards(1)[1].id)

            math.random = function(...)
                if select("#", ...) == 0 then return 0 end
                return originalRandom(...)
            end
            assert.are.equal(available[1].id, upgrade_system.generateCards(1)[1].id)
            assert.is_true(totalWeight > #available)
        end)

        it("shows tags on the card, in gold when they match", function()
            local card = UpgradeCard:new(100, 100, { name = "X", description = "Y", tags = { "frost" }, sharesTag = true })
            assert.are.equal("frost", card.tagsText.text)

            local plain = UpgradeCard:new(100, 100, { name = "X", description = "Y" })
            assert.is_nil(plain.tagsText)
        end)
    end)
end)
