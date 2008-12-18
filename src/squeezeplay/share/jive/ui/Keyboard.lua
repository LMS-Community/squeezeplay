
--[[
=head1 NAME

jive.ui.Keyboard - A keyboard widget.

=head1 DESCRIPTION

A keyboard widget, extends L<jive.ui.Widget>, it is a container for other widgets, primarily buttons. 

=head1 SYNOPSIS

 -- Create a new qwerty keyboard
 local keyboard = jive.ui.Keyboard("qwerty")

 -- Create a new numeric keyboard (IP addresses, time)
 local keyboard = jive.ui.Keyboard("numeric")

 -- Create a new hex keyboard (WEP passwords)
 local keyboard = jive.ui.Keyboard("hex")


=head1 STYLE

The Keyboard includes the following style parameters in addition to the widgets basic parameters.

=over

=head1 METHODS

=cut
--]]


local _assert, pairs, string, tostring, type = _assert, pairs, string, tostring, type

local oo                = require("loop.simple")
local Widget            = require("jive.ui.Widget")
local Button            = require("jive.ui.Button")
local Group             = require("jive.ui.Group")
local Label             = require("jive.ui.Label")
local Framework         = require("jive.ui.Framework")

local table             = require("jive.utils.table")
local debug             = require("jive.utils.debug")
local log               = require("jive.utils.log").logger("ui")


module(..., Framework.constants)

oo.class(_M, Group)

-- accepted keyboard types
local keyboards = { 
	['qwerty']  = { 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P' },
	['hex']     = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' },
	['numeric'] = { }
 }

--[[

=head2 jive.ui.Keyboard(style, widgets)

Constructs a new Keyboard widget. I<style> is the widgets style.

=cut
--]]
function __init(self, style, kbType)
	_assert(type(style) == "string")

	local obj = oo.rawnew(self, Widget(style))
	local widgets = obj:_getWidgetTable(kbType)

	obj.widgets = widgets
debug.dump(obj.widgets)

	for _,widget in pairs(obj.widgets) do
		widget.parent = obj
	end

	-- forward events to contained widgets
	obj:addListener(EVENT_ALL,
			 function(event)
				 local notMouse = (event:getType() & EVENT_MOUSE_ALL) == 0

				 for _,widget in pairs(obj.widgets) do
					 if notMouse or widget:mouseInside(event) then
						 local r = widget:_event(event)
						 if r ~= EVENT_UNUSED then
							 return r
						 end
					 end
				 end
				 return EVENT_UNUSED
			 end)

	obj:_layout()

	return obj
end


--
function _layout(self)

	-- call Button:setPosition() for each key for layout
	local x, y = 5, 45
	for k, button in pairs(self.widgets) do
		button:setBounds(x, y, 35, 35)
		x = x + 40
	end

end

--Sets up the keys to lay out in the keyboard
function _getWidgetTable(self, kbType)

	-- user defined keyboard
	if type(kbType) == 'table' then

		-- make buttons from table of custom keys

	-- qwerty keyboard
	elseif kbType == 'qwerty' then

		--local secondRow = { 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L' }
		--local thirdRow  = { 'Z', 'X', 'C', 'V', 'B', 'N', 'M' }

		local firstRowButtons = self:_buttonsFromChars(keyboards[kbType])

		--local secondRowButtons = self:_buttonsFromChars(secondRow)
		--local thirdRowButtons = self:_buttonsFromChars(thirdRow)

		return firstRowButtons

	-- other keyboards
	elseif kbType == 'hex' then

		-- make buttons for hex keyboard

	elseif kbType == 'numeric' then

		-- make buttons for numeric keyboard

	end

end

-- turn the key in a row into Group widgets with Button widgets
function _buttonsFromChars(self, charTable)
	_assert(type(charTable) == 'table')

	local buttonTable = {}

	for k, v in pairs(charTable) do
		local label  = Label("touchButton", v)
		local button = Button(
				label, 
				function()
					Framework:dispatchNewEvent(EVENT_CHAR_PRESS, v) 
					return EVENT_CONSUME 
				end
		)
		buttonTable[k] = button
	end
	return buttonTable
end

--[[

=head1 LICENSE

Copyright 2008 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
