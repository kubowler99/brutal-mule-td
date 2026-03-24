# Solar2D Professional Project Template

A professional, production-ready scaffolding for Solar2D (formerly Corona SDK) games. This template implements best practices for project organization, scene management, data persistence, and cross-platform compatibility.

## Project Structure

```text
MyGame/
├── main.lua                    # Entry point
├── config.lua                  # App configuration
├── build.settings              # Build settings
├── .luarc.json                 # Lua Language Server configuration
├── config.ld                   # LDoc documentation configuration
├── *.rockspec                  # LuaRocks package specification
├── Icon.png                    # App icon (1024x1024)
├── Icon-Small.png             # Small icon
│
├── src/
│   ├── scenes/                # Scene files
│   │   ├── menu.lua
│   │   ├── game.lua
│   │   ├── pause.lua
│   │   └── gameover.lua
│   │
│   ├── entities/              # Game objects/entities
│   │   ├── player.lua
│   │   └── enemy.lua
│   │
│   ├── controllers/           # Business logic / Game loop controllers
│   │   └── gameController.lua
│   │
│   ├── models/                # Data models and state management
│   │   ├── data.lua           # Persistent game data
│   │   └── settings.lua       # User settings
│   │
│   ├── systems/               # Core game systems
│   │   ├── physics.lua
│   │   ├── collision.lua
│   │   └── particles.lua
│   │
│   ├── ui/                    # UI components
│   │   ├── button.lua
│   │   ├── panel.lua
│   │   └── healthbar.lua
│   │
│   ├── constants/             # Global constants
│   │   └── colors.lua
│   │
│   └── utils/                 # Utility modules
│       ├── helpers.lua        # UI Facade and shortcuts
│       ├── screen.lua         # Screen metric utilities
│       ├── device.lua         # Device/Platform flags
│       ├── math.lua           # Game-specific math
│       ├── string.lua         # String helpers
│       ├── taskQueue.lua      # Time-aware task scheduling
│       ├── pool.lua           # Object pooling system
│       ├── i18n.lua           # Localization
│       └── logger.lua         # Custom logging
│
├── lib/                       # Third-party libraries
│   ├── middleclass.lua        # OOP Class system
│   └── stateful.lua           # State Machine for classes
├── assets/
│   ├── images/
│   │   ├── backgrounds/
│   │   ├── sprites/
│   │   ├── ui/
│   │   └── effects/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   ├── fonts/
│   └── particles/             # Particle definitions (.json)
│
├── data/                      # Game data files
│   ├── levels.json
│   ├── enemies.json
│   └── strings.json           # Localization strings
│
├── docs/                      # Project documentation and design notes
│   ├── design.md
│   ├── ARCHITECTURE.md
│   └── PROJECT-STRUCTURE.md
│
├── tests/                     # Unit tests
│   ├── spec_helper.lua        # Test environment and Solar2D mocks
│   ├── utils/                 # Tests for src/utils/
│   │   ├── math_spec.lua
│   │   └── string_spec.lua
│   └── models/                # Tests for src/models/
│       └── data_spec.lua
└── Icon.png                   # App icon (1024x1024)
```

---

## Core Files

### 1. config.lua

Standard configuration for 720x1280 resolution with letterbox scaling and adaptive high-resolution asset support.

### 2. build.settings

Modern build settings including:

- Android permissions (`INTERNET`, `BILLING`).
- iOS Privacy descriptions (Camera, Photo Library).
- Desktop window settings.

### 3. main.lua

The entry point of the application, featuring:

- Global unhandled error handling to prevent crashes.
- Android hardware back button management.
- Intelligent platform detection to silence iOS simulator warnings.
- Game data initialization and scene routing.

### 4. .luarc.json

Configuration file for the [Lua Language Server](https://github.com/LuaLS/lua-language-server). It pre-defines Solar2D globals (like `display`, `transition`, `Runtime`) to provide better autocomplete and linting in IDEs like VS Code and IntelliJ IDEA.

### 5. solar2d-game-template-0.1.0-1.rockspec

A template for [LuaRocks](https://luarocks.org/), the package manager for Lua. This allows you to define project metadata and manage external Lua dependencies if your project uses them.

### 6. config.ld

Configuration file for [LDoc](https://github.com/lunarmodules/LDoc), the documentation generator for Lua. It defines which files to document and where to output the generated HTML.

### 7. middleclass.lua

A lightweight Object-Orientation library for Lua. It provides a standard `class()` function to create classes with inheritance, mixins, and constructors (`initialize`).

### 8. stateful.lua

An extension for `middleclass` that adds state machine support to classes. It allows objects to change their behavior by switching between different states (e.g., `Moving`, `Attacking`, `Idle`).

---

## Utility Modules

- **src/models/data.lua**: Handles persistent game data (save/load) with dot-notation access and sandbox mode support.
- **src/utils/helpers.lua**: UI shortcuts and a robust `newButton` implementation.
- **src/utils/screen.lua**: Standardized display metrics and safe area handling.
- **src/utils/device.lua**: Platform and device detection flags.
- **src/utils/math.lua**: Common mathematical functions like `clamp`, `lerp`, and `lengthDir`.
- **src/utils/string.lua**: String manipulation helpers (split, trim, etc.).
- **src/utils/taskQueue.lua**: Frame-independent task scheduling (supports time-scaling).
- **src/utils/pool.lua**: Generic object pooling system.

---

## Getting Started

1. **Install Solar2D**: Download from [https://solar2d.com/](https://solar2d.com/)
2. **Clone/Copy This Template**: Use this repository as the base for your new game project.
3. **Add Assets**: Place your images, sounds, and fonts in the `assets/` folder.
4. **Configure**: Adjust `config.lua` and `build.settings` for your specific game requirements.
5. **Build Scenes**: Create your game scenes in `src/scenes/` using the Composer library.
6. **Test**: Run in the Solar2D Simulator and test on physical devices early and often.
7. **Build**: Use the Solar2D Simulator to create builds for iOS, Android, or Desktop.

## Best Practices

- **Centralized State**: Use modules (like `src/models/data.lua`) instead of global variables (`_G`) for data persistence.
- **Scene Management**: Use Composer and strictly follow the lifecycle (`create`, `show`, `hide`, `destroy`).
- **Memory Management**: Always clean up timers, transitions, and event listeners in `scene:hide` (phase "will") or `scene:destroy`.
- **Content Scaling**: Use a high base resolution (e.g., 720x1280) and `display.contentCenterX` etc., for responsive UI.
- **Localization**: Implement a string look-up system early to support multiple languages.
- **Android Back Button**: Always implement a "key" event listener to handle the hardware back button (demonstrated in `main.lua`).
- **Class/Inheritance**: Provided by `middleclass.lua` and registered as a global `Class` in `main.lua`.
- **State Management**: Use `stateful.lua` (registered as `Stateful`) for complex entity behavior and state machines.
- **Safe I/O**: Use `pcall` when encoding/decoding JSON and check for file existence to prevent crashes.
- **Dependency Management**: A `.rockspec` template is included. For a professional workflow, consider using LuaRocks to install:
  - **busted**: For unit testing.
  - **luacheck**: For static analysis and catching common Lua errors.
  - **ldoc**: For generating API documentation from source code comments.
- **Profiling**: Regularly use the Solar2D Profiler to check for memory leaks and high CPU usage.
- **Unit Testing**: A standardized `tests/` directory is provided. Use [Busted](https://olivinelabs.com/busted/) for unit testing logic in `src/`. Mocks for Solar2D globals are provided in `tests/spec_helper.lua`.
- **Asset Optimization**: Use `@2x` and `@4x` suffixes for high-resolution assets to save memory on older devices.
- **Error Handling**: Use a custom logger that can be disabled in production builds.
- **Plugin Management**: Only include necessary plugins in `build.settings` to keep the binary size small.
