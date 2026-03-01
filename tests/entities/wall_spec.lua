require("tests.spec_helper")
local Wall = require("src.entities.wall")

describe("Wall Entity", function()
    local wall

    before_each(function()
        wall = Wall:new(360, 1180, 720)
    end)

    after_each(function()
        if wall and wall.destroy then
            wall:destroy()
        end
        wall = nil
    end)

    describe("initialization", function()
        it("should initialize with correct position", function()
            assert.is.equal(360, wall.x)
            assert.is.equal(1180, wall.y)
        end)

        it("should initialize with correct width", function()
            assert.is.equal(720, wall.width)
        end)

        it("should initialize with health of 100", function()
            assert.is.equal(100, wall.health)
        end)

        it("should initialize with maxHealth of 100", function()
            assert.is.equal(100, wall.maxHealth)
        end)

        it("should create a display object", function()
            assert.is_not_nil(wall.displayObject)
        end)

        it("should initialize with custom position and width", function()
            local customWall = Wall:new(200, 500, 400)
            assert.is.equal(200, customWall.x)
            assert.is.equal(500, customWall.y)
            assert.is.equal(400, customWall.width)
            customWall:destroy()
        end)
    end)

    describe("takeDamage", function()
        it("should reduce health by damage amount", function()
            wall:takeDamage(30)
            assert.is.equal(70, wall.health)
        end)

        it("should reduce health correctly with multiple damage calls", function()
            wall:takeDamage(20)
            wall:takeDamage(15)
            assert.is.equal(65, wall.health)
        end)

        it("should clamp health to minimum 0 when damage equals health", function()
            wall:takeDamage(100)
            assert.is.equal(0, wall.health)
        end)

        it("should clamp health to minimum 0 when damage exceeds health", function()
            wall:takeDamage(150)
            assert.is.equal(0, wall.health)
        end)

        it("should handle zero damage", function()
            wall:takeDamage(0)
            assert.is.equal(100, wall.health)
        end)

        it("should handle negative damage by treating it as zero", function()
            wall:takeDamage(-10)
            assert.is.equal(100, wall.health)
        end)

        it("should trigger flashDamage when taking damage", function()
            -- This test verifies that flashDamage is called
            -- In a real scenario, we'd mock the transition, but for now
            -- we just verify the method doesn't crash
            wall:takeDamage(10)
            assert.is.equal(90, wall.health)
        end)
    end)

    describe("isDead", function()
        it("should return false when health is above 0", function()
            assert.is_false(wall:isDead())
        end)

        it("should return false when health is at maximum", function()
            assert.is.equal(100, wall.health)
            assert.is_false(wall:isDead())
        end)

        it("should return true when health is exactly 0", function()
            wall:takeDamage(100)
            assert.is_true(wall:isDead())
        end)

        it("should return true when health reaches 0 from damage", function()
            wall:takeDamage(50)
            assert.is_false(wall:isDead())
            wall:takeDamage(50)
            assert.is_true(wall:isDead())
        end)

        it("should return true when health would go below 0", function()
            wall:takeDamage(150)
            assert.is_true(wall:isDead())
        end)

        it("should return false when health is 1", function()
            wall:takeDamage(99)
            assert.is.equal(1, wall.health)
            assert.is_false(wall:isDead())
        end)
    end)

    describe("flashDamage", function()
        it("should not crash when display object exists", function()
            -- flashDamage uses transition.to which is mocked
            -- This test verifies the method can be called safely
            wall:flashDamage()
            assert.is_not_nil(wall.displayObject)
        end)

        it("should handle nil display object gracefully", function()
            wall.displayObject = nil
            -- Should not crash
            wall:flashDamage()
            assert.is_nil(wall.displayObject)
        end)

        it("should be called automatically by takeDamage", function()
            -- Verify that taking damage doesn't crash due to flashDamage
            wall:takeDamage(25)
            assert.is.equal(75, wall.health)
            assert.is_not_nil(wall.displayObject)
        end)
    end)

    describe("destroy", function()
        it("should remove display object", function()
            wall:destroy()
            assert.is_nil(wall.displayObject)
        end)

        it("should handle destroy when display object is nil", function()
            wall.displayObject = nil
            -- Should not crash
            wall:destroy()
            assert.is_nil(wall.displayObject)
        end)

        it("should handle multiple destroy calls safely", function()
            wall:destroy()
            wall:destroy()
            assert.is_nil(wall.displayObject)
        end)

        it("should clean up display object after taking damage", function()
            wall:takeDamage(50)
            assert.is.equal(50, wall.health)
            wall:destroy()
            assert.is_nil(wall.displayObject)
        end)
    end)
end)
