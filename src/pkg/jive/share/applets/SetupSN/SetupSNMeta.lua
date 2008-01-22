
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local jul           = require("jive.utils.log")

local appletManager = appletManager
local jiveMain      = jiveMain

local jnt           = jnt
local pairs         = pairs

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end

function defaultSettings(meta)
	return {
		use_sn_beta = false,
	}
end

function registerApplet(meta)

	local settings = meta:getSettings()
	for k,v in pairs(settings) do
		if k == "use_sn_beta" then
			jnt:setSNBeta(v)
			if(v) then
				jiveMain:addItem({
					id = 'snBetaIndicator',
					node = 'home',
					text = "* SN BETA *",
					weight = 100,
					titleStyle = 'settings'
				})
			end
		end
	end

	jiveMain:addItem(meta:menuItem('appletSetupSN', 'advancedSettings', "ADVSET_SQUEEZENETWORK", function(applet, ...) applet:settingsShow(...) end))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

