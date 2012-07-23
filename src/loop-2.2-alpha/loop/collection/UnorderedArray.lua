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
-- Title  : Array Optimized for Insertion/Removal that Doesn't Garantee Order --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 13/12/2004 13:51                                                  --
--------------------------------------------------------------------------------

local table = require "table"
local oo    = require "loop.base"

module("loop.collection.UnorderedArray", oo.class)

function add(self, value)
	self[#self + 1] = value
end

function remove(self, index)
	local size = #self
	if index == size then
		self[size] = nil
	elseif (index > 0) and (index < size) then
		self[index], self[size] = self[size], nil
	end
end