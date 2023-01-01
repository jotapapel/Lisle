local lexer = require "lexer"
local generator = require "generator"

local file <close> = io.open("examples/prototypes.lse", "r")
local text = string.gsub(file:read("*all"), "%s*\n", "\n")

local master = {keyword = "global", body = {}}
local buffer = {master}

local ni, line, node, current
local level, i, j = 0, 1, 1
while true do
	ni, j, line = string.find(string.format("%s\n", text), "%f[%g](.-)\n", i)
	if not ni then break end
	-- generate closings
	while ni - i <= level do
		current, level = table.remove(buffer), level - 1
	end
	-- generate node
	node = lexer:generate_node(line)
	table.insert(current.body, node)
	if node.body then
		table.insert(buffer, current)
		current, level = node, level + 1
	end
	-- next line
	i = j + 1
end

-- debug
local debugger = require "debugger"
debugger:print(master)