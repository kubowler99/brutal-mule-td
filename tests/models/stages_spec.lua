-- Tests for stages: data, unlocks, the spawner using a stage, runs on a
-- stage, the stage select scene, and unlocking on victory

require("tests.spec_helper")

local composer = require("composer")
local data = require("src.models.data")
local meta = require("src.models.meta_progression")
local cards = require("src.models.card_collection")
local stages = require("src.models.stages")
local spawner_system = require("src.systems.spawner_system")
local game_controller = require("src.controllers.game_controller")
local game_state = require("src.models.game_state")
local Walker = require("src.entities.walker")
local pool = require("src.utils.pool")

local function findText(group, pattern)
    for i = 1, group.numChildren do
        local child = group[i]
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

describe("Stages", function()
    local originalGotoScene
    local gotoCalls

    before_each(function()
        stages.setStages(nil)
        meta.setDefinitions(nil)
        cards.setDefinitions(nil)
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
        game_controller.cleanup()
        spawner_system.cleanup()
        data.stopSandbox(false)
    end)

    describe("data", function()
        it("defines 5 stages in order with rising multipliers", function()
            local list = stages.getStages()
            assert.are.equal(5, #list)
            local ids = {}
            for i, stage in ipairs(list) do ids[i] = stage.id end
            assert.are.same({ "cursed_field", "frozen_pass", "burning_keep", "sunken_crypt", "arcane_rift" }, ids)
            for i = 2, #list do
                assert.is_true(list[i].enemyMultiplier > list[i - 1].enemyMultiplier)
                assert.is_true(list[i].goldMultiplier > list[i - 1].goldMultiplier)
                assert.are.equal(list[i - 1].id, list[i].unlockedBy)
            end
        end)

        it("uses only enemy types and bosses that exist", function()
            local walker = Walker:new(nil)
            for _, stage in ipairs(stages.getStages()) do
                for _, entry in ipairs(stage.enemyTable) do
                    walker:activate(100, 0, 100, entry.type)
                    assert.are.equal(entry.type, walker.type)
                    assert.is_false(walker.isBoss, entry.type .. " should not be a boss")
                end
                assert.are.equal(2, #stage.bosses)
                for i, boss in ipairs(stage.bosses) do
                    walker:activate(100, 0, 100, boss.type)
                    assert.is_true(walker.isBoss, boss.type)
                    assert.are.equal(i == 2, walker.isFinalBoss, boss.type)
                    assert.is_not_nil(walker.displayName, boss.type)
                end
            end
        end)

        it("names each stage's bosses", function()
            assert.are.same({ "Frost Troll", "Ice Wyrm" }, stages.getBossNames(stages.getStage("frozen_pass")))
            assert.are.same({ "Bone Colossus", "The Lich" }, stages.getBossNames(stages.getStage("cursed_field")))
        end)

        it("gives each stage a background", function()
            local helpers = require("src.utils.helpers")
            for _, stage in ipairs(stages.getStages()) do
                assert.is_not_nil(helpers.BACKGROUNDS[stage.background], stage.id)
            end
        end)
    end)

    describe("unlocks", function()
        it("starts with only the first stage unlocked", function()
            assert.is_true(stages.isUnlocked("cursed_field"))
            assert.is_false(stages.isUnlocked("frozen_pass"))
            assert.are.equal("cursed_field", stages.getSelectedStageId())
        end)

        it("unlocks the next stage once", function()
            local unlocked = stages.unlockAfterVictory("cursed_field")
            assert.are.equal(1, #unlocked)
            assert.are.equal("frozen_pass", unlocked[1].id)
            assert.is_true(stages.isUnlocked("frozen_pass"))
            assert.are.equal(0, #stages.unlockAfterVictory("cursed_field"))
        end)

        it("falls back to the first stage if the saved stage is locked", function()
            stages.setSelectedStageId("arcane_rift")
            assert.are.equal("cursed_field", stages.getSelectedStageId())
            data.set("meta.stages.arcane_rift", true)
            assert.are.equal("arcane_rift", stages.getSelectedStageId())
        end)
    end)

    describe("spawning", function()
        it("uses the stage's enemy table, bosses, and multiplier", function()
            local stage = stages.getStage("burning_keep")
            spawner_system.initialize(pool.new(function() return Walker:new(nil) end), 1, stage)
            assert.are.equal(#stage.enemyTable, #spawner_system.enemyTable)
            assert.are.equal("flame_juggernaut", spawner_system.bossSchedule[1].type)
            assert.are.equal(1.7, spawner_system.enemyMultiplier)

            local bomber = spawner_system.spawnWalker("bomber", 200, true, { noElite = true })
            assert.is_true(math.abs(bomber.maxHealth - 12 * 1.7) < 1e-9)
            assert.are.equal(bomber.maxHealth, bomber.health)
            assert.is_true(math.abs(bomber.explodeDamage - 25 * 1.7) < 1e-9)
        end)

        it("keeps the old spawn table without a stage", function()
            require("src.models.config_loader").initialize()
            spawner_system.initialize(pool.new(function() return Walker:new(nil) end), 1)
            assert.are.equal(1, spawner_system.enemyMultiplier)
            assert.are.equal("boss", spawner_system.bossSchedule[1].type)
        end)

        it("gives stage bosses their attack abilities", function()
            local walker = Walker:new(nil)
            walker:activate(100, 0, 100, "frost_troll")
            assert.are.equal("slam", walker.eliteAbility)
            walker:activate(100, 0, 100, "flame_juggernaut")
            assert.are.equal("charge", walker.eliteAbility)
            walker:activate(100, 0, 100, "ember_drake")
            assert.are.equal("bomber", walker.summonType)
        end)
    end)

    describe("runs", function()
        it("records the stage and scales gold by the stage", function()
            game_controller.initialize(display.newGroup(), nil, "sunken_crypt")
            local stats = game_state.getStatistics()
            assert.are.equal("sunken_crypt", stats.stageId)
            assert.are.equal(1.75, stats.goldMultiplier)
            assert.are.equal(2.2, spawner_system.enemyMultiplier)
        end)

        it("uses the selected stage when none is given", function()
            data.set("meta.stages.frozen_pass", true)
            stages.setSelectedStageId("frozen_pass")
            game_controller.initialize(display.newGroup())
            assert.are.equal("frozen_pass", game_state.getStatistics().stageId)
        end)
    end)

    describe("stage select scene", function()
        local scene

        before_each(function()
            scene = loadScene("src.scenes.stage_select")
            scene:create({ name = "create" })
            scene:show({ name = "show", phase = "will" })
        end)

        after_each(function()
            scene:destroy({ name = "destroy" })
        end)

        it("lists every stage with its multipliers and bosses", function()
            assert.is_not_nil(findText(scene.view, "^1%. Cursed Field$"))
            assert.is_not_nil(findText(scene.view, "^5%. Arcane Rift$"))
            assert.is_not_nil(findText(scene.view, "Enemies x1%.3   Gold x1%.25   Bosses: Frost Troll, Ice Wyrm"))
        end)

        it("plays unlocked stages and says what to win for locked ones", function()
            assert.are.equal("PLAY", scene.buttonLabel(stages.getStage("cursed_field")))
            assert.are.equal("Win Cursed Field", scene.buttonLabel(stages.getStage("frozen_pass")))
            assert.is_false(scene.selectStage("frozen_pass"))
            assert.are.equal(0, #gotoCalls)

            assert.is_true(scene.selectStage("cursed_field"))
            assert.are.equal("src.scenes.hero_select", gotoCalls[1].name)
            assert.are.equal("cursed_field", gotoCalls[1].params.stageId)
        end)

        it("shows newly unlocked stages as playable", function()
            stages.unlockAfterVictory("cursed_field")
            scene.refresh()
            assert.are.equal("PLAY", scene.buttonLabel(stages.getStage("frozen_pass")))
        end)
    end)

    describe("hero select", function()
        it("starts the run on the chosen stage", function()
            local scene = loadScene("src.scenes.hero_select")
            scene:create({ name = "create" })
            data.set("meta.stages.frozen_pass", true)
            scene:show({ name = "show", phase = "will", params = { stageId = "frozen_pass" } })
            scene.selectHero("arcane_wanderer")
            assert.are.equal("src.scenes.game", gotoCalls[1].name)
            assert.are.equal("frozen_pass", gotoCalls[1].params.stageId)
            scene:destroy({ name = "destroy" })
        end)
    end)

    describe("game scene", function()
        it("swaps the battlefield background to the stage's", function()
            local scene = loadScene("src.scenes.game")
            scene:create({ name = "create" })
            local function backgroundFile()
                for i = 1, scene.view.numChildren do
                    local child = scene.view[i]
                    if child.backgroundName then return child.filename end
                end
            end
            assert.are.equal("assets/images/backgrounds/game.png", backgroundFile())
            scene.setStageBackground("burning_keep")
            assert.are.equal("assets/images/backgrounds/burning_keep.png", backgroundFile())
            scene.setStageBackground(nil)
            assert.are.equal("assets/images/backgrounds/game.png", backgroundFile())
            scene:destroy({ name = "destroy" })
        end)
    end)

    describe("game over", function()
        local function showGameOver(params)
            local gameover = loadScene("src.scenes.gameover")
            local scene = composer.newScene()
            scene.create, scene.show, scene.destroy = gameover.create, gameover.show, gameover.destroy
            scene:create({ name = "create" })
            scene:show({ name = "show", phase = "will", params = params })
            return scene
        end

        it("unlocks the next stage after a win and says so", function()
            local scene = showGameOver({ victoryCondition = true, stageId = "cursed_field", finalLevel = 20 })
            assert.is_true(stages.isUnlocked("frozen_pass"))
            assert.is_not_nil(findText(scene.view, "^New stage unlocked: Frozen Pass$"))
        end)

        it("unlocks nothing after a loss", function()
            local scene = showGameOver({ victoryCondition = false, stageId = "cursed_field", finalLevel = 7 })
            assert.is_false(stages.isUnlocked("frozen_pass"))
            assert.is_nil(findText(scene.view, "New stage unlocked"))
        end)
    end)
end)
