local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local jul           = require("jive.utils.log")
local log           = require("jive.utils.log").logger("applets.setup")
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
	-- check for SN PIN when we connect to a new player
	local monitor = {
		notify_playerCurrent =
			function(self, player)

				if player and player:getPin() then
					log:debug("SqueezeNetworkPIN: player has a PIN")
					local applet = appletManager:loadApplet("SqueezeNetworkPIN")		
					applet:forcePin(player)
				end
			end
	}

	jnt:subscribe(monitor)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

