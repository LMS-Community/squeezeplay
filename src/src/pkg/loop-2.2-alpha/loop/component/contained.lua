-------------------------------------------------------------------------------
---------------------- ##       #####    #####   ######  ----------------------
---------------------- ##      ##   ##  ##   ##  ##   ## ----------------------
---------------------- ##      ##   ##  ##   ##  ######  ----------------------
---------------------- ##      ##   ##  ##   ##  ##      ----------------------
---------------------- ######   #####    #####   ##      ----------------------
----------------------                                   ----------------------
----------------------- Lua Object-Oriented Programming -----------------------
-------------------------------------------------------------------------------
-- Title  : LOOP - Lua Object-Oriented Programming                           --
-- Name   : Component Model with Interception                                --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                --
-- Version: 3.0 work1                                                        --
-- Date   : 22/2/2006 16:18                                                  --
-------------------------------------------------------------------------------
-- Exported API:                                                             --
--   Type                                                                    --
-------------------------------------------------------------------------------

local oo          = require "loop.cached"
local base        = require "loop.component.wrapped"

module("loop.component.contained", package.seeall)

--------------------------------------------------------------------------------

BaseType = oo.class({}, base.BaseType)

function BaseType:__new(...)
	local comp = self.__component or self[1]
	if comp then comp = comp(...) end
	local state = {
		__component = comp,
		__home = self,
	}
	for port, class in pairs(self) do
		if type(port) == "string" and port:match("^%a[%w_]*$") then
			state[port] = class(comp and comp[port], comp)
		end
	end
	return state
end

function Type(type, ...)
	if select("#", ...) > 0
		then return oo.class(type, ...)
		else return oo.class(type, BaseType)
	end
end

--------------------------------------------------------------------------------

iports = base.iports
managedby = base.managedby