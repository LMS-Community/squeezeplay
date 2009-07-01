
local assert, getmetatable = assert, getmetatable

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local debug         = require("jive.utils.debug")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function registerApplet(meta)
	meta:registerService("jumpToInStoreDemo")
end

function defaultSettings(meta)
        return { 
		startDemo = false,
	}
end

function configureApplet(meta)
	local localPlayer = nil
	for mac, player in appletManager:callService("iteratePlayers") do
		if player:isLocal() then
			localPlayer = player
			break
		end
        end

	if not localPlayer then
		return
	end

	if meta:getSettings()['startDemo'] then
		local demo = appletManager:loadApplet('Demo')
	        demo:startDemo()
	end

	jiveMain:addItem(meta:menuItem('appletDemo', 'factoryTest', "DEMO", function(applet, ...) applet:enableDemo() end))
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

