
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
 serverDisconnected(self, numUserRequests)

=head1 FUNCTIONS

=cut
--]]

-- our stuff
local _assert, assert, tostring, type, tonumber = _assert, assert, tostring, type, tonumber
local pairs, ipairs, require, setmetatable = pairs, ipairs, require, setmetatable

local os          = require("os")
local table       = require("jive.utils.table")
local string      = require("string")

local oo          = require("loop.base")

local Comet       = require("jive.net.Comet")
local HttpPool    = require("jive.net.HttpPool")
local Surface     = require("jive.ui.Surface")
local RequestHttp = require("jive.net.RequestHttp")
local SocketHttp  = require("jive.net.SocketHttp")
local WakeOnLan   = require("jive.net.WakeOnLan")

local Task        = require("jive.ui.Task")
local Framework   = require("jive.ui.Framework")

local ArtworkCache = require("jive.slim.ArtworkCache")

local debug       = require("jive.utils.debug")
local log         = require("jive.utils.log").logger("slimserver")
local logcache    = require("jive.utils.log").logger("slimserver.cache")


-- jive.slim.SlimServer is a base class
module(..., oo.class)


-- we must load this after the module declartion to dependancy loops
local Player      = require("jive.slim.Player")


-- list of servers index by id. this weak table is used to enforce
-- object equality with the server name.
local serverIds = {}
setmetatable(serverIds, { __mode = 'v' })

-- list of servers, that are active
local serverList = {}

-- current server
local currentServer = nil

-- credential list for http auth
local credentials = {}


-- class function to iterate over all SqueezeCenters
function iterate(class)
	return pairs(serverList)
end


-- class method to return current server
function getCurrentServer(class)
	return currentServer
end


-- class method to set the current server
function setCurrentServer(class, server)
	lastCurrentServer = currentServer

	currentServer = server

	-- is the current server still active, it not clean up?
	if lastCurrentServer and lastCurrentServer.lastSeen == 0 then
		lastCurrentServer:free()
	end
end


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
	self.lastSeen = Framework:getTicks()
	
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

	local pin = nil
	
	if tonumber(data["player count"]) > 0 then

		for i, player_info in ipairs(serverPlayers) do

			local playerId = player_info.playerid

			if player_info.pin then
				pin = player_info.pin
			end

			-- remove the player from our list since it is reported by the server
			selfPlayers[playerId] = nil
	
			-- create new players
			if not self.players[playerId] then
				self.players[playerId] = Player(self.jnt, playerId)
			end

			-- update player state
			self.players[playerId]:updatePlayerInfo(self, player_info)
		end
	else
		log:info(self, ": has no players!")
	end
	
	if self.pin ~= pin then
		self.jnt:notify('serverLinked', self)
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
end


function _addPlayer(self, player)
	self.players[player:getId()] = player
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
function __init(self, jnt, name)
	-- Only create one server object per server. This avoids duplicates
	-- following a server disconnect.

	if serverIds[name] then
		return serverIds[name]
	end

	log:debug("SlimServer:__init(", name, ")")

	local obj = oo.rawnew(self, {
		id = name,
		name = name,
		jnt = jnt,

		-- connection stuff
		lastSeen = 0,
		ip = false,
		port = false,

		-- data from SqueezeCenter
		state = {},

		-- players
		players = {},

		-- our comet connection, initially not connected
		comet = Comet(jnt, name),

		-- are we connected to the server?
		-- 'disconnected' = not connected
		-- 'connecting' = trying to connect
		-- 'connected' = connected
		netstate = 'disconnected',

		-- number of user activated requests
		userRequests = {},

		-- artwork state below here

		-- artwork http pool, initially not connected
		artworkPool = false,

		-- artwork cache: Weak table storing a surface by iconId
		artworkCache = ArtworkCache(),

		-- Icons waiting for the given iconId
		artworkThumbIcons = {},

		-- queue of artwork to fetch
		artworkFetchQueue = {},
		artworkFetchCount = 0,

		-- loaded images
		imageCache = {},
	})

	-- subscribe to server status, max 50 players every 60 seconds.
	-- FIXME: what if the server has more than 50 players?
	obj.comet:aggressiveReconnect(true)
	obj.comet:subscribe('/slim/serverstatus',
		_getSink(obj, '_serverstatusSink'),
		nil,
		{ 'serverstatus', 0, 50, 'subscribe:60' }
	)

	setmetatable(obj.imageCache, { __mode = "kv" })

	serverIds[obj.id] = obj

	-- subscribe to comet events
	jnt:subscribe(obj)

	-- task to fetch artwork while browsing
	obj.artworkFetchTask = Task("artwork", obj, processArtworkQueue)
	
	return obj
end


-- Update server on start up
function updateInit(self, init)
	if serverList[self.id] then
		-- already initialized
		return
	end

	self.ip = init.ip
	self.mac = init.mac

	self.lastSeen = 0 -- don't timeout
	serverList[self.id] = self
end


-- State needed for updateInit
function getInit(self)
	return {
		ip = self.ip,
		mac = self.mac,
	}
end


--[[

=head2 jive.slim.SlimServer:updateAddress(ip, port)

Called to update (or initially set) the ip address and port for SqueezeCenter

=cut
--]]
function updateAddress(self, ip, port)
	if self.ip ~= ip or self.port ~= port then
		log:info(self, ": address set to ", ip , ":", port, " netstate=", self.netstate)

		local oldstate = self.netstate

		-- close old connections
		self:disconnect()

		-- open new comet connection
		self.ip = ip
		self.port = port

		-- http authentication
		local cred = credentials[self.name]
		if cred then
			SocketHttp:setCredentials({
				ipport = { ip, port },
				realm = cred.realm,
				username = cred.username,
				password = cred.password,
			})
		end

		-- artwork http pool
		self.artworkPool = HttpPool(self.jnt, self.name, ip, port, 2, 1, Task.PRIORITY_LOW)

		-- commet
		self.comet:setEndpoint(ip, port, '/cometd')

		-- reconnect, if we were already connected
		if oldstate ~= 'disconnected' then
			self:connect()
		end
	end

	local oldLastSeen = self.lastSeen
	self.lastSeen = Framework:getTicks()

	-- server is now active
	if oldLastSeen == 0  then
		serverList[self.id] = self
		self.jnt:notify('serverNew', self)
	end
end


--[[

=head2 jive.slim.SlimServer:free()

Deletes a SlimServer object, frees memory and closes connections with the server.

=cut
--]]
function free(self)
	log:debug(self, ":free")

	-- clear cache
	self.artworkCache:free()
	self.artworkThumbIcons = {}

	-- server is gone
	self.lastSeen = 0
	self.jnt:notify("serverDelete", self)

	if self == currentServer then
		-- dont' delete state if this is the current server
		return
	end

	-- close connections
	self:disconnect()

	-- delete players
	for id, player in pairs(self.players) do
		player:free(self)
	end
	self.players = {}

	-- server is no longer active
	serverList[self.id] = nil

	-- don't remove the server from serverIds, the weak value means
	-- this instance will be deleted when it is no longer referenced
	-- by any other code
end


function wakeOnLan(self)
	if not self.mac or self:isSqueezeNetwork() then
		return
	end

	log:info("Sending WOL to ", self.mac)

	-- send WOL packet to SqueezeCenter
	local wol = WakeOnLan(self.jnt)
	wol:wakeOnLan(self.mac)
end


-- connect to SqueezeCenter
function connect(self)
	if self.netstate == 'connected' or self.netstate == 'connecting' then
		return
	end

	if self.lastSeen == 0 then
		log:debug("Server ip address is not known")
		return
	end

	log:info(self, ":connect")

	assert(self.comet)
	assert(self.artworkPool)

	self.netstate = 'connecting'

	-- artwork pool connects on demand
	self.comet:connect()
end


-- force disconnect to SqueezeCenter
function disconnect(self)
	if self.netstate == 'disconnected' then
		return
	end

	log:info(self, ":disconnect")

	self.netstate = 'disconnected'

	self.artworkPool:close()
	self.comet:disconnect()
end


-- force reconnection to SqueezeCenter
function reconnect(self)
	log:info(self, ":reconnect")

	self:disconnect()
	self:connect()
end


-- comet has connected to SC
function notify_cometConnected(self, comet)
	if self.comet ~= comet then
		return
	end

	log:info(self, " connected")

	self.netstate = 'connected'
	self.jnt:notify('serverConnected', self)

    -- auto discovery SqueezeCenter's mac address
    self.jnt:arp(self.ip,
             function(chunk, err)
                 if err then
                     log:info("arp: " .. err)
                 else
                     self.mac = chunk
                 end
             end)
end

-- comet is disconnected from SC
function notify_cometDisconnected(self, comet)
	if self.comet ~= comet then
		return
	end

	if self.netstate == 'connected' then
		log:info(self, " disconnected")

		self.netstate = 'connecting'
	end

	-- always send the notification
	self.jnt:notify('serverDisconnected', self, #self.userRequests)
end


-- comet http error
function notify_cometHttpError(self, comet, cometRequest)
	if cometRequest:t_getResponseStatus() == 401 then
		local authenticate = cometRequest:t_getResponseHeader("WWW-Authenticate")

		self.realm = string.match(authenticate, 'Basic realm="(.*)"')
	end
end


-- Returns true if the server is SqueezeNetwork
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
		if player:getPin() == pin then
			player:clearPin()
		end
	end
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
	return self.state.version
end


--[[

=head2 jive.slim.SlimServer:getIpPort()

Returns the server IP address and HTTP port

=cut
--]]
function getIpPort(self)
	return self.ip, self.port
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
	return self.lastSeen
end


--[[

=head2 jive.slim.SlimServer:isConnected()

Returns the state of the long term connection with the server. This is used by
L<jive.slim.SlimServers> to delete old servers.

=cut
--]]
function isConnected(self)
	return self.netstate == 'connected'
end


-- returns true if a password is needed
function isPasswordProtected(self)
	if self.realm and self.netstate ~= 'connected' then
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


-- user request. if not connected to SC, this will try to reconnect and also
-- sends WOL
function userRequest(self, func, ...)
	if self.netstate ~= 'connected' then
		self:wakeOnLan()
		self:connect()
	end

	local req = { func, ... }
	table.insert(self.userRequests, req)

	self.comet:request(
		function(...)
			table.delete(self.userRequests, req)
			if func then
				func(...)
			end
		end,
		...)
end


-- background request
function request(self, ...)
	self.comet:request(...)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

