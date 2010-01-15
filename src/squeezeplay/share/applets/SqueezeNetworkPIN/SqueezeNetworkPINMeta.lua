local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local debug         = require("jive.utils.debug")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt

module(...)
oo.class(_M, AppletMeta)

function jiveVersion(meta)
	return 1, 1
end

function registerApplet(meta)

	meta:registerService("enterPin")
	meta:registerService("forcePin")

	-- check for SN PIN when we connect to a new player
	-- this is needed after upgrading from the MP firmware if 
	-- SqueezeNetwork was selected during Ray setup
	jnt:subscribe(meta)
end


function notify_playerCurrent(self, player)
	if player and player:getPin() then
		log:debug("SqueezeNetworkPIN: player has a PIN")
		appletManager:callService("forcePin", player)
	end
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

