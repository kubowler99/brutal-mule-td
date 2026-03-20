-- Experience System
-- Manages XP accumulation and level-up triggers

local config_loader = require("src.models.config_loader")
local json = _G.json or require("json")

local experience_system = {}

-- State
experience_system.hero = nil
experience_system.onLevelUp = nil
experience_system.enemyConfig = nil

-- Initialize the level system
function experience_system.initialize(hero, onLevelUpCallback)
  experience_system.hero = hero
  experience_system.onLevelUp = onLevelUpCallback

  -- Load enemy configuration from data/enemies.json
  local success, config = pcall(function()
    local path = system.pathForFile("data/enemies.json", system.ResourceDirectory)
    if not path then
      error("Configuration file not found")
    end

    local file = io.open(path, "r")
    if not file then
      error("Failed to open configuration file")
    end

    local contents = file:read("*a")
    file:close()

    if not contents or contents == "" then
      error("Configuration file is empty")
    end

    local decoded = json.decode(contents)
    if not decoded then
      error("Failed to decode JSON")
    end

    return decoded
  end)

  if success and config then
    experience_system.enemyConfig = config
    print("Experience system: Loaded enemy configuration")
  else
    print("Warning: Failed to load enemy config, using defaults:", config)
    experience_system.enemyConfig = {}
  end
end

--- Get XP value for an enemy type
-- @param enemyType string The enemy type
-- @return number The XP value (or default if not configured)
function experience_system.getEnemyXPValue(enemyType)
  -- Default XP value for unconfigured or invalid enemy types
  local DEFAULT_XP = 10

  -- Validate enemy type parameter
  if type(enemyType) ~= "string" or enemyType == "" then
    print("Warning: Invalid enemy type for XP lookup, using default XP")
    return DEFAULT_XP
  end

  -- Check if configuration is loaded
  if not experience_system.enemyConfig then
    print("Warning: Enemy configuration not loaded, using default XP")
    return DEFAULT_XP
  end

  -- Look up enemy configuration
  local enemyData = experience_system.enemyConfig[enemyType]

  -- Check if enemy type exists in configuration
  if not enemyData then
    print("Warning: Enemy type '" .. enemyType .. "' not found in configuration, using default XP")
    return DEFAULT_XP
  end

  -- Check if xpValue field exists and is valid
  if type(enemyData.xpValue) ~= "number" then
    print("Warning: Invalid xpValue for enemy type '" .. enemyType .. "', using default XP")
    return DEFAULT_XP
  end

  -- Validate XP value is positive
  if enemyData.xpValue <= 0 then
    print("Warning: Non-positive xpValue for enemy type '" .. enemyType .. "', using default XP")
    return DEFAULT_XP
  end

  -- Return configured XP value
  return enemyData.xpValue
end

--- Award XP for defeating an enemy
-- @param enemyType string The type of enemy defeated (e.g., "walker")
-- @param x number X position of defeated enemy
-- @param y number Y position of defeated enemy
function experience_system.awardXP(enemyType, x, y)
  -- Check for nil hero reference
  if not experience_system.hero then
    print("Error: Cannot award XP, hero is nil")
    return
  end

  -- Validate enemy type (getEnemyXPValue handles invalid types)
  if type(enemyType) ~= "string" or enemyType == "" then
    print("Warning: Invalid enemy type, using default")
    enemyType = "walker"
  end

  -- Validate position coordinates
  if type(x) ~= "number" or type(y) ~= "number" then
    print("Warning: Invalid enemy position for XP feedback")
    -- Use hero position as fallback for feedback
    x, y = experience_system.hero.x, experience_system.hero.y
  end

  -- Get XP value for this enemy type
  local xpAmount = experience_system.getEnemyXPValue(enemyType)

  -- Award XP to hero
  experience_system.addXP(xpAmount)

  -- Trigger visual/audio feedback
  -- Note: showXPFeedback will be implemented in task 2.7
  local success, err = pcall(experience_system.showXPFeedback, xpAmount, x, y)
  if not success then
    print("Warning: XP feedback failed:", err)
    -- XP already awarded, continue
  end
end

--- Show XP gain feedback
-- @param amount number XP amount gained
-- @param x number X position for visual effect
-- @param y number Y position for visual effect
function experience_system.showXPFeedback(amount, x, y)
  -- Wrap entire feedback creation in pcall for error handling
  local success, err = pcall(function()
    -- Validate parameters
    if type(amount) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
      print("Warning: Invalid parameters for showXPFeedback")
      return
    end

    -- Create floating text showing "+X XP"
    local feedbackText = display.newText({
      text = "+" .. tostring(math.floor(amount)) .. " XP",
      x = x,
      y = y,
      font = native.systemFontBold,
      fontSize = 24
    })
    feedbackText:setFillColor(1, 0.9, 0.2) -- Gold/yellow color for XP
    feedbackText.anchorY = 0.5

    -- Create glow effect (circle behind text)
    local glowEffect = display.newCircle(x, y, 30)
    glowEffect:setFillColor(1, 0.9, 0.2, 0.3) -- Semi-transparent gold
    glowEffect.strokeWidth = 2
    glowEffect:setStrokeColor(1, 0.9, 0.2, 0.6)

    -- Animate floating text upward and fade out
    transition.to(feedbackText, {
      time = 1000,
      y = y - 50,
      alpha = 0,
      onComplete = function()
        -- Remove text after animation completes
        if feedbackText and feedbackText.removeSelf then
          feedbackText:removeSelf()
        end
      end
    })

    -- Animate glow effect (expand and fade)
    transition.to(glowEffect, {
      time = 1000,
      xScale = 1.5,
      yScale = 1.5,
      alpha = 0,
      onComplete = function()
        -- Remove glow after animation completes
        if glowEffect and glowEffect.removeSelf then
          glowEffect:removeSelf()
        end
      end
    })

    -- Play XP gain sound effect (wrapped in pcall since audio file may not exist)
    local audioSuccess, audioErr = pcall(function()
      -- Check if audio file exists before attempting to play
      local audioPath = system.pathForFile("assets/audio/sfx/xp_gain.wav", system.ResourceDirectory)
      if audioPath then
        audio.play(audio.loadSound("assets/audio/sfx/xp_gain.wav"))
      end
    end)

    if not audioSuccess then
      -- Silently fail for audio - not critical for gameplay
      -- Audio file may not exist yet, which is acceptable
    end
  end)

  if not success then
    print("Warning: XP feedback creation failed:", err)
    -- Feedback failure is non-critical, game continues
  end
end

-- Add XP to hero and check for level-up
function experience_system.addXP(amount)
  if not experience_system.hero then
    return
  end
  
  -- Validate XP amount is positive
  if type(amount) ~= "number" or amount <= 0 then
    print("Warning: Invalid XP amount:", amount)
    return
  end
  
  -- Clamp XP to reasonable maximum (999999)
  local clampedAmount = math.min(amount, 999999)
  if clampedAmount ~= amount then
    print("Warning: XP amount clamped from", amount, "to", clampedAmount)
  end
  
  -- Add XP to hero
  experience_system.hero:addXP(clampedAmount)
  
  -- Check if hero has enough XP to level up
  while experience_system.hero.xp >= experience_system.hero.xpRequired do
    -- Subtract XP requirement from current XP
    experience_system.hero.xp = experience_system.hero.xp - experience_system.hero.xpRequired
    
    -- Increment level
    experience_system.hero.level = experience_system.hero.level + 1
    
    -- Calculate new XP requirement
    experience_system.hero.xpRequired = experience_system.calculateXPRequired(experience_system.hero.level)
    
    -- Check game state before pausing for level-up
    -- Only trigger level-up callback if callback exists and hero is valid
    if experience_system.onLevelUp and experience_system.hero then
      experience_system.onLevelUp(experience_system.hero.level)
    end
  end
end

-- Calculate XP required for a given level
-- Formula: baseXP + (level - 1) * perLevelIncrement
function experience_system.calculateXPRequired(level)
  -- Validate level is a positive number
  if type(level) ~= "number" or level < 1 then
    print("Warning: Invalid level for XP calculation:", level)
    return 100  -- Return base XP requirement
  end
  
  local baseXP = config_loader.positiveNumber(config_loader.get("experience.baseXPRequired"), 100)
  local perLevel = config_loader.positiveNumber(config_loader.get("experience.xpPerLevelIncrement"), 20)
  
  return baseXP + (level - 1) * perLevel
end

-- Cleanup the level system
function experience_system.cleanup()
  experience_system.hero = nil
  experience_system.onLevelUp = nil
end

return experience_system
