--- Property-based tests for Projectile Trajectory Origin
-- Feature: projectile-fire-from-wall, Property 4: Trajectory originates from fire origin
-- **Validates: Requirements 3.1, 3.2**

require("tests.spec_helper")

local Projectile = require("src.entities.projectile")
local property = require("lqc.property")
local lqc = require("lqc.quickcheck")
local lqc_gen = require("lqc.lqc_gen")

describe("Projectile Trajectory Origin Properties", function()

  before_each(function()
    lqc.init(100, 100)
  end)

  -- Feature: projectile-fire-from-wall, Property 4: Trajectory originates from fire origin
  -- **Validates: Requirements 3.1, 3.2**
  describe("Property 4: Trajectory originates from fire origin", function()
    it("projectile spawns at fire origin and velocity points toward target", function()
      property "Trajectory originates from fire origin" {
        generators = {
          lqc_gen.choose(0, 720),   -- origin x
          lqc_gen.choose(0, 1280),  -- origin y
          lqc_gen.choose(0, 720),   -- target x
          lqc_gen.choose(0, 1280),  -- target y
          lqc_gen.choose(100, 800)  -- speed
        },
        check = function(ox, oy, tx, ty, speed)
          -- Skip if origin == target (degenerate case)
          if ox == tx and oy == ty then
            return true
          end

          local p = Projectile:new()
          p:activate(ox, oy, tx, ty, speed, 10, 1)

          -- Property part 1: initial position equals fire origin
          if p.x ~= ox or p.y ~= oy then
            p:destroy()
            return false
          end

          -- Property part 2: velocity direction matches (target - origin) direction
          local dx = tx - ox
          local dy = ty - oy
          local dist = math.sqrt(dx * dx + dy * dy)

          -- Expected normalized direction
          local expectedDirX = dx / dist
          local expectedDirY = dy / dist

          -- Actual normalized velocity direction
          local vMag = math.sqrt(p.vx * p.vx + p.vy * p.vy)
          if vMag == 0 then
            p:destroy()
            return false
          end

          local actualDirX = p.vx / vMag
          local actualDirY = p.vy / vMag

          -- Compare with tolerance for floating point
          local epsilon = 1e-6
          local dirMatch = math.abs(actualDirX - expectedDirX) < epsilon
                       and math.abs(actualDirY - expectedDirY) < epsilon

          p:destroy()
          return dirMatch
        end
      }

      checkProperties()
    end)
  end)

end)
