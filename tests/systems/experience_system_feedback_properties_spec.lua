--- Property-based tests for Experience System Feedback Functions
-- Feature: automatic-xp-on-defeat
-- Tests Property 6, 7, 8, 9: Visual Feedback, Audio Feedback, XP Amount Display, Feedback Timing

require("tests.spec_helper")

local experience_system = require("src.systems.experience_system")
local Hero = require("src.entities.hero")

-- **Validates: Requirements 5.1**
-- Property 6: Visual Feedback on XP Award
describe("Property 6: Visual Feedback on XP Award", function()
  local hero

  before_each(function()
    -- Create hero for initialization
    hero = Hero:new(360, 1180)
    experience_system.initialize(hero, function() end)
  end)

  after_each(function()
    experience_system.cleanup()
    hero = nil
  end)

  it("should create visual effects at enemy defeat position for any XP award", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random XP amount and position
      local xpAmount = math.random(1, 200)
      local enemyX = math.random(0, 720)
      local enemyY = math.random(0, 1280)

      -- Track display object creation
      local displayObjectsCreated = {}
      local originalNewText = display.newText
      local originalNewCircle = display.newCircle

      -- Mock display.newText to track text creation
      display.newText = function(options)
        local textObj = originalNewText(options)
        textObj._createdAt = {x = options.x, y = options.y}
        textObj._text = options.text
        table.insert(displayObjectsCreated, {type = "text", obj = textObj})
        return textObj
      end

      -- Mock display.newCircle to track circle/glow creation
      display.newCircle = function(x, y, r)
        local circleObj = originalNewCircle(x, y, r)
        circleObj._createdAt = {x = x, y = y}
        table.insert(displayObjectsCreated, {type = "circle", obj = circleObj})
        return circleObj
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(xpAmount, enemyX, enemyY)

      -- Property: Visual effects should be created at the specified position
      local foundText = false
      local foundCircle = false

      for _, item in ipairs(displayObjectsCreated) do
        if item.type == "text" and item.obj._createdAt then
          assert.are.equal(enemyX, item.obj._createdAt.x,
            string.format("Iteration %d: Text should be created at enemy X position %d", iteration, enemyX))
          assert.are.equal(enemyY, item.obj._createdAt.y,
            string.format("Iteration %d: Text should be created at enemy Y position %d", iteration, enemyY))
          foundText = true
        elseif item.type == "circle" and item.obj._createdAt then
          assert.are.equal(enemyX, item.obj._createdAt.x,
            string.format("Iteration %d: Glow effect should be created at enemy X position %d", iteration, enemyX))
          assert.are.equal(enemyY, item.obj._createdAt.y,
            string.format("Iteration %d: Glow effect should be created at enemy Y position %d", iteration, enemyY))
          foundCircle = true
        end
      end

      -- Verify both visual elements were created
      assert.is_true(foundText,
        string.format("Iteration %d: Text visual effect should be created", iteration))
      assert.is_true(foundCircle,
        string.format("Iteration %d: Glow visual effect should be created", iteration))

      -- Restore original functions
      display.newText = originalNewText
      display.newCircle = originalNewCircle
    end
  end)

  it("should create visual effects at various screen positions", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Test various positions including edge cases
      local positions = {
        {0, 0},                    -- Top-left corner
        {720, 0},                  -- Top-right corner
        {0, 1280},                 -- Bottom-left corner
        {720, 1280},               -- Bottom-right corner
        {360, 640},                -- Center
        {math.random(0, 720), math.random(0, 1280)}  -- Random position
      }
      local pos = positions[math.random(1, #positions)]
      local xpAmount = math.random(5, 100)

      -- Track display object creation
      local visualEffectsCreated = 0
      local originalNewText = display.newText
      local originalNewCircle = display.newCircle

      display.newText = function(options)
        visualEffectsCreated = visualEffectsCreated + 1
        return originalNewText(options)
      end

      display.newCircle = function(x, y, r)
        visualEffectsCreated = visualEffectsCreated + 1
        return originalNewCircle(x, y, r)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(xpAmount, pos[1], pos[2])

      -- Property: Visual effects should be created regardless of position
      assert.is_true(visualEffectsCreated >= 2,
        string.format("Iteration %d: At least 2 visual effects should be created at position (%d, %d)", 
          iteration, pos[1], pos[2]))

      -- Restore original functions
      display.newText = originalNewText
      display.newCircle = originalNewCircle
    end
  end)

  it("should create visual effects for any XP amount value", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Test various XP amounts including edge cases
      local xpAmounts = {
        1,                          -- Minimum XP
        math.random(1, 10),        -- Small XP
        math.random(11, 50),       -- Medium XP
        math.random(51, 200),      -- Large XP
        math.random(201, 1000)     -- Very large XP
      }
      local xpAmount = xpAmounts[math.random(1, #xpAmounts)]

      -- Track display object creation
      local visualEffectsCreated = false
      local originalNewText = display.newText

      display.newText = function(options)
        visualEffectsCreated = true
        return originalNewText(options)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(xpAmount, 360, 640)

      -- Property: Visual effects should be created for any valid XP amount
      assert.is_true(visualEffectsCreated,
        string.format("Iteration %d: Visual effects should be created for XP amount %d", iteration, xpAmount))

      -- Restore original function
      display.newText = originalNewText
    end
  end)
end)

-- **Validates: Requirements 5.2**
-- Property 7: Audio Feedback on XP Award
describe("Property 7: Audio Feedback on XP Award", function()
  local hero

  before_each(function()
    -- Create hero for initialization
    hero = Hero:new(360, 1180)
    experience_system.initialize(hero, function() end)
  end)

  after_each(function()
    experience_system.cleanup()
    hero = nil
  end)

  it("should attempt to play audio for any XP award", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random XP amount and position
      local xpAmount = math.random(1, 200)
      local enemyX = math.random(0, 720)
      local enemyY = math.random(0, 1280)

      -- Track audio.play calls
      local audioPlayCalled = false
      local originalAudioPlay = audio.play

      audio.play = function(...)
        audioPlayCalled = true
        return originalAudioPlay(...)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(xpAmount, enemyX, enemyY)

      -- Property: Audio should be attempted to play (may fail if file doesn't exist, but attempt should be made)
      -- Note: The implementation wraps audio in pcall, so we check if play was called
      assert.is_true(audioPlayCalled,
        string.format("Iteration %d: Audio play should be attempted for XP award", iteration))

      -- Restore original function
      audio.play = originalAudioPlay
    end
  end)

  it("should attempt audio playback regardless of XP amount", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Test various XP amounts
      local xpAmounts = {1, 10, 50, 100, 500, 1000}
      local xpAmount = xpAmounts[math.random(1, #xpAmounts)]

      -- Track audio.play calls
      local audioPlayCalled = false
      local originalAudioPlay = audio.play

      audio.play = function(...)
        audioPlayCalled = true
        return originalAudioPlay(...)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(xpAmount, 360, 640)

      -- Property: Audio should be attempted regardless of XP amount
      assert.is_true(audioPlayCalled,
        string.format("Iteration %d: Audio should be attempted for XP amount %d", iteration, xpAmount))

      -- Restore original function
      audio.play = originalAudioPlay
    end
  end)

  it("should attempt audio playback regardless of position", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random position
      local enemyX = math.random(0, 720)
      local enemyY = math.random(0, 1280)

      -- Track audio.play calls
      local audioPlayCalled = false
      local originalAudioPlay = audio.play

      audio.play = function(...)
        audioPlayCalled = true
        return originalAudioPlay(...)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(10, enemyX, enemyY)

      -- Property: Audio should be attempted regardless of position
      assert.is_true(audioPlayCalled,
        string.format("Iteration %d: Audio should be attempted at position (%d, %d)", iteration, enemyX, enemyY))

      -- Restore original function
      audio.play = originalAudioPlay
    end
  end)
end)

-- **Validates: Requirements 5.3**
-- Property 8: XP Amount Display
describe("Property 8: XP Amount Display", function()
  local hero

  before_each(function()
    -- Create hero for initialization
    hero = Hero:new(360, 1180)
    experience_system.initialize(hero, function() end)
  end)

  after_each(function()
    experience_system.cleanup()
    hero = nil
  end)

  it("should display correct XP amount in text for any XP value", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random XP amount
      local xpAmount = math.random(1, 500)

      -- Track text creation
      local displayedText = nil
      local originalNewText = display.newText

      display.newText = function(options)
        displayedText = options.text
        return originalNewText(options)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(xpAmount, 360, 640)

      -- Property: Displayed text should contain the XP amount
      assert.is_not_nil(displayedText,
        string.format("Iteration %d: Text should be created", iteration))

      -- Check if text contains the XP amount (format: "+X XP")
      local expectedText = "+" .. tostring(math.floor(xpAmount)) .. " XP"
      assert.are.equal(expectedText, displayedText,
        string.format("Iteration %d: Text should display '+%d XP', got '%s'", 
          iteration, math.floor(xpAmount), displayedText or "nil"))

      -- Restore original function
      display.newText = originalNewText
    end
  end)

  it("should display XP amount with correct formatting for various values", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Test various XP amounts including edge cases
      local xpAmounts = {
        1,                          -- Single digit
        math.random(10, 99),       -- Two digits
        math.random(100, 999),     -- Three digits
        math.random(1000, 9999)    -- Four digits
      }
      local xpAmount = xpAmounts[math.random(1, #xpAmounts)]

      -- Track text creation
      local displayedText = nil
      local originalNewText = display.newText

      display.newText = function(options)
        displayedText = options.text
        return originalNewText(options)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(xpAmount, 360, 640)

      -- Property: Text should always follow the format "+X XP"
      assert.is_not_nil(displayedText,
        string.format("Iteration %d: Text should be created for XP amount %d", iteration, xpAmount))

      -- Verify format
      local expectedText = "+" .. tostring(math.floor(xpAmount)) .. " XP"
      assert.are.equal(expectedText, displayedText,
        string.format("Iteration %d: Text format should be correct for XP %d", iteration, xpAmount))

      -- Restore original function
      display.newText = originalNewText
    end
  end)

  it("should handle fractional XP amounts by flooring to integer", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate fractional XP amount
      local xpAmount = math.random(1, 100) + math.random()

      -- Track text creation
      local displayedText = nil
      local originalNewText = display.newText

      display.newText = function(options)
        displayedText = options.text
        return originalNewText(options)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(xpAmount, 360, 640)

      -- Property: Fractional XP should be floored to integer in display
      local expectedText = "+" .. tostring(math.floor(xpAmount)) .. " XP"
      assert.are.equal(expectedText, displayedText,
        string.format("Iteration %d: Fractional XP %.2f should be displayed as %d", 
          iteration, xpAmount, math.floor(xpAmount)))

      -- Restore original function
      display.newText = originalNewText
    end
  end)

  it("should display XP amount consistently across multiple calls", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random XP amount
      local xpAmount = math.random(1, 200)

      -- Track text creation for multiple calls
      local displayedTexts = {}
      local originalNewText = display.newText

      display.newText = function(options)
        table.insert(displayedTexts, options.text)
        return originalNewText(options)
      end

      -- Call showXPFeedback multiple times with same XP amount
      experience_system.showXPFeedback(xpAmount, 100, 200)
      experience_system.showXPFeedback(xpAmount, 300, 400)
      experience_system.showXPFeedback(xpAmount, 500, 600)

      -- Property: Same XP amount should produce same text across calls
      local expectedText = "+" .. tostring(math.floor(xpAmount)) .. " XP"
      for i, text in ipairs(displayedTexts) do
        assert.are.equal(expectedText, text,
          string.format("Iteration %d, Call %d: Text should be consistent for XP %d", iteration, i, xpAmount))
      end

      -- Restore original function
      display.newText = originalNewText
    end
  end)
end)

-- **Validates: Requirements 5.4**
-- Property 9: Feedback Timing
describe("Property 9: Feedback Timing", function()
  local hero

  before_each(function()
    -- Create hero for initialization
    hero = Hero:new(360, 1180)
    experience_system.initialize(hero, function() end)
  end)

  after_each(function()
    experience_system.cleanup()
    hero = nil
  end)

  it("should set transition duration to 1000ms (1 second) for any XP award", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random XP amount and position
      local xpAmount = math.random(1, 200)
      local enemyX = math.random(0, 720)
      local enemyY = math.random(0, 1280)

      -- Track transition.to calls
      local transitionDurations = {}
      local originalTransitionTo = transition.to

      transition.to = function(target, params)
        if params and params.time then
          table.insert(transitionDurations, params.time)
        end
        return originalTransitionTo(target, params)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(xpAmount, enemyX, enemyY)

      -- Property: All transitions should have duration of 1000ms (1 second)
      for i, duration in ipairs(transitionDurations) do
        assert.are.equal(1000, duration,
          string.format("Iteration %d, Transition %d: Duration should be 1000ms, got %d", 
            iteration, i, duration))
      end

      -- Verify at least one transition was created
      assert.is_true(#transitionDurations > 0,
        string.format("Iteration %d: At least one transition should be created", iteration))

      -- Restore original function
      transition.to = originalTransitionTo
    end
  end)

  it("should create transitions with 1000ms duration regardless of XP amount", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Test various XP amounts
      local xpAmounts = {1, 10, 50, 100, 500, 1000}
      local xpAmount = xpAmounts[math.random(1, #xpAmounts)]

      -- Track transition.to calls
      local transitionDurations = {}
      local originalTransitionTo = transition.to

      transition.to = function(target, params)
        if params and params.time then
          table.insert(transitionDurations, params.time)
        end
        return originalTransitionTo(target, params)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(xpAmount, 360, 640)

      -- Property: Duration should be 1000ms regardless of XP amount
      for i, duration in ipairs(transitionDurations) do
        assert.are.equal(1000, duration,
          string.format("Iteration %d, XP %d, Transition %d: Duration should be 1000ms", 
            iteration, xpAmount, i))
      end

      -- Restore original function
      transition.to = originalTransitionTo
    end
  end)

  it("should create transitions with 1000ms duration regardless of position", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random position
      local enemyX = math.random(0, 720)
      local enemyY = math.random(0, 1280)

      -- Track transition.to calls
      local transitionDurations = {}
      local originalTransitionTo = transition.to

      transition.to = function(target, params)
        if params and params.time then
          table.insert(transitionDurations, params.time)
        end
        return originalTransitionTo(target, params)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(10, enemyX, enemyY)

      -- Property: Duration should be 1000ms regardless of position
      for i, duration in ipairs(transitionDurations) do
        assert.are.equal(1000, duration,
          string.format("Iteration %d, Position (%d, %d), Transition %d: Duration should be 1000ms", 
            iteration, enemyX, enemyY, i))
      end

      -- Restore original function
      transition.to = originalTransitionTo
    end
  end)

  it("should create multiple transitions all with 1000ms duration", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random XP amount
      local xpAmount = math.random(1, 100)

      -- Track transition.to calls
      local transitionDurations = {}
      local originalTransitionTo = transition.to

      transition.to = function(target, params)
        if params and params.time then
          table.insert(transitionDurations, params.time)
        end
        return originalTransitionTo(target, params)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(xpAmount, 360, 640)

      -- Property: All transitions should have the same duration (1000ms)
      -- Typically there should be 2 transitions (text and glow)
      assert.is_true(#transitionDurations >= 2,
        string.format("Iteration %d: At least 2 transitions should be created", iteration))

      -- Verify all durations are 1000ms
      for i, duration in ipairs(transitionDurations) do
        assert.are.equal(1000, duration,
          string.format("Iteration %d, Transition %d: All transitions should have 1000ms duration", 
            iteration, i))
      end

      -- Restore original function
      transition.to = originalTransitionTo
    end
  end)

  it("should complete feedback within 1 second time constraint", function()
    -- Run property test with 100 iterations
    for iteration = 1, 100 do
      -- Generate random XP amount and position
      local xpAmount = math.random(1, 200)
      local enemyX = math.random(0, 720)
      local enemyY = math.random(0, 1280)

      -- Track transition.to calls and verify timing constraint
      local maxDuration = 0
      local originalTransitionTo = transition.to

      transition.to = function(target, params)
        if params and params.time then
          maxDuration = math.max(maxDuration, params.time)
        end
        return originalTransitionTo(target, params)
      end

      -- Call showXPFeedback
      experience_system.showXPFeedback(xpAmount, enemyX, enemyY)

      -- Property: Maximum transition duration should not exceed 1000ms (1 second)
      assert.is_true(maxDuration <= 1000,
        string.format("Iteration %d: Feedback should complete within 1 second (1000ms), max duration was %d", 
          iteration, maxDuration))

      -- Restore original function
      transition.to = originalTransitionTo
    end
  end)
end)
