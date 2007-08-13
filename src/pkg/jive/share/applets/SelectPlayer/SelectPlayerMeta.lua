
--[[
=head1 NAME

applets.SelectPlayer.SelectPlayerMeta - SelectPlayer meta-info

=head1 DESCRIPTION

See L<applets.SelectPlayer.SelectPlayer>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)

function defaultSettings(meta)
	return {
		selectedPlayer = '00:00:00:00:00:00',
		selectedServer = 'no_server_selected',
	}
end

function jiveVersion(meta)
	return 0.1, 0.1
end


function registerApplet(meta)
	
	-- add ourselves to the main menu
	--[[ comment this until it's functional
	jiveMain:addItem(meta:menuItem(meta:string("SELECT_PLAYER"), function(applet, ...) applet:getPlayers(...) end), 900)
	--]]
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
