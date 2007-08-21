
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

Notifications:

 serverNew (performed by SlimServers)
 serverDelete (performed by SlimServers)

=head1 FUNCTIONS

=cut
--]]

-- our stuff
local assert, tostring, type = assert, tostring, type
local pairs, ipairs, setmetatable = pairs, ipairs, setmetatable

local os          = require("os")
local table       = require("table")

local oo          = require("loop.base")

local Comet       = require("jive.net.Comet")
local HttpPool    = require("jive.net.HttpPool")
local Player      = require("jive.slim.Player")
local Surface     = require("jive.ui.Surface")
local RequestHttp = require("jive.net.RequestHttp")

local log         = require("jive.utils.log").logger("slimserver")
local logcache    = require("jive.utils.log").logger("slimserver.cache")

-- FIXME: squeezenetwork behaviour

-- jive.slim.SlimServer is a base class
module(..., oo.class)

-- our class constants
local RETRY_UNREACHABLE = 120        -- Min delay (in s) before retrying a server unreachable


-- _setPlumbingState
-- set the validity status of the server, i.e. can we talk to it
local function _setPlumbingState(self, state)

	if state ~= self.plumbing.state then
		
		log:debug(self, ":_setPlumbingState(", state, ")")

		if self.plumbing.state == 'init' and state == 'connected' then
			self.jnt:notify('serverConnected', self)
		end
		
		log:warn(self, ' is ', state)

		self.plumbing.state = state
	end
end


-- forward declaration
local _establishConnection


-- _errSink
-- manages connection errors
local function _errSink(self, name, err)

	if err then
		log:error(self, ": ", err, " during ", name)
	
		-- give peace a chance and retry immediately, unless that's what we were already doing
		if self.plumbing.state == 'retry' then
			_setPlumbingState(self, 'unreachable')
		else
			_setPlumbingState(self, 'retry')
			_establishConnection(self)
		end
	end
	
	-- always return false so data (probably bogus) is not sent for processing
	return false
end


-- _getSink
-- returns a sink
local function _getSink(self, name)

	local func = self[name]
	if func and type(func) == "function" then

		return function(chunk, err)
			
			-- be smart and don't call errSink if not necessary
			if not err or _errSink(self, name, err) then
			
				func(self, chunk)
			end
		end

	else
		log:error(self, ": no function called [", name .."]")
	end
end


-- _establishConnection
-- sends our long term request
_establishConnection = function(self)
	log:debug(self, ":_establishConnection()")

	-- try to get a long term connection with the server, timeout at 60 seconds.
	-- get 50 players
	-- FIXME: what if the server has more than 50 players?
	
	self.comet:subscribe(
		'/slim/serverstatus',
		_getSink(self, '_serverstatusSink'),
		nil,
		{ 'serverstatus', 0, 50, 'subscribe:60' }
	)
	
	-- Start the Comet connection process
	self.comet:start()
end


-- _serverstatusSink
-- processes the result of the serverstatus call
function _serverstatusSink(self, event, err)
	log:debug(self, ":_serverstatusSink()")
--	log:info(event)

	local data = event.data

	-- check we have a result 
	if not data then
		log:error(self, ": chunk with no data ??!")
		log:error(event)
		return
	end

	-- if we get here we're connected
	_setPlumbingState(self, 'connected')
	
	-- remember players from server
	local serverPlayers = data.players_loop
	data.players_loop = nil
	
	-- remember our state
	local selfState = self.state
	
	-- update in one shot
	self.state = data
	
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
	local player
	
	for k,v in pairs(self.players) do
		selfPlayers[k] = k
	end
	
	if data["player count"] > 0 then

		for i, player_info in ipairs(serverPlayers) do
	
			-- remove the player from our list since it is reported by the server
			selfPlayers[player_info.playerid] = nil
	
			-- create new players
			if not self.players[player_info.playerid] then
			
				player = Player(self, self.jnt, self.jpool, player_info)
			
				self.players[player_info.playerid] = player
				
				-- notify of new player
				self.jnt:notify('playerNew', player)

			else
				-- update existing players
				self.players[player_info.playerid]:updateFromSS(player_info)
			end
		end
	else
		log:warn(self, ": has no players!")
	end
	
	-- any players still in the list are gone...
	for k,v in pairs(selfPlayers) do
		player = self.players[k]
		self.players[k] = nil
		-- wave player bye bye
		self.jnt:notify('playerDelete', player)
		player:free()
	end
	
end


--[[

=head2 jive.slim.SlimServer(jnt, ip, name)

Create a SlimServer object at IP address I<ip> with name I<name>. Once created, the
object will immediately connect to slimserver to discover players and other attributes
of the server.

=cut
--]]
function __init(self, jnt, ip, port, name)
	log:debug("SlimServer:__init(", ip, ":", port, " ",name, ")")

	assert(ip, "Cannot create SlimServer without ip address")
	
	local jpool = HttpPool(jnt, ip, port, 4, 2, name)

	local obj = oo.rawnew(self, {

		name = name,
		jnt = jnt,

		-- connection stuff
		plumbing = {
			state = 'init',
			lastSeen = os.time(),
			ip = ip,
			port = port,
		},

		-- data from SS
		state = {},

		-- players
		players = {},

		-- our pool
		jpool = jpool,

		-- our socket for long term connections, this will not
		-- actually connect yet
		comet = Comet(jnt, jpool, ip, port, '/cometd', name),
		
		-- artwork cache: Weak table storing a surface by iconId
		artworkThumbCache = setmetatable({}, { __mode="k" }),
		-- Icons waiting for the given iconId
		artworkThumbIcons = {},
		
	})

	obj.id = obj:idFor(ip, port, name)
	
	-- our long term request
	_establishConnection(obj)
	
	-- notify we're here by caller in SlimServers
	
	return obj
end


--[[

=head2 jive.slim.SlimServer:free()

Deletes a SlimServer object, frees memory and closes connections with the server.

=cut
--]]
function free(self)
	log:debug(self, ":free()")
	
	-- notify we're gone by caller in SlimServers
		
	-- clear cache
	self.artworkThumbCache = nil
	self.artworkThumbIcons = nil

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
	if self.comet then
		self.comet:free()
		self.comet = nil
	end
end


--[[

=head2 jive.slim.SlimServer:idFor(ip, port, name)

Returns an identifier for a server named I<name> at IP address I<ip>:I<port>.

=cut
--]]
function idFor(self, ip, port, name)
	return tostring(ip) .. ":" .. tostring(port)
end


--[[

=head2 jive.slim.SlimServer:updateFromUdp(name)

The L<jive.slim.SlimServers> cache calls this method every time the server
answers the discovery request. This method updates the server name if it has changed
and manages retries of the server long term connection.

=cut
--]]
function updateFromUdp(self, name)
	log:debug(self, ":updateFromUdp()")

	-- update the name in all cases
	if self.name ~= name then
	
		log:info(self, ": Renamed to ", name)
		self.name = name
	end

	-- manage retries
	local now = os.time()
	
	if self.plumbing.state == 'unreachable' and now - self.plumbing.lastSeen > RETRY_UNREACHABLE then
		_setPlumbingState(self, 'retry')
		_establishConnection(self)
	end

	self.plumbing.lastSeen = now
end


-- _dunpArtworkCache
-- returns statistical data about our cache
local function _dumpArtworkThumbCache(self)
	local items = 0
	for k, v in pairs(self.artworkThumbCache) do
		items = items + 1
	end
	logcache:debug("artworkThumbCache contains ", items, " items")
end


-- _getArworkThumbSink
-- returns a sink for artwork so we can cache it as Surface before sending it forward
local function _getArtworkThumbSink(self, iconId)

	local icons = self.artworkThumbIcons

	return function(chunk, err)
		-- on error, print something...
		if err then
			logcache:error("_getArtworkThumbSink(", iconId, "):", err)
		end
		-- if we have data
		if chunk then
			logcache:debug("_getArtworkThumbSink(", iconId, ")")
			
			-- create a surface
			local artwork = Surface:loadImageData(chunk, #chunk)
			
			-- set it to all icons waiting for it
			for i, icon in ipairs(icons[iconId]) do
				icon:setImage(artwork)
			end
			
			-- store the artwork in the cache
			self.artworkThumbCache[iconId] = artwork
			
			if logcache:isDebug() then
				_dumpArtworkThumbCache(self)
			end
		end
		-- in all cases, remove the sinks
		icons[iconId] = nil
	end
end


--[[

=head2 jive.slim.SlimServer:fetchArtworkThumb(iconId, icon, uriGenerator, size)

The SlimServer object maintains an artwork cache. This function either loads from the cache or
gets from the network the thumb for I<iconId>. A L<jive.ui.Surface> is used to perform
I<icon>:setImage(). I<uriGenerator> must be a function that
computes the URI to request the artwork from the server from I<iconId> (i.e. if needed, this
method will call uriGenerator(iconId) and use the result as URI).


=cut
--]]
function fetchArtworkThumb(self, iconId, icon, uriGenerator, size, priority)
	logcache:debug(self, ":fetchArtworkThumb(", iconId, ")")

	if logcache:isDebug() then
		_dumpArtworkThumbCache(self)
	end

	-- cache non default sizes with their own key
	if size then
		iconId = iconId .. size
	end

	-- do we have the artwork in the cache
	local artwork = self.artworkThumbCache[iconId]
	if artwork then
		logcache:debug("..artwork in cache")
		icon:setImage(artwork)
		return
	end
	
	-- are we requesting it already?
	local icons = self.artworkThumbIcons[iconId]
	if icons then
		logcache:debug("..artwork already requested")
		table.insert(icons, icon)
		return
	end
	
	-- no luck, generate a request for the artwork
	local req = RequestHttp(
		_getArtworkThumbSink(self, iconId), 
		'GET', 
		uriGenerator(iconId)
	)
	-- remember the icon
	self.artworkThumbIcons[iconId] = {icon}
	logcache:debug("..fetching artwork")

	if priority then
		self.jpool:queuePriority(req)
	else
		self.jpool:queue(req)
	end
end


--[[

=head2 tostring(aSlimServer)

if I<aSlimServer> is a L<jive.slim.SlimServer>, prints
 SlimServer {name}

=cut
--]]
function __tostring(self)
	return "SlimServer {" .. tostring(self.name) .. "}"
end


-- Accessors

--[[

=head2 jive.slim.SlimServer:getVersion()

Returns the server version

=cut
--]]
function getVersion(self)
	if self.state then 
		return self.state.version
	end
end


--[[

=head2 jive.slim.SlimServer:getIpPort()

Returns the server IP address and HTTP port

=cut
--]]
function getIpPort(self)
	return self.plumbing.ip, self.plumbing.port
end


--[[

=head2 jive.slim.SlimServer:getName()

Returns the server name

=cut
--]]
function getName(self)
	return self.name
end


--[[

=head2 jive.slim.SlimServer:getLastSeen()

Returns the time at which the last indication the server is alive happened,
either data from the server or response to discovery. This is used by
L<jive.slim.SlimServers> to delete old servers.

=cut
--]]
function getLastSeen(self)
	return self.plumbing.lastSeen
end


--[[

=head2 jive.slim.SlimServer:isConnected()

Returns the state of the long term connection with the server. This is used by
L<jive.slim.SlimServers> to delete old servers.

=cut
--]]
function isConnected(self)
	return self.plumbing.state == "connected"
end


--[[

=head2 jive.slim.SlimServer:allPlayers()

Returns all players iterator

 for id, player in allPlayers() do
     xxx
 end

=cut
--]]
function allPlayers(self)
	return pairs(self.players)
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

