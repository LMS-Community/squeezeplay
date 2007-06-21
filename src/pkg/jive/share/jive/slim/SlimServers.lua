
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

=head1 FUNCTIONS

=cut
--]]

-- stuff we use
local assert, tostring, pairs = assert, tostring, pairs

local table          = require("table")
local string         = require("string")
local os             = require("os")

local oo             = require("loop.base")

local SocketUdpBcast = require("jive.net.SocketUdpBcast")
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
		"d",                                                 -- discovery
		string.char(0),                                      -- reserved
		string.char(4),                                      -- hardware id
		string.char(67),                                     -- software id
		string.char(0, 0, 0, 0, 0, 0, 0, 0),                 -- reserved
		string.char(0x12, 0x34, 0x56, 0x78, 0x12, 0x34)      -- mac address
	}
end


-- _cacheServer
-- adds or updates the server list
local function _cacheServer(self, ss_ip, ss_port, ss_name)
	log:debug("_cacheServer()")

	-- get an id
	local ss_id = SlimServer.idFor(nil, ss_ip, ss_port, ss_name)
			
	-- in the cache?			
	if self.servers[ss_id] == nil then
		log:info("Creating server ", ss_name, " (", ss_id, ")")
		
		-- drop the port info, we're not doing anything with it
		self.servers[ss_id] = SlimServer(self.jnt, ss_ip, ss_name)

	else
	
		-- update the server with the name info, might have changed
		-- also keeps track of the last time we've seen the server for deletion
		self.servers[ss_id]:updateFromUdp(ss_name)
	end
end


-- _processUdp
-- processes a udp datagram,
-- FIXME: do we need the port for anything ?
local function _processUdp(self, chunk, err)
	log:debug("_processUdp()")
	
	if chunk.data then
		if chunk.data:sub(1,1) == 'D' then
	
			local servername = strings.trim(chunk.data:sub(2))
		
			log:debug("Discovered server ", servername, " @", chunk.ip, ":", chunk.port)
		
			_cacheServer(self, chunk.ip, chunk.port, servername)
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
	
	for ss_id, server in pairs(self.servers) do
	
		if not server:isConnected() and
			os.time() - server:getLastSeen() > TIMEOUT then
		
			log:info("Removing server ", server:getName(), " (", ss_id, ")")
			self.servers[ss_id] = nil
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
		servers = {},
	})
	
	-- create a udp socket
	obj.js = SocketUdpBcast(jnt, _getSink(obj))
			
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

	self.js:send(t_source, PORT)
	_cacheCleanup(self)	
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

