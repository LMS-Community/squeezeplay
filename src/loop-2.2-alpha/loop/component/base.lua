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
-- Name   : Base Component Model                                             --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                --
-- Version: 3.0 work1                                                        --
-- Date   : 22/2/2006 16:18                                                  --
-------------------------------------------------------------------------------
-- Exported API:                                                             --
--   Type                                                                    --
--   Facet                                                                   --
--   Receptacle                                                              --
--   ListReceptacle                                                          --
--   HashReceptacle                                                          --
--   SetReceptacle                                                           --
-------------------------------------------------------------------------------

local oo = require "loop.cached"

module("loop.component.base", package.seeall)

--------------------------------------------------------------------------------

BaseType = oo.class()

function BaseType:__call(...)
	return self:__build(self:__new(...))
end

function BaseType:__new(...)
	local comp = self.__component or self[1]
	if comp then
		comp = comp(...)
		comp.__home = self
		comp.__component = comp
	else
		comp = { __home = self }
	end
	for port, class in pairs(self) do
		if type(port) == "string" and port:match("^%a[%w_]*$") then
			comp[port] = class(comp[port], comp)
		end
	end
	return comp
end

local function tryindex(segment) return segment.context end
function BaseType:__setcontext(segment, context)
	local success, setcontext = pcall(tryindex, segment)
	if success and setcontext ~= nil then
		if type(setcontext) == "function"
			then setcontext(segment, context)
			else segment.context = context
		end
	end
end

function BaseType:__build(comp)
	for port in pairs(self) do
		if port == 1
			then self:__setcontext(comp.__component, comp)
			else self:__setcontext(comp[port], comp)
		end
	end
	for port, class in oo.allmembers(oo.classof(self)) do
		if port:find("^%a") then
			class(comp, port, comp)
		end
	end
	return comp
end

function Type(type, ...)
	if select("#", ...) > 0
		then return oo.class(type, ...)
		else return oo.class(type, BaseType)
	end
end

--------------------------------------------------------------------------------

local nextmember

local function portiterator(state, name)
	local port
	repeat
		name, port = nextmember(state, name)
		if name == nil then return end
	until name:find("^%a")
	return name, port
end

function iports(component)
	local state, var
	nextmember, state, var = oo.allmembers(oo.classof(component.__home))
	return portiterator, state, var
end

function managedby(component, home)
	return (component.__home == home)
end

--------------------------------------------------------------------------------

function Facet(segments, name)
	segments[name] = segments[name] or segments.__component
	return false
end

--------------------------------------------------------------------------------

function Receptacle()
	return false
end

--------------------------------------------------------------------------------

MultipleReceptacle = oo.class{
	__all = pairs,
	__hasany = next,
	__get = rawget,
}

function MultipleReceptacle:__init(segments, name)
	local receptacle = oo.rawnew(self, segments[name])
	segments[name] = receptacle
	return receptacle
end

function MultipleReceptacle:__newindex(key, value)
	if value == nil
		then self:__unbind(key)
		else self:__bind(value, key)
	end
end

function MultipleReceptacle:__unbind(key)
	local port = rawget(self, key)
	rawset(self, key, nil)
	return port
end

--------------------------------------------------------------------------------

ListReceptacle = oo.class({}, MultipleReceptacle)

function ListReceptacle:__bind(port)
	local index = #self + 1
	rawset(self, index, port)
	return index
end

--------------------------------------------------------------------------------

HashReceptacle = oo.class({}, MultipleReceptacle)

function HashReceptacle:__bind(port, key)
	rawset(self, key, port)
	return key
end

--------------------------------------------------------------------------------

SetReceptacle = oo.class({}, MultipleReceptacle)

function SetReceptacle:__bind(port)
	rawset(self, port, port)
	return port
end

--------------------------------------------------------------------------------

_M[Facet         ] = "Facet"
_M[Receptacle    ] = "Receptacle"
_M[ListReceptacle] = "ListReceptacle"
_M[HashReceptacle] = "HashReceptacle"
_M[SetReceptacle ] = "SetReceptacle"
