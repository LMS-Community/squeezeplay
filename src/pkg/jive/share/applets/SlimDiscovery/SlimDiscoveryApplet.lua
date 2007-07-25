
--[[
=head1 NAME

applets.SlimDiscovery.SlimDiscoveryApplet - Discover Slimservers on the network

=head1 DESCRIPTION

This applet uses the L<jive.slim.SlimServers> class to discover Slimservers on the network
using the SqueezeBox discovery protocol. Slimservers are then queried to retrieve available
music players.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
QuitApplet does not override any jive.Applet method.

=cut
--]]


-- stuff we use
local oo            = require("loop.simple")

local Applet        = require("jive.Applet")
local SlimServers   = require("jive.slim.SlimServers")

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(...)
oo.class(_M, Applet)


-- FIXME: freeing this should free all the jive.slim.* stuff!

-- init
-- Initializes the applet
function __init(self, ...)

	-- init superclass
	local obj = oo.rawnew(self, Applet(...))

	-- subscribe to the jnt so that we get notifications of players added/removed
	jnt:subscribe(obj)

	-- create a list of SlimServers
	obj.servers = SlimServers(jnt)

	-- arrange so that discover is called when in home
	jiveMain:addInHomeListener(
		function()
			obj.servers:discover()
		end
	)
	
	return obj
end


-- getSlimServers
-- returns the slimServers object
function getSlimServers(self)
	return self.servers
end


-- notify_playerNew
-- this is called by jnt when the playerNew message is sent
function notify_playerNew(self, player)

	-- add the player to the main menu if it is not there already
	if not player:getHomeMenuItem() then

		local menuItem = appletManager:menuItem(player:getName(), "SlimBrowser", "openPlayer", player)

		jiveMain:addItem(menuItem, 100)

		player:setHomeMenuItem(menuItem)
	end
end


-- notify_playerDelete
-- this is called by jnt when the playerDelete message is sent
function notify_playerDelete(self, player)

	-- remove the player from the menu if it has one
	local menuItem = player:getHomeMenuItem()
	if menuItem then
	
		jiveMain:removeItem(menuItem)
		player:setHomeMenuItem(nil)
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

