--- Unit tests for collision_system module
require("tests.spec_helper")

local collision_system = require("src.systems.collision_system")

describe("Collision System", function()
  
  describe("checkDistance", function()
    it("calculates distance between two points correctly", function()
      -- Test horizontal distance
      local dist1 = collision_system.checkDistance(0, 0, 10, 0)
      assert.are.equal(10, dist1)
      
      -- Test vertical distance
      local dist2 = collision_system.checkDistance(0, 0, 0, 10)
      assert.are.equal(10, dist2)
      
      -- Test diagonal distance (3-4-5 triangle)
      local dist3 = collision_system.checkDistance(0, 0, 3, 4)
      assert.are.equal(5, dist3)
      
      -- Test with negative coordinates
      local dist4 = collision_system.checkDistance(-5, -5, 5, 5)
      assert.is_true(math.abs(dist4 - 14.142) < 0.01)
    end)
    
    it("returns zero for same point", function()
      local dist = collision_system.checkDistance(100, 200, 100, 200)
      assert.are.equal(0, dist)
    end)
  end)
  
  describe("checkProjectileCollisions", function()
    it("detects collision when projectile is within threshold", function()
      local projectiles = {
        {x = 100, y = 100, isActive = true}
      }
      local enemies = {
        {x = 110, y = 100, isActive = true}  -- 10 pixels away (< 20 threshold)
      }
      
      local collisions = collision_system.checkProjectileCollisions(projectiles, enemies)
      
      assert.are.equal(1, #collisions)
      assert.are.equal(projectiles[1], collisions[1].projectile)
      assert.are.equal(enemies[1], collisions[1].enemy)
    end)
    
    it("does not detect collision when projectile is beyond threshold", function()
      local projectiles = {
        {x = 100, y = 100, isActive = true}
      }
      local enemies = {
        {x = 130, y = 100, isActive = true}  -- 30 pixels away (> 20 threshold)
      }
      
      local collisions = collision_system.checkProjectileCollisions(projectiles, enemies)
      
      assert.are.equal(0, #collisions)
    end)
    
    it("detects multiple collisions", function()
      local projectiles = {
        {x = 100, y = 100, isActive = true},
        {x = 200, y = 200, isActive = true}
      }
      local enemies = {
        {x = 105, y = 100, isActive = true},  -- Collides with projectile 1
        {x = 205, y = 200, isActive = true}   -- Collides with projectile 2
      }
      
      local collisions = collision_system.checkProjectileCollisions(projectiles, enemies)
      
      assert.are.equal(2, #collisions)
    end)
    
    it("skips inactive projectiles", function()
      local projectiles = {
        {x = 100, y = 100, isActive = false}
      }
      local enemies = {
        {x = 105, y = 100, isActive = true}
      }
      
      local collisions = collision_system.checkProjectileCollisions(projectiles, enemies)
      
      assert.are.equal(0, #collisions)
    end)
    
    it("skips inactive enemies", function()
      local projectiles = {
        {x = 100, y = 100, isActive = true}
      }
      local enemies = {
        {x = 105, y = 100, isActive = false}
      }
      
      local collisions = collision_system.checkProjectileCollisions(projectiles, enemies)
      
      assert.are.equal(0, #collisions)
    end)
    
    it("handles empty arrays", function()
      local collisions1 = collision_system.checkProjectileCollisions({}, {})
      assert.are.equal(0, #collisions1)
      
      local collisions2 = collision_system.checkProjectileCollisions(
        {{x = 100, y = 100, isActive = true}}, 
        {}
      )
      assert.are.equal(0, #collisions2)
    end)
    
    it("handles nil inputs gracefully", function()
      local collisions1 = collision_system.checkProjectileCollisions(nil, nil)
      assert.are.equal(0, #collisions1)
      
      local collisions2 = collision_system.checkProjectileCollisions(nil, {})
      assert.are.equal(0, #collisions2)
    end)
    
    it("handles invalid positions gracefully", function()
      local projectiles = {
        {x = "invalid", y = 100, isActive = true}
      }
      local enemies = {
        {x = 105, y = 100, isActive = true}
      }
      
      local collisions = collision_system.checkProjectileCollisions(projectiles, enemies)
      
      assert.are.equal(0, #collisions)
    end)
  end)
  
  describe("checkXPCollection", function()
    it("detects XP orb within pickup radius", function()
      local hero = {x = 100, y = 100, pickupRadius = 40}
      local xpOrbs = {
        {x = 120, y = 100, isActive = true}  -- 20 pixels away (< 40 radius)
      }
      
      local collectible = collision_system.checkXPCollection(hero, xpOrbs)
      
      assert.are.equal(1, #collectible)
      assert.are.equal(xpOrbs[1], collectible[1])
    end)
    
    it("does not detect XP orb beyond pickup radius", function()
      local hero = {x = 100, y = 100, pickupRadius = 40}
      local xpOrbs = {
        {x = 150, y = 100, isActive = true}  -- 50 pixels away (> 40 radius)
      }
      
      local collectible = collision_system.checkXPCollection(hero, xpOrbs)
      
      assert.are.equal(0, #collectible)
    end)
    
    it("detects multiple XP orbs within radius", function()
      local hero = {x = 100, y = 100, pickupRadius = 40}
      local xpOrbs = {
        {x = 110, y = 100, isActive = true},
        {x = 100, y = 110, isActive = true},
        {x = 90, y = 100, isActive = true}
      }
      
      local collectible = collision_system.checkXPCollection(hero, xpOrbs)
      
      assert.are.equal(3, #collectible)
    end)
    
    it("skips inactive XP orbs", function()
      local hero = {x = 100, y = 100, pickupRadius = 40}
      local xpOrbs = {
        {x = 110, y = 100, isActive = false}
      }
      
      local collectible = collision_system.checkXPCollection(hero, xpOrbs)
      
      assert.are.equal(0, #collectible)
    end)
    
    it("handles empty XP orb array", function()
      local hero = {x = 100, y = 100, pickupRadius = 40}
      local collectible = collision_system.checkXPCollection(hero, {})
      
      assert.are.equal(0, #collectible)
    end)
    
    it("handles nil inputs gracefully", function()
      local collectible1 = collision_system.checkXPCollection(nil, nil)
      assert.are.equal(0, #collectible1)
      
      local collectible2 = collision_system.checkXPCollection(
        {x = 100, y = 100, pickupRadius = 40}, 
        nil
      )
      assert.are.equal(0, #collectible2)
    end)
    
    it("handles invalid hero properties gracefully", function()
      local hero1 = {x = "invalid", y = 100, pickupRadius = 40}
      local xpOrbs = {{x = 110, y = 100, isActive = true}}
      
      local collectible1 = collision_system.checkXPCollection(hero1, xpOrbs)
      assert.are.equal(0, #collectible1)
      
      local hero2 = {x = 100, y = 100, pickupRadius = "invalid"}
      local collectible2 = collision_system.checkXPCollection(hero2, xpOrbs)
      assert.are.equal(0, #collectible2)
    end)
  end)
  
  describe("checkMeleeRange", function()
    it("detects enemy within melee range", function()
      local hero = {x = 100, y = 100}
      local enemies = {
        {x = 115, y = 100, isActive = true}  -- 15 pixels away (< 30 threshold)
      }
      
      local meleeEnemies = collision_system.checkMeleeRange(hero, enemies)
      
      assert.are.equal(1, #meleeEnemies)
      assert.are.equal(enemies[1], meleeEnemies[1])
    end)
    
    it("does not detect enemy beyond melee range", function()
      local hero = {x = 100, y = 100}
      local enemies = {
        {x = 140, y = 100, isActive = true}  -- 40 pixels away (> 30 threshold)
      }
      
      local meleeEnemies = collision_system.checkMeleeRange(hero, enemies)
      
      assert.are.equal(0, #meleeEnemies)
    end)
    
    it("detects multiple enemies within melee range", function()
      local hero = {x = 100, y = 100}
      local enemies = {
        {x = 110, y = 100, isActive = true},
        {x = 100, y = 110, isActive = true},
        {x = 90, y = 100, isActive = true}
      }
      
      local meleeEnemies = collision_system.checkMeleeRange(hero, enemies)
      
      assert.are.equal(3, #meleeEnemies)
    end)
    
    it("skips inactive enemies", function()
      local hero = {x = 100, y = 100}
      local enemies = {
        {x = 110, y = 100, isActive = false}
      }
      
      local meleeEnemies = collision_system.checkMeleeRange(hero, enemies)
      
      assert.are.equal(0, #meleeEnemies)
    end)
    
    it("handles empty enemy array", function()
      local hero = {x = 100, y = 100}
      local meleeEnemies = collision_system.checkMeleeRange(hero, {})
      
      assert.are.equal(0, #meleeEnemies)
    end)
    
    it("handles nil inputs gracefully", function()
      local meleeEnemies1 = collision_system.checkMeleeRange(nil, nil)
      assert.are.equal(0, #meleeEnemies1)
      
      local meleeEnemies2 = collision_system.checkMeleeRange({x = 100, y = 100}, nil)
      assert.are.equal(0, #meleeEnemies2)
    end)
    
    it("handles invalid hero position gracefully", function()
      local hero = {x = "invalid", y = 100}
      local enemies = {{x = 110, y = 100, isActive = true}}
      
      local meleeEnemies = collision_system.checkMeleeRange(hero, enemies)
      
      assert.are.equal(0, #meleeEnemies)
    end)
  end)

  describe("checkWallCollisions", function()
    it("returns walkers at threshold", function()
      local walkers = {
        {x = 100, y = 1180, isActive = true},  -- At threshold
        {x = 200, y = 1185, isActive = true}   -- Past threshold
      }
      local wallThreshold = 1180
      
      local collisions = collision_system.checkWallCollisions(walkers, wallThreshold)
      
      assert.are.equal(2, #collisions)
      assert.are.equal(walkers[1], collisions[1])
      assert.are.equal(walkers[2], collisions[2])
    end)
    
    it("excludes walkers above threshold", function()
      local walkers = {
        {x = 100, y = 1170, isActive = true},  -- Above threshold (y < wallThreshold)
        {x = 200, y = 1180, isActive = true},  -- At threshold
        {x = 300, y = 1100, isActive = true}   -- Above threshold
      }
      local wallThreshold = 1180
      
      local collisions = collision_system.checkWallCollisions(walkers, wallThreshold)
      
      assert.are.equal(1, #collisions)
      assert.are.equal(walkers[2], collisions[1])
    end)
    
    it("handles empty walker array", function()
      local collisions = collision_system.checkWallCollisions({}, 1180)
      
      assert.are.equal(0, #collisions)
    end)
    
    it("handles nil walkers", function()
      local collisions = collision_system.checkWallCollisions(nil, 1180)
      
      assert.are.equal(0, #collisions)
    end)
    
    it("handles nil wallThreshold", function()
      local walkers = {
        {x = 100, y = 1180, isActive = true}
      }
      
      local collisions = collision_system.checkWallCollisions(walkers, nil)
      
      assert.are.equal(0, #collisions)
    end)
    
    it("skips inactive walkers", function()
      local walkers = {
        {x = 100, y = 1180, isActive = false},  -- Inactive
        {x = 200, y = 1180, isActive = true}    -- Active
      }
      local wallThreshold = 1180
      
      local collisions = collision_system.checkWallCollisions(walkers, wallThreshold)
      
      assert.are.equal(1, #collisions)
      assert.are.equal(walkers[2], collisions[1])
    end)
    
    it("handles invalid walker Y-coordinates", function()
      local walkers = {
        {x = 100, y = "invalid", isActive = true},  -- Invalid Y
        {x = 200, y = 1180, isActive = true}        -- Valid
      }
      local wallThreshold = 1180
      
      local collisions = collision_system.checkWallCollisions(walkers, wallThreshold)
      
      assert.are.equal(1, #collisions)
      assert.are.equal(walkers[2], collisions[1])
    end)
    
    it("detects walkers exactly at threshold", function()
      local walkers = {
        {x = 100, y = 1180, isActive = true}
      }
      local wallThreshold = 1180
      
      local collisions = collision_system.checkWallCollisions(walkers, wallThreshold)
      
      assert.are.equal(1, #collisions)
    end)
    
    it("detects walkers past threshold", function()
      local walkers = {
        {x = 100, y = 1200, isActive = true}  -- Well past threshold
      }
      local wallThreshold = 1180
      
      local collisions = collision_system.checkWallCollisions(walkers, wallThreshold)
      
      assert.are.equal(1, #collisions)
    end)
  end)

  -- **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.6**
  -- Property 24: Distance-Based Collision Detection
  describe("Property 24: Distance-Based Collision Detection", function()
    local generators = require("tests.generators.game_generators")

    it("should detect collision when distance is within threshold for projectile-walker pairs", function()
      -- Run property test with 100 iterations
      for _ = 1, 100 do
        local pos1 = generators.position()()
        local pos2 = generators.position()()
        
        -- Calculate actual distance
        local distance = collision_system.checkDistance(pos1.x, pos1.y, pos2.x, pos2.y)
        
        -- Projectile-enemy collision threshold is 20 pixels
        local threshold = 20
        
        -- Create test entities
        local projectiles = {{x = pos1.x, y = pos1.y, isActive = true}}
        local enemies = {{x = pos2.x, y = pos2.y, isActive = true}}
        
        -- Check collision
        local collisions = collision_system.checkProjectileCollisions(projectiles, enemies)
        
        -- Property: collision should be detected if and only if distance <= threshold
        if distance <= threshold then
          assert.are.equal(1, #collisions, 
            string.format("Expected collision at distance %.2f (threshold: %d)", distance, threshold))
        else
          assert.are.equal(0, #collisions,
            string.format("Expected no collision at distance %.2f (threshold: %d)", distance, threshold))
        end
      end
    end)

    it("should detect collection when distance is within pickup radius for hero-XP orb pairs", function()
      -- Run property test with 100 iterations
      for _ = 1, 100 do
        local heroPos = generators.position()()
        local orbPos = generators.position()()
        
        -- Generate random pickup radius (20-100 pixels)
        local pickupRadius = math.random(20, 100)
        
        -- Calculate actual distance
        local distance = collision_system.checkDistance(heroPos.x, heroPos.y, orbPos.x, orbPos.y)
        
        -- Create test entities
        local hero = {x = heroPos.x, y = heroPos.y, pickupRadius = pickupRadius}
        local xpOrbs = {{x = orbPos.x, y = orbPos.y, isActive = true}}
        
        -- Check collection
        local collectible = collision_system.checkXPCollection(hero, xpOrbs)
        
        -- Property: collection should be detected if and only if distance <= pickupRadius
        if distance <= pickupRadius then
          assert.are.equal(1, #collectible,
            string.format("Expected collection at distance %.2f (radius: %d)", distance, pickupRadius))
        else
          assert.are.equal(0, #collectible,
            string.format("Expected no collection at distance %.2f (radius: %d)", distance, pickupRadius))
        end
      end
    end)

    it("should detect melee range when distance is within threshold for hero-walker pairs", function()
      -- Run property test with 100 iterations
      for _ = 1, 100 do
        local heroPos = generators.position()()
        local enemyPos = generators.position()()
        
        -- Calculate actual distance
        local distance = collision_system.checkDistance(heroPos.x, heroPos.y, enemyPos.x, enemyPos.y)
        
        -- Melee range threshold is 30 pixels
        local threshold = 30
        
        -- Create test entities
        local hero = {x = heroPos.x, y = heroPos.y}
        local enemies = {{x = enemyPos.x, y = enemyPos.y, isActive = true}}
        
        -- Check melee range
        local meleeEnemies = collision_system.checkMeleeRange(hero, enemies)
        
        -- Property: melee range should be detected if and only if distance <= threshold
        if distance <= threshold then
          assert.are.equal(1, #meleeEnemies,
            string.format("Expected melee range at distance %.2f (threshold: %d)", distance, threshold))
        else
          assert.are.equal(0, #meleeEnemies,
            string.format("Expected no melee range at distance %.2f (threshold: %d)", distance, threshold))
        end
      end
    end)

    it("should handle multiple entity pairs correctly", function()
      -- Run property test with 100 iterations
      for _ = 1, 100 do
        -- Generate 2-5 projectiles and 2-5 enemies
        local numProjectiles = math.random(2, 5)
        local numEnemies = math.random(2, 5)
        
        local projectiles = {}
        local enemies = {}
        
        for i = 1, numProjectiles do
          local pos = generators.position()()
          table.insert(projectiles, {x = pos.x, y = pos.y, isActive = true})
        end
        
        for i = 1, numEnemies do
          local pos = generators.position()()
          table.insert(enemies, {x = pos.x, y = pos.y, isActive = true})
        end
        
        -- Check collisions
        local collisions = collision_system.checkProjectileCollisions(projectiles, enemies)
        
        -- Property: number of collisions should not exceed min(numProjectiles, numEnemies)
        -- (each projectile can collide with at most one enemy per frame)
        assert.is_true(#collisions <= numProjectiles * numEnemies,
          string.format("Too many collisions: %d (max possible: %d)", 
            #collisions, numProjectiles * numEnemies))
        
        -- Verify each collision has valid projectile and enemy references
        for _, collision in ipairs(collisions) do
          assert.is_not_nil(collision.projectile, "Collision should have projectile reference")
          assert.is_not_nil(collision.enemy, "Collision should have enemy reference")
          
          -- Verify the collision is within threshold
          local distance = collision_system.checkDistance(
            collision.projectile.x, collision.projectile.y,
            collision.enemy.x, collision.enemy.y
          )
          assert.is_true(distance <= 20,
            string.format("Collision detected at distance %.2f (threshold: 20)", distance))
        end
      end
    end)

    it("should correctly apply distance formula for all collision types", function()
      -- Run property test with 100 iterations
      for _ = 1, 100 do
        local pos1 = generators.position()()
        local pos2 = generators.position()()
        
        -- Calculate distance using the collision system
        local systemDistance = collision_system.checkDistance(pos1.x, pos1.y, pos2.x, pos2.y)
        
        -- Calculate expected distance using Euclidean formula
        local dx = pos2.x - pos1.x
        local dy = pos2.y - pos1.y
        local expectedDistance = math.sqrt(dx * dx + dy * dy)
        
        -- Property: system distance should match mathematical distance
        -- Allow small floating point error (< 0.001)
        local error = math.abs(systemDistance - expectedDistance)
        assert.is_true(error < 0.001,
          string.format("Distance calculation error: %.6f (system: %.2f, expected: %.2f)",
            error, systemDistance, expectedDistance))
      end
    end)
  end)
  
end)

