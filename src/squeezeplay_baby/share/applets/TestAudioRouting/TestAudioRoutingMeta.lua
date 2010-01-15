local oo            = require("loop.simple")

local Framework     = require("jive.ui.Framework")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
	jiveMain:addItem(meta:menuItem('audioRouting', 'factoryTest', "TEST_AUDIO_ROUTING", function(applet, ...) applet:audioRoutingMenu(...) end, _, { noCustom = 1}))

	Framework:addActionListener("go_test_audio_routing", self, _goTestAudioRouting, 9999)
end

function _goTestAudioRouting(self)
	local key = "audioRouting"

	if jiveMain:getMenuTable()[key] then
		Framework:playSound("JUMP")
		jiveMain:getMenuTable()[key].callback()
	end

	return EVENT_CONSUME
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]


