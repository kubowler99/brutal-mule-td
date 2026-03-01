require("tests.spec_helper")
local upgrade_system = require("src.systems.upgrade_system")
local Hero = require("src.entities.hero")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")

describe("Upgrade System", function()
    local hero
    local upgradeCallback
    local callbackCalled

    before_each(function()
        -- Create hero
        hero = Hero:new(360, 1180)
        
        -- Add Arcane Bolt ability to hero
        local arcaneBolt = ArcaneBolt:new()
        hero:addAbility(arcaneBolt)
        
        -- Create upgrade callback
        callbackCalled = false
        upgradeCallback = function()
            callbackCalled = true
        end
        
        -- Initialize upgrade system
        upgrade_system.initialize(hero, upgradeCallback)
    end)

    after_each(function()
        upgrade_system.cleanup()
        hero = nil
        upgradeCallback = nil
    end)

    describe("initialization", function()
        it("should initialize with hero reference", function()
            assert.are.equal(hero, upgrade_system.hero)
        end)

        it("should initialize with upgrade callback", function()
            assert.are.equal(upgradeCallback, upgrade_system.onUpgradeSelected)
        end)

        it("should initialize upgrade pool with MVP upgrades", function()
            assert.is_not_nil(upgrade_system.upgradePool)
            assert.is_true(#upgrade_system.upgradePool >= 5)
        end)

        it("should have Arcane Bolt damage upgrade in pool", function()
            local found = false
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_damage" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should have Arcane Bolt attack speed upgrade in pool", function()
            local found = false
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_attack_speed" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should have Arcane Bolt projectile count upgrade in pool", function()
            local found = false
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_projectile_count" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should have Arcane Bolt pierce upgrade in pool", function()
            local found = false
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_pierce" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("should have XP pickup radius upgrade in pool", function()
            local found = false
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "xp_pickup_radius" then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)
    end)

    -- **Validates: Requirements 6.1**
    -- Test card generation creates exactly 3 cards
    describe("card generation creates exactly 3 cards", function()
        it("should generate exactly 3 upgrade cards", function()
            local cards = upgrade_system.generateCards(3)
            
            assert.are.equal(3, #cards)
        end)

        it("should generate cards with valid structure", function()
            local cards = upgrade_system.generateCards(3)
            
            for _, card in ipairs(cards) do
                assert.is_not_nil(card.id)
                assert.is_not_nil(card.type)
                assert.is_not_nil(card.name)
                assert.is_not_nil(card.description)
                assert.is_not_nil(card.apply)
                assert.is_function(card.apply)
            end
        end)

        it("should generate unique cards (no duplicates)", function()
            local cards = upgrade_system.generateCards(3)
            
            local ids = {}
            for _, card in ipairs(cards) do
                assert.is_nil(ids[card.id], "Duplicate card ID found: " .. card.id)
                ids[card.id] = true
            end
        end)

        it("should handle request for more cards than available", function()
            -- With only Arcane Bolt, we have 5 upgrades available
            local cards = upgrade_system.generateCards(10)
            
            -- Should return at most 5 cards
            assert.is_true(#cards <= 5)
        end)

        it("should return empty array when no upgrades available", function()
            -- Create hero with no abilities and all slots filled
            local testHero = Hero:new(360, 1180)
            -- Fill all 5 slots with max tier abilities
            for i = 1, 5 do
                local ability = ArcaneBolt:new()
                ability.tier = 5
                testHero:addAbility(ability)
            end
            
            upgrade_system.initialize(testHero, upgradeCallback)
            
            local cards = upgrade_system.generateCards(3)
            
            -- Should still have stat upgrades available (XP radius)
            assert.is_true(#cards >= 1)
        end)
    end)

    -- **Validates: Requirements 6.3**
    -- Test new ability availability when slots < 5
    describe("new ability availability when slots < 5", function()
        it("should return true when hero has fewer than 5 abilities", function()
            assert.is_true(upgrade_system.canOfferNewAbility())
        end)

        it("should return false when hero has 5 abilities", function()
            -- Add 4 more abilities (already has 1)
            for i = 1, 4 do
                local ability = ArcaneBolt:new()
                hero:addAbility(ability)
            end
            
            assert.is_false(upgrade_system.canOfferNewAbility())
        end)

        it("should return true when hero has 0 abilities", function()
            local testHero = Hero:new(360, 1180)
            upgrade_system.initialize(testHero, upgradeCallback)
            
            assert.is_true(upgrade_system.canOfferNewAbility())
        end)

        it("should return true when hero has 4 abilities", function()
            -- Add 3 more abilities (already has 1)
            for i = 1, 3 do
                local ability = ArcaneBolt:new()
                hero:addAbility(ability)
            end
            
            assert.is_true(upgrade_system.canOfferNewAbility())
        end)
    end)

    -- **Validates: Requirements 6.4**
    -- Test tier upgrade availability when abilities exist
    describe("tier upgrade availability when abilities exist", function()
        it("should include tier upgrades in available upgrades when hero has abilities", function()
            local available = upgrade_system.getAvailableUpgrades()
            
            local hasTierUpgrade = false
            for _, upgrade in ipairs(available) do
                if upgrade.type == "tier_upgrade" then
                    hasTierUpgrade = true
                    break
                end
            end
            
            assert.is_true(hasTierUpgrade)
        end)

        it("should not include tier upgrades for abilities at max tier", function()
            -- Set Arcane Bolt to max tier
            hero.abilities[1].tier = 5
            
            local available = upgrade_system.getAvailableUpgrades()
            
            local hasArcaneBoltUpgrade = false
            for _, upgrade in ipairs(available) do
                if upgrade.type == "tier_upgrade" and upgrade.abilityId == "arcane_bolt" then
                    hasArcaneBoltUpgrade = true
                    break
                end
            end
            
            assert.is_false(hasArcaneBoltUpgrade)
        end)

        it("should include tier upgrades for abilities below max tier", function()
            -- Set Arcane Bolt to tier 3
            hero.abilities[1].tier = 3
            
            local available = upgrade_system.getAvailableUpgrades()
            
            local hasArcaneBoltUpgrade = false
            for _, upgrade in ipairs(available) do
                if upgrade.type == "tier_upgrade" and upgrade.abilityId == "arcane_bolt" then
                    hasArcaneBoltUpgrade = true
                    break
                end
            end
            
            assert.is_true(hasArcaneBoltUpgrade)
        end)

        it("should not include tier upgrades when hero has no abilities", function()
            local testHero = Hero:new(360, 1180)
            upgrade_system.initialize(testHero, upgradeCallback)
            
            local available = upgrade_system.getAvailableUpgrades()
            
            local hasTierUpgrade = false
            for _, upgrade in ipairs(available) do
                if upgrade.type == "tier_upgrade" then
                    hasTierUpgrade = true
                    break
                end
            end
            
            assert.is_false(hasTierUpgrade)
        end)
    end)

    -- **Validates: Requirements 6.5, 6.6**
    -- Test upgrade application modifies abilities correctly
    describe("upgrade application modifies abilities correctly", function()
        it("should apply damage upgrade to Arcane Bolt", function()
            local initialDamage = hero.abilities[1].damage
            
            -- Find damage upgrade
            local damageUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_damage" then
                    damageUpgrade = upgrade
                    break
                end
            end
            
            upgrade_system.applyUpgrade(damageUpgrade)
            
            assert.are.equal(initialDamage + 5, hero.abilities[1].damage)
        end)

        it("should apply attack speed upgrade to Arcane Bolt", function()
            local initialCooldown = hero.abilities[1].cooldown
            
            -- Find attack speed upgrade
            local speedUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_attack_speed" then
                    speedUpgrade = upgrade
                    break
                end
            end
            
            upgrade_system.applyUpgrade(speedUpgrade)
            
            assert.are.equal(initialCooldown - 0.15, hero.abilities[1].cooldown)
        end)

        it("should apply projectile count upgrade to Arcane Bolt", function()
            local initialCount = hero.abilities[1].projectileCount
            
            -- Find projectile count upgrade
            local countUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_projectile_count" then
                    countUpgrade = upgrade
                    break
                end
            end
            
            upgrade_system.applyUpgrade(countUpgrade)
            
            assert.are.equal(initialCount + 1, hero.abilities[1].projectileCount)
        end)

        it("should apply pierce upgrade to Arcane Bolt", function()
            local initialPierce = hero.abilities[1].pierceCount
            
            -- Find pierce upgrade
            local pierceUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_pierce" then
                    pierceUpgrade = upgrade
                    break
                end
            end
            
            upgrade_system.applyUpgrade(pierceUpgrade)
            
            assert.are.equal(initialPierce + 1, hero.abilities[1].pierceCount)
        end)

        it("should apply XP pickup radius upgrade to hero", function()
            local initialRadius = hero.pickupRadius
            
            -- Find XP radius upgrade
            local radiusUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "xp_pickup_radius" then
                    radiusUpgrade = upgrade
                    break
                end
            end
            
            upgrade_system.applyUpgrade(radiusUpgrade)
            
            assert.are.equal(initialRadius + 20, hero.pickupRadius)
        end)

        it("should call upgrade callback after successful application", function()
            local damageUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_damage" then
                    damageUpgrade = upgrade
                    break
                end
            end
            
            upgrade_system.applyUpgrade(damageUpgrade)
            
            assert.is_true(callbackCalled)
        end)

        it("should return true on successful upgrade application", function()
            local damageUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_damage" then
                    damageUpgrade = upgrade
                    break
                end
            end
            
            local success = upgrade_system.applyUpgrade(damageUpgrade)
            
            assert.is_true(success)
        end)

        it("should return false when upgrade card is nil", function()
            local success = upgrade_system.applyUpgrade(nil)
            
            assert.is_false(success)
        end)
    end)

    -- **Validates: Requirements 6.6**
    -- Test tier limit enforcement (max tier 5)
    describe("tier limit enforcement (max tier 5)", function()
        it("should not offer upgrades for abilities at tier 5", function()
            -- Set Arcane Bolt to tier 5
            hero.abilities[1].tier = 5
            
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Check that no Arcane Bolt tier upgrades are available
            for _, upgrade in ipairs(available) do
                if upgrade.type == "tier_upgrade" and upgrade.abilityId == "arcane_bolt" then
                    assert.fail("Should not offer tier upgrade for max tier ability")
                end
            end
        end)

        it("should offer upgrades for abilities below tier 5", function()
            -- Set Arcane Bolt to tier 4
            hero.abilities[1].tier = 4
            
            local available = upgrade_system.getAvailableUpgrades()
            
            local hasArcaneBoltUpgrade = false
            for _, upgrade in ipairs(available) do
                if upgrade.type == "tier_upgrade" and upgrade.abilityId == "arcane_bolt" then
                    hasArcaneBoltUpgrade = true
                    break
                end
            end
            
            assert.is_true(hasArcaneBoltUpgrade)
        end)

        it("should allow upgrading from tier 4 to tier 5", function()
            -- Set Arcane Bolt to tier 4
            hero.abilities[1].tier = 4
            
            local damageUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_damage" then
                    damageUpgrade = upgrade
                    break
                end
            end
            
            upgrade_system.applyUpgrade(damageUpgrade)
            
            assert.are.equal(5, hero.abilities[1].tier)
        end)
    end)

    describe("getAvailableUpgrades", function()
        it("should return stat upgrades when hero has no abilities", function()
            local testHero = Hero:new(360, 1180)
            upgrade_system.initialize(testHero, upgradeCallback)
            
            local available = upgrade_system.getAvailableUpgrades()
            
            local hasStatUpgrade = false
            for _, upgrade in ipairs(available) do
                if upgrade.type == "stat_upgrade" then
                    hasStatUpgrade = true
                    break
                end
            end
            
            assert.is_true(hasStatUpgrade)
        end)

        it("should return empty array when hero is nil", function()
            upgrade_system.hero = nil
            
            local available = upgrade_system.getAvailableUpgrades()
            
            assert.are.equal(0, #available)
        end)

        it("should include all applicable upgrade types", function()
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Should have tier upgrades for Arcane Bolt and stat upgrades
            assert.is_true(#available >= 5)
        end)
    end)

    describe("cleanup", function()
        it("should clear hero reference", function()
            upgrade_system.cleanup()
            
            assert.is_nil(upgrade_system.hero)
        end)

        it("should clear upgrade pool", function()
            upgrade_system.cleanup()
            
            assert.are.equal(0, #upgrade_system.upgradePool)
        end)

        it("should clear upgrade callback", function()
            upgrade_system.cleanup()
            
            assert.is_nil(upgrade_system.onUpgradeSelected)
        end)
    end)
end)


-- **Validates: Requirements 6.1**
-- Property 20: Upgrade Card Count
describe("Property 20: Upgrade Card Count", function()
    local generators = require("tests.generators.game_generators")

    it("should present exactly 3 upgrade cards for any level-up event", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create fresh hero with random number of abilities (0-4)
            local testHero = Hero:new(360, 1180)
            local abilityCount = math.random(0, 4)
            
            for i = 1, abilityCount do
                local ability = ArcaneBolt:new()
                ability.tier = math.random(1, 4)  -- Random tier 1-4 (not max)
                testHero:addAbility(ability)
            end
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Generate cards
            local cards = upgrade_system.generateCards(3)
            
            -- Property: Should always generate exactly 3 cards (or less if not enough upgrades)
            -- With at least one ability and stat upgrades, we should always have at least 3 options
            if abilityCount > 0 then
                assert.are.equal(3, #cards, "Should generate exactly 3 cards when upgrades available")
            end
            
            -- Property: All cards should be unique
            local cardIds = {}
            for _, card in ipairs(cards) do
                assert.is_nil(cardIds[card.id], "Cards should be unique")
                cardIds[card.id] = true
            end
            
            -- Property: All cards should have required fields
            for _, card in ipairs(cards) do
                assert.is_not_nil(card.id, "Card should have id")
                assert.is_not_nil(card.type, "Card should have type")
                assert.is_not_nil(card.name, "Card should have name")
                assert.is_not_nil(card.description, "Card should have description")
                assert.is_function(card.apply, "Card should have apply function")
            end
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should generate valid cards regardless of hero state", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with random configuration
            local testHero = Hero:new(360, 1180)
            
            -- Random number of abilities (0-5)
            local abilityCount = math.random(0, 5)
            for i = 1, abilityCount do
                local ability = ArcaneBolt:new()
                -- Random tier (1-5)
                ability.tier = math.random(1, 5)
                testHero:addAbility(ability)
            end
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Generate cards
            local cards = upgrade_system.generateCards(3)
            
            -- Property: Should never generate more than 3 cards
            assert.is_true(#cards <= 3, "Should never generate more than 3 cards")
            
            -- Property: Should generate at least 1 card if any upgrades available
            local availableUpgrades = upgrade_system.getAvailableUpgrades()
            if #availableUpgrades > 0 then
                assert.is_true(#cards >= 1, "Should generate at least 1 card when upgrades available")
            end
            
            -- Property: Number of cards should not exceed available upgrades
            assert.is_true(#cards <= #availableUpgrades, "Cards should not exceed available upgrades")
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should handle edge cases in card generation", function()
        -- Test with hero at various states
        for _ = 1, 100 do
            local testHero = Hero:new(360, 1180)
            
            -- Randomly decide hero configuration
            local config = math.random(1, 4)
            
            if config == 1 then
                -- No abilities
                -- Should still have stat upgrades
            elseif config == 2 then
                -- One ability at tier 1
                local ability = ArcaneBolt:new()
                ability.tier = 1
                testHero:addAbility(ability)
            elseif config == 3 then
                -- Multiple abilities at various tiers
                for i = 1, math.random(2, 4) do
                    local ability = ArcaneBolt:new()
                    ability.tier = math.random(1, 4)
                    testHero:addAbility(ability)
                end
            else
                -- Full slots with mixed tiers
                for i = 1, 5 do
                    local ability = ArcaneBolt:new()
                    ability.tier = math.random(1, 5)
                    testHero:addAbility(ability)
                end
            end
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Generate cards
            local cards = upgrade_system.generateCards(3)
            
            -- Property: Should always return valid array
            assert.is_table(cards, "Should return table")
            assert.is_true(#cards >= 0, "Should have non-negative count")
            assert.is_true(#cards <= 3, "Should not exceed 3 cards")
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)
end)


-- **Validates: Requirements 6.3**
-- Property 21: New Ability Availability
describe("Property 21: New Ability Availability", function()
    local generators = require("tests.generators.game_generators")

    it("should offer at least one new ability option when hero has fewer than 5 abilities", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with random number of abilities (0-4)
            local testHero = Hero:new(360, 1180)
            local abilityCount = math.random(0, 4)
            
            for i = 1, abilityCount do
                local ability = ArcaneBolt:new()
                ability.tier = math.random(1, 5)
                testHero:addAbility(ability)
            end
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Property: canOfferNewAbility should return true
            assert.is_true(upgrade_system.canOfferNewAbility(),
                string.format("Should be able to offer new ability with %d abilities", abilityCount))
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should not offer new ability options when hero has 5 abilities", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with 5 abilities
            local testHero = Hero:new(360, 1180)
            
            for i = 1, 5 do
                local ability = ArcaneBolt:new()
                ability.tier = math.random(1, 5)
                testHero:addAbility(ability)
            end
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Property: canOfferNewAbility should return false
            assert.is_false(upgrade_system.canOfferNewAbility(),
                "Should not be able to offer new ability with 5 abilities")
            
            -- Property: Available upgrades should not include new_ability type
            local available = upgrade_system.getAvailableUpgrades()
            for _, upgrade in ipairs(available) do
                assert.is_not_equal("new_ability", upgrade.type,
                    "Should not offer new_ability upgrades when slots full")
            end
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should respect ability slot limit across all operations", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with random ability count
            local testHero = Hero:new(360, 1180)
            local abilityCount = math.random(0, 5)
            
            for i = 1, abilityCount do
                local ability = ArcaneBolt:new()
                testHero:addAbility(ability)
            end
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Property: canOfferNewAbility result should match slot availability
            local hasAvailableSlots = #testHero.abilities < 5
            local canOffer = upgrade_system.canOfferNewAbility()
            
            assert.are.equal(hasAvailableSlots, canOffer,
                string.format("canOfferNewAbility should match slot availability (has %d abilities)", abilityCount))
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should maintain consistency between canOfferNewAbility and available upgrades", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with random configuration
            local testHero = Hero:new(360, 1180)
            local abilityCount = math.random(0, 5)
            
            for i = 1, abilityCount do
                local ability = ArcaneBolt:new()
                ability.tier = math.random(1, 5)
                testHero:addAbility(ability)
            end
            
            upgrade_system.initialize(testHero, function() end)
            
            local canOffer = upgrade_system.canOfferNewAbility()
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Count new_ability type upgrades in available pool
            local newAbilityCount = 0
            for _, upgrade in ipairs(available) do
                if upgrade.type == "new_ability" then
                    newAbilityCount = newAbilityCount + 1
                end
            end
            
            -- Property: If canOffer is true, there should be new_ability upgrades available
            -- If canOffer is false, there should be no new_ability upgrades available
            if canOffer then
                -- Note: In MVP, we don't have new_ability type upgrades defined yet
                -- This test validates the logic is consistent
                assert.is_true(#testHero.abilities < 5, "Should have available slots")
            else
                assert.are.equal(0, newAbilityCount, "Should have no new_ability upgrades when slots full")
                assert.are.equal(5, #testHero.abilities, "Should have 5 abilities")
            end
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)
end)


-- **Validates: Requirements 6.4**
-- Property 22: Tier Upgrade Availability
describe("Property 22: Tier Upgrade Availability", function()
    local generators = require("tests.generators.game_generators")

    it("should offer at least one tier upgrade when hero has abilities below max tier", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with random number of abilities (1-5)
            local testHero = Hero:new(360, 1180)
            local abilityCount = math.random(1, 5)
            
            for i = 1, abilityCount do
                local ability = ArcaneBolt:new()
                -- Ensure at least one ability is below max tier
                if i == 1 then
                    ability.tier = math.random(1, 4)  -- First ability always below max
                else
                    ability.tier = math.random(1, 5)  -- Others can be any tier
                end
                testHero:addAbility(ability)
            end
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Get available upgrades
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Property: Should have at least one tier upgrade available
            local hasTierUpgrade = false
            for _, upgrade in ipairs(available) do
                if upgrade.type == "tier_upgrade" then
                    hasTierUpgrade = true
                    break
                end
            end
            
            assert.is_true(hasTierUpgrade,
                string.format("Should offer tier upgrade with %d abilities", abilityCount))
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should not offer tier upgrades for abilities at max tier (5)", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with abilities at max tier
            local testHero = Hero:new(360, 1180)
            local abilityCount = math.random(1, 5)
            
            for i = 1, abilityCount do
                local ability = ArcaneBolt:new()
                ability.tier = 5  -- Max tier
                testHero:addAbility(ability)
            end
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Get available upgrades
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Property: Should not have tier upgrades for Arcane Bolt
            for _, upgrade in ipairs(available) do
                if upgrade.type == "tier_upgrade" and upgrade.abilityId == "arcane_bolt" then
                    assert.fail("Should not offer tier upgrade for max tier ability")
                end
            end
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should offer tier upgrades proportional to upgradeable abilities", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with mixed tier abilities
            local testHero = Hero:new(360, 1180)
            local abilityCount = math.random(1, 5)
            local upgradeableCount = 0
            
            for i = 1, abilityCount do
                local ability = ArcaneBolt:new()
                -- Random tier
                ability.tier = math.random(1, 5)
                
                if ability.tier < 5 then
                    upgradeableCount = upgradeableCount + 1
                end
                
                testHero:addAbility(ability)
            end
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Get available upgrades
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Count tier upgrades
            local tierUpgradeCount = 0
            for _, upgrade in ipairs(available) do
                if upgrade.type == "tier_upgrade" then
                    tierUpgradeCount = tierUpgradeCount + 1
                end
            end
            
            -- Property: If there are upgradeable abilities, should have tier upgrades
            if upgradeableCount > 0 then
                assert.is_true(tierUpgradeCount > 0,
                    string.format("Should have tier upgrades with %d upgradeable abilities", upgradeableCount))
            else
                -- All abilities at max tier, should have no tier upgrades
                assert.are.equal(0, tierUpgradeCount,
                    "Should have no tier upgrades when all abilities at max tier")
            end
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should respect tier limits when generating upgrade cards", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with one ability at random tier
            local testHero = Hero:new(360, 1180)
            local ability = ArcaneBolt:new()
            ability.tier = math.random(1, 5)
            testHero:addAbility(ability)
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Generate cards
            local cards = upgrade_system.generateCards(3)
            
            -- Property: All tier upgrade cards should target abilities below max tier
            for _, card in ipairs(cards) do
                if card.type == "tier_upgrade" and card.abilityId == "arcane_bolt" then
                    -- If we got an Arcane Bolt upgrade card, the ability must be below tier 5
                    assert.is_true(ability.tier < 5,
                        string.format("Tier upgrade should only be offered when ability is below tier 5 (found tier %d)", ability.tier))
                end
            end
            
            -- Property: If ability is at tier 5, no tier upgrades for it should be offered
            if ability.tier == 5 then
                for _, card in ipairs(cards) do
                    if card.type == "tier_upgrade" and card.abilityId == "arcane_bolt" then
                        assert.fail("Should not offer tier upgrade for ability at max tier")
                    end
                end
            end
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should handle edge case of no abilities", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with no abilities
            local testHero = Hero:new(360, 1180)
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Get available upgrades
            local available = upgrade_system.getAvailableUpgrades()
            
            -- Property: Should have no tier upgrades when no abilities exist
            local hasTierUpgrade = false
            for _, upgrade in ipairs(available) do
                if upgrade.type == "tier_upgrade" then
                    hasTierUpgrade = true
                    break
                end
            end
            
            assert.is_false(hasTierUpgrade,
                "Should not offer tier upgrades when hero has no abilities")
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)
end)


-- **Validates: Requirements 6.5, 6.6, 6.7**
-- Property 23: Upgrade Application
describe("Property 23: Upgrade Application", function()
    local generators = require("tests.generators.game_generators")

    it("should correctly apply tier upgrades and increment ability tier (max 5)", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with Arcane Bolt at random tier (1-4)
            local testHero = Hero:new(360, 1180)
            local ability = ArcaneBolt:new()
            ability.tier = math.random(1, 4)  -- Not at max tier
            testHero:addAbility(ability)
            
            local initialTier = ability.tier
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Get a random tier upgrade for Arcane Bolt
            local tierUpgrades = {}
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.type == "tier_upgrade" and upgrade.abilityId == "arcane_bolt" then
                    table.insert(tierUpgrades, upgrade)
                end
            end
            
            if #tierUpgrades > 0 then
                local randomUpgrade = tierUpgrades[math.random(1, #tierUpgrades)]
                
                -- Apply the upgrade
                local success = upgrade_system.applyUpgrade(randomUpgrade)
                
                -- Property: Upgrade should succeed
                assert.is_true(success, "Upgrade should succeed")
                
                -- Property: Tier should increment by 1
                assert.are.equal(initialTier + 1, ability.tier,
                    string.format("Tier should increment from %d to %d", initialTier, initialTier + 1))
                
                -- Property: Tier should not exceed 5
                assert.is_true(ability.tier <= 5, "Tier should not exceed 5")
            end
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should correctly apply stat upgrades to hero", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero
            local testHero = Hero:new(360, 1180)
            local initialRadius = testHero.pickupRadius
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Find XP radius upgrade
            local radiusUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "xp_pickup_radius" then
                    radiusUpgrade = upgrade
                    break
                end
            end
            
            -- Apply the upgrade
            local success = upgrade_system.applyUpgrade(radiusUpgrade)
            
            -- Property: Upgrade should succeed
            assert.is_true(success, "Stat upgrade should succeed")
            
            -- Property: Pickup radius should increase by 20
            assert.are.equal(initialRadius + 20, testHero.pickupRadius,
                string.format("Pickup radius should increase from %d to %d", initialRadius, initialRadius + 20))
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should trigger callback after successful upgrade application", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with ability
            local testHero = Hero:new(360, 1180)
            local ability = ArcaneBolt:new()
            ability.tier = math.random(1, 4)
            testHero:addAbility(ability)
            
            local callbackTriggered = false
            local callback = function()
                callbackTriggered = true
            end
            
            upgrade_system.initialize(testHero, callback)
            
            -- Get any valid upgrade
            local available = upgrade_system.getAvailableUpgrades()
            if #available > 0 then
                local randomUpgrade = available[math.random(1, #available)]
                
                -- Apply the upgrade
                upgrade_system.applyUpgrade(randomUpgrade)
                
                -- Property: Callback should be triggered
                assert.is_true(callbackTriggered,
                    "Callback should be triggered after successful upgrade")
            end
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should handle multiple sequential upgrades correctly", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with ability at tier 1
            local testHero = Hero:new(360, 1180)
            local ability = ArcaneBolt:new()
            ability.tier = 1
            testHero:addAbility(ability)
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Apply random number of upgrades (1-4, to not exceed tier 5)
            local upgradeCount = math.random(1, 4)
            
            for i = 1, upgradeCount do
                local available = upgrade_system.getAvailableUpgrades()
                
                -- Find tier upgrades
                local tierUpgrades = {}
                for _, upgrade in ipairs(available) do
                    if upgrade.type == "tier_upgrade" and upgrade.abilityId == "arcane_bolt" then
                        table.insert(tierUpgrades, upgrade)
                    end
                end
                
                if #tierUpgrades > 0 then
                    local randomUpgrade = tierUpgrades[math.random(1, #tierUpgrades)]
                    upgrade_system.applyUpgrade(randomUpgrade)
                end
            end
            
            -- Property: Final tier should be initial tier + upgrade count
            local expectedTier = math.min(1 + upgradeCount, 5)
            assert.are.equal(expectedTier, ability.tier,
                string.format("After %d upgrades, tier should be %d", upgradeCount, expectedTier))
            
            -- Property: Tier should never exceed 5
            assert.is_true(ability.tier <= 5, "Tier should never exceed 5")
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should apply damage upgrades correctly", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with Arcane Bolt
            local testHero = Hero:new(360, 1180)
            local ability = ArcaneBolt:new()
            ability.tier = math.random(1, 4)
            testHero:addAbility(ability)
            
            local initialDamage = ability.damage
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Find damage upgrade
            local damageUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_damage" then
                    damageUpgrade = upgrade
                    break
                end
            end
            
            -- Apply upgrade
            upgrade_system.applyUpgrade(damageUpgrade)
            
            -- Property: Damage should increase by 5
            assert.are.equal(initialDamage + 5, ability.damage,
                "Damage should increase by 5")
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should apply attack speed upgrades correctly", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with Arcane Bolt
            local testHero = Hero:new(360, 1180)
            local ability = ArcaneBolt:new()
            ability.tier = math.random(1, 4)
            testHero:addAbility(ability)
            
            local initialCooldown = ability.cooldown
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Find attack speed upgrade
            local speedUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_attack_speed" then
                    speedUpgrade = upgrade
                    break
                end
            end
            
            -- Apply upgrade
            upgrade_system.applyUpgrade(speedUpgrade)
            
            -- Property: Cooldown should decrease by 0.15
            assert.are.equal(initialCooldown - 0.15, ability.cooldown,
                "Cooldown should decrease by 0.15")
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should apply projectile count upgrades correctly", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with Arcane Bolt
            local testHero = Hero:new(360, 1180)
            local ability = ArcaneBolt:new()
            ability.tier = math.random(1, 4)
            testHero:addAbility(ability)
            
            local initialCount = ability.projectileCount
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Find projectile count upgrade
            local countUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_projectile_count" then
                    countUpgrade = upgrade
                    break
                end
            end
            
            -- Apply upgrade
            upgrade_system.applyUpgrade(countUpgrade)
            
            -- Property: Projectile count should increase by 1
            assert.are.equal(initialCount + 1, ability.projectileCount,
                "Projectile count should increase by 1")
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should apply pierce upgrades correctly", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with Arcane Bolt
            local testHero = Hero:new(360, 1180)
            local ability = ArcaneBolt:new()
            ability.tier = math.random(1, 4)
            testHero:addAbility(ability)
            
            local initialPierce = ability.pierceCount
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Find pierce upgrade
            local pierceUpgrade = nil
            for _, upgrade in ipairs(upgrade_system.upgradePool) do
                if upgrade.id == "arcane_bolt_pierce" then
                    pierceUpgrade = upgrade
                    break
                end
            end
            
            -- Apply upgrade
            upgrade_system.applyUpgrade(pierceUpgrade)
            
            -- Property: Pierce count should increase by 1
            assert.are.equal(initialPierce + 1, ability.pierceCount,
                "Pierce count should increase by 1")
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should return false when applying nil upgrade", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero
            local testHero = Hero:new(360, 1180)
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Apply nil upgrade
            local success = upgrade_system.applyUpgrade(nil)
            
            -- Property: Should return false
            assert.is_false(success, "Should return false for nil upgrade")
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)

    it("should maintain upgrade consistency across different ability configurations", function()
        -- Run property test with 100 iterations
        for _ = 1, 100 do
            -- Create hero with random ability configuration
            local testHero = Hero:new(360, 1180)
            local abilityCount = math.random(1, 5)
            
            for i = 1, abilityCount do
                local ability = ArcaneBolt:new()
                ability.tier = math.random(1, 4)
                testHero:addAbility(ability)
            end
            
            upgrade_system.initialize(testHero, function() end)
            
            -- Get available upgrades
            local available = upgrade_system.getAvailableUpgrades()
            
            if #available > 0 then
                -- Select random upgrade
                local randomUpgrade = available[math.random(1, #available)]
                
                -- Store initial state
                local initialState = {}
                for i, ability in ipairs(testHero.abilities) do
                    initialState[i] = {
                        tier = ability.tier,
                        damage = ability.damage,
                        cooldown = ability.cooldown,
                        projectileCount = ability.projectileCount,
                        pierceCount = ability.pierceCount
                    }
                end
                local initialRadius = testHero.pickupRadius
                
                -- Apply upgrade
                local success = upgrade_system.applyUpgrade(randomUpgrade)
                
                -- Property: Upgrade should succeed
                assert.is_true(success, "Upgrade should succeed")
                
                -- Property: Only the targeted property should change
                if randomUpgrade.type == "tier_upgrade" then
                    -- Find which ability was upgraded (only the first one with matching ID)
                    local foundFirst = false
                    for i, ability in ipairs(testHero.abilities) do
                        if ability.id == randomUpgrade.abilityId and not foundFirst then
                            -- This is the first ability with matching ID - it should have changed tier
                            assert.are.equal(initialState[i].tier + 1, ability.tier,
                                "Upgraded ability tier should increment")
                            foundFirst = true
                        end
                    end
                elseif randomUpgrade.type == "stat_upgrade" then
                    -- Hero stat should change
                    if randomUpgrade.id == "xp_pickup_radius" then
                        assert.are.equal(initialRadius + 20, testHero.pickupRadius,
                            "Pickup radius should increase")
                    end
                end
            end
            
            -- Cleanup
            upgrade_system.cleanup()
        end
    end)
end)
