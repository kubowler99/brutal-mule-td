---@class Device
---Device detection utility module
local M = {}

local platform = system.getInfo("platform")
local env = system.getInfo("environment")
local model = system.getInfo("model")

M.isSimulator = (env == "simulator")
M.isAndroid = (platform == "android")
M.isIos = (platform == "ios")
M.isApple = M.isIos or (platform == "macos")
M.isMobile = M.isAndroid or M.isIos

-- Aspect ratio flags
M.isTall = (display.pixelHeight / display.pixelWidth) > 1.5
M.isWide = (display.pixelWidth / display.pixelHeight) > 1.5

-- Specific iOS models detection (Simplified)
M.is_iPad = model:find("iPad") ~= nil
M.is_iPhone = model:find("iPhone") ~= nil

return M
