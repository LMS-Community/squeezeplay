
--[[
=head1 NAME

jive.util.serialize - table serializer.

=head1 DESCRIPTION

Table serializer. From PIA chapter 12.1.2 Saving Table with Cycles.

=head1 SYNOPSIS

 file = io.open("output.lua")
 serialize.save(file, name, value)

--]]


local string = require("string")

local pairs, tostring, type = pairs, tostring, type

module(...)


function basicSerialize (o)
	if type(o) == "number" then
		return tostring(o)
	elseif type(o) == "boolean" then
		if o == true then
			return "true"
		else
			return "false"
		end
	else   -- assume it is a string
		return string.format("%q", o)
	end
end


function save (file, name, value, saved)
	saved = saved or {}       -- initial value
	file:write(name, " = ")
	if type(value) == "number" or type(value) == "string" then
		file:write(basicSerialize(value), ";\n")
	elseif type(value) == "table" then
		if saved[value] then    -- value already saved?
			file:write(saved[value], ";\n")  -- use its previous name
		else
			saved[value] = name   -- save name for next time
			file:write("{};\n")     -- create a new table
			for k,v in pairs(value) do      -- save its fields
				local fieldname = string.format("%s[%s]", name,
								basicSerialize(k))
				save(file, fieldname, v, saved)
			end
		end
	elseif type(value) == "boolean" then
		file:write(basicSerialize(value), ";\n")
	else
		error("cannot save a " .. type(value))
	end
end

