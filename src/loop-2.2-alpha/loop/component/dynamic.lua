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

local oo   = require "loop.cached"
local base = require "loop.component.contained"

module("loop.component.dynamic", package.seeall)

--------------------------------------------------------------------------------

local WeakTable = oo.class{ __mode = "k" }

--------------------------------------------------------------------------------

local DynamicPort = oo.class()

function DynamicPort:__call(state, name, ...)
	if self.class then
		state[name] = self.class(state[name], state.__component)
	end
	return self.port(state, name, ...)
end

function DynamicPort:__tostring()
	return self.name
end

--------------------------------------------------------------------------------

local InternalState = oo.class()

function InternalState:__index(name)
	self = self.__container
	local state = self.__state
	local port, manager = state[name], self[name]
	if manager == nil then
		local home = state.__home
		local class = home[name]
		if oo.classof(class) == DynamicPort then
			local context = self.__internal
			self[class] = class(state, class, context)
			port, manager = state[class], self[class]
			home:__setcontext(port, context)
		end
	end
	return port, manager
end

function InternalState:__newindex(name, value)
	self = self.__container
	local state = self.__state
	local manager = self[name]
	if manager == nil then
		local home = state.__home
		local class = home[name]
		if oo.classof(class) == DynamicPort then
			local context = self.__internal
			self[class] = class(state, class, context)
			manager = self[class]
			home:__setcontext(state[class], context)
		end
	end
	if manager and manager.__bind then
		manager:__bind(value)
	elseif manager ~= nil then
		state[name] = value
	else
		state.__component[name] = value
	end
end

--------------------------------------------------------------------------------

local ExternalState = oo.class({}, InternalState)

function ExternalState:__index(name)
	local port, manager = oo.superclass(ExternalState).__index(self, name)
	if port and manager
		then return rawget(manager, "__external") or manager
		else return port or self.__container.__state.__component[name]
	end
end

--------------------------------------------------------------------------------

BaseType = oo.class({}, base.BaseType)

function BaseType:__container(comp)
	local container = WeakTable(oo.superclass(BaseType).__container(self, comp))
	container.__state = WeakTable(container.__state)
	container.__internal = InternalState{ __container = container }
	container.__external = ExternalState{ __container = container }
	return container
end

function Type(type, ...)
	if select("#", ...) > 0
		then return oo.class(type, ...)
		else return oo.class(type, BaseType)
	end
end

--------------------------------------------------------------------------------

local function portiterator(container, name)
	local home = container.__state.__home
	local port = home[name]
	if oo.classof(port) == DynamicPort then
		name = port
	end
	repeat
		name = next(container, name)
		if name == nil then
			return nil
		elseif oo.classof(name) == DynamicPort then
			return name.name, name.port
		end
	until name:find("^%a")
	return name, oo.classof(home)[name]
end

function iports(component)
	local container = component.__container
	if container
		then return portiterator, container
		else return base.iport(component)
	end
end

function managedby(component, home)
	local container = component.__container
	if container
		then return (container.__state.__home == home)
		else return base.managedby(component, home)
	end
end

--------------------------------------------------------------------------------

function addport(scope, name, port, class)
	if oo.isclass(scope) or oo.instanceof(scope, BaseType) then
		scope[name] = DynamicPort{
			name = name,
			port = port,
			class = class,
		}
	else
		local container = scope.__container
		if container then
			local context = container.__internal
			local state = container.__state
			local home = state.__home
			if class then
				local comp = state.__component
				state[name] = class(comp[name], comp)
			end
			container[name] = port(state, name, context, home)
			home:__setcontext(state[name], context)
		end
	end
end

function removeport(scope, name)
	if oo.isclass(scope) or oo.instanceof(scope, BaseType) then
		scope[name] = nil
	else
		local container = scope.__container
		if container then
			local state = container.__state
			container[name] = nil
			state[name] = nil
		end
	end
end

--[[----------------------------------------------------------------------------
MyCompType = comp.Type{
	[<portname>] = <PortClass>,
	[<portname>] = <PortClass>,
	[<portname>] = <PortClass>,
}

MyContainer = WeakKeyTable{
	__external = Handler{ <container> },
	__internal = Context{ <container> },
	__state = WeakKeyTable{
		<componentimpl>,
		[<portname>] = <portimpl>,
		[<portname>] = <portimpl>,
		[<dynaport>] = <portimpl>,
	},
	__home = {
		[<portname>] = <portclass>,
		[<portname>] = <portclass>,
		[<portname>] = <dynaport>,
	},
	[<portname>] = <portmanager>,
	[<portname>] = <portmanager>,
	[<dynaport>] = <portmanager>,
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
