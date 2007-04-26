-----------------------------------------------------------------------------
-- log.lua
-----------------------------------------------------------------------------

--[[
=head1 NAME

jive.util.log - logging facility

=head1 DESCRIPTION

A basic logging facility by category and level. Functionality based on improved lualogging.

=head1 SYNOPSIS

 -- create a log of a given category (screensaver.flickr) and at a given level (DEBUG)
 local log = jive.utils.log.addCategory("screensaver.flickr", jive.utils.log.DEBUG)

 -- get the logger for a category that should exist
 local log = jive.utils.log.logger("net.http")

 -- typically at the top of a module, you'd do
 local log = require("jive.utils.log").logger("net.http") 

 -- log something
 log:debug("hello world")

 -- prints
 161845:39202 DEBUG (somefile.lua:45) - Hello world

 -- format is
 -- Time (HHMMSS) : ticks (ms) LEVEL (source file:line) - message


The logging functions concatenate data more efficiently than operator .. does, so
for best performance, do 

 log:debug("Welcome ", first_name, ", thanks for visiting us ", time_of_day)

rather than

 log:debug("Welcome " .. first_name .. ", thanks for visiting us " .. time_of_day)

If the first parameter is a table, it is rendered as a string.

=cut
--]]

local debug     = require("debug")
local string    = require("string")
local table     = require("table")

local logging   = require("logging")
local Framework = require("jive.ui.Framework")

local find, sub, format = string.find, string.sub, string.format
local print, assert, type = print, assert, type
local concat = table.concat
local getinfo = debug.getinfo
local date = os.date

module(...)

--[[

=head1 LEVELS

The following levels are defined: DEBUG, INFO, WARN, ERROR and FATAL.
They are defined in the module and can therefore be accessed using jive.utils.log.LEVEL,
for example jive.utils.log.DEBUG.

=cut
--]]

-- re-define the logging levels, so we can say jive.utils.log.DEBUG
DEBUG = logging.DEBUG
INFO = logging.INFO
WARN = logging.WARN
ERROR = logging.ERROR
FATAL = logging.FATAL


-- jiveLogger
-- our Lualogging "appender"
local function jiveLogger(level)

	return logging.new(
		function(self, level, ...)
		
			-- figure out the source file and line
			local info = getinfo(4, "Sl")
			local where = find(info.short_src, "/[%w_]-.lua", 1)
			if where == nil then
				where = 0
			end
			local source = sub(info.short_src, where+1)
			
			-- print the message
			print(
				format(
					"%s:%s %s (%s:%d) - %s", 
					date("%H%M%S"),
					Framework:getTicks(),
					level,
					source, 
					info.currentline or "?",
					concat({...})
				)
			)
			return true
		end,
		level
	)

end


-- the root logger
local log = jiveLogger(logging.WARN)


--[[

=head1 CATEGORIES

Categories are strings. The following are the default categories:

 -- browser
 -- applets
 -- screensavers

 -- slimserver
 -- slimserver.cache
 -- player

 -- net.cli
 -- net.thread
 -- net.socket
 -- net.http

 -- ui
=cut
--]]

-- table to contain all the loggers indexed by category
local categories = {
	["browser"]          = jiveLogger(logging.WARN),
	["applets"]          = jiveLogger(logging.WARN),
	["screensavers"]     = jiveLogger(logging.WARN),

	["slimserver"]       = jiveLogger(logging.WARN),
	["slimserver.cache"] = jiveLogger(logging.DEBUG),
	["player"]           = jiveLogger(logging.WARN),
                         
	["net.cli"]          = jiveLogger(logging.WARN),
	["net.thread"]       = jiveLogger(logging.WARN),
	["net.socket"]       = jiveLogger(logging.WARN),
	["net.http"]         = jiveLogger(logging.WARN),
	
	["ui"]               = jiveLogger(logging.WARN),
}

--[[

=head1 FUNCTIONS

=cut
--]]

--[[

=head2 logger(category)

Returns the logger of the given category. It is an error if the category does not exist and
a default logger is returned in that case.

=cut
--]]
function logger(category)

	local found=categories[category]
	if found then
		return found
	else
		log:error("Log category ", category, " does not exist => returning default logger")
		return log
	end
end


--[[

=head2 addCategory(category, initialLevel)

Creates and returns a logger of the given category. 

=cut
--]]
function addCategory(category, initialLevel)

	assert(category, "addLogCategory requires a category")
	assert(type(category) == "string", "category must be a string")
	
	local level = initialLevel or WARN
	
	local log = jiveLogger(level)
	categories[category] = log
	return log
end


--[[

=head2 logger:log(level, message, ...)

Logs a message at the given level in the given logger. message and ... are concatenated before
output. If message is a table, it is rendered as string; tables that refer to themselves are not
supported however.

=cut
--]]


--[[

=head2 logger:<level>(message, ...)

Utility functions that call log(<level>, message, ...), for example

 log:debug("bla")

This are defined dynamically depending on the current log level, so
are faster than log(level, messsage).
=cut
--]]


--[[

=head2 logger:getLevel()

Returns the level of the logger (one of jive.log.DEBUG, etc.)

=cut
--]]


--[[

=head2 logger:isDebug()

Returns true if the level of the logger is DEBUG, this enables diagnostic code
to be run only when in debug. Particularly useful if the code is expensive.

=cut
--]]


--[[

=head2 getCategories()

Returns all loggers in an array with categories as keys.

=cut
--]]
function getCategories()
	return categories
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

