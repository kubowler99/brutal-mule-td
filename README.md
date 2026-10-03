# Arcane Survivor

A stationary-hero defense game built with [Solar2D](https://solar2d.com/). The hero holds a wall at the bottom of the screen while enemies advance from the top. Abilities fire automatically. Defeating enemies awards XP, and each level-up offers three random cards: a new ability or an upgrade to one you have. The run ends when the wall falls.

See [docs/arcane-survivor/game-concept.md](docs/arcane-survivor/game-concept.md) for the full game concept.

## Current content

- **Abilities** (up to 5, each upgradeable to tier 5)
  - **Arcane Bolt**: fires at the nearest enemy. Upgrades: damage, attack speed, projectile count, pierce.
  - **Frost Nova**: pulses along the wall, damaging and slowing every enemy within range. Upgrades: damage, range, cooldown, slow.
  - **Orbiting Blades**: blades circle the ability's spot on the wall and cut enemies they touch. Upgrades: blade count, speed, damage, size.
  - **Arcane Might** (passive): +10% damage for all abilities per tier.
  - **Quickening** (passive): 8% shorter cooldowns for all abilities per tier.
- **Enemies** (the spawn mix is set by `spawner.enemyTable` in `game_config.json`)
  - **Walker**: the basic melee enemy.
  - **Runner** (level 3+): half the health and double the speed of a walker.
  - **Swarmling** (level 4+): very weak, spawns in groups of 4.
  - **Brute** (level 5+): slow and tanky, hits the wall hard.
- **Stat upgrades**: wall repair, wall fortify, XP boost.
- **Screens**: main menu with your best run, game with pause, game over with run stats and a "NEW BEST!" highlight.

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
assets/images/        Sprites and sprite sheet data
src/
  scenes/             menu, game, gameover (Composer scenes)
  controllers/        game_controller: game loop and system wiring
  systems/            spawner, combat, collision, experience, upgrade
  entities/           hero, wall, walker (all enemy types), projectile
    abilities/        arcane_bolt, frost_nova, orbiting_blades, passive
  models/             game state, save data, config and ability loaders
  ui/                 health bar, XP bar, ability indicators, upgrade cards
  utils/              object pool, helpers, placeholder graphics
lib/                  middleclass (OOP) and stateful
tests/                busted specs and Solar2D mocks (spec_helper.lua)
docs/                 Game concept and architecture notes
```

## Tuning

Most balance values live in `data/`, so you can change them without touching code:

- `game_config.json`: spawn interval, spawn count, the enemy spawn table (type, weight, unlock level, group size), wall health, XP curve.
- `enemies.json`: health, speed, damage, attack cooldown, and XP value per enemy type.
- `abilities.json`: base stats and upgrade amounts per ability. Set `"unlocked": false` to stop an ability from being offered.

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
