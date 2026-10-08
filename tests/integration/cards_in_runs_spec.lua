-- Integration tests: equipped cards change a run through the game
-- controller, meta progression, abilities, and the game scene

require("tests.spec_helper")

local data = require("src.models.data")
local meta = require("src.models.meta_progression")
local cards = require("src.models.card_collection")
local card_powers = require("src.systems.card_powers")
local game_controller = require("src.controllers.game_controller")
local game_state = require("src.models.game_state")
local Hero = require("src.entities.hero")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")

--- Give one card at a level and equip it in a slot
local function equipCard(cardId, slot, level)
    local saved = data.get("meta.cards") or {}
    saved.nextUid = saved.nextUid or 1
    saved.instances = saved.instances or {}
    saved.loadout = saved.loadout or {}
    saved.pity = saved.pity or {}
    local uid = "c" .. saved.nextUid
    saved.nextUid = saved.nextUid + 1
    saved.instances[uid] = { cardId = cardId, level = level or 1 }
    data.set("meta.cards", saved)
    assert.is_true(cards.equip(slot, uid))
    return uid
end

describe("Cards in runs", function()
    local sceneGroup

    before_each(function()
        cards.setDefinitions(nil)
        meta.setDefinitions(nil)
        data.startSandbox()
        data.set("meta", {})
        sceneGroup = display.newGroup()
    end)

    after_each(function()
        game_controller.cleanup()
        data.stopSandbox(false)
    end)

    describe("run bonuses", function()
        it("adds passive card stats to the bonuses they cover and ignores the rest", function()
            local bonuses = meta.getRunBonuses(nil, {
                damageMultiplier = 0.04, wallHealth = 10, goldMultiplier = 0.05,
                extraAbilitySlots = 1, startXP = 20, burnChance = 0.1,
            })
            assert.is_true(math.abs(bonuses.damageMultiplier - 1.04) < 1e-9)
            assert.are.equal(10, bonuses.wallHealth)
            assert.is_true(math.abs(bonuses.goldMultiplier - 1.05) < 1e-9)
            assert.are.equal(1, bonuses.extraAbilitySlots)
            assert.are.equal(20, bonuses.startXP)
            assert.is_nil(bonuses.burnChance)
        end)

        it("scales run gold by the gold multiplier (Gold Pouch)", function()
            local stats = { enemiesDefeated = 100, finalLevel = 10, goldMultiplier = 1.1 }
            assert.are.equal(math.floor((100 + 50) * 1.1), meta.goldForRun(stats))
        end)
    end)

    describe("starting a run", function()
        it("applies equipped passive cards", function()
            equipCard("stone_mortar", 1)
            equipCard("head_start", 2)
            equipCard("gold_pouch", 3)
            game_controller.initialize(sceneGroup)

            assert.are.equal(110, game_controller.getWall().maxHealth)
            assert.are.equal(110, game_controller.getWall().health)
            assert.are.equal(20, game_controller.getHero().xp)
            assert.is_true(math.abs(game_state.getStatistics().goldMultiplier - 1.05) < 1e-9)
        end)

        it("never starts a run with a full level of XP", function()
            local uid = equipCard("head_start", 1, 15)
            game_controller.initialize(sceneGroup)
            local hero = game_controller.getHero()
            assert.are.equal(1, hero.level)
            assert.are.equal(hero.xpRequired - 1, hero.xp)
        end)

        it("gives the hero a sixth ability slot (Sixth Seal)", function()
            equipCard("sixth_seal", 1)
            game_controller.initialize(sceneGroup)
            assert.are.equal(6, game_controller.getHero():getMaxAbilities())
        end)

        it("starts active cards with their charges", function()
            equipCard("spark", 1, 10)
            game_controller.initialize(sceneGroup)
            local hud = card_powers.getHudActives()
            assert.are.equal(1, #hud)
            assert.are.equal(3, hud[1].chargesLeft)
        end)
    end)

    describe("level-ups", function()
        it("shows another draft instead of resuming when an extra pick is due", function()
            game_controller.initialize(sceneGroup)
            local drafts = 0
            game_controller.onLevelUpCallback = function() drafts = drafts + 1 end
            game_controller.pendingPicks = 1

            game_controller.onUpgradeSelected(nil)
            assert.are.equal(1, drafts)
            assert.are.equal(0, game_controller.pendingPicks)

            game_controller.onUpgradeSelected(nil)
            assert.are.equal(1, drafts)
        end)

        it("rerolls the draft with Second Opinion charges", function()
            equipCard("second_opinion", 1)
            game_controller.initialize(sceneGroup)
            local drafts = 0
            game_controller.onLevelUpCallback = function() drafts = drafts + 1 end

            assert.is_not_nil(game_controller.rerollDraft())
            assert.is_nil(game_controller.rerollDraft())
            assert.are.equal(1, drafts)
        end)
    end)

    describe("abilities", function()
        it("lets the hero hold more abilities with extra slots", function()
            local hero = Hero:new(45, 1200)
            hero.extraAbilitySlots = 1
            for i = 1, 6 do assert.is_true(hero:addAbility({ id = "a" .. i })) end
            assert.is_false(hero:addAbility({ id = "a7" }))
            hero:destroy()
        end)

        it("fires extra projectiles and softens their damage penalty (Split Shot)", function()
            local bolt = ArcaneBolt:new()
            local baseDamage = bolt:getProjectileDamage({ damageMultiplier = 1 })
            local stats = { damageMultiplier = 1, extraProjectiles = 1, extraProjectilePenaltyReduction = 0 }
            assert.are.equal(bolt.projectileCount + 1, bolt:getVolleyCount(stats))
            assert.is_true(bolt:getProjectileDamage(stats) < baseDamage)

            stats.extraProjectilePenaltyReduction = 0.1
            local softened = bolt:getProjectileDamage(stats)
            assert.is_true(softened > bolt:getProjectileDamage({ damageMultiplier = 1, extraProjectiles = 1 }))

            local enemies = {
                { x = 300, y = 500, isActive = true }, { x = 400, y = 500, isActive = true },
            }
            assert.are.equal(bolt.projectileCount + 1, #bolt:getAimPoints(360, 1200, enemies, stats))
        end)
    end)

    describe("game scene", function()
        it("shows one HUD button per active card, but not Second Opinion", function()
            equipCard("spark", 1)
            equipCard("second_opinion", 2)
            equipCard("purge", 3)
            game_controller.initialize(sceneGroup)

            package.loaded["src.scenes.game"] = nil
            local scene = require("src.scenes.game")
            local group = display.newGroup()
            scene.createCardButtons(group)
            assert.are.equal(2, group.numChildren)
            assert.are.equal("spark", group[1].cardId)
            assert.are.equal("purge", group[2].cardId)
            scene.destroyCardButtons()
        end)

        it("spends a charge when a HUD card is used", function()
            equipCard("bastion", 1)
            game_controller.initialize(sceneGroup)
            game_controller.start()

            package.loaded["src.scenes.game"] = nil
            local scene = require("src.scenes.game")
            scene.createCardButtons(display.newGroup())
            local index = card_powers.getHudActives()[1].index
            assert.is_true(scene.useCard(index))
            assert.is_true(card_powers.isWallInvulnerable())
            assert.is_false(scene.useCard(index))
            scene.destroyCardButtons()
        end)
    end)

    describe("milestones in runs", function()
        it("adds card gold from kills and victories to run gold", function()
            local stats = { enemiesDefeated = 0, finalLevel = 1, victoryCondition = true,
                bonusGold = 15, victoryBonusGold = 50 }
            assert.are.equal(5 + 100 + 50 + 15, meta.goldForRun(stats))
            stats.victoryCondition = false
            assert.are.equal(5 + 15, meta.goldForRun(stats))
        end)

        it("counts boss and elite gold during a run (Gold Pouch 5, Bounty Hunter 5)", function()
            equipCard("gold_pouch", 1, 5)
            game_controller.initialize(sceneGroup)
            game_controller.onEnemyKilled({ type = "boss", x = 0, y = 0, isBoss = true })
            assert.are.equal(10, game_state.getStatistics().bonusGold)
        end)

        it("starts the run at level 2 (Head Start 15)", function()
            equipCard("head_start", 1, 15)
            game_controller.initialize(sceneGroup)
            local drafts = 0
            game_controller.onLevelUpCallback = function() drafts = drafts + 1 end
            game_controller.start()
            assert.are.equal(2, game_controller.getHero().level)
            assert.are.equal(1, drafts)
        end)

        it("offers 4 cards in the first draft only (Scholar's Notes 15)", function()
            equipCard("scholars_notes", 1, 15)
            game_controller.initialize(sceneGroup)
            local sizes = {}
            game_controller.onLevelUpCallback = function(cardsOffered) table.insert(sizes, #cardsOffered) end
            game_controller.onLevelUp(2)
            game_controller.onUpgradeSelected(nil)
            game_controller.onLevelUp(3)
            assert.are.same({ 4, 3 }, sizes)
        end)

        it("makes elites more common (Bounty Hunter 15)", function()
            local spawner_system = require("src.systems.spawner_system")
            game_controller.initialize(sceneGroup)
            local baseChance = spawner_system.elites.chance
            game_controller.cleanup()

            equipCard("bounty_hunter", 1, 15)
            game_controller.initialize(sceneGroup)
            assert.is_true(math.abs(spawner_system.elites.chance - math.min(1, baseChance * 1.25)) < 1e-9)
        end)

        it("gives extra projectiles more pierce (Split Shot 5)", function()
            local bolt = ArcaneBolt:new()
            local fired = {}
            local pool = { get = function()
                local p = { activate = function(self, x, y, tx, ty, speed, damage, pierce) self.pierce = pierce end }
                table.insert(fired, p)
                return p
            end }
            local enemies = { { x = 300, y = 500, isActive = true }, { x = 400, y = 500, isActive = true } }
            bolt:activate(360, 1200, enemies, pool, nil,
                { damageMultiplier = 1, extraProjectiles = 1, extraProjectilePierce = 1 })
            assert.are.equal(bolt.pierceCount, fired[1].pierce)
            assert.are.equal(bolt.pierceCount + 1, fired[2].pierce)
        end)
    end)
end)
