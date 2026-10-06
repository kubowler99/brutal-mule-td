-- Tests for the cards scene (shop and collection), the card face component,
-- the card loadout row on hero select, and the menu's CARDS button

require("tests.spec_helper")

local composer = require("composer")
local data = require("src.models.data")
local meta = require("src.models.meta_progression")
local cards = require("src.models.card_collection")
local card_face = require("src.ui.card_face")

local function seededRng(seed)
    local state = seed
    return function()
        state = (state * 1103515245 + 12345) % 2147483648
        return state / 2147483648
    end
end

--- Find text in a group and its child groups
local function findText(group, pattern)
    for i = 1, group.numChildren do
        local child = group[i]
        if type(child.text) == "string" and child.text:find(pattern) then
            return child
        end
        if child._type == "group" then
            local found = findText(child, pattern)
            if found then return found end
        end
    end
    return nil
end

--- Count card faces (groups with a cardId) in a group and its child groups
local function countFaces(group)
    local count = 0
    for i = 1, group.numChildren do
        local child = group[i]
        if child.cardId then
            count = count + 1
        elseif child._type == "group" then
            count = count + countFaces(child)
        end
    end
    return count
end

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

local function loadScene(name)
    package.loaded[name] = nil
    return require(name)
end

describe("Card screens", function()
    local originalGotoScene
    local gotoCalls

    before_each(function()
        cards.setDefinitions(nil)
        meta.setDefinitions(nil)
        data.startSandbox()
        data.set("meta", {})
        originalGotoScene = composer.gotoScene
        gotoCalls = {}
        composer.gotoScene = function(name, options)
            table.insert(gotoCalls, { name = name, params = options and options.params })
        end
    end)

    after_each(function()
        composer.gotoScene = originalGotoScene
        data.stopSandbox(false)
    end)

    describe("card face", function()
        it("draws the tier frame, the card icon, and the card name", function()
            local group = display.newGroup()
            local face = card_face.new(group, 100, 200, { cardId = "purge", size = 170, level = 3, count = 2 })
            assert.are.equal("assets/images/cards/frame_rare.png", face.frame.filename)
            assert.are.equal("assets/images/cards/icons/purge.png", face.icon.filename)
            assert.are.equal("Purge", face.nameText.text)
            assert.are.equal("Lv 3", face.levelText.text)
            assert.are.equal("x2", face.countText.text)
            assert.are.equal(100, face.x)
            assert.are.equal(200, face.y)
        end)

        it("fades unowned cards", function()
            local face = card_face.new(display.newGroup(), 0, 0, { cardId = "spark", dimmed = true })
            assert.are.equal(0.35, face.alpha)
        end)

        it("names and colors tiers from the card data", function()
            assert.are.equal("Legendary", card_face.tierName("legendary"))
            assert.are.same({ 0.3, 0.55, 1.0 }, card_face.tierColor("rare"))
        end)
    end)

    describe("cards scene", function()
        local scene

        before_each(function()
            scene = loadScene("src.scenes.cards")
            scene:create({ name = "create" })
            scene:show({ name = "show", phase = "will", params = { tab = "shop" } })
        end)

        after_each(function()
            scene:destroy({ name = "destroy" })
        end)

        it("shows the pack price, odds, and gold", function()
            assert.is_not_nil(findText(scene.view, "^Pack: 3 cards for 150 gold$"))
            assert.is_not_nil(findText(scene.view, "Common 75%%"))
            assert.is_not_nil(findText(scene.view, "Mythic 0.1%%"))
            assert.is_not_nil(findText(scene.view, "^Gold: 0$"))
        end)

        it("buys a pack, shows its 3 cards, and updates gold", function()
            meta.addGold(200)
            local opened = scene.buyPack(seededRng(5))
            assert.are.equal(3, #opened)
            assert.are.equal(3, countFaces(scene.view))
            assert.is_not_nil(findText(scene.view, "^Gold: 50$"))
            assert.are.equal(3, #cards.getInstances())
        end)

        it("says so when there is not enough gold", function()
            assert.is_nil(scene.buyPack(seededRng(5)))
            assert.is_not_nil(findText(scene.view, "^Not enough gold%.$"))
            assert.are.equal(0, countFaces(scene.view))
        end)

        it("shows every card of the chosen tier in the collection, owned or not", function()
            give("purge", 2)
            scene.showTab("collection")
            assert.are.equal(8, countFaces(scene.view))
            scene.showTier("rare")
            assert.are.equal(5, countFaces(scene.view))
            assert.is_not_nil(findText(scene.view, "^x2$"))
            assert.is_not_nil(findText(scene.view, "^x0$"))
        end)

        it("levels up the open card with spare cards of its tier", function()
            local target = give("sharpened_focus", 1)[1]
            give("stone_mortar", 5)
            scene.showTab("collection")
            scene.openDetail("sharpened_focus")
            assert.is_not_nil(findText(scene.view, "Next level: 5 Common cards %(5 spare%)"))

            assert.is_true(scene.mergeSelected())
            assert.are.equal(2, cards.getInstance(target).level)
            assert.is_not_nil(findText(scene.view, "^Leveled up to 2!$"))
        end)

        it("explains when there are not enough spare cards to level up", function()
            give("sharpened_focus", 1)
            give("stone_mortar", 4)
            scene.showTab("collection")
            scene.openDetail("sharpened_focus")
            assert.is_false(scene.mergeSelected())
            assert.is_not_nil(findText(scene.view, "^Not enough spare cards of this tier%.$"))
        end)

        it("fuses spare cards but keeps the open card", function()
            local kept = give("sharpened_focus", 1)[1]
            give("stone_mortar", 5)
            scene.showTab("collection")
            scene.openDetail("sharpened_focus")

            local fused = scene.fuseSelected(seededRng(2))
            assert.are.equal("uncommon", fused.tier)
            assert.is_not_nil(cards.getInstance(kept))
            assert.are.equal(2, #cards.getInstances())
        end)

        it("equips the open card in a loadout slot", function()
            local uid = give("spark", 1)[1]
            scene.showTab("collection")
            scene.openDetail("spark")
            assert.is_true(scene.equipSelected(2))
            assert.are.equal(uid, cards.getLoadout()[2])
            assert.is_not_nil(findText(scene.view, "^SLOT 2 ✓$"))
        end)

        it("closes the detail panel", function()
            give("spark", 1)
            scene.showTab("collection")
            scene.openDetail("spark")
            assert.is_not_nil(findText(scene.view, "^CLOSE$"))
            scene.closeDetail()
            assert.is_nil(findText(scene.view, "^CLOSE$"))
        end)
    end)

    describe("hero select loadout", function()
        local scene

        before_each(function()
            scene = loadScene("src.scenes.hero_select")
            scene:create({ name = "create" })
            scene:show({ name = "show", phase = "will" })
        end)

        after_each(function()
            scene:destroy({ name = "destroy" })
        end)

        it("shows 3 empty slots by default", function()
            for slot = 1, 3 do
                assert.are.equal("Empty", scene.loadoutLabel(slot))
            end
            assert.is_not_nil(findText(scene.view, "^CARD LOADOUT$"))
        end)

        it("shows equipped cards with their level", function()
            local uid = give("purge", 1)[1]
            data.get("meta.cards").instances[uid].level = 4
            cards.equip(3, uid)
            scene.refresh()
            assert.are.equal("Purge 4", scene.loadoutLabel(3))
            assert.is_not_nil(findText(scene.view, "^Purge 4$"))
        end)

        it("opens the collection and comes back to hero select", function()
            scene.openCards()
            assert.are.equal("src.scenes.cards", gotoCalls[1].name)
            assert.are.equal("collection", gotoCalls[1].params.tab)
            assert.are.equal("src.scenes.hero_select", gotoCalls[1].params.returnScene)
        end)
    end)

    describe("menu", function()
        it("opens the card shop", function()
            local menu = loadScene("src.scenes.menu")
            menu:dispatchEvent({ name = "create", phase = "will" })
            menu:dispatchEvent({ name = "show", phase = "will" })
            menu:dispatchEvent({ name = "show", phase = "did" })
            for i = 1, menu.view.numChildren do
                local child = menu.view[i]
                if child._tapListener and child.label and child.label.text == "CARDS" then
                    child._tapListener({ name = "tap" })
                end
            end
            assert.are.equal("src.scenes.cards", gotoCalls[1].name)
            assert.are.equal("shop", gotoCalls[1].params.tab)
        end)
    end)
end)
