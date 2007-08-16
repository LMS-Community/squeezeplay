
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
	obj.serversObj = SlimServers(jnt)

	-- arrange so that discover is called when in home
	jiveMain:addInHomeListener(
		function()
			obj.serversObj:discover()
		end
	)
	
	return obj
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
-- this iterator respects the implementation privacy of the SlimServers and SlimServer
-- classes. It only uses the fact allServers and allPlayers calls respect the for
-- generator logic of Lua.
local function _playerIterator(invariant)
	while true do
	
		-- if no current player, load next server
		-- NB: true first time
		if not invariant.pk then
			invariant.sk, invariant.sv = invariant.sf(invariant.si, invariant.sk)
			invariant.pk = nil
			if invariant.sv then
				invariant.pf, invariant.pi, invariant.pk = invariant.sv:allPlayers()
			end
		end
	
		-- if we have a server, use it to get players
		if invariant.sv then
			-- get the next/first player, depending on pk
			local pv
			invariant.pk, pv = invariant.pf(invariant.pi, invariant.pk)
			if invariant.pk then
				return invariant.pk, pv
			end
		else
			-- no further servers, we're done
			return nil
		end
	end
end

function allPlayers(self)
	local i = {}
	i.sf, i.si, i.sk = self:allServers()
	return _playerIterator, i
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

=head2 applets.SlimDiscovery.SlimDiscoveryApplet:setCurrentPlayer()

Sets the current player

=cut
--]]
function setCurrentPlayer(self, player)
	self.currentPlayer = player
	jnt:notify("playerCurrent", player)
end


--[[

=head2 applets.SlimDiscovery.SlimDiscoveryApplet:getCurrentPlayer()

Returns the current player

=cut
--]]
function getCurrentPlayer(self)
	return self.currentPlayer
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

	-- add the player to the main menu if it is not there already
	if not player:getHomeMenuItem() then

		local menuItem = {
			text = player:getName(),
			callback = function(_, menuItem)
					appletManager:loadApplet("SlimBrowser"):openPlayer(menuItem, player)
				   end
		}


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

