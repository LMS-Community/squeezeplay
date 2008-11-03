
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
	defaultSetting["flickr.idstring" ] = ""
	defaultSetting["flickr.id"] = ""
	defaultSetting["flickr.transition"] = "random"
	return defaultSetting
end


function registerApplet(self)
end

function configureApplet(self)

	appletManager:callService("addScreenSaver", self:string("SCREENSAVER_FLICKR"), "Flickr", 
"openScreensaver", self:string("SCREENSAVER_FLICKR_SETTINGS"), "openSettings", 90)

end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
