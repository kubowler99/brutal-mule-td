--- Property-based tests for Projectile Visual Rendering
-- Feature: game-visual-and-data-improvements
-- Tests Properties 1-3

require("tests.spec_helper")

local Projectile = require("src.entities.projectile")

describe("Projectile Visual Properties", function()

  -- Feature: game-visual-and-data-improvements, Property 1: Active projectiles have visible display objects
  -- **Validates: Requirements 1.1, 1.5**
  describe("Property 1: Active projectiles have visible display objects", function()
    it("should create a distinct visible display object at spawn position for each active projectile", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Generate random number of simultaneous projectiles (1 to 5)
        local count = math.random(1, 5)
        local projectiles = {}
        local displayObjects = {}

        for j = 1, count do
          -- Generate random valid spawn positions: x in [0, 720], y in [0, 1280]
          local spawnX = math.random(0, 720)
          local spawnY = math.random(0, 1280)
          local targetX = math.random(0, 720)
          local targetY = math.random(0, 1280)

          local p = Projectile:new()
          p:activate(spawnX, spawnY, targetX, targetY, 400, 10, 0)
          table.insert(projectiles, p)

          -- Each active projectile shall have a display object
          assert.is_not_nil(p.displayObject,
            "Projectile " .. j .. " should have a display object after activation")

          -- Display object shall be visible
          assert.is_true(p.displayObject.isVisible,
            "Projectile " .. j .. " display object should be visible")

          -- Display object shall be positioned at spawn coordinates
          assert.are.equal(spawnX, p.displayObject.x,
            "Projectile " .. j .. " display x should match spawn x")
          assert.are.equal(spawnY, p.displayObject.y,
            "Projectile " .. j .. " display y should match spawn y")

          -- Track display objects for distinctness check
          table.insert(displayObjects, p.displayObject)
        end

        -- Each active projectile shall have its own distinct display object
        for a = 1, #displayObjects do
          for b = a + 1, #displayObjects do
            assert.are_not.equal(displayObjects[a], displayObjects[b],
              "Projectiles " .. a .. " and " .. b .. " should have distinct display objects")
          end
        end

        -- Cleanup
        for _, p in ipairs(projectiles) do
          p:destroy()
        end
      end
    end)
  end)

  -- Feature: game-visual-and-data-improvements, Property 2: Projectile display position tracks logical position
  -- **Validates: Requirements 1.2**
  describe("Property 2: Projectile display position tracks logical position", function()
    it("should sync display object position with logical position after update", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Generate random spawn and target positions
        local spawnX = math.random(0, 720)
        local spawnY = math.random(0, 1280)
        local targetX = math.random(0, 720)
        local targetY = math.random(0, 1280)

        -- Generate random velocity components via speed
        local speed = math.random(50, 1000)

        -- Generate random positive delta time (small frame-like values)
        local dt = math.random(1, 50) / 1000  -- 1ms to 50ms

        local p = Projectile:new()
        p:activate(spawnX, spawnY, targetX, targetY, speed, 10, 0)

        -- Update with random dt
        p:update(dt)

        -- If projectile is still active, display position must match logical position
        if p.isActive and p.displayObject then
          assert.are.equal(p.x, p.displayObject.x,
            "Display x should equal logical x after update")
          assert.are.equal(p.y, p.displayObject.y,
            "Display y should equal logical y after update")
        end

        -- Cleanup
        p:destroy()
      end
    end)
  end)

  -- Feature: game-visual-and-data-improvements, Property 3: Deactivated projectile display is hidden
  -- **Validates: Requirements 1.3**
  describe("Property 3: Deactivated projectile display is hidden", function()
    it("should hide display object when deactivate is called", function()
      -- Run property test with 100 iterations
      for i = 1, 100 do
        -- Generate random valid spawn positions
        local spawnX = math.random(0, 720)
        local spawnY = math.random(0, 1280)
        local targetX = math.random(0, 720)
        local targetY = math.random(0, 1280)

        local p = Projectile:new()
        p:activate(spawnX, spawnY, targetX, targetY, 400, 10, 0)

        -- Verify it's visible before deactivation
        assert.is_true(p.displayObject.isVisible,
          "Display object should be visible before deactivation")

        -- Deactivate
        p:deactivate()

        -- Display object's isVisible shall be false
        assert.is_false(p.displayObject.isVisible,
          "Display object isVisible should be false after deactivation")

        -- Cleanup
        p:destroy()
      end
    end)
  end)
end)
