
local ipairs, pairs = ipairs, pairs

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local System        = require("jive.System")

local Framework     = require("jive.ui.Framework")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("ui")

local appletManager = appletManager


module(..., Framework.constants)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
end


function registerApplet(meta)
	meta:registerService('debugSkin')
	meta:registerService('debugStyle')
end


function configureApplet(meta)
	local desktop = System:getMachine() == "squeezeplay"

	Framework:addActionListener("debug_skin", meta, function()
		appletManager:callService("debugSkin")

		if not desktop then
			appletManager:callService("debugStyle")
		end
	end)

	if desktop then
		appletManager:callService("debugStyle")
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
