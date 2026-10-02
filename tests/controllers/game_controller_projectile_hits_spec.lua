-- Regression tests for projectile hit resolution in the game loop
-- Collisions are gathered before damage is applied, so several projectiles can
-- report a hit on the same walker in one frame. A kill must be rewarded once.

require("tests.spec_helper")

local game_controller = require("src.controllers.game_controller")
local game_state = require("src.models.game_state")
local collision_system = require("src.systems.collision_system")
local experience_system = require("src.systems.experience_system")
local Walker = require("src.entities.walker")
local Projectile = require("src.entities.projectile")

describe("Game Controller projectile hits", function()
  local originalCheckProjectileCollisions
  local originalAwardXP
  local awardXPCalls
  local stubbedCollisions

  local function newWalker(health)
    local walker = Walker:new(nil)
    walker:activate(360, 300, 360)
    walker.health = health
    walker.maxHealth = health
    return walker
  end

  local function newProjectile(damage, pierce)
    local projectile = Projectile:new(nil)
    projectile:activate(360, 1200, 360, 300, 600, damage, pierce)
    return projectile
  end

  before_each(function()
    originalCheckProjectileCollisions = collision_system.checkProjectileCollisions
    originalAwardXP = experience_system.awardXP

    stubbedCollisions = {}
    collision_system.checkProjectileCollisions = function()
      return stubbedCollisions
    end

    awardXPCalls = 0
    experience_system.awardXP = function()
      awardXPCalls = awardXPCalls + 1
    end

    game_controller.initialize({ insert = function() end, numChildren = 0 })
    game_controller.start()
  end)

  after_each(function()
    collision_system.checkProjectileCollisions = originalCheckProjectileCollisions
    experience_system.awardXP = originalAwardXP
    game_controller.cleanup()
  end)

  it("awards XP once when two projectiles kill the same walker in one frame", function()
    local walker = newWalker(10)
    local first = newProjectile(10, 0)
    local second = newProjectile(10, 0)

    stubbedCollisions = {
      { projectile = first, enemy = walker },
      { projectile = second, enemy = walker },
    }

    game_controller.update({ time = 16 })

    assert.is_false(walker.isActive)
    assert.are.equal(1, awardXPCalls)
    assert.are.equal(1, game_state.enemiesDefeated)
  end)

  it("does not spend a projectile on a walker killed earlier in the same frame", function()
    local walker = newWalker(10)
    local first = newProjectile(10, 0)
    local second = newProjectile(10, 0)

    stubbedCollisions = {
      { projectile = first, enemy = walker },
      { projectile = second, enemy = walker },
    }

    game_controller.update({ time = 16 })

    assert.is_true(second.isActive)
    assert.are.equal(0, #second.hitEnemies)
  end)

  it("does not let a spent projectile damage a second walker in the same frame", function()
    local firstWalker = newWalker(30)
    local secondWalker = newWalker(30)
    local projectile = newProjectile(10, 0)

    stubbedCollisions = {
      { projectile = projectile, enemy = firstWalker },
      { projectile = projectile, enemy = secondWalker },
    }

    game_controller.update({ time = 16 })

    assert.are.equal(20, firstWalker.health)
    assert.are.equal(30, secondWalker.health)
  end)

  it("still awards XP for each distinct walker killed in one frame", function()
    local firstWalker = newWalker(10)
    local secondWalker = newWalker(10)

    stubbedCollisions = {
      { projectile = newProjectile(10, 0), enemy = firstWalker },
      { projectile = newProjectile(10, 0), enemy = secondWalker },
    }

    game_controller.update({ time = 16 })

    assert.are.equal(2, awardXPCalls)
    assert.are.equal(2, game_state.enemiesDefeated)
  end)
end)
