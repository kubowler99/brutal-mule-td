require("tests.spec_helper")
local upgrade_system = require("src.systems.upgrade_system")
local ability_registry = require("src.models.ability_registry")
local Hero = require("src.entities.hero")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")

describe("Upgrade System - New Ability Cards", function()
    local hero
    local upgradeCallback

    before_each(function()
        -- Create hero with no abilities initially
        hero = Hero:new(360, 1180)
        
        -- Create upgrade callback
        upgradeCallback = function() end
        
        -- Initialize upgrade system
        upgrade_system.initialize(hero, upgradeCallback)
    end)

    after_each(function()
        upgrade_system.cleanup()
        hero = nil
        upgradeCallback = nil
    end)

    describe("getAvailableUpgrades with new ability cards", function()
        it("should include new ability cards when hero has fewer than 5 abilities", function()
            -- Hero has 0 abilities, should offer new abilities
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Check if new_ability type cards are present
            local hasNewAbilityCard = false
            for _, upgrade in ipairs(available) do
                if upgrade.type == "new_ability" then
                    hasNewAbilityCard = true
                    break
                end
            end
            
            assert.is_true(hasNewAbilityCard, "Should offer new ability cards when hero has < 5 abilities")
        end)

        it("should include arcane_bolt as a new ability option when hero has no abilities", function()
            -- Hero has 0 abilities
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Find arcane_bolt new ability card
            local arcaneBoltCard = nil
            for _, upgrade in ipairs(available) do
                if upgrade.type == "new_ability" and upgrade.abilityId == "arcane_bolt" then
                    arcaneBoltCard = upgrade
                    break
                end
            end
            
            assert.is_not_nil(arcaneBoltCard, "Should offer arcane_bolt as new ability")
            assert.are.equal("new_ability_arcane_bolt", arcaneBoltCard.id)
            assert.are.equal("Arcane Bolt", arcaneBoltCard.name)
            assert.is_not_nil(arcaneBoltCard.description)
            assert.is_not_nil(arcaneBoltCard.iconType)
            assert.is_function(arcaneBoltCard.apply)
        end)

        it("should not include abilities hero already has", function()
            -- Add Arcane Bolt to hero
            local arcaneBolt = ArcaneBolt:new()
            hero:addAbility(arcaneBolt)
            
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Check that arcane_bolt is not offered as new ability
            for _, upgrade in ipairs(available) do
                if upgrade.type == "new_ability" and upgrade.abilityId == "arcane_bolt" then
                    assert.fail("Should not offer ability hero already has")
                end
            end
        end)

        it("should not include new ability cards when hero has 5 abilities", function()
            -- Fill all 5 slots
            for i = 1, 5 do
                local ability = ArcaneBolt:new()
                ability.id = "ability_" .. i  -- Give unique IDs
                hero:addAbility(ability)
            end
            
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Check that no new_ability cards are present
            for _, upgrade in ipairs(available) do
                assert.is_not_equal("new_ability", upgrade.type, 
                    "Should not offer new ability cards when all 5 slots full")
            end
        end)

        it("should include new ability cards when hero has 4 abilities", function()
            -- Add 4 abilities
            for i = 1, 4 do
                local ability = ArcaneBolt:new()
                ability.id = "ability_" .. i
                hero:addAbility(ability)
            end
            
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Check if new_ability type cards are present
            local hasNewAbilityCard = false
            for _, upgrade in ipairs(available) do
                if upgrade.type == "new_ability" then
                    hasNewAbilityCard = true
                    break
                end
            end
            
            assert.is_true(hasNewAbilityCard, "Should offer new ability cards when hero has 4 abilities")
        end)
    end)

    describe("new ability card structure", function()
        it("should have all required fields", function()
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Find a new ability card
            local newAbilityCard = nil
            for _, upgrade in ipairs(available) do
                if upgrade.type == "new_ability" then
                    newAbilityCard = upgrade
                    break
                end
            end
            
            if newAbilityCard then
                assert.is_not_nil(newAbilityCard.id, "Card should have id")
                assert.are.equal("new_ability", newAbilityCard.type, "Card should have type 'new_ability'")
                assert.is_not_nil(newAbilityCard.abilityId, "Card should have abilityId")
                assert.is_not_nil(newAbilityCard.name, "Card should have name")
                assert.is_not_nil(newAbilityCard.description, "Card should have description")
                assert.is_not_nil(newAbilityCard.iconType, "Card should have iconType")
                assert.is_function(newAbilityCard.apply, "Card should have apply function")
            end
        end)

        it("should have id in format 'new_ability_<abilityId>'", function()
            local available = upgrade_system.getAvailableUpgrades()
            
            for _, upgrade in ipairs(available) do
                if upgrade.type == "new_ability" then
                    local expectedId = "new_ability_" .. upgrade.abilityId
                    assert.are.equal(expectedId, upgrade.id, 
                        "Card id should be in format 'new_ability_<abilityId>'")
                end
            end
        end)
    end)

    describe("new ability card apply function", function()
        it("should add ability to hero when applied", function()
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Find arcane_bolt new ability card
            local arcaneBoltCard = nil
            for _, upgrade in ipairs(available) do
                if upgrade.type == "new_ability" and upgrade.abilityId == "arcane_bolt" then
                    arcaneBoltCard = upgrade
                    break
                end
            end
            
            assert.is_not_nil(arcaneBoltCard, "Should have arcane_bolt card")
            
            local initialCount = #hero.abilities
            local success = arcaneBoltCard.apply(hero)
            
            assert.is_true(success, "Apply should succeed")
            assert.are.equal(initialCount + 1, #hero.abilities, "Should add ability to hero")
            assert.are.equal("arcane_bolt", hero.abilities[1].id, "Should add correct ability")
        end)

        it("should return false when hero has 5 abilities", function()
            -- Fill all 5 slots
            for i = 1, 5 do
                local ability = ArcaneBolt:new()
                ability.id = "ability_" .. i
                hero:addAbility(ability)
            end
            
            -- Create a new ability card manually
            local newAbilityCard = {
                id = "new_ability_test",
                type = "new_ability",
                abilityId = "arcane_bolt",
                name = "Test Ability",
                description = "Test",
                iconType = "test",
                apply = function(h)
                    if not ability_registry.isUnlocked("arcane_bolt") then
                        return false
                    end
                    if #h.abilities >= 5 then
                        return false
                    end
                    local ability = ability_registry.createInstance("arcane_bolt")
                    if ability then
                        return h:addAbility(ability)
                    end
                    return false
                end
            }
            
            local success = newAbilityCard.apply(hero)
            
            assert.is_false(success, "Apply should fail when slots full")
            assert.are.equal(5, #hero.abilities, "Should not add ability when slots full")
        end)

        it("should create new instance of ability", function()
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Find arcane_bolt new ability card
            local arcaneBoltCard = nil
            for _, upgrade in ipairs(available) do
                if upgrade.type == "new_ability" and upgrade.abilityId == "arcane_bolt" then
                    arcaneBoltCard = upgrade
                    break
                end
            end
            
            arcaneBoltCard.apply(hero)
            
            -- Verify it's a proper instance
            assert.is_not_nil(hero.abilities[1])
            assert.are.equal("arcane_bolt", hero.abilities[1].id)
            assert.are.equal(1, hero.abilities[1].tier, "New ability should start at tier 1")
        end)
    end)

    describe("integration with generateCards", function()
        it("should include new ability cards in generated cards", function()
            local cards = upgrade_system.generateCards(3)
            
            -- Check if any card is a new ability
            local hasNewAbilityCard = false
            for _, card in ipairs(cards) do
                if card.type == "new_ability" then
                    hasNewAbilityCard = true
                    break
                end
            end
            
            -- With 0 abilities, we should get new ability cards
            assert.is_true(hasNewAbilityCard, "Generated cards should include new ability options")
        end)

        it("should not include new ability cards when hero has 5 abilities", function()
            -- Fill all 5 slots
            for i = 1, 5 do
                local ability = ArcaneBolt:new()
                ability.id = "ability_" .. i
                hero:addAbility(ability)
            end
            
            local cards = upgrade_system.generateCards(3)
            
            -- Check that no card is a new ability
            for _, card in ipairs(cards) do
                assert.is_not_equal("new_ability", card.type, 
                    "Should not generate new ability cards when slots full")
            end
        end)
    end)
end)
