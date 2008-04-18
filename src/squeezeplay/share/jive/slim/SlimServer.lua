
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
 serverConnected(self)
 serverDisconnected(self, numPendingRequests)

=head1 FUNCTIONS

=cut
--]]

-- our stuff
local _assert, assert, tostring, type, tonumber = _assert, assert, tostring, type, tonumber
local pairs, ipairs, setmetatable = pairs, ipairs, setmetatable

local os          = require("os")
local table       = require("jive.utils.table")
local string      = require("string")
local debug       = require("jive.utils.debug")

local oo          = require("loop.base")

local Comet       = require("jive.net.Comet")
local HttpPool    = require("jive.net.HttpPool")
local Player      = require("jive.slim.Player")
local Surface     = require("jive.ui.Surface")
local RequestHttp = require("jive.net.RequestHttp")
local SocketHttp  = require("jive.net.SocketHttp")
local WakeOnLan   = require("jive.net.WakeOnLan")

local Task        = require("jive.ui.Task")
local Framework   = require("jive.ui.Framework")

local ArtworkCache = require("jive.slim.ArtworkCache")

local log         = require("jive.utils.log").logger("slimserver")
local logcache    = require("jive.utils.log").logger("slimserver.cache")

-- FIXME: squeezenetwork behaviour

-- jive.slim.SlimServer is a base class
module(..., oo.class)

-- our class constants
local RETRY_UNREACHABLE = 120        -- Min delay (in s) before retrying a server unreachable


-- list of servers index by id.
local servers = {}
setmetatable(servers, { __mode = 'v' })

-- credential list
local credentials = {}


-- _getSink
-- returns a sink
local function _getSink(self, name)

	local func = self[name]
	if func and type(func) == "function" then

		return function(chunk, err)
			
			if err then
				log:error(self, ": ", err, " during ", name)
			else
				func(self, chunk)
			end
		end

	else
		log:error(self, ": no function called [", name .."]")
	end
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

	-- remember players from server
	local serverPlayers = data.players_loop
	data.players_loop = nil
	
	-- remember our state
	local selfState = self.state
	
	-- update in one shot
	self.state = data
	self.plumbing.lastSeen = Framework:getTicks()
	
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

	self.pin = nil
	
	if tonumber(data["player count"]) > 0 then

		for i, player_info in ipairs(serverPlayers) do

			if player_info.pin then
				self.pin = player_info.pin
			end

			-- remove the player from our list since it is reported by the server
			selfPlayers[player_info.playerid] = nil
	
			-- create new players
			if not self.players[player_info.playerid] then
			
				player = Player(self.jnt, self, player_info)
			
			else
				-- update existing players
				self.players[player_info.playerid]:update(self, player_info)
			end
		end
	else
		log:info(self, ": has no players!")
	end
	
	-- any players still in the list are gone...
	for k,v in pairs(selfPlayers) do
		player = self.players[k]
		-- wave player bye bye
		player:free(self)
		self.players[k] = nil
	end
	
end

-- package private method to delete a player
function _deletePlayer(self, player)
	self.players[player:getId()] = nil
	self.jnt:notify('playerDelete', player)
end


function _addPlayer(self, player)
	self.players[player:getId()] = player
	self.jnt:notify('playerNew', player)
end


-- can be called as a object or class method
function setCredentials(self, cred, name)
	if not name then
		-- object method
		name = self:getName()

		SocketHttp:setCredentials({
			ipport = { self:getIpPort() },
			realm = cred.realm,
			username = cred.username,
			password = cred.password,
		})

		-- force re-connection
		self:connect()
	end

	credentials[name] = cred
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

	_assert(ip, "Cannot create SlimServer without ip address")

	-- Only create one server object per server. This avoids duplicates
	-- following a server disconnect.

	local id = self:idFor(ip, port, name)
	local obj = servers[id]
	if obj then
		obj:connect(obj)
		return obj
	end


	local obj = oo.rawnew(self, {

		id = id,
		name = name,
		jnt = jnt,

		-- connection stuff
		plumbing = {
			lastSeen = Framework:getTicks(),
			ip = ip,
			port = port,
		},

		-- data from SS
		state = {},

		-- players
		players = {},

		-- artwork http pool
		artworkPool = HttpPool(jnt, name, ip, port, 2, 1, Task.PRIORITY_LOW),

		-- artwork cache: Weak table storing a surface by iconId
		artworkCache = ArtworkCache(),
		-- Icons waiting for the given iconId
		artworkThumbIcons = {},

		-- our socket for long term connections, this will not
		-- actually connect yet
		comet = Comet(jnt, ip, port, '/cometd', name),

		-- are we connected to the server?
		active = false,
		connecting = false,

		-- queue of artwork to fetch
		artworkFetchQueue = {},
		artworkFetchCount = 0,

		-- loaded images
		imageCache = {},
	})

	setmetatable(obj.imageCache, { __mode = "kv" })

	obj.id = obj:idFor(ip, port, name)
	servers[obj.id] = obj

	-- http authentication
	local cred = credentials[name]
	if cred then
		SocketHttp:setCredentials({
			ipport = { obj:getIpPort() },
			realm = cred.realm,
			username = cred.username,
			password = cred.password,
		})
	end

	-- subscribe to comet events
	jnt:subscribe(obj)

	-- subscribe to server status, timeout at 60 seconds.
	-- get 50 players
	-- FIXME: what if the server has more than 50 players?
	obj.comet:aggressiveReconnect(true)
	obj.comet:subscribe('/slim/serverstatus',
			    _getSink(obj, '_serverstatusSink'),
			    nil,
			    { 'serverstatus', 0, 50, 'subscribe:60' }
		    )

	-- long term connection to the server
	obj:connect(obj)
	
	-- notify we're here by caller in SlimServers
	
	-- task to fetch artwork while browsing
	obj.artworkFetchTask = Task("artwork", obj, processArtworkQueue)

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
	self.artworkCache:free()
	self.artworkThumbIcons = {}

	-- delete players
	for id, player in pairs(self.players) do
		player:free(self)
	end
	self.players = {}

	-- delete connections
	self.artworkPool:close()
	self.comet:disconnect()
end


function isSqueezeNetwork(self)
	return self.name == "SqueezeNetwork"
end


--[[

=head2 jive.slim.SlimServer:getPin()

Returns the PIN for SqueezeNetwork, if it needs to be registered

=cut
--]]
function getPin(self)
	return self.pin
end


--[[

=head2 jive.slim.SlimServer:linked(pin)

Called once the server or player are linked on SqueezeNetwork.

=cut
--]]
function linked(self, pin)
	if self.pin == pin then
		self.pin = nil
	end

	for id, player in pairs(self.players) do
		if player.pin == pin then
			player.pin = nil
		end
	end
end


function connect(self)
	log:info(self, ":connect()")

	self.connecting = true

	if self.plumbing.mac and not self:isSqueezeNetwork() then
		-- send WOL packet to SqueezeCenter
		local wol = WakeOnLan(self.jnt)
		wol:wakeOnLan(self.plumbing.mac)
	end

	-- artwork pool connects on demand
	self.comet:connect()
end


function disconnect(self)
	log:info(self, ":disconnect()")

	self.connecting = false

	self.artworkPool:close()
	self.comet:disconnect()
end

function reconnect(self)
	log:info(self, ":reconnect()")

	self:disconnect()
	self:connect()
end

-- comet has connected to SC
function notify_cometConnected(self, comet)
	if self.comet ~= comet then
		return
	end

	log:info(self, " connected")
	self.active = true
	self.jnt:notify('serverConnected', self)

	-- auto discovery SqueezeCenter's mac address
	self.jnt:arp(self.plumbing.ip,
		     function(chunk, err)
			     if err then
				     log:warn("arp: " .. err)
			     else
				     self.plumbing.mac = chunk
			     end
		     end)
end

-- comet is disconnected from SC
function notify_cometDisconnected(self, comet, numPendingRequests)
	if self.comet ~= comet then
		return
	end

	log:info(self, " disconnected")
	self.active = false
	self.jnt:notify('serverDisconnected', self, numPendingRequests)
end


-- comet http error
function notify_cometHttpError(self, comet, cometRequest)
	if cometRequest:t_getResponseStatus() == 401 then
		local authenticate = cometRequest:t_getResponseHeader("WWW-Authenticate")

		self.realm = string.match(authenticate, 'Basic realm="(.*)"')
	end
end


--[[

=head2 jive.slim.SlimServer:idFor(ip, port, name)

Returns an identifier for a server named I<name> at IP address I<ip>:I<port>.

=cut
--]]
function idFor(self, ip, port, name)
	-- XXXX remove this function and just use SC name
	return name
end


--[[

=head2 jive.slim.SlimServer:updateFromUdp(name)

The L<jive.slim.SlimServers> cache calls this method every time the server
answers the discovery request. This method updates the server name if it has changed
and manages retries of the server long term connection.

=cut
--]]
function updateFromUdp(self, ip, port, name)
	log:debug(self, ":updateFromUdp()")

	-- update the name in all cases
	if self.name ~= name then
		log:info(self, ": Renamed to ", name)
		self.name = name
	end

	if self.plumbing.ip ~= ip or self.plumbing.port ~= port then
		log:info(self, ": IP Address changed to ", ip , ":", port, " connecting=", self.connecting)

		local connecting = self.connecting

		-- close old comet connection
		self:disconnect()

		-- open new comet connection
		self.plumbing.ip = ip
		self.plumbing.port = port
		self.artworkPool = HttpPool(self.jnt, name, ip, port, 2, 1, Task.PRIORITY_LOW)
		self.comet = Comet(self.jnt, ip, port, '/cometd', name)

		-- reconnect, if we were already connected
		if connecting then
			self:connect()
		end
	end

	self.plumbing.lastSeen = Framework:getTicks()
end


-- convert artwork to a resized image
local function _loadArtworkImage(self, cacheKey, chunk, size)
	-- create a surface
	local image = Surface:loadImageData(chunk, #chunk)

	local w, h = image:getSize()

	-- don't display empty artwork
	if w == 0 or h == 0 then
		self.imageCache[cacheKey] = true
		return nil
	end

	-- Resize image
	-- Note this allows for artwork to be resized to a larger
	-- size than the original.  This is intentional so smaller cover
	-- art will still fill the space properly on the Now Playing screen
	if w ~= size and h ~= size then
		image = image:rotozoom(0, size / w, 1)
		if logcache:isDebug() then
			local wnew, hnew = image:getSize()
			logcache:debug("Resized artwork from ", w, "x", h, " to ", wnew, "x", hnew)
		end
	end

	-- cache image
	self.imageCache[cacheKey] = image

	return image
end


-- _getArworkThumbSink
-- returns a sink for artwork so we can cache it as Surface before sending it forward
local function _getArtworkThumbSink(self, cacheKey, size)

	assert(size)
	
	return function(chunk, err)

		if err or chunk then
			-- allow more artwork to be fetched
			self.artworkFetchCount = self.artworkFetchCount - 1
			self.artworkFetchTask:addTask()
		end

		-- on error, print something...
		if err then
			logcache:error("_getArtworkThumbSink(", iconId, ", ", size, ") error: ", err)
		end
		-- if we have data
		if chunk then
			logcache:debug("_getArtworkThumbSink(", iconId, ", ", size, ")")

			-- store the compressed artwork in the cache
			self.artworkCache:set(cacheKey, chunk)

			local image = _loadArtworkImage(self, cacheKey, chunk, size)

			-- set it to all icons waiting for it
			local icons = self.artworkThumbIcons
			for icon, key in pairs(icons) do
				if key == cacheKey then
					icon:setValue(image)
					icons[icon] = nil
				end
			end
		end
	end
end


function processArtworkQueue(self)
	while true do
		while self.artworkFetchCount < 4 and #self.artworkFetchQueue > 0 do
			-- remove tail entry
			local entry = table.remove(self.artworkFetchQueue)

			--log:debug("ARTWORK ID=", entry.key)
			local req = RequestHttp(
				_getArtworkThumbSink(self, entry.key, entry.size),
				'GET',
				entry.url
			)

			self.artworkFetchCount = self.artworkFetchCount + 1


			if entry.id then
				-- slimserver icon id
				self.artworkPool:queue(req)
			else
				-- image from remote server

				-- XXXX manage pool of connections to remote server
				local uri  = req:getURI()
				local http = SocketHttp(self.jnt, uri.host, uri.port, uri.host)
						    
				http:fetch(req)
			end

			-- try again
			Task:yield(true)
		end

		Task:yield(false)
	end
end



--[[

=head2 jive.slim.SlimServer:artworkThumbCached(iconId, size)

Returns true if artwork for iconId and size are in the cache.  This may be used to decide
whether to display the thumb straight away or wait before fetching it.

=cut

--]]

function artworkThumbCached(self, iconId, size)
	local cacheKey = iconId .. "@" .. (size)
	if self.artworkCache:get(cacheKey) then
		return true
	else
		return false
	end
end


--[[

=head2 jive.slim.SlimServer:cancelArtworkThumb(icon)

Cancel loading the artwork for icon.

=cut
--]]
function cancelArtwork(self, icon)
	-- prevent artwork being display when it has been loaded
	if icon then
		icon:setValue(nil)
		self.artworkThumbIcons[icon] = nil
	end
end


--[[

=head2 jive.slim.SlimServer:cancelArtworkThumb(icon)

Cancel loading the artwork for icon.

=cut
--]]
function cancelAllArtwork(self, icon)

	for i, entry in ipairs(self.artworkFetchQueue) do
		local cacheKey = entry.key

		-- release cache marker
		self.artworkCache:set(cacheKey, nil)

		-- release icons
		local icons = self.artworkThumbIcons
		for icon, key in pairs(icons) do
			if key == cacheKey then
				icons[icon] = nil
			end
		end
	end

	-- clear the queue
	self.artworkFetchQueue = {}
end


--[[

=head2 jive.slim.SlimServer:fetchArtworkThumb(iconId, icon, size, imgFormat)

The SlimServer object maintains an artwork cache. This function either loads from the cache or
gets from the network the thumb for I<iconId>. A L<jive.ui.Surface> is used to perform
I<icon>:setValue(). This function computes the URI to request the artwork from the server from I<iconId>. I<imgFormat> is an optional
argument to control the image format.

=cut
--]]
function fetchArtworkThumb(self, iconId, icon, size, imgFormat)
	logcache:debug(self, ":fetchArtworkThumb(", iconId, ")")

	assert(size)

	-- we want jpg if it wasn't specified
	if not imgFormat then
		imgFormat = 'jpg'
	end

	local cacheKey = iconId .. "@" .. size

	-- request SqueezeCenter resizes the thumbnail, use 'o' for
	-- original aspect ratio
	local resizeFrag = '_' .. size .. 'x' .. size .. '_o'

	local url
	if string.match(iconId, "^%d+$") then
		-- if the iconId is a number, this is cover art
		url = '/music/' .. iconId .. '/cover' .. resizeFrag .. "." .. imgFormat
	else
		url = string.gsub(iconId, "(%a+)(%.%a+)", "%1" .. resizeFrag .. "%2")

		if not string.find(url, "^/") then
			-- Bug 7123, Add a leading slash if needed
			url = "/" .. url
		end
	end

	return _fetchArtworkURL(self, icon, iconId, size, cacheKey, url)
end

--[[

=head2 jive.slim.SlimServer:fetchArtworkURL(url, icon, size)

Same as fetchArtworkThumb except it fetches the artwork from a remote URL.
This method is in the SlimServer class so it can reuse the other artwork code.

=cut
--]]
function fetchArtworkURL(self, url, icon, size)
	logcache:debug(self, ":fetchArtworkURL(", url, ")")

	assert(size)
	local cacheKey = url .. "@" .. size

	return _fetchArtworkURL(self, icon, nil, size, cacheKey, url)
end


-- common parts of fetchArtworkThumb and fetchArtworkURL
function _fetchArtworkURL(self, icon, iconId, size, cacheKey, url)

	-- do we have an image cached
	local image = self.imageCache[cacheKey]
	if image then
		logcache:debug("..image in cache")

		-- are we requesting it already?
		if image == true then
			if icon then
				icon:setValue(nil)
				self.artworkThumbIcons[icon] = cacheKey
			end
			return
		else
			if icon then
				icon:setValue(image)
				self.artworkThumbIcons[icon] = nil
			end
			return
		end
	end

	-- or do is the compressed artwork cached
	local artwork = self.artworkCache:get(cacheKey)
	if artwork then
		if artwork == true then
			logcache:debug("..artwork already requested")
			if icon then
				icon:setValue(nil)
				self.artworkThumbIcons[icon] = cacheKey
			end
			return
		else
			logcache:debug("..artwork in cache")
			if icon then
				image = _loadArtworkImage(self, cacheKey, artwork, size)
				icon:setValue(image)
				self.artworkThumbIcons[icon] = nil
			end
			return
		end
	end

	-- no luck, generate a request for the artwork
	self.artworkCache:set(cacheKey, true)
	if icon then
		icon:setValue(nil)
		self.artworkThumbIcons[icon] = cacheKey
	end
	logcache:debug("..fetching artwork")

	-- queue up the request on a lifo
	table.insert(self.artworkFetchQueue, {
			     key = cacheKey,
			     id = iconId,
			     url = url,
			     size = size,
		     })
	self.artworkFetchTask:addTask()
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
	return self.active
end


-- returns true if a password is needed
function isPasswordProtected(self)
	if self.realm and not self.active then
		return true, self.realm
	else
		return false
	end
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

function request(self, ...)
	self.comet:request(...)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

