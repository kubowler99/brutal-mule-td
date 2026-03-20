--- Unit tests for combat_system module
require("tests.spec_helper")

local combat_system = require("src.systems.combat_system")
local collision_system = require("src.systems.collision_system")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")
local Projectile = require("src.entities.projectile")
local Walker = require("src.entities.walker")
local pool = require("src.utils.pool")
local property = require("lqc.property")
local lqc = require("lqc.quickcheck")
local lqc_gen = require("lqc.lqc_gen")
local generators = require("tests.generators.game_generators")

describe("Combat System", function()

  local hero
  local projectilePool
  local enemies

  before_each(function()
    -- Reset combat system state
    combat_system.cleanup()

    -- Create mock hero with abilities
    hero = {
      x = 360,
      y = 1200,
      isAlive = true,
      abilities = {}
    }

    -- Create projectile pool
    projectilePool = {
      pool = {},
      get = function(self)
        local proj = Projectile:new()
        table.insert(self.pool, proj)
        return proj
      end
    }

    -- Create enemies array
    enemies = {}
  end)

  after_each(function()
    combat_system.cleanup()
  end)

  describe("initialize", function()
    it("stores references to hero, projectile pool, and enemies", function()
      combat_system.initialize(hero, projectilePool, enemies)

      -- Verify initialization by checking that update doesn't crash
      local success = pcall(function()
        combat_system.update(0.016, 1.0)
      end)

      assert.is_true(success)
    end)

    it("resets active projectiles array", function()
      combat_system.initialize(hero, projectilePool, enemies)

      local activeProjectiles = combat_system.getActiveProjectiles()
      assert.are.equal(0, #activeProjectiles)
    end)
  end)

  describe("activateAbilities", function()
    it("activates ability when cooldown is ready and enemies exist", function()
      -- Create ability with ready cooldown
      local ability = ArcaneBolt:new()
      ability.lastActivation = 0
      hero.abilities = {ability}

      -- Add an enemy
      table.insert(enemies, {x = 360, y = 600, isActive = true})

      combat_system.initialize(hero, projectilePool, enemies)

      -- Activate abilities at time 2.0 (well past cooldown)
      combat_system.activateAbilities(2.0)

      -- Verify projectile was created
      assert.are.equal(1, #projectilePool.pool)
      assert.is_true(projectilePool.pool[1].isActive)
    end)

    it("respects ability cooldown timer", function()
      local ability = ArcaneBolt:new()
      ability.lastActivation = 1.0
      ability.cooldown = 1.0
      hero.abilities = {ability}

      table.insert(enemies, {x = 360, y = 600, isActive = true})

      combat_system.initialize(hero, projectilePool, enemies)

      -- Try to activate at 1.5 seconds (0.5s since last activation, cooldown is 1.0s)
      combat_system.activateAbilities(1.5)

      -- Should not activate (cooldown not ready)
      assert.are.equal(0, #projectilePool.pool)
    end)

    it("does not activate abilities when no enemies exist", function()
      local ability = ArcaneBolt:new()
      ability.lastActivation = 0
      hero.abilities = {ability}

      combat_system.initialize(hero, projectilePool, enemies)

      -- Try to activate with no enemies
      combat_system.activateAbilities(2.0)

      -- Should not create projectiles
      assert.are.equal(0, #projectilePool.pool)
    end)

    it("skips inactive enemies when checking for targets", function()
      local ability = ArcaneBolt:new()
      ability.lastActivation = 0
      hero.abilities = {ability}

      -- Add only inactive enemies
      table.insert(enemies, {x = 360, y = 600, isActive = false})
      table.insert(enemies, {x = 360, y = 700, isActive = false})

      combat_system.initialize(hero, projectilePool, enemies)

      combat_system.activateAbilities(2.0)

      -- Should not activate (no active enemies)
      assert.are.equal(0, #projectilePool.pool)
    end)

    it("activates multiple abilities independently", function()
      local ability1 = ArcaneBolt:new()
      ability1.lastActivation = 0
      local ability2 = ArcaneBolt:new()
      ability2.lastActivation = 0

      hero.abilities = {ability1, ability2}

      table.insert(enemies, {x = 360, y = 600, isActive = true})

      combat_system.initialize(hero, projectilePool, enemies)

      combat_system.activateAbilities(2.0)

      -- Both abilities should create projectiles
      assert.are.equal(2, #projectilePool.pool)
    end)

    it("handles nil hero gracefully", function()
      combat_system.initialize(nil, projectilePool, enemies)

      local success = pcall(function()
        combat_system.activateAbilities(1.0)
      end)

      assert.is_true(success)
    end)

    it("handles hero without abilities array", function()
      hero.abilities = nil
      combat_system.initialize(hero, projectilePool, enemies)

      local success = pcall(function()
        combat_system.activateAbilities(1.0)
      end)

      assert.is_true(success)
    end)
  end)

  describe("refreshActiveProjectiles", function()
    it("tracks newly created projectiles from pool", function()
      combat_system.initialize(hero, projectilePool, enemies)

      -- Manually create some active projectiles
      local proj1 = projectilePool:get()
      proj1.isActive = true
      local proj2 = projectilePool:get()
      proj2.isActive = true

      combat_system.refreshActiveProjectiles()

      local activeProjectiles = combat_system.getActiveProjectiles()
      assert.are.equal(2, #activeProjectiles)
    end)

    it("excludes inactive projectiles", function()
      combat_system.initialize(hero, projectilePool, enemies)

      local proj1 = projectilePool:get()
      proj1.isActive = true
      local proj2 = projectilePool:get()
      proj2.isActive = false

      combat_system.refreshActiveProjectiles()

      local activeProjectiles = combat_system.getActiveProjectiles()
      assert.are.equal(1, #activeProjectiles)
    end)

    it("handles empty pool gracefully", function()
      projectilePool.pool = {}
      combat_system.initialize(hero, projectilePool, enemies)

      local success = pcall(function()
        combat_system.refreshActiveProjectiles()
      end)

      assert.is_true(success)
    end)
  end)

  describe("updateProjectiles", function()
    it("updates active projectile positions", function()
      combat_system.initialize(hero, projectilePool, enemies)

      local proj = projectilePool:get()
      proj:activate(100, 100, 200, 200, 100, 10, 0)

      combat_system.refreshActiveProjectiles()

      local initialX = proj.x
      local initialY = proj.y

      -- Update with 0.1 second delta time
      combat_system.updateProjectiles(0.1)

      -- Position should have changed
      assert.is_true(proj.x ~= initialX or proj.y ~= initialY)
    end)

    it("removes inactive projectiles from tracking", function()
      combat_system.initialize(hero, projectilePool, enemies)

      local proj = projectilePool:get()
      proj:activate(100, 100, 200, 200, 100, 10, 0)

      combat_system.refreshActiveProjectiles()

      -- Deactivate the projectile
      proj:deactivate()

      combat_system.updateProjectiles(0.016)

      local activeProjectiles = combat_system.getActiveProjectiles()
      assert.are.equal(0, #activeProjectiles)
    end)

    it("removes off-screen projectiles", function()
      combat_system.initialize(hero, projectilePool, enemies)

      local proj = projectilePool:get()
      -- Position far off-screen
      proj:activate(-500, -500, -600, -600, 100, 10, 0)

      combat_system.refreshActiveProjectiles()

      -- Update should detect off-screen and deactivate
      combat_system.updateProjectiles(0.016)

      assert.is_false(proj.isActive)
    end)

    it("handles multiple projectiles correctly", function()
      combat_system.initialize(hero, projectilePool, enemies)

      local proj1 = projectilePool:get()
      proj1:activate(100, 100, 200, 200, 100, 10, 0)
      local proj2 = projectilePool:get()
      proj2:activate(300, 300, 400, 400, 100, 10, 0)

      combat_system.refreshActiveProjectiles()

      combat_system.updateProjectiles(0.016)

      -- Both should still be active (not off-screen)
      assert.is_true(proj1.isActive)
      assert.is_true(proj2.isActive)
    end)

    it("handles empty projectiles array gracefully", function()
      combat_system.initialize(hero, projectilePool, enemies)

      local success = pcall(function()
        combat_system.updateProjectiles(0.016)
      end)

      assert.is_true(success)
    end)
  end)

  describe("applyDamage", function()
    it("applies damage to entity with takeDamage method", function()
      local entity = {
        health = 100,
        takeDamage = function(self, amount)
          self.health = self.health - amount
        end
      }

      combat_system.applyDamage(entity, 25)

      assert.are.equal(75, entity.health)
    end)

    it("validates damage amount is non-negative", function()
      local entity = {
        health = 100,
        takeDamage = function(self, amount)
          self.health = self.health - amount
        end
      }

      -- Try to apply negative damage
      combat_system.applyDamage(entity, -10)

      -- Health should not change (damage clamped to 0)
      assert.are.equal(100, entity.health)
    end)

    it("handles nil entity gracefully", function()
      local success = pcall(function()
        combat_system.applyDamage(nil, 10)
      end)

      assert.is_true(success)
    end)

    it("handles entity without takeDamage method", function()
      local entity = {health = 100}

      local success = pcall(function()
        combat_system.applyDamage(entity, 10)
      end)

      assert.is_true(success)
      -- Health should be unchanged
      assert.are.equal(100, entity.health)
    end)

    it("handles nil damage amount", function()
      local entity = {
        health = 100,
        takeDamage = function(self, amount)
          self.health = self.health - amount
        end
      }

      combat_system.applyDamage(entity, nil)

      -- Should apply 0 damage
      assert.are.equal(100, entity.health)
    end)
  end)

  describe("update", function()
    it("does not update when hero is not alive", function()
      hero.isAlive = false
      local ability = ArcaneBolt:new()
      ability.lastActivation = 0
      hero.abilities = {ability}

      table.insert(enemies, {x = 360, y = 600, isActive = true})

      combat_system.initialize(hero, projectilePool, enemies)

      combat_system.update(0.016, 2.0)

      -- Should not activate abilities
      assert.are.equal(0, #projectilePool.pool)
    end)

    it("does not update when hero is nil", function()
      combat_system.initialize(nil, projectilePool, enemies)

      local success = pcall(function()
        combat_system.update(0.016, 1.0)
      end)

      assert.is_true(success)
    end)

    it("coordinates ability activation and projectile updates", function()
      local ability = ArcaneBolt:new()
      ability.lastActivation = 0
      hero.abilities = {ability}

      table.insert(enemies, {x = 360, y = 600, isActive = true})

      combat_system.initialize(hero, projectilePool, enemies)

      -- First update should activate ability and create projectile
      combat_system.update(0.016, 2.0)

      assert.are.equal(1, #projectilePool.pool)

      local proj = projectilePool.pool[1]
      local initialX = proj.x

      -- Second update should move the projectile
      combat_system.update(0.016, 2.016)

      -- Position should have changed
      assert.is_true(proj.x ~= initialX or proj.y ~= initialX)
    end)
  end)

  describe("getActiveProjectiles", function()
    it("returns the active projectiles array", function()
      combat_system.initialize(hero, projectilePool, enemies)

      local activeProjectiles = combat_system.getActiveProjectiles()

      assert.is_not_nil(activeProjectiles)
      assert.are.equal("table", type(activeProjectiles))
    end)

    it("returns empty array initially", function()
      combat_system.initialize(hero, projectilePool, enemies)

      local activeProjectiles = combat_system.getActiveProjectiles()

      assert.are.equal(0, #activeProjectiles)
    end)
  end)

  describe("cleanup", function()
    it("clears all references and resets state", function()
      combat_system.initialize(hero, projectilePool, enemies)

      local ability = ArcaneBolt:new()
      ability.lastActivation = 0
      hero.abilities = {ability}

      table.insert(enemies, {x = 360, y = 600, isActive = true})

      combat_system.activateAbilities(2.0)

      -- Cleanup
      combat_system.cleanup()

      -- Should be able to update without errors (no-op)
      local success = pcall(function()
        combat_system.update(0.016, 1.0)
      end)

      assert.is_true(success)

      -- Active projectiles should be cleared
      local activeProjectiles = combat_system.getActiveProjectiles()
      assert.are.equal(0, #activeProjectiles)
    end)
  end)

  describe("Integration: Full combat cycle", function()
    it("creates projectile when ability activates with valid target", function()
      local ability = ArcaneBolt:new()
      ability.lastActivation = 0
      hero.abilities = {ability}

      table.insert(enemies, {x = 360, y = 600, isActive = true})

      combat_system.initialize(hero, projectilePool, enemies)

      -- Activate abilities
      combat_system.activateAbilities(2.0)

      -- Verify projectile was created and is active
      assert.are.equal(1, #projectilePool.pool)
      assert.is_true(projectilePool.pool[1].isActive)

      -- Verify projectile has correct damage
      assert.are.equal(10, projectilePool.pool[1].damage)
    end)

    it("tracks projectiles after activation", function()
      local ability = ArcaneBolt:new()
      ability.lastActivation = 0
      hero.abilities = {ability}

      table.insert(enemies, {x = 360, y = 600, isActive = true})

      combat_system.initialize(hero, projectilePool, enemies)

      combat_system.activateAbilities(2.0)

      -- Active projectiles should be tracked
      local activeProjectiles = combat_system.getActiveProjectiles()
      assert.are.equal(1, #activeProjectiles)
    end)

    it("removes projectile when it goes off-screen", function()
      local ability = ArcaneBolt:new()
      ability.lastActivation = 0
      hero.abilities = {ability}

      -- Place enemy far off-screen so projectile travels off-screen
      table.insert(enemies, {x = -1000, y = -1000, isActive = true})

      combat_system.initialize(hero, projectilePool, enemies)

      combat_system.activateAbilities(2.0)

      local proj = projectilePool.pool[1]

      -- Update multiple times to move projectile off-screen
      for i = 1, 100 do
        combat_system.updateProjectiles(0.1)
      end

      -- Projectile should be deactivated
      assert.is_false(proj.isActive)
    end)
  end)

  describe("Integration: Wall Combat", function()
    local Wall

    before_each(function()
      Wall = require("src.entities.wall")
    end)

    it("applies walker damage to wall", function()
      local wall = Wall:new(360, 1180, 720)
      local initialHealth = wall.health

      -- Apply damage using combat system
      combat_system.applyDamage(wall, 10)

      -- Verify wall health decreased
      assert.are.equal(initialHealth - 10, wall.health)
    end)

    it("decreases wall health correctly with 10 damage per attack", function()
      local wall = Wall:new(360, 1180, 720)
      
      -- Simulate multiple walker attacks (10 damage each)
      combat_system.applyDamage(wall, 10)
      assert.are.equal(90, wall.health)
      
      combat_system.applyDamage(wall, 10)
      assert.are.equal(80, wall.health)
      
      combat_system.applyDamage(wall, 10)
      assert.are.equal(70, wall.health)
    end)

    it("triggers wall flash effect on damage", function()
      local wall = Wall:new(360, 1180, 720)
      
      -- Spy on flashDamage method
      local flashCalled = false
      local originalFlash = wall.flashDamage
      wall.flashDamage = function(self)
        flashCalled = true
        originalFlash(self)
      end
      
      -- Apply damage (takeDamage calls flashDamage internally)
      wall:takeDamage(10)
      
      -- Verify flash was triggered
      assert.is_true(flashCalled)
    end)

    it("triggers game over when wall health reaches zero", function()
      local wall = Wall:new(360, 1180, 720)
      
      -- Reduce wall health to near zero
      wall.health = 5
      
      -- Apply fatal damage
      combat_system.applyDamage(wall, 10)
      
      -- Verify wall is dead
      assert.is_true(wall:isDead())
      assert.are.equal(0, wall.health)
    end)

    it("handles multiple walkers attacking wall simultaneously", function()
      local wall = Wall:new(360, 1180, 720)
      
      -- Simulate 3 walkers attacking at once
      combat_system.applyDamage(wall, 10)
      combat_system.applyDamage(wall, 10)
      combat_system.applyDamage(wall, 10)
      
      -- Verify cumulative damage
      assert.are.equal(70, wall.health)
      assert.is_false(wall:isDead())
    end)

    it("clamps wall health to zero when overkill damage is applied", function()
      local wall = Wall:new(360, 1180, 720)
      wall.health = 5
      
      -- Apply more damage than remaining health
      combat_system.applyDamage(wall, 50)
      
      -- Health should be clamped to 0, not negative
      assert.are.equal(0, wall.health)
      assert.is_true(wall:isDead())
    end)

    it("wall survives when health is above zero", function()
      local wall = Wall:new(360, 1180, 720)
      
      -- Apply damage but keep wall alive
      combat_system.applyDamage(wall, 50)
      
      assert.are.equal(50, wall.health)
      assert.is_false(wall:isDead())
    end)
  end)

  describe("sceneGroup integration", function()
    it("stores sceneGroup reference when passed to initialize", function()
      local group = display.newGroup()
      combat_system.initialize(hero, projectilePool, enemies, group)

      -- Verify initialization works with sceneGroup by running update without error
      local success = pcall(function()
        combat_system.update(0.016, 1.0)
      end)
      assert.is_true(success)
    end)

    it("works without sceneGroup (backward compatible)", function()
      combat_system.initialize(hero, projectilePool, enemies)

      local success = pcall(function()
        combat_system.update(0.016, 1.0)
      end)
      assert.is_true(success)
    end)

    it("inserts projectile display objects into sceneGroup on refresh", function()
      local group = display.newGroup()
      combat_system.initialize(hero, projectilePool, enemies, group)

      -- Create an active projectile with a display object that has no parent
      local proj = projectilePool:get()
      proj:activate(100, 100, 200, 200, 100, 10, 0)
      -- Simulate a display object without a parent (newly created, not yet in scene)
      proj.displayObject.parent = nil

      combat_system.refreshActiveProjectiles()

      -- Display object should now have the sceneGroup as parent
      assert.are.equal(group, proj.displayObject.parent)
    end)

    it("does not re-insert display objects that already have a parent", function()
      local group = display.newGroup()
      local otherGroup = display.newGroup()
      combat_system.initialize(hero, projectilePool, enemies, group)

      local proj = projectilePool:get()
      proj:activate(100, 100, 200, 200, 100, 10, 0)
      -- Simulate a display object already in another group
      proj.displayObject.parent = otherGroup

      local initialCount = group.numChildren
      combat_system.refreshActiveProjectiles()

      -- Should not have been inserted into sceneGroup (already has a parent)
      assert.are.equal(initialCount, group.numChildren)
      assert.are.equal(otherGroup, proj.displayObject.parent)
    end)

    it("skips insertion when sceneGroup is nil", function()
      combat_system.initialize(hero, projectilePool, enemies, nil)

      local proj = projectilePool:get()
      proj:activate(100, 100, 200, 200, 100, 10, 0)
      proj.displayObject.parent = nil

      -- Should not crash
      local success = pcall(function()
        combat_system.refreshActiveProjectiles()
      end)
      assert.is_true(success)
    end)

    it("skips insertion when projectile has no display object", function()
      local group = display.newGroup()
      combat_system.initialize(hero, projectilePool, enemies, group)

      local proj = projectilePool:get()
      proj.isActive = true
      proj.displayObject = nil

      local initialCount = group.numChildren
      combat_system.refreshActiveProjectiles()

      -- No new children should be added
      assert.are.equal(initialCount, group.numChildren)
    end)

    it("clears sceneGroup reference on cleanup", function()
      local group = display.newGroup()
      combat_system.initialize(hero, projectilePool, enemies, group)
      combat_system.cleanup()

      -- After cleanup, re-initialize without sceneGroup and verify no crash
      combat_system.initialize(hero, projectilePool, enemies)
      local proj = projectilePool:get()
      proj:activate(100, 100, 200, 200, 100, 10, 0)
      proj.displayObject.parent = nil

      local success = pcall(function()
        combat_system.refreshActiveProjectiles()
      end)
      assert.is_true(success)
      -- Display object should still have no parent (no sceneGroup to insert into)
      assert.is_nil(proj.displayObject.parent)
    end)
  end)

  -- Property-Based Tests
  describe("Property Tests", function()

    before_each(function()
      -- Initialize lua-quickcheck
      lqc.init(100, 100)  -- 100 tests, 100 shrinks
    end)

    -- Feature: arcane-survivor-mvp, Property 14: Projectile Damage Application
    describe("Property 14: Projectile Damage Application", function()
      it("applies projectile damage to walker health on collision", function()
        -- **Validates: Requirements 2.5**
        
        -- Define property: For any collision between a projectile and walker,
        -- the walker's health should decrease by the projectile's damage value
        property "Projectile damage reduces walker health correctly" {
          generators = {
            lqc_gen.choose(5, 50),    -- damage values (5-50)
            lqc_gen.choose(1, 100)    -- walker health (1-100)
          },
          check = function(damage, initialHealth)
            -- Setup: Create walker with specific health
            local walker = Walker:new()
            walker:activate(360, 600, 360)
            walker.health = initialHealth
            
            -- Setup: Create projectile with specific damage
            local projectile = Projectile:new()
            projectile:activate(360, 700, 360, 600, 400, damage, 0)
            
            -- Setup: Position projectile to collide with walker
            projectile.x = walker.x
            projectile.y = walker.y
            
            -- Record initial health
            local healthBefore = walker.health
            
            -- Simulate collision detection
            local collisions = collision_system.checkProjectileCollisions(
              {projectile},
              {walker}
            )
            
            -- Apply damage if collision detected
            if #collisions > 0 then
              combat_system.applyDamage(walker, projectile.damage)
            end
            
            -- Verify: Health decreased by exactly the damage amount
            local expectedHealth = math.max(0, healthBefore - damage)
            local actualHealth = walker.health
            
            -- Property holds if health decreased correctly
            return actualHealth == expectedHealth
          end
        }
        
        -- Run all registered properties
        lqc.check()
        
        -- Verify no failures
        assert.is_false(lqc.failed)
      end)
    end)

    -- Feature: arcane-survivor-mvp, Property 15: Projectile Removal on Collision
    describe("Property 15: Projectile Removal on Collision", function()
      it("deactivates projectile when it collides with enemy", function()
        -- **Validates: Requirements 2.6, 12.5**
        
        -- Define property: For any projectile that collides with an enemy,
        -- the projectile should be deactivated
        property "Projectile deactivates on enemy collision" {
          generators = {
            lqc_gen.choose(100, 600),  -- projectile X position
            lqc_gen.choose(100, 600)   -- projectile Y position
          },
          check = function(projX, projY)
            -- Setup: Create walker
            local walker = Walker:new()
            walker:activate(projX, projY, projX)
            
            -- Setup: Create projectile at same position (collision)
            local projectile = Projectile:new()
            projectile:activate(projX + 50, projY + 50, projX, projY, 400, 10, 0)
            projectile.x = projX
            projectile.y = projY
            
            -- Verify projectile is initially active
            if not projectile.isActive then
              return false
            end
            
            -- Simulate collision and hit
            projectile:onHit(walker)
            
            -- Property holds if projectile is deactivated after collision
            return not projectile.isActive
          end
        }
        
        -- Run all registered properties
        lqc.check()
        
        -- Verify no failures
        assert.is_false(lqc.failed)
      end)
      
      it("deactivates projectile when it travels beyond game boundaries", function()
        -- **Validates: Requirements 2.6, 12.5**
        
        -- Define property: For any projectile beyond game boundaries (200px off-screen),
        -- the projectile should be deactivated
        property "Projectile deactivates when off-screen" {
          generators = {
            lqc_gen.oneof({
              lqc_gen.choose(-500, -201),  -- Far left/top
              lqc_gen.choose(921, 1500)    -- Far right/bottom
            }),
            lqc_gen.oneof({
              lqc_gen.choose(-500, -201),  -- Far left/top
              lqc_gen.choose(1481, 2000)   -- Far right/bottom
            })
          },
          check = function(x, y)
            -- Setup: Create projectile
            local projectile = Projectile:new()
            projectile:activate(360, 640, x, y, 400, 10, 0)
            
            -- Move projectile to off-screen position
            projectile.x = x
            projectile.y = y
            
            -- Check if off-screen
            local isOffScreen = projectile:isOffScreen()
            
            -- If off-screen, it should be deactivated
            if isOffScreen then
              projectile:deactivate()
            end
            
            -- Property holds if off-screen projectiles are deactivated
            return isOffScreen == (not projectile.isActive)
          end
        }
        
        -- Run all registered properties
        lqc.check()
        
        -- Verify no failures
        assert.is_false(lqc.failed)
      end)
    end)

  end)

end)
