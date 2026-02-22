# Requirements Document

## Introduction

Arcane Survivor MVP is a hero-centric roguelike tower-defense action game for mobile platforms built with Solar2D and Lua. The hero defends from a stationary position on a defensive wall at the bottom center of the screen while enemies advance from the top and sides. The MVP delivers a level-based survival experience featuring one playable hero (Arcane Wanderer), one enemy type (Walker), automatic combat with multiple ability slots, XP-based progression, and a randomized upgrade system. The game uses portrait orientation (720x1280 base resolution) with no movement controls—gameplay focuses entirely on ability selection and upgrades.

## Glossary

- **Game_System**: The complete Arcane Survivor game application
- **Hero**: The stationary player character positioned on the defensive wall (Arcane Wanderer in MVP)
- **Defensive_Wall**: The fixed position at the bottom center of the screen where the Hero defends
- **Lane**: A narrow vertical path from the top of the screen to the Defensive_Wall where enemies advance in straight lines
- **Walker**: Basic melee enemy that advances toward the Defensive_Wall
- **Ability**: An active attack or effect that the Hero can use (up to 5 active abilities)
- **Arcane_Bolt**: The hero's default automatic projectile attack ability
- **Ability_Slot**: One of five slots that can hold an active ability
- **Upgrade_Tier**: A level of improvement for an ability (1-5 tiers per ability)
- **XP_Orb**: Collectible experience point dropped by defeated enemies
- **Upgrade_Card**: A selectable new ability or ability upgrade offered at level-up
- **Game_Session**: A single level-based survival run from start to game over
- **Combat_System**: The subsystem managing abilities, attacks, damage, and enemy defeat
- **Spawner_System**: The subsystem managing enemy wave generation
- **Level_System**: The subsystem managing XP accumulation and level-ups
- **Upgrade_System**: The subsystem managing upgrade card selection and application
- **Collision_System**: The subsystem detecting entity interactions
- **Object_Pool**: A reusable collection of game entities for memory efficiency

## Requirements

### Requirement 1: Hero Character

**User Story:** As a player, I want the Arcane Wanderer hero to defend from a fixed position, so that I can focus on ability selection and strategic upgrades.

#### Acceptance Criteria

1. THE Game_System SHALL create one Hero instance at the start of each Game_Session
2. THE Hero SHALL have a base health value of 100 hit points
3. THE Hero SHALL be positioned at the bottom center of the screen on the Defensive_Wall
4. THE Hero position SHALL remain fixed throughout the Game_Session
5. WHEN the Hero health reaches zero, THE Game_System SHALL end the Game_Session
6. THE Hero SHALL be visually represented as a distinct silhouette with glowing accents
7. THE Hero SHALL support up to 5 active Ability_Slots

### Requirement 2: Automatic Combat

**User Story:** As a player, I want the hero to automatically use abilities, so that I can focus on strategic upgrade choices rather than manual combat.

#### Acceptance Criteria

1. THE Hero SHALL start each Game_Session with one Ability in the first Ability_Slot (Arcane_Bolt)
2. THE Combat_System SHALL automatically activate each Ability according to its cooldown timer
3. WHEN Arcane_Bolt is activated, THE Combat_System SHALL fire one projectile toward the nearest Walker to the Hero
4. THE Arcane_Bolt SHALL travel at 400 pixels per second toward the target position
5. THE Arcane_Bolt SHALL deal 10 damage to a Walker on collision
6. WHEN an Arcane_Bolt collides with a Walker or travels beyond the game area, THE Combat_System SHALL remove the Arcane_Bolt from the game
7. WHERE no Walker exists in the game area, THE Combat_System SHALL not activate targeting abilities
8. THE Combat_System SHALL manage cooldowns independently for each active Ability
9. THE Hero SHALL be able to have up to 5 active abilities simultaneously

### Requirement 3: Enemy Spawning

**User Story:** As a player, I want enemies to spawn in increasing waves from the top, so that the game becomes progressively challenging.

#### Acceptance Criteria

1. THE Spawner_System SHALL spawn Walker enemies at intervals throughout the Game_Session
2. WHEN the Game_Session starts, THE Spawner_System SHALL spawn 3 Walkers within 2 seconds
3. WHILE the Hero level is less than 5, THE Spawner_System SHALL spawn 1 Walker every 3 seconds
4. WHILE the Hero level is between 5 and 10, THE Spawner_System SHALL spawn 2 Walkers every 3 seconds
5. WHILE the Hero level is between 10 and 15, THE Spawner_System SHALL spawn 3 Walkers every 2 seconds
6. WHILE the Hero level is 15 or greater, THE Spawner_System SHALL spawn 4 Walkers every 2 seconds
7. THE Spawner_System SHALL spawn each Walker at a random position along the top edge of the screen
8. WHEN a Walker is spawned, THE Spawner_System SHALL assign the Walker to a Lane based on its spawn position
9. THE Spawner_System SHALL limit the maximum concurrent Walker count to 50 entities

### Requirement 4: Enemy Behavior

**User Story:** As a player, I want enemies to advance down lanes toward my defensive position and attack, so that I must build effective ability combinations to survive.

#### Acceptance Criteria

1. THE Walker SHALL move down its assigned Lane in a straight vertical line toward the Defensive_Wall at 80 pixels per second
2. WHILE the Walker is within 30 pixels of the Hero at the Defensive_Wall, THE Walker SHALL deal 5 damage to the Hero every 1.0 seconds
3. THE Walker SHALL have 20 hit points
4. WHEN the Walker health reaches zero, THE Combat_System SHALL remove the Walker from the game
5. WHEN a Walker is removed from the game, THE Combat_System SHALL spawn one XP_Orb at the Walker position
6. THE Walker SHALL be visually represented as a distinct silhouette contrasting with the Hero

### Requirement 5: Experience and Leveling

**User Story:** As a player, I want to collect XP and level up, so that I can gain new abilities and upgrades to become stronger.

#### Acceptance Criteria

1. THE XP_Orb SHALL remain at its spawn position for 30 seconds before disappearing
2. WHEN the Hero is within 40 pixels of an XP_Orb, THE Level_System SHALL automatically collect the XP_Orb and add 10 XP to the Hero total
3. THE Level_System SHALL require 100 XP for the Hero to reach level 2
4. THE Level_System SHALL increase the XP requirement by 20 XP for each subsequent level
5. WHEN the Hero accumulates sufficient XP for the next level, THE Level_System SHALL increment the Hero level by 1
6. WHEN the Hero level increases, THE Game_System SHALL pause the game and display the upgrade selection interface

### Requirement 6: Upgrade System

**User Story:** As a player, I want to choose from random upgrades when I level up, so that I can build unique ability combinations and customize my strategy.

#### Acceptance Criteria

1. WHEN the upgrade selection interface is displayed, THE Upgrade_System SHALL present 3 randomly selected Upgrade_Cards
2. THE Upgrade_System SHALL include at least 5 distinct upgrade options in the available pool for the MVP
3. WHERE the Hero has fewer than 5 active abilities, THE Upgrade_System SHALL offer new Ability options in the Upgrade_Cards
4. WHERE the Hero has one or more active abilities, THE Upgrade_System SHALL offer Upgrade_Tier improvements for existing abilities in the Upgrade_Cards
5. WHEN the player selects an Upgrade_Card for a new Ability, THE Upgrade_System SHALL add the Ability to an available Ability_Slot
6. WHEN the player selects an Upgrade_Card for an existing Ability, THE Upgrade_System SHALL increment the Upgrade_Tier for that Ability (maximum 5 tiers)
7. WHEN an upgrade is applied, THE Game_System SHALL resume the game
8. THE Upgrade_System SHALL include upgrade options for: Arcane_Bolt damage increase, Arcane_Bolt attack speed increase, Arcane_Bolt projectile count increase, Arcane_Bolt pierce ability, and XP_Orb pickup radius increase

### Requirement 7: Game Session Management

**User Story:** As a player, I want clear game start and end conditions based on level progression, so that I understand when a run begins and concludes.

#### Acceptance Criteria

1. WHEN the player starts a new game, THE Game_System SHALL initialize a Game_Session with the Hero at level 1
2. WHILE the Game_Session is active, THE Game_System SHALL display the elapsed time in seconds
3. WHILE the Game_Session is active, THE Game_System SHALL display the current Hero level
4. WHEN the Hero reaches level 20, THE Game_System SHALL spawn a final boss enemy
5. WHEN the final boss is defeated, THE Game_System SHALL end the Game_Session with a victory condition
6. WHEN the Hero health reaches zero, THE Game_System SHALL end the Game_Session with a defeat condition
7. WHEN a Game_Session ends, THE Game_System SHALL display the final statistics including: survival time, enemies defeated, and final Hero level
8. WHEN a Game_Session ends, THE Game_System SHALL provide options to restart or return to the main menu

### Requirement 8: Collision Detection

**User Story:** As a developer, I want accurate collision detection, so that combat and collection mechanics function correctly.

#### Acceptance Criteria

1. THE Collision_System SHALL detect collisions between Arcane_Bolts and Walkers using distance-based detection
2. THE Collision_System SHALL detect collisions between the Hero and XP_Orbs using distance-based detection with the Hero pickup radius
3. THE Collision_System SHALL detect proximity between the Hero and Walkers for melee damage using distance-based detection
4. THE Collision_System SHALL detect collisions between any active Ability projectiles and Walkers
5. THE Collision_System SHALL check for collisions every frame during the game update loop
6. WHEN a collision is detected, THE Collision_System SHALL notify the relevant game systems to apply effects

### Requirement 9: Object Pooling

**User Story:** As a developer, I want efficient memory management for frequently created entities, so that the game performs smoothly on mobile devices.

#### Acceptance Criteria

1. THE Game_System SHALL use Object_Pools for Walker entities
2. THE Game_System SHALL use Object_Pools for Arcane_Bolt entities
3. THE Game_System SHALL use Object_Pools for XP_Orb entities
4. THE Game_System SHALL use Object_Pools for all Ability projectile entities
5. WHEN an entity is removed from the game, THE Game_System SHALL return the entity to its Object_Pool for reuse
6. WHEN an entity is needed, THE Game_System SHALL retrieve an available entity from the Object_Pool or create a new one if the pool is empty

### Requirement 10: User Interface

**User Story:** As a player, I want clear visual feedback on my status and abilities, so that I can make informed decisions during gameplay.

#### Acceptance Criteria

1. THE Game_System SHALL display the Hero current health and maximum health as a health bar
2. THE Game_System SHALL display the Hero current level as a numeric value
3. THE Game_System SHALL display the Hero current XP and XP required for next level as a progress bar
4. THE Game_System SHALL display the Game_Session elapsed time in MM:SS format
5. THE Game_System SHALL display the current count of defeated enemies
6. THE Game_System SHALL display visual indicators for each active Ability_Slot showing which abilities are equipped
7. THE Game_System SHALL display cooldown timers for each active Ability
8. WHEN the Hero takes damage, THE Game_System SHALL provide visual feedback through screen shake or flash effects

### Requirement 11: Scene Management

**User Story:** As a player, I want smooth transitions between menu and gameplay, so that the game feels polished and responsive.

#### Acceptance Criteria

1. THE Game_System SHALL implement a main menu scene using the Composer library
2. THE Game_System SHALL implement a gameplay scene using the Composer library
3. THE Game_System SHALL implement a game over scene using the Composer library
4. WHEN transitioning between scenes, THE Game_System SHALL properly clean up resources from the previous scene
5. WHEN the gameplay scene is hidden, THE Game_System SHALL cancel all active timers and transitions
6. WHEN the gameplay scene is destroyed, THE Game_System SHALL remove all event listeners and nil large object references

### Requirement 12: Performance Optimization

**User Story:** As a developer, I want the game to run at 60 FPS on target mobile devices, so that players have a smooth experience.

#### Acceptance Criteria

1. THE Game_System SHALL maintain 60 frames per second during typical gameplay with 30 concurrent Walkers
2. THE Game_System SHALL limit the maximum concurrent Walker count to prevent performance degradation
3. THE Game_System SHALL use the existing project object pooling utilities for entity management
4. THE Game_System SHALL batch display object updates within the game loop
5. THE Game_System SHALL remove off-screen entities that are beyond 200 pixels from the game area boundaries
