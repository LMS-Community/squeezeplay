
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

local log              = require("jive.utils.log").logger("applets.setup")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return {
		[ "setupDone" ] = false,
		[ "registerDone" ] = false,
	}
end


function registerApplet(meta)
	meta:registerService("startSetup")
	meta:registerService("startRegister")
end


function configureApplet(meta)
	local settings = meta:getSettings()

	if not settings.setupDone then
		appletManager:callService("startSetup")
	elseif not settings.registerDone then
		appletManager:callService("startRegister")
	end

	if not settings.registerDone then
		jnt:subscribe(meta)
	end
end


function notify_serverLinked(meta, server)
	log:info("server linked: ", server)

	local settings = meta:getSettings()
	settings.registerDone = (server:getPin() == nil)
	self:storeSettings()

	if settings.registerDone then
		jnt:subscribe(meta)
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
