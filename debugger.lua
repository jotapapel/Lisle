local function len(tbl)
	local index = 0
	for _ in pairs(tbl) do index = index + 1 end
	return index
end

local function opairs(tbl)
	local buffer, index = {}, 0
	for k in pairs(tbl) do
		table.insert(buffer, k)
	end
	table.sort(buffer)
	return function()
		index = index + 1
		if index <= len(buffer) then
			return buffer[index], tbl[buffer[index]]
		end
	end
end

return (function()
	local self = {}
	
	function self:print(value)
		print(self:tostring(value))
	end
	
	function self:tostring(value, indent)
		if type(value) == "table" then
			local template, parts = "{\n%s\n%s}", {}
			indent = indent or 0
			for k, v in opairs(value) do
				if tonumber(k) then k = string.format("[%s]", k) end
				if type(v) == "string" then v = string.format("\"%s\"", string.gsub(v, "\"", "\\\"")) end
				if type(v) == "table" then v = len(v) > 0 and self:tostring(v, indent + 1) or "{}" end
				table.insert(parts, string.format("%s%s = %s", string.rep("\t", indent + 1), k, v))
			end
			return string.format(template, table.concat(parts, ",\n"), string.rep("\t", indent))
		end
		return tostring(value)
	end
	
	return self
end)()