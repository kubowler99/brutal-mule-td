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
