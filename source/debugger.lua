local function len(tbl)
    local index = 0
    for _ in pairs(tbl) do
        index = index + 1
    end
    return index
end

local order = {"keyword", "key", "value", "before", "after", "body"}

local function opairs(tbl)
    local buffer, index = {}, 0
    for _, key in ipairs(order) do
        if tbl[key] then
            table.insert(buffer, {key, tbl[key]})
        end
    end
    for index = 1, #tbl do
        buffer[#buffer + 1] = {index, tbl[index]}
    end
    return function()
        index = index + 1
        if index <= #buffer then
            return table.unpack(buffer[index])
        end
    end
end

return (function()
    local __default__ = {}
    function __default__:tostring(value, indent)
        indent = indent or 0
        if type(value) == "table" then
            local parts = {}
            for k, v in opairs(value) do
                if tonumber(k) then
                    k = "[" .. k .. "]"
                end
                if type(v) == "string" then
                    v = "\"" .. string.gsub(v, "\"", "\\\"") .. "\""
                elseif type(v) == "table" then
                    v = len(v) > 0 and self:tostring(v, indent + 1) or "{}"
                end
                table.insert(parts, string.rep("\t", indent + 1) .. k .. " = " .. v)
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. string.rep("\t", indent) .. "}"
        end
        return tostring(value)
    end
    return __default__
end)()
