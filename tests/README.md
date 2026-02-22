# Testing Infrastructure

This directory contains the test suite for Arcane Survivor MVP, including unit tests and property-based tests.

## Test Framework

- **Busted**: Unit testing framework for Lua
- **lua-quickcheck**: Property-based testing library

## Installation

### Install Busted (Unit Testing)

```bash
luarocks install busted
```

### Install lua-quickcheck (Property-Based Testing)

```bash
luarocks install lua-quickcheck
```

**Note**: lua-quickcheck is required for running property-based tests that validate universal correctness properties across all inputs.

## Running Tests

### Run All Tests

```bash
busted
```

### Run Specific Test File

```bash
busted tests/entities/hero_spec.lua
```

### Run Tests with Coverage

```bash
busted --coverage
luacov
```

## Test Structure

```
tests/
├── spec_helper.lua           # Solar2D mocks for testing
├── entities/                 # Tests for game entities
├── systems/                  # Tests for game systems
├── scenes/                   # Tests for Composer scenes
├── generators/               # Custom generators for property tests
│   └── game_generators.lua   # Generators for hero levels, positions, walkers, abilities
├── models/                   # Tests for data models
└── utils/                    # Tests for utility modules
```

## Custom Generators

The `generators/game_generators.lua` file provides custom generators for property-based testing:

- `heroLevel()`: Random hero levels (1-20)
- `position()`: Random positions within game area (0-720, 0-1280)
- `walker()`: Random walker configurations
- `ability()`: Random ability configurations
- `walkerArray(minSize, maxSize)`: Arrays of walkers

## Property Test Format

Property tests should reference their design document property:

```lua
-- Feature: arcane-survivor-mvp, Property 7: Spawn Rate Scaling
describe("Spawner System - Difficulty Scaling", function()
  it("adjusts spawn rate based on hero level", function()
    property.check(generators.heroLevel(), function(level)
      -- Test implementation
      return true
    end, {numTests = 100})
  end)
end)
```

## Solar2D Mocks

The `spec_helper.lua` file provides mocks for Solar2D globals:

- `display`: Display object creation and properties
- `system`: System information and file paths
- `Runtime`: Event handling
- `transition`: Transitions and animations
- `timer`: Timer functions
- `audio`: Audio playback
- `native`: Native UI elements
- `composer`: Scene management

Always require `spec_helper.lua` at the top of test files:

```lua
require("tests.spec_helper")
```

## Coverage Goals

- **Entities**: 80% line coverage
- **Systems**: 85% line coverage
- **Controllers**: 75% line coverage
- **UI Components**: 70% line coverage
- **Critical Paths**: 100% coverage (hero damage/death, spawning, XP, upgrades, collision)

## Testing Strategy

The project uses a dual testing approach:

1. **Unit Tests**: Validate specific examples, edge cases, and integration points
2. **Property Tests**: Verify universal properties across all inputs (100 iterations minimum)

Both types of tests are valuable and complement each other to ensure comprehensive correctness validation.
