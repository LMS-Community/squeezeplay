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
-- Title  : Stream that Serializes and Restores Values from Sockets           --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 12/09/2006 00:59                                                  --
--------------------------------------------------------------------------------

local assert = assert
local select = select
local table = require "table"
local oo = require "loop.simple"
local Serializer = require "loop.serial.Serializer"

module"loop.serial.SocketStream"

oo.class(_M, Serializer)

function write(self, ...)
	for i=1, select("#", ...) do
		self.buffer[#self.buffer+1] = select(i, ...)
	end
end

function put(self, ...)
	self.buffer = {}
	self:serialize(...)
	assert(self.socket:send(table.concat(self.buffer).."\0\n"))
	self.buffer = nil
end

function get(self)
	local lines = {}
	local line
	repeat
		line = assert(self.socket:receive())
		if line and line:find("%z$") then
			lines[#lines+1] = line:sub(1, #line-1)
			break
		end
		lines[#lines+1] = line
	until not line
	return assert(self:load("return "..table.concat(lines, "\n")))()
end
