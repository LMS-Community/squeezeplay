
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


local _assert, pairs, tostring, type, ipairs, math = _assert, pairs, tostring, type, ipairs, math

local oo                = require("loop.simple")
local Event             = require("jive.ui.Event")
local Widget            = require("jive.ui.Widget")
local Button            = require("jive.ui.Button")
local Icon              = require("jive.ui.Icon")
local Group             = require("jive.ui.Group")
local Label             = require("jive.ui.Label")
local Framework         = require("jive.ui.Framework")

local table             = require("jive.utils.table")
local string            = require("jive.utils.string")
local debug             = require("jive.utils.debug")
local log               = require("jive.utils.log").logger("ui")

module(..., Framework.constants)

oo.class(_M, Group)

local keyboardButtonText = {
        qwerty = 'ABC',
        qwertyLower  = 'abc',
        numeric = '123-&',
        hex = 'hex',
        chars = '!@&',
        emailNumeric = '123-&',
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

	--[[ code for styling keyboard based on number of rows... may or may not use this
	local numRows = #obj.keyboard
	local kbStyle = 'keyboard_' .. tostring(numRows)
	obj:setStyle(kbStyle)
	--]]

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
		['button_fill'] = 0,
	}
end

function _predefinedKeyboards(self)
		local emailKeyboardBottomRow = { 
					self:_switchKeyboardButton('emailNumeric', keyboardButtonText.emailNumeric), 
					{ style = 'button_fill', text = '.' },
					{ style = 'button_fill', text = '@' },
					self:_macroKeyButton('.com', 'button_fill'),
					self:_go() 
		}
		self.keyboards = { 
		['qwerty']  = { 
				{ 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P' },
				{ self:_spacer(), 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', self:_spacer()  },
				{ self:_shiftKey('qwertyLower'), 'Z', 'X', 'C', 'V', 'B', 'N', 'M', self:_spacer()  },
				{
					self:_switchKeyboardButton('numeric', keyboardButtonText.numeric), 
					self:_spaceBar(),
					self:_go(),
				},
		} ,
		['qwertyLower']  = { 
				{ 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p' },
				{ self:_spacer(), 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', self:_spacer() },
				{ self:_shiftKey('qwerty', 'qwertyLower'), 'z', 'x', 'c', 'v', 'b', 'n', 'm', self:_spacer() },
				{
					self:_switchKeyboardButton('numeric', keyboardButtonText.numeric), 
					self:_spaceBar(),
					self:_go(),
				},
		} ,
		['email']  = { 
				{ 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p' },
				{ self:_spacer(), 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', self:_spacer() },
				{ self:_shiftKey('emailUpper', 'email'), '@', 'z', 'x', 'c', 'v', 'b', 'n', 'm', '_' },
				emailKeyboardBottomRow
		} ,
		['emailUpper']  = { 
				{ 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P' },
				{ self:_spacer(), 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', self:_spacer() },
				{ self:_shiftKey('email'), '@', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '_'  },
				emailKeyboardBottomRow
		} ,
		['emailNumeric'] = { 
				{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' },
				{ '$', '+', '_', '-', '!', '#', '%', '&', "'", '*' },
				{ '@', '/', '=', '?', '^', '`', '{', '|', '}', '~', '.' },
				{
					self:_switchKeyboardButton('email', keyboardButtonText.qwertyLower), 
					{ style = 'button_fill', text = '.' },
					{ style = 'button_fill', text = '@' },
					self:_macroKeyButton('.com', 'button_fill'),
					self:_go() 
				},
		},
		['hex']     = { 
				{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' } ,
				{ self:_spacer(), 'A', 'B', 'C', 'D', 'E', 'F', self:_go() },
		},
		['ip']     = { 
				{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' } ,
				{ '.', self:_spacer(), self:_go() },
		},
		['numeric'] = { 
				{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' },
				{ '.', '-', '+', '/', '=', '_', '@', '#', '$', '%' },
				{ self:_spacer(), ':', '&', ',', '?', '!', '(', ')', "'", self:_spacer() },
				{
					self:_switchKeyboardButton('qwerty', keyboardButtonText.qwerty), 
					self:_spaceBar(),
					self:_go(),
				},
		},
	}
end


function _layout(self)

	local x, y, w, h = self:getBounds()
	local screenWidth, screenHeight = Framework:getScreenSize()

	local keyWidth
	local defaultKeyWidth = 46
	local rowWidth = screenWidth - 16
	local defaultKeyHeight = 45

	-- self.keyboard has the keyboard, table of rows of key objects
	-- self.specialKeyWidths has data on keys that aren't the default width
	-- 	local style = key:getStyle()
	-- 	if self.specialKeyWidths[style] then ... end

	for i, row in ipairs(self.keyboard) do
		local spacers = 0 
		local nonSpacerKeyWidth = 0
		-- first pass for non-spacer nonSpacerKeyWidth
		for _, key in ipairs(row) do
			local style = key:getStyle()
			local keyWidth = defaultKeyWidth
			if style == 'keyboard_spacer' or style == 'shiftOff' or style == 'shiftOn' or self.specialKeyWidths[style] == 0 then
				spacers = spacers + 1
			else
				if self.specialKeyWidths[style] then
					keyWidth = self.specialKeyWidths[style]
				end
				nonSpacerKeyWidth = keyWidth + nonSpacerKeyWidth
			end
		end
		-- second pass, layout the keys
		local extraSpacerPixels = ( rowWidth - nonSpacerKeyWidth) % spacers
		spacerWidth = math.floor( ( rowWidth - nonSpacerKeyWidth ) / spacers )

		x = 10
		local numberOfSpacers = 0
		for _, key in ipairs(row) do
			local style = key:getStyle()
			local keyWidth
			if style == 'keyboard_spacer' or style == 'button_fill' or style == 'shiftOff' or style == 'shiftOn' then
				numberOfSpacers = numberOfSpacers + 1
				if numberOfSpacers == 1 and extraSpacerPixels then
					keyWidth = spacerWidth + extraSpacerPixels
				else
					keyWidth = spacerWidth	
				end
			else
				if self.specialKeyWidths[style] then
					keyWidth = self.specialKeyWidths[style]
				else
					keyWidth = defaultKeyWidth
				end
			end
			
			log:debug('keyWidth for this key set to: ', keyWidth)
			key:setBounds(x, y, keyWidth, defaultKeyHeight)
			x = x + keyWidth
		end

		-- on to the next row: add some vertical pixels to our key positioning
		y = y + defaultKeyHeight 
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

function _macroKeyButton(self, keyText, style)
	if not style then
		style = 'button'
	end
	return {	
		text     = keyText,
		style    = style,
		callback = function()
				local stringTable = string.split('', keyText)
				for _, v in ipairs(stringTable) do
					local e = Event:new(EVENT_CHAR_PRESS, string.byte(v))
					Framework:dispatchEvent(nil, e) 
				end
				return EVENT_CONSUME 
			end,
	}
end


function _switchKeyboardButton(self, kbType, keyText)
	return {	
		text     = keyText,
		style    = "button_fill",
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
function _go(self, style)
	return {	
		-- FIXME: don't hardcode to 'done'
		text     = 'done',
		style    = 'button_fill',
		callback = function()
			local e = Event:new(EVENT_KEY_PRESS, KEY_GO)
			Framework:dispatchEvent(nil, e) 
			return EVENT_CONSUME 
		end
	}
end

function _spacer(self)
	return {
		text = '',
		style = 'keyboard_spacer',
		callback = function()
			return EVENT_CONSUME
		end
	}
end

-- return a table that can be used as a shift key
function _shiftKey(self, switchTo, switchBack)
	local style
	if switchBack then
		style = 'shiftOff'
	else
		style = 'shiftOn'
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


-- return a table that can be used as a space bar in keyboards
function _spaceBar(self)
	return {	
		style    = 'button_fill',
		-- FIXME, don't hard-code this text
		text     = 'space',
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
