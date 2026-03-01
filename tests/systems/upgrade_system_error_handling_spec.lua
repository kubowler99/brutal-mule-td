require("tests.spec_helper")
local upgrade_system = require("src.systems.upgrade_system")
local Hero = require("src.entities.hero")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")

describe("Upgrade System Error Handling", function()
    local hero
    local upgradeCallback

    before_each(function()
        hero = Hero:new(360, 1180)
        upgradeCallback = function() end
        upgrade_system.initialize(hero, upgradeCallback)
    end)

    after_each(function()
        upgrade_system.cleanup()
        hero = nil
    end)

    describe("tier limit validation", function()
        it("should not allow upgrading ability at tier 5", function()
            -- Add Arcane Bolt at max tier
            local ability = ArcaneBolt:new()
            ability.tier = 5
            hero:addAbility(ability)
            
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- Try to apply damage upgrade
            local damageUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_damage" then
                    damageUpgrade = upgrade
                    break
                end
            end
            
            -- Should return false because ability is at max tier
            local success = upgrade_system.applyUpgrade(damageUpgrade)
            assert.is_false(success)
            
            -- Tier should remain at 5
            assert.are.equal(5, ability.tier)
        end)

        it("should allow upgrading ability below tier 5", function()
            -- Add Arcane Bolt at tier 4
            local ability = ArcaneBolt:new()
            ability.tier = 4
            hero:addAbility(ability)
            
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- Apply damage upgrade
            local damageUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_damage" then
                    damageUpgrade = upgrade
                    break
                end
            end
            
            -- Should succeed
            local success = upgrade_system.applyUpgrade(damageUpgrade)
            assert.is_true(success)
            
            -- Tier should increment to 5
            assert.are.equal(5, ability.tier)
        end)

        it("should not offer tier upgrades for abilities at tier 5", function()
            -- Add Arcane Bolt at max tier
            local ability = ArcaneBolt:new()
            ability.tier = 5
            hero:addAbility(ability)
            
            upgrade_system.initialize(hero, upgradeCallback)
            
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Should not include Arcane Bolt tier upgrades
            for _, upgrade in ipairs(available) do
                if upgrade.type == "tier_upgrade" and upgrade.abilityId == "arcane_bolt" then
                    assert.fail("Should not offer tier upgrade for max tier ability")
                end
            end
        end)
    end)

    describe("ability slot limit validation", function()
        it("should not allow adding new ability when 5 slots are full", function()
            -- Fill all 5 slots
            for i = 1, 5 do
                local ability = ArcaneBolt:new()
                hero:addAbility(ability)
            end
            
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- canOfferNewAbility should return false
            assert.is_false(upgrade_system.canOfferNewAbility())
        end)

        it("should allow adding new ability when slots < 5", function()
            -- Add only 3 abilities
            for i = 1, 3 do
                local ability = ArcaneBolt:new()
                hero:addAbility(ability)
            end
            
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- canOfferNewAbility should return true
            assert.is_true(upgrade_system.canOfferNewAbility())
        end)

        it("should not offer new_ability upgrades when slots are full", function()
            -- Fill all 5 slots
            for i = 1, 5 do
                local ability = ArcaneBolt:new()
                hero:addAbility(ability)
            end
            
            upgrade_system.initialize(hero, upgradeCallback)
            
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Should not include new_ability type upgrades
            for _, upgrade in ipairs(available) do
                assert.is_not_equal("new_ability", upgrade.type,
                    "Should not offer new_ability upgrades when slots full")
            end
        end)
    end)

    describe("empty pool fallback", function()
        it("should return empty array when no upgrades available", function()
            -- Create hero with all abilities at max tier and all slots full
            for i = 1, 5 do
                local ability = ArcaneBolt:new()
                ability.tier = 5
                hero:addAbility(ability)
            end
            
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- Get available upgrades (should only have stat upgrades)
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Should still have stat upgrades (XP radius)
            assert.is_true(#available >= 1)
        end)

        it("should handle generateCards with no available upgrades gracefully", function()
            -- Create scenario with no tier upgrades available
            for i = 1, 5 do
                local ability = ArcaneBolt:new()
                ability.tier = 5
                hero:addAbility(ability)
            end
            
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- Generate cards - should still work with stat upgrades
            local cards = upgrade_system.generateCards(3)
            
            -- Should return at least stat upgrades
            assert.is_true(#cards >= 1)
        end)
    end)

    describe("nil and invalid input handling", function()
        it("should handle nil upgradeCard in applyUpgrade", function()
            local success = upgrade_system.applyUpgrade(nil)
            assert.is_false(success)
        end)

        it("should handle invalid upgradeCard type in applyUpgrade", function()
            local success = upgrade_system.applyUpgrade("not a table")
            assert.is_false(success)
        end)

        it("should handle upgradeCard without apply function", function()
            local invalidCard = {
                id = "invalid",
                type = "tier_upgrade",
                name = "Invalid"
            }
            
            local success = upgrade_system.applyUpgrade(invalidCard)
            assert.is_false(success)
        end)

        it("should handle nil hero in generateCards", function()
            upgrade_system.hero = nil
            local cards = upgrade_system.generateCards(3)
            assert.are.equal(0, #cards)
        end)

        it("should handle nil hero in getAvailableUpgrades", function()
            upgrade_system.hero = nil
            local available = upgrade_system.getAvailableUpgrades()
            assert.are.equal(0, #available)
        end)

        it("should handle nil hero in canOfferNewAbility", function()
            upgrade_system.hero = nil
            local canOffer = upgrade_system.canOfferNewAbility()
            assert.is_false(canOffer)
        end)

        it("should handle invalid count parameter in generateCards", function()
            local ability = ArcaneBolt:new()
            hero:addAbility(ability)
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- Should default to 3 when count is invalid
            local cards = upgrade_system.generateCards("invalid")
            assert.is_true(#cards <= 3)
        end)

        it("should handle negative count parameter in generateCards", function()
            local ability = ArcaneBolt:new()
            hero:addAbility(ability)
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- Should default to 3 when count is negative
            local cards = upgrade_system.generateCards(-5)
            assert.is_true(#cards <= 3)
        end)
    end)

    describe("ability validation", function()
        it("should handle hero with invalid abilities array", function()
            hero.abilities = "not an array"
            upgrade_system.initialize(hero, upgradeCallback)
            
            local available = upgrade_system.getAvailableUpgrades()
            assert.are.equal(0, #available)
        end)

        it("should handle hero with nil abilities array", function()
            hero.abilities = nil
            upgrade_system.initialize(hero, upgradeCallback)
            
            local canOffer = upgrade_system.canOfferNewAbility()
            assert.is_false(canOffer)
        end)

        it("should handle ability with invalid tier value", function()
            local ability = ArcaneBolt:new()
            ability.tier = "not a number"
            hero:addAbility(ability)
            
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- Should still work, treating invalid tier as 1
            local available = upgrade_system.getAvailableUpgrades()
            assert.is_true(#available > 0)
        end)

        it("should handle ability with nil tier value", function()
            local ability = ArcaneBolt:new()
            ability.tier = nil
            hero:addAbility(ability)
            
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- Should still work, treating nil tier as 1
            local available = upgrade_system.getAvailableUpgrades()
            assert.is_true(#available > 0)
        end)
    end)

    describe("upgrade application with pcall protection", function()
        it("should handle errors in upgrade apply function", function()
            local ability = ArcaneBolt:new()
            hero:addAbility(ability)
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- Create upgrade with failing apply function
            local badUpgrade = {
                id = "bad_upgrade",
                type = "tier_upgrade",
                abilityId = "arcane_bolt",
                name = "Bad Upgrade",
                apply = function(hero)
                    error("Intentional error for testing")
                end
            }
            
            -- Should return false and not crash
            local success = upgrade_system.applyUpgrade(badUpgrade)
            assert.is_false(success)
        end)

        it("should handle upgrade apply function returning false", function()
            local ability = ArcaneBolt:new()
            hero:addAbility(ability)
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- Create upgrade that returns false
            local failingUpgrade = {
                id = "failing_upgrade",
                type = "tier_upgrade",
                abilityId = "arcane_bolt",
                name = "Failing Upgrade",
                apply = function(hero)
                    return false
                end
            }
            
            -- Should return false
            local success = upgrade_system.applyUpgrade(failingUpgrade)
            assert.is_false(success)
        end)
    end)

    describe("attempting to upgrade non-existent ability", function()
        it("should return false when upgrading ability hero doesn't have", function()
            -- Hero has no abilities
            upgrade_system.initialize(hero, upgradeCallback)
            
            -- Try to apply Arcane Bolt upgrade
            local damageUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_damage" then
                    damageUpgrade = upgrade
                    break
                end
            end
            
            -- Should return false because hero doesn't have Arcane Bolt
            local success = upgrade_system.applyUpgrade(damageUpgrade)
            assert.is_false(success)
        end)
    end)
end)
