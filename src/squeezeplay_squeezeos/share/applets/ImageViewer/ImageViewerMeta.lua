
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
		jiveMain:addItem(meta:menuItem('appletImageViewer', 'home', "IMAGE_VIEWER", 
			function(applet, ...) applet:startSlideshow(...) end, 100))
end


function configureApplet(self)
	appletManager:callService("addScreenSaver", self:string("IMAGE_VIEWER"), "ImageViewer", 
		"startSlideshow", self:string("IMAGE_VIEWER_SETTINGS"), "openSettings", 90)

end


function defaultSettings(self)
	local defaultSetting = {}
	defaultSetting["delay"] = 10000
	defaultSetting["source"] = "card"
	defaultSetting["rotation" ] = "auto"
	defaultSetting["fullscreen"] = false
	defaultSetting["transition"] = "random"
	defaultSetting["ordering"] = "random"
	defaultSetting["textinfo"] = true

	defaultSetting["card.path"] = "/media"
	defaultSetting["http.path"] = "http://www.web4free.ch/test.txt"
	return defaultSetting
end

--[[

=head1 LICENSE

Copyright 2009 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

