local M = {}

--- Capitalizes the first letter of a string
function M.capitalize(str)
    if not str or #str == 0 then return str end
    return str:sub(1, 1):upper() .. str:sub(2)
end

--- Splits a string by a delimiter
function M.split(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = str:find(delimiter, from)
    while delim_from do
        table.insert(result, str:sub(from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = str:find(delimiter, from)
    end
    table.insert(result, str:sub(from))
    return result
end

--- Trims whitespace from both ends of a string
function M.trim(str)
    return str:match("^%s*(.-)%s*$")
end

return M
