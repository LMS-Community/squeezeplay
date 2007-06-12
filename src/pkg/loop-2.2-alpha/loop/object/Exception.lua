--------------------------------------------------------------------------------
---------------------- ##       #####    #####   ######  -----------------------
---------------------- ##      ##   ##  ##   ##  ##   ## -----------------------
---------------------- ##      ##   ##  ##   ##  ######  -----------------------
---------------------- ##      ##   ##  ##   ##  ##      -----------------------
---------------------- ######   #####    #####   ##      -----------------------
----------------------                                   -----------------------
----------------------- Lua Object-Oriented Programming ------------------------
--------------------------------------------------------------------------------
-- Project: LOOP Class Library                                                --
-- Release: 2.2 alpha                                                         --
-- Title  : Data structure to hold information about exceptions in Lua        --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 03/08/2005 16:35                                                  --
--------------------------------------------------------------------------------

local error     = error
local type      = type
local traceback = debug and debug.traceback

local table = require "table"
local oo    = require "loop.base"

module("loop.object.Exception", oo.class)

function __init(class, object)
	if traceback then
		if not object then
			object = { traceback = traceback() }
		elseif object.traceback == nil then
			object.traceback = traceback()
		end
	end
	return oo.rawnew(class, object)
end

function __concat(op1, op2)
	if oo.instanceof(op1, _M) then
		op1 = op1:__tostring()
	elseif type(op1) ~= "string" then
		error("attempt to concatenate a "..type(op1).." value")
	end
	if oo.instanceof(op2, _M) then
		op2 = op2:__tostring()
	elseif type(op2) ~= "string" then
		error("attempt to concatenate a "..type(op2).." value")
	end
	return op1 .. op2
end

function __tostring(self)
	local message = { self[1] or _NAME," raised" }
	if self.message then
		message[#message + 1] = ": "
		message[#message + 1] = self.message
	end
	if self.traceback then
		message[#message + 1] = "\n"
		message[#message + 1] = self.traceback
	end
	return table.concat(message)
end