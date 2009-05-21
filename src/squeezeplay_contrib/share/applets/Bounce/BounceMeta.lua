
--[[
=head1 NAME

applets.Bounce.BounceMeta - Bounce meta-info

=head1 DESCRIPTION

See L<applets.Bounce.BounceApplet>.

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


function jiveVersion(self)
	return 1, 1
end

function registerApplet(self)
end

function configureApplet(self)
	appletManager:callService("addScreenSaver", self:string("SCREENSAVER_BOUNCE"), "Bounce",
"bounce", _, _, 90)
end

--[[

=head1 LICENSE

This source code is public domain. It is intended for you to use as a starting
point to create your own applet.

=cut
--]]

