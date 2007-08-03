
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
	return 0.1, 0.1
end


function registerApplet(self)

	-- Flickr implements a screensaver
	local ssMgr = appletManager:load("ScreenSavers")

	if ssMgr ~= nil then
		-- Flickr uses its own log category
		-- defined here so that it can be changed using LogSettingsApplet before the applet is run.		
		jul.addCategory("screensaver.flickr", jul.DEBUG)

		-- second string translation should be SCREENSAVER_FLICKR_SETTINGS, but that isn't translated yet
		-- ssMgr:addScreenSaver(self:string("SCREENSAVER_FLICKR"), "Flickr", "openScreensaver", self:string("SCREENSAVER_FLICKR"), "openSettings")
		ssMgr:addScreenSaver(self:string("SCREENSAVER_FLICKR"), "Flickr", "openScreensaver", self:string("SCREENSAVER_FLICKR"), "openSettings")

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
