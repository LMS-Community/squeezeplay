
--[[
=head1 NAME

applets.SetupWelcome.SetupWelcomeMeta - SetupWelcome meta-info

=head1 DESCRIPTION

See L<applets.SetupWelcome.SetupWelcomeApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")
local locale	    = require("jive.utils.locale")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return {
		[ "setupDone" ] = false
	}
end


function registerApplet(meta)
	if meta:getSettings().setupDone then
		-- if setup is completed, remove Return to Setup from JiveMain
		jiveMain:removeItemByText(meta:string("RETURN_TO_SETUP"))
	else
		-- if setup is not completed, put Return to Setup at the top
		jiveMain:addItem({
			text = meta:string("RETURN_TO_SETUP"),
			callback = function()
				appletManager:loadApplet("SetupWelcome"):step1()
			end,
			weight = 2,
		})
		appletManager:loadApplet("SetupWelcome"):step1()	
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
