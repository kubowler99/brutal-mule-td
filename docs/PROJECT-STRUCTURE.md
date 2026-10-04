# Project Structure

How Arcane Survivor's code is organized, how a run flows through it, and where to make common changes. For what the game is, see the [README](../README.md) and the [game concept](arcane-survivor/game-concept.md).

## Folder layout

```text
main.lua                 Entry point
config.lua               Content size (720x1280 portrait, letterbox) and image suffixes
build.settings           Platform build settings (orientation, permissions, icons)
.luarc.json              Lua Language Server setup (Lua 5.1, Solar2D globals)
config.ld                LDoc settings for generated API docs (docs/api, ignored by git)
*.rockspec               LuaRocks metadata (left over from the project template)
.github/workflows/       CI: runs the test suite on every pull request
data/                    Game data; most balance changes happen here
  abilities.json         Abilities: base stats, synergy tags, upgrade cards
  enemies.json           Enemy types: health, speed, damage, range, XP, boss flags
  game_config.json       Wall, spawner (spawn table, elites, bosses), synergy, collision, XP
  meta.json              Gold rates, permanent upgrades, heroes
assets/images/sprites/   Zombie sprite sheets (PNG plus sheet data .lua)
src/
  scenes/                Composer scenes (screens)
  controllers/           game_controller: one run's setup, game loop, and events
  systems/               Per-frame game systems and feedback
  entities/              Hero, wall, enemies, projectiles
    abilities/           One module per ability class
  models/                Data loading, save data, run state, meta progression
  ui/                    Reusable in-game UI pieces
  utils/                 Helpers (pooling, buttons, placeholder graphics, math, strings)
lib/                     middleclass (classes) and stateful
tests/                   busted specs and Solar2D mocks
docs/                    This document, architecture notes, game concept
```

## Startup and screens

`main.lua` registers `Class` (middleclass) and `Stateful` as globals, installs an unhandled-error handler and the Android back button, loads save data (`src/models/data.lua`), initializes the ability registry, and opens the menu.

Screens are Composer scenes in `src/scenes/`:

| Scene | Purpose | Goes to |
|---|---|---|
| `menu` | Title, best run, gold | `hero_select` (PLAY), `upgrades` (UPGRADES) |
| `hero_select` | Pick an unlocked hero or buy a locked one | `game` with `params.heroId`, or `menu` |
| `upgrades` | Buy permanent upgrades with gold | `menu` |
| `game` | The run: HUD, ability indicators, level-up cards, pause, boss bar | `gameover`, or `menu` (quit from pause) |
| `gameover` | VICTORY! or GAME OVER, run stats, best run, gold earned; saves stats and gold | `game` (Play Again, same hero) or `menu` |

The game scene builds its UI once in `create` and starts a new run in `show` ("will"), so Play Again works with Composer's cached scene.

## A run

`src/controllers/game_controller.lua` owns one run.

**`initialize(group, heroId)`** loads the data files, then:
1. reads the hero and run bonuses from `meta_progression` (permanent upgrades plus hero bonuses);
2. creates the wall and the hero with its starting ability;
3. creates object pools for enemies and projectiles;
4. initializes the systems and connects their callbacks.

**`update(event)`** runs every frame. It caps the frame step at 0.1s, then:
1. `spawner_system` spawns enemies and bosses;
2. difficulty follows the hero level;
3. enemies move (and slow effects tick);
4. collisions: projectile hits deal damage (with slow, freeze, and ricochet), enemies at the wall attack it (bosses and slam elites wind up first);
5. `combat_system` fires abilities whose cooldown is ready, runs per-frame abilities, and moves projectiles;
6. `effects` advances screen shake.

**Ending a run:** the wall reaching 0 health calls `onGameOver`; killing the final boss calls `onVictory`. Both pass the run statistics to the game scene, which opens `gameover`.

**Pausing:** the pause button, the level-up panel, and app suspend all call `game_controller.pause()`; the game loop skips frames while paused.

## Systems (`src/systems/`)

| Module | Responsibility |
|---|---|
| `spawner_system` | Spawns from the weighted spawn table, rolls elites and their abilities, spawns bosses at their levels and summoners' minions, scales spawn rate with hero level |
| `combat_system` | Fires abilities at their wall slot, runs per-frame abilities, tracks and recycles projectiles, applies damage |
| `collision_system` | Distance checks: projectile vs enemy, enemy reaching its attack position at the wall |
| `experience_system` | Awards XP (with elite and hero multipliers), levels the hero up, XP feedback |
| `upgrade_system` | Builds the level-up card pool and draws cards, weighted toward synergies |
| `effects` | Damage numbers, hit sparks, screen shake |
| `sound` | Sound effects and music from `assets/audio/` when the files exist |

Systems talk to the controller through callbacks rather than requiring it:

| Callback | Set by | Called when |
|---|---|---|
| `combat_system.onEnemyKilled` | game_controller | any damage source kills an enemy (awards XP, counts the kill, checks victory) |
| `combat_system.onEnemyDamaged` | game_controller | any hit on an enemy (damage number, spark, sound) |
| `spawner_system.onBossSpawned` | game_controller | a boss spawns (sound, shake, scene banner) |
| `game_controller.onLevelUpCallback` | game scene | the hero levels up (show cards) |
| `game_controller.onGameOverCallback` | game scene | the run ends (go to gameover) |
| `game_controller.onBossSpawnedCallback` | game scene | a boss spawns (banner) |

## Entities (`src/entities/`)

- **`hero.lua`**: stationary at the wall's left edge. Holds up to 5 abilities. `Hero:getStats()` combines base stats (permanent upgrades and hero bonus), passive abilities, and synergy bonuses into a `damageMultiplier` and `cooldownMultiplier`.
- **`wall.lua`**: the thing to protect. The run ends when its health reaches 0.
- **`walker.lua`**: every enemy type. `activate(x, y, lane, enemyType)` loads that type's stats from `enemies.json`. It also handles elites (`makeElite`, with the charge and summon abilities), attack wind-ups (`setTelegraph`), slows (`applySlow`), burns (`applyBurn`; the controller applies the collected burn damage each frame), ranged stopping (`attackRange`), the sprite animation, and per-type tint and size.
- **`projectile.lua`**: a pooled projectile with damage, pierce, and an optional on-hit slow.

### Abilities (`src/entities/abilities/`)

An ability is a middleclass object with an `id` and a `tier` (1 to 5). The combat system calls these methods when they exist:

| Method | Used for |
|---|---|
| `canActivate(currentTime, heroStats)` | Whether the cooldown has elapsed (cooldown scaled by `heroStats.cooldownMultiplier`) |
| `activate(x, y, enemies, projectilePool, displayGroup, heroStats)` | Fire once; `x, y` is the ability's slot on the wall |
| `update(dt, x, y, enemies, displayGroup, heroStats)` | Per-frame abilities such as Patrol Blades |
| `upgrade(upgradeType)` | Apply one level-up card |
| `applyStats(stats)` | Passives: change the hero stats table |
| `destroy()` | Remove display objects the ability owns |

| Module | Ability |
|---|---|
| `arcane_bolt.lua` | Projectile at the nearest enemy, with predictive aim |
| `frost_shard.lua` | Arcane Bolt subclass; piercing shards that slow on hit |
| `frost_nova.lua` | Pulse along the wall that damages and slows |
| `flame_slash.lua` | Short-range sweep from its slot; burn upgrade |
| `patrol_blades.lua` | Blades sweeping along the whole wall (uses `update`) |
| `passive.lua` | One class for every passive; `abilities.json` sets the stat and amount per tier |

## Models (`src/models/`)

| Module | Responsibility |
|---|---|
| `data` | Save data (`gamedata.json` in the documents directory) with dot-path `get`/`set`, and a sandbox mode for tests |
| `game_state` | The current run: state, elapsed time, kills, victory |
| `config_loader` | Reads `game_config.json` (`get("spawner.spawnInterval")`) |
| `ability_data_loader` | Reads and validates `abilities.json` (base stats, upgrade parameters) |
| `ability_registry` | Ability definitions and instances by id (`createInstance(id)`) |
| `synergy` | Ability tags, shared-tag damage bonus, draft weights |
| `meta_progression` | Gold, permanent upgrades, heroes, and the run bonuses they give; definitions from `meta.json` |

## Common changes

**Tune balance:** edit the files in `data/`; no code changes needed. The [README](../README.md#tuning) lists what each file controls.

**Add an enemy type**
1. Add an entry to `data/enemies.json` (health, speed, damage, attackCooldown, xpValue; optional attackRange, isBoss, isFinalBoss).
2. Add it to `spawner.enemyTable` in `data/game_config.json` with a weight, unlock level, and group size.
3. Add fallback stats and a tint/size to `DEFAULT_STATS` and `TYPE_STYLES` in `src/entities/walker.lua`.

**Add an ability**
1. Create a module in `src/entities/abilities/` with the methods above.
2. Add an entry to `data/abilities.json` with `module`, `unlocked: true`, `baseStats`, `tags`, and `upgrades`. The upgrade cards and the new-ability card come from this entry.
3. Optionally give it an indicator color in `src/ui/ability_indicator.lua`.

**Add a passive:** only a `data/abilities.json` entry is needed. Use `"module": "src.entities.abilities.passive"`, a `"passive": { "stat": ..., "perTier": ... }` section, and one upgrade.

**Add a hero or permanent upgrade:** add an entry to `heroes` or `upgrades` in `data/meta.json`.

## Tests

`tests/` mirrors `src/` (`controllers/`, `entities/`, `models/`, `scenes/`, `systems/`, `ui/`, `utils/`), plus `integration/`, `performance/`, and `generators/` (random data for property tests).

- `tests/spec_helper.lua` mocks the Solar2D APIs (display, system, audio, transition, composer). It also provides:
  - `snapshotModule(mod)`: restore a module's stubbed functions after a test;
  - `checkProperties()`: run the lua-quickcheck properties a test defined and fail the test if one fails.
- Writable paths (save data) resolve to the OS temp directory, so tests never touch the working tree.
- See the [README](../README.md#tests) for setup and commands. CI runs the suite in normal and shuffled order.
