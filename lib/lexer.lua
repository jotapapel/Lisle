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

local function totable(chunk)
	return string.gsub(chunk, "(.?)(%b[])", function(before, content)
		content = string.gsub(string.match(content, "^%[(.-)%]$"), "%b[]", totable)
		if not string.match(before, "[%)%]%w]") then
			local entries = slice(content, ",", function(entry)
				local key, value = string.match(entry, "^%s*(.-):%s+(.-)$")
				if not key and not value then
					return entry
				end
				return "[\"" .. key .. "\"]" .. " = " .. value
			end)
			return before .. "{" .. table.concat(entries, ", ") .. "}"
		end
		return before .. content
	end)
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
				-- look for syntax errors
				local errormsg
				if not analyser.typeof(key) then
					analyser.error(index, "Invalid variable name")
				end
				local value = string.match(after, "%s*=%s*(.-)$")
				if string.len(after) > 0 and not value then
					errormsg = "Misshaped variable declaration"
				elseif not analyser.typeof(value, "string", "number", "record", "variable-access", "function-call") then
					errormsg = "Invalid variable value"
				end
				-- throw error if present
				if errormsg then
					analyser.error(index, errormsg)
				end
				return {
					keyword = "variable",
					body = {
						{
							keyword = "assignment",
							key = key,
							value = value
						}
					}
				}
			end
		},
		-- function declarations
		["func"] = {
			pattern = "func%s+(.-)%((.-)%)",
			analyser = function(index, parent, key, value)
				-- look for syntax errors
				local errormsg
				if not analyser.typeof(key, "variable-access") then
					errormsg = "Invalid function name"
				elseif not string.match(value, "^[_%w%s,]*$") then
					errormsg = "Misshaped function arguments"
				end
				-- parse arguments
				local argn = 0
				value = slice(value, ",", function(arg)
					arg, argn = string.match(arg, "^%s*(.-)%s*$"), argn + 1
					if not analyser.typeof(arg, "variable") and arg ~= "..." then
						analyser.error(index, "Invalid function argument n°" .. tostring(argn))
					end
					return arg
				end)
				-- throw errors if found
				if errormsg then
					analyser.error(index, errormsg)
				end
				return {
					keyword = "function",
					key = key,
					value = value,
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
					value = subtitute(value),
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
		-- numeric for
		["for"] = {
			pattern = "for%s+(.-)%s+=%s+(.-)%s+to%s+(.-)$",
			analyser = function(index, parent, key, value, after)
				-- look for syntax errors
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
				-- throw errors if found
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
		},
		--- iterator for
		["foreach"] = {
			pattern = "foreach%s+%[(.-)%]%s+in%s+(.-)$",
			analyser = function(index, parent, keys, value)
				-- look for syntax errors
				if not analyser.typeof(value, "variable-access", "record") then
					analyser.error(index, "Invalid iterable value")
				end
				-- parse keys
				local keyn = 0
				keys = slice(keys, ",", function(key)
					key, keyn = string.match(key, "^%s*(.-)%s*$"), keyn + 1
					if not analyser.typeof(key, "variable") then
						analyser.error(index, "Invalid variable name - n°" .. tostring(keyn))
					end
					return key
				end)
				return {
					keyword = "foreach",
					key = keys,
					value = value
				}
			end
		},
		-- while loop
		["while"] = {
			pattern = "while%s+(.-)$",
			analyser = function(index, parent, value)
				--if not analyser.typeof(value, "boolean", "variable-access")
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