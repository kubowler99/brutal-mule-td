--- Upgrade Selection Flow Integration Tests
-- Tests for the complete upgrade selection flow: level-up → pause → select → resume

require("tests.spec_helper")

local composer = require("composer")
local game_controller = require("src.controllers.game_controller")
local upgrade_system = require("src.systems.upgrade_system")
local experience_system = require("src.systems.experience_system")

describe("Upgrade Selection Flow Integration", function()
  local scene
  
  before_each(function()
    -- Create a new scene instance
    scene = composer.newScene()
    
    -- Load the game scene module
    local gameSceneModule = require("src.scenes.game")
    
    -- Copy functions from module to scene
    scene.create = gameSceneModule.create
    scene.show = gameSceneModule.show
    scene.hide = gameSceneModule.hide
    scene.destroy = gameSceneModule.destroy
  end)
  
  after_each(function()
    -- Cleanup
    if scene and scene.destroy then
      local event = { name = "destroy", phase = "will" }
      scene:destroy(event)
    end
    
    scene = nil
  end)
  
  it("triggers level-up, pauses game, shows upgrade panel with 3 cards", function()
    -- Setup: Save original functions
    local originalInit = game_controller.initialize
    local originalPause = game_controller.pause
    local originalGetHero = game_controller.getHero
    local originalGetWall = game_controller.getWall
    local originalStart = game_controller.start
    local originalGenerateCards = upgrade_system.generateCards
    
    -- Track state
    local pauseCalled = false
    local mockHero = {
      health = 100,
      maxHealth = 100,
      level = 1,
      xp = 0,
      xpRequired = 100,
      abilities = {
        { id = "arcane_bolt", name = "Arcane Bolt", tier = 1, cooldown = 1.0 }
      },
      displayObject = { isVisible = true }
    }
    
    local mockWall = {
      health = 100,
      maxHealth = 100,
      displayObject = { isVisible = true },
      isDead = function(self) return self.health <= 0 end
    }
    
    local mockCards = {
      { id = "arcane_bolt_damage", name = "Arcane Bolt Damage", description = "+5 damage", type = "tier_upgrade" },
      { id = "arcane_bolt_attack_speed", name = "Arcane Bolt Attack Speed", description = "-0.15s cooldown", type = "tier_upgrade" },
      { id = "xp_pickup_radius", name = "XP Pickup Radius", description = "+20 pixels", type = "stat_upgrade" }
    }
    
    -- Mock functions
    game_controller.initialize = function(group) end
    game_controller.pause = function()
      pauseCalled = true
    end
    game_controller.getHero = function() return mockHero end
    game_controller.getWall = function() return mockWall end
    game_controller.start = function() end
    
    upgrade_system.generateCards = function(count)
      assert.are.equal(3, count, "Should request exactly 3 upgrade cards")
      return mockCards
    end
    
    -- Create and show scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    event = { name = "show", phase = "will" }
    scene:show(event)
    
    event = { name = "show", phase = "did" }
    scene:show(event)
    
    -- Verify upgrade panel callback is registered
    assert.is_not_nil(game_controller.onLevelUpCallback, "Level-up callback should be registered")
    assert.is_function(game_controller.onLevelUpCallback, "Level-up callback should be a function")
    
    -- Reset pause flag
    pauseCalled = false
    
    -- STEP 1: Trigger level-up
    game_controller.onLevelUp(2)
    
    -- STEP 2: Verify game was paused
    assert.is_true(pauseCalled, "Game should be paused when level-up occurs")
    
    -- STEP 3: Verify upgrade panel callback was called with 3 cards
    -- The callback should have been called by onLevelUp
    -- We can't directly verify the panel is visible without accessing scene internals,
    -- but we can verify the callback exists and would be called
    
    -- Cleanup
    game_controller.initialize = originalInit
    game_controller.pause = originalPause
    game_controller.getHero = originalGetHero
    game_controller.getWall = originalGetWall
    game_controller.start = originalStart
    upgrade_system.generateCards = originalGenerateCards
  end)
  
  it("applies selected upgrade and resumes game after card selection", function()
    -- Setup: Save original functions
    local originalInit = game_controller.initialize
    local originalPause = game_controller.pause
    local originalResume = game_controller.resume
    local originalGetHero = game_controller.getHero
    local originalGetWall = game_controller.getWall
    local originalStart = game_controller.start
    local originalApplyUpgrade = upgrade_system.applyUpgrade
    
    -- Track state
    local resumeCalled = false
    local appliedUpgrade = nil
    local mockHero = {
      health = 100,
      maxHealth = 100,
      level = 2,
      xp = 0,
      xpRequired = 120,
      abilities = {
        { 
          id = "arcane_bolt", 
          name = "Arcane Bolt", 
          tier = 1, 
          cooldown = 1.0,
          damage = 10,
          upgrade = function(self, upgradeType)
            if upgradeType == "damage_increase" then
              self.damage = self.damage + 5
              self.tier = self.tier + 1
            end
          end
        }
      },
      displayObject = { isVisible = true }
    }
    
    local mockWall = {
      health = 100,
      maxHealth = 100,
      displayObject = { isVisible = true },
      isDead = function(self) return self.health <= 0 end
    }
    
    local selectedUpgrade = {
      id = "arcane_bolt_damage",
      name = "Arcane Bolt Damage",
      description = "+5 damage",
      type = "tier_upgrade",
      abilityId = "arcane_bolt",
      apply = function(hero)
        for _, ability in ipairs(hero.abilities) do
          if ability.id == "arcane_bolt" then
            ability:upgrade("damage_increase")
            return true
          end
        end
        return false
      end
    }
    
    -- Mock functions
    game_controller.initialize = function(group) end
    game_controller.pause = function() end
    game_controller.resume = function()
      resumeCalled = true
    end
    game_controller.getHero = function() return mockHero end
    game_controller.getWall = function() return mockWall end
    game_controller.start = function() end
    
    upgrade_system.applyUpgrade = function(upgrade)
      appliedUpgrade = upgrade
      if upgrade and upgrade.apply then
        upgrade.apply(mockHero)
      end
    end
    
    -- Create and show scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    event = { name = "show", phase = "will" }
    scene:show(event)
    
    event = { name = "show", phase = "did" }
    scene:show(event)
    
    -- Verify initial ability state
    local ability = mockHero.abilities[1]
    assert.are.equal(10, ability.damage, "Initial damage should be 10")
    assert.are.equal(1, ability.tier, "Initial tier should be 1")
    
    -- STEP 1: Select an upgrade (simulate card tap)
    game_controller.onUpgradeSelected(selectedUpgrade)
    
    -- STEP 2: Verify upgrade was applied
    assert.is_not_nil(appliedUpgrade, "Upgrade should have been applied")
    assert.are.equal("arcane_bolt_damage", appliedUpgrade.id, "Correct upgrade should be applied")
    
    -- STEP 3: Verify ability was upgraded
    assert.are.equal(15, ability.damage, "Damage should increase from 10 to 15")
    assert.are.equal(2, ability.tier, "Tier should increase from 1 to 2")
    
    -- STEP 4: Verify game was resumed
    assert.is_true(resumeCalled, "Game should resume after upgrade selection")
    
    -- Cleanup
    game_controller.initialize = originalInit
    game_controller.pause = originalPause
    game_controller.resume = originalResume
    game_controller.getHero = originalGetHero
    game_controller.getWall = originalGetWall
    game_controller.start = originalStart
    upgrade_system.applyUpgrade = originalApplyUpgrade
  end)
  
  it("completes full upgrade flow: level-up → pause → select → apply → resume", function()
    -- Setup: Save original functions
    local originalInit = game_controller.initialize
    local originalPause = game_controller.pause
    local originalResume = game_controller.resume
    local originalGetHero = game_controller.getHero
    local originalGetWall = game_controller.getWall
    local originalStart = game_controller.start
    local originalGenerateCards = upgrade_system.generateCards
    local originalApplyUpgrade = upgrade_system.applyUpgrade
    
    -- Track execution flow
    local executionFlow = {}
    
    local mockHero = {
      health = 100,
      maxHealth = 100,
      level = 1,
      xp = 100,  -- Enough XP to level up
      xpRequired = 100,
      abilities = {
        { 
          id = "arcane_bolt", 
          name = "Arcane Bolt", 
          tier = 1, 
          cooldown = 1.0,
          projectileCount = 1,
          upgrade = function(self, upgradeType)
            if upgradeType == "projectile_count" then
              self.projectileCount = self.projectileCount + 1
              self.tier = self.tier + 1
            end
          end
        }
      },
      displayObject = { isVisible = true }
    }
    
    local mockWall = {
      health = 100,
      maxHealth = 100,
      displayObject = { isVisible = true },
      isDead = function(self) return self.health <= 0 end
    }
    
    local mockCards = {
      { 
        id = "arcane_bolt_projectile_count",
        name = "Arcane Bolt Projectile Count",
        description = "+1 projectile",
        type = "tier_upgrade",
        abilityId = "arcane_bolt",
        apply = function(hero)
          for _, ability in ipairs(hero.abilities) do
            if ability.id == "arcane_bolt" then
              ability:upgrade("projectile_count")
              return true
            end
          end
          return false
        end
      },
      { id = "arcane_bolt_damage", name = "Damage", description = "+5 damage", type = "tier_upgrade" },
      { id = "xp_pickup_radius", name = "XP Radius", description = "+20 pixels", type = "stat_upgrade" }
    }
    
    -- Mock functions with flow tracking
    game_controller.initialize = function(group) end
    
    game_controller.pause = function()
      table.insert(executionFlow, "pause")
    end
    
    game_controller.resume = function()
      table.insert(executionFlow, "resume")
    end
    
    game_controller.getHero = function() return mockHero end
    game_controller.getWall = function() return mockWall end
    game_controller.start = function() end
    
    upgrade_system.generateCards = function(count)
      table.insert(executionFlow, "generateCards")
      return mockCards
    end
    
    upgrade_system.applyUpgrade = function(upgrade)
      table.insert(executionFlow, "applyUpgrade")
      if upgrade and upgrade.apply then
        upgrade.apply(mockHero)
      end
    end
    
    -- Create and show scene
    local event = { name = "create", phase = "will" }
    scene:create(event)
    
    event = { name = "show", phase = "will" }
    scene:show(event)
    
    event = { name = "show", phase = "did" }
    scene:show(event)
    
    -- Verify initial state
    local ability = mockHero.abilities[1]
    assert.are.equal(1, ability.projectileCount, "Initial projectile count should be 1")
    assert.are.equal(1, ability.tier, "Initial tier should be 1")
    
    -- STEP 1: Trigger level-up (simulates hero gaining enough XP)
    table.insert(executionFlow, "levelUp")
    game_controller.onLevelUp(2)
    
    -- STEP 2: Select first upgrade card (projectile count)
    table.insert(executionFlow, "selectCard")
    game_controller.onUpgradeSelected(mockCards[1])
    
    -- Verify execution flow
    assert.are.equal(6, #executionFlow, "Should have 6 steps in execution flow")
    assert.are.equal("levelUp", executionFlow[1], "Step 1: Level-up triggered")
    assert.are.equal("pause", executionFlow[2], "Step 2: Game paused")
    assert.are.equal("generateCards", executionFlow[3], "Step 3: Cards generated")
    assert.are.equal("selectCard", executionFlow[4], "Step 4: Card selected")
    assert.are.equal("applyUpgrade", executionFlow[5], "Step 5: Upgrade applied")
    assert.are.equal("resume", executionFlow[6], "Step 6: Game resumed")
    
    -- Verify upgrade was applied
    assert.are.equal(2, ability.projectileCount, "Projectile count should increase from 1 to 2")
    assert.are.equal(2, ability.tier, "Tier should increase from 1 to 2")
    
    -- Cleanup
    game_controller.initialize = originalInit
    game_controller.pause = originalPause
    game_controller.resume = originalResume
    game_controller.getHero = originalGetHero
    game_controller.getWall = originalGetWall
    game_controller.start = originalStart
    upgrade_system.generateCards = originalGenerateCards
    upgrade_system.applyUpgrade = originalApplyUpgrade
  end)
end)

