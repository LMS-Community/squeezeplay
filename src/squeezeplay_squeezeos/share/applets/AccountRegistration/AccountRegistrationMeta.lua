
--[[
=head1 NAME

applets.AccountRegistration.AccountRegistrationMeta - AccountRegistration meta-info

=head1 DESCRIPTION

See L<applets.AccountRegistration.AccountRegistrationApplet>.

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


-- HACK: this is bad, but we need to keep the meta in scope for the network
-- subscription to work
local hackMeta = true


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return {
		[ "registerDone" ] = false,
	}
end


function registerApplet(meta)
	meta:registerService("startRegister")
	meta:registerService("waitForSqueezenetwork")
end


function configureApplet(meta)

end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
