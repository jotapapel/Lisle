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

local function syntaxerror(index, msg)
	msg = msg and (". (" .. msg .. ")") or "."
	io.write("Lisle: Syntax error in line " .. tostring(index) .. msg .. "\n")
	os.exit() 
end

local function safe(str, ...)
	
end

return {
	error = syntaxerror
}