
local oo            = require("loop.simple")
local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt = jnt


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(self)
	return {
		currentSN = nil
	}
end


function registerApplet(meta)
	meta:registerService("fetchConfigServerData")
	meta:registerService("checkRequiredFirmwareUpgrade")
end


--[[

=head1 LICENSE

Copyright 2012 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

