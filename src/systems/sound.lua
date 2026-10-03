-- Sound
-- Plays sound effects and background music when their files exist.
-- Audio is optional: missing files are skipped, so the game runs silently
-- until files are added under assets/audio/. Respects the soundOn and
-- musicOn settings in the save data.

local data = require("src.models.data")

local M = {}

-- Sound effect files (add a file at any of these paths to enable it)
M.SOUND_FILES = {
  hit = "assets/audio/sfx/hit.wav",
  enemy_death = "assets/audio/sfx/enemy_death.wav",
  wall_hit = "assets/audio/sfx/wall_hit.wav",
  boss = "assets/audio/sfx/boss.wav",
  level_up = "assets/audio/sfx/level_up.wav",
  victory = "assets/audio/sfx/victory.wav",
  defeat = "assets/audio/sfx/defeat.wav",
}

M.MUSIC_FILE = "assets/audio/music/battle.mp3"

-- Minimum seconds between two plays of the same sound
local MIN_REPEAT_INTERVAL = 0.06

local MUSIC_CHANNEL = 1

-- Internal state
local sounds = {}        -- name -> loaded handle
local lastPlayed = {}    -- name -> time of last play
local music = nil
local musicPlaying = false

local function fileExists(path)
  local ok, found = pcall(system.pathForFile, path, system.ResourceDirectory)
  return ok and found ~= nil
end

local function setting(key)
  local value = data.get("settings." .. key)
  return value ~= false  -- on unless explicitly turned off
end

--- Load every sound effect whose file exists
function M.initialize()
  M.cleanup()
  for name, path in pairs(M.SOUND_FILES) do
    if fileExists(path) then
      local ok, handle = pcall(audio.loadSound, path)
      if ok and handle then
        sounds[name] = handle
      end
    end
  end
end

--- Whether a sound effect is loaded
function M.isLoaded(name)
  return sounds[name] ~= nil
end

--- Play a sound effect (skipped if missing, muted, or just played)
-- @param name string Key in SOUND_FILES
-- @return boolean True if it played
function M.play(name)
  local handle = sounds[name]
  if not handle or not setting("soundOn") then
    return false
  end

  local now = system.getTimer() / 1000
  if lastPlayed[name] and now - lastPlayed[name] < MIN_REPEAT_INTERVAL then
    return false
  end
  lastPlayed[name] = now

  pcall(audio.play, handle)
  return true
end

--- Start looping background music if the file exists and music is on
-- @return boolean True if music started
function M.playMusic()
  if musicPlaying or not setting("musicOn") or not fileExists(M.MUSIC_FILE) then
    return false
  end

  local ok, stream = pcall(audio.loadStream, M.MUSIC_FILE)
  if not ok or not stream then
    return false
  end
  music = stream
  pcall(audio.play, music, { channel = MUSIC_CHANNEL, loops = -1 })
  musicPlaying = true
  return true
end

--- Stop and free the background music
function M.stopMusic()
  if music then
    pcall(audio.stop, MUSIC_CHANNEL)
    pcall(audio.dispose, music)
  end
  music = nil
  musicPlaying = false
end

--- Free all loaded sounds and music
function M.cleanup()
  M.stopMusic()
  for _, handle in pairs(sounds) do
    pcall(audio.dispose, handle)
  end
  sounds = {}
  lastPlayed = {}
end

return M
