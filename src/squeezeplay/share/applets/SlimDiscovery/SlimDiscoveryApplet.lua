
--[[
=head1 NAME

applets.SlimDiscovery.SlimDiscoveryApplet - Discover Slimservers on the network

=head1 DESCRIPTION

This applet uses the L<jive.slim.SlimServers> class to discover Slimservers on the network
using the SqueezeBox discovery protocol. Slimservers are then queried to retrieve available
music players.
This applet provides the plumbing as well an API to access the discovered servers and players,
including a notification to inform of a change in the "current" player.


Notifications:

 playerCurrent


=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
QuitApplet does not override any jive.Applet method.

=cut
--]]


-- stuff we use
local oo            = require("loop.simple")

local Applet        = require("jive.Applet")
local SlimServers   = require("jive.slim.SlimServers")

local log           = require("jive.utils.log").logger("applets.setup")

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(...)
oo.class(_M, Applet)


-- FIXME: this class does not really do much now, it should be written out!


-- init
-- Initializes the applet
function __init(self, ...)

	-- init superclass
	local obj = oo.rawnew(self, Applet(...))

	-- subscribe to the jnt so that we get notifications of players added/removed
	jnt:subscribe(obj)

	-- create a list of SlimServers
	obj.serversObj = SlimServers(jnt)

	return obj
end


--[[

=head2 applets.SlimDiscovery.SlimDiscoveryApplet:discover()

Send a discovery packet over the network looking for slimservers and players.

=cut
--]]
function discover(self)
	self.serversObj:discover()
end


--[[

=head2 applets.SlimDiscovery.SlimDiscoveryApplet:allServers()

Returns an iterator over the discovered slimservers.
Proxy for L<jive.slim.SlimServers:allServers>

 for _, server in allServers() do
    ...
 end

=cut
--]]
function allServers(self)
	return self.serversObj:allServers()
end


--[[

=head2 applets.SlimDiscovery.SlimDiscoveryApplet:allPlayers()

Returns an iterator over the discovered players.

 for id, player in allPlayers() do
    ...
 end

=cut
--]]
function allPlayers(self)
	return self.serversObj:allPlayers()
end


--[[

=head2 applets.SlimDiscovery.SlimDiscoveryApplet:countPlayers()

Returns the number of discovered players.

=cut
--]]
function countPlayers(self)
	local count = 0
	for i, _ in self:allPlayers() do
		count = count + 1
	end
	return count
end


--[[

=head2 applets.SlimDiscovery.SlimDiscoveryApplet:countPlayers()

Returns the number of connected players.

=cut
--]]
function countConnectedPlayers(self)
	local count = 0
	for i, player in self:allPlayers() do
		if player:isConnected() then
			count = count + 1
		end
	end
	return count
end


--[[

=head2 applets.SlimDiscovery.SlimDiscoveryApplet:setCurrentPlayer()

Sets the current player

=cut
--]]
function setCurrentPlayer(self, player)
	local settings = self:getSettings()

	if player and settings.currentPlayer ~= player then
		settings.currentPlayer = player and player.id or false
		self:storeSettings()
	end

	self.serversObj:setCurrentPlayer(player)
end


--[[

=head2 applets.SlimDiscovery.SlimDiscoveryApplet:getCurrentPlayer()

Returns the current player

=cut
--]]
function getCurrentPlayer(self)
	return self.serversObj:getCurrentPlayer()
end


--[[

=head2 applets.SlimDiscovery.SlimDiscoveryApplet:pollList()

Get/set the list of addresses which are polled with discovery packets.
Proxy for L<jive.slim.SlimServers:pollList>

=cut
--]]
function pollList(self, list)
	return self.serversObj:pollList(list)
end


-- notify_playerNew
-- this is called by jnt when the playerNew message is sent
function notify_playerNew(self, player)
	if not self:getCurrentPlayer() then
		local settings = self:getSettings()

		if settings.currentPlayer == player.id then
			self:setCurrentPlayer(player)
		end
	end
end


-- notify_playerDelete
-- this is called by jnt when the playerDelete message is sent
function notify_playerDelete(self, player)
	if self:getCurrentPlayer() == player then
		self:setCurrentPlayer(nil)
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

