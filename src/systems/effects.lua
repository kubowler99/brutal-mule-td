-- Effects
-- Visual feedback: hit sparks, floating damage numbers, and screen shake.
-- Everything is cosmetic; failures are swallowed so effects never break play.

local M = {}

-- Floating damage numbers
local NUMBER_RISE = 30         -- pixels the number floats up
local NUMBER_TIME_MS = 500
local MAX_NUMBERS = 40         -- skip new numbers past this many on screen
local NUMBER_COLOR = {1, 1, 1}
local KILL_NUMBER_COLOR = {1, 0.85, 0.3}

-- Hit sparks
local SPARK_RADIUS = 6
local SPARK_TIME_MS = 200
local SPARK_COLOR = {1, 0.95, 0.6}

-- Internal state
local effectGroup = nil
local shakeTarget = nil
local shakeIntensity = 0
local shakeRemaining = 0
local activeNumbers = 0

--- Set where effects are drawn and what shakes
-- @param group table Display group for sparks and numbers
-- @param target table|nil Display object to shake (default: group)
function M.initialize(group, target)
  effectGroup = group
  shakeTarget = target or group
  shakeIntensity = 0
  shakeRemaining = 0
  activeNumbers = 0
end

--- Number of damage numbers currently on screen
function M.getActiveNumberCount()
  return activeNumbers
end

--- Float a damage number up from a point
-- @param x number X position
-- @param y number Y position
-- @param amount number Damage dealt
-- @param killed boolean|nil True to show it in the kill color
function M.damageNumber(x, y, amount, killed)
  if not effectGroup or activeNumbers >= MAX_NUMBERS then
    return
  end

  pcall(function()
    local text = display.newText({
      parent = effectGroup,
      text = tostring(math.floor(amount + 0.5)),
      x = x,
      y = y - 20,
      font = native.systemFontBold,
      fontSize = killed and 22 or 16
    })
    local color = killed and KILL_NUMBER_COLOR or NUMBER_COLOR
    text:setFillColor(color[1], color[2], color[3])

    activeNumbers = activeNumbers + 1
    transition.to(text, {
      time = NUMBER_TIME_MS,
      y = text.y - NUMBER_RISE,
      alpha = 0,
      onComplete = function()
        activeNumbers = math.max(0, activeNumbers - 1)
        if text.removeSelf then
          text:removeSelf()
        end
      end
    })
  end)
end

--- Flash a short spark at a hit point
-- @param x number X position
-- @param y number Y position
function M.hitSpark(x, y)
  if not effectGroup then
    return
  end

  pcall(function()
    local spark = display.newCircle(effectGroup, x, y, SPARK_RADIUS)
    spark:setFillColor(SPARK_COLOR[1], SPARK_COLOR[2], SPARK_COLOR[3])
    transition.to(spark, {
      time = SPARK_TIME_MS,
      xScale = 2,
      yScale = 2,
      alpha = 0,
      onComplete = function()
        if spark.removeSelf then
          spark:removeSelf()
        end
      end
    })
  end)
end

--- Start (or extend) a screen shake
-- A stronger or longer shake replaces a weaker one in progress.
-- @param intensity number Maximum offset in pixels
-- @param duration number Seconds
function M.screenShake(intensity, duration)
  shakeIntensity = math.max(shakeIntensity, intensity)
  shakeRemaining = math.max(shakeRemaining, duration)
end

--- Whether a shake is in progress
function M.isShaking()
  return shakeRemaining > 0
end

--- Move the shake target for this frame (call from the game loop)
-- @param dt number Delta time in seconds
function M.update(dt)
  if not shakeTarget then
    return
  end

  if shakeRemaining > 0 then
    shakeRemaining = shakeRemaining - dt
    if shakeRemaining > 0 then
      shakeTarget.x = (math.random() * 2 - 1) * shakeIntensity
      shakeTarget.y = (math.random() * 2 - 1) * shakeIntensity
      return
    end
  end

  -- Shake over: settle back in place
  shakeRemaining = 0
  shakeIntensity = 0
  shakeTarget.x = 0
  shakeTarget.y = 0
end

--- Stop shaking and forget the display group
function M.cleanup()
  if shakeTarget then
    shakeTarget.x = 0
    shakeTarget.y = 0
  end
  effectGroup = nil
  shakeTarget = nil
  shakeIntensity = 0
  shakeRemaining = 0
  activeNumbers = 0
end

return M
