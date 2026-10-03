# Architecture

The design decisions behind Arcane Survivor's code and the reasons for them. For where things live and how to make common changes, see [PROJECT-STRUCTURE.md](PROJECT-STRUCTURE.md).

## 1. Layers and dependencies

```text
scenes  ->  game_controller  ->  systems  ->  entities, models
                     (callbacks flow back up)
```

- **Scenes** handle display and the Composer lifecycle. The game scene owns the HUD and overlays (level-up cards, pause, boss bar) and asks `game_controller` to run the game.
- **`game_controller`** owns one run: it creates the hero, wall, and pools, wires the systems together, and runs the game loop.
- **Systems** do one job each per frame (spawning, combat, collisions, XP, cards, effects, sound).
- **Entities and models** hold state and data and know nothing about the game loop.

Lower layers never `require` higher ones. When a system needs to tell the controller something, it calls a callback that the controller sets (for example `combat_system.onEnemyKilled`). The same goes for the controller and the scene (`onLevelUpCallback`, `onGameOverCallback`, `onBossSpawnedCallback`). This keeps the systems testable on their own and avoids circular requires.

Two deliberate exceptions:
- Abilities that deal damage directly (Frost Nova, Orbiting Blades) require `combat_system` so that their damage goes through `applyDamage` like everything else.
- The wall repair and fortify cards in `upgrade_system` require `game_controller` inside their `apply` functions to reach the wall. The require is lazy, so there is no load-time cycle.

## 2. Data-driven design

Balance and content live in `data/*.json`, not in code:
- `abilities.json`: abilities, their tags, and upgrade cards.
- `enemies.json`: enemy types.
- `game_config.json`: spawning, elites, bosses, synergy, collision, XP curve.
- `meta.json`: gold, permanent upgrades, heroes.

Loaders (`config_loader`, `ability_data_loader`, `ability_registry`, `meta_progression`) read these files once and validate values. Every reader also has hard-coded fallbacks, so a missing or broken value never crashes the game.

A missing section turns a feature off rather than inventing values. Without a spawn table, only walkers spawn; without `spawner.elites` or `spawner.bosses`, there are no elites or bosses. This also keeps tests deterministic, since most specs run without the config loaded.

Adding an enemy, passive, hero, or permanent upgrade is usually a data change only. New abilities and new kinds of behavior need code.

## 3. The game loop and time

There is one `enterFrame` listener, `game_controller.update`. It runs the systems in a fixed order each frame (see PROJECT-STRUCTURE.md).

- **Movement and timers use `dt`**, the time since the last frame, capped at 0.1s. Solar2D stops sending frames while the app is suspended, so without the cap the first frame back would move enemies across the screen. The game also pauses on `applicationSuspend`.
- **Ability and attack cooldowns use the frame's absolute time** (`event.time` in seconds). This time keeps running during a pause, so abilities are ready again right after resuming.
- **Pausing** sets a flag that makes `update` skip frames, and `resume` resets the frame timer so the first frame back has a normal `dt`. The pause button, the level-up panel, and app suspend all use it.

## 4. Hero stats

Abilities don't store hero-wide bonuses. They ask the hero when they fire: `Hero:getStats()` builds `damageMultiplier` and `cooldownMultiplier` fresh each time from
1. `hero.baseStats`: permanent upgrades and the hero's own bonus, set at run start;
2. passive abilities, which add to the stats through `applyStats`;
3. synergy: +10% damage per tag shared by two or more abilities;
4. a floor on the cooldown multiplier (0.4).

Combat passes the result to `canActivate` and `activate`. Because it is recomputed, picking a passive or a synergy card takes effect on the next shot with nothing to keep in sync. With at most five abilities, the cost is negligible.

XP works the same way: `experience_system.awardXP` multiplies by the kill's multiplier (elites) and `hero.xpMultiplier` (hero, permanent upgrade, XP Boost card).

## 5. Damage and kills

All damage to enemies goes through `combat_system.applyDamage`. It reports a kill only when the hit moved an active enemy to inactive, then calls `onEnemyDamaged` (numbers, sparks, sound) and `onEnemyKilled` (XP, kill count, victory check).

One path for every source (projectiles, Frost Nova, blades) means every source rewards kills the same way. It also prevents double rewards:
- collision pairs whose enemy already died, or whose projectile was already spent, earlier in the same frame are skipped;
- a dead enemy can't be "killed" again.

## 6. Object pooling

Enemies and projectiles are pooled (`src/utils/pool.lua`) to avoid allocating display objects during play. Two rules keep pooling correct:

- **Reset on reuse.** `Walker:activate` reloads stats when the type changes or when the previous life was an elite, and clears slows. `Projectile:activate` clears the on-hit slow. Anything an ability adds to a pooled object must be reset there.
- **Always release.** Every path that stops tracking a projectile (hit, off-screen, error, cleanup) returns it to the pool. At the end of a run, the controller destroys every pooled display object.

## 7. Abilities

An ability is a middleclass object. The combat system calls whichever of `canActivate`, `activate`, `update`, `upgrade`, `applyStats`, and `destroy` it defines (see PROJECT-STRUCTURE.md for signatures). There is no base class to inherit from; the interface is the method names.

- **Created by id.** `ability_registry.createInstance(id)` requires the `module` named in `abilities.json` and calls `Class:new(id)`. Passing the id lets one class back several abilities: every passive is the same `Passive` class, configured by its data entry.
- **Inheritance where it helps.** Frost Shard subclasses Arcane Bolt and adds the slow, reusing the targeting and firing.
- **Slots.** Each ability fires or runs from its indicator's position on the wall (`combat_system.getFireOrigin`), so slot order matters for area and orbital abilities.

## 8. Persistence

`src/models/data.lua` stores save data as JSON in the documents directory (`gamedata.json`, not tracked in git). It offers dot-path access (`data.get("meta.gold")`) and a sandbox mode that tests use to change data in memory without writing it.

- **Run statistics** are saved under `stats` by the game over scene.
- **Meta progression** (gold, upgrade levels, unlocked heroes, selected hero) is saved under `meta` by `meta_progression`. Definitions stay in `data/meta.json`, so prices can change without migrating saves.

## 9. Feedback and optional assets

Effects and sound must never break play:
- Effects draw with `pcall`, cap how many damage numbers can be on screen, and run screen shake from the game loop so it stops while paused.
- Sounds load only if their file exists under `assets/audio/`, so the game runs silently until audio is added, and the `soundOn`/`musicOn` settings turn them off.
- Placeholder graphics (`placeholder_graphics.lua`) stand in for art that doesn't exist yet.

## 10. Testing

Specs run outside Solar2D with busted on LuaJIT (Lua 5.1, matching Solar2D). `tests/spec_helper.lua` mocks the Solar2D APIs. Writable paths resolve to the OS temp directory so tests never touch the working tree.

- **Isolation:** busted reloads modules for each spec file. Within a file, tests restore what they stub; `snapshotModule(mod)` restores a module's functions in `after_each` even when a test fails partway.
- **Property tests:** lua-quickcheck properties run through `checkProperties()`, which fails the test when a property fails. Plain `lqc.check()` only records failures.
- **Run order:** CI runs the suite in normal and shuffled order (`busted --shuffle`) to catch tests that depend on each other. The shuffled run has already caught one real bug: spawn groups at the screen edge.

## 11. Libraries

- **middleclass** (`Class`, global): classes and inheritance for entities, abilities, and UI components.
- **stateful** (`Stateful`, global): state machines for middleclass objects. It is loaded in `main.lua` but no game code uses it yet.

The `.rockspec` and `config.ld` files come from the original project template. They are kept for LuaRocks metadata and LDoc generation, but the build doesn't depend on them.
