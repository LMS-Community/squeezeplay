
local assert, getmetatable = assert, getmetatable

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local debug         = require("jive.utils.debug")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function registerApplet(meta)
end


function configureApplet(meta)
	local localPlayer = nil
	for mac, player in appletManager:callService("iteratePlayers") do
		if player:isLocal() then
			localPlayer = player
			break
		end
        end

	if not localPlayer then
		return
	end

	jiveMain:addItem(meta:menuItem('factoryTones', 'factoryTest', "TEST_TONES", function(applet, ...) applet:testTonesShow() end))
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

