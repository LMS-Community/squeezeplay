
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
		[ "setupDone" ] = false,
		[ "registerDone" ] = false,
	}
end


function registerApplet(meta)
	meta:registerService("startSetup")
	meta:registerService("startRegister")
	meta:registerService("isSetupDone")
end


function configureApplet(meta)
	local settings = meta:getSettings()

	if not settings.setupDone then
		appletManager:callService("startSetup")
	end

	if not settings.registerDone then
		hackMeta = meta
		jnt:subscribe(meta)
	end
end


function notify_serverNew(meta, server)
	local settings = meta:getSettings()

	if settings.setupDone and server:isSqueezeNetwork() then
		appletManager:callService("startRegister")

		jnt:unsubscribe(meta)
		hackMeta = nil
	end
end


--[[
function notify_serverLinked(meta, server)
	if not server:isSqueezeNetwork() then
		return
	end

	log:info("server linked: ", server, " pin=", server:getPin())

	local settings = meta:getSettings()
	if server:getPin() == false then
		settings.registerDone = true
		meta:storeSettings()
	end

	if settings.registerDone then

		-- for testing connect the player tosqueezenetwork
		local player = appletManager:callService("getCurrentPlayer")
		log:info(player, " is conencted to ", player and player:getSlimServer())

		if player and not player:getSlimServer() then
			local squeezenetwork = false
			for name, server in slimServer:iterate() do
				if server:isSqueezeNetwork() then
					squeezenetwork = server
				end
			end

			log:info("connecting ", player, " to ", squeezenetwork)
			player:connectToServer(squeezenetwork)
		end

		jnt:unsubscribe(meta)
		hackMeta = nil
	end
end
--]]


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
