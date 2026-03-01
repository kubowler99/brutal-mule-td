-- Hero Ability Slot Property Tests
-- Property-based tests for hero ability slot management

require("tests.spec_helper")

local Hero = require("src.entities.hero")
local lqc = require("lqc.quickcheck")
local property = require("lqc.property")
local lqc_gen = require("lqc.lqc_gen")

describe("Hero - Ability Slot Properties", function()
  before_each(function()
    -- Initialize lua-quickcheck
    lqc.init(100, 100)  -- 100 tests, 100 shrinks
  end)
  
  -- Feature: arcane-survivor-mvp, Property 1: Ability Slot Limit
  describe("Property 1: Ability Slot Limit", function()
    it("should never exceed 5 active abilities regardless of how many times we try to add abilities", function()
      -- **Validates: Requirements 1.7, 2.9**
      
      -- Define property: For any hero instance, the number of active abilities
      -- should never exceed 5 slots
      property "Hero ability count never exceeds 5" {
        generators = {
          lqc_gen.choose(1, 20)  -- Number of ability add attempts (1-20)
        },
        check = function(attemptCount)
          -- Create a new hero instance
          local hero = Hero:new(360, 1200)
          
          -- Track successful additions
          local successfulAdds = 0
          
          -- Attempt to add abilities multiple times
          for i = 1, attemptCount do
            -- Create a mock ability (just needs to be a table/object)
            local mockAbility = {
              id = "ability_" .. i,
              name = "Test Ability " .. i,
              cooldown = 1.0
            }
            
            -- Try to add the ability
            local added = hero:addAbility(mockAbility)
            
            -- Track successful additions
            if added then
              successfulAdds = successfulAdds + 1
            end
            
            -- CRITICAL PROPERTY: Ability count must never exceed 5
            if #hero.abilities > 5 then
              hero:destroy()
              return false, "Ability count exceeded 5: " .. #hero.abilities
            end
          end
          
          -- Verify that we can add at most 5 abilities
          local expectedCount = math.min(attemptCount, 5)
          local actualCount = #hero.abilities
          
          -- The actual count should match expected (capped at 5)
          local countMatches = actualCount == expectedCount
          
          -- Verify successful adds matches actual count
          local addsMatch = successfulAdds == actualCount
          
          -- After 5 additions, further attempts should fail
          local correctRejection = true
          if attemptCount > 5 then
            correctRejection = (successfulAdds == 5)
          end
          
          hero:destroy()
          
          return countMatches and addsMatch and correctRejection
        end
      }
    end)
    
    it("should return false when attempting to add a 6th ability", function()
      -- **Validates: Requirements 1.7, 2.9**
      
      -- Property: Adding abilities beyond the 5th should always fail
      property "Adding 6th ability always returns false" {
        generators = {
          lqc_gen.choose(6, 15)  -- Attempt to add 6-15 abilities
        },
        check = function(attemptCount)
          local hero = Hero:new(360, 1200)
          
          local results = {}
          
          -- Add abilities and track results
          for i = 1, attemptCount do
            local mockAbility = {
              id = "ability_" .. i,
              name = "Test Ability " .. i
            }
            
            local result = hero:addAbility(mockAbility)
            table.insert(results, result)
          end
          
          -- First 5 should succeed
          for i = 1, 5 do
            if not results[i] then
              hero:destroy()
              return false, "Ability " .. i .. " should have been added successfully"
            end
          end
          
          -- All attempts after 5 should fail
          for i = 6, attemptCount do
            if results[i] then
              hero:destroy()
              return false, "Ability " .. i .. " should have been rejected"
            end
          end
          
          -- Final count must be exactly 5
          if #hero.abilities ~= 5 then
            hero:destroy()
            return false, "Final ability count should be 5, got " .. #hero.abilities
          end
          
          hero:destroy()
          return true
        end
      }
    end)
    
    it("should maintain ability slot limit across different hero instances", function()
      -- **Validates: Requirements 1.7, 2.9**
      
      -- Property: Every hero instance independently enforces the 5-slot limit
      property "Each hero instance enforces 5-slot limit independently" {
        generators = {
          lqc_gen.choose(2, 5),   -- Number of hero instances
          lqc_gen.choose(3, 10)   -- Abilities to add per hero
        },
        check = function(heroCount, abilitiesPerHero)
          local heroes = {}
          
          -- Create multiple hero instances
          for i = 1, heroCount do
            local hero = Hero:new(360, 1200)
            table.insert(heroes, hero)
            
            -- Try to add abilities to this hero
            for j = 1, abilitiesPerHero do
              local mockAbility = {
                id = "hero" .. i .. "_ability_" .. j,
                name = "Hero " .. i .. " Ability " .. j
              }
              hero:addAbility(mockAbility)
            end
          end
          
          -- Verify each hero has at most 5 abilities
          local allValid = true
          for i, hero in ipairs(heroes) do
            if #hero.abilities > 5 then
              allValid = false
              break
            end
            
            -- Each hero should have min(abilitiesPerHero, 5) abilities
            local expected = math.min(abilitiesPerHero, 5)
            if #hero.abilities ~= expected then
              allValid = false
              break
            end
          end
          
          -- Cleanup
          for _, hero in ipairs(heroes) do
            hero:destroy()
          end
          
          return allValid
        end
      }
    end)
  end)
end)
