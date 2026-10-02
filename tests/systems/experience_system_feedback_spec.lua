-- Test for experience_system showXPFeedback function
require("tests.spec_helper")

describe("experience_system.showXPFeedback", function()
  local experience_system

  before_each(function()
    experience_system = require("src.systems.experience_system")
  end)

  after_each(function()
    package.loaded["src.systems.experience_system"] = nil
  end)

  it("should not crash with valid parameters", function()
    -- This test verifies the function can be called without crashing
    -- Visual effects are mocked by spec_helper
    local success = pcall(function()
      experience_system.showXPFeedback(10, 100, 200)
    end)
    
    assert.is_true(success)
  end)

  it("should handle invalid parameters gracefully", function()
    -- Test with nil parameters
    local success = pcall(function()
      experience_system.showXPFeedback(nil, nil, nil)
    end)
    
    assert.is_true(success)
  end)

  it("should handle invalid amount parameter", function()
    local success = pcall(function()
      experience_system.showXPFeedback("invalid", 100, 200)
    end)
    
    assert.is_true(success)
  end)

  it("should handle invalid position parameters", function()
    local success = pcall(function()
      experience_system.showXPFeedback(10, "invalid", "invalid")
    end)
    
    assert.is_true(success)
  end)

  it("should handle zero XP amount", function()
    local success = pcall(function()
      experience_system.showXPFeedback(0, 100, 200)
    end)
    
    assert.is_true(success)
  end)

  it("should handle negative XP amount", function()
    local success = pcall(function()
      experience_system.showXPFeedback(-10, 100, 200)
    end)
    
    assert.is_true(success)
  end)

  it("should handle large XP amounts", function()
    local success = pcall(function()
      experience_system.showXPFeedback(999999, 100, 200)
    end)
    
    assert.is_true(success)
  end)

  it("should handle edge screen positions", function()
    local success = pcall(function()
      experience_system.showXPFeedback(10, 0, 0)
    end)
    
    assert.is_true(success)
  end)
end)

describe("experience_system XP gain sound", function()
  local experience_system
  local Hero = require("src.entities.hero")
  local originalLoadSound
  local originalPlay
  local originalDispose
  local loadCount
  local played
  local disposed

  before_each(function()
    package.loaded["src.systems.experience_system"] = nil
    experience_system = require("src.systems.experience_system")

    originalLoadSound = audio.loadSound
    originalPlay = audio.play
    originalDispose = audio.dispose

    loadCount = 0
    played = {}
    disposed = {}
    audio.loadSound = function(filename)
      loadCount = loadCount + 1
      return { filename = filename }
    end
    audio.play = function(handle)
      table.insert(played, handle)
    end
    audio.dispose = function(handle)
      table.insert(disposed, handle)
    end
  end)

  after_each(function()
    audio.loadSound = originalLoadSound
    audio.play = originalPlay
    audio.dispose = originalDispose
    package.loaded["src.systems.experience_system"] = nil
  end)

  it("loads the sound once and reuses it for every XP award", function()
    experience_system.initialize(Hero:new(360, 1180), function() end)

    for _ = 1, 20 do
      experience_system.showXPFeedback(10, 100, 200)
    end

    assert.are.equal(1, loadCount)
    assert.are.equal(20, #played)
    for _, handle in ipairs(played) do
      assert.are.equal(played[1], handle)
    end

    experience_system.cleanup()
  end)

  it("disposes the sound on cleanup and reloads it on the next initialize", function()
    experience_system.initialize(Hero:new(360, 1180), function() end)
    experience_system.showXPFeedback(10, 100, 200)
    local firstHandle = played[1]

    experience_system.cleanup()

    assert.are.equal(1, #disposed)
    assert.are.equal(firstHandle, disposed[1])

    experience_system.initialize(Hero:new(360, 1180), function() end)
    assert.are.equal(2, loadCount)
    experience_system.cleanup()
  end)

  it("plays nothing when the sound file is missing", function()
    local originalPathForFile = system.pathForFile
    system.pathForFile = function(name, dir)
      if name:match("%.wav$") then return nil end
      return originalPathForFile(name, dir)
    end

    experience_system.initialize(Hero:new(360, 1180), function() end)
    local success = pcall(experience_system.showXPFeedback, 10, 100, 200)
    system.pathForFile = originalPathForFile

    assert.is_true(success)
    assert.are.equal(0, loadCount)
    assert.are.equal(0, #played)
    experience_system.cleanup()
  end)
end)
