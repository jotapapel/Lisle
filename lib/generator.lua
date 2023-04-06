local chunk = "(a == 32 && b) or false"
for part in string.gmatch(chunk, "%S+") do
	print(part)
end