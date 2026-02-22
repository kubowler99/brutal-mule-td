# Project Structure & Conventions

## Directory Organization

```
project/
├── main.lua                    # Entry point - initializes globals, error handling, scene routing
├── config.lua                  # App configuration (resolution, scaling, FPS)
├── build.settings              # Platform-specific build settings
├── gamedata.json              # Persistent game data (generated at runtime)
│
├── lib/                       # Third-party libraries
│   ├── middleclass.lua        # OOP system (global Class)
│   └── stateful.lua           # State machines (global Stateful)
│
├── src/                       # Source code (modular architecture)
│   ├── scenes/                # Composer scenes (menu, game, pause, gameover)
│   ├── entities/              # Game objects (player, enemy)
│   ├── controllers/           # Business logic and game loop controllers
│   ├── models/                # Data models and state management
│   ├── systems/               # Core game systems (physics, collision, particles)
│   ├── ui/                    # Reusable UI components (button, panel, healthbar)
│   ├── constants/             # Global constants (colors, config values)
│   └── utils/                 # Utility modules (helpers, math, screen, device, etc.)
│
├── assets/                    # Game assets
│   ├── images/                # Sprites, backgrounds, UI, effects
│   ├── audio/                 # Music and sound effects
│   ├── fonts/                 # Custom fonts
│   └── particles/             # Particle system definitions (.json)
│
├── data/                      # Game data files (.json)
├── docs/                      # Documentation
└── tests/                     # Unit tests (mirrors src/ structure)
    ├── spec_helper.lua        # Solar2D mocks for testing
    ├── utils/                 # Tests for src/utils/
    └── models/                # Tests for src/models/
```

## Module Conventions

### Requiring Modules
```lua
-- Use dot notation for paths
local helpers = require("src.utils.helpers")
local Player = require("src.entities.player")
local data = require("src.models.data")
```

### Module Pattern
```lua
-- Standard module structure
local M = {}

-- Module functions
function M.functionName(params)
    -- implementation
end

return M
```

### Class Pattern (OOP)
```lua
-- Using middleclass
local MyClass = Class("MyClass")
MyClass:include(Stateful)  -- Optional: for state machines

function MyClass:initialize(params)
    -- constructor
end

function MyClass:method()
    -- instance method
end

return MyClass
```

## Naming Conventions

- **Files**: lowercase with underscores (e.g., `game_controller.lua`)
- **Modules**: camelCase for module tables (e.g., `local M = {}`)
- **Classes**: PascalCase (e.g., `Player`, `GameController`)
- **Functions**: camelCase (e.g., `function M.calculateScore()`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH = 100`)
- **Private functions**: Prefix with underscore (e.g., `local function _helperFunction()`)

## Code Style

### Globals
- Avoid polluting `_G` except for essential libraries
- `Class` and `Stateful` are registered as globals in `main.lua`
- Use `local` for all other variables

### Comments
```lua
-- Single line comment

---@class ClassName
---@field fieldName type Description
-- LDoc-style annotations for documentation

--[[
    Multi-line comment
    for longer explanations
]]
```

### Error Handling
```lua
-- Use pcall for risky operations
local success, result = pcall(json.decode, jsonString)
if not success then
    print("Error decoding JSON:", result)
end
```

## Scene Lifecycle (Composer)

Scenes must implement these lifecycle methods:

```lua
function scene:create(event)
    -- Create display objects, add to sceneGroup
    -- Runs once when scene is first created
end

function scene:show(event)
    if event.phase == "will" then
        -- Scene is about to appear (still off-screen)
    elseif event.phase == "did" then
        -- Scene is fully on-screen
        -- Start timers, transitions, physics
    end
end

function scene:hide(event)
    if event.phase == "will" then
        -- Scene is about to disappear (still on-screen)
        -- Stop timers, transitions, physics
    elseif event.phase == "did" then
        -- Scene is fully off-screen
    end
end

function scene:destroy(event)
    -- Clean up resources, remove listeners
    -- Runs when scene is removed from memory
end
```

## Memory Management Rules

1. **Always add display objects to sceneGroup** in `scene:create()`
2. **Cancel timers and transitions** in `scene:hide(phase="will")`
3. **Remove event listeners** in `scene:hide()` or `scene:destroy()`
4. **Nil out references** to large objects when done
5. **Use object pooling** (`src/utils/pool.lua`) for frequently created/destroyed objects

## Testing Conventions

- Test files mirror source structure: `tests/utils/math_spec.lua` tests `src/utils/math.lua`
- Test files use `_spec.lua` suffix
- Always require `spec_helper.lua` first to mock Solar2D globals
- Use Busted's `describe` and `it` blocks for organization
- Focus on testing pure logic in `utils/` and `models/`

## Data Persistence

- Use `src/models/data.lua` for all persistent game data
- Never write directly to `_G` for state management
- Use dot notation for nested data access: `data.get("settings.sound.volume")`
- Enable sandbox mode during development: `data.startSandbox()`

## Platform Detection

Use `src/utils/device.lua` for platform-specific logic:
```lua
local device = require("src.utils.device")

if device.isAndroid then
    -- Android-specific code
elseif device.isIos then
    -- iOS-specific code
end
```

## Display Metrics

Use `src/utils/screen.lua` or `src/utils/helpers.lua` for consistent positioning:
```lua
local helpers = require("src.utils.helpers")

local obj = display.newRect(
    helpers.centerX,  -- Use helpers for positioning
    helpers.centerY,
    100, 100
)
```

## Asset Organization

- **Images**: Use `@2x` and `@4x` suffixes for high-res variants
- **Audio**: Separate music (streams) from sfx (loaded into memory)
- **Fonts**: Place custom fonts in `assets/fonts/`
- **Particles**: JSON definitions in `assets/particles/`
