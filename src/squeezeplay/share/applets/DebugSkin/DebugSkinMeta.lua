
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local Canvas        = require("jive.ui.Canvas")
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
end


function configureApplet(meta)
	Framework:addActionListener("debug_skin", meta, _debugSkin, 9999)
end


function _debugWidget(meta, screen, widget)
	if meta.mouseEvent and widget:mouseInside(meta.mouseEvent) then
		local x,y,w,h = widget:getBounds()
		local l,t,r,b = widget:getBorder()

		screen:filledRectangle(x-l,y-t, x+w+r,y, 0x00FF003F)
		screen:filledRectangle(x-l,y+h, x+w+r,y+h+b, 0x00FF003F)

		screen:filledRectangle(x-l,y, x,y+h, 0x00FF003F)
		screen:filledRectangle(x+w,y, x+w+r,y+h, 0x00FF003F)

		screen:filledRectangle(x,y, x+w,y+h, 0xFF00003F)

		log:info("-> ", widget, " (", x, ",", y, " ", w, "x", h, ")")
	end

	widget:iterate(function(child)
		_debugWidget(meta, screen, child)
	end)
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


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
