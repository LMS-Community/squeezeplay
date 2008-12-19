
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
local Event             = require("jive.ui.Event")
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
	['qwerty']  = { 
			{ 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P' },
			{ 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L' },
			{ 'Z', 'X', 'C', 'V', 'B', 'N', 'M' }
	} ,
	['hex']     = { 
			{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' },
			{ },
			{'A', 'B', 'C', 'D', 'E', 'F' }
	},
	['numeric'] = { 
			{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' },
			{ '.', ',', '@' },
	}
 }

--[[

=head2 jive.ui.Keyboard(style, widgets)

Constructs a new Keyboard widget. I<style> is the widgets style.

=cut
--]]
function __init(self, style, kbType)
	_assert(type(style) == "string")

	local obj = oo.rawnew(self, Widget(style))
	local keyboard, widgets = obj:_setupKeyboard(kbType)

	obj.keyboard = keyboard
	obj.widgets  = widgets

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
	local x, y, w, h = self:getBounds()

	local keyWidth  = 35
	local keyHeight = 35

	-- find row with most keys to determine interkey spacing
	local maxRowKeys = 0
	for _, row in pairs(self.keyboard) do
		local numOfKeys = #row
		if numOfKeys >= maxRowKeys then
			maxRowKeys = numOfKeys
		end
	end
	local keySpacing = ( w - ( keyWidth * maxRowKeys ) ) / ( maxRowKeys + 1 ) 

	for _, row in pairs(self.keyboard) do
		-- center row
		x = ( w - ( (keyWidth * #row) + ( keySpacing * (#row - 1) ) ) ) / 2
		for _, key in pairs(row) do
			key:setBounds(x, y, keyWidth, keyHeight)
			x = x + keyWidth + keySpacing
		end
		y = y + 40
	end

end

--Sets up the keys to lay out in the keyboard
function _setupKeyboard(self, kbType)

	local keyboardTable = {}
	local widgetTable   = {}
	-- user defined keyboard
	if type(kbType) == 'table' then

		-- make buttons from table of custom keys

	-- qwerty keyboard
	elseif type(kbType) == 'string' then

		_assert(keyboards[kbType])

		for i,row in pairs(keyboards[kbType]) do
			local rowButtons = self:_buttonsFromChars(row)
			keyboardTable[i] = rowButtons
			for _, widget in pairs(rowButtons) do
				table.insert(widgetTable, widget)
			end
		end

		return keyboardTable, widgetTable
	end

end

-- turn the key in a row into Group widgets with Button widgets
function _buttonsFromChars(self, charTable)
	_assert(type(charTable) == 'table')

	local buttonTable = {}

	for k, v in pairs(charTable) do
		-- FIXME: add support special keys (shift, go, etc)
		if type(v) == 'function' then
		else
			local label  = Label("keyboardButton", v)
			local button = Button(
					label, 
					function()
						local e = Event:new(EVENT_CHAR_PRESS, string.byte(v))
						Framework:dispatchEvent(nil, e) 
						return EVENT_CONSUME 
					end
			)
			buttonTable[k] = button
		end
	end
	return buttonTable
end

--[[

=head1 LICENSE

Copyright 2008 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
