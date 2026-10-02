--
-- created with TexturePacker - https://www.codeandweb.com/texturepacker
--
-- $TexturePacker:SmartUpdate:3a073b9b08910d0e29013adeb2e3cef3:48d44890ca003d206b2fdd5f29a9171b:426db0d955d6907b7571fbc9dea91f89$
--
-- local sheetInfo = require("mysheet")
-- local myImageSheet = graphics.newImageSheet( "mysheet.png", sheetInfo:getSheet() )
-- local sprite = display.newSprite( myImageSheet , {frames={sheetInfo:getFrameIndex("sprite")}} )
--

local SheetInfo = {}

SheetInfo.sheet =
{
    frames = {
    
        {
            -- Zombie1-run-with-shadow-down-0
            x=1,
            y=77,
            width=22,
            height=32,

            sourceX = 19,
            sourceY = 14,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-run-with-shadow-down-1
            x=1,
            y=213,
            width=22,
            height=30,

            sourceX = 19,
            sourceY = 16,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-run-with-shadow-down-2
            x=1,
            y=111,
            width=22,
            height=32,

            sourceX = 20,
            sourceY = 14,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-run-with-shadow-down-3
            x=1,
            y=1,
            width=22,
            height=36,

            sourceX = 20,
            sourceY = 10,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-run-with-shadow-down-4
            x=1,
            y=145,
            width=22,
            height=32,

            sourceX = 21,
            sourceY = 14,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-run-with-shadow-down-5
            x=1,
            y=245,
            width=22,
            height=30,

            sourceX = 21,
            sourceY = 16,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-run-with-shadow-down-6
            x=1,
            y=179,
            width=22,
            height=32,

            sourceX = 21,
            sourceY = 14,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-run-with-shadow-down-7
            x=1,
            y=39,
            width=22,
            height=36,

            sourceX = 20,
            sourceY = 10,
            sourceWidth = 64,
            sourceHeight = 64
        },
    },

    sheetContentWidth = 24,
    sheetContentHeight = 276
}

SheetInfo.frameIndex =
{
    ["Zombie1-run-with-shadow-down-0"] = 1,
    ["Zombie1-run-with-shadow-down-1"] = 2,
    ["Zombie1-run-with-shadow-down-2"] = 3,
    ["Zombie1-run-with-shadow-down-3"] = 4,
    ["Zombie1-run-with-shadow-down-4"] = 5,
    ["Zombie1-run-with-shadow-down-5"] = 6,
    ["Zombie1-run-with-shadow-down-6"] = 7,
    ["Zombie1-run-with-shadow-down-7"] = 8,
}

SheetInfo.animation = 
{
   ["Zombie1-run-with-shadow-down"] = { 1, 2, 3, 4, 5, 6, 7, 8 }
}

function SheetInfo:getSheet()
    return self.sheet;
end

function SheetInfo:getFrameIndex(name)
    return self.frameIndex[name];
end

function SheetInfo:getAnimation(name)
    return self.animation[name];
end

return SheetInfo
