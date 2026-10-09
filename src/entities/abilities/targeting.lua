-- Targeting helpers shared by abilities

local M = {}

--- Whether an enemy can be targeted (active, and not phased or burrowed)
function M.isTargetable(enemy)
  return enemy ~= nil and enemy.isActive == true and type(enemy.x) == "number" and type(enemy.y) == "number"
    and not (enemy.isUntargetable and enemy:isUntargetable())
end

--- The targetable enemy nearest to a point
-- @param x number Point X
-- @param y number Point Y
-- @param enemies table Array of enemies
-- @param maxDistance number|nil Ignore enemies farther than this
-- @param exclude table|nil Set of enemies to skip
-- @return table|nil The nearest enemy
function M.nearest(x, y, enemies, maxDistance, exclude)
  local best, bestDistSq = nil, maxDistance and maxDistance * maxDistance or math.huge
  for _, enemy in ipairs(enemies or {}) do
    if M.isTargetable(enemy) and not (exclude and exclude[enemy]) then
      local dx, dy = enemy.x - x, enemy.y - y
      local distSq = dx * dx + dy * dy
      if distSq <= bestDistSq then
        best, bestDistSq = enemy, distSq
      end
    end
  end
  return best
end

--- The targetable enemy with the most targetable neighbors within a radius
-- (ties go to the enemy closest to the wall, which is lower on screen)
-- @param enemies table Array of enemies
-- @param radius number Neighbor radius
-- @param filter function|nil Only consider enemies for which filter(enemy) is true
-- @return table|nil The center enemy of the densest group
function M.densest(enemies, radius, filter)
  local radiusSq = radius * radius
  local best, bestCount = nil, -1
  for _, center in ipairs(enemies or {}) do
    if M.isTargetable(center) and (not filter or filter(center)) then
      local count = 0
      for _, other in ipairs(enemies) do
        if M.isTargetable(other) then
          local dx, dy = other.x - center.x, other.y - center.y
          if dx * dx + dy * dy <= radiusSq then
            count = count + 1
          end
        end
      end
      if count > bestCount or (count == bestCount and best and center.y > best.y) then
        best, bestCount = center, count
      end
    end
  end
  return best
end

--- Targetable enemies within a radius of a point
function M.within(x, y, radius, enemies)
  local list = {}
  local radiusSq = radius * radius
  for _, enemy in ipairs(enemies or {}) do
    if M.isTargetable(enemy) then
      local dx, dy = enemy.x - x, enemy.y - y
      if dx * dx + dy * dy <= radiusSq then
        table.insert(list, enemy)
      end
    end
  end
  return list
end

return M
