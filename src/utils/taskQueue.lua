---@class TaskQueue
---Frame-independent task scheduling system.
---Useful for game logic that needs to be pauseable or time-scaled.
local M = {}

function M.new()
    local tq = {}
    tq._tasks = {}
    tq.timeElapsed = 0

    ---Adds a new task to the queue
    ---@param params table { time: number, toDo: function }
    function tq:addTask(params)
        local task = {
            time = (params.time or 0) + self.timeElapsed,
            toDo = params.toDo,
            isCancelled = false
        }
        
        -- Insert sorted by time
        local index = #self._tasks + 1
        for i = 1, #self._tasks do
            if self._tasks[i].time > task.time then
                index = i
                break
            end
        end
        table.insert(self._tasks, index, task)
        
        -- Return task handle for cancellation
        return task
    end

    ---Advances the queue by delta time and performs pending tasks
    ---@param dt number Delta time in milliseconds
    function tq:update(dt)
        self.timeElapsed = self.timeElapsed + dt
        
        while #self._tasks > 0 and self._tasks[1].time <= self.timeElapsed do
            local task = table.remove(self._tasks, 1)
            if not task.isCancelled and task.toDo then
                task.toDo()
            end
        end
    end

    function tq:cancelTask(task)
        if task then
            task.isCancelled = true
        end
    end

    function tq:clear()
        self._tasks = {}
        self.timeElapsed = 0
    end

    return tq
end

return M
