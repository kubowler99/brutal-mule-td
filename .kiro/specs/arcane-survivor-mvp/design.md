# Design Document: Arcane Survivor MVP

## Overview

Arcane Survivor MVP is a lane-based tower defense roguelike built on Solar2D with Lua 5.1. The game features a stationary hero defending from the bottom center of the screen against waves of enemies advancing down vertical lanes from the top. The core gameplay loop centers on automatic combat with up to 5 active abilities, XP-based progression, and strategic upgrade selection at level-up.

The design leverages the existing Solar2D project template architecture with Composer scene management, middleclass OOP system with Stateful state machines, and established utility modules for pooling, data persistence, and helper functions. The game targets portrait orientation (720x1280 base resolution) with 60 FPS performance on mobile devices.

### Core Design Principles

1. **Automatic Combat**: All abilities auto-fire based on cooldown timers, removing manual aiming/firing controls
2. **Stationary Hero**: Hero position is fixed at bottom center, focusing gameplay on ability selection rather than movement
3. **Lane-Based Movement**: Enemies advance in straight vertical lines from spawn position to defensive wall
4. **Object Pooling**: All frequently spawned entities (walkers, projectiles, XP orbs) use pooling for memory efficiency
5. **Distance-Based Collision**: Simple distance calculations for all collision detection (no physics engine)
6. **Level-Based Progression**: XP collection triggers level-ups which pause gameplay for upgrade selection

## Architecture

### High-Level System Architecture

``` text
┌─────────────────────────────────────────────────────────────┐
│                        Main Entry                           │
│                       (main.lua)                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Scene Management                         │
│                   (Composer Library)                        │
│    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│    │ Menu Scene   │  │ Game Scene   │  │GameOver Scene│     │
│    └──────────────┘  └──────┬───────┘  └──────────────┘     │
└─────────────────────────────┼───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Game Controller                          │
│              (src/controllers/game_controller.lua)          │
│                                                             │
│  • Orchestrates game loop (enterFrame)                      │
│  • Manages game state (playing, paused, game_over)          │
│  • Coordinates system updates                               │
│  • Handles scene lifecycle                                  │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┬──────────────┐
         ▼               ▼               ▼              ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│Combat System│  │Spawner Sys  │  │Level System │  │Collision Sys│
│             │  │             │  │             │  │             │
│• Ability    │  │• Wave       │  │• XP         │  │• Distance   │
│  activation │  │  generation │  │  tracking   │  │  checks     │
│• Cooldowns  │  │• Enemy      │  │• Level-up   │  │• Proximity  │
│• Targeting  │  │  spawning   │  │  triggers   │  │  detection  │
│• Damage     │  │• Difficulty │  │• XP orb     │  │• Collision  │
│  application│  │  scaling    │  │  collection │  │  response   │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │                │
       └────────────────┼────────────────┼────────────────┘
                        │                │
                        ▼                ▼
              ┌─────────────────────────────────┐
              │      Upgrade System             │
              │                                 │
              │  • Card generation              │
              │  • Ability unlocking            │
              │  • Tier upgrades                │
              │  • Slot management              │
              └─────────────────────────────────┘
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Entities  │  │Object Pools │  │  UI Layer   │
│             │  │             │  │             │
│• Hero       │  │• Walker     │  │• Health bar │
│• Walker     │  │  pool       │  │• XP bar     │
│• Arcane Bolt│  │• Projectile │  │• Level      │
│• XP Orb     │  │  pool       │  │  display    │
│             │  │• XP orb     │  │• Ability    │
│             │  │  pool       │  │  indicators │
└─────────────┘  └─────────────┘  └─────────────┘
```

### System Responsibilities

**Game Controller** (`src/controllers/game_controller.lua`)

- Owns the main game loop via Runtime:addEventListener("enterFrame")
- Manages game state transitions (playing, paused, game_over)
- Coordinates updates across all systems in correct order
- Handles pause/resume for upgrade selection
- Manages scene lifecycle integration

**Combat System** (`src/systems/combat_system.lua`)

- Tracks active abilities and their cooldown timers
- Executes ability activation logic (targeting, projectile creation)
- Applies damage to entities on collision
- Handles entity defeat and removal
- Manages ability slot assignments (up to 5 slots)

**Spawner System** (`src/systems/spawner_system.lua`)

- Generates enemy waves based on elapsed time and hero level
- Scales spawn rate and count according to difficulty curve
- Assigns lanes to spawned enemies based on spawn position
- Enforces maximum concurrent enemy limit (50)
- Retrieves enemies from object pool

**Level System** (`src/systems/level_system.lua`)

- Tracks hero XP accumulation
- Calculates XP requirements per level (100 + 20 * (level - 1))
- Triggers level-up events
- Manages XP orb spawning on enemy defeat
- Handles XP orb collection via proximity detection

**Collision System** (`src/systems/collision_system.lua`)

- Performs distance-based collision checks every frame
- Detects projectile-enemy collisions
- Detects hero-XP orb proximity for collection
- Detects hero-enemy proximity for melee damage
- Notifies relevant systems of collision events

**Upgrade System** (`src/systems/upgrade_system.lua`)

- Generates 3 random upgrade cards at level-up
- Manages upgrade pool (new abilities + tier upgrades)
- Applies selected upgrades to hero abilities
- Tracks ability tiers (1-5 per ability)
- Manages ability slot allocation

### Data Flow

1. **Game Loop**: Game controller calls update() on all systems each frame
2. **Spawning**: Spawner system creates enemies → retrieves from pool → positions in lanes
3. **Movement**: Entities update positions based on velocity and dt
4. **Collision**: Collision system checks distances → notifies combat/level systems
5. **Combat**: Combat system activates abilities → creates projectiles → applies damage
6. **Defeat**: Enemy defeated → spawns XP orb → returns enemy to pool
7. **Collection**: Hero proximity to XP orb → adds XP → checks for level-up
8. **Level-Up**: Pause game → upgrade system generates cards → player selects → resume game

## Components and Interfaces

### Hero Entity

**File**: `src/entities/hero.lua`

**Class**: `Hero` (extends middleclass)

**Properties**:

```lua
{
  displayObject = display.newImageRect(...),  -- Visual representation
  x = 360,                                     -- Fixed X position (center)
  y = 1180,                                    -- Fixed Y position (near bottom)
  health = 100,                                -- Current health
  maxHealth = 100,                             -- Maximum health
  level = 1,                                   -- Current level
  xp = 0,                                      -- Current XP
  xpRequired = 100,                            -- XP needed for next level
  abilities = {},                              -- Array of active abilities (max 5)
  pickupRadius = 40,                           -- XP collection radius
  isAlive = true                               -- Alive state
}
```

**Methods**:

```lua
function Hero:initialize(x, y)
function Hero:takeDamage(amount)
function Hero:addAbility(ability)
function Hero:upgradeAbility(abilityId, tier)
function Hero:addXP(amount)
function Hero:levelUp()
function Hero:destroy()
```

**Interface**:

- Read-only position (x, y) for collision checks
- Public health for UI display and damage application
- Public abilities array for combat system iteration
- Public pickupRadius for XP collection range

### Walker Entity

**File**: `src/entities/walker.lua`

**Class**: `Walker` (extends middleclass)

**Properties**:

```lua
{
  displayObject = display.newImageRect(...),  -- Visual representation
  x = 0,                                       -- Current X position
  y = 0,                                       -- Current Y position
  lane = 0,                                    -- Assigned lane (X coordinate)
  health = 20,                                 -- Current health
  maxHealth = 20,                              -- Maximum health
  speed = 80,                                  -- Movement speed (pixels/sec)
  damage = 5,                                  -- Melee damage
  attackCooldown = 1.0,                        -- Time between attacks (seconds)
  lastAttackTime = 0,                          -- Timestamp of last attack
  isActive = false,                            -- Pool active state
  attackRange = 30                             -- Distance to hero for melee
}
```

**Methods**:

```lua
function Walker:initialize()
function Walker:activate(x, y, lane)         -- Called when retrieved from pool
function Walker:update(dt, heroX, heroY)     -- Movement and attack logic
function Walker:takeDamage(amount)
function Walker:deactivate()                 -- Called when returned to pool
function Walker:getDistance(x, y)            -- Helper for collision
```

**Interface**:

- activate/deactivate for object pooling
- update(dt, heroX, heroY) called each frame by game controller
- takeDamage(amount) called by combat system on collision
- Public x, y, isActive for collision system

### Arcane Bolt Ability

**File**: `src/entities/abilities/arcane_bolt.lua`

**Class**: `ArcaneBolt` (extends middleclass)

**Properties**:

```lua
{
  id = "arcane_bolt",                          -- Unique ability identifier
  name = "Arcane Bolt",                        -- Display name
  cooldown = 1.0,                              -- Base cooldown (seconds)
  lastActivation = 0,                          -- Timestamp of last activation
  damage = 10,                                 -- Base damage
  projectileSpeed = 400,                       -- Pixels per second
  tier = 1,                                    -- Current upgrade tier (1-5)
  pierceCount = 0,                             -- Number of enemies to pierce
  projectileCount = 1                          -- Number of projectiles per activation
}
```

**Methods**:

```lua
function ArcaneBolt:initialize()
function ArcaneBolt:canActivate(currentTime)
function ArcaneBolt:activate(heroX, heroY, enemies, projectilePool)
function ArcaneBolt:upgrade(upgradeType)     -- Apply tier upgrade
function ArcaneBolt:findNearestEnemy(heroX, heroY, enemies)
```

**Upgrade Types**:

- `damage_increase`: +5 damage per tier
- `attack_speed`: -0.15s cooldown per tier (min 0.25s)
- `projectile_count`: +1 projectile per tier
- `pierce`: +1 pierce count per tier

### Projectile Entity

**File**: `src/entities/projectile.lua`

**Class**: `Projectile` (extends middleclass)

**Properties**:

```lua
{
  displayObject = display.newCircle(...),      -- Visual representation
  x = 0,                                       -- Current X position
  y = 0,                                       -- Current Y position
  vx = 0,                                      -- X velocity
  vy = 0,                                      -- Y velocity
  damage = 0,                                  -- Damage on hit
  pierceCount = 0,                             -- Remaining pierce count
  isActive = false,                            -- Pool active state
  hitEnemies = {}                              -- Track pierced enemies
}
```

**Methods**:

```lua
function Projectile:initialize()
function Projectile:activate(x, y, targetX, targetY, speed, damage, pierce)
function Projectile:update(dt)
function Projectile:onHit(enemy)
function Projectile:deactivate()
function Projectile:isOffScreen()
```

### XP Orb Entity

**File**: `src/entities/xp_orb.lua`

**Class**: `XPOrb` (extends middleclass)

**Properties**:

```lua
{
  displayObject = display.newCircle(...),      -- Visual representation
  x = 0,                                       -- Current X position
  y = 0,                                       -- Current Y position
  xpValue = 10,                                -- XP granted on collection
  lifetime = 30,                               -- Seconds before despawn
  spawnTime = 0,                               -- Timestamp of spawn
  isActive = false                             -- Pool active state
}
```

**Methods**:

```lua
function XPOrb:initialize()
function XPOrb:activate(x, y)
function XPOrb:update(currentTime)           -- Check lifetime expiration
function XPOrb:collect()                     -- Called on hero proximity
function XPOrb:deactivate()
```

### Combat System

**File**: `src/systems/combat_system.lua`

**Module**: `combat_system` (table-based module)

**State**:

```lua
{
  hero = nil,                                  -- Reference to hero entity
  projectilePool = nil,                        -- Object pool for projectiles
  activeProjectiles = {},                      -- Array of active projectiles
  enemies = {}                                 -- Reference to active enemies array
}
```

**Interface**:

```lua
function combat_system.initialize(hero, projectilePool, enemies)
function combat_system.update(dt, currentTime)
function combat_system.activateAbilities(currentTime)
function combat_system.updateProjectiles(dt)
function combat_system.applyDamage(entity, amount)
function combat_system.cleanup()
```

**Update Flow**:

1. Iterate hero abilities, check cooldowns
2. Activate ready abilities (create projectiles, apply targeting)
3. Update all active projectiles (movement)
4. Check projectile-enemy collisions via collision system
5. Apply damage and handle defeats

### Spawner System

**File**: `src/systems/spawner_system.lua`

**Module**: `spawner_system` (table-based module)

**State**:

```lua
{
  walkerPool = nil,                            -- Object pool for walkers
  activeWalkers = {},                          -- Array of active walkers
  spawnTimer = 0,                              -- Accumulator for spawn intervals
  spawnInterval = 3.0,                         -- Current spawn interval (seconds)
  spawnCount = 1,                              -- Walkers per spawn
  maxConcurrent = 50,                          -- Maximum active walkers
  heroLevel = 1,                               -- Reference to hero level
  gameStartTime = 0                            -- For initial spawn burst
}
```

**Interface**:

```lua
function spawner_system.initialize(walkerPool, heroLevel)
function spawner_system.update(dt, currentTime)
function spawner_system.spawnWalker()
function spawner_system.updateDifficulty(heroLevel)
function spawner_system.getActiveWalkers()
function spawner_system.cleanup()
```

**Difficulty Scaling**:

```lua
-- Level < 5: 1 walker every 3 seconds
-- Level 5-10: 2 walkers every 3 seconds
-- Level 10-15: 3 walkers every 2 seconds
-- Level 15+: 4 walkers every 2 seconds
```

### Level System

**File**: `src/systems/level_system.lua`

**Module**: `level_system` (table-based module)

**State**:

```lua
{
  hero = nil,                                  -- Reference to hero entity
  xpOrbPool = nil,                             -- Object pool for XP orbs
  activeOrbs = {},                             -- Array of active XP orbs
  onLevelUp = nil                              -- Callback function
}
```

**Interface**:

```lua
function level_system.initialize(hero, xpOrbPool, onLevelUpCallback)
function level_system.update(dt, currentTime)
function level_system.spawnXPOrb(x, y)
function level_system.checkOrbCollection(heroX, heroY, heroRadius)
function level_system.addXP(amount)
function level_system.calculateXPRequired(level)
function level_system.cleanup()
```

**XP Formula**:

```lua
xpRequired = 100 + (level - 1) * 20
-- Level 1→2: 100 XP
-- Level 2→3: 120 XP
-- Level 3→4: 140 XP
-- etc.
```

### Collision System

**File**: `src/systems/collision_system.lua`

**Module**: `collision_system` (table-based module)

**Interface**:

```lua
function collision_system.checkDistance(x1, y1, x2, y2)
function collision_system.checkProjectileCollisions(projectiles, enemies)
function collision_system.checkXPCollection(hero, xpOrbs)
function collision_system.checkMeleeRange(hero, enemies)
```

**Distance Formula**:

```lua
distance = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
```

**Collision Thresholds**:

- Projectile-Enemy: 20 pixels (projectile radius + enemy radius)
- Hero-XP Orb: hero.pickupRadius (default 40, upgradeable)
- Hero-Enemy Melee: 30 pixels

### Upgrade System

**File**: `src/systems/upgrade_system.lua`

**Module**: `upgrade_system` (table-based module)

**State**:

```lua
{
  hero = nil,                                  -- Reference to hero entity
  upgradePool = {},                            -- Available upgrade definitions
  onUpgradeSelected = nil                      -- Callback to resume game
}
```

**Interface**:

```lua
function upgrade_system.initialize(hero, onUpgradeSelectedCallback)
function upgrade_system.generateCards(count)
function upgrade_system.applyUpgrade(upgradeCard)
function upgrade_system.canOfferNewAbility()
function upgrade_system.getAvailableUpgrades()
```

**Upgrade Card Structure**:

```lua
{
  id = "arcane_bolt_damage",                   -- Unique identifier
  type = "tier_upgrade",                       -- "new_ability" or "tier_upgrade"
  abilityId = "arcane_bolt",                   -- Target ability
  name = "Arcane Bolt Damage",                 -- Display name
  description = "+5 damage per bolt",          -- Display description
  icon = "assets/images/upgrades/bolt_dmg.png",
  apply = function(hero) ... end               -- Application logic
}
```

**MVP Upgrade Pool**:

1. Arcane Bolt Damage (+5 damage)
2. Arcane Bolt Attack Speed (-0.15s cooldown)
3. Arcane Bolt Projectile Count (+1 projectile)
4. Arcane Bolt Pierce (+1 pierce)
5. XP Pickup Radius (+20 pixels)

### Object Pools

**File**: `src/utils/pool.lua` (existing utility)

**Usage**:

```lua
local pool = require("src.utils.pool")

-- Create pools
local walkerPool = pool.create(Walker, 50)
local projectilePool = pool.create(Projectile, 100)
local xpOrbPool = pool.create(XPOrb, 100)

-- Retrieve from pool
local walker = walkerPool:get()
walker:activate(x, y, lane)

-- Return to pool
walker:deactivate()
walkerPool:release(walker)
```

### UI Components

**Health Bar** (`src/ui/health_bar.lua`)

```lua
function HealthBar:initialize(x, y, width, height)
function HealthBar:update(current, max)
```

**XP Bar** (`src/ui/xp_bar.lua`)

```lua
function XPBar:initialize(x, y, width, height)
function XPBar:update(current, required)
```

**Ability Indicator** (`src/ui/ability_indicator.lua`)

```lua
function AbilityIndicator:initialize(x, y, slotIndex)
function AbilityIndicator:setAbility(ability)
function AbilityIndicator:updateCooldown(remaining, total)
```

**Upgrade Card** (`src/ui/upgrade_card.lua`)

```lua
function UpgradeCard:initialize(x, y, upgradeData)
function UpgradeCard:onTap(callback)
```

## Data Models

### Game State Model

**File**: `src/models/game_state.lua`

**Structure**:

```lua
{
  state = "playing",                           -- "playing", "paused", "game_over"
  startTime = 0,                               -- Game session start timestamp
  elapsedTime = 0,                             -- Total elapsed seconds
  enemiesDefeated = 0,                         -- Kill count
  finalLevel = 0,                              -- Level at game over
  victoryCondition = false                     -- true if boss defeated
}
```

**Methods**:

```lua
function game_state.initialize()
function game_state.pause()
function game_state.resume()
function game_state.endGame(victory)
function game_state.getStatistics()
```

### Ability Registry

**File**: `src/models/ability_registry.lua`

**Structure**:

```lua
{
  abilities = {
    arcane_bolt = {
      class = ArcaneBolt,
      unlocked = true,
      maxTier = 5
    },
    -- Future abilities...
  }
}
```

**Methods**:

```lua
function ability_registry.getAbility(id)
function ability_registry.createInstance(id)
function ability_registry.isUnlocked(id)
```

### Persistent Data Schema

**File**: Uses existing `src/models/data.lua`

**Schema**:

```lua
{
  settings = {
    sound = {
      volume = 1.0,
      enabled = true
    },
    music = {
      volume = 0.7,
      enabled = true
    }
  },
  stats = {
    gamesPlayed = 0,
    highestLevel = 0,
    longestSurvival = 0,
    totalEnemiesDefeated = 0
  }
}
```

**Usage**:

```lua
local data = require("src.models.data")
data.set("stats.gamesPlayed", data.get("stats.gamesPlayed") + 1)
data.save()
```

### Lane System

**Conceptual Model** (no separate file, integrated into spawner)

Lanes are implicit based on X coordinates:

- Screen width: 720 pixels
- Lanes are continuous (not discrete slots)
- Walker spawns at random X position along top edge (y = 0)
- Walker's lane = its spawn X coordinate
- Walker moves straight down (constant X, decreasing Y)

**Lane Assignment**:

```lua
local spawnX = math.random(50, 670)  -- Avoid screen edges
local spawnY = 0
walker:activate(spawnX, spawnY, spawnX)  -- lane = spawnX
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all acceptance criteria, I identified the following redundancies:

- Requirements 1.7 and 2.9 both test the 5 ability slot limit → Combined into Property 1
- Requirements 1.5 and 7.6 both test game over on hero death → Combined into Property 2
- Requirements 7.3 and 10.2 both test level display → Combined into Property 18
- Requirements 3.9 and 12.2 both test 50 walker limit → Combined into Property 8
- Requirements 8.1 and 8.4 both test projectile-enemy collision → Combined into Property 24
- Spawn rate properties 3.3-3.6 can be combined into a single difficulty scaling property → Combined into Property 7

### Property 1: Ability Slot Limit

*For any* hero instaemain equal to the initial position (bottom center of screen).

**Validates: Requirements 1.4**

### Property 4: Ability Cooldown Independence

*For any* set of active abilities on the hero, activating one ability should not affect the cooldown timer or activation state of any other ability.

**Validates: Requirements 2.8**

### Property 5: Nearest Enemy Targeting

*For any* activation of Arcane Bolt when enemies exist, the projectile should be fired toward the enemy with the minimum distance to the hero.

**Validates: Requirements 2.3**

### Property 6: Projectile Velocity

*For any* Arcane Bolt projectile, its velocity magnitude should equal 400 pixels per second in the direction of the target.

**Validates: Requirements 2.4**

### Property 7: Spawn Rate Scaling

*For any* hero level L, the spawner system's spawn interval and count should match the difficulty curve: level < 5 spawns 1 walker every 3s, level 5-10 spawns 2 every 3s, level 10-15 spawns 3 every 2s, level 15+ spawns 4 every 2s.

**Validates: Requirements 3.3, 3.4, 3.5, 3.6**

### Property 8: Maximum Concurrent Enemies

*For any* point in time during gameplay, the number of active walkers should not exceed 50.

**Validates: Requirements 3.9, 12.2**

### Property 9: Walker Spawn Position

*For any* spawned walker, its Y coordinate should be at the top edge of the screen (y ≈ 0) and its X coordinate should be within the playable area bounds.

**Validates: Requirements 3.7**

### Property 10: Lane Assignment

*For any* spawned walker, its assigned lane value should equal its spawn X coordinate.

**Validates: Requirements 3.8**

### Property 11: Walker Vertical Movement

*For any* walker over any time interval dt, its Y position should decrease by 80 * dt pixels while its X position remains constant (vertical lane movement).

**Validates: Requirements 4.1**

### Property 12: Walker Melee Damage

*For any* walker within 30 pixels of the hero, the walker should deal 5 damage to the hero every 1.0 seconds while in range.

**Validates: Requirements 4.2**

### Property 13: Walker Defeat Spawns XP

*For any* walker that is defeated (health reaches zero), exactly one XP orb should spawn at the walker's position.

**Validates: Requirements 4.5**

### Property 14: Projectile Damage Application

*For any* collision between an Arcane Bolt projectile and a walker, the walker's health should decrease by the projectile's damage value.

**Validates: Requirements 2.5**

### Property 15: Projectile Removal on Collision

*For any* projectile that collides with an enemy or travels beyond the game area boundaries (200 pixels off-screen), the projectile should be deactivated and removed from active projectiles.

**Validates: Requirements 2.6, 12.5**

### Property 16: XP Orb Lifetime

*For any* XP orb, if not collected within 30 seconds of spawn time, the orb should despawn and be removed from the game.

**Validates: Requirements 5.1**

### Property 17: XP Collection on Proximity

*For any* XP orb within the hero's pickup radius, the orb should be collected, grant its XP value to the hero, and be removed from the game.

**Validates: Requirements 5.2**

### Property 18: XP Requirement Formula

*For any* hero level N, the XP required to reach level N+1 should equal 100 + (N - 1) * 20.

**Validates: Requirements 5.4**

### Property 19: Level-Up Trigger

*For any* hero with accumulated XP greater than or equal to the XP requirement, the hero's level should increment by 1 and the game should pause for upgrade selection.

**Validates: Requirements 5.5, 5.6**

### Property 20: Upgrade Card Count

*For any* level-up event, the upgrade system should present exactly 3 upgrade cards to the player.

**Validates: Requirements 6.1**

### Property 21: New Ability Availability

*For any* upgrade card generation when the hero has fewer than 5 active abilities, at least one of the 3 cards should offer a new ability option.

**Validates: Requirements 6.3**

### Property 22: Tier Upgrade Availability

*For any* upgrade card generation when the hero has one or more active abilities, at least one of the 3 cards should offer a tier upgrade for an existing ability.

**Validates: Requirements 6.4**

### Property 23: Upgrade Application

*For any* selected upgrade card, applying the upgrade should either add a new ability to an available slot or increment the tier of an existing ability (max tier 5), and the game should resume.

**Validates: Requirements 6.5, 6.6, 6.7**

### Property 24: Distance-Based Collision Detection

*For any* pair of entities (projectile-walker, hero-XP orb, hero-walker), when the distance between their centers is less than or equal to the collision threshold, a collision should be detected and appropriate effects applied.

**Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.6**

### Property 25: Health Bar Accuracy

*For any* game state, the displayed health bar should accurately reflect the ratio of hero's current health to maximum health.

**Validates: Requirements 10.1**

### Property 26: XP Bar Accuracy

*For any* game state, the displayed XP bar should accurately reflect the ratio of hero's current XP to XP required for next level.

**Validates: Requirements 10.3**

### Property 27: Time Display Format

*For any* game state, the displayed elapsed time should match the actual elapsed seconds formatted as MM:SS.

**Validates: Requirements 10.4**

### Property 28: Enemy Defeat Counter

*For any* game state, the displayed enemy defeat count should equal the total number of walkers defeated since game start.

**Validates: Requirements 10.5**

### Property 29: Ability Indicator Synchronization

*For any* game state, each ability slot indicator should display the correct ability icon and cooldown state matching the hero's active abilities.

**Validates: Requirements 10.6, 10.7**

### Property 30: Scene Cleanup on Hide

*For any* gameplay scene hide event, all active timers and transitions should be cancelled to prevent memory leaks.

**Validates: Requirements 11.5**

### Property 31: Game Over Statistics

*For any* game over event, the displayed statistics should include the correct survival time, enemies defeated count, and final hero level.

**Validates: Requirements 7.7**

### Property 32: Spawning Continues Throughout Session

*For any* active game session, the spawner system should continue spawning walkers at regular intervals until the game ends.

**Validates: Requirements 3.1**

### Property 33: Elapsed Time Increases

*For any* active game session, the elapsed time should continuously increase at a rate of 1 second per real-time second.

**Validates: Requirements 7.2**

## Error Handling

### Combat System Errors

**No Valid Targets**

- Condition: Ability activation when no enemies exist
- Handling: Skip activation, do not create projectiles, cooldown does not trigger
- Validation: Check enemies array length before targeting

**Invalid Damage Values**

- Condition: Negative or NaN damage values
- Handling: Clamp damage to minimum 0, log warning
- Validation: Assert damage >= 0 before application

**Projectile Out of Bounds**

- Condition: Projectile position exceeds game area + 200 pixel buffer
- Handling: Deactivate projectile, return to pool
- Validation: Check bounds in projectile update loop

### Spawner System Errors

**Pool Exhaustion**

- Condition: Walker pool empty when spawn requested
- Handling: Create new walker instance, expand pool dynamically
- Validation: Pool.get() creates new instance if empty

**Maximum Concurrent Limit**

- Condition: Spawn requested when 50 walkers active
- Handling: Skip spawn, log warning, continue normal operation
- Validation: Check activeWalkers.length before spawn

**Invalid Spawn Position**

- Condition: Calculated spawn X outside screen bounds
- Handling: Clamp to valid range [50, 670]
- Validation: math.max(50, math.min(670, spawnX))

### Level System Errors

**XP Overflow**

- Condition: XP value exceeds maximum safe integer
- Handling: Clamp to reasonable maximum (e.g., 999999)
- Validation: Check XP value before addition

**Negative XP**

- Condition: Attempt to add negative XP
- Handling: Reject operation, log warning
- Validation: Assert xpAmount > 0

**Level-Up During Pause**

- Condition: XP threshold reached while game already paused
- Handling: Queue level-up event, process after current upgrade selection
- Validation: Check game state before pausing

### Upgrade System Errors

**Empty Upgrade Pool**

- Condition: No valid upgrades available for card generation
- Handling: Fallback to generic upgrades (XP radius, health)
- Validation: Check pool size before random selection

**Invalid Ability Tier**

- Condition: Attempt to upgrade ability beyond tier 5
- Handling: Reject upgrade, do not increment tier
- Validation: Check ability.tier < 5 before upgrade

**Full Ability Slots**

- Condition: New ability selected when 5 slots occupied
- Handling: Should not occur (card generation prevents this), but if it does, reject upgrade
- Validation: Check abilities.length < 5 before adding

### Collision System Errors

**NaN Distance Calculation**

- Condition: Invalid entity positions (nil or NaN coordinates)
- Handling: Skip collision check for that pair, log warning
- Validation: Check for valid numbers before distance calculation

**Null Entity References**

- Condition: Entity reference becomes nil during collision check
- Handling: Skip that entity, continue with remaining checks
- Validation: Check entity ~= nil before accessing properties

### Scene Management Errors

**Scene Transition During Pause**

- Condition: Attempt to change scene while upgrade UI active
- Handling: Complete upgrade selection first, then allow transition
- Validation: Check game state before scene change

**Resource Cleanup Failure**

- Condition: Timer or listener removal fails
- Handling: Use pcall for cleanup operations, log failures
- Validation: Wrap cleanup in protected calls

**Memory Leak Detection**

- Condition: Display objects not removed from scene group
- Handling: Iterate sceneGroup in destroy phase, force remove all children
- Validation: sceneGroup.numChildren should be 0 after cleanup

### Data Persistence Errors

**Save File Corruption**

- Condition: Invalid JSON in gamedata.json
- Handling: Use default values, create new save file
- Validation: pcall(json.decode, fileContent)

**Write Permission Denied**

- Condition: Cannot write to documents directory
- Handling: Continue with in-memory state, warn user
- Validation: Check file system permissions on startup

## Testing Strategy

### Dual Testing Approach

The Arcane Survivor MVP will use both unit testing and property-based testing to ensure comprehensive coverage:

**Unit Tests**: Focus on specific examples, edge cases, and integration points

- Initial state validation (hero starts at level 1, health 100, etc.)
- Specific upgrade applications (Arcane Bolt damage +5)
- Edge cases (no enemies, empty upgrade pool, full ability slots)
- Scene lifecycle events (create, show, hide, destroy)
- UI component rendering with specific values

**Property Tests**: Verify universal properties across all inputs

- Combat mechanics (damage application, projectile behavior)
- Spawning patterns (difficulty scaling, lane assignment)
- Collision detection (distance calculations for all entity pairs)
- Level progression (XP formula, level-up triggers)
- Upgrade system (card generation, tier limits)

### Property-Based Testing Configuration

**Framework**: Use [lua-quickcheck](https://github.com/luc-tielen/lua-quickcheck) for Lua property-based testing

**Configuration**:

- Minimum 100 iterations per property test
- Random seed logging for reproducibility
- Shrinking enabled for minimal failing examples

**Test Tagging**: Each property test must reference its design document property:

```lua
-- Feature: arcane-survivor-mvp, Property 7: Spawn Rate Scaling
describe("Spawner System", function()
  it("scales spawn rate based on hero level", function()
    property.check(generators.heroLevel(), function(level)
      -- Test implementation
    end, {numTests = 100})
  end)
end)
```

### Test Organization

**Directory Structure**:

```
tests/
├── spec_helper.lua                    # Solar2D mocks
├── entities/
│   ├── hero_spec.lua                  # Unit tests for hero
│   ├── walker_spec.lua                # Unit tests for walker
│   ├── projectile_spec.lua            # Unit tests for projectile
│   └── xp_orb_spec.lua                # Unit tests for XP orb
├── systems/
│   ├── combat_system_spec.lua         # Unit + property tests
│   ├── spawner_system_spec.lua        # Unit + property tests
│   ├── level_system_spec.lua          # Unit + property tests
│   ├── upgrade_system_spec.lua        # Unit + property tests
│   └── collision_system_spec.lua      # Property tests
├── scenes/
│   ├── menu_spec.lua                  # Unit tests for menu scene
│   ├── game_spec.lua                  # Integration tests
│   └── gameover_spec.lua              # Unit tests for game over
└── generators/
    └── game_generators.lua            # Custom generators for property tests
```

### Custom Generators

**File**: `tests/generators/game_generators.lua`

```lua
local generators = {}

-- Generate random hero levels (1-20)
function generators.heroLevel()
  return function()
    return math.random(1, 20)
  end
end

-- Generate random positions within game area
function generators.position()
  return function()
    return {
      x = math.random(0, 720),
      y = math.random(0, 1280)
    }
  end
end

-- Generate random walker configurations
function generators.walker()
  return function()
    return {
      x = math.random(50, 670),
      y = math.random(0, 1280),
      health = math.random(1, 20),
      lane = math.random(50, 670)
    }
  end
end

-- Generate random ability configurations
function generators.ability()
  return function()
    return {
      cooldown = math.random(1, 5) * 0.5,
      damage = math.random(5, 50),
      tier = math.random(1, 5)
    }
  end
end

-- Generate arrays of entities
function generators.walkerArray(minSize, maxSize)
  return function()
    local count = math.random(minSize, maxSize)
    local walkers = {}
    for i = 1, count do
      table.insert(walkers, generators.walker()())
    end
    return walkers
  end
end

return generators
```

### Key Property Test Examples

**Property 7: Spawn Rate Scaling**

```lua
-- Feature: arcane-survivor-mvp, Property 7: Spawn Rate Scaling
describe("Spawner System - Difficulty Scaling", function()
  it("adjusts spawn rate based on hero level", function()
    property.check(generators.heroLevel(), function(level)
      local spawner = spawner_system.create()
      spawner.updateDifficulty(level)
      
      local expectedInterval, expectedCount
      if level < 5 then
        expectedInterval, expectedCount = 3.0, 1
      elseif level < 10 then
        expectedInterval, expectedCount = 3.0, 2
      elseif level < 15 then
        expectedInterval, expectedCount = 2.0, 3
      else
        expectedInterval, expectedCount = 2.0, 4
      end
      
      assert.are.equal(expectedInterval, spawner.spawnInterval)
      assert.are.equal(expectedCount, spawner.spawnCount)
      return true
    end, {numTests = 100})
  end)
end)
```

**Property 18: XP Requirement Formula**

```lua
-- Feature: arcane-survivor-mvp, Property 18: XP Requirement Formula
describe("Level System - XP Requirements", function()
  it("calculates XP requirement correctly for any level", function()
    property.check(generators.heroLevel(), function(level)
      local required = level_system.calculateXPRequired(level)
      local expected = 100 + (level - 1) * 20
      assert.are.equal(expected, required)
      return true
    end, {numTests = 100})
  end)
end)
```

**Property 24: Distance-Based Collision Detection**

```lua
-- Feature: arcane-survivor-mvp, Property 24: Distance-Based Collision Detection
describe("Collision System", function()
  it("detects collision when distance is within threshold", function()
    property.check(
      generators.position(),
      generators.position(),
      function(pos1, pos2)
        local distance = collision_system.checkDistance(
          pos1.x, pos1.y, pos2.x, pos2.y
        )
        local threshold = 20
        local shouldCollide = distance <= threshold
        
        local collision = collision_system.checkCollision(
          {x = pos1.x, y = pos1.y, radius = 10},
          {x = pos2.x, y = pos2.y, radius = 10}
        )
        
        assert.are.equal(shouldCollide, collision)
        return true
      end,
      {numTests = 100}
    )
  end)
end)
```

### Unit Test Coverage Goals

**Minimum Coverage Targets**:

- Entities: 80% line coverage
- Systems: 85% line coverage
- Controllers: 75% line coverage
- UI Components: 70% line coverage

**Critical Paths** (100% coverage required):

- Hero damage and death
- Enemy spawning and defeat
- XP collection and level-up
- Upgrade application
- Collision detection

### Integration Testing

**Game Loop Integration**:

- Test full game session from start to game over
- Verify system coordination (spawning → movement → collision → defeat → XP → level-up)
- Test pause/resume during upgrade selection
- Verify scene transitions and cleanup

**Performance Testing**:

- Measure FPS with 30 concurrent walkers
- Verify object pool efficiency (no memory growth over 5 minutes)
- Test maximum concurrent entity limits (50 walkers)

### Manual Testing Checklist

- [ ] Hero remains stationary throughout game
- [ ] Abilities auto-fire at correct intervals
- [ ] Enemies spawn and advance down lanes
- [ ] Projectiles hit enemies and deal damage
- [ ] XP orbs spawn on enemy defeat
- [ ] XP collection triggers level-up
- [ ] Upgrade cards display correctly
- [ ] Selected upgrades apply correctly
- [ ] Game ends on hero death
- [ ] Statistics display correctly on game over
- [ ] Scene transitions are smooth
- [ ] No memory leaks after multiple sessions

### Continuous Testing

**Pre-Commit**:

- Run all unit tests
- Run fast property tests (10 iterations)

**CI Pipeline**:

- Run all unit tests
- Run full property tests (100 iterations)
- Generate coverage report
- Run integration tests

**Pre-Release**:

- Full test suite
- Performance profiling
- Manual testing checklist
- Device testing (iOS and Android)
