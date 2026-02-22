---@class Player
---@field group table Solar2D display group
---@field sprite table Player sprite
local Player = Class("Player")
Player:include(Stateful)

function Player:initialize(parent, x, y)
    self.group = display.newGroup()
    if parent then parent:insert(self.group) end
    
    self.group.x = x or display.contentCenterX
    self.group.y = y or display.contentCenterY
    
    -- Placeholder for player visual
    self.sprite = display.newRect(self.group, 0, 0, 40, 60)
    self.sprite:setFillColor(0.8, 0.2, 0.2)
    
    print("Player initialized. Current state: ", self:getStateStackDebugInfo()[1] or "None")
    
    -- Start in Idle state
    self:gotoState("Idle")
end

-- Idle State
local Idle = Player:addState("Idle")

function Idle:enteredState()
    print("Player entered IDLE state")
    self.sprite:setFillColor(0.8, 0.2, 0.2)
end

function Idle:move(dx, dy)
    -- Transition to moving state if we actually move
    if dx ~= 0 or dy ~= 0 then
        self:gotoState("Moving", dx, dy)
    end
end

-- Moving State
local Moving = Player:addState("Moving")

function Moving:enteredState(dx, dy)
    print("Player entered MOVING state")
    self.sprite:setFillColor(0.2, 0.8, 0.2)
    self:move(dx, dy)
end

function Moving:move(dx, dy)
    if dx == 0 and dy == 0 then
        self:gotoState("Idle")
    else
        self.group.x = self.group.x + (dx or 0)
        self.group.y = self.group.y + (dy or 0)
    end
end

function Player:destroy()
    if self.group then
        display.remove(self.group)
        self.group = nil
    end
end

return Player
