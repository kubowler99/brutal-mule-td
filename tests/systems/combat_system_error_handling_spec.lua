--- Unit tests for combat_system error handling
require("tests.spec_helper")

local combat_system = require("src.systems.combat_system")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")
local Projectile = require("src.entities.projectile")

describe("Combat System Error Handling", function()

  local hero
  local projectilePool
  local enemies

  before_each(function()
    combat_system.cleanup()

    hero = {
      x = 360,
      y = 1200,
      isAlive = true,
      abilities = {}
    }

    projectilePool = {
      pool = {},
      get = function(self)
        local proj = Projectile:new()
        table.insert(self.pool, proj)
        return proj
      end
    }

    enemies = {}
  end)

  after_each(function()
    combat_system.cleanup()
  end)

  describe("activateAbilities error handling", function()
    it("handles empty enemies array gracefully", function()
      local ability = ArcaneBolt:new()
      ability.lastActivation = 0
      hero.abilities = {ability}

      -- Initialize with empty enemies array
      combat_system.initialize(hero, projectilePool, {})

      local success = pcall(function()
        combat_system.activateAbilities(2.0)
      end)

      assert.is_true(success)
      -- No projectiles should be created
      assert.are.equal(0, #projectilePool.pool)
    end)

    it("handles nil enemies array gracefully", function()
      local ability = ArcaneBolt:new()
      ability.lastActivation = 0
      hero.abilities = {ability}

      -- Initialize with nil enemies
      combat_system.initialize(hero, projectilePool, nil)

      local success = pcall(function()
        combat_system.activateAbilities(2.0)
      end)

      assert.is_true(success)
    end)

    it("handles non-table enemies gracefully", function()
      local ability = ArcaneBolt:new()
      ability.lastActivation = 0
      hero.abilities = {ability}

      -- Initialize with invalid enemies type
      combat_system.initialize(hero, projectilePool, "not a table")

      local success = pcall(function()
        combat_system.activateAbilities(2.0)
      end)

      assert.is_true(success)
    end)

    it("continues with other abilities if one fails", function()
      -- Create a faulty ability that throws an error
      local faultyAbility = {
        canActivate = function() return true end,
        activate = function()
          error("Simulated ability error")
        end
      }

      -- Create a normal ability
      local normalAbility = ArcaneBolt:new()
      normalAbility.lastActivation = 0

      hero.abilities = {faultyAbility, normalAbility}
      table.insert(enemies, {x = 360, y = 600, isActive = true})

      combat_system.initialize(hero, projectilePool, enemies)

      -- Should not crash despite faulty ability
      local success = pcall(function()
        combat_system.activateAbilities(2.0)
      end)

      assert.is_true(success)
      -- Normal ability should still create projectile
      assert.are.equal(1, #projectilePool.pool)
    end)
  end)

  describe("updateProjectiles error handling", function()
    it("handles projectile with faulty update method", function()
      combat_system.initialize(hero, projectilePool, enemies)

      -- Create a projectile with faulty update
      local faultyProj = {
        isActive = true,
        update = function()
          error("Simulated projectile error")
        end,
        deactivate = function(self)
          self.isActive = false
        end
      }

      table.insert(projectilePool.pool, faultyProj)
      combat_system.refreshActiveProjectiles()

      -- Should not crash
      local success = pcall(function()
        combat_system.updateProjectiles(0.016)
      end)

      assert.is_true(success)
      -- Faulty projectile should be deactivated
      assert.is_false(faultyProj.isActive)
    end)

    it("checks projectile bounds correctly", function()
      combat_system.initialize(hero, projectilePool, enemies)

      local proj = projectilePool:get()
      proj:activate(100, 100, 200, 200, 100, 10, 0)

      combat_system.refreshActiveProjectiles()

      -- Move projectile far off-screen (> 200px)
      proj.x = -500
      proj.y = -500

      combat_system.updateProjectiles(0.016)

      -- Projectile should be deactivated
      assert.is_false(proj.isActive)
    end)
  end)

  describe("applyDamage error handling", function()
    it("validates damage is a number", function()
      local entity = {
        health = 100,
        takeDamage = function(self, amount)
          self.health = self.health - amount
        end
      }

      -- Try with string damage
      combat_system.applyDamage(entity, "not a number")

      -- Should apply 0 damage
      assert.are.equal(100, entity.health)
    end)

    it("clamps negative damage to 0", function()
      local entity = {
        health = 100,
        takeDamage = function(self, amount)
          self.health = self.health - amount
        end
      }

      combat_system.applyDamage(entity, -50)

      -- Health should not change
      assert.are.equal(100, entity.health)
    end)

    it("handles entity with faulty takeDamage method", function()
      local entity = {
        health = 100,
        takeDamage = function()
          error("Simulated takeDamage error")
        end
      }

      -- Should not crash
      local success = pcall(function()
        combat_system.applyDamage(entity, 10)
      end)

      assert.is_true(success)
    end)

    it("applies correct damage with valid inputs", function()
      local entity = {
        health = 100,
        takeDamage = function(self, amount)
          self.health = self.health - amount
        end
      }

      combat_system.applyDamage(entity, 25)

      assert.are.equal(75, entity.health)
    end)
  end)

end)
