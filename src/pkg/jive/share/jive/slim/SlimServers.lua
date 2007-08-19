
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
local assert, tostring, pairs, type = assert, tostring, pairs, type

local table          = require("table")
local string         = require("string")
local os             = require("os")

local oo             = require("loop.base")

local SocketUdp      = require("jive.net.SocketUdp")
local SlimServer     = require("jive.slim.SlimServer")
local strings        = require("jive.utils.strings")

local log            = require("jive.utils.log").logger("slimserver")


-- jive.slim.SlimServers is a base class
module("jive.slim.SlimServers", oo.class)

-- constants
local PORT    = 3483            -- port used to discover servers
local TIMEOUT = 300             -- timeout (in seconds) before removing servers


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
		log:info("Creating server ", ss_name, " (", ss_id, ":", ss_port, ")")
		
		-- drop the port info, we're not doing anything with it
	 	local server = SlimServer(self.jnt, ss_ip, ss_port, ss_name)
	
		-- add to DB
		self._servers[ss_id] = server
		
		-- notify
		self.jnt:notify('serverNew', server)	

	else
	
		-- update the server with the name info, might have changed
		-- also keeps track of the last time we've seen the server for deletion
		self._servers[ss_id]:updateFromUdp(ss_name)
	end
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
	
	for ss_id, server in pairs(self._servers) do
	
		if not server:isConnected() and
			os.time() - server:getLastSeen() > TIMEOUT then
		
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
	
	assert(jnt, "Cannot create SlimServers without NetworkThread object")
	
	local obj = oo.rawnew(self, {
		jnt = jnt,
		
		-- servers cache
		_servers = {},
		
		-- list of addresses to poll, updated by applet.SlimServers
		poll = {},
	})
	
	-- create a udp socket
	obj.js = SocketUdp(jnt, _getSink(obj))

	-- make us start
	obj:discover()

	return obj
end


--[[

=head2 jive.slim.SlimServers:discover()

Sends the necessary broadcast message to discover slimservers on the network.
Called repeatedly by SlimDiscovery applet while in home.

=cut
--]]
function discover(self)
	log:debug("SlimServers:discover()")

	for _, address in pairs(self.poll) do
		self.js:send(t_source, address, PORT)
	end
	_cacheCleanup(self)	
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
	end

	return self.poll
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

