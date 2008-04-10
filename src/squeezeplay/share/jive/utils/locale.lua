
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
local ipairs, pairs, io, select, setmetatable, string, tostring = ipairs, pairs, io, select, setmetatable, string, tostring

local log              = require("jive.utils.log").logger("utils")
local Framework        = require("jive.ui.Framework")
local Task             = require("jive.ui.Task")

module(...)


-- current locale
local globalLocale = "EN"

-- all locales seen in strings.txt files
local allLocales = {}

-- weak table containing loaded locales
local loadedFiles = {}
setmetatable(loadedFiles, { __mode = "v" })

-- weak table containing global strings
local globalStrings = {}

--[[
=head 2 setLocale(newLocale)

Set a new locale. All strings already loaded are reloaded from the strings
file for the new locale.

=cut
--]]
function setLocale(self, newLocale, doYield)
	if newLocale == globalLocale then
		return
	end

	globalLocale = newLocale or "EN"
	readGlobalStringsFile(self)

for i=1,100 do
	-- reload existing strings files
	for k, v in pairs(loadedFiles) do
		if doYield then
			Task:yield(true)
		end
		_parseStringsFile(self, newLocale, k, v)
	end
end
end


--[[
=head2 getLocale()

Returns the current locale.

=cut
--]]
function getLocale(self)
	return globalLocale
end


--[[
=head2 getAllLocales()

Returns all locales.

=cut
--]]
function getAllLocales(self)
	local array = {}
	for locale, _ in pairs(allLocales) do
		array[#array + 1] = locale
	end
	return array
end

--[[

=head2 readStringsFile(self, fullPath, stringsTable)

Parse strings.txt file and put all locale translations into a lua table
that is returned. The strings are for the current locale.

=cut
--]]

function readGlobalStringsFile(self)
	local globalStringsPath = Framework:findFile("jive/global_strings.txt")
	if globalStringsPath == nil then
		return globalStrings
	end
	globalStrings = _parseStringsFile(self, globalLocale, globalStringsPath, globalStrings)
	setmetatable(globalStrings, { __index = self , mode = "_v" })
	return globalStrings
end

function readStringsFile(self, fullPath, stringsTable)
	log:debug("loading strings from ", fullPath)
	--local defaults = getDefaultStrings(self)

	stringsTable = stringsTable or {}
	loadedFiles[fullPath] = stringsTable
	setmetatable(stringsTable, { __index = globalStrings })
	stringsTable = _parseStringsFile(self, globalLocale, fullPath, stringsTable)

	return stringsTable
end

function _parseStringsFile(self, myLocale, myFilePath, stringsTable)
	log:debug("starting to parse", myFilePath)

	local stringsFile = io.open(myFilePath)
	if stringsFile == nil then
		return stringsTable
	end
	stringsTable = stringsTable or {}

	-- meta table for strings
	local strmt = {
		__tostring = function(e)
				     return e.str -- .. "{" .. myLocale .. "}"
			     end,
	}
	local thisString 
	while true do
		local line = stringsFile:read()
		if not line then
			break
		end

		-- remove trailing spaces and/or control chars
		line = string.gsub(line, "[%c ]+$", '')
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

				-- convert \n to \n
				translatedString = string.gsub(translatedString, "\\n", "\n")

				-- wrap the string in a table to allow the
				-- localized value to be changed if a different
				-- locale is loaded.
				local str = stringsTable[thisString] or {}
				str.str = translatedString
				setmetatable(str, strmt)
				stringsTable[thisString] = str
				log:debug("translated string: |", thisString, "|", stringsTable[thisString].str, "|")
			end
		end
	end
	stringsFile:close()

	return stringsTable
end


--[[

=head2 loadAllStrings(self, filePath)

Parse strings.txt file and put all locale translations into a lua table
that is returned. Strings for all locales are returned.

=cut
--]]
function loadAllStrings(self, myFilePath)
	local stringsFile = io.open(myFilePath)
	if stringsFile == nil then
		return {}
	end
	
	local allStrings = {}
	local thisString 
	while true do
		local line = stringsFile:read()
		if not line then
			break
		end

		-- remove trailing spaces and/or control chars
		line = string.gsub(line, "[%c ]+$", '')
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

			if thisString and translatedString then
				-- convert \n to \n
				translatedString = string.gsub(translatedString, "\\n", "\n")

				if allStrings[locale] == nil then
					allStrings[locale] = {}
				end

				allStrings[locale][thisString] = translatedString
			end
		end
	end
	stringsFile:close()

	return allStrings
end


function str(self, token, ...)
	if select('#', ...) == 0 then
		return self[token] or token
	else
		return string.format(self[token].str or token, ...)
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

