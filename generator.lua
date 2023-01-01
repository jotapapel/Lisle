local templates = {
	["comment"] = "-- <value>",
	["variable"] = "<key> = <value>"
}

return (function()
	local self = {}
	
	function self:replace_placeholder(str, key, value, patt, sep)
		local repl = ""
		if type(value) == "table" then value = #value > 0 and table.concat(value, sep) end
		if value then repl = string.format(patt or "%s", value) end
		return string.gsub(str, "<" .. key .. ">", repl)
	end
	
	function self:process_master(master, raw)
		local nodes = {}
		for _, n in ipairs(master.body) do
			local t = self:process_node(n)
			table.insert(nodes, t)
		end
		return raw and nodes or table.concat(nodes, "\n")
	end
	
	function self:process_node(node)
		if type(node) == "table" then
			local template = templates[node.keyword] or ""
			
			if node.keyword == "variable" then
				
			elseif node.keyword == "comment" then
				local nodes = self:process_master(node, true)
				template = self:replace_placeholder(template, "value", node, "%s", "\n-- ")
			elseif node.key and node.value then
				template = string.format("%s = %s", node.key, node.value)
			end
			
			return template
		end		
		return node
	end
	
	return self
end)()