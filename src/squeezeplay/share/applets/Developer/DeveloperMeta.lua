
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
	meta:registerService("developerModeSwitch")
	jiveMain:addItem(meta:menuItem('appletDeveloperExit', 'developerSettings', "EXIT_DEVELOPER_MODE", function(applet, ...) applet:settingsShow(...) end, 150))
	jiveMain:addItem(meta:menuItem('appletEnableStrTrace', 'developerSettings', "STR_TRACE", function(applet, ...) applet:enableLocalStrIdentifier(...) end, 110))
end

function defaultSettings(meta)
        return {
		developerMode = false,
	}
end

function configureApplet(meta)
	if meta:getSettings()['developerMode'] == true then
		local developer = appletManager:loadApplet('Developer')
		developer:loadDeveloperMenu()
	end
end


--[[

=head1 LICENSE

Copyright 2012 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
