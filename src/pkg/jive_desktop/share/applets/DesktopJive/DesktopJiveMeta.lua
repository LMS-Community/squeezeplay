
local oo            = require("loop.simple")
local math          = require("math")
local string        = require("string")
local table         = require("jive.utils.table")

local AppletMeta    = require("jive.AppletMeta")

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
		uuid = false
	}
end


function registerApplet(meta)
	local settings = meta:getSettings()

	if not settings.uuid then
		local uuid = {}
		for i = 1,16 do
			uuid[#uuid + 1] = string.format('%02x', math.random(255))
		end

		settings.uuid = table.concat(uuid)
		meta:storeSettings()
	end

	-- set uuid
	jnt:setUUID(settings.uuid)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

