# Arcane Survivor

A stationary-hero defense game built with [Solar2D](https://solar2d.com/). The hero holds a wall at the bottom of the screen while enemies advance from the top. Abilities fire automatically. Defeating enemies awards XP, and each level-up offers three random cards: a new ability or an upgrade to one you have. A boss arrives at level 10, and the final boss at level 20. Kill the final boss to win; the run ends in defeat if the wall falls.

See [docs/arcane-survivor/game-concept.md](docs/arcane-survivor/game-concept.md) for the full game concept.

## Current content

- **Abilities** (up to 5, each upgradeable to tier 5)
  - **Arcane Bolt**: fires at the nearest enemy. Upgrades: damage, attack speed, projectile count (each extra bolt targets the next-nearest enemy), pierce.
  - Extra bolts and shards share the damage: each projectile past the first lowers every projectile's damage by 20% (2 deal 80% each, 3 deal 64% each).
  - **Frost Nova**: pulses along the wall, damaging and slowing every enemy within range. Upgrades: damage, range, cooldown, slow.
  - **Frost Shard**: fires a piercing shard at the nearest enemy that slows what it hits. Upgrades: damage, shard count (extra shards fan out 12° apart), pierce, slow, ricochet (bounce to another enemy), freeze chance.
  - **Flame Slash**: sweeps fire across every enemy within 220px of its spot on the wall. Upgrades: damage, reach, cooldown, burn (damage over time).
  - **Patrol Blades**: blades sweep back and forth along the whole wall, just in front of it, and cut enemies they touch. Upgrades: blade count, patrol speed, damage, size.
  - **Arcane Might** (passive): +10% damage for all abilities per tier.
  - **Quickening** (passive): 8% shorter cooldowns for all abilities per tier.
- **Enemies** (the spawn mix is set by `spawner.enemyTable` in `game_config.json`)
  - **Walker**: the basic melee enemy.
  - **Runner** (level 3+): half the health and double the speed of a walker.
  - **Swarmling** (level 4+): very weak, spawns in groups of 4.
  - **Brute** (level 5+): slow and tanky, hits the wall hard.
  - **Spitter** (level 6+): stops short of the wall and attacks from range.
  - **Elites** (level 8+): any normal enemy can spawn as a gold elite with 4x health, 2x damage, and 5x XP, plus one ability:
    - **Slam**: winds up (flashes red) and hits the wall twice as hard.
    - **Charge**: dashes at triple speed once it gets close to the wall.
    - **Summon**: calls two swarmlings every 5 seconds.
  - **Bosses**: a boss at level 10 and the final boss at level 20, announced with a banner and a boss health bar. Bosses flash red and grow just before each attack.
- **Stat upgrades**: wall repair, wall fortify, XP boost.
- **Synergies**: abilities have tags (projectile, frost, fire, arcane, area, blade). Each tag shared by two or more of your abilities adds +10% damage, and level-up cards that share a tag with your abilities are twice as likely to appear. Cards show their tags, in gold when they match.
- **Heroes** (chosen before each run)
  - **Arcane Wanderer** (free): starts with Arcane Bolt, +10% XP.
  - **Frost Witch** (300 gold): starts with Frost Shard, 10% shorter cooldowns.
  - **Ember Knight** (500 gold): starts with Flame Slash, +20% damage while the wall is below half health.
- **Meta progression**: each run earns gold (per kill, per level reached, and a bonus for winning). Spend it on heroes and on permanent upgrades: wall health, damage, cooldowns, XP gain.
- **Feedback**: floating damage numbers, hit sparks, and screen shake on heavy wall hits and boss arrivals.
- **Screens**: main menu with your best run and gold, hero select, upgrades, game with pause, and an end screen titled VICTORY! or GAME OVER with run stats, gold earned, and a "NEW BEST!" highlight.

## Running the game

1. Install the [Solar2D Simulator](https://solar2d.com/).
2. Open this folder (the one with `main.lua`) in the simulator.

The game is designed for 720x1280 portrait (see `config.lua`).

## Project structure

```text
main.lua              Entry point: error handling, save data, scene routing
config.lua            Content size and scaling
build.settings        Platform build settings
data/                 Game data (edit these to tune balance)
  abilities.json      Ability base stats and upgrade cards
  enemies.json        Enemy stats and XP values
  game_config.json    Wall, spawner, collision, and XP settings
  meta.json           Gold rates, permanent upgrades, and heroes
assets/images/        Sprites and sprite sheet data
src/
  scenes/             menu, hero_select, upgrades, game, gameover (Composer scenes)
  controllers/        game_controller: game loop and system wiring
  systems/            spawner, combat, collision, experience, upgrade
  entities/           hero, wall, walker (all enemy types), projectile
    abilities/        arcane_bolt, frost_shard, frost_nova, flame_slash, patrol_blades, passive
  models/             game state, save data, meta progression, synergy, config and ability loaders
  ui/                 health bar, XP bar, ability indicators, upgrade cards
  utils/              object pool, helpers, placeholder graphics
lib/                  middleclass (OOP) and stateful
tests/                busted specs and Solar2D mocks (spec_helper.lua)
docs/                 Game concept and architecture notes
```

## Tuning

Most balance values live in `data/`, so you can change them without touching code:

- `game_config.json`: spawn interval, spawn count, the enemy spawn table (type, weight, unlock level, group size), elite settings and abilities, boss levels, extra-projectile damage penalty, synergy bonus and draft weight, wall health, XP curve.
- `enemies.json`: health, speed, damage, attack cooldown, attack range, and XP value per enemy type; boss flags.
- `abilities.json`: base stats, synergy tags, and upgrade amounts per ability. Set `"unlocked": false` to stop an ability from being offered.
- `meta.json`: gold per kill, per level, and for winning; permanent upgrade costs and amounts; hero prices, starting abilities, and bonuses.

## Audio

The game plays sounds only when their files exist, so it runs silently until you add them. Add any of these files to enable them:

| File | Plays on |
|---|---|
| `assets/audio/sfx/hit.wav` | an enemy is hit |
| `assets/audio/sfx/enemy_death.wav` | an enemy dies |
| `assets/audio/sfx/wall_hit.wav` | the wall takes damage |
| `assets/audio/sfx/boss.wav` | a boss arrives |
| `assets/audio/sfx/level_up.wav` | level-up |
| `assets/audio/sfx/xp_gain.wav` | XP is awarded |
| `assets/audio/sfx/victory.wav` | the run is won |
| `assets/audio/sfx/defeat.wav` | the wall falls |
| `assets/audio/music/battle.mp3` | loops during a run |

The `soundOn` and `musicOn` settings in the save data turn them off.

## Tests

The specs run outside Solar2D with [busted](https://lunarmodules.github.io/busted/). `tests/spec_helper.lua` mocks the Solar2D APIs.

Solar2D uses Lua 5.1, so run the tests on LuaJIT 2.1 (or Lua 5.1). `lua-quickcheck` does not install on newer Lua versions.

Install (macOS with Homebrew):

```bash
brew install luajit luarocks
```

```bash
for rock in busted lua-quickcheck dkjson; do luarocks --lua-version=5.1 --lua-dir="$(brew --prefix luajit)" install --local "$rock"; done
```

Run from the repository root:

```bash
eval "$(luarocks --lua-version=5.1 path --local)" && ~/.luarocks/bin/busted tests
```

Add `--shuffle` to check that no test depends on run order. GitHub Actions runs the suite in both normal and shuffled order on every pull request (`.github/workflows/tests.yml`).

## Libraries

- [middleclass](https://github.com/kikito/middleclass): classes and inheritance
- [stateful](https://github.com/kikito/stateful.lua): state machines for middleclass objects
