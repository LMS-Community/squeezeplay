
require("json")


function dump(o, d)
	d = (d or "") .. "  "

	if type(o) == "number" then
		print(o)
	elseif type(o) == "string" then
		print(string.format("%q", o))
	elseif type(o) == "boolean" then
		print('bool(' .. tostring(o)..')')
	elseif type(o) == "table" then
		print(d .. "{")
		for k,v in pairs(o) do
			io.write(string.format('%s \"%s\": ', d, k))
			dump(v, d)
		end
		print(d .. "}")
	elseif o == json.null then
		print('null')
	elseif o == nil then
		print('nil')
	else
		error("cannot dump a " .. type(o))
	end
end




--file = io.open("test/pass1.json", "r")
file = io.open(arg[1], "r")

body = {}
for line in file:lines() do
	body[#body + 1] = line
end
body = table.concat(body)

ok = json.decode(body)

--dump(ok)

out = json.encode(ok)

print(out)
