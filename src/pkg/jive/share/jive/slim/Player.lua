
--[[
=head1 NAME

jive.slim.Player - Squeezebox/Transporter player.

=head1 DESCRIPTION

TODO

=head1 SYNOPSIS

Notifications:

 playerConnected:
 playerDisconnected:
 playerNew (performed by SlimServer)
 playerDelete (performed by SlimServer)

=head1 FUNCTIONS

=cut
--]]

local debug = require("jive.utils.debug")

-- stuff we need
local assert, tostring = assert, tostring

local os             = require("os")
local string         = require("string")
local table          = require("table")

local oo             = require("loop.base")

local SocketHttp     = require("jive.net.SocketHttp")
local RequestHttp    = require("jive.net.RequestHttp")
local RequestJsonRpc = require("jive.net.RequestJsonRpc")
local Framework      = require("jive.ui.Framework")
local Popup          = require("jive.ui.Popup")
local Icon           = require("jive.ui.Icon")
local Textarea       = require("jive.ui.Textarea")
local Window         = require("jive.ui.Window")

local log            = require("jive.utils.log").logger("player")

require("jive.slim.RequestsCli")
local RequestCli     = jive.slim.RequestCli

local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME

local iconbar        = iconbar


local fmt = string.format

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
			--log:info(chunk)
			
			local channel = string.match(chunk._channel, "/slim/(%a+)/")
			
			local proc = "_process_" .. channel
			if self[proc] then
				self[proc](self, chunk)
			end
				
		end
	end
end


-- _setConnected(connected)
-- sets the connected state from the player
-- sends an appropriate notification on change
local function _setConnected(self, connected)
	log:debug("_setConnected(", connected, ")")
	
	-- use tostring to handle nil case (in either)
	if tostring(connected) != tostring(self.connected) then
		if connected == 1 then
			self.jnt:notify('playerConnected', self)
		else
			self.jnt:notify('playerDisconnected', self)
		end
		self.connected = connected
	end
end


--[[

=head2 jive.slim.Player(server, jnt, jpool, playerInfo)

Create a Player object for server I<server>.

=cut
--]]
function __init(self, slimServer, jnt, jpool, playerInfo)
	log:debug("Player:__init(", playerInfo.playerid, ")")

	assert(slimServer, "Cannot create Player without SlimServer object")
	
	local obj = oo.rawnew(self,{
		
		lastSeen = os.time(),
		
		slimServer = slimServer,
		jnt = jnt,
		jpool = jpool,

		id = playerInfo.playerid,
		name = playerInfo.name,
		model = playerInfo.model,
		connected = playerInfo.connected,

		-- menu item of home menu that represents this player
		homeMenuItem = false,
		
		jsp = false,
		jdsp = false,
		
		isOnStage = false,
		statusSink = false,

		-- current song info
		currentSong = {}
	})
	
	-- SlimServer notifies of our arrival, so that listener see us in the SS db when notified, not before
	
	return obj
end


--[[

=head2 jive.slim.Player:updateFromSS(playerInfo)

Updates the player with fresh data from SS.

=cut
--]]
function updateFromSS(self, playerInfo)
	
	self.name = playerInfo.name
	self.model = playerInfo.model
	_setConnected(self, playerInfo.connected)
end

--[[

=head2 jive.slim.Player:free()

Deletes the player.

=cut
--]]
function free(self)
	self:offStage()
	-- caller has to notify we're gone
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


--[[

=head2 jive.slim.Player:getName()

Returns the player name

=cut
--]]
function getName(self)
	return self.name
end


--[[

=head2 jive.slim.Player:getId()

Returns the player id (in general the MAC address)

=cut
--]]
function getId(self)
	return self.id
end


--[[

=head2 jive.slim.Player:getSlimServer()

Returns the player SlimServer (a L<jive.slim.SlimServer>).

=cut
--]]
function getSlimServer(self)
	return self.slimServer
end


-- call
-- sends a command
function call(self, cmd)
	log:debug("Player:call():")
	log:debug(cmd)
	local req = RequestCli(
		_getSink(self), --sink, 
		self, --player, 
		cmd --cmdarray, 
		--from, 
		--to, 
		--params, 
		--options
	)
	local id = req:getJsonId()
	self:queuePriority(req)
	return id
end


-- onStage
-- we're being browsed!
function onStage(self, sink)
	log:debug("Player:onStage()")

	self.isOnStage = true
	self.statusSink = sink
	
	-- subscribe to player status updates
	self.slimServer.comet:subscribe(
		'/slim/playerstatus/' .. self.id,
		_getSink(self),
		self.id,
		{ 'status', '-', 10, 'menu:menu', 'subscribe:30' }
	)

	-- subscribe to displaystatus
	self.slimServer.comet:subscribe(
		'/slim/displaystatus/' .. self.id,
		_getSink(self),
		self.id,
		{ 'displaystatus', 'subscribe:showbriefly' }
	)

	-- create window to display current song info
	self.currentSong.window = Popup("currentsong")
	self.currentSong.artIcon = Icon("icon")
	self.currentSong.text = Textarea("text")
	self.currentSong.window:addWidget(self.currentSong.artIcon)
	self.currentSong.window:addWidget(self.currentSong.text)
	self.currentSong.window:addListener(EVENT_KEY_PRESS | EVENT_SCROLL,
		function(event)
			local prev = self.currentSong.window:getLowerWindow()
			if prev then
				Framework:dispatchEvent(prev, event)
			end
			return EVENT_CONSUME
		end)
	self.currentSong.window.brieflyHandler = 1
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

	if self.jdsp then
		self.jdsp:free()
		self.jdsp = false
	end
	
	iconbar:setPlaymode(nil)
	iconbar:setRepeat(nil)
	iconbar:setShuffle(nil)
	
	-- unsubscribe from playerstatus and displaystatus events
	self.slimServer.comet:unsubscribe('/slim/playerstatus/' .. self.id)
	self.slimServer.comet:unsubscribe('/slim/displaystatus/' .. self.id)

	self.currentSong = {}
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
function _process_playerstatus(self, event)
	log:debug("Player:_process_playerstatus()")
	if self.state then
		log:debug("-------------------------Player:volume: ", self.state["mixer volume"], " - " , event["mixer volume"])
	end
	
	-- update our cache in one go
	self.state = event
	
	_setConnected(self, self.state["player_connected"])
	
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


function artworkThumbUri (iconId)
	return '/music/' .. iconId .. '/cover_50x50_f_000000.jpg'
end


function _showCurrentSong(self, text, iconId)
	log:debug("Player:showCurrentSong()")

	local s = self.currentSong

	if iconId then
		s.window:removeWidget(s.artIcon)
		s.artIcon = Icon("icon")
		s.window:addWidget(s.artIcon)
		if iconId ~= 0 then
			self.slimServer:fetchArtworkThumb(iconId, s.artIcon, artworkThumbUri, nil, true)
		end
	end

	s.text:setText(text)

	s.window:showBriefly(3000)
end


-- _process_displaystatus
-- receives the display status data
function _process_displaystatus(self, event)
	log:debug("Player:_process_displaystatus()")

	if event.display then
		local display = event.display
		local type    = display["type"] or 'text'

		if type == 'song' then
			-- new song display from server
			self:_showCurrentSong(table.concat(display["text"], "\n"), display["icon-id"])
		else
			-- other message from server
			local popup = Popup("popup")
			popup:addWidget(Textarea("textarea", table.concat(display["text"], "\n")))
			popup:showBriefly(2000)
		end
	end
end


-- togglePause
--
function togglePause(self)

	if not self.state then return end
	
	local paused = self.state["mode"]
	log:debug("Player:togglePause(", paused, ")")

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


-- isPaused
--
function isPaused(self)
	if self.state then
		return self.state["mode"] == 'pause'
	end
end


-- isCurrent
--
function isCurrent(self, index)
	if self.state then
		return self.state["playlist_cur_index"] == index - 1
	end
end


-- stop
-- 
function stop(self)
	log:debug("Player:stop()")
	self:call({'mode', 'stop'})
	self.state["mode"] = 'stop'
	self:updateIconbar()
end


-- playlistJumpIndex
--
function playlistJumpIndex(self, index)
	log:debug("Player:playlistJumpIndex(", index, ")")
	if index < 1 then return end
	self:call({'playlist', 'index', index - 1})
end


-- playlistDeleteIndex(self, index)
--
function playlistDeleteIndex(self, index)
	log:debug("Player:playlistDeleteIndex(", index, ")")
	if index < 1 then return end
	self:call({'playlist', 'delete', index - 1})
end


-- playlistZapIndex(self, index)
--
function playlistZapIndex(self, index)
	log:debug("Player:playlistZapIndex(", index, ")")
	if index < 1 then return end
	self:call({'playlist', 'zap', index - 1})
end



-- _process_button
--
function _process_button(self, event)
	log:debug("_process_button()")
	log:debug("id:", event["id"], " waiting on:", self.buttonId)
	if event["id"] == self.buttonId then
		log:debug("cleared")
		self.buttonId = false
	end
end


-- button
-- 
function button(self, buttonName)
	log:debug("Player:button(", buttonName, ")")
	if not self.buttonId then
		log:debug(".. sent")
		self.buttonId = self:call({'button', buttonName})
	else
		log:debug(".. ignored")
	end
end


-- rew
-- what to do for the rew button
-- use button so that the logic of SS (skip to start of current or previous song) is used
function rew(self)
	log:debug("Player:rew()")
	self:button('jump_rew')
end


-- fwd
-- what to do for the fwd button
-- use button so that the logic of SS (skip to start of current or previous song) is used
function fwd(self)
	log:debug("Player:fwd()")
	self:button('jump_fwd')
end






--[[
local function _t()
	return Framework:getTicks() / 1000
end


function _process_ir(self, data)
--	log:debug("_process_ir()")
--	log:debug("id:", data["id"], " waiting on:", self.irId)
	if data["id"] == self.irId then
--		log:debug("cleared")
		self.irId = false
		log:warn("round trip:", _t() - self.irT)
	end
end

function volumeUp(self)
--	log:debug("Player:volumeUp()")
	if not self.irId then
--		log:debug(".. sent")
		local t = _t()
		self.irT = t
		self.irId = self:call({'ir', '7689807f', _t()})
--	else
--		log:debug(".. ignored")
	end
end

function volumeDown(self)
--	log:debug("Player:volumeDown")
	if not self.irId then
--		log:debug(".. sent")
		local t = _t()
		self.irT = t
		self.irId = self:call({'ir', '768900ff', _t()})
--	else
--		log:debug(".. ignored")
	end
end
--]]


function _process_mixer(self, event)
--	log:debug("_process_ir()")
--	log:debug("id:", data["id"], " waiting on:", self.irId)
	if event["id"] == self.mixerId then
--		log:debug("cleared")
		self.mixerId = false
--		log:warn("Mixer round trip:", _t() - self.mixerT)
	end
end

function volume(self, amount)

	local vol = self.state["mixer volume"]
	
	if not self.mixerId then
		log:debug("Player:volume(", amount, ")")
		
--		self.mixerT = _t()
		self.mixerId = self:call({'mixer', 'volume', fmt("%+d", amount)})
		
		vol = vol + amount
		if vol > 100 then vol = 100 elseif vol < 0 then vol = 0 end
		self.state["mixer volume"] = vol
		
--	else
--		log:debug("(Player:volume(", amount, "))")
	end
	
	return vol
end


function getVolume(self)
	if self.state then
		return self.state["mixer volume"] or 0
	end
end




function getConnected(self)
	return self.connected
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

