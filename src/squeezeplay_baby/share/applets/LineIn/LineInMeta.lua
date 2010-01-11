
--[[
=head1 NAME

applets.LineIn.LineInMeta

=head1 DESCRIPTION

See L<applets.LineIn.LineInApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")
local locale	    = require("jive.utils.locale")

local AppletMeta    = require("jive.AppletMeta")

local slimServer    = require("jive.slim.SlimServer")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt



module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
end


function registerApplet(meta)
	meta:registerService("addLineInMenuItem")
	meta:registerService("removeLineInMenuItem")
	meta:registerService("activateLineIn")
	meta:registerService("isLineInActive")
	meta:registerService("getLineInNpWindow")

end


function configureApplet(meta)
	appletManager:loadApplet("LineIn")
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
