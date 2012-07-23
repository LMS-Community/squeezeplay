
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local Canvas        = require("jive.ui.Canvas")
local Framework     = require("jive.ui.Framework")
local Timer         = require("jive.ui.Timer")

local debug         = require("jive.utils.debug")

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
	Framework:addActionListener("debug_touch", meta, _debugTouch, 9999)

	-- turn on by default for debugging
--	meta:_debugTouch()
end


function _debugWidget(meta, screen, event, widget)
	if widget:mouseInside(event) then
		local kids = 0
		widget:iterate(function(child)
			kids = kids + 1
		end)

		if kids == 0 then
			local x,y,w,h = widget:getBounds()
			screen:filledRectangle(x,y, x+w,y+h, 0xFF00003F)
		else
			widget:iterate(function(child)
				_debugWidget(meta, screen, event, child)
			end)
		end
	end
end


function _debugEvent(meta, screen)
	local r = 30

	if meta.mouseDown then
		local ev = meta.mouseDown
		local cx,cy = meta.mouseDown:getMouse()
		local hx,hy = cx,cy
		local col = 0xFFFFFFAF

		if meta.mouseDrag then
			ev = meta.mouseDrag
			hx,hy = meta.mouseDrag:getMouse()
			col = 0x000000AF
		end

--		if not meta.mouseUp then
--			_debugWidget(meta, screen, ev, Framework.windowStack[1])
--		end

		screen:circle(cx, cy, r, col)
		screen:hline(hx - r, hx + r, hy, 0xFFFFFFAF)
		screen:vline(hx, hy - r, hy + r, 0xFFFFFFAF)
	end
end


function _debugTouch(meta)
	if meta.enabled then
		meta.enabled = nil

		Framework:removeWidget(meta.canvas)
		Framework:removeListener(meta.mouseListener)

		return
	end

	meta.enabled = true

	meta.canvas = Canvas("debug_canvas", function(screen)
		_debugEvent(meta, screen)
	end)
	Framework:addWidget(meta.canvas)

	meta.timer = Timer(2000, function()
		meta.mouseDown = nil
		meta.mouseDrag = nil
		Framework:reDraw(nil)
	end)

	meta.mouseListener = Framework:addListener(EVENT_MOUSE_ALL,
		function(event)
			local type = event:getType()

			if type == EVENT_MOUSE_DOWN then
				meta.mouseUp = false
				meta.mouseDown = event
				meta.mouseDrag = nil
				meta.timer:stop()

			elseif type == EVENT_MOUSE_DRAG then
				meta.mouseDrag = event

			elseif type == EVENT_MOUSE_UP then
				meta.mouseUp = true
				meta.timer:restart()

			end
			Framework:reDraw(nil)
		end, -99)
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

