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

-- don't do anything in the svn checkin until complete
--	appletManager:loadApplet("AlarmSnooze")
--	jiveMain:addItem(self:menuItem('appletAlarmSnooze', 'home', "ALARM_SNOOZE_SNOOZE", function(applet, ...) applet:openAlarmWindow(...) end, 1))

end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
