local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end

function defaultSettings(self)
	return {
	}
end

function registerApplet(self)

end

function configureApplet(self)
	-- snooze is a resident applet
	appletManager:loadApplet("AlarmSnooze")

	-- following lineonly used for testing
	--jiveMain:addItem(self:menuItem('appletAlarmSnooze', 'home', "ALARM_SNOOZE_SNOOZE", function(applet, ...) applet:openAlarmWindow(...) end, 1))

end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
