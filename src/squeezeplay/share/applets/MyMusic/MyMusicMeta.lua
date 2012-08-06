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
	-- MyMusic is a resident applet
	appletManager:loadApplet("MyMusic")

	-- add a menu item for myMusic
	jiveMain:addItem(self:menuItem('myMusicSelector', 'home', 'MYMUSIC_MY_MUSIC', function(applet, ...) applet:myMusicSelector(...) end, 95, nil, "hm_myMusicSelector"))
end


--[[

=head1 LICENSE

Copyright 2012 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

