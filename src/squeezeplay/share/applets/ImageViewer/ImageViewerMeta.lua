
--[[
=head1 NAME

applets.Slideshow.SlideshowMeta - Slideshow meta-info

=head1 DESCRIPTION

See L<applets.Slideshow.SlideshowMeta>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local System           = require("jive.System")
local AppletMeta    = require("jive.AppletMeta")
local lfs           = require("lfs")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
	if System:getMachine() ~= "baby" and System:getMachine() ~= "jive" then
		jiveMain:addItem(meta:menuItem('appletImageViewer', 'settings', "IMAGE_VIEWER", 
			function(applet, ...) applet:openImageViewer(...) end, 58, nil, "hm_appletImageViewer"))
	else
		jiveMain:addItem(meta:menuItem('appletImageViewer', 'screenSettings', "IMAGE_VIEWER_SETTINGS",
			function(applet, ...) applet:openMinimalSettings(...) end, 105, nil, "hm_appletImageViewer"))

	end
	
	meta:registerService("registerRemoteScreensaver")
	meta:registerService("unregisterRemoteScreensaver")
	meta:registerService("openRemoteScreensaver")
end


function configureApplet(self)
	if System:getMachine() ~= "baby" and System:getMachine() ~= "jive" then
		appletManager:callService("addScreenSaver", self:string("IMAGE_VIEWER"), "ImageViewer",
			"startSlideshow", self:string("IMAGE_VIEWER_SETTINGS"), "openSettings", 90)
	end
end


function defaultSettings(self)
	local defaultSetting = {}
	defaultSetting["delay"] = 10000
	defaultSetting["source"] = "card"
	defaultSetting["rotation" ] = "auto"
	defaultSetting["fullscreen"] = false
	defaultSetting["transition"] = "fade"
	defaultSetting["ordering"] = "random"
	defaultSetting["textinfo"] = false

	defaultSetting["card.path"] = "/media"
	defaultSetting["http.path"] = "http://www.herger.net/sbtouch.lst"
	return defaultSetting
end

--[[

=head1 LICENSE

Copyright 2009 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

