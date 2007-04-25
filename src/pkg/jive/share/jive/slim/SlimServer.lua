
--[[
=head1 NAME

jive.slim.SlimServer - SlimServer object

=head1 DESCRIPTION

Represents and interfaces with a real SlimServer on the network.

=head1 SYNOPSIS

 -- Create a SlimServer
 local myServer = SlimServer(jnt, '192.168.1.1', 'Raoul')

 -- Allow some time here for newtork IO to occur

 -- Get the SlimServer version
 local myServerVersion = myServer:getVersion()

=head1 FUNCTIONS

=cut
--]]

-- our stuff
local assert, tostring, type = assert, tostring, type
local pairs, ipairs = pairs, ipairs

local os          = require("os")

local oo          = require("loop.base")

local SocketHttp  = require("jive.net.SocketHttp")
local HttpPool    = require("jive.net.HttpPool")
local Player      = require("jive.slim.Player")

local log         = require("jive.utils.log").logger("slimserver")

require("jive.slim.RequestsCli")
local RequestServerstatus = jive.slim.RequestServerstatus


-- FIXME: squeezenetwork behaviour

-- jive.slim.SlimServer is a base class
module(..., oo.class)

-- our class constants
local HTTPPORT = 9000                -- Slimserver HTTP port
local RETRY_UNREACHABLE = 120        -- Min delay (in s) before retrying a server unreachable


-- init
-- creates a SlimServer object
function __init(self, jnt, ip, name)
	log:debug("SlimServer:__init(", tostring(ip), ", ", tostring(name), ")")

	assert(ip, "Cannot create SlimServer without ip address")

	local obj = oo.rawnew(self, {

		name = name,
		jnt = jnt,

		-- connection stuff
		plumbing = {
			state = 'init',
			lastSeen = os.time(),
			ip = ip,
		},

		-- data from SS
		state = {},

		-- players
		players = {},

		-- our pool
		jpool = HttpPool(jnt, ip, HTTPPORT, 4, 2, name),

		-- our socket for long term connections
		jsp = SocketHttp(jnt, ip, HTTPPORT, name .. "LT"),
		
	})

	obj.id = obj:idFor(ip, port, name)
	
	-- our long term request
	obj:_establishConnection()
	
	-- We're here!
	obj.jnt:notify('serverNew', obj)
	
	return obj
end


-- free
-- delete data and closes connections
function free(self)
	log:debug(tostring(self), ":free()")
	
	-- notify we're going away
	self.jnt:notify("serverDelete", self)

	-- delete players
	for id, player in pairs(self.players) do
		player:free()
	end
	self.players = nil

	-- delete connections
	if self.jpool then
		self.jpool:free()
		self.jpool = nil
	end
	if self.jsp then
		self.jsp:free()
		self.jsp = nil
	end
end


-- idFor
-- returns the id for a server based on ip, port and name
-- NOTE: call as SlimServer.static.idFor(nil, ip, ...) wo an object...
function idFor(self, ip, port, name)
	return tostring(ip) .. ":" .. tostring(port)
end


-- updateFromUdp
-- the server answers the discovery request sent regularly when in home
function updateFromUdp(self, name)
	log:debug(tostring(self), ":updateFromUdp()")

	-- update the name in all cases
	if self.name ~= name then
	
		log:info(tostring(self), ": Renamed to ", tostring(name))
		self.name = name
	end

	-- manage retries
	local now = os.time()
	
	if self.plumbing.state == 'unreachable' and now - self.plumbing.lastSeen > RETRY_UNREACHABLE then
		self:_setPlumbingState('retry')
		self:_establishConnection()
	end

	self.plumbing.lastSeen = now
end


-- _establishConnection
-- sends our long term request
function _establishConnection(self)
	log:debug(tostring(self), ":_establishConnection()")

	-- try to get a long term connection with the server, timeout at 60 seconds.
	-- get 50 players
	-- FIXME: what if the server has more than 50 players?
	
	self.jsp:fetch(
		RequestServerstatus(
			self:_getSink("_serverstatusSink"), 
			0, 
			50, 
			60, 
			{
				["playerprefs"] = 'menuItem'
			}
		)
	)
end


-- _getSink
-- returns a sink
function _getSink(self, name)

	local func = self[name]
	if func and type(func) == "function" then

		return function(chunk, err)
			
			-- be smart and don't call errSink if not necessary
			if not err or self:_errSink(name, err) then
			
				func(self, chunk)
			end
		end

	else
		log:error(tostring(self), ": no function called [", name .."]")
	end
end


-- _errSink
-- manages connection errors
function _errSink(self, name, err)

	if err then
		log:error(tostring(self), ": ", err, " during ", name)
	
		-- give peace a chance and retry immediately, unless that's what we were already doing
		if self.plumbing.state == 'retry' then
			self:_setPlumbingState('unreachable')
		else
			self:_setPlumbingState('retry')
			self:_establishConnection()
		end
	end
	
	-- always return false so data (probably bogus) is not sent for processing
	return false
end


-- _serverstatusSink
-- processes the result of the serverstatus call
function _serverstatusSink(self, data, err)
	log:debug(tostring(self), ":_serverstatusSink()")
--	log:info(data)

	-- check we have a result 
	if not data.result then
		log:error(tostring(self), ": chunk with no result ??!")
		log:error(data)
		return
	end

	-- if we get here we're connected
	self:_setPlumbingState('connected')
	
	-- remember players from server
	local serverPlayers = data.result["@players"]
	data.result["@players"] = nil
	
	-- remember our state
	local selfState = self.state
	
	-- update in one shot
	self.state = data.result
	
	-- manage rescan
	-- use tostring to handle nil case (in either server of self data)
	if tostring(self.state["rescan"]) != tostring(selfState["rescan"]) then
		-- rescan has changed
		if not self.state["rescan"] then
			-- rescanning
			self.jnt:notify('serverRescanning', self)
		else
			self.jnt:notify('serverRescanDone', self)
		end
	end
	
	-- update players
	
	-- copy all players we know about
	local selfPlayers = {}
	for k,v in pairs(self.players) do
		selfPlayers[k] = k
	end
	
	if data.result["player count"] > 0 then

		for i, player_info in ipairs(serverPlayers) do
	
			-- remove the player from our list since it is reported by the server
			selfPlayers[player_info.playerid] = nil
	
			if not self.players[player_info.playerid] then
			
				self.players[player_info.playerid] = Player(self, self.jnt, self.jpool, player_info)
			end
		end
	else
		log:warn(tostring(self), ": has no players!")
	end
	
	-- any players still in the list are gone...
	for k,v in pairs(selfPlayers) do
		self.players[k]:free()
		self.players[k] = nil
	end
	
end


-- _setPlumbingState
-- set the validity status of the server, i.e. can we talk to it
function _setPlumbingState(self, state)

	if state ~= self.plumbing.state then
		
		log:debug(tostring(self), ":_setPlumbingState(", state, ")")

		if self.plumbing.state == 'init' and state == 'connected' then
			self.jnt:notify('serverConnected', self)
		end

		self.plumbing.state = state
	end
end


-- __tostring
-- returns human readable identifier of self
function __tostring(self)
	return "SlimServer {" .. tostring(self:getName()) .. "}"
end


-- Accessors

function getVersion(self)
	return self.version
end
function getIp(self)
	return self.plumbing.ip
end
function getHttpPort(self)
	return HTTPPORT
end
function getName(self)
	return self.name
end
function getLastSeen(self)
	return self.plumbing.lastSeen
end
function isConnected(self)
	return self.plumbing.state == "connected"
end


-- Proxies

function queue(self, request)
	self.jpool:queue(request)
end
function queuePriority(self, request)
	self.jpool:queuePriority(request)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

