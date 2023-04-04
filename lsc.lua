debugger = require "source.debugger"
analyser = require "source.analyser"
lexer = require "source.lexer"
json = require "source.json"

local parameters = {...}
local function parameter(pmtr)
    if pmtr == "$file" then
        return parameters[1]
    end
    for index = 2, #parameters do
        if parameters[index] == pmtr then
            return pmtr, index
        end
    end
    return false
end

local file_path = string.match(parameter("$file"), "/?(.-)%.le$")
local file_content, file_line_index = "", 0
for file_line in io.lines(parameter("$file")) do
    file_line_index = file_line_index + 1
    if string.len(file_line) > 0 then
        file_content = file_content .. file_line .. ";" .. tostring(file_line_index) .. "\n"
    end
end

local master_node = {
    keyword = "global",
    body = {}
}
local buffer = {master_node}

local ni, line, node, current
local level, i, j = 0, 1, 1
while true do
    ni, j, line = string.find(string.format("%s\n", file_content), "%f[%g](.-)\n", i)
    if not ni then
        break
    end
    while ni - i <= level do
        current, level = table.remove(buffer), level - 1
    end
    node = lexer:generate(current, line)
    table.insert(current.body, node)
    if node.body then
        table.insert(buffer, current)
        current, level = node, level + 1
    end
    i = j + 1
end

local astfile<close> = io.open(file_path .. ".ast.json", "w")
astfile:write(json.encode(master_node))
