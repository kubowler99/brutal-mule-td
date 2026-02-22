local M = {}

-- Clamp value between min and max
function M.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Linear interpolation
function M.lerp(a, b, t)
    return a + (b - a) * t
end

-- Distance between two points
function M.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Angle between two points (in degrees)
function M.angleBetween(x1, y1, x2, y2)
    return math.deg(math.atan2(y2 - y1, x2 - x1))
end

-- Checks if a number is valid (not NaN or infinite)
function M.isValid(n)
    return n == n and n ~= math.huge and n ~= -math.huge
end

-- Generates a random decimal number between two values
function M.randomFloat(min, max)
    return math.random() * (max - min) + min
end

-- Returns the sign of a number (1, -1, or 0)
function M.sign(n)
    return n > 0 and 1 or n < 0 and -1 or 0
end

-- Returns a random sign (1 or -1)
function M.randomSign()
    return math.random(1, 2) == 1 and 1 or -1
end

-- Calculates the x and y components from angle (degrees) and magnitude
function M.lengthDir(angle, magnitude)
    local rad = math.rad(angle)
    return math.cos(rad) * magnitude, math.sin(rad) * magnitude
end

-- Round to nearest integer
function M.round(num)
    return math.floor(num + 0.5)
end

return M
