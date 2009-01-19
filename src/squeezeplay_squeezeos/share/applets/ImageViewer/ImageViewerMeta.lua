
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
        -- only make this available if an SD card is slotted in and
        -- a /media/*/images directory is present
        local media = false
        for dir in lfs.dir("/media") do
                if lfs.attributes("/media/" .. dir .. "/images", "mode") == "directory" then
                        media = true
			jiveMain:addItem(meta:menuItem('appletImageViewer', 'home', "IMAGE_VIEWER", function(applet, ...) applet:startSlideshow(...) end, 100))
                        break
                end
        end
end


--[[

=head1 LICENSE

Copyright 2009 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

