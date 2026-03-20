--- Property-based tests for Walker Health Bar
-- Feature: game-visual-and-data-improvements
-- Tests Properties 4-7

require("tests.spec_helper")

local Walker = require("src.entities.walker")

describe("Walker Health Bar Properties", function()

  -- Feature: game-visual-and-data-improvements, Property 4: Walker health bar appears on activation
  -- **Validates: Requirements 2.1**
  describe("Property 4: Walker health bar appears on activation", function()
    it("should have a visible health bar instance after activation for any valid position", function()
      for _ = 1, 100 do
        -- Generate random valid positions: x in [0, 720], y in [0, 1280]
        local x = math.random(0, 720)
        local y = math.random(0, 1280)

        local walker = Walker:new()
        walker:activate(x, y, x)

        -- Walker shall have a health bar instance after activation
        assert.is_not_nil(walker.healthBar,
          "Walker should have a healthBar after activation at (" .. x .. ", " .. y .. ")")

        -- Health bar group shall be visible
        assert.is_not_nil(walker.healthBar.group,
          "Health bar should have a display group")
        assert.is_true(walker.healthBar.group.isVisible,
          "Health bar group should be visible after activation")

        -- Cleanup
        walker:destroy()
      end
    end)
  end)

  -- Feature: game-visual-and-data-improvements, Property 5: Health bar fill ratio equals current/max health
  -- **Validates: Requirements 2.2, 2.3, 2.7**
  describe("Property 5: Health bar fill ratio equals current/max health", function()
    it("should have foreground width equal to (currentHealth / maxHealth) * total width", function()
      for _ = 1, 100 do
        -- Generate random valid health values: maxHealth in (1, 1000)
        local maxHealth = math.random(1, 1000)
        -- currentHealth in [0, maxHealth]
        local currentHealth = math.random(0, maxHealth)

        local walker = Walker:new()
        walker.maxHealth = maxHealth
        walker.health = maxHealth
        walker:activate(math.random(0, 720), math.random(0, 1280), 0)

        -- Apply damage to reach the desired currentHealth
        local damage = maxHealth - currentHealth
        if damage > 0 and currentHealth > 0 then
          walker:takeDamage(damage)
        elseif currentHealth == 0 then
          -- Taking full damage deactivates the walker, so we update the bar manually
          -- to test the ratio property at zero health
          walker.health = 0
          walker.healthBar:update(0, maxHealth)
        end

        -- Calculate expected fill ratio
        local expectedRatio = currentHealth / maxHealth
        local healthBarWidth = walker.healthBar.width  -- total width (30)
        local expectedForegroundWidth = healthBarWidth * expectedRatio

        -- The foreground width shall equal currentHealth / maxHealth * total width
        assert.are.equal(expectedForegroundWidth, walker.healthBar.foreground.width,
          "Fill ratio mismatch: currentHealth=" .. currentHealth ..
          ", maxHealth=" .. maxHealth ..
          ", expected foreground width=" .. expectedForegroundWidth ..
          ", got=" .. walker.healthBar.foreground.width)

        -- Cleanup
        walker:destroy()
      end
    end)
  end)

  -- Feature: game-visual-and-data-improvements, Property 6: Walker health bar hidden on deactivation
  -- **Validates: Requirements 2.4**
  describe("Property 6: Walker health bar hidden on deactivation", function()
    it("should hide the health bar when deactivate is called", function()
      for _ = 1, 100 do
        -- Generate random valid positions
        local x = math.random(0, 720)
        local y = math.random(0, 1280)

        local walker = Walker:new()
        walker:activate(x, y, x)

        -- Verify health bar is visible before deactivation
        assert.is_true(walker.healthBar.group.isVisible,
          "Health bar should be visible before deactivation")

        -- Deactivate
        walker:deactivate()

        -- Health bar group shall be hidden (not visible)
        assert.is_false(walker.healthBar.group.isVisible,
          "Health bar group should be hidden after deactivation")

        -- Cleanup
        walker:destroy()
      end
    end)
  end)

  -- Feature: game-visual-and-data-improvements, Property 7: Health bar positioned above walker
  -- **Validates: Requirements 2.5**
  describe("Property 7: Health bar positioned above walker", function()
    it("should position health bar centered at x and at y - 25", function()
      for _ = 1, 100 do
        -- Generate random valid positions: x in [0, 720], y in [0, 1280]
        local x = math.random(0, 720)
        local y = math.random(0, 1280)

        local walker = Walker:new()
        walker:activate(x, y, x)

        local expectedBarY = y - 25

        -- Health bar shall be centered at x (background.x == x)
        assert.are.equal(x, walker.healthBar.background.x,
          "Health bar background x should equal walker x=" .. x)

        -- Health bar shall be positioned at y - 25
        assert.are.equal(expectedBarY, walker.healthBar.background.y,
          "Health bar background y should equal walker y - 25 = " .. expectedBarY)

        -- Foreground y should also be at y - 25
        assert.are.equal(expectedBarY, walker.healthBar.foreground.y,
          "Health bar foreground y should equal walker y - 25 = " .. expectedBarY)

        -- Cleanup
        walker:destroy()
      end
    end)
  end)
end)
