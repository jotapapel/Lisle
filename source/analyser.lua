local patterns = {
	["keywords"] = "rem var func return type if elseif else while until for to step foreach in break true false nil",
	["key"] = "^[_%a][_%w]*$",
	["number"] = "^%-?[0-9]*%.?[0-9]*$",
	["call"] = function(str)
		local k, v = string.match(str, "^([_%a][_%w%.]*)(%b())$")
		return k and v
	end,
	["record"] = "^%b[]$"
}

local function error(index, msg)
	msg = msg and (". (" .. msg .. ")") or "."
	io.write("Lisle: Syntax error in line " .. tostring(index) .. msg .. "\n")
	os.exit() 
end

local function safe(str, ...)
	for keyword in string.gmatch(patterns["keywords"], "%w+") do
		if str == keyword then
			return false
		end
	end
	for _, check in ipairs({...}) do
		if type(patterns[check]) == "string" then
			if not string.match(str, patterns[check]) then
				return false
			end
		elseif type(patterns[check]) == "function" then
			if not patterns[check](str) then
				return false
			end
		end
		if string.sub(str, -1) == "." then
			return false
		end
	end
	return true
end

return {
	error = error,
	issafe = safe
}