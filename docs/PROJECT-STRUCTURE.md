# Solar2D Professional Project Scaffolding

## Project Structure

```
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

---

## Core Files

### 1. config.lua
```lua
application = {
    content = {
        width = 720,
        height = 1280,
        scale = "letterbox",
        fps = 60,
        
        xAlign = "center",
        yAlign = "center",

        imageSuffix = {
            ["@2x"] = 2,
            ["@4x"] = 4,
        },
    },
    -- Use adaptive FPS for better battery life when possible
    -- (Requires specific plugins or implementation)
}
```

### 2. build.settings
```lua
settings = {
    orientation = {
        default = "portrait",
        supported = { "portrait", "portraitUpsideDown" }
    },
    
    android = {
        usesPermissions = {
            "android.permission.INTERNET",
            "com.android.vending.BILLING", -- Common for games
        },
        versionCode = "1",
    },
    
    iphone = {
        xcassets = "Images.xcassets",
        plist = {
            UIStatusBarHidden = true,
            UILaunchStoryboardName = "LaunchScreen",
            -- Privacy descriptions (Mandatory for modern iOS)
            NSCameraUsageDescription = "This app does not use the camera.",
            NSPhotoLibraryUsageDescription = "This app does not use the photo library.",
            -- NSAdvertisingAttributionReportEndpoint = "https://postbacks-is.com", -- For SkAdNetwork (Note: Warning in simulator is normal)
            CFBundleIconFiles = {
                "Icon.png",
                "Icon@2x.png",
                "Icon-60.png",
                "Icon-60@2x.png",
                "Icon-60@3x.png",
                "Icon-76.png",
                "Icon-76@2x.png",
                "Icon-Small-40.png",
                "Icon-Small-40@2x.png",
                "Icon-Small.png",
                "Icon-Small@2x.png",
                "Icon-Small@3x.png"
            },
        },
    },

    window = {
        defaultMode = "normal",
        defaultViewWidth = 360,
        defaultViewHeight = 640,
        resizable = true,
        titleText = {
            default = "My Game",
        },
    },
    
    plugins = {
        -- Example: ["plugin.json"] = { publisherId = "com.coronalabs" },
    },
}
```

### 3. main.lua
```lua
-- Global modules
_G.Class = require("lib.middleclass")
_G.Stateful = require("lib.stateful")
local composer = require("composer")
local state = require("src.models.data")

-- Hide status bar
display.setStatusBar(display.HiddenStatusBar)

-- Seed random
math.randomseed(os.time())

-- Global Error Handler
local function onUnhandledError(event)
    print("[ERROR] Unhandled Error: " .. tostring(event.errorMessage))
    -- Log to analytics or file
    return true -- Prevents app from crashing in some environments
end
Runtime:addEventListener("unhandledError", onUnhandledError)

-- Android Back Button Handler
local function onKeyEvent(event)
    if event.keyName == "back" and event.phase == "up" then
        local currentScene = composer.getSceneName("current")
        if currentScene == "src.scenes.menu" then
            native.requestExit()
        else
            composer.gotoScene("src.scenes.menu", { effect = "fade", time = 300 })
        end
        return true
    end
    return false
end

-- Only add the key listener on Android and Simulator (excluding iOS skins) to avoid warnings
local platform = system.getInfo("platform")
local env = system.getInfo("environment")
if (platform == "android") or (env == "simulator" and platform ~= "ios") then
    Runtime:addEventListener("key", onKeyEvent)
end

-- Initialize and Load Game Data
state.load()

-- Go to menu scene
composer.gotoScene("src.scenes.menu")
```

---

## Utility Modules

### src/models/data.lua
```lua
local json = require("json")
local M = {}

M.filename = "gamedata.json"
M.defaultData = {
    settings = {
        soundOn = true,
        musicOn = true,
    },
    score = 0,
    highScore = 0,
    sessions = 0,
    firstRun = os.time(),
}

M.data = {}
local isSandboxMode = false
local sandboxData = nil

-- Getter with dot notation support
function M.get(path)
    -- implementation details...
end

-- Setter with dot notation support
function M.set(path, value, shouldSave)
    -- implementation details...
end

function M.load()
    -- Safe load and session tracking...
end

function M.save()
    -- Safe save with sandbox protection...
end

function M.startSandbox()
    -- Initialize sandboxData...
end

return M
```

### src/utils/helpers.lua
```lua
local M = {}

-- Display shortcuts
M.centerX = display.contentCenterX
M.centerY = display.contentCenterY
M.width = display.contentWidth
M.height = display.contentHeight
M.screenOriginX = display.screenOriginX
M.screenOriginY = display.screenOriginY
M.actualWidth = display.actualContentWidth
M.actualHeight = display.actualContentHeight

-- Create a simple button
function M.newButton(options)
    local btn = display.newRect(
        options.x or 0,
        options.y or 0,
        options.width or 100,
        options.height or 40
    )
    btn:setFillColor(unpack(options.fillColor or {0.2, 0.5, 1}))
    btn.strokeWidth = 2
    btn:setStrokeColor(1, 1, 1)
    
    local label = display.newText({
        text = options.label or "Button",
        x = btn.x,
        y = btn.y,
        font = native.systemFontBold,
        fontSize = options.fontSize or 18
    })
    
    local function touch(event)
        local phase = event.phase
        if phase == "began" then
            display.getCurrentStage():setFocus(btn)
            btn.isFocus = true
            btn:setFillColor(0.1, 0.3, 0.8)
        elseif btn.isFocus then
            if phase == "moved" then
                -- Optional: change color if finger moves out of bounds
                local bounds = btn.contentBounds
                local x, y = event.x, event.y
                if (x < bounds.xMin or x > bounds.xMax or y < bounds.yMin or y > bounds.yMax) then
                    btn:setFillColor(unpack(options.fillColor or {0.2, 0.5, 1}))
                else
                    btn:setFillColor(0.1, 0.3, 0.8)
                end
            elseif phase == "ended" or phase == "cancelled" then
                display.getCurrentStage():setFocus(nil)
                btn.isFocus = false
                btn:setFillColor(unpack(options.fillColor or {0.2, 0.5, 1}))
                
                if phase == "ended" then
                    local bounds = btn.contentBounds
                    local x, y = event.x, event.y
                    if (x >= bounds.xMin and x <= bounds.xMax and y >= bounds.yMin and y <= bounds.yMax) then
                        if options.onRelease then
                            options.onRelease(event)
                        end
                    end
                end
            end
        end
        return true
    end
    
    btn:addEventListener("touch", touch)
    
    btn.label = label
    return btn
end

-- Clean up display group
function M.cleanGroup(group)
    if group then
        while group.numChildren > 0 do
            display.remove(group[1])
        end
    end
end

-- Print table contents (debug)
function M.printTable(t, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)
    
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(spacing .. tostring(k) .. ":")
            M.printTable(v, indent + 1)
        else
            print(spacing .. tostring(k) .. ": " .. tostring(v))
        end
    end
end

return M
```

### src/utils/math.lua
```lua
local M = {}

-- Clamp value between min and max
function M.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Linear interpolation
function M.lerp(a, b, t)
    return a + (b - a) * t
end

-- Distance between two points
function M.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Angle between two points (in degrees)
function M.angleBetween(x1, y1, x2, y2)
    return math.deg(math.atan2(y2 - y1, x2 - x1))
end

-- Round to nearest integer
function M.round(num)
    return math.floor(num + 0.5)
end

-- Random float between min and max
function M.randomFloat(min, max)
    return min + math.random() * (max - min)
end

return M
```

---

## Scene Template

### src/scenes/menu.lua
```lua
local composer = require("composer")
local helpers = require("src.utils.helpers")
local state = require("src.models.data")

local scene = composer.newScene()

-- Scene variables
local background
local titleText
local playButton

-- Scene lifecycle functions

function scene:create(event)
    local sceneGroup = self.view
    local params = event.params or {} -- Access passed parameters
    
    -- Background
    background = display.newRect(
        sceneGroup,
        helpers.centerX,
        helpers.centerY,
        helpers.width,
        helpers.height
    )
    background:setFillColor(0.1, 0.1, 0.2)
    
    -- Title
    titleText = display.newText({
        parent = sceneGroup,
        text = "My Game",
        x = helpers.centerX,
        y = 100,
        font = native.systemFontBold,
        fontSize = 48
    })
    
    -- Play button
    playButton = helpers.newButton({
        x = helpers.centerX,
        y = helpers.centerY,
        width = 200,
        height = 60,
        label = "PLAY",
        fontSize = 24,
        onRelease = function()
            composer.gotoScene("src.scenes.game", {
                effect = "fade",
                time = 300,
                params = { difficulty = "easy" } -- Example parameter passing
            })
        end
    })
    sceneGroup:insert(playButton)
    sceneGroup:insert(playButton.label)
end

function scene:show(event)
    local sceneGroup = self.view
    local phase = event.phase
    
    if phase == "will" then
        -- Code here runs when scene is still off screen
    elseif phase == "did" then
        -- Code here runs when scene is on screen
        -- Start timers, music, or physics
    end
end

function scene:hide(event)
    local sceneGroup = self.view
    local phase = event.phase
    
    if phase == "will" then
        -- Code here runs when scene is still on screen
        -- Stop timers, music, or physics
    elseif phase == "did" then
        -- Code here runs when scene is off screen
    end
end

function scene:destroy(event)
    local sceneGroup = self.view
    -- Clean up scene resources, remove listeners
    if playButton then
        -- The label is not a child of playButton but was inserted into sceneGroup separately
        -- so it will be cleaned up by composer, but it's good practice to nil references.
        playButton = nil
    end
end

-- Scene event listeners
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
```

---

## Getting Started

1. **Install Solar2D**: Download from https://solar2d.com/
2. **Create Project**: Use the Solar2D Simulator to create a new project
3. **Copy Structure**: Implement the folder structure above
4. **Add Assets**: Place your images, sounds, and fonts in the assets folder
5. **Configure**: Adjust config.lua and build.settings for your game
6. **Build Scenes**: Create your game scenes using Composer
7. **Test**: Run in simulator, test on devices
8. **Build**: Create builds for iOS/Android

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
- **IDE Support**: A `.luarc.json` file is provided to pre-define Solar2D globals, enabling better autocomplete and linting in modern editors.
- **Dependency Management**: A `.rockspec` template is included. For a professional workflow, consider using LuaRocks to install:
    - **busted**: For unit testing (logic in `src/`).
    - **luacheck**: For static analysis and identifying potential bugs.
    - **ldoc**: For generating API documentation from source code comments.
- **Profiling**: Regularly use the Solar2D Profiler to check for memory leaks and high CPU usage.
- **Asset Optimization**: Use `@2x` and `@4x` suffixes for high-resolution assets to save memory on older devices.
- **Error Handling**: Use a custom logger that can be disabled in production builds.
- **Plugin Management**: Only include necessary plugins in `build.settings` to keep the binary size small.