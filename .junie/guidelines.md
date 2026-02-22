# Solar2D Project Guidelines

This document outlines the architectural principles, coding standards, and best practices for the Solar2D Professional Project Template. All contributors and AI agents should adhere to these rules to maintain project consistency and scalability.

## 1. Project Philosophy
- **Modularity First**: Favor small, specialized modules over large, monolithic files.
- **Layered Architecture**: Strictly separate display logic (Scenes), business logic (Controllers/Entities), and data management (Models).
- **Modern Standards**: Use formal OOP (MiddleClass), State Machines (Stateful), and frame-independent scheduling (TaskQueue).
- **Defensive Programming**: Always implement error handling (pcall) and safety checks for I/O and resource management.

## 2. Directory Structure Rules
Maintain the established hierarchy. Do not create new top-level directories without justification.
- `src/scenes/`: Pure Composer scenes. Lifecycle management only.
- `src/entities/`: OOP classes for game objects. Use `lib/middleclass.lua`.
- `src/models/`: Data persistence and state singletons (e.g., `data.lua`).
- `src/utils/`: Side-effect-free logic modules (math, screen, string, etc.).
- `lib/`: External dependencies only.
- `assets/`: Strictly organized by type (images, audio, fonts).

## 3. Coding Standards

### OOP & State Management
- Use the global `Class` keyword for all entities.
- Use `Stateful` for entities with complex behavioral states (e.g., `Idle`, `Moving`, `Attacking`).
- Always implement a `destroy()` or `cleanup()` method for classes to manage memory.

### Display & UI
- Use `src/utils/screen.lua` for all positioning. Avoid hardcoded coordinates.
- Use `display.contentCenterX`, `display.actualContentWidth`, etc., for responsive design.
- UI components should be built using factories or classes to ensure reusability.

### Data Management (`src/models/data.lua`)
- Access persistent data using `data.get("path.to.key")` and `data.set("path.to.key", value)`.
- Use **Sandbox Mode** (`startSandbox()`) for destructive testing or simulation.
- Never use `_G` for game state; use the data model.

## 4. Performance & Memory
- **Object Pooling**: Use `src/utils/pool.lua` for high-frequency objects (bullets, particles, enemies).
- **Cleanup**: Strictly follow the Composer lifecycle. Clean up timers, transitions, and listeners in `scene:hide` or `scene:destroy`.
- **TaskQueue**: Use `src/utils/taskQueue.lua` for logic that needs to be pause-aware or time-scaled.

## 5. Error Handling
- Maintain the global `unhandledError` listener in `main.lua`.
- Use `pcall` for JSON operations and file I/O.
- Log errors using a consistent format: `[ERROR] ModuleName: Message`.

## 6. Documentation & Testing
- **LDoc**: Document all public functions using LuaDoc/LDoc comments.
- **Unit Tests**: Place tests in `tests/`. Logic in `src/` should have corresponding unit tests where applicable.
- **Intellisense**: Keep `.luarc.json` updated with any new globals or library paths.

## 7. Platform Specifics
- **Android**: Always handle the hardware back button in `main.lua` and relevant scenes.
- **iOS**: Be mindful of safe areas and privacy descriptions in `build.settings`.
- **Simulator**: Use the platform detection logic in `main.lua` to avoid unnecessary warnings (e.g., key event listeners on iOS skins).
