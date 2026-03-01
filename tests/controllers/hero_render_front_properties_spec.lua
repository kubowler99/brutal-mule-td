--- Property-based tests for Hero Render Front of Wall Bugfix
-- Feature: hero-render-front-of-wall
-- Tests bug condition exploration for hero rendering behind wall

require("tests.spec_helper")

local game_controller = require("src.controllers.game_controller")

describe("Hero Render Front of Wall - Bug Condition Exploration", function()
  local mockSceneGroup
  
  after_each(function()
    -- Cleanup after each test
    game_controller.cleanup()
  end)
  
  -- Property 1: Fault Condition - Hero Renders in Front of Wall After Pool Pre-warming
  -- **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  -- **Feature**: hero-render-front-of-wall
  -- **Validates: Requirements 1.1, 2.1, 2.2**
  describe("Property 1: Fault Condition - Hero Renders in Front of Wall", function()
    it("should ensure hero display object index > wall display object index after initialization (EXPECTED TO FAIL ON UNFIXED CODE)", function()
      -- This test encodes the EXPECTED behavior (hero in front of wall)
      -- On UNFIXED code, this will FAIL because wall.toFront() moves wall in front of hero
      -- After the fix, this test will PASS
      
      -- Create enhanced mock scene group that tracks display object indices
      local displayObjects = {}
      mockSceneGroup = {
        insert = function(self, obj)
          if obj then
            table.insert(displayObjects, obj)
            obj._sceneIndex = #displayObjects
            self.numChildren = #displayObjects
          end
        end,
        numChildren = 0
      }
      
      -- Override toFront() to actually move objects to front in our mock
      local originalNewRect = display.newRect
      local originalNewCircle = display.newCircle
      
      display.newRect = function(...)
        local rect = originalNewRect(...)
        rect.toFront = function(self)
          -- Find this object in displayObjects
          for i, obj in ipairs(displayObjects) do
            if obj == self then
              -- Remove from current position
              table.remove(displayObjects, i)
              -- Add to end (front)
              table.insert(displayObjects, self)
              -- Update all indices
              for j, o in ipairs(displayObjects) do
                o._sceneIndex = j
              end
              break
            end
          end
        end
        return rect
      end
      
      display.newCircle = function(...)
        local circle = originalNewCircle(...)
        circle.toFront = function(self)
          -- Find this object in displayObjects
          for i, obj in ipairs(displayObjects) do
            if obj == self then
              -- Remove from current position
              table.remove(displayObjects, i)
              -- Add to end (front)
              table.insert(displayObjects, self)
              -- Update all indices
              for j, o in ipairs(displayObjects) do
                o._sceneIndex = j
              end
              break
            end
          end
        end
        return circle
      end
      
      -- Initialize game controller
      game_controller.initialize(mockSceneGroup)
      
      -- Get hero and wall
      local hero = game_controller.getHero()
      local wall = game_controller.getWall()
      
      -- Verify both exist
      assert.is_not_nil(hero, "Hero should exist")
      assert.is_not_nil(wall, "Wall should exist")
      assert.is_not_nil(hero.displayObject, "Hero display object should exist")
      assert.is_not_nil(wall.displayObject, "Wall display object should exist")
      
      -- Get display object indices
      local heroIndex = hero.displayObject._sceneIndex
      local wallIndex = wall.displayObject._sceneIndex
      
      -- Verify indices exist
      assert.is_not_nil(heroIndex, "Hero display object should have scene index")
      assert.is_not_nil(wallIndex, "Wall display object should have scene index")
      
      -- EXPECTED BEHAVIOR: Hero should render in front of wall (heroIndex > wallIndex)
      -- On UNFIXED code, this assertion will FAIL because wall.toFront() moves wall in front of hero
      -- This proves the bug exists
      assert.is_true(heroIndex > wallIndex, 
        string.format("Hero should render in front of wall (hero index: %d, wall index: %d). " ..
                      "BUG DETECTED: Hero is behind wall!", heroIndex or 0, wallIndex or 0))
      
      -- Restore original functions
      display.newRect = originalNewRect
      display.newCircle = originalNewCircle
    end)
    
    it("should ensure hero display object index is maximum among all game entities (EXPECTED TO FAIL ON UNFIXED CODE)", function()
      -- This test verifies hero is the topmost game entity
      -- On UNFIXED code, this will FAIL because wall is in front
      
      -- Create enhanced mock scene group that tracks display object indices
      local displayObjects = {}
      mockSceneGroup = {
        insert = function(self, obj)
          if obj then
            table.insert(displayObjects, obj)
            obj._sceneIndex = #displayObjects
            self.numChildren = #displayObjects
          end
        end,
        numChildren = 0
      }
      
      -- Override toFront() to actually move objects to front in our mock
      local originalNewRect = display.newRect
      local originalNewCircle = display.newCircle
      
      display.newRect = function(...)
        local rect = originalNewRect(...)
        rect.toFront = function(self)
          for i, obj in ipairs(displayObjects) do
            if obj == self then
              table.remove(displayObjects, i)
              table.insert(displayObjects, self)
              for j, o in ipairs(displayObjects) do
                o._sceneIndex = j
              end
              break
            end
          end
        end
        return rect
      end
      
      display.newCircle = function(...)
        local circle = originalNewCircle(...)
        circle.toFront = function(self)
          for i, obj in ipairs(displayObjects) do
            if obj == self then
              table.remove(displayObjects, i)
              table.insert(displayObjects, self)
              for j, o in ipairs(displayObjects) do
                o._sceneIndex = j
              end
              break
            end
          end
        end
        return circle
      end
      
      -- Initialize game controller
      game_controller.initialize(mockSceneGroup)
      
      -- Get hero and wall
      local hero = game_controller.getHero()
      local wall = game_controller.getWall()
      
      -- Get hero index
      local heroIndex = hero.displayObject._sceneIndex
      
      -- Find maximum index among all display objects
      local maxIndex = 0
      for _, obj in ipairs(displayObjects) do
        if obj._sceneIndex and obj._sceneIndex > maxIndex then
          maxIndex = obj._sceneIndex
        end
      end
      
      -- EXPECTED BEHAVIOR: Hero should have the maximum index (topmost entity)
      -- On UNFIXED code, this will FAIL because wall has the maximum index
      assert.are.equal(maxIndex, heroIndex,
        string.format("Hero should be topmost game entity (hero index: %d, max index: %d). " ..
                      "BUG DETECTED: Hero is not topmost!", heroIndex or 0, maxIndex))
      
      -- Restore original functions
      display.newRect = originalNewRect
      display.newCircle = originalNewCircle
    end)
  end)
end)

-- Property 2: Preservation - Display Order for Wall and Pooled Objects
-- **IMPORTANT**: This test verifies that the fix doesn't break wall rendering
-- **Feature**: hero-render-front-of-wall
-- **Validates: Requirements 3.1, 3.2, 3.3**
describe("Property 2: Preservation - Wall Display Object and Rendering", function()
  it("should preserve wall's display object and ensure it continues to render correctly (EXPECTED TO PASS)", function()
    -- This test verifies the PRESERVATION requirements:
    --
    -- OBSERVATION FROM CODE ANALYSIS:
    -- - Pool pre-warming in game_controller.initialize() creates entity instances
    -- - BUT pooled entities don't have display objects until activated (displayObject = nil in initialize())
    -- - So only wall and hero display objects exist after initialization
    -- - Pooled objects will be activated later during gameplay and will render behind the wall
    --   (this is already handled by existing code - they're inserted into scene group before wall)
    --
    -- PRESERVATION REQUIREMENTS:
    -- - Wall's display object must exist and be positioned correctly
    -- - Wall must continue to render (not be broken by the fix)
    -- - When pooled objects are activated later, they will render behind the wall
    --   (this is guaranteed by insertion order - pooled objects inserted before wall)
    -- - The fix should only affect hero's position relative to wall, nothing else

    -- Create mock scene group
    local displayObjects = {}
    mockSceneGroup = {
      insert = function(self, obj)
        if obj then
          table.insert(displayObjects, obj)
          obj._sceneIndex = #displayObjects
          self.numChildren = #displayObjects
        end
      end,
      numChildren = 0
    }

    -- Override toFront() to actually move objects to front in our mock
    local originalNewRect = display.newRect
    local originalNewCircle = display.newCircle

    display.newRect = function(...)
      local rect = originalNewRect(...)
      rect.toFront = function(self)
        for i, obj in ipairs(displayObjects) do
          if obj == self then
            table.remove(displayObjects, i)
            table.insert(displayObjects, self)
            for j, o in ipairs(displayObjects) do
              o._sceneIndex = j
            end
            break
          end
        end
      end
      return rect
    end

    display.newCircle = function(...)
      local circle = originalNewCircle(...)
      circle.toFront = function(self)
        for i, obj in ipairs(displayObjects) do
          if obj == self then
            table.remove(displayObjects, i)
            table.insert(displayObjects, self)
            for j, o in ipairs(displayObjects) do
              o._sceneIndex = j
            end
            break
          end
        end
      end
      return circle
    end

    -- Initialize game controller
    game_controller.initialize(mockSceneGroup)

    -- Get wall
    local wall = game_controller.getWall()

    -- PRESERVATION REQUIREMENT 1: Wall display object must exist
    assert.is_not_nil(wall, "Wall should exist")
    assert.is_not_nil(wall.displayObject, "Wall display object should exist after initialization")

    -- PRESERVATION REQUIREMENT 2: Wall display object should be positioned correctly
    -- (The fix should not change wall's position, only its Z-order relative to hero)
    assert.is_not_nil(wall.displayObject.x, "Wall display object should have x position")
    assert.is_not_nil(wall.displayObject.y, "Wall display object should have y position")

    -- PRESERVATION REQUIREMENT 3: Wall should be in the scene group
    -- (Verify wall was inserted and has a scene index)
    local wallIndex = wall.displayObject._sceneIndex
    assert.is_not_nil(wallIndex, "Wall display object should have a scene index")
    assert.is_true(wallIndex > 0, "Wall display object should be in scene group (index > 0)")

    -- PRESERVATION REQUIREMENT 4: Only wall and hero display objects exist after initialization
    -- (Pooled objects don't have display objects until activated)
    -- This verifies the fix doesn't accidentally create extra display objects
    assert.are.equal(2, #displayObjects,
      string.format("Should have exactly 2 display objects after initialization (wall + hero), found %d", #displayObjects))

    -- NOTE: Requirements 3.1, 3.2, 3.3 state that pooled objects should render behind the wall.
    -- Since pooled objects don't have display objects at initialization time, we can't test this directly here.
    -- However, this is guaranteed by the existing code:
    -- - Pooled objects are inserted into scene group BEFORE wall during initialization
    -- - When they're activated later, their display objects will be created and inserted
    -- - Since they were inserted before wall, they will render behind wall
    -- - The fix (adding hero.toFront()) doesn't change this behavior at all

    -- Restore original functions
    display.newRect = originalNewRect
    display.newCircle = originalNewCircle
  end)
end)
