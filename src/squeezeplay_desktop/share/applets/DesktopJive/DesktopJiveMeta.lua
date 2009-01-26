
local oo            = require("loop.simple")
local io            = require("io")
local math          = require("math")
local string        = require("string")
local table         = require("jive.utils.table")

local AppletMeta    = require("jive.AppletMeta")
local LocalPlayer   = require("jive.slim.LocalPlayer")
local Framework     = require("jive.ui.Framework")
local System        = require("jive.System")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt

local log         = require("jive.utils.log").logger("applets.setup")


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return { 
		uuid = false
	}
end


function registerApplet(meta)
	--disable arp to avoid os calls, which is problematic on windows - popups, vista permissions -  disabling disables WOL functionality
	jnt:setArpEnabled(false)


	local settings = meta:getSettings()

	local store = false

	if not settings.uuid then
		store = true

		local uuid = {}
		for i = 1,16 do
			uuid[#uuid + 1] = string.format('%02x', math.random(255))
		end

		settings.uuid = table.concat(uuid)
	end

	if not settings.mac then
		settings.mac = System:getMacAddress()
		store = true
	end

	if not settings.mac then
		-- random fallback
		mac = {}
		for i = 1,6 do
			mac[#mac + 1] = string.format('%02x', math.random(255))
		end

		store = true
		settings.mac = table.concat(mac, ":")
	end

	-- Set player device type
	--LocalPlayer:setDeviceType("controller", "Controller")

	settings.mac = "00:04:20:ff:ff:10"

	if store then
		log:debug("Mac Address: ", settings.mac)
		meta:storeSettings()
	end

	-- set mac address and uuid
	System:init({
		macAddress = settings.mac,
		uuid = settings.uuid,
	})

	
	appletManager:addDefaultSetting("ScreenSavers", "whenStopped", "false:false")
	appletManager:addDefaultSetting("Playback", "enableAudio", 1)

	jiveMain:setDefaultSkin("FullscreenSkin")
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

