--[[

Player instance for local playback.

--]]

local assert = assert

local oo             = require("loop.simple")

local Framework      = require("jive.ui.Framework")
local Player         = require("jive.slim.Player")

local SlimProto      = require("jive.net.SlimProto")
local Playback       = require("jive.audio.Playback")

local debug          = require("jive.utils.debug")
local log            = require("jive.utils.log").logger("player")


-- can be overridden by hardware specific classes
local DEVICE_MODEL   = "SqueezePlay"


module(...)
oo.class(_M, Player)


local device2id = {
	["Controller"] = 9,
	["SqueezePlay"] = 12,
}

function __init(self, jnt, playerId, uuid)
	local obj = oo.rawnew(self, Player(jnt, playerId))

	local deviceid = device2id[DEVICE_MODEL]
	assert(deviceid)

	obj.slimproto = SlimProto(jnt, {
		opcode = "HELO",
		deviceID = deviceid,
	       	revision = 0,
		mac = obj.id,
		uuid = uuid,
	})
	obj.playback = Playback(jnt, obj.slimproto)

	-- initialize with default values
	obj:updateInit(nil, {
		name = DEVICE_MODEL,
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
		self.playback:free()
		self.playback = nil
	end

	Player.free(self, server)
end


function updateInit(self, server, init)
	Player.updateInit(self, squeezeCenter, init)

	if server then
		self:connectToServer(server)
	end
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

	if server then
		local serverip = server:getIpPort()
		self.slimproto:connect(serverip)
	end
end


function getLastSeen(self)
	-- never timeout a local player
	return Framework:getTicks()
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
