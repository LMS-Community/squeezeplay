
--[[
=head1 NAME

applets.ChooseMusicSource.ChooseMusicSourceMeta

=head1 DESCRIPTION

See L<applets.ChooseMusicSource.ChooseMusicSourceApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local log           = require("jive.utils.log").logger("applets.setup")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt
local _player       = false

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return {
		poll = { ["255.255.255.255"] = "255.255.255.255" }
	}
end


function registerApplet(meta)

	meta:registerService("selectMusicSource")

	-- set the poll list for discovery of slimservers based on our settings
	if appletManager:hasService("setPollList") then
		appletManager:callService("setPollList", meta:getSettings().poll)
		jiveMain:addItem(
			meta:menuItem(
				'appletSlimservers', 
				'settings', 
				"SLIMSERVER_SERVERS", 
				function(applet, ...) 
					applet:settingsShow(...) 
				end, 
				60
			)
		)

	end

	jnt:subscribe(meta)

end

function notify_playerCurrent(meta, player)
	if player == nil then
		jiveMain:removeItemById('appletSlimservers')
	else
		jiveMain:addItem(
			meta:menuItem(
				'appletSlimservers', 
				'settings', 
				"SLIMSERVER_SERVERS", 
				function(applet, ...) 
					applet:settingsShow(...) 
				end, 
				60
			)
		)
	end
	_player = player
end

function notify_playerDelete(self, player)
	if player == _player then
		jiveMain:removeItemById('appletSlimservers')
	end
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

