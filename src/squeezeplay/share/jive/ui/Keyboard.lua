
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

 -- switch an existing keyboard to hex
 keyboard:setKeyboard('hex')

=head1 STYLE

The Keyboard includes the following style parameters in addition to the widgets basic parameters.

=over

=head1 METHODS

=cut
--]]


local _assert, pairs, string, tostring, type, ipairs = _assert, pairs, string, tostring, type, ipairs

local oo                = require("loop.simple")
local Event             = require("jive.ui.Event")
local Widget            = require("jive.ui.Widget")
local Button            = require("jive.ui.Button")
local Icon              = require("jive.ui.Icon")
local Group             = require("jive.ui.Group")
local Label             = require("jive.ui.Label")
local Framework         = require("jive.ui.Framework")

local table             = require("jive.utils.table")
local debug             = require("jive.utils.debug")
local log               = require("jive.utils.log").logger("ui")

module(..., Framework.constants)

oo.class(_M, Group)

--[[

=head2 jive.ui.Keyboard(style, widgets)

Constructs a new Keyboard widget. I<style> is the widgets style.

=cut
--]]
function __init(self, style, kbType)
	_assert(type(style) == "string")

	local obj = oo.rawnew(self, Widget(style))

	-- accepted keyboard types
	obj.keyboard = {}
	obj.widgets  = {}

	obj:_predefinedKeyboards()
	obj:_specialKeyWidths()

	local keyboard, widgets = obj:setKeyboard(kbType)

	-- forward events to contained widgets
	obj:addListener(EVENT_MOUSE_ALL,
			 function(event)
				for _, widget in ipairs(obj.widgets) do
					if notMouse or widget:mouseInside(event) then
						 local r = widget:_event(event)
						 if r ~= EVENT_UNUSED then
							 return r
						 end
					 end
				 end
				 return EVENT_UNUSED
			 end)
	return obj

end

function _specialKeyWidths(self)
	self.specialKeyWidths = {
		['keyboardSpace'] = 150,
		['keyboardShift'] = 60,
	}
end

function _predefinedKeyboards(self)
	self.keyboards = { 
		['qwerty']  = { 
				{ 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P' },
				{ 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L' },
				{ 'Z', 'X', 'C', 'V', 'B', 'N', 'M', self:_backspaceButton()  },
				{ 
					self:_switchKeyboardButton(style, 'numeric', '123'), 
					self:_spaceBar(), 
					self:_switchKeyboardButton(style, 'qwertyLower', 'abc'), 
					self:_go() 
				}
		} ,
		['qwertyLower']  = { 
				{ 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p' },
				{ 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l' },
				{ 'z', 'x', 'c', 'v', 'b', 'n', 'm', self:_backspaceButton() },
				{ 
					self:_switchKeyboardButton(style, 'numeric', '123'), 
					self:_spaceBar(), 
					self:_switchKeyboardButton(style, 'qwerty', 'ABC'), 
					self:_go() 
				}
		} ,
		['hex']     = { 
				{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' } ,
				{ 'A', 'B', 'C', 'D', 'E', 'F', self:_backspaceButton() },
				{},
				{ 
					self:_switchKeyboardButton(style, 'numeric', '123'), 
					self:_spaceBar(), 
					self:_switchKeyboardButton(style, 'qwerty', 'ABC'), 
					self:_go() 
				}
		},
		['numeric'] = { 
				{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' },
				{ '.', ',', '@', self:_backspaceButton() },
				{},
				{ 
					self:_switchKeyboardButton(style, 'hex', 'hex'), 
					self:_spaceBar(), 
					self:_switchKeyboardButton(style, 'qwerty', 'ABC'), 
					self:_go()
				}
		}
	}
end


--
function _layout(self)

	-- call Button:setPosition() for each key for layout
	local x, y, w, h = self:getBounds()

	local keyWidth

	-- find row with most keys to determine interkey spacing
	local maxRowKeys = 0
	local maxWidth   = 0
	local rowWidths  = {}

	for _, row in ipairs(self.keyboard) do
		local rowWidth = 0
		for _, key in ipairs(row) do
			local style = key:getStyle()
			if self.specialKeyWidths[style] then
				keyWidth = self.specialKeyWidths[style]
			else
				keyWidth = 35
			end
			rowWidth = rowWidth + keyWidth
		end
		table.insert(rowWidths, rowWidth)
		if rowWidth > maxWidth then
			maxWidth = rowWidth
		end
		local numOfKeys = #row
		if numOfKeys > maxRowKeys then
			maxRowKeys = numOfKeys
		end
	end

	local keySpacing = ( w - ( maxWidth ) ) / ( maxRowKeys + 1 ) 

	for i, row in ipairs(self.keyboard) do
		-- center row
		x = ( w - ( (rowWidths[i]) + ( keySpacing * (#row - 1) ) ) ) / 2
		for _, key in ipairs(row) do
			local style = key:getStyle()
			if self.specialKeyWidths[style] then
				keyWidth = self.specialKeyWidths[style]
			else
				keyWidth = 35
			end
			key:setBounds(x, y, keyWidth, 35)
			x = x + keyWidth + keySpacing
		end
		y = y + 50
	end

end

--[[

=head2 jive.ui.Keyboard:setKeyboard(kbType)

Changes Keyboard widget to I<type>, where type is either a pre-defined keyboard ('qwerty', 'qwertyLower', 'numeric', 'hex'),
or a user-defined table of keys to render

=cut
--]]

--Sets up the keys to lay out in the keyboard
function setKeyboard(self, kbType)

	-- unlink any current widgets to their parents
	-- clear object's widgets and keyboard tables
	if self.widgets then
		for _, widget in ipairs(self.widgets) do
			widget.parent = nil
		end
		self.widgets  = {}
		self.keyboard = {}
	end

	local keyboardTable = {}
	local widgetTable   = {}

	local keyboard

	-- user defined keyboard
	if type(kbType) == 'table' then
		keyboard = kbType

	-- pre-defined keyboard
	elseif type(kbType) == 'string' then
		keyboard = self.keyboards[kbType]

	end

	_assert(keyboard)

	for i,row in ipairs(keyboard) do
		local rowButtons = self:_buttonsFromChars(row)
		table.insert(keyboardTable, rowButtons)
		for _, widget in ipairs(rowButtons) do
			table.insert(widgetTable, widget)
		end
	end

	self.keyboard = keyboardTable
	self.widgets  = widgetTable

	for _,widget in ipairs(self.widgets) do
		widget.parent = self
	end

	self:reLayout()

end



-- turn the key in a row into Group widgets with Button widgets
function _buttonsFromChars(self, charTable)
	_assert(type(charTable) == 'table')

	local buttonTable = {}

	for k, v in ipairs(charTable) do
		local button
		if type(v) == 'table' then
			local keyStyle = v.style or 'keyboardButton'
			local label
			if v.icon then
				label = v.icon
			else
				label    = Label(keyStyle, v.text)
			end
			local callback = v.callback or 
					function()
						local e = Event:new(EVENT_CHAR_PRESS, string.byte(v.text))
						Framework:dispatchEvent(nil, e) 
						return EVENT_CONSUME 
					end
			button   = Button(label, callback)
		else
			local label  = Label("keyboardButton", v)
			button = Button(
					label, 
					function()
						local e = Event:new(EVENT_CHAR_PRESS, string.byte(v))
						Framework:dispatchEvent(nil, e) 
						return EVENT_CONSUME 
					end
			)
		end
		table.insert(buttonTable, button)
	end
	return buttonTable
end

function _switchKeyboardButton(self, style, kbType, keyText)
	return {	
		text     = keyText,
		style    = 'keyboardShift',
		callback = function()
			self:setKeyboard(kbType)
			return EVENT_CONSUME 
		end
	}
end

-- return a table that can be used as a space bar in keyboards
function _go(self)
	return {	
		icon	 = Icon("keyboardGo"),
		callback = function()
			local e = Event:new(EVENT_KEY_PRESS, KEY_GO)
			Framework:dispatchEvent(nil, e) 
			return EVENT_CONSUME 
		end
	}
end

-- return a table that can be used as a backspace bar in keyboards
function _backspaceButton(self)
	return {	
		icon	 = Icon("keyboardBack"),
		callback = function()
			local e = Event:new(EVENT_CHAR_PRESS, string.byte("\b"))
			Framework:dispatchEvent(nil, e) 
			return EVENT_CONSUME 
		end
	}
end


-- return a table that can be used as a space bar in keyboards
function _spaceBar(self)
	return {	
		style    = 'keyboardSpace',
		text     = ' ',
		callback = function()
			local e = Event:new(EVENT_CHAR_PRESS, string.byte(' '))
			Framework:dispatchEvent(nil, e) 
			return EVENT_CONSUME 
		end
	}
end

--[[

=head1 LICENSE

Copyright 2008 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
