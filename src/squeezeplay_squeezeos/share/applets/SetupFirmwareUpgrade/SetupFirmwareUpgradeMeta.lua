
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local log           = require("jive.utils.log").logger("applets.setup")
local debug         = require("jive.utils.debug")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt

-- naughty polluting global table, but I don't want to store this
-- in the applet settings as this value does not need to be persisted
upgradeUrl          = { false }
local upgradeUrl    = upgradeUrl


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
	jiveMain:addItem(meta:menuItem('appletSetupFirmwareUpgrade', 'advancedSettings', "UPDATE", function(applet) applet:settingsShow() end))

	meta:registerService("forceUpgrade")

	-- check for firmware upgrades when we connect to a new player
	-- we don't want the firmware upgrade applets always loaded so
	-- do this in the meta class
	jnt:subscribe(meta)
end


function notify_playerCurrent(meta, player)
	local server = player:getSlimServer()

	if not server then
		return
	end

	local url, force = server:getUpgradeUrl()
	upgradeUrl[1] = url

	if force then
		log:info("Firmware upgrade")
		appletManager:callService("forceUpgrade", force, url)
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

