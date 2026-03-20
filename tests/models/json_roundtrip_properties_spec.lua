--- Property-based tests for JSON data round-trip integrity
-- Feature: game-visual-and-data-improvements, Property 15: JSON data round-trip integrity
-- **Validates: Requirements 8.1, 8.2**

require("tests.spec_helper")

-- Helper: deep equality check for Lua tables (handles nested tables, ignores key order)
local function deepEqual(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end

  for k, v in pairs(a) do
    if not deepEqual(v, b[k]) then return false end
  end
  for k, _ in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

-- Helper: read a JSON file from disk and return the parsed Lua table
local function readJsonFile(path)
  local file = io.open(path, "r")
  if not file then return nil, "Could not open file: " .. path end
  local content = file:read("*a")
  file:close()
  if not content or content == "" then return nil, "Empty file: " .. path end
  local data = json.decode(content)
  if not data then return nil, "Failed to decode JSON from: " .. path end
  return data
end

-- Helper: describe a table structure for error messages
local function describeValue(v, depth)
  depth = depth or 0
  if depth > 3 then return "..." end
  if type(v) == "table" then
    local parts = {}
    local count = 0
    for k, val in pairs(v) do
      count = count + 1
      if count > 3 then
        parts[#parts + 1] = "..."
        break
      end
      parts[#parts + 1] = tostring(k) .. "=" .. describeValue(val, depth + 1)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  return tostring(v)
end

-- Generators for random JSON-compatible data structures

local function randomString(minLen, maxLen)
  minLen = minLen or 1
  maxLen = maxLen or 20
  local len = math.random(minLen, maxLen)
  local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- "
  local result = {}
  for i = 1, len do
    local idx = math.random(1, #chars)
    result[i] = chars:sub(idx, idx)
  end
  return table.concat(result)
end

local function randomNumber()
  -- Generate integers and floats, positive and negative
  if math.random() < 0.5 then
    return math.random(-1000, 1000)
  else
    return math.random(-10000, 10000) / 10.0
  end
end

local function randomBoolean()
  return math.random() < 0.5
end

-- Forward declaration
local randomValue

local function randomTable(maxDepth, maxKeys)
  maxDepth = maxDepth or 2
  maxKeys = maxKeys or 5
  local t = {}
  local numKeys = math.random(1, maxKeys)
  for _ = 1, numKeys do
    local key = randomString(1, 10)
    t[key] = randomValue(maxDepth - 1, maxKeys)
  end
  return t
end

randomValue = function(maxDepth, maxKeys)
  maxDepth = maxDepth or 2
  maxKeys = maxKeys or 5
  if maxDepth <= 0 then
    -- Only leaf values at max depth
    local choice = math.random(1, 3)
    if choice == 1 then return randomString() end
    if choice == 2 then return randomNumber() end
    return randomBoolean()
  end
  local choice = math.random(1, 4)
  if choice == 1 then return randomString() end
  if choice == 2 then return randomNumber() end
  if choice == 3 then return randomBoolean() end
  return randomTable(maxDepth, maxKeys)
end

-- Generator: random abilities-like data structure
local function randomAbilitiesData()
  local data = {}
  local numAbilities = math.random(1, 3)
  for i = 1, numAbilities do
    local id = "ability_" .. i
    data[id] = {
      name = randomString(3, 15),
      module = "src.entities.abilities." .. randomString(3, 10),
      unlocked = randomBoolean(),
      maxTier = math.random(1, 10),
      baseStats = {
        cooldown = math.random(1, 50) / 10.0,
        damage = math.random(1, 100),
        projectileSpeed = math.random(50, 1000),
        pierceCount = math.random(0, 10),
        projectileCount = math.random(1, 5)
      }
    }
  end
  return data
end

-- Generator: random enemies-like data structure
local function randomEnemiesData()
  local data = {}
  local numEnemies = math.random(1, 3)
  for i = 1, numEnemies do
    local id = "enemy_" .. i
    data[id] = {
      health = math.random(5, 500),
      speed = math.random(20, 300),
      damage = math.random(1, 50),
      attackCooldown = math.random(5, 50) / 10.0,
      xpValue = math.random(1, 100)
    }
  end
  return data
end

describe("JSON Round-Trip Properties", function()

  -- Feature: game-visual-and-data-improvements, Property 15: JSON data round-trip integrity
  -- **Validates: Requirements 8.1, 8.2**
  describe("Property 15: JSON data round-trip integrity", function()

    describe("Actual abilities.json round-trip (Requirement 8.1)", function()
      it("should produce equivalent data after encode-then-decode", function()
        local original = readJsonFile("data/abilities.json")
        assert.is_not_nil(original, "abilities.json should be readable and valid JSON")

        local encoded = json.encode(original)
        assert.is_not_nil(encoded, "Encoding abilities data should produce a string")
        assert.is_true(type(encoded) == "string", "Encoded result should be a string")

        local decoded = json.decode(encoded)
        assert.is_not_nil(decoded, "Decoding the re-encoded JSON should succeed")

        assert.is_true(deepEqual(original, decoded),
          "Round-trip of abilities.json should produce equivalent data.\nOriginal: " ..
          describeValue(original) .. "\nDecoded: " .. describeValue(decoded))
      end)
    end)

    describe("Actual enemies.json round-trip (Requirement 8.2)", function()
      it("should produce equivalent data after encode-then-decode", function()
        local original = readJsonFile("data/enemies.json")
        assert.is_not_nil(original, "enemies.json should be readable and valid JSON")

        local encoded = json.encode(original)
        assert.is_not_nil(encoded, "Encoding enemies data should produce a string")
        assert.is_true(type(encoded) == "string", "Encoded result should be a string")

        local decoded = json.decode(encoded)
        assert.is_not_nil(decoded, "Decoding the re-encoded JSON should succeed")

        assert.is_true(deepEqual(original, decoded),
          "Round-trip of enemies.json should produce equivalent data.\nOriginal: " ..
          describeValue(original) .. "\nDecoded: " .. describeValue(decoded))
      end)
    end)

    describe("Random abilities-like structures round-trip (Requirement 8.1)", function()
      it("should preserve equivalence across 100 random abilities structures", function()
        for i = 1, 100 do
          local original = randomAbilitiesData()

          local encoded = json.encode(original)
          assert.is_not_nil(encoded,
            "Iteration " .. i .. ": encoding should produce a string")

          local decoded = json.decode(encoded)
          assert.is_not_nil(decoded,
            "Iteration " .. i .. ": decoding should succeed")

          assert.is_true(deepEqual(original, decoded),
            "Iteration " .. i .. ": round-trip should produce equivalent data.\nOriginal: " ..
            describeValue(original) .. "\nDecoded: " .. describeValue(decoded))
        end
      end)
    end)

    describe("Random enemies-like structures round-trip (Requirement 8.2)", function()
      it("should preserve equivalence across 100 random enemies structures", function()
        for i = 1, 100 do
          local original = randomEnemiesData()

          local encoded = json.encode(original)
          assert.is_not_nil(encoded,
            "Iteration " .. i .. ": encoding should produce a string")

          local decoded = json.decode(encoded)
          assert.is_not_nil(decoded,
            "Iteration " .. i .. ": decoding should succeed")

          assert.is_true(deepEqual(original, decoded),
            "Iteration " .. i .. ": round-trip should produce equivalent data.\nOriginal: " ..
            describeValue(original) .. "\nDecoded: " .. describeValue(decoded))
        end
      end)
    end)

    describe("Random nested data structures round-trip", function()
      it("should preserve equivalence across 100 random nested tables", function()
        for i = 1, 100 do
          local original = randomTable(3, 5)

          local encoded = json.encode(original)
          assert.is_not_nil(encoded,
            "Iteration " .. i .. ": encoding nested table should produce a string")

          local decoded = json.decode(encoded)
          assert.is_not_nil(decoded,
            "Iteration " .. i .. ": decoding nested table should succeed")

          assert.is_true(deepEqual(original, decoded),
            "Iteration " .. i .. ": round-trip of nested table should produce equivalent data.\nOriginal: " ..
            describeValue(original) .. "\nDecoded: " .. describeValue(decoded))
        end
      end)
    end)

  end)
end)
