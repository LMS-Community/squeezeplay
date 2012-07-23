
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

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
	
	jiveMain:addItem(meta:menuItem('appletTest', 'home', "TEST", function(applet, ...) applet:menu(...) end, 900))

end


--[[

=head1 LICENSE

This source code is public domain. It is intended for you to use as a starting
point to create your own applet.

=cut
--]]

