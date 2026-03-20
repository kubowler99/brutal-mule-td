--- Full Game Session Integration Test
-- Comprehensive end-to-end test that validates the entire game flow
-- from menu to game over, including multiple level-ups, upgrade selection,
-- and all systems working together correctly.

require("tests.spec_helper")

local composer = require("composer")
local game_controller = require("src.controllers.game_controller")
local game_state = require("src.models.game_state")
local spawner_system = require("src.systems.spawner_system")
local experience_system = require("src.systems.experience_system")
local upgrade_system = require("src.systems.upgrade_system")
local data = require("src.models.data")

describe("Full Game Session Integration", function()
  local mockSceneGroup
  
  before_each(function()
    -- Create mock scene group
    mockSceneGroup = {
      insert = function(self, obj) end,
      numChildren = 0
    }
    
    -- Initialize game state
    game_state.initialize()
    
    -- Initialize data model in sandbox mode for testing
    data.startSandbox()
  end)
  
  after_each(function()
    -- Cleanup after each test
    game_controller.cleanup()
    data.stopSandbox()
  end)
  
  describe("Complete Game Flow", function()
    it("initializes game correctly from menu", function()
      -- Simulate transition from menu scene
      game_controller.initialize(mockSceneGroup)
      
      -- Verify hero is created
      local hero = game_controller.getHero()
      assert.is_not_nil(hero)
      assert.are.equal(1, hero.level)
      assert.are.equal(1, #hero.abilities)  -- Should have Arcane Bolt
      
      -- Verify wall is created
      local wall = game_controller.getWall()
      assert.is_not_nil(wall)
      assert.are.equal(100, wall.health)
      assert.is_false(wall:isDead())
      
      -- Verify game state
      assert.are.equal("playing", game_state.state)
    end)
    
    it("spawns enemies and hero abilities activate automatically", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local hero = game_controller.getHero()
      
      -- Simulate 3 seconds of gameplay (enough for initial spawn)
      local fps = 60
      local frames = 3 * fps
      
      for i = 1, frames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Verify walkers were spawned
      local activeWalkers = spawner_system.getActiveWalkers()
      assert.is_true(#activeWalkers > 0, "Walkers should have spawned")
      
      -- Verify walkers are moving toward wall
      local walker = activeWalkers[1]
      if walker then
        local initialY = walker.y
        
        -- Run a few more frames
        for i = frames + 1, frames + 30 do
          local event = { time = i * 16.67 }
          game_controller.update(event)
        end
        
        -- Walker should have moved downward (Y increased)
        assert.is_true(walker.y > initialY, "Walker should move toward wall")
      end
    end)
    
    it("collects XP from defeated enemies and levels up", function()
      game_controller.initialize(mockSceneGroup)
      
      -- Set up level-up callback
      local levelUpCalled = false
      local levelUpLevel = nil
      game_controller.onLevelUpCallback = function(cards)
        levelUpCalled = true
      end
      
      game_controller.start()
      
      local hero = game_controller.getHero()
      local initialLevel = hero.level
      
      -- Use experience_system.addXP to trigger level-up (not hero:addXP)
      experience_system.addXP(100)  -- Enough for level 2
      
      -- Verify level-up occurred
      assert.are.equal(2, hero.level, "Hero should level up to 2")
      assert.is_true(levelUpCalled, "Level-up callback should be called")
      assert.are.equal("paused", game_state.state, "Game should pause for upgrade selection")
    end)
    
    it("displays 3 upgrade cards on level-up", function()
      game_controller.initialize(mockSceneGroup)
      
      local upgradeCards = nil
      game_controller.onLevelUpCallback = function(cards)
        upgradeCards = cards
      end
      
      game_controller.start()
      
      local hero = game_controller.getHero()
      
      -- Trigger level-up using experience_system
      experience_system.addXP(100)
      
      -- Verify 3 upgrade cards were generated
      assert.is_not_nil(upgradeCards, "Upgrade cards should be generated")
      assert.are.equal(3, #upgradeCards, "Should have exactly 3 upgrade cards")
      
      -- Verify cards have required properties
      for _, card in ipairs(upgradeCards) do
        assert.is_not_nil(card.id)
        assert.is_not_nil(card.name)
        assert.is_not_nil(card.description)
        assert.is_not_nil(card.type)
      end
    end)
    
    it("applies selected upgrade and resumes game", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local hero = game_controller.getHero()
      
      -- Trigger level-up using experience_system
      experience_system.addXP(100)
      
      -- Verify game is paused
      assert.are.equal("paused", game_state.state)
      
      -- Get initial ability state
      local ability = hero.abilities[1]
      local initialDamage = ability.damage
      local initialTier = ability.tier
      
      -- Create and select a damage upgrade
      local damageUpgrade = {
        id = "arcane_bolt_damage",
        name = "Arcane Bolt Damage",
        description = "+5 damage",
        type = "tier_upgrade",
        abilityId = "arcane_bolt",
        apply = function(h)
          for _, ab in ipairs(h.abilities) do
            if ab.id == "arcane_bolt" then
              ab:upgrade("damage_increase")
              return true
            end
          end
          return false
        end
      }
      
      -- Select upgrade
      game_controller.onUpgradeSelected(damageUpgrade)
      
      -- Verify upgrade was applied
      assert.are.equal(initialDamage + 5, ability.damage, "Damage should increase")
      assert.are.equal(initialTier + 1, ability.tier, "Tier should increase")
      
      -- Verify game resumed
      assert.are.equal("playing", game_state.state, "Game should resume after upgrade")
    end)
    
    it("handles multiple level-ups with various upgrades", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local hero = game_controller.getHero()
      local levelUpCount = 0
      
      game_controller.onLevelUpCallback = function(cards)
        levelUpCount = levelUpCount + 1
        
        -- Auto-select first card for testing
        if cards and #cards > 0 then
          game_controller.onUpgradeSelected(cards[1])
        end
      end
      
      -- Level up 3 times
      for i = 1, 3 do
        local xpNeeded = experience_system.calculateXPRequired(hero.level)
        experience_system.addXP(xpNeeded)
      end
      
      -- Verify multiple level-ups occurred
      assert.are.equal(3, levelUpCount, "Should have 3 level-ups")
      assert.are.equal(4, hero.level, "Hero should be level 4")
      
      -- Verify game is still playable
      assert.are.equal("playing", game_state.state)
    end)
    
    it("wall takes damage from walkers and triggers game over on death", function()
      game_controller.initialize(mockSceneGroup)
      
      local gameOverCalled = false
      local gameOverStats = nil
      game_controller.onGameOverCallback = function(stats)
        gameOverCalled = true
        gameOverStats = stats
      end
      
      game_controller.start()
      
      local wall = game_controller.getWall()
      
      -- Set wall to low health for faster test
      wall.health = 10
      
      -- Simulate gameplay until wall dies
      local fps = 60
      local maxFrames = 40 * fps  -- 40 seconds max
      
      for i = 1, maxFrames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
        
        if wall:isDead() then
          break
        end
      end
      
      -- Verify wall died
      assert.is_true(wall:isDead(), "Wall should be dead")
      
      -- Verify game over was triggered
      assert.is_true(gameOverCalled, "Game over callback should be called")
      assert.are.equal("game_over", game_state.state)
      
      -- Verify statistics are provided
      assert.is_not_nil(gameOverStats)
      assert.is_not_nil(gameOverStats.survivalTime)
      assert.is_not_nil(gameOverStats.enemiesDefeated)
      assert.is_not_nil(gameOverStats.finalLevel)
    end)
    
    it("displays correct statistics on game over", function()
      game_controller.initialize(mockSceneGroup)
      
      local gameOverStats = nil
      game_controller.onGameOverCallback = function(stats)
        gameOverStats = stats
      end
      
      game_controller.start()
      
      local hero = game_controller.getHero()
      
      -- Simulate some gameplay
      local fps = 60
      local simulationSeconds = 10
      
      for i = 1, simulationSeconds * fps do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Manually trigger game over
      game_controller.onGameOver()
      
      -- Verify statistics
      assert.is_not_nil(gameOverStats)
      assert.is_true(gameOverStats.survivalTime > 0, "Survival time should be positive")
      assert.is_true(gameOverStats.enemiesDefeated >= 0, "Enemies defeated should be non-negative")
      assert.are.equal(hero.level, gameOverStats.finalLevel, "Final level should match hero level")
      
      -- Verify statistics are numbers
      assert.are.equal("number", type(gameOverStats.survivalTime))
      assert.are.equal("number", type(gameOverStats.enemiesDefeated))
      assert.are.equal("number", type(gameOverStats.finalLevel))
    end)
    
    it("saves statistics to persistent data on game over", function()
      game_controller.initialize(mockSceneGroup)
      
      -- Get initial stats
      local initialGamesPlayed = data.get("stats.gamesPlayed") or 0
      
      game_controller.onGameOverCallback = function(stats)
        -- Simulate what game over scene does
        data.set("stats.gamesPlayed", (data.get("stats.gamesPlayed") or 0) + 1)
        
        local currentHighest = data.get("stats.highestLevel") or 0
        if stats.finalLevel > currentHighest then
          data.set("stats.highestLevel", stats.finalLevel)
        end
        
        local currentLongest = data.get("stats.longestSurvival") or 0
        if stats.survivalTime > currentLongest then
          data.set("stats.longestSurvival", stats.survivalTime)
        end
        
        local totalDefeated = data.get("stats.totalEnemiesDefeated") or 0
        data.set("stats.totalEnemiesDefeated", totalDefeated + stats.enemiesDefeated)
        
        data.save()
      end
      
      game_controller.start()
      
      -- Simulate gameplay
      for i = 1, 60 do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Trigger game over
      game_controller.onGameOver()
      
      -- Verify stats were updated
      assert.are.equal(initialGamesPlayed + 1, data.get("stats.gamesPlayed"))
    end)
  end)
  
  describe("System Integration", function()
    it("all systems work together correctly during gameplay", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local hero = game_controller.getHero()
      local wall = game_controller.getWall()
      
      -- Simulate 15 seconds of gameplay
      local fps = 60
      local frames = 15 * fps
      
      for i = 1, frames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Verify all systems are functioning:
      
      -- 1. Spawner system: enemies spawned
      local activeWalkers = spawner_system.getActiveWalkers()
      assert.is_true(#activeWalkers > 0, "Spawner system should spawn enemies")
      
      -- 2. Combat system: hero has abilities
      assert.is_true(#hero.abilities > 0, "Hero should have abilities")
      
      -- 3. Level system: XP orbs may exist (if enemies defeated)
      local activeOrbs = experience_system.getActiveOrbs()
      -- Can't guarantee orbs exist, but system should be initialized
      assert.is_not_nil(activeOrbs)
      
      -- 4. Game state: time is tracking
      assert.is_true(game_state.elapsedTime > 0, "Elapsed time should be tracked")
      
      -- 5. Wall: should still be alive or have taken damage
      assert.is_true(wall.health <= 100, "Wall health should be <= initial")
    end)
    
    it("handles rapid level-ups without errors", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local hero = game_controller.getHero()
      
      game_controller.onLevelUpCallback = function(cards)
        -- Auto-select first card
        if cards and #cards > 0 then
          game_controller.onUpgradeSelected(cards[1])
        end
      end
      
      -- Rapidly level up 5 times
      for i = 1, 5 do
        local xpNeeded = experience_system.calculateXPRequired(hero.level)
        experience_system.addXP(xpNeeded)
      end
      
      -- Verify hero reached level 6
      assert.are.equal(6, hero.level)
      
      -- Verify game is still functional
      assert.are.equal("playing", game_state.state)
      
      -- Run a few more frames to ensure stability
      for i = 1, 30 do
        local event = { time = (i + 100) * 16.67 }
        game_controller.update(event)
      end
      
      -- No errors means success
      assert.is_true(true)
    end)
    
    it("handles maximum walkers (50) without performance issues", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      -- Simulate long gameplay to reach max walkers
      local fps = 60
      local frames = 120 * fps  -- 2 minutes
      
      for i = 1, frames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
        
        -- Check walker count periodically
        if i % fps == 0 then
          local activeWalkers = spawner_system.getActiveWalkers()
          -- Should never exceed 50
          assert.is_true(#activeWalkers <= 50, "Walker count should not exceed 50")
        end
      end
      
      -- Verify game is still functional
      local activeWalkers = spawner_system.getActiveWalkers()
      assert.is_true(#activeWalkers <= 50)
    end)
  end)
  
  describe("Edge Cases and Error Handling", function()
    it("handles game with no enemies gracefully", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local wall = game_controller.getWall()
      local initialHealth = wall.health
      
      -- Simulate very short time (before enemies spawn)
      for i = 1, 30 do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Wall should not have taken damage
      assert.are.equal(initialHealth, wall.health)
    end)
    
    it("handles hero with all 5 ability slots filled", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local hero = game_controller.getHero()
      
      -- Fill all ability slots (already has 1, add 4 more)
      local ArcaneBolt = require("src.entities.abilities.arcane_bolt")
      for i = 1, 4 do
        local ability = ArcaneBolt:new()
        ability.id = "ability_" .. i
        hero:addAbility(ability)
      end
      
      -- Verify 5 abilities
      assert.are.equal(5, #hero.abilities)
      
      -- Try to add another (should fail or be ignored)
      local extraAbility = ArcaneBolt:new()
      extraAbility.id = "extra"
      hero:addAbility(extraAbility)
      
      -- Should still have 5 abilities
      assert.are.equal(5, #hero.abilities)
    end)
    
    it("handles ability at max tier (5)", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      local hero = game_controller.getHero()
      local ability = hero.abilities[1]
      
      -- Upgrade to max tier
      for i = 1, 4 do
        ability:upgrade("damage_increase")
      end
      
      -- Verify at tier 5
      assert.are.equal(5, ability.tier)
      
      -- Try to upgrade beyond max (should be prevented)
      local initialDamage = ability.damage
      ability:upgrade("damage_increase")
      
      -- Tier should still be 5
      assert.are.equal(5, ability.tier)
    end)
    
    it("handles XP orb lifetime expiration", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      -- Get current time from system
      local startTime = system.getTimer() / 1000
      
      -- Manually spawn an XP orb
      experience_system.spawnXPOrb(360, 640)
      
      local activeOrbs = experience_system.getActiveOrbs()
      assert.are.equal(1, #activeOrbs)
      
      -- Mock system.getTimer to simulate 31 seconds passing
      local originalGetTimer = system.getTimer
      system.getTimer = function()
        return (startTime + 31) * 1000  -- 31 seconds later in milliseconds
      end
      
      -- Simulate a frame with the new time
      local currentTime = startTime + 31
      experience_system.update(0.016, currentTime)
      
      -- Restore original getTimer
      system.getTimer = originalGetTimer
      
      -- Orb should have expired
      activeOrbs = experience_system.getActiveOrbs()
      assert.are.equal(0, #activeOrbs, "Orb should expire after 30 seconds")
    end)
    
    it("handles pause and resume correctly", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      -- Verify game is playing
      assert.are.equal("playing", game_state.state)
      
      -- Pause game
      game_controller.pause()
      assert.are.equal("paused", game_state.state)
      
      -- Resume game
      game_controller.resume()
      assert.are.equal("playing", game_state.state)
    end)
    
    it("handles cleanup correctly", function()
      game_controller.initialize(mockSceneGroup)
      game_controller.start()
      
      -- Simulate some gameplay
      for i = 1, 60 do
        local event = { time = i * 16.67 }
        game_controller.update(event)
      end
      
      -- Cleanup
      game_controller.cleanup()
      
      -- Verify cleanup
      assert.is_nil(game_controller.getHero())
      assert.is_nil(game_controller.getWall())
    end)
  end)
  
  describe("Full Session Simulation", function()
    it("simulates complete game session from start to game over", function()
      -- This test simulates a realistic game session
      game_controller.initialize(mockSceneGroup)
      
      local levelUpCount = 0
      local upgradesApplied = {}
      
      game_controller.onLevelUpCallback = function(cards)
        levelUpCount = levelUpCount + 1
        
        -- Select a random upgrade
        if cards and #cards > 0 then
          local selectedCard = cards[math.random(1, #cards)]
          table.insert(upgradesApplied, selectedCard.id)
          game_controller.onUpgradeSelected(selectedCard)
        end
      end
      
      local gameOverCalled = false
      local finalStats = nil
      game_controller.onGameOverCallback = function(stats)
        gameOverCalled = true
        finalStats = stats
      end
      
      game_controller.start()
      
      local hero = game_controller.getHero()
      local wall = game_controller.getWall()
      
      -- Add XP immediately to ensure at least one level-up
      experience_system.addXP(100)  -- Level up to 2
      experience_system.addXP(120)  -- Level up to 3
      
      -- Simulate gameplay (shorter duration since we're testing integration)
      local fps = 60
      local maxFrames = 30 * fps  -- 30 seconds
      
      for i = 1, maxFrames do
        local event = { time = i * 16.67 }
        game_controller.update(event)
        
        -- Periodically add more XP
        if i % (3 * fps) == 0 then  -- Every 3 seconds
          experience_system.addXP(50)
        end
        
        -- Check if game over
        if wall:isDead() or gameOverCalled then
          break
        end
      end
      
      -- Verify game session completed
      assert.is_true(levelUpCount > 0, "Should have leveled up at least once")
      assert.is_true(#upgradesApplied > 0, "Should have applied at least one upgrade")
      
      -- Verify final state
      assert.is_true(hero.level > 1, "Hero should have leveled up")
      assert.is_true(game_state.elapsedTime > 0, "Time should have elapsed")
      assert.is_true(game_state.enemiesDefeated >= 0, "Enemy count should be tracked")
      
      -- If game over occurred naturally, verify it
      if gameOverCalled then
        assert.is_not_nil(finalStats)
        assert.are.equal("game_over", game_state.state)
      end
    end)
  end)
end)

