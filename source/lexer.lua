local function slice(str, token, repl)
	local parts, newstr = {}, string.gsub(str .. token, "\".-\"]", function(s) return string.gsub(s, "%s+", "\0") end)
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
				return "[\"".. k  .."\"]" .. " = " .. v
			end)
			return head .. "{" .. table.concat(parts, ", ") .. "}"
		end
		return head .. body
	end)

	return str
end

local primary_grammar = {

	["rem"] = {
		pattern = "rem%s+(.-)$",
		analyser = function(index, value)
			return {
				keyword = "comment",
				body = {
					value
				}
			}
		end
	};
	
	["var"] = {
		pattern = "var%s+([_%a][_%w]*)(.-)$",
		analyser = function(index, parent_keyword, key, after)
			if not analyser.issafe(key, "key") then
				syntaxerror(index, "Variable name cannot be a reserved keyword")
			end
			local value = string.match(after, "%s*=%s*([_\"%w%(%[].-)$")
			if string.len(after) > 0 and not value then
				syntaxerror(index, "Invalid variable declaration")
			end
			return {
				keyword = "variable",
				storage = (parent_keyword and not(parent_keyword == "global" or parent_keyword == "prototype")) and "local" or nil,
				body = {
					{
						keyword = "assignment",
						key = key,
						value = substitute(value)
					}
				}
			}
		end
	};

	["func"] = {
		pattern = "func%s+(.-)%((.-)%)",
		analyser = function(index, parent_keyword, key, value)
			if not safe(key, "or", "extvariable", "reserved") then
				syntaxerror(index, "Invalid function name")
			end
			value = slice(value, ",", function(argument)
				argument = string.match(argument, "^%s*(.-)%s*$")
				if not string.match(argument, "[_%a][_%w]*") and argument ~= "..." then
					syntaxerror(index, "Invalid function argument")
				end
				return argument
			end)
			return {
				keyword = "function",
				storage = (parent_keyword and not(parent_keyword == "global")) and "local" or nil,
				key = key,
				value = #value > 0 and value or nil,
				body = {}
			}
		end
	};

	["return"] = {
		pattern = "return%s+(.-)$",
		analyser = function(index, parent_keyword, value)
			if not(parent_keyword == "function") then
				syntaxerror(index, "Keyword used outside function declaration")
			end
			return {
				keyword = "return",
				value = value
			}
		end
	};

	["type"] = {
		pattern = "type%s+([_%a][_%w]*){(.-)}",
		analyser = function(index, parent_keyword, key, value)
			if parent_keyword ~= "global" then
				syntaxerror(index, "Prototypes cannot be declared inside other structures")
			end
			if not safe(key, "only", "reserved") then
				syntaxerror(index, "Prototype name cannot be a reserved keyword")
			end
			value = string.match(value, "^%s*(.-)%s*$")
			if #value >0 and not string.match(value, "[_%a][_%w]*") then
				syntaxerror(index, "Parent prototype invalid name")
			end
			return {
				keyword = "prototype",
				key = key,
				value = #value > 0 and value or nil,
				body = {}
			}
		end
	};

	["if"] = {
		pattern = "if%s+(.-)$",
		analyser = function(index, parent_keyword, value)
			return {
				keyword = "if",
				value = value,
				body = {}
			}
		end
	};

	["elseif"] = {
		pattern = "if%s+(.-)$",
		analyser = function(index, parent_keyword, value)
			return {
				before = {
					"if",
					"elseif"
				},
				keyword = "elseif",
				value = value,
				body = {}
			}
		end
	};

	["else"] = {
		pattern = "else",
		analyser = function(index, parent_keyword)
			return {
				before = {
					"if",
					"elseif"
				},
				keyword = "else",
				body = {}
			}
		end
	};

	["while"] = {
		pattern = "while%s+(.-)$",
		analyser = function(index, parent_keyword, value)
			if string.match(value, "%d+") or string.match(value, "%b\"\"") then
				syntaxerror(index, "Invalid condition")
			end
			return {
				keyword = "while",
				value = value,
				body = {}
			}
		end
	};

	["until"] = {
		pattern = "until%s+(.-)$",
		analyser = function(index, parent_keyword, value)
			if string.match(value, "^%d+$") or string.match(value, "%b\"\"") then
				syntaxerror(index, "Invalid condition")
			end
			return {
				keyword = "until",
				value = value,
				body = {}
			}
		end
	};

	["for"] = {
		pattern = "for%s+([_%a][_%w]*)%s+=%s+(.-)%s+to%s+(.-)$",
		analyser = function(index, parent_keyword, key, value, tail)
			if not safe(value, "or", "number", "extvariable") then
				syntaxerror(index, "Invalid for loop start value")
			end
			local finish, step = string.match(tail, "(.-)%s+step%s+(.-)$")
			if not finish and not step then
				finish = tail
			end
			if not safe(finish, "or", "number", "extvariable") then
				syntaxerror(index, "Invalid for loop finish value")
			end
			if step and not safe(step, "or", "number", "extvariable") then
				syntaxerror(index, "Invalid for loop step value")
			end
			return {
				keyword = "numeric-for",
				value = value,
				before = finish,
				after = step,
				body = {}
			}
		end
	};

	["foreach"] = {
		pattern = "foreach%s+(%b[])%s+in%s+([_%a][_%w%.]*[_%w]*)$",
		analyser = function(index, parent_keyword, value, after)
			
			return {
				keyword = "numeric-for",
				value = value,
				before = finish,
				after = step,
				body = {}
			}
		end
	};

	["break"] = {
		pattern = "break",
		analyser = function(index, parent_keyword)
			if (parent_keyword == "variable" or parent_keyword == "if" or parent_keyword == "elseif" or parent_keyword == "else") then
				syntaxerror(index, "Break outside loop")
			end
			return {
				"break"
			}
		end
	};

}
local secondary_grammar = {

	["([_%a][_%w%.]*)(.-)$"] = function(index, parent_keyword, key, tail)
		local keyword
		local value = string.match(tail, "%((.-)%)")
		if value then
			keyword = "call"
		else
			keyword = "assignment"
			value = string.match(tail, "^%s*=%s*([_%w%(%[].-)$")
			if (parent_keyword == "variable" and string.find(key, "%.")) or (string.len(tail) >= 0 and not value) then
				if not safe(key, "and", "extvariable", "reserved") then
					syntaxerror(index)
				end
				syntaxerror(index, "Misshaped variable declaration")
			end
		end
		return {
			keyword = keyword,
			key = key,
			value = substitute(value)
		}
	end;

}