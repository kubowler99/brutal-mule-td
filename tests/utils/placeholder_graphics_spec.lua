---
-- Unit tests for placeholder_graphics module
---

require("tests.spec_helper")
local placeholderGraphics = require("src.utils.placeholder_graphics")

describe("Placeholder Graphics", function()
    describe("createHeroSprite", function()
        it("should create a display group", function()
            local sprite = placeholderGraphics.createHeroSprite(100, 200)
            
            assert.is_not_nil(sprite)
            assert.equals("group", sprite._type)
            assert.equals(100, sprite.x)
            assert.equals(200, sprite.y)
        end)
        
        it("should contain multiple display objects", function()
            local sprite = placeholderGraphics.createHeroSprite(0, 0)
            
            -- Should have at least 3 objects (body, border, glow)
            assert.is_true(sprite.numChildren >= 3)
        end)
    end)
    
    describe("createWalkerSprite", function()
        it("should create a display group", function()
            local sprite = placeholderGraphics.createWalkerSprite(150, 250)
            
            assert.is_not_nil(sprite)
            assert.equals("group", sprite._type)
            assert.equals(150, sprite.x)
            assert.equals(250, sprite.y)
        end)
        
        it("should contain multiple display objects", function()
            local sprite = placeholderGraphics.createWalkerSprite(0, 0)
            
            -- Should have at least 2 objects (body, border)
            assert.is_true(sprite.numChildren >= 2)
        end)
    end)
    
    describe("createProjectileSprite", function()
        it("should create a display group", function()
            local sprite = placeholderGraphics.createProjectileSprite(50, 75)
            
            assert.is_not_nil(sprite)
            assert.equals("group", sprite._type)
            assert.equals(50, sprite.x)
            assert.equals(75, sprite.y)
        end)
        
        it("should contain multiple display objects", function()
            local sprite = placeholderGraphics.createProjectileSprite(0, 0)
            
            -- Should have at least 2 objects (body, glow)
            assert.is_true(sprite.numChildren >= 2)
        end)
    end)
    
    describe("createXPOrbSprite", function()
        it("should create a display group", function()
            local sprite = placeholderGraphics.createXPOrbSprite(300, 400)
            
            assert.is_not_nil(sprite)
            assert.equals("group", sprite._type)
            assert.equals(300, sprite.x)
            assert.equals(400, sprite.y)
        end)
        
        it("should contain multiple display objects for glow effect", function()
            local sprite = placeholderGraphics.createXPOrbSprite(0, 0)
            
            -- Should have at least 3 objects (outer glow, inner glow, core)
            assert.is_true(sprite.numChildren >= 3)
        end)
    end)
    
    describe("createBackground", function()
        it("should create a display group", function()
            local bg = placeholderGraphics.createBackground(720, 1280)
            
            assert.is_not_nil(bg)
            assert.equals("group", bg._type)
        end)
        
        it("should contain multiple stripes for gradient effect", function()
            local bg = placeholderGraphics.createBackground(720, 1280)
            
            -- Should have multiple stripes (at least 5)
            assert.is_true(bg.numChildren >= 5)
        end)
    end)
    
    describe("createUpgradeIcon", function()
        it("should create damage icon", function()
            local icon = placeholderGraphics.createUpgradeIcon("damage")
            
            assert.is_not_nil(icon)
            assert.equals("group", icon._type)
            assert.is_true(icon.numChildren >= 1)
        end)
        
        it("should create speed icon", function()
            local icon = placeholderGraphics.createUpgradeIcon("speed")
            
            assert.is_not_nil(icon)
            assert.equals("group", icon._type)
            assert.is_true(icon.numChildren >= 1)
        end)
        
        it("should create count icon", function()
            local icon = placeholderGraphics.createUpgradeIcon("count")
            
            assert.is_not_nil(icon)
            assert.equals("group", icon._type)
            assert.is_true(icon.numChildren >= 1)
        end)
        
        it("should create pierce icon", function()
            local icon = placeholderGraphics.createUpgradeIcon("pierce")
            
            assert.is_not_nil(icon)
            assert.equals("group", icon._type)
            assert.is_true(icon.numChildren >= 1)
        end)
        
        it("should create radius icon", function()
            local icon = placeholderGraphics.createUpgradeIcon("radius")
            
            assert.is_not_nil(icon)
            assert.equals("group", icon._type)
            assert.is_true(icon.numChildren >= 1)
        end)
        
        it("should create default icon for unknown type", function()
            local icon = placeholderGraphics.createUpgradeIcon("unknown")
            
            assert.is_not_nil(icon)
            assert.equals("group", icon._type)
            assert.is_true(icon.numChildren >= 1)
        end)
    end)
end)
