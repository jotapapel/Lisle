local analyser = require "lib.analyser"

---@param str string
---@param token string
---@param repl fun(part: string): string
---@return string[]
local function slice(str, token, repl)
    local parts, newstr = {}, string.gsub(str .. token, "[%(%[\"].-[\"%]%)]", function(s)
        return string.gsub(s, "%s+", "\0")
    end)
    print(newstr)
    for part in string.gmatch(newstr, "(.-)" .. token) do
        part = string.gsub(part, "%z+", string.char(32))
        if string.len(part) > 0 then
            if type(repl) == "function" then
                part = repl(part)
            end
            table.insert(parts, part)
        end
    end
    return parts
end

---@param str string
---@return string
local function substitute(str)
    if not str then
        return
    end
    str = string.gsub(str, "(.?)(%b[])", function(head, body)
        if not string.match(head, "[%w%]%)]") then
            local parts = slice(string.match(body, "%[(.-)%]"), ",", function(part)
                local k, v = string.match(part, "^%s*(.-):%s+(.-)$")
                if not k and not v then
                    return part
                end
                return "[\"" .. k .. "\"]" .. " = " .. v
            end)
            return head .. "{" .. table.concat(parts, ", ") .. "}"
        end
        return head .. body
    end)
    return str
end

local grammar = {
    keywords = {
        -- comments
        ["rem"] = {
            pattern = "rem%s+(.-)$",
            analyser = function(index, parent, value)
                return {
                    keyword = "comment",
                    body = {value}
                }
            end
        },
        -- variable declarations
        ["var"] = {
            pattern = "var%s+([_%a][_%w]*)(.-)$",
            analyser = function(index, parent, key, after)
                if not analyser.typeof(key) then
                    analyser.error(index, "Invalid variable name")
                end
                local value = string.match(after, "%s*=%s*(.-)$")
                if string.len(after) > 0 and not value then
                    analyser.error(index, "Misshaped variable declaration")
                end
                if not analyser.typeof(value, "string", "number", "record", "variable-access", "function-call") then
                    analyser.error(index, "Invalid variable value")
                end
                return {
                    keyword = "variable",
                    body = {{
                        keyword = "assignment",
                        key = key,
                        value = substitute(value)
                    }}
                }
            end
        },
        -- function declarations
        ["func"] = {
            pattern = "func%s+(.-)%((.-)%)",
            analyser = function(index, parent, key, value)
                if not analyser.typeof(key, "variable-access") then
                    analyser.error(index, "Invalid function name")
                end
                if not string.match(value, "^[_%w%s,]*$") then
                    analyser.error(index, "Misshaped function arguments")
                end
                local args = slice(value, ",", function(arg)
                    return string.match(arg, "^%s*(.-)%s*$")
                end)
                for pos, arg in ipairs(args) do
                    if not analyser.typeof(arg, "variable") and arg ~= "..." then
                        analyser.error(index, "Invalid function argument, arg. nº " .. tostring(pos))
                    end
                end
                return {
                    keyword = "function",
                    key = key,
                    value = args,
                    body = {}
                }
            end
        }
    },
    statements = { --- variable assignment
    function(index, content, parent)
        local key, value = string.match(content, "^(.-)%s*=%s*(.-)$")
        if (key and value) or (analyser.typeof(content, "variable") and parent == "variable") then
            if (value and not analyser.typeof(value, "boolean", "string", "number", "variable-access", "function-call")) then
                analyser.error(index, "Invalid variable value")
            end
            return {
                keyword = "assignment",
                key = key or content,
                value = value or "nil"
            }
        end
    end, --- function calls
    function(index, content, parent)
        if analyser.typeof(content, "function-call") then
            local key, value = string.match(content, "^(.-)%((.-)%)")
            return {
                keyword = "call",
                key = key,
                value = slice(value, ",")
            }
        end
    end, --- return statement
    function(index, content, parent)
        local value = string.match(content, "^return%s+(.-)$")
        if value then
            if parent ~= "function" then
                analyser.error(index, "Return statement outside function")
            end
            if (value and not analyser.typeof(value, "boolean", "string", "number", "variable-access", "function-call")) then
                analyser.error(index, "Invalid return value")
            end
            return {
                keyword = "return",
                value = value
            }
        end
    end}
}
return (function()
    local __default__ = {}
    function __default__:generate(parent, line)
        local content, index = string.match(line, "^(.-);(%d+)$")
        if parent.keyword == "comment" then
            return content
        end
        local node
        -- keywords
        for keyword, descriptor in pairs(grammar.keywords) do
            if string.match(content, "^(%w+)") == keyword then
                if string.match(content, descriptor.pattern) then
                    string.gsub(content, descriptor.pattern, function(...)
                        node = descriptor.analyser(index, parent.keyword, ...)
                    end)
                    return node
                end
            end
        end
        -- statements
        for _, analyser in ipairs(grammar.statements) do
            node = analyser(index, content, parent.keyword) or node
        end
        -- default
        return node or analyser.error(index)
    end
    return __default__
end)()
