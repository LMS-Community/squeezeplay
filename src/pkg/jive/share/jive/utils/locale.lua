
--[[
=head1 NAME

jive.utils.locale - Deliver strings based on locale (defaults to EN) and path

=head1 DESCRIPTION

Parses strings.txt from appropriate directory and sends it back as a table

=head1 FUNCTIONS

setLocale(locale)

readStringsFile(thisPath)

=cut
--]]

-- stuff we use
local ipairs, pairs, assert, io, setmetatable, string = ipairs, pairs, assert, io, setmetatable, string

local log              = require("jive.utils.log").logger("utils")


module(...)


-- current locale
local globalLocale = "EN"

-- all locales seen in strings.txt files
local allLocales = {}

-- weak table containing loaded locales
local loadedFiles = {}
setmetatable(loadedFiles, { __mode = "v" })



--[[
=head 2 setLocale(newLocale)

Set a new locale. All strings already loaded are reloaded from the strings
file for the new locale.

=cut
--]]
function setLocale(newLocale)
	if newLocale == globalLocale then
		return
	end

	globalLocale = newLocale

	-- reload existing strings files
	for k, v in pairs(loadedFiles) do
		log:warn("reloaded strings from ", k)
		readStringsFile(k, v)
	end
end


--[[
=head2 getLocale()

Returns the current locale.

=cut
--]]
function getLocale()
	return globalLocale
end


--[[
=head2 getAllLocales()

Returns all locales.

=cut
--]]
function getAllLocales()
	local array = {}
	for locale, _ in pairs(allLocales) do
		array[#array + 1] = locale
	end
	return array
end


--[[
=head2 readStringsFile(path)

Parse strings.txt file and put all locale translations into a lua table
that is returned. The strings are for the current locale.

=cut
--]]
function readStringsFile(fullPath, stringsTable)
	stringsTable = stringsTable or {}

	local myLocale = globalLocale

	local stringsFile = io.open(fullPath)
	if stringsFile == nil then
		return stringsTable
	end

	loadedFiles[fullPath] = stringsTable

	-- meta table for strings
	local mt = {
		__tostring = function(e)
				     return e.str .. "{" .. myLocale .. "}"
			     end
	}

	local thisString 
	while true do
		local line = stringsFile:read()
		if not line then
			break
		end

		-- remove one or more control chars from the end of line (newline and any stray tabs)
		line = string.gsub(line, '%c+$', '')
		-- lines that begin with an uppercase char are the strings to translate
		if string.match(line, '^%u') then
			thisString = line
			log:debug("this is a string to be matched |", thisString, "|")
		else
			-- look for matching translation lines.
			-- defined here as one or more tabs
			-- followed by one or more non-spaces (lang)
			-- followed by one or more tabs
			-- followed by the rest (the translation)
			local locale, translatedString  = string.match(line, '^\t+([^%s]+)\t+(.+)')

			-- remember all locales seen
			if locale ~= nil then
				allLocales[locale] = true
			end

			if locale == myLocale and thisString and translatedString then
				-- dump the translations to log:debug
				log:debug("strings.txt data\nlocale=", locale, "\nthisString = ", thisString, "translatedString = ", translatedString, "\n\n")

				-- wrap the string in a table to allow the
				-- localized value to be changed if a different
				-- locale is loaded.
				local str = stringsTable[thisString] or {}
				str.str = translatedString
				setmetatable(str, mt)
				stringsTable[thisString] = str
			end
		end
	end
	stringsFile:close()
	return stringsTable
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

