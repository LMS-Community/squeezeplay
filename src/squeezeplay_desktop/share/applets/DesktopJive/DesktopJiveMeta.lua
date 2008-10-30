
local oo            = require("loop.simple")
local io            = require("io")
local math          = require("math")
local string        = require("string")
local table         = require("jive.utils.table")

local AppletMeta    = require("jive.AppletMeta")

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
		local f = io.popen("ifconfig")
		if f then
			local ifconfig = f:read("*a")
			f:close()

			store = true
			settings.mac = string.match(ifconfig, "HWaddr%s([%x:]+)")
		end
	end

	if not settings.mac then
		local f = io.popen("ipconfig /all")
		if f then
			local ipconfig = f:read("*a")
			f:close()

			store = true
			local mac = string.match(ipconfig, "Physical Address[ %.%-]-:%s([%x%-]+)")

			if mac then
				settings.mac = string.gsub(mac, "%-", ":")
			end
		end
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

	if store then
		meta:storeSettings()
	end

	-- set uuid
	jnt:setUUID(settings.uuid, settings.mac)
	
	jiveMain:setDefaultSkin("FullscreenSkin")
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

