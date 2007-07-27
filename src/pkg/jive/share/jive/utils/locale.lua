
--[[
=head1 NAME

jive.utils.locale - Deliver strings based on locale (defaults to EN) and path

=head1 DESCRIPTION

Parses strings.txt from appropriate directory and sends it back as a table

=head1 FUNCTIONS

readStringsFile(thisLocale, thisPath)

takes
=cut
--]]

-- stuff we use
local ipairs, pairs, assert, io, string = ipairs, pairs, assert, io, string
local Framework        = require("jive.ui.Framework")
local log              = require("jive.utils.log").logger("applets.setup")
module(...)

-- parse strings.txt file and put all locale translations into a lua table that is returned
function readStringsFile(thisLocale, thisPath)
	local myLocale = thisLocale or "EN"
	local relativePath = "applets/" .. thisPath .. "/strings.txt"
	local fullPath = Framework:findFile(relativePath)
	local stringsFile = assert(io.open(fullPath))
	local stringsTable = {}

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
			if (locale == myLocale and thisString and translatedString) then
				-- dump the translations to log:debug
				log:debug("strings.txt data\nlocale=", locale, "\nthisString = ", thisString, "translatedString = ", translatedString, "\n\n")
				stringsTable[thisString] = translatedString
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

