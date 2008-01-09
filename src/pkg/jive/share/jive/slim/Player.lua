
--[[
=head1 NAME

jive.slim.Player - Squeezebox/Transporter player.

=head1 DESCRIPTION

TODO

=head1 SYNOPSIS

Notifications:

 playerConnected:
 playerNewName:
 playerDisconnected:
 playerPower:
 playerNew (performed by SlimServer)
 playerDelete (performed by SlimServer)
 playerTrackChange
 playerModeChange

=head1 FUNCTIONS

=cut
--]]

local debug = require("jive.utils.debug")

-- stuff we need
local _assert, tonumber, tostring, pairs = _assert, tonumber, tostring, pairs

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
local Label          = require("jive.ui.Label")
local Window         = require("jive.ui.Window")

local debug          = require("jive.utils.debug")
local log            = require("jive.utils.log").logger("player")

local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME

local iconbar        = iconbar


local fmt = string.format

local MIN_KEY_INT    = 150  -- sending key rate limit in ms

-- jive.slim.Player is a base class
module(..., oo.class)


-- _getSink
-- returns a sink with a closure to self
-- cmd is passed in so we know what process function to call
-- this sink receives all the data from our Comet interface
local function _getSink(self, cmd)
	return function(chunk, err)
	
		if err then
			log:warn("########### ", err)
			
		elseif chunk then
			--log:info(chunk)
			
			local proc = "_process_" .. cmd[1]
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
		self.connected = connected
		if connected == 1 then
			self.jnt:notify('playerConnected', self)
		else
			self.jnt:notify('playerDisconnected', self)
		end
	end
end

-- _setPlayerName()
-- sets the name of the player
-- sends an appropriate notification on change
local function _setPlayerName(self, playerName)
	log:debug("_setPlayerName(", playerName, ")")

	-- make sure this is a new name
	if tostring(playerName) != tostring(self.name) then
		self.name = playerName
		self.jnt:notify('playerNewName', self, playerName)
	end
end


local function _setPlayerPower(self, power)
	log:debug("_setPlayerPower")

	if power != self.power then
		self.power = power
		self.jnt:notify('playerPower', self, power)
	end
end


-- _setPlayerModeChange()
-- sends notifications when changes in the play mode (e.g., moves from play to paused)
local function _setPlayerModeChange(self, mode)
	log:debug("_setPlayerModeChange")
	if mode != self.mode then
		self.mode = mode
		self.jnt:notify('playerModeChange', self, mode)
	end
end

-- _whatsPlaying(obj)
-- returns the track_id from a playerstatus structure
local function _whatsPlaying(obj)
	if obj.item_loop then
		if obj.item_loop[1].params then
			if obj.item_loop[1].params.track_id and not obj.remote then
				return obj.item_loop[1].params.track_id
			elseif obj.item_loop[1].text then
				return obj.item_loop[1].text
			end
		end
	end
	return nil
end

-- _setPlayerTrackChange()
-- sends notifications when a change occurs to the currently playing track
local function _setPlayerTrackChange(self, nowPlaying, data)
	log:debug("_setPlayerTrackChange")
	self.playerStatus = data
	if self.nowPlaying != nowPlaying then
		self.nowPlaying = nowPlaying
		self.jnt:notify('playerTrackChange', self, nowPlaying)
	end
end

--[[

=head2 jive.slim.Player(server, jnt, playerInfo)

Create a Player object for server I<server>.

=cut
--]]

function __init(self, slimServer, jnt, playerInfo)
	log:debug("Player:__init(", playerInfo.playerid, ")")

	_assert(slimServer, "Cannot create Player without SlimServer object")
	
	local obj = oo.rawnew(self,{
		
		lastSeen = os.time(),
		
		slimServer = slimServer,
		jnt = jnt,

		id = playerInfo.playerid,
		name = playerInfo.name,
		model = playerInfo.model,
		connected = playerInfo.connected,
		power = playerInfo.power,
		needsUpgrade = (tonumber(playerInfo.player_needs_upgrade) == 1),
		pin = playerInfo.pin,

		-- menu item of home menu that represents this player
		homeMenuItem = false,
		
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
	
	self.model = playerInfo.model
	self.needsUpgrade = (tonumber(playerInfo.player_needs_upgrade) == 1)

	_setPlayerName(self, playerInfo.name)
	_setPlayerPower(self, tonumber(playerInfo.power))
	_setConnected(self, playerInfo.connected)

	-- PIN is removed from serverstatus after a player is linked
	if self.pin and not playerInfo.pin then
		self.pin = nil
	end

end

--[[

=head2 jive.slim.Player:getTrackElapsed()

returns the amount of time elapsed on the current track

=cut
--]]
function getTrackElapsed(self, data)

	local now = os.time()
	local correction = now - data.lastSeen
	local trackElapsed = data.time + correction
	if correction <= 0 then
		return data.time
	else
		return trackElapsed
	end
	
end

--[[

=head2 jive.slim.Player:getTrackRemaining()

returns the amount of time left on the current track

=cut
--]]

function getTrackRemaining(self)

	local now = os.time()
	local correction = now - self.lastSeen
	if correction < 0 then
		correction = 0
	end

	return self.duration - self.time + correction
	
end

--[[

=head2 jive.slim.Player:getPlayerStatus()

returns the playerStatus information for a given player object

=cut
--]]

function getPlayerStatus(self)
	return self.playerStatus
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

=head2 jive.slim.Player:isPowerOn()

Returns true if the player is powered on

=cut
--]]
function isPowerOn(self)
	return tonumber(self.power) == 1
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

=head2 jive.slim.Player:getPin()

Returns the SqueezeNetwork PIN for this player, if it needs to be registered

=cut
--]]
function getPin(self)
	return self.pin
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
--	log:debug(cmd)

	local reqid = self.slimServer.comet:request(
		_getSink(self, cmd),
		self.id,
		cmd
	)

	return reqid
end


-- send
-- sends a command but does not look for a response
function send(self, cmd)
	log:debug("Player:send():")
--	log:debug(cmd)

	self.slimServer.comet:request(
		nil,
		self.id,
		cmd
	)
end


-- onStage
-- we're being browsed!
function onStage(self, sink)
	log:debug("Player:onStage()")

	self.isOnStage = true
	self.statusSink = sink
	
	-- Batch these queries together
	self.slimServer.comet:startBatch()
	
	-- subscribe to player status updates
	local cmd = { 'status', '-', 10, 'menu:menu', 'subscribe:30' }
	self.slimServer.comet:subscribe(
		'/slim/playerstatus/' .. self.id,
		_getSink(self, cmd),
		self.id,
		cmd
	)

	-- subscribe to displaystatus
	cmd = { 'displaystatus', 'subscribe:showbriefly' }
	self.slimServer.comet:subscribe(
		'/slim/displaystatus/' .. self.id,
		_getSink(self, cmd),
		self.id,
		cmd
	)
	
	self.slimServer.comet:endBatch()

	-- create window to display current song info
	self.currentSong.window = Popup("currentsong")
	self.currentSong.artIcon = Icon("icon")
	self.currentSong.text = Label("text", "")
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
	
	iconbar:setPlaymode(nil)
	iconbar:setRepeat(nil)
	iconbar:setShuffle(nil)
	
	-- unsubscribe from playerstatus and displaystatus events
	self.slimServer.comet:startBatch()
	self.slimServer.comet:unsubscribe('/slim/playerstatus/' .. self.id)
	self.slimServer.comet:unsubscribe('/slim/displaystatus/' .. self.id)
	self.slimServer.comet:endBatch()

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
-- processes the playerstatus data and calls associated functions for notification
function _process_status(self, event)
	log:debug("Player:_process_playerstatus()")
	
	-- update our cache in one go
	self.state = event.data
	
	-- used for calculating getTrackElapsed(), getTrackRemaining()
	self.lastSeen = os.time()
	event.data.lastSeen = self.lastSeen

	_setConnected(self, self.state["player_connected"])

	_setPlayerModeChange(self, event.data.mode)

	local nowPlaying = _whatsPlaying(event.data)

	_setPlayerTrackChange(self, nowPlaying, event.data)

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


function artworkThumbUri (iconId, size)
	return '/music/' .. iconId .. '/cover_' .. size .. 'x' .. size .. '_f_000000.jpg'
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

	s.text:setValue(text)

	s.window:showBriefly(3000, nil, Window.transitionPushPopupUp, Window.transitionPushPopupDown)
end


-- _process_displaystatus
-- receives the display status data
function _process_displaystatus(self, event)
	log:debug("Player:_process_displaystatus()")
	
	local data = event.data

	if data.display then
		local display = data.display
		local type    = display["type"] or 'text'

		if type == 'song' then
			-- new song display from server
			self:_showCurrentSong(table.concat(display["text"], "\n"), display["icon-id"])
		elseif type == 'popupplay' then
			-- playing display from server for artist/genre/year etc - no artwork 
			local popup = Popup("popupplay")
			popup:addWidget(Label("text", table.concat(display["text"], "\n")))
			popup:showBriefly(3000, nil, Window.transitionPushPopupUp, Window.transitionPushPopupDown)
		else
			-- other message from server
			local popup = Popup("popupinfo")
			popup:addWidget(Label("text", table.concat(display["text"], "\n")))
			popup:showBriefly(3000, nil, Window.transitionPushPopupUp, Window.transitionPushPopupDown)
		end
	end
end


-- togglePause
--
function togglePause(self)

	if not self.state then return end
	
	local paused = self.state["mode"]
	log:debug("Player:togglePause(", paused, ")")

	if paused == 'stop' or paused == 'pause' then
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


-- getPlayMode returns nil|stop|play|pause
--
function getPlayMode(self)
	if self.state then
		return self.state["mode"]
	end
end

-- isCurrent
--
function isCurrent(self, index)
	if self.state then
		return self.state["playlist_cur_index"] == index - 1
	end
end


function isNeedsUpgrade(self)
	return self.needsUpgrade
end


-- play
-- 
function play(self)
	log:debug("Player:play()")
	self:call({'mode', 'play'})
	self.state["mode"] = 'play'
	self:updateIconbar()
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
	self.buttonTo = nil
end


-- button
-- 
function button(self, buttonName)
	local now = Framework:getTicks()
	if self.buttonTo == nil or self.buttonTo < now then
		log:debug("Sending button: ", buttonName)
		self:call({'button', buttonName })
		self.buttonTo = now + MIN_KEY_INT
	else
		log:debug("Suppressing button: ", buttonName)
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


-- volume
-- send new volume value to SS
function volume(self, vol, send)
	local now = Framework:getTicks()
	if self.mixerTo == nil or self.mixerTo < now or send then
		log:debug("Sending player:volume(", vol, ")")
		self:send({'mixer', 'volume', vol })
		self.mixerTo = now + MIN_KEY_INT
		self.state["mixer volume"] = vol
		return vol
	else
		log:debug("Suppressing player:volume(", vol, ")")
		return nil
	end
end

-- getVolume
-- returns current volume (from last status update)
function getVolume(self)
	if self.state then
		return self.state["mixer volume"] or 0
	end
end


function getConnected(self)
	return self.connected
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

