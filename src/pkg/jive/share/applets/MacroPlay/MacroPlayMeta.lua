
--[[
=head1 NAME

applets.AutoFWUpdate.AutoFWUpdateMeta - AutoFWUpdate meta-info

=head1 DESCRIPTION

See L<applets.AutoFWUpdate.AutoFWUpdateApplet>.

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


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
end


function registerApplet(meta)
	-- menu item to start
	jiveMain:addItem(meta:menuItem('macroPlay', 'advancedSettings', 'MACRO_PLAY', function(applet, ...) applet:play(...) end))
end

