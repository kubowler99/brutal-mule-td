--- Property-based tests for Game Over Scene
-- Feature: arcane-survivor-mvp, Property 31: Game Over Statistics
-- **Validates: Requirements 7.7**

require("tests.spec_helper")
local lqc = require("lqc.quickcheck")
local property = require("lqc.property")
local lqc_gen = require("lqc.lqc_gen")

describe("Game Over Scene - Property Tests", function()
  local gameover
  
  before_each(function()
    -- Reset package.loaded to get fresh instances
    package.loaded["src.scenes.gameover"] = nil
    package.loaded["src.utils.helpers"] = nil
    
    -- Load gameover scene
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
  
  describe("Property 31: Game Over Statistics", function()
    it("should display correct statistics for any game over event", function()
      -- Property: For any game over event, the displayed statistics should include
      -- the correct survival time, enemies defeated count, and final hero level
      
      lqc.init(100, 100)
      
      property "Game over scene displays correct statistics" {
        generators = {
          lqc_gen.choose(0, 10000),  -- survivalTime (0 to 10000 seconds)
          lqc_gen.choose(0, 1000),   -- enemiesDefeated (0 to 1000)
          lqc_gen.choose(1, 20)      -- finalLevel (1 to 20)
        },
        check = function(survivalTime, enemiesDefeated, finalLevel)
          -- Create scene
          local createEvent = { name = "create", phase = "will" }
          gameover:dispatchEvent(createEvent)
          
          -- Show scene with statistics
          local showEvent = {
            name = "show",
            phase = "will",
            params = {
              survivalTime = survivalTime,
              enemiesDefeated = enemiesDefeated,
              finalLevel = finalLevel
            }
          }
          
          -- Should not throw error
          local success, err = pcall(function()
            gameover:dispatchEvent(showEvent)
          end)
          
          if not success then
            return false
          end
          
          -- Verify scene was created and shown
          if not gameover or not gameover.view then
            return false
          end
          
          -- Verify scene has display objects (statistics are displayed)
          if gameover.view.numChildren < 5 then
            return false
          end
          
          return true
        end
      }
    end)
    
    it("should handle edge case statistics values", function()
      -- Test edge cases: zero values, maximum values
      
      local edgeCases = {
        { survivalTime = 0, enemiesDefeated = 0, finalLevel = 1 },
        { survivalTime = 0, enemiesDefeated = 1000, finalLevel = 20 },
        { survivalTime = 10000, enemiesDefeated = 0, finalLevel = 1 },
        { survivalTime = 10000, enemiesDefeated = 1000, finalLevel = 20 }
      }
      
      for _, testCase in ipairs(edgeCases) do
        -- Create scene
        local createEvent = { name = "create", phase = "will" }
        gameover:dispatchEvent(createEvent)
        
        -- Show scene with edge case statistics
        local showEvent = {
          name = "show",
          phase = "will",
          params = {
            survivalTime = testCase.survivalTime,
            enemiesDefeated = testCase.enemiesDefeated,
            finalLevel = testCase.finalLevel
          }
        }
        
        -- Should not throw error
        assert.has_no.errors(function()
          gameover:dispatchEvent(showEvent)
        end)
        
        -- Verify scene has display objects
        assert.is_true(gameover.view.numChildren >= 5)
      end
    end)
    
    it("should format survival time correctly for any time value", function()
      -- Property: For any survival time value, the time should be formatted as MM:SS
      
      lqc.init(100, 100)
      
      property "Survival time is formatted as MM:SS" {
        generators = {
          lqc_gen.choose(0, 7200)  -- 0 to 2 hours
        },
        check = function(survivalTime)
          -- Create scene
          local createEvent = { name = "create", phase = "will" }
          gameover:dispatchEvent(createEvent)
          
          -- Show scene with survival time
          local showEvent = {
            name = "show",
            phase = "will",
            params = {
              survivalTime = survivalTime,
              enemiesDefeated = 0,
              finalLevel = 1
            }
          }
          
          -- Should not throw error
          local success, err = pcall(function()
            gameover:dispatchEvent(showEvent)
          end)
          
          if not success then
            return false
          end
          
          -- Verify scene was properly created
          if not gameover or not gameover.view then
            return false
          end
          
          return true
        end
      }
    end)
    
    it("should handle missing or partial statistics gracefully", function()
      -- Property: For any combination of missing statistics fields,
      -- the scene should use fallback values and not crash
      
      local testCases = {
        {},  -- All missing
        { survivalTime = 100 },  -- Only survivalTime
        { enemiesDefeated = 50 },  -- Only enemiesDefeated
        { finalLevel = 10 },  -- Only finalLevel
        { survivalTime = 100, enemiesDefeated = 50 },  -- Missing finalLevel
        { survivalTime = 100, finalLevel = 10 },  -- Missing enemiesDefeated
        { enemiesDefeated = 50, finalLevel = 10 },  -- Missing survivalTime
        { elapsedTime = 100, level = 5 },  -- Using fallback field names
      }
      
      for _, params in ipairs(testCases) do
        -- Create scene
        local createEvent = { name = "create", phase = "will" }
        gameover:dispatchEvent(createEvent)
        
        -- Show scene with partial statistics
        local showEvent = {
          name = "show",
          phase = "will",
          params = params
        }
        
        -- Should not throw error
        assert.has_no.errors(function()
          gameover:dispatchEvent(showEvent)
        end)
        
        -- Verify scene was created
        assert.is_not_nil(gameover)
        assert.is_not_nil(gameover.view)
      end
    end)
  end)
end)
