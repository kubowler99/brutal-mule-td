--- Property-based tests for Combat System Fire Origin
-- Feature: projectile-fire-from-wall
-- Tests Properties 1, 2, 3, 5

require("tests.spec_helper")

local combat_system = require("src.systems.combat_system")
local property = require("lqc.property")
local lqc = require("lqc.quickcheck")
local lqc_gen = require("lqc.lqc_gen")

describe("Combat System Fire Origin Properties", function()

  before_each(function()
    lqc.init(100, 100)
    combat_system.cleanup()
  end)

  after_each(function()
    combat_system.cleanup()
  end)

  -- Feature: projectile-fire-from-wall, Property 1: Fire origin resolves to indicator position
  -- **Validates: Requirements 1.1, 1.2, 2.1, 2.3, 4.1**
  describe("Property 1: Fire origin resolves to indicator position", function()
    it("getFireOrigin returns indicator (x, y) for any valid slot with a valid indicator", function()
      property "Fire origin resolves to indicator position" {
        generators = {
          lqc_gen.choose(0, 720),   -- indicator x
          lqc_gen.choose(0, 1280),  -- indicator y
          lqc_gen.choose(1, 5)      -- slot index
        },
        check = function(indX, indY, slotIndex)
          -- Initialize combat system with a mock hero (fallback should NOT be used)
          local hero = { x = 45, y = 1200, isAlive = true, abilities = {} }
          combat_system.initialize(hero, nil, {})

          -- Build indicators array with the indicator at the generated slot
          local indicators = {}
          indicators[slotIndex] = { x = indX, y = indY }

          combat_system.setIndicatorPositions(indicators)

          -- Resolve fire origin for the slot
          local originX, originY = combat_system.getFireOrigin(slotIndex)

          -- Property: returned coordinates must match the indicator's coordinates
          return originX == indX and originY == indY
        end
      }

      checkProperties()
    end)
  end)

  -- Feature: projectile-fire-from-wall, Property 2: Fallback to hero position when no indicator exists
  -- **Validates: Requirements 1.3**
  describe("Property 2: Fallback to hero position when no indicator exists", function()
    it("getFireOrigin returns hero (x, y) when indicator is nil or missing for the slot", function()
      property "Fallback to hero position when no indicator exists" {
        generators = {
          lqc_gen.choose(0, 720),   -- hero x
          lqc_gen.choose(0, 1280),  -- hero y
          lqc_gen.choose(1, 5),     -- slot index
          lqc_gen.choose(1, 3)      -- fallback scenario: 1=nil indicators, 2=empty table, 3=indicator with nil coords
        },
        check = function(heroX, heroY, slotIndex, scenario)
          local hero = { x = heroX, y = heroY, isAlive = true, abilities = {} }
          combat_system.initialize(hero, nil, {})

          if scenario == 1 then
            -- Nil indicators (setIndicatorPositions not called or called with nil)
            combat_system.setIndicatorPositions(nil)
          elseif scenario == 2 then
            -- Empty indicators table (slot simply missing)
            combat_system.setIndicatorPositions({})
          else
            -- Indicator exists at slot but has nil coordinates
            local indicators = {}
            indicators[slotIndex] = { x = nil, y = nil }
            combat_system.setIndicatorPositions(indicators)
          end

          local originX, originY = combat_system.getFireOrigin(slotIndex)

          return originX == heroX and originY == heroY
        end
      }

      checkProperties()
    end)
  end)

  -- Feature: projectile-fire-from-wall, Property 3: Position updates reflected immediately
  -- **Validates: Requirements 2.2**
  describe("Property 3: Position updates reflected immediately", function()
    it("getFireOrigin returns updated coordinates after indicator x/y are mutated", function()
      property "Position updates reflected immediately" {
        generators = {
          lqc_gen.choose(1, 5),     -- slot index
          lqc_gen.choose(0, 720),   -- initial x
          lqc_gen.choose(0, 1280),  -- initial y
          lqc_gen.choose(0, 720),   -- updated x
          lqc_gen.choose(0, 1280)   -- updated y
        },
        check = function(slotIndex, initX, initY, newX, newY)
          -- Initialize combat system with a mock hero
          local hero = { x = 45, y = 1200, isAlive = true, abilities = {} }
          combat_system.initialize(hero, nil, {})

          -- Build indicators with initial positions and set them
          local indicators = {}
          indicators[slotIndex] = { x = initX, y = initY }
          combat_system.setIndicatorPositions(indicators)

          -- Verify initial positions are returned
          local ox, oy = combat_system.getFireOrigin(slotIndex)
          if ox ~= initX or oy ~= initY then
            return false
          end

          -- Mutate the indicator's x and y to new random values
          indicators[slotIndex].x = newX
          indicators[slotIndex].y = newY

          -- Call getFireOrigin again — must return updated values, not stale cache
          local ux, uy = combat_system.getFireOrigin(slotIndex)
          return ux == newX and uy == newY
        end
      }

      checkProperties()
    end)
  end)

  -- Feature: projectile-fire-from-wall, Property 5: Independent fire origins per ability slot
  -- **Validates: Requirements 4.2**
  describe("Property 5: Independent fire origins per ability slot", function()
    it("getFireOrigin for slot i depends only on slot i's indicator, not on other slots", function()
      property "Independent fire origins per ability slot" {
        generators = {
          lqc_gen.choose(1, 5)  -- N: number of ability slots to populate
        },
        check = function(n)
          -- Initialize combat system with a mock hero (fallback reference)
          local hero = { x = 45, y = 1200, isAlive = true, abilities = {} }
          combat_system.initialize(hero, nil, {})

          -- Generate N distinct random indicator positions (one per slot, slots 1..N)
          local indicators = {}
          for i = 1, n do
            indicators[i] = {
              x = math.random(0, 720),
              y = math.random(0, 1280)
            }
          end

          combat_system.setIndicatorPositions(indicators)

          -- For each slot i, verify getFireOrigin(i) returns slot i's position
          for i = 1, n do
            local originX, originY = combat_system.getFireOrigin(i)
            if originX ~= indicators[i].x or originY ~= indicators[i].y then
              return false
            end
          end

          -- Now mutate one slot and verify other slots are unaffected
          -- Pick a random slot to mutate
          local mutateSlot = math.random(1, n)
          local newX = math.random(0, 720)
          local newY = math.random(0, 1280)
          indicators[mutateSlot].x = newX
          indicators[mutateSlot].y = newY

          -- Verify the mutated slot returns new values
          local mx, my = combat_system.getFireOrigin(mutateSlot)
          if mx ~= newX or my ~= newY then
            return false
          end

          -- Verify all other slots still return their original values
          for i = 1, n do
            if i ~= mutateSlot then
              local ox, oy = combat_system.getFireOrigin(i)
              if ox ~= indicators[i].x or oy ~= indicators[i].y then
                return false
              end
            end
          end

          return true
        end
      }

      checkProperties()
    end)
  end)

end)
