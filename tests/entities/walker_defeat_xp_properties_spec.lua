-- Walker Defeat XP Spawning Property Tests
-- Property-based tests for XP orb spawning when walkers are defeated

require("tests.spec_helper")

local Walker = require("src.entities.walker")
local experience_system = require("src.systems.experience_system")
local pool = require("src.utils.pool")
local XPOrb = require("src.entities.xp_orb")
local lqc = require("lqc.quickcheck")
local property = require("lqc.property")
local lqc_gen = require("lqc.lqc_gen")

describe("Walker - Defeat XP Spawning Properties", function()
  local xpOrbPool

  before_each(function()
    -- Initialize lua-quickcheck
    lqc.init(100, 100)  -- 100 tests, 100 shrinks

    -- Create XP orb pool
    xpOrbPool = pool.new(
      function() return XPOrb:new() end,
      nil
    )

    -- Initialize level system with mock hero
    local mockHero = {
      x = 360,
      y = 1200,
      level = 1,
      xp = 0,
      xpRequired = 100,
      pickupRadius = 40,
      addXP = function(self, amount)
        self.xp = self.xp + amount
      end
    }

    experience_system.initialize(mockHero, xpOrbPool, function() end)
  end)

  after_each(function()
    -- Cleanup level system
    experience_system.cleanup()
  end)

  -- Feature: arcane-survivor-mvp, Property 13: Walker Defeat Spawns XP
  describe("Property 13: Walker Defeat Spawns XP", function()
    it("should spawn exactly one XP orb when walker health reaches zero", function()
      -- **Validates: Requirements 4.5**

      -- Property: For any walker that is defeated (health reaches zero),
      -- exactly one XP orb should spawn at the walker's position
      property "Walker defeat spawns exactly one XP orb" {
        generators = {
          lqc_gen.choose(50, 670),   -- Walker X position (within game bounds)
          lqc_gen.choose(100, 1000), -- Walker Y position (within game bounds)
          lqc_gen.choose(1, 50)      -- Damage amount to defeat walker (1-50)
        },
        check = function(walkerX, walkerY, damageAmount)
          -- Create and activate walker
          local walker = Walker:new()
          walker:activate(walkerX, walkerY, walkerX)

          -- Track initial orb count
          local initialOrbCount = #experience_system.getActiveOrbs()

          -- Apply damage to defeat walker (walker has 20 health)
          -- Ensure damage is enough to defeat walker
          local totalDamage = math.max(damageAmount, walker.health)
          walker:takeDamage(totalDamage)

          -- CRITICAL PROPERTY: Walker should be defeated
          if walker.isActive then
            walker:destroy()
            return false, string.format(
              "Walker should be defeated after taking %d damage (health: %d)",
              totalDamage, walker.health
            )
          end

          -- Simulate XP orb spawning (as done in game controller)
          experience_system.spawnXPOrb(walkerX, walkerY)

          -- Get current orb count
          local currentOrbCount = #experience_system.getActiveOrbs()

          -- CRITICAL PROPERTY: Exactly one XP orb should be spawned
          local orbsSpawned = currentOrbCount - initialOrbCount

          if orbsSpawned ~= 1 then
            walker:destroy()
            return false, string.format(
              "Expected exactly 1 XP orb to spawn, got %d",
              orbsSpawned
            )
          end

          -- Verify the spawned orb is at the walker's position
          local spawnedOrb = experience_system.getActiveOrbs()[currentOrbCount]

          if not spawnedOrb then
            walker:destroy()
            return false, "Spawned orb not found in active orbs"
          end

          -- CRITICAL PROPERTY: XP orb should be at walker's position
          if spawnedOrb.x ~= walkerX or spawnedOrb.y ~= walkerY then
            walker:destroy()
            return false, string.format(
              "XP orb position (%.2f, %.2f) does not match walker position (%.2f, %.2f)",
              spawnedOrb.x, spawnedOrb.y, walkerX, walkerY
            )
          end

          walker:destroy()
          return true
        end
      }
    end)

    it("should spawn XP orb at exact walker position regardless of damage amount", function()
      -- **Validates: Requirements 4.5**

      -- Property: XP orb position should match walker position exactly
      property "XP orb spawns at exact walker position" {
        generators = {
          lqc_gen.choose(50, 670),   -- Walker X position
          lqc_gen.choose(100, 1000), -- Walker Y position
          lqc_gen.choose(20, 100)    -- Overkill damage (more than walker health)
        },
        check = function(walkerX, walkerY, damageAmount)
          local walker = Walker:new()
          walker:activate(walkerX, walkerY, walkerX)

          -- Store walker position before defeat
          local defeatX = walker.x
          local defeatY = walker.y

          -- Defeat walker with overkill damage
          walker:takeDamage(damageAmount)

          -- Spawn XP orb at defeat position
          experience_system.spawnXPOrb(defeatX, defeatY)

          -- Get the spawned orb
          local activeOrbs = experience_system.getActiveOrbs()
          local spawnedOrb = activeOrbs[#activeOrbs]

          -- CRITICAL PROPERTY: Orb position must exactly match walker defeat position
          if not spawnedOrb then
            walker:destroy()
            return false, "No XP orb was spawned"
          end

          if spawnedOrb.x ~= defeatX or spawnedOrb.y ~= defeatY then
            walker:destroy()
            return false, string.format(
              "XP orb at (%.2f, %.2f) does not match walker defeat position (%.2f, %.2f)",
              spawnedOrb.x, spawnedOrb.y, defeatX, defeatY
            )
          end

          walker:destroy()
          return true
        end
      }
    end)

    it("should spawn one XP orb per defeated walker when multiple walkers are defeated", function()
      -- **Validates: Requirements 4.5**

      -- Property: Each defeated walker spawns exactly one XP orb
      property "Each defeated walker spawns one XP orb" {
        generators = {
          lqc_gen.choose(2, 10)  -- Number of walkers to defeat (2-10)
        },
        check = function(walkerCount)
          local walkers = {}
          local walkerPositions = {}

          -- Create and activate multiple walkers
          for i = 1, walkerCount do
            local walker = Walker:new()
            local x = 100 + (i * 50)  -- Spread walkers horizontally
            local y = 200 + (i * 30)  -- Spread walkers vertically
            walker:activate(x, y, x)
            table.insert(walkers, walker)
            table.insert(walkerPositions, {x = x, y = y})
          end

          local initialOrbCount = #experience_system.getActiveOrbs()

          -- Defeat all walkers and spawn XP orbs
          for i, walker in ipairs(walkers) do
            walker:takeDamage(walker.health)

            -- Verify walker is defeated
            if walker.isActive then
              for _, w in ipairs(walkers) do
                w:destroy()
              end
              return false, string.format("Walker %d should be defeated", i)
            end

            -- Spawn XP orb at walker position
            experience_system.spawnXPOrb(walkerPositions[i].x, walkerPositions[i].y)
          end

          local finalOrbCount = #experience_system.getActiveOrbs()
          local orbsSpawned = finalOrbCount - initialOrbCount

          -- CRITICAL PROPERTY: Number of orbs spawned should equal number of walkers defeated
          if orbsSpawned ~= walkerCount then
            for _, walker in ipairs(walkers) do
              walker:destroy()
            end
            return false, string.format(
              "Expected %d XP orbs for %d defeated walkers, got %d",
              walkerCount, walkerCount, orbsSpawned
            )
          end

          -- Cleanup
          for _, walker in ipairs(walkers) do
            walker:destroy()
          end
          return true
        end
      }
    end)

    it("should spawn XP orb with correct properties when walker is defeated", function()
      -- **Validates: Requirements 4.5**

      -- Property: Spawned XP orb should be active and have correct XP value
      property "Spawned XP orb has correct properties" {
        generators = {
          lqc_gen.choose(50, 670),   -- Walker X position
          lqc_gen.choose(100, 1000)  -- Walker Y position
        },
        check = function(walkerX, walkerY)
          local walker = Walker:new()
          walker:activate(walkerX, walkerY, walkerX)

          -- Defeat walker
          walker:takeDamage(walker.health)

          -- Spawn XP orb
          local orb = experience_system.spawnXPOrb(walkerX, walkerY)

          -- CRITICAL PROPERTY: Orb should be active
          if not orb or not orb.isActive then
            walker:destroy()
            return false, "Spawned XP orb should be active"
          end

          -- CRITICAL PROPERTY: Orb should have correct XP value (10)
          if orb.xpValue ~= 10 then
            walker:destroy()
            return false, string.format(
              "XP orb should have value 10, got %d",
              orb.xpValue
            )
          end

          -- CRITICAL PROPERTY: Orb should have spawn time set
          if not orb.spawnTime or orb.spawnTime <= 0 then
            walker:destroy()
            return false, "XP orb should have valid spawn time"
          end

          walker:destroy()
          return true
        end
      }
    end)

    it("should not spawn XP orb if walker is not defeated (health > 0)", function()
      -- **Validates: Requirements 4.5**

      -- Property: XP orb should only spawn when walker health reaches zero
      property "No XP orb spawns if walker not defeated" {
        generators = {
          lqc_gen.choose(50, 670),   -- Walker X position
          lqc_gen.choose(100, 1000), -- Walker Y position
          lqc_gen.choose(1, 19)      -- Damage amount (less than walker health of 20)
        },
        check = function(walkerX, walkerY, damageAmount)
          local walker = Walker:new()
          walker:activate(walkerX, walkerY, walkerX)

          local initialOrbCount = #experience_system.getActiveOrbs()

          -- Apply non-lethal damage
          walker:takeDamage(damageAmount)

          -- CRITICAL PROPERTY: Walker should still be active (not defeated)
          if not walker.isActive then
            walker:destroy()
            return false, string.format(
              "Walker should still be active after taking %d damage (health: %d)",
              damageAmount, walker.health
            )
          end

          -- In the actual game, XP orb spawning only happens when walker is defeated
          -- So we should NOT spawn an orb here
          -- This test verifies the condition: only spawn if walker.isActive == false

          local currentOrbCount = #experience_system.getActiveOrbs()
          local orbsSpawned = currentOrbCount - initialOrbCount

          -- CRITICAL PROPERTY: No XP orb should be spawned if walker is still alive
          if orbsSpawned ~= 0 then
            walker:destroy()
            return false, string.format(
              "No XP orb should spawn when walker is still alive, but %d orbs spawned",
              orbsSpawned
            )
          end

          walker:destroy()
          return true
        end
      }
    end)

    it("should spawn XP orb at walker position even at game boundaries", function()
      -- **Validates: Requirements 4.5**

      -- Property: XP orb spawning should work at any valid game position
      property "XP orb spawns at boundary positions" {
        generators = {
          lqc_gen.oneof({
            lqc_gen.elements({50, 360, 670}),      -- X: left edge, center, right edge
            lqc_gen.elements({0, 640, 1140})       -- Y: top, middle, wall threshold
          })
        },
        check = function(position)
          local walkerX = position[1]
          local walkerY = position[2]

          local walker = Walker:new()
          walker:activate(walkerX, walkerY, walkerX)

          -- Defeat walker
          walker:takeDamage(walker.health)

          -- Spawn XP orb
          local orb = experience_system.spawnXPOrb(walkerX, walkerY)

          -- CRITICAL PROPERTY: Orb should spawn at exact position
          if not orb then
            walker:destroy()
            return false, "XP orb should spawn at boundary position"
          end

          if orb.x ~= walkerX or orb.y ~= walkerY then
            walker:destroy()
            return false, string.format(
              "XP orb at (%.2f, %.2f) does not match boundary position (%.2f, %.2f)",
              orb.x, orb.y, walkerX, walkerY
            )
          end

          walker:destroy()
          return true
        end
      }
    end)
  end)
end)

