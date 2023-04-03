local function error(index, msg)
	msg = msg and (". (" .. msg .. ")") or "."
	io.write("Lisle: Syntax error in line " .. tostring(index) .. msg .. "\n")
	os.exit() 
end

local patterns = {
	["keywords"] = "rem var func return type if elseif else while until for to step foreach in break true false nil",
	["string"] = function(str)
		return string.match(str, [[^%b""$]])
	end,
	["number"] = function(str)
		return string.match(str, "^%-?[0-9]*%.?[0-9]*$") and not string.sub(str, -1) == "."
	end,
	["boolean"] = function(str)
		for keyword in string.gmatch("true false undefined", "%w+") do
			if str == keyword then
				return true
			end
		end
		return false
	end,
	["variable"] = function(str, safe)
		if not string.match(str, "^[_%w%.%[%]\"]+$") then
			return false
		end
		for key in string.gmatch(str .. ".", "(.-)%f[%.]") do
			local access, closing = string.match(key, "^[_%a][_%w]*(%[\"[_%a][_%w]*\")(.)$")
			if access then
				if closing ~= "]" then
					return false
				end
			else
				if not string.match(key, "^[_%a][_%w]*$") then
					return false
				end
			end
			if not safe(key) then
				return false
			end
		end
		return true
	end,
	["functioncall"] = function(str, safe)
		local variable, args = string.match(str, "^(.-)(%b())$")
		return safe(variable, "variable") and args
	end,
	["record"] = function(str)
		return string.match(str, "^%b[]$")
	end
}

local function safe(str, ...)
	local allowed = true
	for keyword in string.gmatch(patterns["keywords"], "%w+") do
		if str == keyword then
			return false
		end
	end
	for _, check in ipairs({...}) do
		allowed = patterns[check](str, safe)
	end
	return allowed
end

return {
	error = error,
	issafe = safe
}