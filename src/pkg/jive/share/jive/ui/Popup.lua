
--[[
=head1 NAME

jive.ui.Popup - A popup window widget.

=head1 DESCRIPTION

The popup widget, extends L<jive.ui.Window>. This is a container for other widgets on the screen.

=head1 SYNOPSIS

 -- Create a popup window with title "Boo!"
 local popup = jive.ui.Popup("popup", "Boo1")

 -- Show the window on the screen
 popup:show()

 -- Hide the window from the screen
 popup:hide()


=head1 STYLE

The Popup includes the following style parameters in addition to the Window basic parameters.

=over

B<maskImg> : Tile painted over any parts of the lower window that are visible behind the popup.

=head1 METHODS

=cut
--]]


-- stuff we use
local ipairs, tostring, type = ipairs, tostring, type

local oo              = require("loop.simple")
local Framework       = require("jive.ui.Framework")
local Widget          = require("jive.ui.Widget")
local Window          = require("jive.ui.Window")

local log             = require("jive.utils.log").logger("ui")

local EVENT_ACTION    = jive.ui.EVENT_ACTION
local EVENT_KEY_PRESS = jive.ui.EVENT_KEY_PRESS
local EVENT_CONSUME   = jive.ui.EVENT_CONSUME


-- our class
module(...)
oo.class(_M, Window)


function __init(self, style, title)
	local obj = oo.rawnew(self, Window(style, title))

	obj._DEFAULT_SHOW_TRANSITION = Window.transitionNone
	obj._DEFAULT_HIDE_TRANSITION = Window.transitionNone

	obj:setAllowScreensaver(false)
	obj:setAlwaysOnTop(true)
	obj:setAutoHide(true)
	obj:setShowFrameworkWidgets(false)
	obj:setTransparent(true)

	-- by default close popup on keypress
	obj:addListener(EVENT_KEY_PRESS,
			function(event)
				obj:playSound("WINDOWHIDE")
				obj:hide()
				return EVENT_CONSUME
			end)

	return obj
end


--[[

=head2 jive.ui.Popup:lowerWindow(widget)

Returns the window beneath this popup.

=cut
--]]
function getLowerWindow(self)
	for i = 1,#Framework.windowStack do
		if Framework.windowStack[i] == self then
			return Framework.windowStack[i + 1]
		end
	end
	return nil
end


function borderLayout(self)
	Window.borderLayout(self, true)
end


function __tostring(self)
	return "Popup()"
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
