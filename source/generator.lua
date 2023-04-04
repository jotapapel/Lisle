local str = "_var = 32"
print(string.match(str, "^(.-)%s*=%s*(.-)$"))
