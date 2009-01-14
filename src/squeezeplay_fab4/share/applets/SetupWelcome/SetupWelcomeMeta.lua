
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

local startingStep = 'step1'

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
	meta:registerService(startingStep)
	-- for development, add a menu item for this
	jiveMain:addItem(meta:menuItem('appletSetupWelcome', 'home', "SETUP_DEVELOPMENT", function(applet, ...) applet:step1(...) end, 100))

end

function configureApplet(meta)
--[[ DISABLE UNTIL COMPLETE
	if not meta:getSettings().setupDone then
		appletManager:callService(startingStep)
	end
--]]
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
