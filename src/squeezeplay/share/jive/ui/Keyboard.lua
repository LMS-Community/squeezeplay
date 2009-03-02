
--[[
=head1 NAME

jive.ui.Keyboard - A keyboard widget.

=head1 DESCRIPTION

A keyboard widget, extends L<jive.ui.Widget>, it is a container for other widgets, primarily buttons. 

=head1 SYNOPSIS

 -- Create a new qwerty keyboard
 local keyboard = jive.ui.Keyboard("keyboard", "qwerty")

 -- Create a new numeric keyboard (IP addresses, time)
 local keyboard = jive.ui.Keyboard("keyboard", "numeric")

 -- Create a new hex keyboard (WEP passwords)
 local keyboard = jive.ui.Keyboard("keyboard", "hex")

 -- switch an existing keyboard to hex
 keyboard:setKeyboard("hex")

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

local keyboardButtonText = {
        qwerty = 'ABC',
        qwertyLower  = 'abc',
        numeric = '123',
        hex = 'hex',
        chars = '!@&',
}

--[[

=head2 jive.ui.Keyboard(style, widgets)

Constructs a new Keyboard widget. I<style> is the widgets style.

=cut
--]]
function __init(self, style, kbType)
	_assert(type(style) == "string")

	local obj = oo.rawnew(self, Widget(style))

	obj.kbType = kbType

	-- accepted keyboard types
	obj.keyboard = {}
	obj.widgets  = {}

	obj:_predefinedKeyboards()
	obj:_specialKeyWidths()


	local keyboard, widgets = obj:setKeyboard(kbType)

	-- forward events to contained widgets
	obj:addListener(EVENT_MOUSE_ALL,
			 function(event)
				return _eventHandler(obj, event)
			 end)
	return obj

end

function _eventHandler(self, event)
	local evtType = event:getType()
	if evtType == EVENT_KEY_PRESS then
		local keycode = event:getKeycode()
		if keycode == KEY_BACK or keycode == KEY_LEFT then
			self:getWindow():hide()
			return EVENT_CONSUME
		else
			return EVENT_UNUSED
		end
	else
		for _, widget in ipairs(self.widgets) do
			if widget:mouseInside(event) then
				local r = widget:_event(event)
				 if r ~= EVENT_UNUSED then
					 return r
				 end
			 end
		 end
	end
	return EVENT_UNUSED
end

function _specialKeyWidths(self)
	self.specialKeyWidths = {
		['button_space'] = 150,
		['button_shift'] = 60,
		['pushed'] = 60,
	}
end

function _predefinedKeyboards(self)
		local bottomRow = { 
					self:_switchKeyboardButton(style, 'numeric', keyboardButtonText.numeric), 
					self:_switchKeyboardButton(style, 'hex', keyboardButtonText.hex), 
					self:_spaceBar(), 
					self:_switchKeyboardButton(style, 'chars', keyboardButtonText.chars), 
					self:_switchKeyboardButton(style, 'qwerty', keyboardButtonText.qwerty), 
					self:_switchKeyboardButton(style, 'qwertyLower', keyboardButtonText.qwertyLower), 
					self:_go() 
		}
		self.keyboards = { 
		['qwerty']  = { 
				{ 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P' },
				{ 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L' },
				{ self:_shiftKey('qwertyLower'), 'Z', 'X', 'C', 'V', 'B', 'N', 'M', self:_backspaceButton()  },
				bottomRow
		} ,
		['qwertyLower']  = { 
				{ 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p' },
				{ 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l' },
				{ self:_shiftKey('qwerty', 'qwertyLower'), 'z', 'x', 'c', 'v', 'b', 'n', 'm', self:_backspaceButton() },
				bottomRow
		} ,
		['hex']     = { 
				{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' } ,
				{ 'A', 'B', 'C', 'D', 'E', 'F', self:_backspaceButton() },
				{},
				bottomRow
		},
		['numeric'] = { 
				{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' },
				{ '.', ',', '@', '$', '+', ':', '_', '-', self:_backspaceButton() },
				{},
				bottomRow
		},
		['chars'] = {
				{ '.', ',', '@', '!', '#', '$', '%', '^', '&', '*' },
				{ '(', ')', '_', '+', '{', '}', '|', ':', '~', '?' }, 
				{ '-', '=', '/', '\\', '`', '[', ']', "'", '"', self:_backspaceButton() },
				bottomRow
		}
	}
end


--
function _layout(self)

	-- call Button:setPosition() for each key for layout
	local x, y, w, h = self:getBounds()

	local keyWidth

	-- find row with most keys to determine interkey spacing
	local maxRowKeys     = 0
	local maxWidth       = 0
	-- bottom row is treated differently for layout
	local bottomRowWidth = 0
	local bottomRowKeys  = 0
	local rowWidths      = {}

	for i, row in ipairs(self.keyboard) do
		local rowWidth = 0
		for _, key in ipairs(row) do
			local style = key:getStyle()
			if self.specialKeyWidths[style] then
				keyWidth = self.specialKeyWidths[style]
			else
				keyWidth = 45
			end
				rowWidth = rowWidth + keyWidth
		end
		table.insert(rowWidths, rowWidth)
		if rowWidth > maxWidth and i ~= #self.keyboard then
			maxWidth = rowWidth
		end
			local numOfKeys = #row
		if numOfKeys > maxRowKeys then
			maxRowKeys = numOfKeys
		end
		if i == #self.keyboard then
			bottomRowWidth = rowWidth
			bottomRowKeys  = numOfKeys
		end
	end

	-- FIXME: this is a hack. self:getBounds() values aren't correct while the widget is being laid out. 
	-- screenWidth - 16 needs replacing
	local screenWidth, screenHeight = Framework:getScreenSize()
	local keySpacing = ( (screenWidth - 16) - ( maxWidth ) ) / ( maxRowKeys + 1 ) 

	for i, row in ipairs(self.keyboard) do
		local rowKeySpacing = keySpacing
		if i == #self.keyboard then
			-- FIXME: replace screenWidth with something measured from the widget's dimension
			rowKeySpacing = ( screenWidth - ( bottomRowWidth ) ) / ( bottomRowKeys + 1 ) 
		end
		-- center row
		-- FIXME: replace screenWidth with something measured from the widget's dimension
		x = ( screenWidth - ( (rowWidths[i]) + ( rowKeySpacing * (#row - 1) ) ) ) / 2
		for _, key in ipairs(row) do
			local style = key:getStyle()
			if self.specialKeyWidths[style] then
				keyWidth = self.specialKeyWidths[style]
			else
				keyWidth = 45
			end
			key:setBounds(x, y, keyWidth, 45)
			x = x + keyWidth + rowKeySpacing
		end
		y = y + 50
	end

end

--[[

=head2 jive.ui.Keyboard:setKeyboard(kbType)

Changes Keyboard widget to I<type>, where type is either a pre-defined keyboard ('qwerty', 'qwertyLower', 'numeric', 'hex'),
or a user-defined table of keys to render

If a I<self.last> keyboard is defined, the keyboard switches back to that keyboard after one key is pressed

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
			local keyStyle = v.style or 'button'
			if keyStyle == 'shift' or keyStyle == 'pushed' then
				if v.text == self.pushed or self.pushed == nil and keyboardButtonText[self.kbType] == v.text then
					keyStyle = 'pushed'
				else
					keyStyle = 'shift'
				end
			end
			local label
			if v.icon then
				label = v.icon
			else
				label    = Label(keyStyle, v.text)
			end
			-- XXX, v.callback, if used, not compatible with self.last
			local callback = v.callback or 
					function()
						local e = Event:new(EVENT_CHAR_PRESS, string.byte(v.text))
						Framework:dispatchEvent(nil, e) 
						if self.last then
							self:setKeyboard(self.last)
							self.last = nil
						end
						return EVENT_CONSUME 
					end
			button   = Button(label, callback)
		else
			local label  = Label("button", v)
			button = Button(
					label, 
					function()
						local e = Event:new(EVENT_CHAR_PRESS, string.byte(v))
						Framework:dispatchEvent(nil, e) 
						if self.last then
							self:setKeyboard(self.last)
							self.last = nil
						end
						return EVENT_CONSUME 
					end
			)
		end
		table.insert(buttonTable, button)
	end
	return buttonTable
end

function _switchKeyboardButton(self, style, kbType, keyText)
	local keyStyle = 'shift'
	if kbType == self.kbType then
		keyStyle = 'pushed'
	end
	return {	
		text     = keyText,
		style    = keyStyle,
		callback = function()
			self.kbType = kbType
			self.pushed = keyText
			self:setKeyboard(kbType)
			-- unset any one key shift behavior if a switch keyboard button is hit directly
			self.last = nil
			return EVENT_CONSUME 
		end
	}
end

-- return a table that can be used as a space bar in keyboards
function _go(self)
	return {	
		icon	 = Icon("button_enter"),
		callback = function()
			local e = Event:new(EVENT_KEY_PRESS, KEY_GO)
			Framework:dispatchEvent(nil, e) 
			return EVENT_CONSUME 
		end
	}
end

-- return a table that can be used as a shift key
function _shiftKey(self, switchTo, switchBack)
	local style
	if switchBack then
		style = switchBack
	else
		style = 'qwertyUpper'
	end
	return {	
		icon	 = Icon(style),
		callback = function()
			self:setKeyboard(switchTo)
			if switchBack then
				self.last = switchBack
			else
				self.last = nil
			end
			return EVENT_CONSUME 
		end
	}
end


-- return a table that can be used as a backspace bar in keyboards
function _backspaceButton(self)
	return {	
		icon	 = Icon("button_back"),
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
		style    = 'space',
		text     = 'SPACE',
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
