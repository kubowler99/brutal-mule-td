# Visual Assets

## Current Status: Placeholder Graphics

This project currently uses **procedurally generated placeholder graphics** created via the `src/utils/placeholder_graphics.lua` module. These are simple vector shapes rendered using Solar2D's display API.

## Placeholder Graphics

The following placeholder graphics are available:

### Game Entities

1. **Hero Sprite** - Blue circle with white border and glow effect (50px diameter)
2. **Walker Sprite** - Red square with dark border (30x30px)
3. **Projectile Sprite** - Small cyan circle with glow (16px diameter)
4. **XP Orb Sprite** - Yellow/gold glowing circle with multiple glow layers (40px diameter)
5. **Background** - Dark gradient with subtle blue tint

### Upgrade Icons

The placeholder graphics module also generates upgrade icons for:
- **Damage** - Red sword/strike symbol
- **Speed** - Yellow lightning bolt
- **Count** - Green multiple dots
- **Pierce** - Orange arrow through target
- **Radius** - Blue expanding circles

## Usage

To use placeholder graphics in your entities:

```lua
local placeholderGraphics = require("src.utils.placeholder_graphics")

-- Create a hero sprite
local heroSprite = placeholderGraphics.createHeroSprite(x, y)

-- Create a walker sprite
local walkerSprite = placeholderGraphics.createWalkerSprite(x, y)

-- Create a projectile sprite
local projectileSprite = placeholderGraphics.createProjectileSprite(x, y)

-- Create an XP orb sprite
local xpOrbSprite = placeholderGraphics.createXPOrbSprite(x, y)

-- Create a background
local background = placeholderGraphics.createBackground(720, 1280)

-- Create an upgrade icon
local damageIcon = placeholderGraphics.createUpgradeIcon("damage")
```

## Future: Real Image Assets

When ready to replace placeholders with real artwork, place image files in the following directories:

### Directory Structure

```
assets/images/
├── sprites/
│   ├── hero.png          # Hero character sprite
│   ├── hero@2x.png       # 2x resolution variant
│   ├── hero@4x.png       # 4x resolution variant
│   ├── walker.png        # Walker enemy sprite
│   ├── walker@2x.png
│   ├── walker@4x.png
│   ├── projectile.png    # Projectile sprite
│   ├── projectile@2x.png
│   ├── projectile@4x.png
│   ├── xp_orb.png        # XP orb sprite
│   ├── xp_orb@2x.png
│   └── xp_orb@4x.png
├── backgrounds/
│   ├── game_bg.png       # Game background
│   ├── game_bg@2x.png
│   └── game_bg@4x.png
└── ui/
    └── upgrades/
        ├── damage.png    # Damage upgrade icon
        ├── speed.png     # Speed upgrade icon
        ├── count.png     # Count upgrade icon
        ├── pierce.png    # Pierce upgrade icon
        └── radius.png    # Radius upgrade icon
```

### Image Specifications

- **Base Resolution**: 720x1280 (portrait)
- **Image Suffixes**: Use `@2x` and `@4x` for adaptive resolution
- **Format**: PNG with transparency (except backgrounds)
- **Color Space**: sRGB

### Replacing Placeholders

To replace placeholder graphics with real images:

1. Place image files in the appropriate directories
2. Update entity initialization code to use `display.newImageRect()` instead of placeholder functions
3. Example:
   ```lua
   -- Old (placeholder)
   local heroSprite = placeholderGraphics.createHeroSprite(x, y)
   
   -- New (real image)
   local heroSprite = display.newImageRect("assets/images/sprites/hero.png", 50, 50)
   heroSprite.x = x
   heroSprite.y = y
   ```

## Benefits of Placeholder Approach

1. **Rapid Prototyping** - Start development immediately without waiting for art assets
2. **Clear Visual Distinction** - Different colors/shapes make entities easy to identify during testing
3. **No External Dependencies** - Everything is code-based and version controlled
4. **Easy Iteration** - Adjust sizes, colors, and effects by editing Lua code
5. **Consistent Sizing** - Ensures proper collision detection and gameplay balance before final art

## Notes

- Placeholder graphics are fully functional for MVP development and testing
- All gameplay mechanics work identically with placeholders or real images
- The visual style is intentionally simple to avoid confusion with final art
- Performance is excellent since vector graphics are lightweight
