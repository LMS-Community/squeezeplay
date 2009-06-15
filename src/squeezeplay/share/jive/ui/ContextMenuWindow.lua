

-- stuff we use
local ipairs, tostring, type = ipairs, tostring, type

local oo              = require("loop.simple")
local Framework       = require("jive.ui.Framework")
local Widget          = require("jive.ui.Widget")
local Window          = require("jive.ui.Window")

local log             = require("jive.utils.log").logger("squeezeplay.ui")

local EVENT_ACTION    = jive.ui.EVENT_ACTION
local EVENT_KEY_PRESS = jive.ui.EVENT_KEY_PRESS
local ACTION          = jive.ui.ACTION
local EVENT_CONSUME   = jive.ui.EVENT_CONSUME


-- our class
module(...)
oo.class(_M, Window)


function __init(self, title)
	local obj = oo.rawnew(self, Window("context_menu" , title))

	obj._DEFAULT_SHOW_TRANSITION = Window.transitionFadeInFast
	obj._DEFAULT_HIDE_TRANSITION = Window.transitionNone

	obj:setAllowScreensaver(true)
	obj:setTransparent(true)
	obj:setShowFrameworkWidgets(false)
	obj:setContextMenu(true)

	obj:setButtonAction("lbutton", nil)
	obj:setButtonAction("rbutton", "cancel")

	obj:addActionListener("cancel", obj, _cancelContextMenuAction)
	obj:addActionListener("context_menu", obj, _cancelContextMenuAction)

	return obj
end

function _cancelContextMenuAction()
	Window:hideContextMenus()
	return EVENT_CONSUME
end

function show(self)

	local stack = Framework.windowStack

	local idx = 1
	local topwindow = stack[idx]
	while topwindow and topwindow.alwaysOnTop do
		idx = idx + 1
		topwindow = stack[idx]
	end

	if topwindow:isContextMenu() then
		log:error("herer")
		Window.show(self, Window.transitionPushLeftStaticTitle)
		self:setStyle("context_submenu")
	else
		Window.show(self)
	end

end

function hide(self)

	local stack = Framework.windowStack

	local idx = 1
	local topwindow = stack[idx]
	while topwindow and topwindow.alwaysOnTop do
		idx = idx + 1
		topwindow = stack[idx]
	end

	if stack[idx + 1] and stack[idx + 1]:isContextMenu() then
		Window.hide(self, Window.transitionPushRightStaticTitle)
	else
		Window.hide(self)
	end

end

--function borderLayout(self)
--	Window.borderLayout(self, true)
--end


function __tostring(self)
	return "ContextMenuWindow()"
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
