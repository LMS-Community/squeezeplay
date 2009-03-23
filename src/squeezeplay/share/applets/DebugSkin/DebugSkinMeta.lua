
local ipairs, pairs = ipairs, pairs

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local System        = require("jive.System")

local Framework     = require("jive.ui.Framework")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("ui")

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
		appletManager:callService("debugStyle")
	end
end


function _debugSkin(meta)
	if meta.enabled then
		meta.enabled = nil

		Framework:removeWidget(meta.canvas)
		Framework:removeListener(meta.mouseListener)

		return
	end

	meta.enabled = true

	meta.canvas = Canvas("blank", function(screen)
		local window = Framework.windowStack[1]

		log:info("Mouse in: ", window)
		window:iterate(function(w)
			_debugWidget(meta, screen, w)
		end)
	end)
	Framework:addWidget(meta.canvas, true)

	meta.mouseListener = Framework:addListener(EVENT_MOUSE_ALL,
		function(event)
			meta.mouseEvent = event
			Framework:reDraw(nil)
		end, -99)
end


function _reloadSkinFromDiskAction(self, event)
	--free first so skin changes can be seen without jive rerun
	jiveMain:freeSkin()
	jiveMain:reloadSkin()
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
