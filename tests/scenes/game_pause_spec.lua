--- Pause Tests for the Game Scene
-- Covers the pause button flow: pause, resume, quit to menu, and the
-- level-up panel interaction.

require("tests.spec_helper")

local composer = require("composer")
local game_controller = require("src.controllers.game_controller")
local game_state = require("src.models.game_state")

describe("Game Scene pause", function()
  local gameScene
  local originalGotoScene
  local gotoSceneCalls

  local function runFrames(startFrame, count)
    for i = startFrame, startFrame + count - 1 do
      game_controller.update({ time = i * 16.67 })
    end
  end

  before_each(function()
    package.loaded["src.scenes.game"] = nil
    gameScene = require("src.scenes.game")

    originalGotoScene = composer.gotoScene
    gotoSceneCalls = {}
    composer.gotoScene = function(sceneName, options)
      table.insert(gotoSceneCalls, sceneName)
    end

    gameScene:create({ name = "create" })
    gameScene:show({ name = "show", phase = "will" })
    gameScene:show({ name = "show", phase = "did" })
  end)

  after_each(function()
    gameScene:destroy({ name = "destroy" })
    composer.gotoScene = originalGotoScene
    package.loaded["src.scenes.game"] = nil
  end)

  it("pauses the game and hides the game layer", function()
    runFrames(1, 10)

    assert.is_true(gameScene.pauseGame())

    assert.are.equal("paused", game_state.state)
    assert.is_false(gameScene.gameLayer.isVisible)
  end)

  it("stops elapsed time while paused", function()
    runFrames(1, 10)
    gameScene.pauseGame()
    local pausedAt = game_state.elapsedTime

    runFrames(11, 60)

    assert.are.equal(pausedAt, game_state.elapsedTime)
  end)

  it("resumes the game and shows the game layer", function()
    runFrames(1, 10)
    gameScene.pauseGame()

    assert.is_true(gameScene.resumeGame())

    assert.are.equal("playing", game_state.state)
    assert.is_true(gameScene.gameLayer.isVisible)

    local resumedAt = game_state.elapsedTime
    runFrames(11, 10)
    assert.is_true(game_state.elapsedTime > resumedAt)
  end)

  it("ignores a second pause and a resume without a pause", function()
    assert.is_false(gameScene.resumeGame())
    assert.is_true(gameScene.pauseGame())
    assert.is_false(gameScene.pauseGame())
  end)

  it("does not pause while the level-up panel is open", function()
    game_controller.onLevelUp(2)

    assert.is_false(gameScene.pauseGame())
    assert.is_false(gameScene.resumeGame())
  end)

  it("quits to the menu and cleans up the session on hide", function()
    gameScene.pauseGame()

    assert.is_true(gameScene.quitToMenu())
    assert.are.same({ "src.scenes.menu" }, gotoSceneCalls)

    gameScene:hide({ name = "hide", phase = "will" })

    assert.is_nil(game_controller.getHero())
    assert.is_nil(game_controller.getWall())
  end)

  it("does not quit unless paused", function()
    assert.is_false(gameScene.quitToMenu())
    assert.are.same({}, gotoSceneCalls)
  end)

  it("starts the next session unpaused after quitting", function()
    gameScene.pauseGame()
    gameScene.quitToMenu()
    gameScene:hide({ name = "hide", phase = "will" })

    gameScene:show({ name = "show", phase = "will" })
    gameScene:show({ name = "show", phase = "did" })

    assert.are.equal("playing", game_state.state)
    assert.is_true(gameScene.gameLayer.isVisible)
    assert.is_true(gameScene.pauseGame())
  end)
end)
