require("tests.spec_helper")

local helpers = require("src.utils.helpers")

describe("helpers.newBackground", function()
    local group

    before_each(function()
        group = display.newGroup()
    end)

    it("scales the image to cover the screen and centers it", function()
        local background = helpers.newBackground(group, "game")
        assert.are.equal("assets/images/backgrounds/game.png", background.filename)
        -- 288x512 scales by 2.5 to exactly 720x1280
        assert.are.equal(720, background.width)
        assert.are.equal(1280, background.height)
        assert.are.equal(helpers.centerX, background.x)
        assert.are.equal(helpers.centerY, background.y)
        assert.are.equal(1, group.numChildren)
    end)

    it("keeps the aspect ratio and never leaves a gap", function()
        for name, info in pairs(helpers.BACKGROUNDS) do
            local background = helpers.newBackground(group, name)
            assert.is_true(background.width >= helpers.width, name .. " too narrow")
            assert.is_true(background.height >= helpers.height, name .. " too short")
            assert.is_true(math.abs(background.width / background.height - info.width / info.height) < 1e-9,
                name .. " aspect ratio changed")
        end
    end)

    it("falls back to a plain rectangle for an unknown background", function()
        local background = helpers.newBackground(group, "nope")
        assert.is_nil(background.filename)
        assert.are.equal(helpers.width, background.width)
        assert.are.equal(helpers.height, background.height)
    end)
end)
