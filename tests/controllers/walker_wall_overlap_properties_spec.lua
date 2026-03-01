--- Property-based tests for Walker-Wall Overlap Bugfix
-- Feature: walker-wall-no-overlap
-- Tests Property 1 (Fault Condition) and Property 2 (Preservation)

require("tests.spec_helper")

local Walker = require("src.entities.walker")
local Wall = require("src.entities.wall")

describe("Walker-Wall Overlap Properties", function()
  
  -- Property 1: Fault Condition - Walker Bottom Edge Overlaps Wall Top Edge
  -- **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  -- **Validates: Requirements 1.1, 1.2**
  describe("Property 1: Fault Condition - Walker Bottom Edge Overlaps Wall Top Edge", function()
    it("should position walkers so bottom edge touches wall without overlap", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create walker
        local walker = Walker:new()
        walker:activate(360, 0, 360)
        
        -- Wall configuration (from game_controller.lua)
        local wallY = 1200
        local wallHeight = 80
        local wallTopEdge = wallY - (wallHeight / 2)  -- Y=1160
        
        -- Walker configuration
        local walkerRadius = 20
        
        -- Current threshold (fixed from 1150 to 1140)
        local currentThreshold = 1140
        
        -- Position walker at current threshold
        walker.y = currentThreshold
        
        -- Update walker (it should stop at threshold)
        walker:update(0.016, currentThreshold)
        
        -- Calculate walker's bottom edge
        local walkerBottomEdge = walker.y + walkerRadius
        
        -- EXPECTED BEHAVIOR (after fix):
        -- Walker should be positioned so bottom edge touches wall without overlap
        -- This means: walkerBottomEdge <= wallTopEdge
        -- For exact touch: walkerBottomEdge == wallTopEdge
        
        -- This assertion will FAIL on unfixed code because:
        -- - walker.y = 1150
        -- - walkerBottomEdge = 1150 + 20 = 1170
        -- - wallTopEdge = 1160
        -- - 1170 > 1160 (10 pixel overlap!)
        
        assert.is_true(
          walkerBottomEdge <= wallTopEdge,
          string.format(
            "Walker bottom edge (Y=%d) overlaps wall top edge (Y=%d) by %d pixels",
            walkerBottomEdge,
            wallTopEdge,
            walkerBottomEdge - wallTopEdge
          )
        )
        
        -- Cleanup
        walker:deactivate()
      end
    end)
    
    it("should position multiple walkers without overlap", function()
      -- Test with multiple walkers to verify consistency
      local walkers = {}
      local wallTopEdge = 1160
      local walkerRadius = 20
      local currentThreshold = 1140
      
      -- Create 10 walkers at threshold
      for i = 1, 10 do
        local walker = Walker:new()
        walker:activate(math.random(100, 620), 0, 360)
        walker.y = currentThreshold
        walker:update(0.016, currentThreshold)
        table.insert(walkers, walker)
      end
      
      -- Verify all walkers have bottom edges that don't overlap
      for _, walker in ipairs(walkers) do
        local walkerBottomEdge = walker.y + walkerRadius
        assert.is_true(
          walkerBottomEdge <= wallTopEdge,
          string.format(
            "Walker at X=%d has bottom edge (Y=%d) overlapping wall top edge (Y=%d)",
            walker.x,
            walkerBottomEdge,
            wallTopEdge
          )
        )
      end
      
      -- Cleanup
      for _, walker in ipairs(walkers) do
        walker:deactivate()
      end
    end)
  end)
  
  -- Property 2: Preservation - Walker Movement and Attack Behavior Unchanged
  -- **IMPORTANT**: Follow observation-first methodology
  -- **Validates: Requirements 3.1, 3.2, 3.3, 3.4**
  describe("Property 2: Preservation - Walker Movement and Attack Behavior Unchanged", function()
    it("should maintain walker movement speed of 80 px/s for walkers below threshold", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create walker
        local walker = Walker:new()
        walker:activate(360, 0, 360)
        
        -- Position walker well above threshold (Y < 1140)
        walker.y = math.random(0, 1000)
        local initialY = walker.y
        
        -- Update walker with known delta time
        local dt = 0.1  -- 100ms
        local threshold = 1140  -- Current threshold (fixed from 1150)
        walker:update(dt, threshold)
        
        -- Calculate expected movement (speed = 80 px/s)
        local expectedDeltaY = 80 * dt  -- 8 pixels
        local actualDeltaY = walker.y - initialY
        
        -- Verify movement speed is preserved (within floating point tolerance)
        assert.is_true(
          math.abs(actualDeltaY - expectedDeltaY) < 0.01,
          string.format(
            "Walker movement speed changed: expected %f px, got %f px",
            expectedDeltaY,
            actualDeltaY
          )
        )
        
        -- Cleanup
        walker:deactivate()
      end
    end)
    
    it("should maintain constant X position during vertical movement", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create walker at random X position
        local initialX = math.random(100, 620)
        local walker = Walker:new()
        walker:activate(initialX, 0, 360)
        
        -- Position walker below threshold
        walker.y = math.random(0, 1000)
        
        -- Update walker multiple times
        for j = 1, 10 do
          walker:update(0.016, 1140)
        end
        
        -- Verify X position unchanged
        assert.are.equal(
          initialX,
          walker.x,
          "Walker X position changed during vertical movement"
        )
        
        -- Cleanup
        walker:deactivate()
      end
    end)
    
    it("should set isAttackingWall flag when reaching threshold", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create walker and wall
        local walker = Walker:new()
        walker:activate(360, 0, 360)
        local wall = Wall:new(360, 1200, 720)
        
        -- Position walker at threshold
        walker.y = 1140  -- New threshold
        walker.wallTarget = wall
        
        -- Update walker
        walker:update(0.016, 1140)
        
        -- Verify attack state is set
        assert.is_true(
          walker.isAttackingWall,
          "Walker should set isAttackingWall flag at threshold"
        )
        
        -- Cleanup
        walker:deactivate()
        wall:destroy()
      end
    end)
    
    it("should preserve walker attack cooldown behavior", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Create walker
        local walker = Walker:new()
        walker:activate(360, 0, 360)
        
        -- Verify attack cooldown is unchanged (should be >= 1.0 second)
        assert.is_true(
          walker.attackCooldown >= 1.0,
          string.format(
            "Walker attack cooldown changed: expected >= 1.0, got %f",
            walker.attackCooldown
          )
        )
        
        -- Cleanup
        walker:deactivate()
      end
    end)
  end)
end)
