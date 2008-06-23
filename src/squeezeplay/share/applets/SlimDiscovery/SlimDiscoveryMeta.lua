
--[[
=head1 NAME

applets.SlimDiscovery.SlimDiscoveryMeta - SlimDiscovery meta-info

=head1 DESCRIPTION

See L<applets.SlimDiscovery.SlimDiscoveryApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local Player        = require("jive.slim.Player")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("applets.setup")

local appletManager = appletManager
local jnt = jnt


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return {
		currentPlayer = false
	}
end


function registerApplet(meta)
	local settings = meta:getSettings()


	meta:registerService("getCurrentPlayer")
	meta:registerService("setCurrentPlayer")

	meta:registerService("discoverPlayers")

	meta:registerService("connectPlayer")
	meta:registerService("disconnectPlayer")

	meta:registerService("iteratePlayers")
	meta:registerService("iterateSqueezeCenters")
	meta:registerService("countPlayers")

	meta:registerService("getPollList")
	meta:registerService("setPollList")


	-- SlimDiscovery is a resident Applet
	local slimDiscovery = appletManager:loadApplet("SlimDiscovery")

	-- Set current player
	if settings.currentPlayer then
		slimDiscovery:setCurrentPlayer(Player(jnt, settings.currentPlayer))
	end

	-- With the MP firmware when SqueezeNetwork is selected a dummy player with an ff mac
	-- address is selected, and then a firmware update starts. When this mac address is seen 
	-- after the upgrade we need to push the choose player and squeezenetwork pin menus
	if settings.currentPlayer == "ff:ff:ff:ff:ff:ff" then
		log:info("SqueezeNetwork dummy player found")

		-- change to a non-existant player to prevent browser connecting
		settings.currentPlayer = "ff:ff:ff:ff:ff:fe"

		-- wait until SN is connected so we know the PIN
		jnt:subscribe(meta)
	end
end


function notify_playerNew(meta, player)
	if player:getId() ~= "ff:ff:ff:ff:ff:ff" then
		return
	end

	-- unsubscribe monitor from future events
	jnt:unsubscribe(meta)

	-- push Choose Player menu
	local selectPlayer = appletManager:loadApplet("SelectPlayer")
	if selectPlayer then
		selectPlayer:setupShow(function() end)
	end

	-- push Active Squeezenetwork
	local snPin = appletManager:loadApplet("SqueezeNetworkPIN")
	if snPin then
		snPin:forcePin(player)
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
