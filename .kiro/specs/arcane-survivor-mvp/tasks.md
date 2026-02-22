# Implementation Plan: Arcane Survivor MVP

## Overview

This implementation plan breaks down the Arcane Survivor MVP into discrete coding tasks. The game is a lane-based tower defense roguelike built on Solar2D with Lua 5.1, featuring automatic combat, XP-based progression, and strategic upgrade selection.

The implementation follows a bottom-up approach: core entities → systems → game controller → scenes → UI. Each task builds incrementally, with property-based tests integrated alongside implementation to catch errors early.

## Tasks

- [x] 1. Set up project structure and testing infrastructure
  - Create directory structure for entities, systems, controllers, scenes, UI
  - Set up Busted testing framework and spec_helper.lua with Solar2D mocks
  - Create custom generators file for property-based testing (tests/generators/game_generators.lua)
  - Install lua-quickcheck for property-based testing
  - _Requirements: 12.1, 12.3_

- [x] 2. Implement core entity: Hero
  - [x] 2.1 Create Hero class with middleclass
    - Implement Hero:initialize(x, y) with fixed position (360, 1180)
    - Add properties: health, maxHealth, level, xp, xpRequired, abilities array, pickupRadius, isAlive
    - Implement Hero:takeDamage(amount), Hero:addAbility(ability), Hero:addXP(amount)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.6_
  
  - [x] 2.2 Write unit tests for Hero entity
    - Test initial state (level 1, health 100, empty abilities)
    - Test takeDamage reduces health correctly
    - Test death state when health reaches zero
    - _Requirements: 1.1, 1.2, 1.5_
  
  - [x] 2.3 Write property test for Hero position immutability
    - **Property 3: Hero Position Immutability**
    - **Validates: Requirements 1.4**


- [ ] 3. Implement core entity: Walker
  - [x] 3.1 Create Walker class with middleclass
    - Implement Walker:initialize() for object pooling
    - Implement Walker:activate(x, y, lane) to set spawn position and lane
    - Add properties: x, y, lane, health, maxHealth, speed, damage, attackCooldown, isActive
    - Implement Walker:update(dt, heroX, heroY) for vertical movement
    - Implement Walker:takeDamage(amount) and Walker:deactivate()
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  
  - [ ] 3.2 Write unit tests for Walker entity
    - Test activate/deactivate for pooling
    - Test vertical movement (Y decreases, X constant)
    - Test takeDamage and defeat behavior
    - _Requirements: 4.1, 4.3, 4.4_
  
  - [ ] 3.3 Write property test for Walker lane assignment
    - **Property 10: Lane Assignment**
    - **Validates: Requirements 3.8**
  
  - [ ] 3.4 Write property test for Walker vertical movement
    - **Property 11: Walker Vertical Movement**
    - **Validates: Requirements 4.1**

- [ ] 4. Implement core entity: Projectile
  - [ ] 4.1 Create Projectile class with middleclass
    - Implement Projectile:initialize() for object pooling
    - Implement Projectile:activate(x, y, targetX, targetY, speed, damage, pierce)
    - Add properties: x, y, vx, vy, damage, pierceCount, isActive, hitEnemies
    - Implement Projectile:update(dt) for movement
    - Implement Projectile:onHit(enemy) and Projectile:deactivate()
    - Implement Projectile:isOffScreen() boundary check
    - _Requirements: 2.4, 2.6_
  
  - [ ] 4.2 Write unit tests for Projectile entity
    - Test activate calculates correct velocity vector
    - Test update moves projectile correctly
    - Test isOffScreen detects boundaries
    - Test pierce behavior (hitEnemies tracking)
    - _Requirements: 2.4, 2.6_
  
  - [ ] 4.3 Write property test for Projectile velocity
    - **Property 6: Projectile Velocity**
    - **Validates: Requirements 2.4**

- [ ] 5. Implement core entity: XP Orb
  - [ ] 5.1 Create XPOrb class with middleclass
    - Implement XPOrb:initialize() for object pooling
    - Implement XPOrb:activate(x, y) to set spawn position and timestamp
    - Add properties: x, y, xpValue, lifetime, spawnTime, isActive
    - Implement XPOrb:update(currentTime) to check lifetime expiration
    - Implement XPOrb:collect() and XPOrb:deactivate()
    - _Requirements: 5.1, 5.2_
  
  - [ ] 5.2 Write unit tests for XP Orb entity
    - Test activate sets position and spawn time
    - Test lifetime expiration after 30 seconds
    - Test collect behavior
    - _Requirements: 5.1, 5.2_
  
  - [ ] 5.3 Write property test for XP Orb lifetime
    - **Property 16: XP Orb Lifetime**
    - **Validates: Requirements 5.1**


- [ ] 6. Implement Arcane Bolt ability
  - [ ] 6.1 Create ArcaneBolt class with middleclass
    - Implement ArcaneBolt:initialize() with base stats (cooldown 1.0s, damage 10)
    - Add properties: id, name, cooldown, lastActivation, damage, projectileSpeed, tier, pierceCount, projectileCount
    - Implement ArcaneBolt:canActivate(currentTime) cooldown check
    - Implement ArcaneBolt:findNearestEnemy(heroX, heroY, enemies)
    - Implement ArcaneBolt:activate(heroX, heroY, enemies, projectilePool)
    - Implement ArcaneBolt:upgrade(upgradeType) for tier upgrades
    - _Requirements: 2.1, 2.2, 2.3, 2.7_
  
  - [ ] 6.2 Write unit tests for Arcane Bolt ability
    - Test canActivate respects cooldown
    - Test findNearestEnemy returns closest enemy
    - Test activate creates projectiles
    - Test upgrade applies tier bonuses correctly
    - _Requirements: 2.1, 2.2, 2.3, 2.7_
  
  - [ ] 6.3 Write property test for ability cooldown independence
    - **Property 4: Ability Cooldown Independence**
    - **Validates: Requirements 2.8**
  
  - [ ] 6.4 Write property test for nearest enemy targeting
    - **Property 5: Nearest Enemy Targeting**
    - **Validates: Requirements 2.3**

- [ ] 7. Implement Collision System
  - [ ] 7.1 Create collision_system module
    - Implement collision_system.checkDistance(x1, y1, x2, y2) using distance formula
    - Implement collision_system.checkProjectileCollisions(projectiles, enemies)
    - Implement collision_system.checkXPCollection(hero, xpOrbs)
    - Implement collision_system.checkMeleeRange(hero, enemies)
    - Define collision thresholds (projectile-enemy: 20px, hero-XP: hero.pickupRadius, hero-enemy: 30px)
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.6_
  
  - [ ] 7.2 Write property test for distance-based collision detection
    - **Property 24: Distance-Based Collision Detection**
    - **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.6**

- [ ] 8. Implement Combat System
  - [ ] 8.1 Create combat_system module
    - Implement combat_system.initialize(hero, projectilePool, enemies)
    - Implement combat_system.update(dt, currentTime) main update loop
    - Implement combat_system.activateAbilities(currentTime) to iterate hero abilities
    - Implement combat_system.updateProjectiles(dt) for projectile movement
    - Implement combat_system.applyDamage(entity, amount) with validation
    - Implement combat_system.cleanup() for resource cleanup
    - Track activeProjectiles array
    - _Requirements: 2.1, 2.5, 2.6, 4.4_
  
  - [ ] 8.2 Write unit tests for Combat System
    - Test ability activation respects cooldowns
    - Test projectile creation and tracking
    - Test damage application on collision
    - Test projectile removal on hit/out of bounds
    - _Requirements: 2.1, 2.5, 2.6_
  
  - [ ] 8.3 Write property test for projectile damage application
    - **Property 14: Projectile Damage Application**
    - **Validates: Requirements 2.5**
  
  - [ ] 8.4 Write property test for projectile removal on collision
    - **Property 15: Projectile Removal on Collision**
    - **Validates: Requirements 2.6, 12.5**


- [ ] 9. Implement Spawner System
  - [ ] 9.1 Create spawner_system module
    - Implement spawner_system.initialize(walkerPool, heroLevel)
    - Implement spawner_system.update(dt, currentTime) with spawn timer
    - Implement spawner_system.spawnWalker() with lane assignment
    - Implement spawner_system.updateDifficulty(heroLevel) for scaling
    - Add difficulty curve logic (level < 5: 1 every 3s, 5-10: 2 every 3s, 10-15: 3 every 2s, 15+: 4 every 2s)
    - Enforce maximum 50 concurrent walkers
    - Track activeWalkers array
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9_
  
  - [ ] 9.2 Write unit tests for Spawner System
    - Test spawn timer accumulation
    - Test walker activation with correct lane
    - Test maximum concurrent limit enforcement
    - Test difficulty scaling at different levels
    - _Requirements: 3.1, 3.3, 3.9_
  
  - [ ] 9.3 Write property test for spawn rate scaling
    - **Property 7: Spawn Rate Scaling**
    - **Validates: Requirements 3.3, 3.4, 3.5, 3.6**
  
  - [ ] 9.4 Write property test for maximum concurrent enemies
    - **Property 8: Maximum Concurrent Enemies**
    - **Validates: Requirements 3.9, 12.2**
  
  - [ ] 9.5 Write property test for walker spawn position
    - **Property 9: Walker Spawn Position**
    - **Validates: Requirements 3.7**

- [ ] 10. Implement Level System
  - [ ] 10.1 Create level_system module
    - Implement level_system.initialize(hero, xpOrbPool, onLevelUpCallback)
    - Implement level_system.update(dt, currentTime) for orb lifetime checks
    - Implement level_system.spawnXPOrb(x, y) on enemy defeat
    - Implement level_system.checkOrbCollection(heroX, heroY, heroRadius)
    - Implement level_system.addXP(amount) with level-up trigger
    - Implement level_system.calculateXPRequired(level) using formula: 100 + (level - 1) * 20
    - Track activeOrbs array
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_
  
  - [ ] 10.2 Write unit tests for Level System
    - Test XP orb spawning and activation
    - Test XP collection on proximity
    - Test XP requirement calculation
    - Test level-up trigger and callback
    - _Requirements: 5.2, 5.4, 5.5, 5.6_
  
  - [ ] 10.3 Write property test for XP collection on proximity
    - **Property 17: XP Collection on Proximity**
    - **Validates: Requirements 5.2**
  
  - [ ] 10.4 Write property test for XP requirement formula
    - **Property 18: XP Requirement Formula**
    - **Validates: Requirements 5.4**
  
  - [ ] 10.5 Write property test for level-up trigger
    - **Property 19: Level-Up Trigger**
    - **Validates: Requirements 5.5, 5.6**


- [ ] 11. Implement Upgrade System
  - [ ] 11.1 Create upgrade_system module
    - Implement upgrade_system.initialize(hero, onUpgradeSelectedCallback)
    - Implement upgrade_system.generateCards(count) to create 3 random upgrade cards
    - Define upgrade pool with MVP upgrades (Arcane Bolt damage, attack speed, projectile count, pierce, XP radius)
    - Implement upgrade_system.applyUpgrade(upgradeCard) to modify hero abilities
    - Implement upgrade_system.canOfferNewAbility() to check slot availability
    - Implement upgrade_system.getAvailableUpgrades() with filtering logic
    - Ensure at least one new ability card when slots < 5
    - Ensure at least one tier upgrade card when abilities exist
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_
  
  - [ ] 11.2 Write unit tests for Upgrade System
    - Test card generation creates exactly 3 cards
    - Test new ability availability when slots < 5
    - Test tier upgrade availability when abilities exist
    - Test upgrade application modifies abilities correctly
    - Test tier limit enforcement (max tier 5)
    - _Requirements: 6.1, 6.3, 6.4, 6.5, 6.6_
  
  - [ ] 11.3 Write property test for upgrade card count
    - **Property 20: Upgrade Card Count**
    - **Validates: Requirements 6.1**
  
  - [ ] 11.4 Write property test for new ability availability
    - **Property 21: New Ability Availability**
    - **Validates: Requirements 6.3**
  
  - [ ] 11.5 Write property test for tier upgrade availability
    - **Property 22: Tier Upgrade Availability**
    - **Validates: Requirements 6.4**
  
  - [ ] 11.6 Write property test for upgrade application
    - **Property 23: Upgrade Application**
    - **Validates: Requirements 6.5, 6.6, 6.7**

- [ ] 12. Checkpoint - Core systems complete
  - Ensure all entity and system tests pass
  - Verify object pooling works correctly for walkers, projectiles, XP orbs
  - Test system integration (spawning → movement → collision → defeat → XP)
  - Ask the user if questions arise

- [ ] 13. Implement Game State Model
  - [ ] 13.1 Create game_state module
    - Implement game_state.initialize() with initial state
    - Add properties: state ("playing", "paused", "game_over"), startTime, elapsedTime, enemiesDefeated, finalLevel, victoryCondition
    - Implement game_state.pause() and game_state.resume()
    - Implement game_state.endGame(victory) to set final statistics
    - Implement game_state.getStatistics() to return game stats
    - _Requirements: 7.1, 7.2, 7.4, 7.7_
  
  - [ ] 13.2 Write unit tests for Game State Model
    - Test initial state values
    - Test pause/resume state transitions
    - Test endGame sets correct statistics
    - _Requirements: 7.1, 7.4, 7.7_
  
  - [ ] 13.3 Write property test for elapsed time increases
    - **Property 33: Elapsed Time Increases**
    - **Validates: Requirements 7.2**


- [ ] 14. Implement Ability Registry
  - [ ] 14.1 Create ability_registry module
    - Define abilities table with Arcane Bolt entry
    - Implement ability_registry.getAbility(id) to retrieve ability definition
    - Implement ability_registry.createInstance(id) to instantiate ability
    - Implement ability_registry.isUnlocked(id) to check availability
    - _Requirements: 2.1, 6.2_
  
  - [ ] 14.2 Write unit tests for Ability Registry
    - Test getAbility returns correct definition
    - Test createInstance creates new ability instance
    - Test isUnlocked checks unlock status
    - _Requirements: 2.1, 6.2_

- [ ] 15. Implement Game Controller
  - [ ] 15.1 Create game_controller module
    - Implement game_controller.initialize(sceneGroup) to set up game session
    - Create hero entity at fixed position (360, 1180)
    - Initialize all object pools (walkers, projectiles, XP orbs)
    - Initialize all systems (combat, spawner, level, upgrade, collision)
    - Implement game_controller.start() to begin game loop
    - Implement game_controller.update(event) as enterFrame listener
    - Coordinate system updates in correct order: spawner → entities → collision → combat → level
    - Implement game_controller.pause() and game_controller.resume()
    - Implement game_controller.onLevelUp() to pause and show upgrade UI
    - Implement game_controller.onUpgradeSelected(upgrade) to apply and resume
    - Implement game_controller.onGameOver() to transition to game over scene
    - Implement game_controller.cleanup() for resource cleanup
    - _Requirements: 7.1, 7.3, 7.4, 7.5, 7.6, 12.1_
  
  - [ ] 15.2 Write integration tests for Game Controller
    - Test game initialization creates all entities and systems
    - Test game loop updates all systems in correct order
    - Test pause/resume during upgrade selection
    - Test game over on hero death
    - Test cleanup removes all listeners and timers
    - _Requirements: 7.1, 7.3, 7.4, 7.5, 7.6_
  
  - [ ] 15.3 Write property test for game over on hero death
    - **Property 2: Game Over on Hero Death**
    - **Validates: Requirements 1.5, 7.6**
  
  - [ ] 15.4 Write property test for spawning continues throughout session
    - **Property 32: Spawning Continues Throughout Session**
    - **Validates: Requirements 3.1**

- [ ] 16. Implement UI Components
  - [ ] 16.1 Create HealthBar UI component
    - Implement HealthBar:initialize(x, y, width, height) with display objects
    - Implement HealthBar:update(current, max) to update fill ratio
    - Add background and foreground rectangles
    - _Requirements: 10.1_
  
  - [ ] 16.2 Create XPBar UI component
    - Implement XPBar:initialize(x, y, width, height) with display objects
    - Implement XPBar:update(current, required) to update fill ratio
    - Add background and foreground rectangles
    - _Requirements: 10.3_
  
  - [ ] 16.3 Create AbilityIndicator UI component
    - Implement AbilityIndicator:initialize(x, y, slotIndex) with display objects
    - Implement AbilityIndicator:setAbility(ability) to show ability icon
    - Implement AbilityIndicator:updateCooldown(remaining, total) to show cooldown overlay
    - _Requirements: 10.6, 10.7_
  
  - [ ] 16.4 Create UpgradeCard UI component
    - Implement UpgradeCard:initialize(x, y, upgradeData) with display objects
    - Display upgrade name, description, and icon
    - Implement UpgradeCard:onTap(callback) for selection
    - Add visual feedback on tap
    - _Requirements: 6.1, 6.8_
  
  - [ ] 16.5 Write unit tests for UI components
    - Test HealthBar displays correct fill ratio
    - Test XPBar displays correct fill ratio
    - Test AbilityIndicator shows correct ability and cooldown
    - Test UpgradeCard displays correct data and handles tap
    - _Requirements: 10.1, 10.3, 10.6, 10.7, 6.8_
  
  - [ ] 16.6 Write property test for health bar accuracy
    - **Property 25: Health Bar Accuracy**
    - **Validates: Requirements 10.1**
  
  - [ ] 16.7 Write property test for XP bar accuracy
    - **Property 26: XP Bar Accuracy**
    - **Validates: Requirements 10.3**
  
  - [ ] 16.8 Write property test for ability indicator synchronization
    - **Property 29: Ability Indicator Synchronization**
    - **Validates: Requirements 10.6, 10.7**


- [ ] 17. Implement Menu Scene
  - [ ] 17.1 Create menu scene with Composer
    - Implement scene:create(event) to build menu UI
    - Add title text, play button, settings button (placeholder)
    - Add display objects to sceneGroup
    - Implement scene:show(event) to add button listeners in "did" phase
    - Implement scene:hide(event) to remove listeners in "will" phase
    - Implement scene:destroy(event) for cleanup
    - Add play button tap handler to transition to game scene
    - _Requirements: 9.1, 9.2, 11.1, 11.2_
  
  - [ ] 17.2 Write unit tests for Menu Scene
    - Test scene:create builds UI correctly
    - Test play button transitions to game scene
    - Test scene lifecycle cleanup
    - _Requirements: 9.1, 9.2, 11.1_

- [ ] 18. Implement Game Scene
  - [ ] 18.1 Create game scene with Composer
    - Implement scene:create(event) to initialize game controller
    - Create background display object
    - Initialize UI layer (health bar, XP bar, level display, time display, enemy count, ability indicators)
    - Add all display objects to sceneGroup
    - Implement scene:show(event) to start game controller in "did" phase
    - Implement scene:hide(event) to pause game and stop controller in "will" phase
    - Implement scene:destroy(event) to cleanup game controller and UI
    - _Requirements: 7.1, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 11.3, 11.4_
  
  - [ ] 18.2 Add upgrade UI overlay to game scene
    - Create upgrade panel that appears on level-up
    - Display 3 upgrade cards using UpgradeCard component
    - Implement card selection handler to apply upgrade and resume game
    - Hide upgrade panel after selection
    - _Requirements: 6.1, 6.8, 7.4_
  
  - [ ] 18.3 Add UI update logic to game scene
    - Update health bar every frame with hero health
    - Update XP bar every frame with hero XP
    - Update level display text with hero level
    - Update time display text with formatted elapsed time (MM:SS)
    - Update enemy count display with active walker count
    - Update ability indicators with cooldown states
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7_
  
  - [ ] 18.4 Write integration tests for Game Scene
    - Test scene initialization creates game controller
    - Test UI updates reflect game state
    - Test upgrade panel appears on level-up
    - Test scene cleanup on hide/destroy
    - _Requirements: 7.1, 10.1, 10.3, 11.3_
  
  - [ ] 18.5 Write property test for time display format
    - **Property 27: Time Display Format**
    - **Validates: Requirements 10.4**
  
  - [ ] 18.6 Write property test for enemy defeat counter
    - **Property 28: Enemy Defeat Counter**
    - **Validates: Requirements 10.5**
  
  - [ ] 18.7 Write property test for scene cleanup on hide
    - **Property 30: Scene Cleanup on Hide**
    - **Validates: Requirements 11.5**

- [ ] 19. Implement Game Over Scene
  - [ ] 19.1 Create gameover scene with Composer
    - Implement scene:create(event) to build game over UI
    - Display "Game Over" title
    - Display statistics: survival time, enemies defeated, final level
    - Add "Play Again" button and "Main Menu" button
    - Add all display objects to sceneGroup
    - Implement scene:show(event) to receive game statistics via event.params
    - Implement scene:hide(event) to remove listeners
    - Implement scene:destroy(event) for cleanup
    - Add button handlers to transition to game or menu scene
    - _Requirements: 7.7, 9.3, 9.4, 11.1, 11.2_
  
  - [ ] 19.2 Write unit tests for Game Over Scene
    - Test scene displays correct statistics
    - Test "Play Again" transitions to game scene
    - Test "Main Menu" transitions to menu scene
    - Test scene lifecycle cleanup
    - _Requirements: 7.7, 9.3, 9.4, 11.1_
  
  - [ ] 19.3 Write property test for game over statistics
    - **Property 31: Game Over Statistics**
    - **Validates: Requirements 7.7**


- [ ] 20. Checkpoint - Scenes and UI complete
  - Ensure all scenes transition correctly (menu → game → gameover)
  - Verify UI components display and update correctly
  - Test upgrade selection flow (level-up → pause → select → resume)
  - Test game over flow (hero death → statistics → scene transition)
  - Ask the user if questions arise

- [ ] 21. Implement persistent data integration
  - [ ] 21.1 Update game over scene to save statistics
    - Use src/models/data.lua to update persistent stats
    - Increment stats.gamesPlayed
    - Update stats.highestLevel if current level is higher
    - Update stats.longestSurvival if current time is longer
    - Add stats.totalEnemiesDefeated
    - Call data.save() to persist changes
    - _Requirements: 7.7_
  
  - [ ] 21.2 Write unit tests for persistent data integration
    - Test statistics are saved correctly on game over
    - Test high scores are updated appropriately
    - _Requirements: 7.7_

- [ ] 22. Add visual assets and polish
  - [ ] 22.1 Create placeholder visual assets
    - Create hero sprite (simple colored circle or square)
    - Create walker sprite (different colored shape)
    - Create projectile sprite (small circle)
    - Create XP orb sprite (glowing circle)
    - Create background image (simple gradient or solid color)
    - Place assets in assets/images/ directory
    - _Requirements: 1.1, 4.1, 2.4, 5.1_
  
  - [ ] 22.2 Integrate visual assets into entities
    - Update Hero:initialize() to use display.newImageRect with hero sprite
    - Update Walker:initialize() to use display.newImageRect with walker sprite
    - Update Projectile:initialize() to use display.newCircle or sprite
    - Update XPOrb:initialize() to use display.newCircle or sprite
    - Update game scene to use background image
    - Ensure all display objects are added to sceneGroup
    - _Requirements: 1.1, 4.1, 2.4, 5.1_
  
  - [ ] 22.3 Add upgrade card icons
    - Create simple icons for each upgrade type (5 icons total)
    - Place icons in assets/images/upgrades/ directory
    - Update upgrade_system upgrade definitions to reference icon paths
    - Update UpgradeCard component to display icons
    - _Requirements: 6.1, 6.8_

- [ ] 23. Implement error handling and edge cases
  - [ ] 23.1 Add error handling to combat system
    - Check enemies array length before targeting (skip if empty)
    - Validate damage values (clamp to minimum 0)
    - Check projectile bounds (deactivate if > 200px off-screen)
    - Add pcall wrappers for critical operations
    - _Requirements: 2.1, 2.5, 2.6, 12.5_
  
  - [ ] 23.2 Add error handling to spawner system
    - Check activeWalkers count before spawning (enforce 50 limit)
    - Clamp spawn X position to valid range [50, 670]
    - Handle pool exhaustion gracefully
    - _Requirements: 3.7, 3.9, 12.2_
  
  - [ ] 23.3 Add error handling to level system
    - Validate XP amount is positive before adding
    - Clamp XP to reasonable maximum (999999)
    - Check game state before pausing for level-up
    - _Requirements: 5.3, 5.5_
  
  - [ ] 23.4 Add error handling to upgrade system
    - Check ability tier < 5 before upgrading
    - Check abilities.length < 5 before adding new ability
    - Provide fallback upgrades if pool is empty
    - _Requirements: 6.5, 6.6_
  
  - [ ] 23.5 Add error handling to collision system
    - Validate entity positions are valid numbers before distance calculation
    - Check entity references are not nil before accessing properties
    - Skip invalid collision pairs
    - _Requirements: 8.1, 8.2, 8.3_


- [ ] 24. Implement remaining correctness properties as tests
  - [ ] 24.1 Write property test for ability slot limit
    - **Property 1: Ability Slot Limit**
    - **Validates: Requirements 1.7, 2.9**
  
  - [ ] 24.2 Write property test for walker melee damage
    - **Property 12: Walker Melee Damage**
    - **Validates: Requirements 4.2**
  
  - [ ] 24.3 Write property test for walker defeat spawns XP
    - **Property 13: Walker Defeat Spawns XP**
    - **Validates: Requirements 4.5**

- [ ] 25. Performance optimization and testing
  - [ ] 25.1 Test performance with 30 concurrent walkers
    - Run game session with spawner configured for high spawn rate
    - Monitor FPS using display.fps in game scene
    - Verify FPS stays at or near 60 with 30 active walkers
    - Profile object pool efficiency (no memory growth over 5 minutes)
    - _Requirements: 12.4_
  
  - [ ] 25.2 Optimize if performance issues found
    - Review entity update loops for inefficiencies
    - Optimize collision detection (spatial partitioning if needed)
    - Reduce display object complexity if needed
    - Consider reducing visual effects or particle counts
    - _Requirements: 12.4_

- [ ] 26. Final integration and end-to-end testing
  - [ ] 26.1 Run full game session test
    - Start from menu scene
    - Play through multiple level-ups
    - Select various upgrades
    - Verify all systems work together correctly
    - Let hero die and verify game over flow
    - Check statistics are displayed and saved
    - Return to menu and start new game
    - _Requirements: All_
  
  - [ ] 26.2 Test edge cases and boundary conditions
    - Test with no enemies (abilities should not activate)
    - Test with maximum walkers (50 limit enforced)
    - Test with all 5 ability slots filled
    - Test with ability at max tier (5)
    - Test XP orb lifetime expiration
    - Test projectile off-screen removal
    - _Requirements: 2.1, 3.9, 6.6, 5.1, 2.6_
  
  - [ ] 26.3 Verify all property tests pass
    - Run full property test suite with 100 iterations
    - Verify all 33 properties pass
    - Fix any failing properties
    - Document any edge cases discovered
    - _Requirements: All_

- [ ] 27. Final checkpoint - MVP complete
  - Ensure all core features are implemented and working
  - Verify all unit tests and property tests pass
  - Confirm performance meets 60 FPS target
  - Test on Solar2D simulator
  - Document any known issues or limitations
  - Ask the user if questions arise

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP delivery
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation and provide opportunities for user feedback
- Property tests validate universal correctness properties across all inputs
- Unit tests validate specific examples, edge cases, and integration points
- The implementation follows a bottom-up approach: entities → systems → controller → scenes → UI
- Object pooling is used for all frequently spawned entities (walkers, projectiles, XP orbs)
- All display objects must be added to sceneGroup for proper memory management
- Scene lifecycle methods (create, show, hide, destroy) must be implemented correctly
- Error handling is integrated throughout to ensure robust gameplay

## Implementation Order Rationale

1. **Entities First**: Core game objects (hero, walker, projectile, XP orb) are foundational
2. **Abilities Next**: Arcane Bolt ability depends on projectile entity
3. **Systems Layer**: Combat, spawner, level, collision, and upgrade systems orchestrate entities
4. **Game Controller**: Coordinates all systems and manages game loop
5. **UI Components**: Visual feedback for game state
6. **Scenes**: Composer scenes tie everything together with proper lifecycle management
7. **Polish and Testing**: Visual assets, error handling, performance optimization, comprehensive testing

This order ensures each component can be tested independently before integration, reducing debugging complexity and enabling incremental progress validation.
