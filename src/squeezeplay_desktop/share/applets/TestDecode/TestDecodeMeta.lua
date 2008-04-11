
--[[
=head1 NAME

applets.Test.TestMeta - Test meta-info

=head1 DESCRIPTION

See L<applets.Test.TestApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local SlimProto     = require("jive.net.SlimProto")
local Playback      = require("jive.audio.Playback")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("test")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
	-- resident applet
	appletManager:loadApplet("TestDecode")


	jiveMain:addItem(meta:menuItem('decodeTest', 'home', "TEST_DECODE", function(applet, ...) applet:menu(...) end, 1))


--	local ip = "127.0.0.1"
	local ip = "10.1.1.10"

	local sp = SlimProto(jnt, ip, {
				     opcode = "HELO",
				     deviceID = "4",
				     revision = "0",
			     })
	Playback(jnt, sp)
	sp:connect()	
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

