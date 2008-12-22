
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
	obj.keyboards           = obj:_predefinedKeyboards()

	local keyboard, widgets = obj:_setupKeyboard(kbType)

	obj.keyboard = keyboard
	obj.widgets  = widgets

	for _,widget in ipairs(obj.widgets) do
		widget.parent = obj
	end

	-- forward events to contained widgets
	obj:addListener(EVENT_ALL,
			 function(event)
				local eventType = event:getType()
				 local notMouse = (eventType & EVENT_MOUSE_ALL) == 0
				if (eventType == EVENT_KEY_PRESS) then
					return EVENT_UNUSED
				end

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

	obj:_layout()

	return obj
end

function _predefinedKeyboards(self)
	return { 
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
				{ 
					self:_switchKeyboardButton(style, 'numeric', '123'), 
					self:_switchKeyboardButton(style, 'qwerty', 'ABC'), 
					self:_switchKeyboardButton(style, 'qwertyLower', 'abc'), 
					self:_go() 
				}
		},
		['numeric'] = { 
				{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' },
				{ '.', ',', '@', self:_backspaceButton() },
				{ 
					self:_switchKeyboardButton(style, 'qwerty', 'ABC'), 
					self:_spaceBar(), 
					self:_switchKeyboardButton(style, 'qwertyLower', 'abc'), 
					self:_go()
				}
		}
	}
end


--
function _layout(self)

	-- call Button:setPosition() for each key for layout
	local x, y, w, h = self:getBounds()

	local keyWidth  = 35
	local keyHeight = 35

	-- find row with most keys to determine interkey spacing
	local maxRowKeys = 0
	for _, row in ipairs(self.keyboard) do
		local numOfKeys = #row
		if numOfKeys >= maxRowKeys then
			maxRowKeys = numOfKeys
		end
	end
	local keySpacing = ( w - ( keyWidth * maxRowKeys ) ) / ( maxRowKeys + 1 ) 

	for _, row in ipairs(self.keyboard) do
		-- center row
		x = ( w - ( (keyWidth * #row) + ( keySpacing * (#row - 1) ) ) ) / 2
		for _, key in ipairs(row) do
			key:setBounds(x, y, keyWidth, keyHeight)
			x = x + keyWidth + keySpacing
		end
		y = y + 50
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

		_assert(self.keyboards[kbType])

		for i,row in ipairs(self.keyboards[kbType]) do
			local rowButtons = self:_buttonsFromChars(row)
			keyboardTable[i] = rowButtons
			for _, widget in ipairs(rowButtons) do
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

function _switchKeyboard(style, kbType)
	log:warn('Not yet functional')
end

function _switchKeyboardButton(self, style, kbType, keyText)
	return {	
		text     = keyText,
		callback = function()
			_switchKeyboard(style, kbType)
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
