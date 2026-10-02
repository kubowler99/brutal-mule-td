--
-- created with TexturePacker - https://www.codeandweb.com/texturepacker
--
-- $TexturePacker:SmartUpdate:81a66e76cd39bd9117e51e0b20307180:f7020dea995c75c2b4477fa32fea2cf7:797cae04b452a827fae88e4b77b86a7d$
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
            -- Zombie1-Attack-With-Shadow-down-0
            x=35,
            y=1,
            width=22,
            height=32,

            sourceX = 19,
            sourceY = 14,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-Attack-With-Shadow-down-1
            x=31,
            y=175,
            width=20,
            height=34,

            sourceX = 21,
            sourceY = 12,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-Attack-With-Shadow-down-2
            x=31,
            y=137,
            width=20,
            height=36,

            sourceX = 21,
            sourceY = 10,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-Attack-With-Shadow-down-3
            x=1,
            y=1,
            width=32,
            height=30,

            sourceX = 15,
            sourceY = 16,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-Attack-With-Shadow-down-4
            x=1,
            y=33,
            width=30,
            height=36,

            sourceX = 16,
            sourceY = 17,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-Attack-With-Shadow-down-5
            x=1,
            y=175,
            width=28,
            height=40,

            sourceX = 17,
            sourceY = 18,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-Attack-With-Shadow-down-6
            x=33,
            y=35,
            width=24,
            height=48,

            sourceX = 19,
            sourceY = 15,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-Attack-With-Shadow-down-7
            x=1,
            y=71,
            width=28,
            height=50,

            sourceX = 17,
            sourceY = 14,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-Attack-With-Shadow-down-8
            x=31,
            y=85,
            width=26,
            height=50,

            sourceX = 17,
            sourceY = 14,
            sourceWidth = 64,
            sourceHeight = 64
        },
        {
            -- Zombie1-Attack-With-Shadow-down-9
            x=1,
            y=123,
            width=28,
            height=50,

            sourceX = 15,
            sourceY = 14,
            sourceWidth = 64,
            sourceHeight = 64
        },
    },

    sheetContentWidth = 58,
    sheetContentHeight = 216
}

SheetInfo.frameIndex =
{
    ["Zombie1-Attack-With-Shadow-down-0"] = 1,
    ["Zombie1-Attack-With-Shadow-down-1"] = 2,
    ["Zombie1-Attack-With-Shadow-down-2"] = 3,
    ["Zombie1-Attack-With-Shadow-down-3"] = 4,
    ["Zombie1-Attack-With-Shadow-down-4"] = 5,
    ["Zombie1-Attack-With-Shadow-down-5"] = 6,
    ["Zombie1-Attack-With-Shadow-down-6"] = 7,
    ["Zombie1-Attack-With-Shadow-down-7"] = 8,
    ["Zombie1-Attack-With-Shadow-down-8"] = 9,
    ["Zombie1-Attack-With-Shadow-down-9"] = 10,
}

SheetInfo.animation = 
{
   ["Zombie1-Attack-With-Shadow-down"] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
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
