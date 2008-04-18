
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
 playerPlaylistChange
 playerPlaylistSize
 playerNeedsUpgrade

=head1 FUNCTIONS

=cut
--]]


-- stuff we need
local _assert, assert, setmetatable, tonumber, tostring, pairs, type = _assert, assert, setmetatable, tonumber, tostring, pairs, type

local os             = require("os")
local math           = require("math")
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
local Textarea       = require("jive.ui.Textarea")
local Window         = require("jive.ui.Window")
local Group          = require("jive.ui.Group")

local debug          = require("jive.utils.debug")
local log            = require("jive.utils.log").logger("player")

local EVENT_KEY_ALL    = jive.ui.EVENT_KEY_ALL
local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME

local iconbar        = iconbar


local fmt = string.format

local MIN_KEY_INT    = 150  -- sending key rate limit in ms

-- jive.slim.Player is a base class
module(..., oo.class)


-- list of players index by id.
local players = {}
setmetatable(players, { __mode = 'v' })


-- _getSink
-- returns a sink with a closure to self
-- cmd is passed in so we know what process function to call
-- this sink receives all the data from our Comet interface
local function _getSink(self, cmd)
	return function(chunk, err)
	
		if err then
			log:warn("########### ", err)
			
		elseif chunk then
			local proc = "_process_" .. cmd[1]
			if cmd[1] == 'status' then
				log:debug('stored playlist timestamp: ', self.playlist_timestamp)
				log:debug('   new playlist timestamp: ', chunk.data.playlist_timestamp)
			end
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

	-- convert to string, in case SC sends a nil player name
	playerName = tostring(playerName)

	-- make sure this is a new name
	if playerName != self.name then
		self.name = playerName
		self.jnt:notify('playerNewName', self, playerName)
	end
end

local function _setPlayerPlaylistSize(self, playlistSize)
	log:debug("_setPlayerPlaylistSize")

	if playlistSize != self.playlistSize then
		self.playlistSize = tonumber(playlistSize)
		self.jnt:notify('playerPlaylistSize', self, tonumber(playlistSize))
	end
end


local function _setPlayerPower(self, power)
	log:debug("_setPlayerPower")

	power = tonumber(power)
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
	local whatsPlaying = nil
	if obj.item_loop then
		if obj.item_loop[1].params then
			if obj.item_loop[1].params.track_id and not obj.remote then
				whatsPlaying = obj.item_loop[1].params.track_id
			elseif obj.item_loop[1].text and obj.remote and type(obj.current_title) == 'string' then
				whatsPlaying = obj.item_loop[1].text .. "\n" .. obj.current_title
			elseif obj.item_loop[1].text then
				whatsPlaying = obj.item_loop[1].text
			end
		end
	end
	return whatsPlaying
end

-- _setPlayerPlaylistChange()
-- sends notifications when anything gets sent about the playlist changing
local function _setPlayerPlaylistChange(self, timestamp)
	log:debug("Player:_setPlayerPlaylistChange")
	if self.playlist_timestamp != timestamp then
		self.playlist_timestamp = timestamp
		self.jnt:notify('playerPlaylistChange', self)
	end
end

-- _setPlayerTrackChange()
-- sends notifications when a change occurs to the currently playing track
local function _setPlayerTrackChange(self, nowPlaying)
	log:debug("Player:_setPlayerTrackChange")

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

function __init(self, jnt, slimServer, playerInfo)
	log:debug("Player:__init(", playerInfo.playerid, ")")

	_assert(slimServer, "Needs slimServer")
	_assert(playerInfo, "Needs playerInfo")

	-- Only create one player object per id. This avoids duplicates
	-- when moving between servers

	local obj = players[playerInfo.playerid]
	if  obj then
		obj:update(slimServer, playerInfo)
		return obj
	end

	local obj = oo.rawnew(self,{
		
		slimServer = slimServer,
		jnt = jnt,

		id = playerInfo.playerid,
		uuid = playerInfo.uuid,
		name = tostring(playerInfo.name),
		model = playerInfo.model,
		connected = playerInfo.connected,
		power = playerInfo.power,
		needsUpgrade = (tonumber(playerInfo.player_needs_upgrade) == 1),
		playerIsUpgrading = (tonumber(playerInfo.player_is_upgrading) == 1),
		pin = playerInfo.pin,

		-- menu item of home menu that represents this player
		homeMenuItem = false,
		
		isOnStage = false,

		-- current song info
		currentSong = {}
	})

	players[obj.id] = obj

	-- notify of new player
	log:info(obj, " new for ", obj.slimServer)
	obj.slimServer:_addPlayer(obj)

	return obj
end


--[[

=head2 jive.slim.Player:update(playerInfo)

Updates the player with fresh data from SS.

=cut
--]]
function update(self, slimServer, playerInfo)
	-- ignore updates from a different server if the player
	-- is not connected to it
	if self.slimServer ~= slimServer 
		and playerInfo.connected ~= 1 then
		return
	end

	-- Update player state
	local lastNeedsUpgrade = self.needsUpgrade
	self.needsUpgrade = (tonumber(playerInfo.player_needs_upgrade) == 1)
	local lastIsUpgrading = self.playerIsUpgrading
	self.playerIsUpgrading = (tonumber(playerInfo.player_is_upgrading) == 1)

	-- FIXME the object state needs setting before any notifications
	-- this is now changed for needsUpgrade and playerIsUpgrading, but still needs to be done
	-- for all other player state


	-- Send player notifications
	if self.slimServer ~= slimServer then
		-- delete from old server
		if self.slimServer then
			self:free(self.slimServer)
		end

		-- add to new server
		self.slimServer = slimServer
		self.slimServer:_addPlayer(self)
		log:info(self, " new for ", self.slimServer)
	end
	
	self.model = playerInfo.model

	if lastNeedsUpgrade != self.needsUpgrade or lastIsUpgrading != self.playerIsUpgrading then
		self.jnt:notify('playerNeedsUpgrade', self, self:isNeedsUpgrade(), self:isUpgrading())
	end

	_setPlayerName(self, playerInfo.name)
	_setPlayerPower(self, tonumber(playerInfo.power))
	_setConnected(self, playerInfo.connected)

	-- PIN is removed from serverstatus after a player is linked
	if self.pin and not playerInfo.pin then
		self.pin = nil
	end
end


-- Subscribe to events for this player
function subscribe(self, ...)
	if not self.slimServer then
		return
	end

	self.slimServer.comet:subscribe(...)
end


-- Unsubscribe to events for this player
function unsubscribe(self, ...)
	if not self.slimServer then
		return
	end

	self.slimServer.comet:unsubscribe(...)
end



--[[

=head2 jive.slim.Player:getTrackElapsed()

Returns the amount of time elapsed on the current track, and the track
duration (if known). eg:

  local elapsed, duration = player:getTrackElapsed()
  local remaining
  if duration then
	  remaining = duration - elapsed
  end

=cut
--]]
function getTrackElapsed(self)
	if not self.trackTime then
		return nil
	end

	if self.state.mode == "play" then
		local now = Framework:getTicks() / 1000

		-- multiply by rate to allow for trick modes
		self.trackCorrection = tonumber(self.state.rate) * (now - self.trackSeen)
	end

	if self.trackCorrection <= 0 then
		return tonumber(self.trackTime), tonumber(self.trackDuration)
	else
		local trackElapsed = self.trackTime + self.trackCorrection
		return tonumber(trackElapsed), tonumber(self.trackDuration)
	end
	
end

--[[

=head2 jive.slim.Player:getPlaylistTimestamp()

returns the playlist timestamp for a given player object
the timestamp is an indicator of the last time the playlist changed
it serves as a good check to see whether playlist items should be refreshed

=cut
--]]
function getPlaylistTimestamp(self)
	return self.playlist_timestamp
end

--[[

=head2 jive.slim.Player:getPlaylistSize()

returns the playlist size for a given player object

=cut
--]]
function getPlaylistSize(self)
	return tonumber(self.playlistSize)
end

--[[

=head2 jive.slim.Player:getPlayerMode()

returns the playerMode for a given player object

=cut
--]]
function getPlayerMode(self)
	return self.mode
end


--[[

=head2 jive.slim.Player:getPlayerPower()

returns the playerPower for a given player object

=cut
--]]
function getPlayerPower(self)
	return tonumber(self.power)
end


--[[

=head2 jive.slim.Player:getPlayerStatus()

returns the playerStatus information for a given player object

=cut
--]]
function getPlayerStatus(self)
	return self.state
end

--[[

=head2 jive.slim.Player:free(slimServer)

Deletes the player, if connect to the given slimServer

=cut
--]]
function free(self, slimServer)
	_assert(slimServer)

	if self.slimServer ~= slimServer then
		-- ignore, we are not connected to this server
		return
	end

	log:info(self, " delete for ", self.slimServer)
	self.slimServer:_deletePlayer(self)
	self:offStage()
	self.slimServer = nil

	-- The global players table uses weak values, it will be removed
	-- when all references are freed.
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

=head2 jive.slim.Player:getUuid()

Returns the player uuid.

=cut
--]]
function getUuid(self)
	return self.uuid
end


--[[

=head2 jive.slim.Player:getMacAddress()

Returns the player mac address, or nil for http players.

=cut
--]]
function getMacAddress(self)
	if self.model == "squeezebox2"
		or self.model == "receiver"
		or self.model == "transporter" then

		return string.gsub(self.id, "[^%x]", "")
	end

	return nil
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
function onStage(self)
	log:debug("Player:onStage()")

	self.isOnStage = true
	
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
	self.currentSong.window:setAllowScreensaver(true)
	self.currentSong.window:setAlwaysOnTop(true)
	self.currentSong.artIcon = Icon("icon")
	self.currentSong.text = Label("text", "")
	self.currentSong.textarea = Textarea('popupplay', '')

	local group = Group("popupToast", {
			text = self.currentSong.text,
			textarea = self.currentSong.textarea,
			icon = self.currentSong.artIcon
	      })

	self.currentSong.window:addWidget(group)
	self.currentSong.window:addListener(EVENT_KEY_ALL | EVENT_SCROLL,
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

	if event.data.error then
		-- ignore player status sent with an error
		return
	end

	-- update our cache in one go
	self.state = event.data
debug.dump(event.data, -1)
	-- used for calculating getTrackElapsed(), getTrackRemaining()
	self.trackSeen = Framework:getTicks() / 1000
	self.trackCorrection = 0
	self.trackTime = event.data.time
	self.trackDuration = event.data.duration

	_setConnected(self, self.state["player_connected"])
	_setPlayerPlaylistSize(self, tonumber(event.data.playlist_tracks))
	_setPlayerPower(self, tonumber(event.data.power))

	_setPlayerModeChange(self, event.data.mode)

	local nowPlaying = _whatsPlaying(event.data)

	_setPlayerTrackChange(self, nowPlaying)
	_setPlayerPlaylistChange(self, event.data.playlist_timestamp)

	self:updateIconbar()
end


-- _process_displaystatus
-- receives the display status data
function _process_displaystatus(self, event)
	log:debug("Player:_process_displaystatus()")
	
	local data = event.data

	if data.display then
		local display = data.display
		local type    = display["type"] or 'text'

		local s = self.currentSong

		if type == 'song' then
			s.textarea:setValue("")
			s.text:setValue(table.concat(display["text"], "\n"))
			s.artIcon:setStyle("icon")
			if display['icon'] then
				self.slimServer:fetchArtworkURL(display['icon'], s.artIcon, 56)
			else
				self.slimServer:fetchArtworkThumb(display["icon-id"], s.artIcon, 56, 'png')
			end
		else
			s.text:setValue('')
			s.artIcon:setStyle("noimage")
			s.artIcon:setValue(nil)
			s.textarea:setValue(table.concat(display["text"], "\n"))
		end
		s.window:showBriefly(3000, nil, Window.transitionPushPopupUp, Window.transitionPushPopupDown)
	end
end


-- togglePause
--
function togglePause(self)

	if not self.state then return end
	
	local paused = self.state["mode"]
	log:debug("Player:togglePause(", paused, ")")

	if paused == 'stop' or paused == 'pause' then
		-- reset the elapsed time epoch
		self.trackSeen = Framework:getTicks() / 1000

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

function isUpgrading(self)
	return self.playerIsUpgrading
end

-- play
-- 
function play(self)
	log:debug("Player:play()")

	if self.state.mode ~= 'play' then
		-- reset the elapsed time epoch
		self.trackSeen = Framework:getTicks()
	end

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

-- scan_rew
-- what to do for the rew button when held
-- use button so that the reverse scan mode is triggered.
function scan_rew(self)
	self:button('scan_rew')
end

-- scan_fwd
-- what to do for the fwd button when held
-- use button so that the forward scan mode is triggered.
function scan_fwd(self)
	self:button('scan_fwd')
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
-- send new volume value to SS, returns a negitive value if the player is muted
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

-- gototime
-- jump to new time in song
function gototime(self, time)
	self.trackSeen = Framework:getTicks() / 1000
	self.trackTime = time
	log:debug("Sending player:time(", time, ")")
	self:send({'time', time })
	return nil
end

-- isTrackSeekable
-- Try to work out if SC can seek in this track - only really a guess
function isTrackSeekable(self)
	return self.trackDuration and not self.state.remote
end

-- mute
-- mutes or ummutes the player, returns a negitive value if the player is muted
function mute(self, mute)
	local vol = self.state["mixer volume"]
	if mute and vol >= 0 then
		-- mute
		self:send({'mixer', 'muting'})
		vol = -math.abs(vol)

	elseif vol < 0 then
		-- unmute
		self:send({'mixer', 'muting'})
		vol = math.abs(vol)
	end

	self.state["mixer volume"] = vol
	return vol
end


-- getVolume
-- returns current volume (from last status update)
function getVolume(self)
	if self.state then
		return self.state["mixer volume"] or 0
	end
end


-- returns true if this player supports udap setup
function canUdap(self)
	return self.model == "receiver"
end


-- returns true if this player can connect to another server
function canConnectToServer(self)
	return self.model == "squeezebox2"
		or self.model == "receiver"
		or self.model == "transporter"
end


-- tell the player to connect to another server
function connectToServer(self, server)
	local ip, port = server:getIpPort()
	self:send({'connect', ip})
end


function isConnected(self)
	return self.slimServer and self.slimServer:isConnected() and self.connected
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

