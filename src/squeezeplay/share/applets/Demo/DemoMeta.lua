
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
	meta:registerService("jumpToInStoreDemo")

	-- uncomment this when wanting to test from desktop SP
	-- jiveMain:addItem(meta:menuItem('appletDemo', 'settings', "DEMO", function(applet, ...) applet:enableDemo() end))

end

function defaultSettings(meta)
        return { 
		startDemo = false,
	}
end

function configureApplet(meta)

	if meta:getSettings()['startDemo'] then
		local demo = appletManager:loadApplet('Demo')
	        demo:startDemo()
	end

end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

