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
-------------------------------------------------------------------------------

module("loop.component.instrospection", package.seeall)

-------------------------------------------------------------------------------

local PortType = {}

function ports(model)
	for name, type in pairs(model) do
		if name:match("^%u%l*$") then
			PortType[type] = name
		end
	end
end

-------------------------------------------------------------------------------

local function iterator(comp, name)
	local name, port
	repeat
		name = next(comp, name)
		if name == nil then return end
	until type(name) == "string" and name:find("^%a")
	local home = comp.__home
	local port = oo.classof(comp.__home)[name] or home[name]
	return name, port
end

function iports(component)
	component = rawget(component, "__container") or component
	return iterator, component
end