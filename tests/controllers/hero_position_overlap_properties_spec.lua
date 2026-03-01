-- Property-Based Tests for Hero Position Overlap Bug
-- Tests the bug condition where hero at X=80 overlaps with first ability indicator
-- This test MUST FAIL on unfixed code to confirm the bug exists

require("tests.spec_helper")
local game_controller = require("src.controllers.game_controller")

describe("Hero Position Overlap Properties", function()
  local sceneGroup
  
  before_each(function()
    -- Create mock scene group
    sceneGroup = {
      insert = function() end,
      numChildren = 0
    }
  end)
  
  after_each(function()
    game_controller.cleanup()
  end)
  
  describe("Property 1: Fault Condition - Hero Overlap with First Ability Indicator", function()
    it("should position hero with at least 5-pixel gap from first ability indicator", function()
      -- **Validates: Requirements 2.1, 2.2**
      -- This test encodes the EXPECTED behavior (5-pixel gap)
      -- On UNFIXED code (hero at X=80), this test will FAIL (gap is -15 pixels)
      -- On FIXED code (hero at X=60), this test will PASS (gap is 5 pixels)
      
      -- Initialize game controller
      game_controller.initialize(sceneGroup)
      
      -- Get hero
      local hero = game_controller.getHero()
      assert.is_not_nil(hero)
      
      -- Hero properties
      local heroX = hero.x
      local heroRadius = 30  -- Hero has radius 30 pixels
      
      -- First ability indicator properties
      local indicatorX = 120  -- First indicator is at X=120
      local indicatorWidth = 50  -- Indicator is 50x50 pixels
      
      -- Calculate edges
      local heroRightEdge = heroX + heroRadius
      local indicatorLeftEdge = indicatorX - (indicatorWidth / 2)
      
      -- Calculate gap (positive = gap, negative = overlap)
      local gap = indicatorLeftEdge - heroRightEdge
      
      -- Assert: gap should be at least 5 pixels
      -- On unfixed code: heroX=80, heroRightEdge=110, indicatorLeftEdge=95, gap=-15 (FAIL)
      -- On fixed code: heroX=60, heroRightEdge=90, indicatorLeftEdge=95, gap=5 (PASS)
      assert.is_true(
        gap >= 5,
        string.format(
          "Expected gap >= 5 pixels, but got %d pixels. " ..
          "Hero right edge: %d (X=%d + radius=%d), " ..
          "Indicator left edge: %d (X=%d - width/2=%d)",
          gap, heroRightEdge, heroX, heroRadius,
          indicatorLeftEdge, indicatorX, indicatorWidth/2
        )
      )
    end)
  end)
end)
