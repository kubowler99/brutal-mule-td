-- Tests for the hero select, upgrades, menu, game, and game over scenes'
-- use of meta progression

require("tests.spec_helper")

local composer = require("composer")
local data = require("src.models.data")
local meta = require("src.models.meta_progression")
local game_controller = require("src.controllers.game_controller")

local function findText(view, pattern)
    for i = 1, view.numChildren do
        local child = view[i]
        if type(child.text) == "string" and child.text:find(pattern) then
            return child
        end
    end
    return nil
end

local function loadScene(name)
    package.loaded[name] = nil
    return require(name)
end

describe("Meta progression scenes", function()
    local originalGotoScene
    local gotoCalls

    before_each(function()
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

    describe("hero select", function()
        local scene

        before_each(function()
            scene = loadScene("src.scenes.hero_select")
            scene:create({ name = "create" })
            scene:show({ name = "show", phase = "will" })
        end)

        after_each(function()
            scene:destroy({ name = "destroy" })
        end)

        it("shows PLAY for unlocked heroes and a price for locked ones", function()
            assert.is_not_nil(findText(scene.view, "^PLAY$"))
            assert.is_not_nil(findText(scene.view, "^UNLOCK %(300 gold%)$"))
            assert.is_not_nil(findText(scene.view, "^UNLOCK %(500 gold%)$"))
        end)

        it("starts a run with an unlocked hero", function()
            assert.is_true(scene.selectHero("arcane_wanderer"))

            assert.are.equal("src.scenes.game", gotoCalls[1].name)
            assert.are.equal("arcane_wanderer", gotoCalls[1].params.heroId)
            assert.are.equal("arcane_wanderer", data.get("meta.selectedHero"))
        end)

        it("unlocks a locked hero with enough gold instead of starting a run", function()
            meta.addGold(300)

            assert.is_false(scene.selectHero("frost_witch"))

            assert.are.equal(0, #gotoCalls)
            assert.is_true(meta.isHeroUnlocked("frost_witch"))
            assert.is_nil(findText(scene.view, "^UNLOCK %(300 gold%)$"))
            assert.is_not_nil(findText(scene.view, "^Gold: 0$"))
        end)

        it("leaves a locked hero locked without enough gold", function()
            assert.is_false(scene.selectHero("ember_knight"))
            assert.is_false(meta.isHeroUnlocked("ember_knight"))
        end)
    end)

    describe("upgrades", function()
        local scene

        before_each(function()
            scene = loadScene("src.scenes.upgrades")
            scene:create({ name = "create" })
            scene:show({ name = "show", phase = "will" })
        end)

        after_each(function()
            scene:destroy({ name = "destroy" })
        end)

        it("lists every upgrade at level 0 with its first price", function()
            assert.is_not_nil(findText(scene.view, "^Thick Walls  Lv 0/5$"))
            assert.is_not_nil(findText(scene.view, "^Scholar  Lv 0/5$"))
            assert.is_not_nil(findText(scene.view, "^BUY %(50 gold%)$"))
        end)

        it("buys a level and refreshes level, price, and gold", function()
            meta.addGold(60)

            assert.is_true(scene.buyUpgrade("wall_health"))

            assert.is_not_nil(findText(scene.view, "^Thick Walls  Lv 1/5$"))
            assert.is_not_nil(findText(scene.view, "^BUY %(100 gold%)$"))
            assert.is_not_nil(findText(scene.view, "^Gold: 10$"))
        end)

        it("shows MAXED for a maxed upgrade", function()
            data.set("meta.upgrades.wall_health", 5)
            scene.refresh()
            assert.is_not_nil(findText(scene.view, "^MAXED$"))
        end)
    end)

    describe("menu", function()
        it("shows gold and opens stage select, upgrades, and settings", function()
            meta.addGold(42)
            local menu = loadScene("src.scenes.menu")
            menu:dispatchEvent({ name = "create", phase = "will" })
            menu:dispatchEvent({ name = "show", phase = "will" })
            menu:dispatchEvent({ name = "show", phase = "did" })

            assert.is_not_nil(findText(menu.view, "^Gold: 42$"))

            local tapped = {}
            for i = 1, menu.view.numChildren do
                local child = menu.view[i]
                if child._tapListener then
                    child._tapListener({ name = "tap" })
                end
            end
            for _, call in ipairs(gotoCalls) do tapped[call.name] = true end
            assert.is_true(tapped["src.scenes.stage_select"])
            assert.is_true(tapped["src.scenes.upgrades"])
            assert.is_true(tapped["src.scenes.settings"])
        end)

        it("uses the menu background image", function()
            local menu = loadScene("src.scenes.menu")
            menu:dispatchEvent({ name = "create", phase = "will" })
            assert.are.equal("assets/images/backgrounds/menu.png", menu.view[1].filename)
        end)
    end)

    describe("settings", function()
        local scene

        local function findButton(view, labelText)
            for i = 1, view.numChildren do
                local child = view[i]
                if child.label and child.label.text == labelText then
                    return child
                end
            end
            return nil
        end

        before_each(function()
            scene = loadScene("src.scenes.settings")
            scene:create({ name = "create" })
            scene:show({ name = "show", phase = "will" })
        end)

        after_each(function()
            scene:destroy({ name = "destroy" })
        end)

        it("uses the settings background image", function()
            assert.are.equal("assets/images/backgrounds/settings.png", scene.view[1].filename)
        end)

        it("shows a toggle for sound effects and music", function()
            assert.is_not_nil(findText(scene.view, "^Sound Effects$"))
            assert.is_not_nil(findText(scene.view, "^Music$"))
            assert.is_not_nil(findText(scene.view, "^ON$"))
        end)

        it("treats settings as on until they are turned off", function()
            data.set("settings", {})
            assert.is_true(scene.isOn("soundOn"))
            assert.is_true(scene.isOn("musicOn"))
        end)

        it("turns a setting off and back on, saving each change", function()
            data.set("settings.soundOn", true)

            assert.is_false(scene.toggle("soundOn"))
            assert.is_false(data.get("settings.soundOn"))
            assert.is_true(scene.toggle("soundOn"))
            assert.is_true(data.get("settings.soundOn"))
        end)

        it("updates the button label when toggled", function()
            data.set("settings.musicOn", true)
            data.set("settings.soundOn", true)
            scene.refresh()

            scene.toggle("musicOn")

            local onCount, offCount = 0, 0
            for i = 1, scene.view.numChildren do
                local text = scene.view[i].text
                if text == "ON" then onCount = onCount + 1 end
                if text == "OFF" then offCount = offCount + 1 end
            end
            assert.are.equal(1, onCount)
            assert.are.equal(1, offCount)
        end)

        it("has a BACK button", function()
            local back = findButton(scene.view, "BACK")
            assert.is_not_nil(back)
        end)
    end)

    describe("game over", function()
        it("awards gold for the run and shows it", function()
            local scene = composer.newScene()
            local gameover = loadScene("src.scenes.gameover")
            scene.create, scene.show, scene.destroy = gameover.create, gameover.show, gameover.destroy

            scene:create({ name = "create" })
            scene:show({ name = "show", phase = "will",
                params = { enemiesDefeated = 10, finalLevel = 4, survivalTime = 90 } })

            assert.are.equal(30, meta.getGold())
            assert.is_not_nil(findText(scene.view, "^%+30 gold"))
            scene:destroy({ name = "destroy" })
        end)
    end)

    describe("game scene", function()
        it("starts the run with the chosen hero and keeps it for Play Again", function()
            local heroes = {}
            local originalInit = game_controller.initialize
            game_controller.initialize = function(group, heroId) table.insert(heroes, heroId) end

            local gameScene = loadScene("src.scenes.game")
            gameScene:create({ name = "create" })
            gameScene:show({ name = "show", phase = "will", params = { heroId = "frost_witch" } })
            gameScene:show({ name = "show", phase = "will" })

            game_controller.initialize = originalInit
            gameScene:destroy({ name = "destroy" })
            assert.are.same({ "frost_witch", "frost_witch" }, heroes)
        end)
    end)
end)
