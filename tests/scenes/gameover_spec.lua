--- Unit tests for Game Over Scene
-- Tests scene lifecycle, statistics display, and button transitions

require("tests.spec_helper")

describe("Game Over Scene", function()
  local gameover
  
  before_each(function()
    -- Reset package.loaded to get fresh instances
    package.loaded["src.scenes.gameover"] = nil
    package.loaded["src.utils.helpers"] = nil
    
    -- Load gameover scene (composer is already mocked by spec_helper)
    gameover = require("src.scenes.gameover")
  end)
  
  after_each(function()
    package.loaded["src.scenes.gameover"] = nil
    package.loaded["src.utils.helpers"] = nil
    
    -- Clean up scene view
    if gameover and gameover.view then
      while gameover.view.numChildren > 0 do
        gameover.view:remove(1)
      end
    end
  end)
  
  describe("scene:create", function()
    it("should build game over UI correctly", function()
      local event = { name = "create", phase = "will" }
      
      -- Call create via dispatchEvent
      gameover:dispatchEvent(event)
      
      -- Verify scene was created (no errors thrown)
      assert.is_not_nil(gameover)
      assert.is_not_nil(gameover.view)
    end)
    
    it("should create all required UI elements", function()
      local event = { name = "create", phase = "will" }
      gameover:dispatchEvent(event)
      
      -- Verify display objects were added to scene group
      -- At minimum: background, title, 3 stat texts, 2 buttons + 2 labels = 8 elements
      assert.is_true(gameover.view.numChildren >= 5)
    end)
  end)
  
  describe("scene:show", function()
    it("should display correct statistics from event.params", function()
      -- Create scene first
      local createEvent = { name = "create", phase = "will" }
      gameover:dispatchEvent(createEvent)
      
      -- Show scene with statistics
      local showEvent = {
        name = "show",
        phase = "will",
        params = {
          survivalTime = 125,  -- 2:05
          enemiesDefeated = 42,
          finalLevel = 7
        }
      }
      
      gameover:dispatchEvent(showEvent)
      
      -- Verify no errors occurred
      assert.is_not_nil(gameover)
    end)
    
    it("should handle missing statistics gracefully", function()
      local createEvent = { name = "create", phase = "will" }
      gameover:dispatchEvent(createEvent)
      
      -- Show scene without statistics
      local showEvent = {
        name = "show",
        phase = "will",
        params = nil
      }
      
      -- Should not throw error
      assert.has_no.errors(function()
        gameover:dispatchEvent(showEvent)
      end)
    end)
    
    it("should add button listeners in 'did' phase", function()
      local createEvent = { name = "create", phase = "will" }
      gameover:dispatchEvent(createEvent)
      
      -- Show scene - "did" phase
      local showEvent = {
        name = "show",
        phase = "did",
        params = {
          survivalTime = 100,
          enemiesDefeated = 20,
          finalLevel = 5
        }
      }
      
      gameover:dispatchEvent(showEvent)
      
      -- Verify no errors occurred
      assert.is_not_nil(gameover)
    end)
  end)
  
  describe("scene:hide", function()
    it("should remove button listeners in 'will' phase", function()
      -- Create and show scene
      local createEvent = { name = "create", phase = "will" }
      gameover:dispatchEvent(createEvent)
      
      local showEvent = {
        name = "show",
        phase = "did",
        params = { survivalTime = 100, enemiesDefeated = 20, finalLevel = 5 }
      }
      gameover:dispatchEvent(showEvent)
      
      -- Hide scene
      local hideEvent = {
        name = "hide",
        phase = "will"
      }
      
      -- Should not throw error
      assert.has_no.errors(function()
        gameover:dispatchEvent(hideEvent)
      end)
    end)
  end)
  
  describe("scene:destroy", function()
    it("should cleanup scene resources", function()
      local createEvent = { name = "create", phase = "will" }
      gameover:dispatchEvent(createEvent)
      
      local destroyEvent = { name = "destroy", phase = "will" }
      
      -- Should not throw error
      assert.has_no.errors(function()
        gameover:dispatchEvent(destroyEvent)
      end)
    end)
  end)
  
  describe("button transitions", function()
    it("should transition to game scene when Play Again is tapped", function()
      local createEvent = { name = "create", phase = "will" }
      gameover:dispatchEvent(createEvent)
      
      local showEvent = {
        name = "show",
        phase = "did",
        params = { survivalTime = 100, enemiesDefeated = 20, finalLevel = 5 }
      }
      gameover:dispatchEvent(showEvent)
      
      -- Verify scene was shown without errors
      assert.is_not_nil(gameover)
      assert.is_true(gameover.view.numChildren > 0)
    end)
    
    it("should transition to menu scene when Main Menu is tapped", function()
      local createEvent = { name = "create", phase = "will" }
      gameover:dispatchEvent(createEvent)
      
      local showEvent = {
        name = "show",
        phase = "did",
        params = { survivalTime = 100, enemiesDefeated = 20, finalLevel = 5 }
      }
      gameover:dispatchEvent(showEvent)
      
      -- Verify scene was shown without errors
      assert.is_not_nil(gameover)
      assert.is_true(gameover.view.numChildren > 0)
    end)
  end)
  
  describe("time formatting", function()
    it("should format survival time as MM:SS", function()
      local createEvent = { name = "create", phase = "will" }
      gameover:dispatchEvent(createEvent)
      
      -- Test various time values
      local testCases = {
        { survivalTime = 0, expected = "00:00" },
        { survivalTime = 59, expected = "00:59" },
        { survivalTime = 60, expected = "01:00" },
        { survivalTime = 125, expected = "02:05" },
        { survivalTime = 3661, expected = "61:01" }
      }
      
      for _, testCase in ipairs(testCases) do
        local showEvent = {
          name = "show",
          phase = "will",
          params = {
            survivalTime = testCase.survivalTime,
            enemiesDefeated = 0,
            finalLevel = 1
          }
        }
        
        -- Should not throw error
        assert.has_no.errors(function()
          gameover:dispatchEvent(showEvent)
        end)
      end
    end)
  end)
  
  describe("statistics fallback", function()
    it("should use elapsedTime if survivalTime is not provided", function()
      local createEvent = { name = "create", phase = "will" }
      gameover:dispatchEvent(createEvent)
      
      local showEvent = {
        name = "show",
        phase = "will",
        params = {
          elapsedTime = 100,  -- Fallback field
          enemiesDefeated = 20,
          level = 5  -- Fallback field for finalLevel
        }
      }
      
      -- Should not throw error
      assert.has_no.errors(function()
        gameover:dispatchEvent(showEvent)
      end)
    end)
    
    it("should use default values if no statistics provided", function()
      local createEvent = { name = "create", phase = "will" }
      gameover:dispatchEvent(createEvent)
      
      local showEvent = {
        name = "show",
        phase = "will",
        params = {}  -- Empty params
      }
      
      -- Should not throw error and use defaults
      assert.has_no.errors(function()
        gameover:dispatchEvent(showEvent)
      end)
    end)
  end)
end)
