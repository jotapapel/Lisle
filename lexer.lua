local function slice(str, token, repl)
	local parts, newstr = {}, string.gsub(str .. token, "[%(\"%[].-[%)\"%]]", function(s) return string.gsub(s, "%s+", "\0") end)
	for part in string.gmatch(newstr, "(%S+)" .. token) do
		part = string.gsub(part, "%z+", string.char(32))
		if type(repl) == "function" then part = repl(part) end
		table.insert(parts, part)
	end
	return parts
end

local grammar = {
	-- comments
	["rem%s+(.-)$"] = function(value)
		return {
			keyword = "comment",
			body = {
				value
			}
		}
	end,
	-- variables
	["var%s+([_%a][_%w]*)%s*=%s*(.-)$"] = function(key, value)
		return {
			keyword = "variable",
			body = {
				{
					key = key,
					value = value
				}
			}
		}
	end,
	["^([_%a][_%w%.]*)%s*=%s*(.-)$"] = function(key, value)
		return {
			key = key,
			value = value
		}
	end,
	-- prototypes
	["type%s+([_%a][_%w]*){(.-)}$"] = function(key, super)
		return {
			keyword = "prototype",
			key = key,
			body = {}
		}
	end,
	-- functions
	["fn%s+([_%a][_%w]*)%((.-)%)"] = function(key, args)
		return {
			keyword = "function",
			key = key,
			args = slice(args, ","),
			body = {}
		}
	end
}

return (function()
	local self = {}
	
	function self:generate_node(str)
		local node = str
		for pattern, repl in pairs(grammar) do
			if string.match(str, pattern) then
				string.gsub(str, pattern, function(...) node = repl(...) end)
				break
			end
		end
		return node
	end
	
	return self
end)()