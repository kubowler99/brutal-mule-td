# Technology Stack

## Engine & Language

- **Engine**: Solar2D (formerly Corona SDK)
- **Language**: Lua 5.1
- **Platform**: Cross-platform (iOS, Android, macOS, Windows)

## Core Libraries

- **middleclass.lua**: OOP class system with inheritance and mixins (global `Class`)
- **stateful.lua**: State machine extension for middleclass (global `Stateful`)
- **composer**: Built-in Solar2D scene management library
- **json**: Built-in JSON encoding/decoding

## Development Tools

- **Busted**: Unit testing framework for Lua
- **LuaCov**: Code coverage analysis (optional)
- **LuaCheck**: Static analysis and linting (optional)
- **LDoc**: Documentation generator from code comments (optional)
- **LuaRocks**: Package manager for Lua dependencies

## Configuration Files

- `.luarc.json`: Lua Language Server configuration for IDE autocomplete
- `config.ld`: LDoc documentation generator settings
- `*.rockspec`: LuaRocks package specification

## Common Commands

### Running the Project
```bash
# Open in Solar2D Simulator
# File > Open > Select project directory
```

### Testing
```bash
# Install Busted (one-time)
luarocks install busted

# Run all tests
busted

# Run specific test file
busted tests/utils/math_spec.lua

# Run with coverage (requires LuaCov)
busted --coverage
luacov
```

### Linting
```bash
# Install LuaCheck (one-time)
luarocks install luacheck

# Lint all Lua files
luacheck src/ tests/

# Lint specific file
luacheck src/utils/math.lua
```

### Documentation
```bash
# Install LDoc (one-time)
luarocks install ldoc

# Generate documentation
ldoc .
```

### Building
```bash
# Builds are created through Solar2D Simulator:
# File > Build > [Platform]
# - iOS: Requires macOS and Xcode
# - Android: Generates APK/AAB
# - Desktop: Creates executable for current platform
```

## Build Configuration

- **Resolution**: 720x1280 (portrait)
- **Scaling**: Letterbox with center alignment
- **FPS**: 60
- **Image Suffixes**: @2x (2x), @4x (4x) for adaptive resolution
- **Orientation**: Portrait only (portrait, portraitUpsideDown)

## Platform-Specific Notes

### Android
- Requires permissions in `build.settings` (INTERNET, BILLING)
- Version code must be incremented for updates
- Hardware back button handling required

### iOS
- Privacy descriptions mandatory in plist
- xcassets for app icons
- Status bar hidden by default
- SkAdNetwork warnings in simulator are normal

### Desktop
- Window is resizable
- Default view: 360x640
- Title configurable in `build.settings`
