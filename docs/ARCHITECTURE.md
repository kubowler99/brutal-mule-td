# Architecture Overview

This project follows a modular, layer-based architecture inspired by professional Solar2D game development patterns.

## 1. Modular Utilities (`src/utils/`)

Instead of a monolithic helper file, the project uses specialized utility modules:

- **screen.lua**: Standardized display metrics. Centralizes access to screen boundaries, safe areas, and center points.
- **device.lua**: Platform and device detection flags (`isAndroid`, `isIos`, `isTall`, etc.).
- **math.lua**: Extended mathematical functions tailored for game development (clamping, lerping, angle calculations).
- **string.lua**: String manipulation helpers (splitting, trimming, capitalization).
- **taskQueue.lua**: A frame-independent task scheduling system. Essential for games that implement time-scaling (slow-motion) or need to pause game logic independently of the engine.
- **pool.lua**: A flexible object pooling utility to reduce memory churn and CPU spikes by reusing display objects and tables.
- **helpers.lua**: UI-specific shortcuts and component factories (like `newButton`).

## 2. Advanced Data Management (`src/models/data.lua`)

The template features a robust data persistence layer supporting:
- **Dot-Notation Access**: Retrieve and set nested data easily (e.g., `data.get("settings.sound.volume")`).
- **Sandbox Mode**: A critical development feature that allows you to test game state changes in memory without overwriting the actual save file on disk.
- **Session Tracking**: Built-in tracking for session counts and first-run timestamps.
- **Safe I/O**: Automated JSON encoding/decoding with protected calls (`pcall`) to prevent crashes from corrupted files.

## 3. Dependency Strategy (Penlight)

While the project includes essential utilities in `src/utils/`, it is designed to be lean. For more advanced needs (complex data structures, filesystem abstraction, functional programming), the **Penlight** library is the recommended upgrade path.

- **Status**: Optional (Recommended).
- **Integration**: Penlight is included in the `.rockspec` as a recommended dependency.
- **Usage**: Use Penlight when you need `pl.List`, `pl.Map`, or advanced table/string manipulations that go beyond the built-in `src/utils/` modules.

## 4. Global Accessibility vs. Modularization

While the project encourages `require()` for modules, some core utilities are often used frequently enough that they can be assigned to local variables in `main.lua` or referenced through a central "game" or "context" object if needed.

## 5. Separation of Concerns

- **Models (`src/models/`)**: Handle data and state. `data.lua` is the primary entry point for persistent storage.
- **Scenes (`src/scenes/`)**: Pure display and lifecycle logic using the Composer library.
- **Utils (`src/utils/`)**: Pure, side-effect-free logic (mostly).

## 6. Design Patterns

- **Facade**: `helpers.lua` acts as a facade for common display operations.
- **Singleton**: The `data.lua` module acts as a state singleton.
- **Object Pool**: Implemented in `pool.lua` to manage resource lifecycle.
- **Command/Task Queue**: Implemented in `taskQueue.lua` for deferred execution.
- **Class/Inheritance**: Provided by `middleclass.lua` for complex entities.
- **State Machine**: Provided by `stateful.lua`, enabling complex behavior management for entities and game systems.

## 7. Object-Oriented Programming (OOP)

The template includes the `middleclass` library to support formal OOP. While Solar2D is naturally modular and functional, OOP is particularly beneficial for:
- **Game Entities**: Managing complex state and behavior for players, enemies, and projectiles.
- **UI Components**: Creating reusable custom UI elements with their own internal logic.
- **Inheritance**: Sharing logic between similar objects (e.g., a base `Enemy` class extended by `FastEnemy`).
- **States**: Managing entity behavior via `Stateful` (e.g., a player switching between `Idle`, `Running`, and `Jumping`).

See `src/entities/player.lua` for a practical implementation example.

## 8. Unit Testing (`tests/`)

The project follows a BDD-style unit testing approach using **Busted**.

- **Test Structure**: Tests are located in the `tests/` directory, mirroring the `src/` hierarchy.
- **Mocking**: Since unit tests run in a standard Lua environment, `tests/spec_helper.lua` provides mocks for Solar2D-specific globals (like `display`, `system`, `Runtime`).
- **Coverage**: Use **LuaCov** to track code coverage.
- **What to Test**: Focus on "pure" logic in `src/utils/` and `src/models/`. Scenes and complex entities are better validated through integration testing or manual playtesting in the simulator.

To run tests:
```bash
luarocks install busted
busted
```

## 9. Inspired by "Pilot" Design

The current architecture is an evolution of simpler templates, incorporating "industry-standard" practices:
- Standardized screen/device abstraction.
- Robust error handling.
- Modularized utility functions for better testability and maintenance.
