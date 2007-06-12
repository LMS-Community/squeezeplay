-------------------------------------------------------------------------------
-- $Id: logging.lua,v 1.8 2006/08/14 18:11:59 carregal Exp $
-- includes a new tostring function that handles tables recursively
--
-- Authors:
--   Danilo Tuler (tuler@ideais.com.br)
--   André Carregal (carregal@keplerproject.org)
--   Thiago Costa Ponte (thiago@ideais.com.br)
--
-- Copyright (c) 2004-2006 Kepler Project
-------------------------------------------------------------------------------

local type, table, string, assert, _tostring, tonumber = type, table, string, assert, tostring, tonumber

module("logging")

-- Meta information
_COPYRIGHT = "Copyright (C) 2004-2006 Kepler Project"
_DESCRIPTION = "A simple API to use logging features in Lua"
_VERSION = "LuaLogging 1.1.2"

-- The DEBUG Level designates fine-grained instring.formational events that are most
-- useful to debug an application
DEBUG = "DEBUG"

-- The INFO level designates instring.formational messages that highlight the
-- progress of the application at coarse-grained level
INFO = "INFO"

-- The WARN level designates potentially harmful situations
WARN = "WARN"

-- The ERROR level designates error events that might still allow the
-- application to continue running
ERROR = "ERROR"

-- The FATAL level designates very severe error events that will presumably
-- lead the application to abort
FATAL = "FATAL"

LEVEL_H = {
	[DEBUG] = 1,
	[INFO]  = 2,
	[WARN]  = 3,
	[ERROR] = 4,
	[FATAL] = 5,
}

LEVEL_A = { 
	DEBUG, 
	INFO, 
	WARN, 
	ERROR, 
	FATAL 
}

local funcs = {
	debug = function (logger, ...) return logger:log(DEBUG, ...) end,
	info  = function (logger, ...) return logger:log(INFO,  ...) end,
	warn  = function (logger, ...) return logger:log(WARN,  ...) end,
	error = function (logger, ...) return logger:log(ERROR, ...) end,
	fatal = function (logger, ...) return logger:log(FATAL, ...) end,
	dummy = function() end,
}


-------------------------------------------------------------------------------
-- Creates a new logger object
-------------------------------------------------------------------------------
function new(append, level)

	if type(append) ~= "function" then
		return nil, "Appender must be a function."
	end

	local logger = {}
    logger.append = append

	logger.log = function (self, level, message, ...)
		assert(LEVEL_H[level], string.format("undefined level `%s'", tostring(level)))
		if LEVEL_H[level] < LEVEL_H[self.level] then
			return
		end
		-- check the type of the first argument, if not string then
		-- use our tostring function to convert it to a string...
		if type(message) ~= "string" then
			return logger:append(level, tostring(message), ...)
		end
		return logger:append(level, message, ...)
	end


	logger.setLevel = function (self, level)
		local li = LEVEL_H[level]
		assert(li, string.format("undefined level `%s'", tostring(level)))
		self.level = level
		for i=1,5 do
			if i<li then
				logger[string.lower(LEVEL_A[i])] = funcs.dummy
			else
				logger[string.lower(LEVEL_A[i])] = funcs[string.lower(LEVEL_A[i])]
			end
		end
	end
	logger.getLevel = function (self)
		return self.level
	end
	logger.isDebug = function(self)
		return self.level == DEBUG
	end

	logger.setLevel(logger, level or DEBUG)

	return logger
end


-------------------------------------------------------------------------------
-- Prepares the log message
-------------------------------------------------------------------------------
function prepareLogMsg(pattern, dt, level, message)

    local logMsg = pattern or "%date %level %message\n"
    message = string.gsub(message, "%%", "%%%%")
    logMsg = string.gsub(logMsg, "%%date", dt)
    logMsg = string.gsub(logMsg, "%%level", level)
    logMsg = string.gsub(logMsg, "%%message", message)
    return logMsg
end


-------------------------------------------------------------------------------
-- Converts a Lua value to a string
--
-- Converts Table fields in alphabetical order
-------------------------------------------------------------------------------
function tostring(value)
  local str = ''

  if (type(value) ~= 'table') then
    if (type(value) == 'string') then
      str = string.format("%q", value)
    else
      str = _tostring(value)
    end
  else
    local auxTable = {}
    table.foreach(value, function(i, v)
      if (tonumber(i) ~= i) then
        table.insert(auxTable, i)
      else
        table.insert(auxTable, tostring(i))
      end
    end)
    table.sort(auxTable)

    str = str..'{'
    local separator = ""
    local entry = ""
    table.foreachi (auxTable, function (i, fieldName)
      if ((tonumber(fieldName)) and (tonumber(fieldName) > 0)) then
        entry = tostring(value[tonumber(fieldName)])
      else
        entry = fieldName.." = "..tostring(value[fieldName])
      end
      str = str..separator..entry
      separator = ", "
    end)
    str = str..'}'
  end
  return str
end
