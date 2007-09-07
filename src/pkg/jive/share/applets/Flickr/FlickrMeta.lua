
--[[
=head1 NAME

applets.Flickr.FlickrMeta - Flickr meta-info

=head1 DESCRIPTION

See L<applets.Flickr.FlickrApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local jul           = require("jive.utils.log")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function defaultSettings(self)
	local defaultSetting = {}
	defaultSetting["flickr.timeout"] = 30000
	defaultSetting["flickr.display"] = "interesting"
	defaultSetting["flickr.id"] = "Your ID"
	defaultSetting["flickr.transition"] = "random"
	return defaultSetting
end


function registerApplet(self)

	-- Flickr implements a screensaver
	local ssMgr = appletManager:loadApplet("ScreenSavers")

	if ssMgr ~= nil then
		ssMgr:addScreenSaver(self:string("SCREENSAVER_FLICKR"), "Flickr", 
"openScreensaver", self:string("SCREENSAVER_FLICKR_SETTINGS"), "openSettings")

		-- load our skin
		jiveMain:loadSkin("Flickr", "skin")
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
