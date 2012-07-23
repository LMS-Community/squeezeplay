
local ipairs, pairs = ipairs, pairs

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local System        = require("jive.System")

local Framework     = require("jive.ui.Framework")

local debug         = require("jive.utils.debug")

local appletManager = appletManager
local jiveMain      = jiveMain


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
	local desktop = not System:isHardware()

	Framework:addActionListener("reload_skin", meta, _reloadSkinFromDiskAction, 9999)

	Framework:addActionListener("debug_skin", meta, function()
		appletManager:callService("debugSkin")

		if not desktop then
			appletManager:callService("debugStyle")
		end
	end)

	if desktop then
--		appletManager:callService("debugStyle")
	end
end


function _reloadSkinFromDiskAction(self, event)
	--free first so skin changes can be seen without jive rerun
	jiveMain:freeSkin()
	jiveMain:reloadSkin()
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
