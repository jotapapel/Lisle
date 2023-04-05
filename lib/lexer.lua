local analyser = require "lib.analyser"

local function slice(str, token, repl)
	local parts, newstr = {}, string.gsub(str .. token, "[%(%[\"].-[\"%]%)]", function(s)
		return string.gsub(s, token, "\0")
	end)
	for part in string.gmatch(newstr, "(.-)" .. token) do
		part = string.gsub(part, "%z+", token)
		if string.len(part) > 0 then
			if type(repl) == "function" then
				part = repl(part)
			end
			table.insert(parts, part)
		end
	end
	return parts
end

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
					body = {
						{
							keyword = "assignment",
							key = key,
							value = substitute(value)
						}
					}
				}
			end
		},
		-- function declarations
		["func"] = {
			pattern = "func%s+(.-)%((.-)%)",
			analyser = function(index, parent, key, value)
				local errormsg
				if not analyser.typeof(key, "variable-access") then
					errormsg = "Invalid function name"
				elseif not string.match(value, "^[_%w%s,]*$") then
					errormsg = "Misshaped function arguments"
				end
				-- parse arguments
				local argn = 0
				local args = slice(value, ",", function(arg)
					arg, argn = string.match(arg, "^%s*(.-)%s*$"), argn + 1
					if not analyser.typeof(arg, "variable") and arg ~= "..." then
						analyser.error(index, "Invalid function argument n°" .. tostring(argn))
					end
					return arg
				end)
				if errormsg then
					analyser.error(index, errormsg)
				end
				return {
					keyword = "function",
					key = key,
					value = args,
					body = {}
				}
			end
		},
		-- control structures
		["if"] = {
			pattern = "if%s+(.-)$",
			analyser = function(index, parent, value)
				return {
					keyword = "if",
					value = value,
					body = {}
				}
			end
		},
		["elseif"] = {
			pattern = "elseif%s+(.-)$",
			analyser = function(index, parent, value)
				return {
					keyword = "elseif",
					value = value,
					after = {"if", "elseif"},
					body = {}
				}
			end
		},
		["else"] = {
			pattern = "else$",
			analyser = function(index, parent, value)
				return {
					keyword = "else",
					after = {"if", "elseif"},
					body = {}
				}
			end
		},
		-- loops
		["for"] = {
			pattern = "for%s+(.-)%s+=%s+(.-)%s+to%s+(.-)$",
			analyser = function(index, parent, key, value, after)
				local errormsg
				local finish, step = string.match(after, "(.-)%s+step%s+(.-)$")
				if not analyser.typeof(key, "variable-access") then
					errormsg = "variable name"
				elseif not analyser.typeof(value, "string", "number", "boolean", "variable-access", "function-call") then
					errormsg = "variable value"
				elseif not analyser.typeof(finish or after, "string", "number", "boolean", "variable-access", "function-call") then
					errormsg = "finish value"
				elseif step and not analyser.typeof(step, "string", "number", "boolean", "variable-access", "function-call") then
					errormsg = "step value"
				end
				if errormsg then
					analyser.error(index, "Invalid " .. errormsg)
				end
				return {
					keyword = "for",
					key = key,
					value = value,
					finish = finish or after,
					step = step
				}
			end
		}
	},
	statements = function(index, content, parent)
		local key, value = string.match(content, "^(.-)%s*=%s*(.-)$")
		-- variable assignment
		if (key and value) or (analyser.typeof(content, "variable") and parent == "variable") then
			if (value and not analyser.typeof(value, "boolean", "string", "number", "variable-access", "function-call")) then
				analyser.error(index, "Invalid variable value")
			end
			return {
				keyword = "assignment",
				key = key or content,
				value = value or "nil"
			}
		-- function call
		elseif analyser.typeof(content, "function-call") then
			local key, value = string.match(content, "^(.-)%((.-)%)")
			return {
				keyword = "call",
				key = key,
				value = slice(value, ",")
			}
		-- return statement
		elseif string.match(content, "^return%s+(.-)$") then
			local value = string.match(content, "^return%s+(.-)$")
			if value then
				if (value and not analyser.typeof(value, "boolean", "string", "number", "variable-access", "function-call")) then
					analyser.error(index, "Invalid return value")
				end
				return {
					keyword = "return",
					value = value
				}
			end
		-- break statement
		elseif string.match(content, "^break$") then
			return {
				keyword = "break"
			}
		end
	end
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
		return grammar.statements(index, content, parent.keyword) or analyser.error(index)
	end
	return __default__
end)()