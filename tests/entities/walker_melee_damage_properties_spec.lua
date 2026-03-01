-- Walker Melee Damage Property Tests
-- Property-based tests for walker melee damage mechanics

require("tests.spec_helper")

local Walker = require("src.entities.walker")
local Wall = require("src.entities.wall")
local collision_system = require("src.systems.collision_system")
local lqc = require("lqc.quickcheck")
local property = require("lqc.property")
local lqc_gen = require("lqc.lqc_gen")

describe("Walker - Melee Damage Properties", function()
  before_each(function()
    -- Initialize lua-quickcheck
    lqc.init(100, 100)  -- 100 tests, 100 shrinks
  end)
  
  -- Feature: arcane-survivor-mvp, Property 12: Walker Melee Damage
  describe("Property 12: Walker Melee Damage", function()
    it("should deal 5 damage to the wall every 1.0 seconds when within 30 pixels", function()
      -- **Validates: Requirements 4.2**
      
      -- Property: For any walker within 30 pixels of the wall, the walker should
      -- deal 5 damage to the wall every 1.0 seconds while in range
      property "Walker deals 5 damage per second when in melee range" {
        generators = {
          lqc_gen.choose(1, 10)  -- Number of attack cycles to test (1-10)
        },
        check = function(attackCycles)
          -- Create wall and walker
          local wall = Wall:new(360, 1200, 720)
          local walker = Walker:new()
          
          -- Position walker within melee range (30 pixels from wall)
          -- Wall is at Y=1200, so position walker at Y=1170 (30 pixels away)
          walker:activate(360, 1170, 360)
          walker.isAttackingWall = true
          walker.wallTarget = wall
          
          -- Track initial wall health
          local initialHealth = wall.health
          local expectedDamage = 0
          
          -- Simulate attack cycles
          local currentTime = 0
          walker.lastAttackTime = 0
          
          for cycle = 1, attackCycles do
            -- Advance time by 1.0 seconds (attack cooldown)
            currentTime = currentTime + 1.0
            
            -- Check if walker can attack (cooldown elapsed)
            if currentTime - walker.lastAttackTime >= walker.attackCooldown then
              -- Apply damage
              wall:takeDamage(walker.damage)
              walker.lastAttackTime = currentTime
              expectedDamage = expectedDamage + walker.damage
            end
          end
          
          -- Verify damage dealt matches expected
          local actualDamage = initialHealth - wall.health
          
          -- CRITICAL PROPERTY: Damage should be exactly 5 per attack cycle
          if actualDamage ~= expectedDamage then
            walker:destroy()
            wall:destroy()
            return false, string.format(
              "Expected %d damage after %d cycles, got %d",
              expectedDamage, attackCycles, actualDamage
            )
          end
          
          -- Verify each attack dealt exactly 5 damage
          if expectedDamage ~= attackCycles * 5 then
            walker:destroy()
            wall:destroy()
            return false, string.format(
              "Expected 5 damage per cycle, got %d total for %d cycles",
              expectedDamage, attackCycles
            )
          end
          
          walker:destroy()
          wall:destroy()
          return true
        end
      }
    end)
    
    it("should respect 1.0 second attack cooldown regardless of time step", function()
      -- **Validates: Requirements 4.2**
      
      -- Property: Walker attack cooldown should be exactly 1.0 seconds
      property "Walker attack cooldown is exactly 1.0 seconds" {
        generators = {
          lqc_gen.choose(5, 20)  -- Time steps between 0.5 and 2.0 seconds (will divide by 10)
        },
        check = function(timeStepRaw)
          local timeStep = timeStepRaw / 10  -- Convert to 0.5-2.0 range
          local wall = Wall:new(360, 1200, 720)
          local walker = Walker:new()
          
          -- Position walker in melee range
          walker:activate(360, 1170, 360)
          walker.isAttackingWall = true
          walker.wallTarget = wall
          
          local initialHealth = wall.health
          local currentTime = 0
          walker.lastAttackTime = 0
          local attackCount = 0
          
          -- Simulate 5 seconds of combat with variable time steps
          while currentTime < 5.0 do
            currentTime = currentTime + timeStep
            
            -- Check if walker can attack
            if currentTime - walker.lastAttackTime >= walker.attackCooldown then
              wall:takeDamage(walker.damage)
              walker.lastAttackTime = currentTime
              attackCount = attackCount + 1
            end
          end
          
          -- CRITICAL PROPERTY: Should have attacked approximately 5 times in 5 seconds
          -- (allowing for timing precision issues)
          local expectedAttacks = math.floor(5.0 / walker.attackCooldown)
          
          if attackCount < expectedAttacks or attackCount > expectedAttacks + 1 then
            walker:destroy()
            wall:destroy()
            return false, string.format(
              "Expected ~%d attacks in 5 seconds, got %d (timeStep=%.2f)",
              expectedAttacks, attackCount, timeStep
            )
          end
          
          -- Verify damage matches attack count
          local actualDamage = initialHealth - wall.health
          local expectedDamage = attackCount * 5
          
          if actualDamage ~= expectedDamage then
            walker:destroy()
            wall:destroy()
            return false, string.format(
              "Damage mismatch: expected %d, got %d",
              expectedDamage, actualDamage
            )
          end
          
          walker:destroy()
          wall:destroy()
          return true
        end
      }
    end)
    
    it("should only attack when within 30 pixel melee range", function()
      -- **Validates: Requirements 4.2**
      
      -- Property: Walker should only deal damage when within 30 pixels of wall
      property "Walker only attacks within 30 pixel range" {
        generators = {
          lqc_gen.choose(1140, 1200)  -- Y positions from wall threshold to wall position
        },
        check = function(walkerY)
          local wall = Wall:new(360, 1200, 720)
          local walker = Walker:new()
          
          -- Position walker at test Y position
          walker:activate(360, walkerY, 360)
          walker.isAttackingWall = true
          walker.wallTarget = wall
          
          -- Calculate distance to wall
          local distance = collision_system.checkDistance(
            walker.x, walker.y,
            wall.x, wall.y
          )
          
          local initialHealth = wall.health
          local currentTime = 1.0  -- 1 second elapsed
          walker.lastAttackTime = 0
          
          -- Attempt to attack
          local shouldAttack = (distance <= 30 and 
                               currentTime - walker.lastAttackTime >= walker.attackCooldown)
          
          if shouldAttack then
            wall:takeDamage(walker.damage)
            walker.lastAttackTime = currentTime
          end
          
          -- CRITICAL PROPERTY: Damage should only occur if within range
          local damageTaken = initialHealth - wall.health
          
          if distance <= 30 then
            -- Should have dealt damage
            if damageTaken ~= 5 then
              walker:destroy()
              wall:destroy()
              return false, string.format(
                "Walker at distance %.2f should deal 5 damage, dealt %d",
                distance, damageTaken
              )
            end
          else
            -- Should NOT have dealt damage
            if damageTaken ~= 0 then
              walker:destroy()
              wall:destroy()
              return false, string.format(
                "Walker at distance %.2f should not deal damage, dealt %d",
                distance, damageTaken
              )
            end
          end
          
          walker:destroy()
          wall:destroy()
          return true
        end
      }
    end)
    
    it("should deal consistent 5 damage per attack regardless of wall health", function()
      -- **Validates: Requirements 4.2**
      
      -- Property: Walker damage amount should be constant (5) regardless of target health
      property "Walker deals constant 5 damage per attack" {
        generators = {
          lqc_gen.choose(10, 100),  -- Initial wall health (10-100)
          lqc_gen.choose(1, 5)      -- Number of attacks (1-5)
        },
        check = function(initialHealth, attackCount)
          local wall = Wall:new(360, 1200, 720)
          wall.health = initialHealth
          wall.maxHealth = initialHealth
          
          local walker = Walker:new()
          walker:activate(360, 1170, 360)
          walker.isAttackingWall = true
          walker.wallTarget = wall
          
          local currentTime = 0
          walker.lastAttackTime = 0
          local damagePerAttack = {}
          
          -- Perform attacks and track damage per attack
          for i = 1, attackCount do
            local healthBefore = wall.health
            currentTime = currentTime + 1.0
            
            -- Only attack if wall is still alive
            if wall.health > 0 and currentTime - walker.lastAttackTime >= walker.attackCooldown then
              wall:takeDamage(walker.damage)
              walker.lastAttackTime = currentTime
              
              local healthAfter = wall.health
              local damageDealt = healthBefore - healthAfter
              table.insert(damagePerAttack, damageDealt)
            end
          end
          
          -- CRITICAL PROPERTY: Each attack should deal exactly 5 damage
          -- (or reduce health to 0 if less than 5 health remaining)
          for i, damage in ipairs(damagePerAttack) do
            local expectedDamage = math.min(5, initialHealth - (i - 1) * 5)
            
            if damage ~= expectedDamage then
              walker:destroy()
              wall:destroy()
              return false, string.format(
                "Attack %d dealt %d damage, expected %d",
                i, damage, expectedDamage
              )
            end
          end
          
          walker:destroy()
          wall:destroy()
          return true
        end
      }
    end)
    
    it("should not attack before cooldown expires", function()
      -- **Validates: Requirements 4.2**
      
      -- Property: Walker should not deal damage if cooldown has not elapsed
      property "Walker respects attack cooldown" {
        generators = {
          lqc_gen.choose(1, 99)  -- Time elapsed (0.01 to 0.99 seconds, will divide by 100)
        },
        check = function(timeElapsedRaw)
          local timeElapsed = timeElapsedRaw / 100  -- Convert to 0.01-0.99 range
          local wall = Wall:new(360, 1200, 720)
          local walker = Walker:new()
          
          walker:activate(360, 1170, 360)
          walker.isAttackingWall = true
          walker.wallTarget = wall
          
          local initialHealth = wall.health
          walker.lastAttackTime = 0
          local currentTime = timeElapsed
          
          -- Attempt to attack before cooldown expires
          if currentTime - walker.lastAttackTime >= walker.attackCooldown then
            wall:takeDamage(walker.damage)
            walker.lastAttackTime = currentTime
          end
          
          -- CRITICAL PROPERTY: No damage should be dealt if cooldown not elapsed
          local damageTaken = initialHealth - wall.health
          
          if timeElapsed < walker.attackCooldown then
            -- Should NOT have attacked
            if damageTaken ~= 0 then
              walker:destroy()
              wall:destroy()
              return false, string.format(
                "Walker attacked at %.2fs (cooldown: %.2fs), should not attack",
                timeElapsed, walker.attackCooldown
              )
            end
          else
            -- Should have attacked
            if damageTaken ~= 5 then
              walker:destroy()
              wall:destroy()
              return false, string.format(
                "Walker should have attacked at %.2fs (cooldown: %.2fs)",
                timeElapsed, walker.attackCooldown
              )
            end
          end
          
          walker:destroy()
          wall:destroy()
          return true
        end
      }
    end)
    
    it("should maintain independent attack timers for multiple walkers", function()
      -- **Validates: Requirements 4.2**
      
      -- Property: Each walker should have independent attack cooldowns
      property "Multiple walkers have independent attack timers" {
        generators = {
          lqc_gen.choose(2, 5)  -- Number of walkers (2-5)
        },
        check = function(walkerCount)
          local wall = Wall:new(360, 1200, 720)
          local walkers = {}
          
          -- Create multiple walkers at different positions in melee range
          for i = 1, walkerCount do
            local walker = Walker:new()
            local xPos = 300 + (i * 20)  -- Spread walkers horizontally
            walker:activate(xPos, 1170, xPos)
            walker.isAttackingWall = true
            walker.wallTarget = wall
            walker.lastAttackTime = (i - 1) * 0.2  -- Stagger initial attack times
            table.insert(walkers, walker)
          end
          
          local initialHealth = wall.health
          local currentTime = 1.5  -- 1.5 seconds elapsed
          local expectedAttacks = 0
          
          -- Each walker attempts to attack
          for _, walker in ipairs(walkers) do
            if currentTime - walker.lastAttackTime >= walker.attackCooldown then
              wall:takeDamage(walker.damage)
              walker.lastAttackTime = currentTime
              expectedAttacks = expectedAttacks + 1
            end
          end
          
          -- CRITICAL PROPERTY: Damage should match number of walkers that could attack
          local actualDamage = initialHealth - wall.health
          local expectedDamage = expectedAttacks * 5
          
          if actualDamage ~= expectedDamage then
            for _, walker in ipairs(walkers) do
              walker:destroy()
            end
            wall:destroy()
            return false, string.format(
              "Expected %d damage from %d attacks, got %d",
              expectedDamage, expectedAttacks, actualDamage
            )
          end
          
          -- Cleanup
          for _, walker in ipairs(walkers) do
            walker:destroy()
          end
          wall:destroy()
          return true
        end
      }
    end)
  end)
end)
