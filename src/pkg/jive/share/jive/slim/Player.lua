
--[[
=head1 NAME

jive.slim.Player - Squeezebox/Transporter player.

=head1 DESCRIPTION

TODO

=head1 SYNOPSIS

TODO

=head1 FUNCTIONS

=cut
--]]

-- stuff we need
local assert, tostring = assert, tostring

local os             = require("os")

local oo             = require("loop.base")

local SocketHttp     = require("jive.net.SocketHttp")
local RequestJsonRpc = require("jive.net.RequestJsonRpc")

local log            = require("jive.utils.log").logger("player")

require("jive.slim.RequestsCli")
local RequestStatus  = jive.slim.RequestStatus
local RequestCli     = jive.slim.RequestCli

local iconbar        = iconbar

-- jive.slim.Player is a base class
module(..., oo.class)


-- _getSink
-- returns a sink with a closure to self
-- this sink receives all the data from our JSON RPC interface
local function _getSink(self)

	return function(chunk, err)
	
		if err then
			log:debug(err)
			
		elseif chunk then
			log:info(chunk)
			
			if chunk.method == 'slim.request' then
			
				local proc = "_process_" .. chunk.params[2][1]
				if self[proc] then
					self[proc](self, chunk)
				end
				
			elseif chunk.method == 'slim.playermenu' then
			
				log:debug("Loading menu for player ", tostring(self))
				self.menuItems = chunk.result["@items"]
			end
		end
	end
end


--[[

=head2 jive.slim.Player(server, jnt, jpool, playerinfo)

Create a Player object for server I<server>.

=cut
--]]
function __init(self, slimServer, jnt, jpool, playerinfo)
	log:debug("Player:__init(", tostring(playerinfo.playerid), ")")

	assert(slimServer, "Cannot create Player without SlimServer object")
	
	local obj = oo.rawnew(self,{
		
		lastSeen = os.time(),
		
		slimServer = slimServer,
		jnt = jnt,
		jpool = jpool,

		id = playerinfo.playerid,
		name = playerinfo.name,
		model = playerinfo.model,

		-- menu item of home menu that represents this player
		homeMenuItem = false,
		
		menuItems = false,
		jsp = false,
		
		isOnStage = false,
		statusSink = false,
	})

	
	jpool:queue(
		RequestJsonRpc(
			_getSink(obj), 
			'/plugins/Jive/jive.js', 
			'slim.playermenu', 
			nil
		)
	)

	jpool:queue(
		RequestStatus(
			_getSink(obj), 
			obj, 
			'-', 
			10, 
			nil, 
			{tags = 'aljJ'}
		)
	)
	
	-- notify we're here
	obj.jnt:notify('playerNew', obj)
	
	return obj
end


--[[

=head2 jive.slim.Player:free()

Deletes the player.

=cut
--]]
function free(self)
	self:offStage()
	self.jnt:notify("playerDelete", self)
end


--[[

=head2 jive.slim.Player:getHomeMenuItem()

Returns the home menu menuItem that represents this player. This is
used by L<jive.applet.SlimDiscovery> to remove the player from the menu
if/when it disappears.

=cut
--]]
function getHomeMenuItem(self)
	-- return nil if self.homeMenuItem is false
	if self.homeMenuItem then
		return self.homeMenuItem
	end
	return nil
end


--[[

=head2 jive.slim.Player:setHomeMenuItem(homeMenuItem)

Stores the main home menuItem that represents this player. This is
used by L<jive.applet.SlimDiscovery> to manage the home menu item.

=cut
--]]
function setHomeMenuItem(self, homeMenuItem)
	-- set self.homeMenuItem to false if sent nil
	if homeMenuItem then
		self.homeMenuItem = homeMenuItem
	else
		self.homeMenuItem = false
	end
end


--[[

=head2 tostring(aPlayer)

if I<aPlayer> is a L<jive.slim.Player>, prints
 Player {name}

=cut
--]]
function __tostring(self)
	return "Player {" .. self.name .. "}"
end






-- call
-- sends a command
function call(self, cmd)
	log:debug("Player:call():")
	log:debug(cmd)
	self:queuePriority(RequestCli(
		_getSink(self), --sink, 
		self, --player, 
		cmd --cmdarray, 
		--from, 
		--to, 
		--tags, 
		--options
		))
end


-- onStage
-- we're being browsed!
function onStage(self, sink)
	log:debug("Player:onStage()")

	self.isOnStage = true
	self.statusSink = sink
	
	-- our socket for long term connections
	local ip, port = self.slimServer:getIpPort()
	self.jsp = SocketHttp(self.jnt, ip, port, "playerLT")
	
	-- our long term request
	local reqcli = RequestStatus(_getSink(self), self, '-', 10, 30, {tags = 'aljJ'})
	
	self.jsp:fetch(reqcli)

	-- update the iconbar with potentially stale cache data
	self:updateIconbar()
	
	-- send current data through our sink
	self:feedStatusSink()
	
	return self.menuItems
end


-- offStage
-- go back to the shadows...
function offStage(self)
	log:debug("Player:offStage()")

	self.isOnStage = false
	
	if self.jsp then
		self.jsp:free()
		self.jsp = false
	end
	
	iconbar:setPlaymode(nil)
	iconbar:setRepeat(nil)
	iconbar:setShuffle(nil)
end


-- updateIconbar
function updateIconbar(self)
	log:debug("Player:updateIconbar()")
	
	if self.isOnStage and self.state then

		-- set the playmode (nil, stop, play, pause)
		iconbar:setPlaymode(self.state["mode"])
		
		-- set the repeat (nil, 0=off, 1=track, 2=playlist)
		iconbar:setRepeat(self.state["playlist repeat"])
	
		-- set the shuffle (nil, 0=off, 1=by song, 2=by album)
		iconbar:setShuffle(self.state["playlist shuffle"])
	end
end


-- _process_status
-- receives the status data
function _process_status(self, data)
	log:debug("Player:_process_status()")
	
	-- cache result
	self.state = data.result
	
	self:updateIconbar()
	
	self:feedStatusSink()
end


-- feedStatusSink
--
function feedStatusSink(self)
	if self.state and self.statusSink then
		self.statusSink(self.state)
	end
end


-- togglepause
--
function togglepause(self)
	local paused = self.state["mode"]
	log:debug("Player:togglepause(", paused, ")")

	if paused == 'stop' then
		return
	elseif paused == 'pause' then
		self:call({'pause', '0'})
		self.state["mode"] = 'play'
	elseif paused == 'play' then
		self:call({'pause', '1'})
		self.state["mode"] = 'pause'
	end
	self:updateIconbar()
end	

function getVolume(self)
	return self.state["mixer volume"] or 0
end

function volumeUp(self)
	log:debug("Player:volumeUp()")
	self:call({'button', 'volume_up'})
end

function volumeDown(self)
	log:debug("Player:volumeDown()")
	self:call({'button', 'volume_down'})
end

function stop(self)
	log:debug("Player:stop()")
	self:call({'mode', 'stop'})
	self.state["mode"] = 'stop'
	self:updateIconbar()
end

-- (accessors)
function getName(self)
	return self.name
end

function getId(self)
	return self.id
end

function getSlimServer(self)
	return self.slimServer
end

-- queue
-- proxy function for the slimserver pool
function queue(self, request)
	self.jpool:queue(request)
end


-- queuePriority
-- proxy function for the slimserver pool
function queuePriority(self, request)
	self.jpool:queuePriority(request)
end






--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

