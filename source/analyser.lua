local keywords = "rem var func return type if elseif else while until for to step foreach in break true false nil"
local patterns = {
    ["string"] = function(str)
        return string.match(str, [[^%b""$]]) or false
    end,
    ["number"] = function(str)
        return string.match(str, "^%-?[0-9]*%.?[0-9]*$") and string.sub(str, -1) ~= "."
    end,
    ["boolean"] = function(str)
        for keyword in string.gmatch("true false undefined", "%w+") do
            if str == keyword then
                return true
            end
        end
        return false
    end,
    ["record"] = function(str)
        return string.match(str, "^%b[]$")
    end,
    ["variable-name"] = function(str, safe)
        if not string.match(str, "^[_%w%.%[%]\"]+$") then
            return false
        end
        for key in string.gmatch(str .. ".", "(.-)%f[%.]") do
            local value, after = string.match(key, "^[_%a][_%w]*%[(\"[_%a][_%w]*\")(.)$")
            if value then
                if after ~= "]" then
                    return false
                end
            else
                if not string.match(key, "^[_%a][_%w]*$") then
                    return false
                end
            end
            if not safe(key) then
                return false
            end
        end
        return true
    end,
    ["variable-assignment"] = function(str, safe)
        local key, value = string.match(str, "^(.-)%s*=%s*(.-)$")
        if not safe(key, "variable-name") then
            return false
        end
    end,
    ["function-call"] = function(str, safe)
        local key, value, after = string.match(str, "^(.-)%((.-)(.)$")
        if not key then
            return false
        end
        if value and after ~= ")" then
            return false
        end
        if not safe(key, "variable") then
            return false
        end
        return key and value and after and true
    end
}

local function error(index, msg)
    msg = msg and (". (" .. msg .. ")") or "."
    io.write("Lisle: Syntax error in line " .. tostring(index) .. msg .. "\n")
    os.exit()
end

local function safe(str, ...)
    local allowed
    for keyword in string.gmatch(keywords, "%w+") do
        if str == keyword then
            return false
        end
    end
    if select("#", ...) == 0 then
        allowed = true
    else
        for _, typecheck in ipairs({...}) do
            allowed = patterns[typecheck](str, safe) or allowed
        end
    end
    return allowed
end

return {
    error = error,
    issafe = safe
}
