
--[[
=head1 NAME

applets.Snake.SnakeMeta - Snake meta-info

=head1 DESCRIPTION

See L<applets.Snake.SnakeApplet>.

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
	jiveMain:addItem(self:menuItem('snake', 'games', "Snake", function(applet, ...) applet:openWindow(...) end))
end


--[[

=head1 LICENSE

Copyright 2007 Lukas Frey

=cut
--]]

