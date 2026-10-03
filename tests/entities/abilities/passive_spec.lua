require("tests.spec_helper")

local ability_data_loader = require("src.models.ability_data_loader")
local ability_registry = require("src.models.ability_registry")
local upgrade_system = require("src.systems.upgrade_system")
local Hero = require("src.entities.hero")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")
local FrostNova = require("src.entities.abilities.frost_nova")
local Walker = require("src.entities.walker")

describe("Passive abilities", function()
    local hero

    before_each(function()
        ability_data_loader.initialize()
        ability_registry.initialize()
        hero = Hero:new(45, 1200)
    end)

    after_each(function()
        upgrade_system.cleanup()
    end)

    local function addPassive(id)
        local passive = ability_registry.createInstance(id)
        hero:addAbility(passive)
        return passive
    end

    describe("hero stats", function()
        it("starts at neutral multipliers", function()
            local stats = hero:getStats()
            assert.are.equal(1, stats.damageMultiplier)
            assert.are.equal(1, stats.cooldownMultiplier)
        end)

        it("Arcane Might adds 10% damage per tier", function()
            local might = addPassive("arcane_might")
            assert.is_true(math.abs(hero:getStats().damageMultiplier - 1.1) < 1e-9)

            might:upgrade()
            might:upgrade()
            assert.is_true(math.abs(hero:getStats().damageMultiplier - 1.3) < 1e-9)
        end)

        it("Quickening shortens cooldowns 8% per tier", function()
            local quickening = addPassive("quickening")
            for _ = 1, 4 do quickening:upgrade() end

            assert.are.equal(5, quickening.tier)
            assert.is_true(math.abs(hero:getStats().cooldownMultiplier - 0.6) < 1e-9)
        end)

        it("never lowers the cooldown multiplier below 0.4", function()
            local quickening = addPassive("quickening")
            quickening.perTier = -0.5
            quickening.tier = 5

            assert.are.equal(0.4, hero:getStats().cooldownMultiplier)
        end)

        it("does not exceed tier 5", function()
            local might = addPassive("arcane_might")
            for _ = 1, 10 do might:upgrade() end
            assert.are.equal(5, might.tier)
        end)
    end)

    describe("effect on active abilities", function()
        it("never fires a passive", function()
            local might = addPassive("arcane_might")
            assert.is_false(might:canActivate(1000))
        end)

        it("scales Arcane Bolt cooldown by the cooldown multiplier", function()
            local bolt = ArcaneBolt:new()
            bolt.lastActivation = 0

            assert.is_false(bolt:canActivate(bolt.cooldown * 0.5))
            assert.is_true(bolt:canActivate(bolt.cooldown * 0.5, { cooldownMultiplier = 0.5 }))
        end)

        it("scales Arcane Bolt projectile damage by the damage multiplier", function()
            local bolt = ArcaneBolt:new()
            local fired = {}
            local projectilePool = {
                get = function()
                    local projectile = { activate = function(self, x, y, tx, ty, speed, damage) self.damage = damage end }
                    table.insert(fired, projectile)
                    return projectile
                end,
            }
            bolt:canActivate(10)
            bolt:activate(45, 1200, { { x = 360, y = 500, isActive = true } }, projectilePool, nil,
                { damageMultiplier = 1.5 })

            assert.are.equal(bolt.damage * 1.5, fired[1].damage)
        end)

        it("scales Frost Nova damage by the damage multiplier", function()
            local nova = FrostNova:new()
            local walker = Walker:new(nil)
            walker:activate(360, 1100, 360)
            walker.health = 100
            walker.maxHealth = 100

            nova:canActivate(10)
            nova:activate(45, 1200, { walker }, nil, nil, { damageMultiplier = 2 })

            assert.are.equal(100 - nova.damage * 2, walker.health)
        end)
    end)

    describe("upgrade cards", function()
        it("offers passives as new ability cards", function()
            upgrade_system.initialize(hero, function() end)
            local offered = {}
            for _, card in ipairs(upgrade_system.getAvailableUpgrades()) do
                if card.type == "new_ability" then
                    offered[card.abilityId] = true
                end
            end
            assert.is_true(offered.arcane_might)
            assert.is_true(offered.quickening)
        end)

        it("raises the passive tier through its upgrade card", function()
            local might = addPassive("arcane_might")
            upgrade_system.initialize(hero, function() end)

            local tierCard
            for _, card in ipairs(upgrade_system.getAvailableUpgrades()) do
                if card.type == "tier_upgrade" and card.abilityId == "arcane_might" then
                    tierCard = card
                end
            end
            assert.is_not_nil(tierCard)

            assert.is_true(upgrade_system.applyUpgrade(tierCard))
            assert.are.equal(2, might.tier)
        end)
    end)
end)
