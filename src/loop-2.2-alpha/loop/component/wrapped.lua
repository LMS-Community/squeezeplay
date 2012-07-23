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
local base        = require "loop.component.base"

module("loop.component.wrapped", package.seeall)

--------------------------------------------------------------------------------

local ExternalState = oo.class()

function ExternalState:__index(name)
	self = self.__container
	local state = self.__state
	local port, manager = state[name], self[name]
	if port and manager
		then return rawget(manager, "__external") or manager
		else return port or state.__component[name]
	end
end

function ExternalState:__newindex(name, value)
	self = self.__container
	local state = self.__state
	local manager = self[name]
	if manager and manager.__bind then
		manager:__bind(value)
	elseif manager ~= nil then
		state[name] = value
	else
		state.__component[name] = value
	end
end

--------------------------------------------------------------------------------

BaseType = oo.class({}, base.BaseType)

function BaseType:__container(segments)
	local container = {
		__state    = segments,
		__internal = segments,
	}
	container.__external = ExternalState{ __container = container }
	return container
end

function BaseType:__build(segments)
	local container = self:__container(segments)
	local state = container.__state
	local context = container.__internal
	for port in pairs(self) do
		if port == 1
			then self:__setcontext(segments.__component, context)
			else self:__setcontext(segments[port], context)
		end
	end
	for port, class in oo.allmembers(oo.classof(self)) do
		if port:find("^%a") then
			container[port] = class(state, port, context, self)
		end
	end
	return container.__external
end

function Type(type, ...)
	if select("#", ...) > 0
		then return oo.class(type, ...)
		else return oo.class(type, BaseType)
	end
end
--------------------------------------------------------------------------------

function iports(component)
	local container = component.__container
	return base.iports(container and container.__state or component)
end

function managedby(component, home)
	local container = component.__container
	return base.managedby(container and container.__state or component, home)
end

--[[----------------------------------------------------------------------------
MyCompType = comp.Type{
	[<portname>] = <PortClass>,
	[<portname>] = <PortClass>,
	[<portname>] = <PortClass>,
}

MyContainer = Container{
	__external = Handler{ <container> },
	__internal = {
		<componentimpl>,
		[<portname>] = <portimpl>,
		[<portname>] = <portimpl>,
		[<portname>] = <portimpl>,
	},
	[<portname>] = <portmanager>,
	[<portname>] = <portmanager>,
	[<portname>] = <portmanager>,
}

EMPTY       Internal Self      |   EMPTY       Internal Self   
Facet       nil      wrapper   |   Facet       nil      nil
Receptacle  nil      wrapper   |   Receptacle  nil      nil
Multiple    multiple wrapper   |   Multiple    multiple nil
                               |                              
FILLED      Internal Self      |   FILLED      Internal Self   
Facet       port     wrapper   |   Facet       port     nil
Receptacle  wrapper  wrapper   |   Receptacle  port     nil
Multiple    multiple wrapper   |   Multiple    multiple nil
----------------------------------------------------------------------------]]--
