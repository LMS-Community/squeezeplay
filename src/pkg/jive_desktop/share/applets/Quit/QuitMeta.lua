
--[[
=head1 NAME

applets.Quit.QuitMeta - Quit meta-info

=head1 DESCRIPTION

See L<applets.Quit.QuitApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain

local EVENT_CONSUME = jive.ui.EVENT_CONSUME
local EVENT_QUIT    = jive.ui.EVENT_QUIT


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function registerApplet(self)
	-- add ourselves to the end of the main menu
	jiveMain:addItem({
		id = 'appletQuit',
		node = 'home',
		text = self:string("QUIT"),
		callback = function() 
			return (EVENT_CONSUME | EVENT_QUIT)
		end,
		weight = 1000,
	})
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
