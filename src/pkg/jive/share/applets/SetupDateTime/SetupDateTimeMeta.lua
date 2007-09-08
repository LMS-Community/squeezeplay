
--[[
=head1 NAME

applets.SetupDateTime.SetupDateTimeMeta - SetupDateTime meta-info

=head1 DESCRIPTION

See L<applets.SetupDateTime.SetupDateTimeApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")
local locale	    = require("jive.utils.locale")
local datetime      = require("jive.utils.datetime")

local AppletMeta    = require("jive.AppletMeta")
local log              = require("jive.utils.log").logger("applets.setup")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return {
		weekstart = "Sunday",
		dateformat = "%a, %B %d %Y",
		hours = "12",
	}
end

function initDateTimeObject(meta)
	local dt = datetime
	dt:setWeekstart(meta:getSettings()["weekstart"])
	dt:setDateFormat(meta:getSettings()["dateformat"])
	dt:setHours(meta:getSettings()["hours"])
end

function registerApplet(meta)

	-- Init Date Time Object for later use
	initDateTimeObject(meta)

        -- Menu for configuration
        jiveMain:subMenu(meta:string("SETTINGS")):subMenu(meta:string("REMOTE_SETTINGS")):addItem(
		meta:menuItem("DATETIME_TITLE", function(applet, ...) applet:settingsShow(...) end)
	)
end



--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--
--]]
