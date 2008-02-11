
--[[
=head1 NAME

jive.slim.SlimServers - Slimservers.

=head1 DESCRIPTION

Manages a list of Slimservers discovered using UDP. This class is used
by the SlimDiscovery applet to discover and cache servers found on the network.

=head1 SYNOPSIS

 -- require us
 local SlimServers = require("jive.slim.SlimServers")

 -- create an instance, we need the NetworkThread...
 local servers = SlimServers(jnt)

 -- discover servers (to call regularly)
 servers:discover()

 -- set addresses to poll (bcast address in this case)
 servers:pollList( { ["255.255.255.255"] = "255.255.255.255" } )

=head1 FUNCTIONS

=cut
--]]

-- stuff we use
local _assert, tostring, pairs, type = _assert, tostring, pairs, type

local math           = require("math")
local table          = require("table")
local string         = require("string")
local os             = require("os")

local oo             = require("loop.base")

local SocketUdp      = require("jive.net.SocketUdp")
local SlimServer     = require("jive.slim.SlimServer")
local strings        = require("jive.utils.strings")
local Framework      = require("jive.ui.Framework")
local Timer          = require("jive.ui.Timer")

local log            = require("jive.utils.log").logger("slimserver")


-- jive.slim.SlimServers is a base class
module(..., oo.class)

-- constants
local PORT    = 3483            -- port used to discover servers
local TIMEOUT = 120000          -- timeout (in milliseconds) before removing servers


-- t_source
-- a ltn12 source that crafts a datagram suitable to discover slimservers
-- NOTE: this is called in jnt thread
local function t_source()
	return table.concat {
		"e",                                                           -- new discovery packet
		'IPAD', string.char(0x00),                                     -- request IP address of server
		'NAME', string.char(0x00),                                     -- request Name of server
		'JSON', string.char(0x00),                                     -- request JSONRPC port 
		'JVID', string.char(0x06, 0x12, 0x34, 0x56, 0x78, 0x12, 0x34), -- My ID - FIXME mac of no use!
	}
end


-- _cacheServer
-- adds or updates the server list
local function _cacheServer(self, ss_ip, ss_port, ss_name)
	log:debug("_cacheServer()")

	-- get an id
	local ss_id = SlimServer.idFor(nil, ss_ip, ss_port, ss_name)
			
	-- in the cache?			
	if self._servers[ss_id] == nil then
		log:info("Creating server ", ss_name, " (", ss_id, ")")
		
		-- drop the port info, we're not doing anything with it
	 	local server = SlimServer(self.jnt, ss_ip, ss_port, ss_name)
	
		-- add to DB
		self._servers[ss_id] = server
		
		-- notify
		self.jnt:notify('serverNew', server)	

	end
	
	-- update the server with the name info, might have changed
	-- also keeps track of the last time we've seen the server for deletion
	self._servers[ss_id]:updateFromUdp(ss_name)
end


-- _processUdp
-- processes a udp datagram,
-- FIXME: do we need the port for anything ?
local function _processUdp(self, chunk, err)
	log:debug("_processUdp()")
	
	if chunk.data then

		if chunk.data:sub(1,1) == 'E' then

			local servername, ip, port = _, chunk.ip, _

			local ptr = 2
			while (ptr <= chunk.data:len() - 5) do
				local t = chunk.data:sub(ptr, ptr + 3)
				local l = string.byte(chunk.data:sub(ptr + 4, ptr + 4))
				local v = chunk.data:sub(ptr + 5, ptr + 4 + l)
				ptr = ptr + 5 + l

				if t and l and v then
					if     t == 'NAME' then servername = v
					elseif t == 'IPAD' then ip = v
					elseif t == 'JSON' then port = v
					end
				end
			end

			if servername and ip and port then

				log:debug("Discovered server ", servername, " @ ", ip, ":", port)
			
				_cacheServer(self, ip, port, servername)
			end

		end
	else
		log:error("_processUdp: chunk has no data field ???")
		log:error(chunk)
	end
end


-- _getsink
-- returns our sink, a callback embedding a ref to self...
local function _getSink(self)
	return function(chunk, err)
		if chunk then 
			_processUdp(self, chunk, err)
		end
		return 1
	end
end


-- _cacheCleanup
-- removes old servers
local function _cacheCleanup(self)
	log:debug("_cacheCleanup()")

	local now = Framework:getTicks()
	for ss_id, server in pairs(self._servers) do
		if not server:isConnected() and
			now - server:getLastSeen() > TIMEOUT then
		
			log:info("Removing server ", server:getName(), " (", ss_id, ")")
			self._servers[ss_id] = nil
			self.jnt:notify("serverDelete", server)
			server:free()
		end
	end
end


--[[

=head2 jive.slim.SlimServers(jnt)

Create a SlimServers object.

=cut
--]]
function __init(self, jnt)
	log:debug("SlimServers:__init()")
	
	_assert(jnt, "Cannot create SlimServers without NetworkThread object")
	
	local obj = oo.rawnew(self, {
		jnt = jnt,

		-- current player
		currentPlayer = nil,
		
		-- servers cache
		_servers = {},
		
		-- list of addresses to poll, updated by applet.SlimServers
		poll = {},
	})
	
	-- create a udp socket
	obj.js = SocketUdp(jnt, _getSink(obj))

	obj.discoverState = 'idle' -- 'discover', 'timeout'
	obj.discoverInterval = 1000
	obj.discoverTimer = Timer(obj.discoverInterval,
				  function() obj:_discover() end)

	-- make us start
	-- FIXME we need a slight delay here to allow the settings to be loaded
	-- really the settings should be loaded before the applets start.
	obj.discoverTimer:restart(2000)

	-- subscribe to network events
	jnt:subscribe(obj)

	return obj
end


--[[

=head2 jive.slim.SlimServers:discover()

Sends the necessary broadcast message to discover slimservers on the network.
Called repeatedly when looking for players.

=cut
--]]
function discover(self)
	-- force a discovery if the timer is not running, otherwise it
	-- will automatically run soon
	if self.discoverState ~= 'discover' then
		if self.discoverState == 'timeout' then
			self.discoverState = 'discover'
		end
		self:_discover()
	end
end


function _discover(self)
	log:debug("SlimServers:discover()")

	-- Broadcast discovery
	for _, address in pairs(self.poll) do
		log:debug("sending to address ", address)
		self.js:send(t_source, address, PORT)
	end

	-- Special case Squeezenetwork
	if self.jnt:getUUID() then
		_cacheServer(self, self.jnt:getSNHostname(), 9000, "SqueezeNetwork")
	end

	-- Remove SqueezeCenters that have not been seen for a while
	_cacheCleanup(self)

	if self.discoverState == 'idle' then
		-- reconnect to all servers
		log:info("Reconnecting to all servers")
		self:connect()
	end

	if self.currentPlayer then
		if self.discoverState ~= 'timeout' then
			self.discoverState = 'timeout'
			self.discoverTimer:restart(10000)

		else
			self.discoverState = 'idle'
			self.discoverTimer:stop()

			-- disconnect from idle servers
			log:info("Disconnecting from idle servers")
			self:idleDisconnect()
		end
	else
		if self.discoverState ~= 'discover' then
			log:info("Starting discovery")

			self.discoverState = 'discover'
			self.discoverInterval = 1000
			self.discoverTimer:restart(self.discoverInterval)

		else
			self.discoverInterval = math.min(self.discoverInterval + 1000, 30000)
			self.discoverTimer:restart(self.discoverInterval)
		end
	end
end


--[[

=head2 connect()

Allow connection to all Slimservers.

=cut
--]]
function connect(self)
	for ss_id, server in pairs(self._servers) do
		server:connect()
	end
end


--[[

=head2 disconnect()

Force disconnection from all Slimservers.

=cut
--]]
function disconnect(self)
	for ss_id, server in pairs(self._servers) do
		server:disconnect()
	end
end


--[[
=head2 idleDisconnect()

Force disconnection from all idle SlimServers, that is all SlimServers
apart from the one controlling the currently selected player.

=cut
--]]
function idleDisconnect(self)
	for ss_id, server in pairs(self._servers) do
		if self.currentPlayer and self.currentPlayer:getSlimServer() ~= server then
			server:disconnect()
		end
	end
end


--[[

=head2 SlimServers:setCurrentPlayer()

Sets the current player

=cut
--]]
function setCurrentPlayer(self, player)
	if self.currentPlayer == player then
		return -- no change
	end

	log:info("selected player: ", player)
	self.currentPlayer = player
	self.jnt:notify("playerCurrent", player)

	-- restart discovery when we have no player
	if not self.currentPlayer then
		self:discover()
	end
end


--[[

=head2 SlimServers:getCurrentPlayer()

Returns the current player

=cut
--]]
function getCurrentPlayer(self)
	return self.currentPlayer
end


--[[

=head2 jive.slim.SlimServers:allServers()

Returns an iterator over the discovered slimservers.

=cut
--]]
function allServers(self)
	return pairs(self._servers)
end


--[[

=head2 SlimServers:allPlayers()

Returns an iterator over the discovered players.

 for id, player in allPlayers() do
    ...
 end

=cut
--]]
-- this iterator respects the implementation privacy of the SlimServers and SlimServer
-- classes. It only uses the fact allServers and allPlayers calls respect the for
-- generator logic of Lua.
local function _playerIterator(invariant)
	while true do
	
		-- if no current player, load next server
		-- NB: true first time
		if not invariant.pk then
			invariant.sk, invariant.sv = invariant.sf(invariant.si, invariant.sk)
			invariant.pk = nil
			if invariant.sv then
				invariant.pf, invariant.pi, invariant.pk = invariant.sv:allPlayers()
			end
		end
	
		-- if we have a server, use it to get players
		if invariant.sv then
			-- get the next/first player, depending on pk
			local pv
			invariant.pk, pv = invariant.pf(invariant.pi, invariant.pk)
			if invariant.pk then
				return invariant.pk, pv
			end
		else
			-- no further servers, we're done
			return nil
		end
	end
end

function allPlayers(self)
	local i = {}
	i.sf, i.si, i.sk = self:allServers()
	return _playerIterator, i
end


--[[

=head2 jive.slim.SlimServers:pollList()

Get/set the list of addresses which are polled with discovery packets.
List is a table with IP address strings as both key and value.
The broadcast address is represented as : { ["255.255.255.255"] = "255.255.255.255" }

=cut
--]]
function pollList(self, list)
	log:debug("SlimServers:pollList()")

	if type(list) == "table" then
		log:info("updated poll list")
		self.poll = list

		-- get going with the new poll list
		self:discover()
	end

	return self.poll
end


-- restart discovery on new network
function notify_networkConnected(self)
	log:info("network connected")

	-- force reconnection to all servers if we don't have a player
	if not self.currentPlayer then
		self:discover()
		self:connect()
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

