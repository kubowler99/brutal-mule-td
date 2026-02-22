---@class Pool
---Simple object pooling utility to reuse display objects and tables.
local M = {}

---Creates a new pool
---@param factory function Function that creates a new object
---@param reset function Function that resets an object before reuse
---@return table pool
function M.new(factory, reset)
    local pool = {}
    pool._available = {}
    pool._factory = factory
    pool._reset = reset

    ---Gets an object from the pool or creates a new one
    function pool:get(...)
        local obj
        if #self._available > 0 then
            obj = table.remove(self._available)
            if self._reset then
                self._reset(obj, ...)
            end
        else
            obj = self._factory(...)
        end
        return obj
    end

    ---Returns an object to the pool
    function pool:release(obj)
        if obj then
            table.insert(self._available, obj)
        end
    end

    ---Pre-warms the pool with a set number of objects
    function pool:prewarm(count, ...)
        for i = 1, count do
            self:release(self._factory(...))
        end
    end

    function pool:clear()
        self._available = {}
    end

    return pool
end

return M
