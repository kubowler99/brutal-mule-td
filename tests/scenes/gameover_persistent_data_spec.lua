--- Persistent Data Integration Tests for Game Over Scene
-- Tests that statistics are saved correctly when game ends

require("tests.spec_helper")

local composer = require("composer")
local data = require("src.models.data")

describe("Game Over Scene - Persistent Data Integration", function()
  local scene
  
  before_each(function()
    -- Create a new scene instance
    scene = composer.newScene()
    
    -- Load the gameover scene module
    local gameoverSceneModule = require("src.scenes.gameover")
    
    -- Copy functions from module to scene
    scene.create = gameoverSceneModule.create
    scene.show = gameoverSceneModule.show
    scene.hide = gameoverSceneModule.hide
    scene.destroy = gameoverSceneModule.destroy
    
    -- Start sandbox mode for testing
    data.startSandbox()
    
    -- Initialize test data with known values
    data.set("stats.gamesPlayed", 0)
    data.set("stats.highestLevel", 1)
    data.set("stats.longestSurvival", 0)
    data.set("stats.totalEnemiesDefeated", 0)
  end)
  
  after_each(function()
    -- Stop sandbox mode without applying changes
    data.stopSandbox(false)
    
    -- Cleanup scene
    if scene and scene.destroy then
      local event = { name = "destroy", phase = "will" }
      scene:destroy(event)
    end
    
    scene = nil
  end)
  
  it("increments gamesPlayed by 1 when game over occurs", function()
    -- Verify initial state
    assert.are.equal(0, data.get("stats.gamesPlayed"), "Initial gamesPlayed should be 0")
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with game stats (triggers data persistence)
    event = {
      name = "show",
      phase = "will",
      params = {
        survivalTime = 60,
        enemiesDefeated = 10,
        finalLevel = 2
      }
    }
    scene:show(event)
    
    -- Verify gamesPlayed was incremented
    assert.are.equal(1, data.get("stats.gamesPlayed"), "gamesPlayed should be incremented to 1")
  end)
  
  it("updates highestLevel when current level is higher", function()
    -- Set initial highest level
    data.set("stats.highestLevel", 3)
    assert.are.equal(3, data.get("stats.highestLevel"), "Initial highestLevel should be 3")
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with higher level
    event = {
      name = "show",
      phase = "will",
      params = {
        survivalTime = 120,
        enemiesDefeated = 25,
        finalLevel = 5  -- Higher than current highest (3)
      }
    }
    scene:show(event)
    
    -- Verify highestLevel was updated
    assert.are.equal(5, data.get("stats.highestLevel"), "highestLevel should be updated to 5")
  end)
  
  it("does NOT update highestLevel when current level is lower", function()
    -- Set initial highest level
    data.set("stats.highestLevel", 7)
    assert.are.equal(7, data.get("stats.highestLevel"), "Initial highestLevel should be 7")
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with lower level
    event = {
      name = "show",
      phase = "will",
      params = {
        survivalTime = 45,
        enemiesDefeated = 8,
        finalLevel = 3  -- Lower than current highest (7)
      }
    }
    scene:show(event)
    
    -- Verify highestLevel was NOT updated
    assert.are.equal(7, data.get("stats.highestLevel"), "highestLevel should remain 7")
  end)
  
  it("does NOT update highestLevel when current level is equal", function()
    -- Set initial highest level
    data.set("stats.highestLevel", 5)
    assert.are.equal(5, data.get("stats.highestLevel"), "Initial highestLevel should be 5")
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with equal level
    event = {
      name = "show",
      phase = "will",
      params = {
        survivalTime = 90,
        enemiesDefeated = 15,
        finalLevel = 5  -- Equal to current highest (5)
      }
    }
    scene:show(event)
    
    -- Verify highestLevel was NOT updated
    assert.are.equal(5, data.get("stats.highestLevel"), "highestLevel should remain 5")
  end)
  
  it("updates longestSurvival when current time is longer", function()
    -- Set initial longest survival
    data.set("stats.longestSurvival", 120)
    assert.are.equal(120, data.get("stats.longestSurvival"), "Initial longestSurvival should be 120")
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with longer survival time
    event = {
      name = "show",
      phase = "will",
      params = {
        survivalTime = 180,  -- Longer than current longest (120)
        enemiesDefeated = 30,
        finalLevel = 4
      }
    }
    scene:show(event)
    
    -- Verify longestSurvival was updated
    assert.are.equal(180, data.get("stats.longestSurvival"), "longestSurvival should be updated to 180")
  end)
  
  it("does NOT update longestSurvival when current time is shorter", function()
    -- Set initial longest survival
    data.set("stats.longestSurvival", 240)
    assert.are.equal(240, data.get("stats.longestSurvival"), "Initial longestSurvival should be 240")
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with shorter survival time
    event = {
      name = "show",
      phase = "will",
      params = {
        survivalTime = 90,  -- Shorter than current longest (240)
        enemiesDefeated = 12,
        finalLevel = 2
      }
    }
    scene:show(event)
    
    -- Verify longestSurvival was NOT updated
    assert.are.equal(240, data.get("stats.longestSurvival"), "longestSurvival should remain 240")
  end)
  
  it("does NOT update longestSurvival when current time is equal", function()
    -- Set initial longest survival
    data.set("stats.longestSurvival", 150)
    assert.are.equal(150, data.get("stats.longestSurvival"), "Initial longestSurvival should be 150")
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with equal survival time
    event = {
      name = "show",
      phase = "will",
      params = {
        survivalTime = 150,  -- Equal to current longest (150)
        enemiesDefeated = 20,
        finalLevel = 3
      }
    }
    scene:show(event)
    
    -- Verify longestSurvival was NOT updated
    assert.are.equal(150, data.get("stats.longestSurvival"), "longestSurvival should remain 150")
  end)
  
  it("increments totalEnemiesDefeated by the correct amount", function()
    -- Set initial total
    data.set("stats.totalEnemiesDefeated", 50)
    assert.are.equal(50, data.get("stats.totalEnemiesDefeated"), "Initial totalEnemiesDefeated should be 50")
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with enemies defeated
    event = {
      name = "show",
      phase = "will",
      params = {
        survivalTime = 100,
        enemiesDefeated = 25,  -- Add 25 to the total
        finalLevel = 3
      }
    }
    scene:show(event)
    
    -- Verify totalEnemiesDefeated was incremented correctly
    assert.are.equal(75, data.get("stats.totalEnemiesDefeated"), "totalEnemiesDefeated should be 75 (50 + 25)")
  end)
  
  it("handles zero enemies defeated correctly", function()
    -- Set initial total
    data.set("stats.totalEnemiesDefeated", 100)
    assert.are.equal(100, data.get("stats.totalEnemiesDefeated"), "Initial totalEnemiesDefeated should be 100")
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with zero enemies defeated
    event = {
      name = "show",
      phase = "will",
      params = {
        survivalTime = 30,
        enemiesDefeated = 0,  -- No enemies defeated
        finalLevel = 1
      }
    }
    scene:show(event)
    
    -- Verify totalEnemiesDefeated remains the same
    assert.are.equal(100, data.get("stats.totalEnemiesDefeated"), "totalEnemiesDefeated should remain 100")
  end)
  
  it("calls data.save() to persist all changes", function()
    -- Mock data.save to track if it was called
    local originalSave = data.save
    local saveCalled = false
    
    data.save = function()
      saveCalled = true
      -- Call original to maintain functionality
      originalSave()
    end
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with game stats
    event = {
      name = "show",
      phase = "will",
      params = {
        survivalTime = 75,
        enemiesDefeated = 15,
        finalLevel = 2
      }
    }
    scene:show(event)
    
    -- Verify save was called
    assert.is_true(saveCalled, "data.save() should be called to persist changes")
    
    -- Restore original save function
    data.save = originalSave
  end)
  
  it("handles missing params gracefully with default values", function()
    -- Verify initial state
    assert.are.equal(0, data.get("stats.gamesPlayed"), "Initial gamesPlayed should be 0")
    assert.are.equal(1, data.get("stats.highestLevel"), "Initial highestLevel should be 1")
    assert.are.equal(0, data.get("stats.longestSurvival"), "Initial longestSurvival should be 0")
    assert.are.equal(0, data.get("stats.totalEnemiesDefeated"), "Initial totalEnemiesDefeated should be 0")
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with no params (edge case)
    event = {
      name = "show",
      phase = "will",
      params = nil  -- No params provided
    }
    scene:show(event)
    
    -- Verify defaults were used and gamesPlayed was still incremented
    assert.are.equal(1, data.get("stats.gamesPlayed"), "gamesPlayed should be incremented even with no params")
    assert.are.equal(1, data.get("stats.highestLevel"), "highestLevel should remain 1 (default level)")
    assert.are.equal(0, data.get("stats.longestSurvival"), "longestSurvival should remain 0 (default time)")
    assert.are.equal(0, data.get("stats.totalEnemiesDefeated"), "totalEnemiesDefeated should remain 0 (default enemies)")
  end)
  
  it("handles alternative param names (elapsedTime, level) correctly", function()
    -- Set initial values
    data.set("stats.highestLevel", 2)
    data.set("stats.longestSurvival", 60)
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with alternative param names
    event = {
      name = "show",
      phase = "will",
      params = {
        elapsedTime = 120,  -- Alternative to survivalTime
        enemiesDefeated = 20,
        level = 4  -- Alternative to finalLevel
      }
    }
    scene:show(event)
    
    -- Verify stats were updated using alternative param names
    assert.are.equal(4, data.get("stats.highestLevel"), "highestLevel should be updated to 4 using 'level' param")
    assert.are.equal(120, data.get("stats.longestSurvival"), "longestSurvival should be updated to 120 using 'elapsedTime' param")
  end)
  
  it("updates all statistics correctly in a complete game over scenario", function()
    -- Set initial statistics
    data.set("stats.gamesPlayed", 5)
    data.set("stats.highestLevel", 3)
    data.set("stats.longestSurvival", 100)
    data.set("stats.totalEnemiesDefeated", 150)
    
    -- Create scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    -- Show scene with new personal bests
    event = {
      name = "show",
      phase = "will",
      params = {
        survivalTime = 180,  -- New longest survival
        enemiesDefeated = 40,  -- Add to total
        finalLevel = 5  -- New highest level
      }
    }
    scene:show(event)
    
    -- Verify all statistics were updated correctly
    assert.are.equal(6, data.get("stats.gamesPlayed"), "gamesPlayed should be 6 (5 + 1)")
    assert.are.equal(5, data.get("stats.highestLevel"), "highestLevel should be 5 (new record)")
    assert.are.equal(180, data.get("stats.longestSurvival"), "longestSurvival should be 180 (new record)")
    assert.are.equal(190, data.get("stats.totalEnemiesDefeated"), "totalEnemiesDefeated should be 190 (150 + 40)")
  end)
end)
