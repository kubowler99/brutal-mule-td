--- Property-based tests for ArcaneBolt Multi-Projectile Origin Consistency
-- Feature: projectile-fire-from-wall, Property 6: Consistent origin within multi-projectile activation
-- **Validates: Requirements 4.3**

require("tests.spec_helper")

local ArcaneBolt = require("src.entities.abilities.arcane_bolt")
local property = require("lqc.property")
local lqc = require("lqc.quickcheck")
local lqc_gen = require("lqc.lqc_gen")

describe("ArcaneBolt Multi-Projectile Origin Properties", function()

  before_each(function()
    lqc.init(100, 100)
  end)

  -- Feature: projectile-fire-from-wall, Property 6: Consistent origin within multi-projectile activation
  -- **Validates: Requirements 4.3**
  describe("Property 6: Consistent origin within multi-projectile activation", function()
    it("all projectiles from a single activation share the same origin position", function()
      property "Consistent origin within multi-projectile activation" {
        generators = {
          lqc_gen.choose(1, 5),     -- projectileCount
          lqc_gen.choose(0, 720),   -- origin x
          lqc_gen.choose(0, 1280)   -- origin y
        },
        check = function(projectileCount, ox, oy)
          -- Create an ArcaneBolt ability with the generated projectileCount
          local ability = ArcaneBolt:new()
          ability.projectileCount = projectileCount
          -- Ensure canActivate returns true
          ability.lastActivation = 0
          ability._lastCurrentTime = 2.0

          -- Track all created projectiles and their activation positions
          local spawnedPositions = {}

          local mockPool = {
            get = function()
              local proj = {
                activate = function(self, x, y, targetX, targetY, speed, damage, pierce)
                  table.insert(spawnedPositions, { x = x, y = y })
                end
              }
              return proj
            end
          }

          -- Create at least one active enemy for targeting
          local enemies = {
            { x = 360, y = 200, isActive = true, speed = 0 }
          }

          -- Activate the ability
          ability:activate(ox, oy, enemies, mockPool)

          -- All created projectiles must have x == ox and y == oy
          if #spawnedPositions ~= projectileCount then
            return false
          end

          for _, pos in ipairs(spawnedPositions) do
            if pos.x ~= ox or pos.y ~= oy then
              return false
            end
          end

          return true
        end
      }

      lqc.check()
      assert.is_false(lqc.failed)
    end)
  end)

end)
