--[[

Player instance for local playback.

--]]

local assert = assert

local oo             = require("loop.simple")

local Framework      = require("jive.ui.Framework")
local Player         = require("jive.slim.Player")

local SlimProto      = require("jive.net.SlimProto")
local Playback       = require("jive.audio.Playback")

local jiveMain       = jiveMain
local debug          = require("jive.utils.debug")
local log            = require("jive.utils.log").logger("squeezebox.player")

local JIVE_VERSION   = jive.JIVE_VERSION

-- can be overridden by hardware specific classes
local DEVICE_ID      = 12
local DEVICE_MODEL   = "squeezeplay"
local DEVICE_NAME    = "SqueezePlay"


module(...)
oo.class(_M, Player)


-- class method to set the device type
function setDeviceType(self, model, name)
	 DEVICE_ID = 9
	 DEVICE_MODEL = model
	 DEVICE_NAME = name or model
end


--class method - disconnect from player and server and re-set "clean (no server)" LocalPlayer as current player (if there is a local player), otherwise set current player to nil
function disconnectServerAndPreserveLocalPlayer(self)
	--disconnect from player and server
	self:setCurrentPlayer(nil)

	--Free server from local player, and re-set current player to LocalPlayer
	local localPlayer = Player:getLocalPlayer()
	if localPlayer then
		localPlayer:disconnectFromServer()
		localPlayer:free(localPlayer:getSlimServer())
		Player:setCurrentPlayer(localPlayer)
	end


end


function getLastSqueezeCenter(self)
	return self.lastSqueezeCenter
end


function setLastSqueezeCenter(self, server)
	log:debug("lastSqueezeCenter set: ", server)

	self.lastSqueezeCenter = server
end


function __init(self, jnt, playerId, uuid)
	local obj = oo.rawnew(self, Player(jnt, playerId))

	obj.slimproto = SlimProto(jnt, {
		opcode = "HELO",
		deviceID = DEVICE_ID,
	       	version = JIVE_VERSION,
		mac = obj.id,
		uuid = uuid,
		model = DEVICE_MODEL,
		modelName = DEVICE_NAME,
	})
	obj.playback = Playback(jnt, obj.slimproto)

	-- initialize with default values
	obj:updateInit(nil, {
		name = DEVICE_NAME,
		model = DEVICE_MODEL,
	})

	return obj
end


function destroy(self, server)
	-- close any previous connection
	if self.slimproto then
		self.slimproto:disconnect()
		self.slimproto = nil
	end

	if self.playback then
		self.playback:stop()
		self.playback = nil
	end

	Player.free(self, server)
end


function playFileInLoop(self, file)
	return self.playback:playFileInLoop(file)
end


function updateInit(self, server, init)
	Player.updateInit(self, server, init)

	if server then
		self:connectToServer(server)
	end
end


function incrementSequenceNumber(self)
	return self.playback:incrementSequenceNumber()
end

function getCurrentSequenceNumber(self)
	return self.playback:getCurrentSequenceNumber()
end

function isSequenceNumberInSync(self, serverSequenceNumber)
	return self.playback:isSequenceNumberInSync(serverSequenceNumber)
end


--resend local values to server
function refreshLocallyMaintainedParameters(self)
	log:info("refreshLocallyMaintainedParameters()")

	--refresh volume
	self:volume(self:getVolume(), true, true)

	--refresh power state
	self:setPower(jiveMain:getSoftPowerState() == "on")

	--todo: pause, mute

end

function isLocal(self)
	return true
end


function needsNetworkConfig(self)
	return false
end


function needsMusicSource(self)
	return not self.slimproto:isConnected()
end


function canConnectToServer(self)
	return true
end


function connectToServer(self, server)
	-- close any previous connection
	self.slimproto:disconnect()

	-- make sure the server we are connecting to is awake
	server:wakeOnLan()

	log:debug("connectToServer: ", server)
	if server then
		server:addLocallyRequestedServer(server)
	
		self.slimproto:connect(server)
	end
end


function disconnectFromServer(self)
	self.slimproto:disconnect()
	self.playback:stop()
end


function getLastSeen(self)
	-- never timeout a local player
	return Framework:getTicks()
end


function isConnected(self)
	return self.slimproto:isConnected()
end


function setSignalStrength(self, signalStrength)
	self.playback:setSignalStrength(signalStrength)
end


function getVolume(self)
	return self.playback:getVolume()
end


-- volume
-- send new volume value to SS, returns a negative value if the player is muted
function volume(self, vol, send)
	self:volumeLocal(vol)
	return Player.volume(self, vol, send, self:incrementSequenceNumber())
end


function volumeLocal(self, vol, updateSequenceNumber)
	--sometime we want to update the sequence number directly, like when there is no server connection and volume is changed
	if updateSequenceNumber then
		self:incrementSequenceNumber()
	end
	self.playback:setVolume(vol)
end



function _pauseOn(self)
	--todo: how to do local pause - maybe do locally as a back on server failure or timeout
	Player._pauseOn(self)
end


function __tostring(self)
	return "LocalPlayer {" .. self:getName() .. "}"
end



--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
