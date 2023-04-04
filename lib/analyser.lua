local keywords = {
	forbidden = "rem var func type if elseif else while until for to step foreach in",
	warning = "break true false undefined"
}
local patterns = {
	["string"] = function(str)
		return string.match(str, [[^%b""$]]) or false
	end,
	["number"] = function(str)
		return string.match(str, "^%-?[0-9]*%.?[0-9]*$") and string.sub(str, -1) ~= "."
	end,
	["boolean"] = function(str)
		for keyword in string.gmatch("true false undefined", "%w+") do
			if str == keyword then
				return true
			end
		end
		return false
	end,
	["record"] = function(str)
		return string.match(str, "^%b[]$")
	end,
	["variable"] = function(str)
		if not string.match(str, "^[_%a][_%w]*$") then
			return false
		end
		return true
	end,
	["variable-access"] = function(str, typeof)
		if not string.match(str, "^[_%w%.%[%]\"]+$") then
			return false
		end
		for key in string.gmatch(str .. ".", "(.-)%f[%.]") do
			local value, after = string.match(key, "^[_%a][_%w]*%[(\"[_%a][_%w]*\")(.)$")
			if value then
				if after ~= "]" then
					return false
				end
			else
				if not string.match(key, "^[_%a][_%w]*$") then
					return false
				end
			end
			if not typeof(key) then
				return false
			end
			for keyword in string.gmatch(keywords.warning, "%w+") do
				if str == keyword then
					return false
				end
			end
		end
		return true
	end,
	["function-call"] = function(str, typeof)
		local key, value, after = string.match(str, "^(.-)%((.-)(.)$")
		if not key then
			return false
		end
		if value and after ~= ")" then
			return false
		end
		if not typeof(key, "variable-access") then
			return false
		end
		return key and value and after and true
	end
}
local function error(index, msg)
	msg = msg and (". (" .. msg .. ")") or "."
	io.write("Lisle: Syntax error in line " .. tostring(index) .. msg .. "\n")
	os.exit()
end
local function typeof(str, ...)
	local allowed
	for keyword in string.gmatch(keywords.forbidden, "%w+") do
		if str == keyword then
			return false
		end
	end
	if select("#", ...) == 0 then
		allowed = true
	else
		for _, typecheck in ipairs({...}) do
			allowed = patterns[typecheck](str, typeof) or allowed
		end
	end
	return allowed
end
return {
	error = error,
	typeof = typeof
}
