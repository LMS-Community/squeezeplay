
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


local _assert, pairs, tostring, tonumber, type, ipairs, math = _assert, pairs, tostring, tonumber, type, ipairs, math

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
        emailNumericShift = '123-&',
}

--[[

=head2 jive.ui.Keyboard(style, widgets)

Constructs a new Keyboard widget. I<style> is the widgets style.

=cut
--]]
function __init(self, style, kbType)
	_assert(type(style) == "string")

	local obj = oo.rawnew(self, Group(style, {}))

	obj.kbType = kbType

	-- accepted keyboard types
	obj.keyboard = {}

	obj:_predefinedKeyboards()

	obj:setKeyboard(kbType)

	return obj

end


function _predefinedKeyboards(self)
		local emailKeyboardBottomRow = { 
					self:_switchKeyboardButton('emailNumeric', keyboardButtonText.emailNumeric), 
					{ keyWidth = 0, text = '.' },
					{ keyWidth = 92, text = '@' },
					self:_macroKeyButton('.com'),
					self:_go() 
		}
		self.keyboards = { 
		['qwerty']  = { 
				{ 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P' },
				{ self:_spacer(), 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', self:_spacer()  },
				{ self:_shiftKey('qwertyLower'), 'Z', 'X', 'C', 'V', 'B', 'N', 'M', self:_spacer()  },
				{
					self:_switchKeyboardButton('numeric', keyboardButtonText.numeric, 92, 'qwerty'), 
					self:_spaceBar(),
					self:_go(92),
				},
		} ,
		['qwertyLower']  = { 
				{ 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p' },
				{ self:_spacer(), 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', self:_spacer() },
				{ self:_shiftKey('qwerty', 'qwertyLower'), 'z', 'x', 'c', 'v', 'b', 'n', 'm', self:_spacer() },
				{
					self:_switchKeyboardButton('numeric', keyboardButtonText.numeric, 92, 'qwertyLower'), 
					self:_spaceBar(),
					self:_go(92),
				},
		} ,
		['email']  = { 
				{ 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p' },
				{ self:_spacer(), 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', self:_spacer() },
				{ self:_shiftKey('emailUpper', 'email'), 'z', 'x', 'c', 'v', 'b', 'n', 'm', '-', '_' },
				emailKeyboardBottomRow
		} ,
		['emailUpper']  = { 
				{ 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P' },
				{ self:_spacer(), 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', self:_spacer() },
				{ self:_shiftKey('email'), 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '-', '_' },
				emailKeyboardBottomRow
		} ,
		['emailNumeric'] = { 
				{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' },
				{ '$', '+', '_', '-', '!', '#', '%', '&', "'", '*' },
				{ '/', '=', '?', '^', '`', '{', '|', '}', '~', '.' },
				{
					self:_switchKeyboardButton(self:_decideKbType('email'), keyboardButtonText.qwertyLower),
					{ keyWidth = 0, text = '.' },
					{ keyWidth = 92, text = '@' },
					self:_macroKeyButton('.com'),
					self:_go() 
				},
		},
		['hex']     = { 
				{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' } ,
				{ self:_spacer(), 'A', 'B', 'C', 'D', 'E', 'F', self:_go() },
		},
		['ip']     = { 
				{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' } ,
				{ '.', self:_spacer(), self:_go(92) },
		},
		['numeric'] = { 
				{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' },
				{ '.', '-', '+', '/', '=', '_', '@', '#', '$', '%' },
				{ self:_shiftKey('numericShift', 'numeric'), ':', '&', ',', '?', '!', '(', ')', "'", self:_spacer() },
				{
					self:_switchKeyboardButton(self:_decideKbType('qwerty'), keyboardButtonText.qwerty, 92), 
					self:_spaceBar(),
					self:_go(92),
				},
		},
		['numericShift'] = { 
				{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' },
				{ ';', '"', '`', '~', '^', '*', '\\', '|', '[', ']' },
				{ self:_shiftKey('numeric'), '{', '}', '<', '>', self:_spacer() },
				{
					self:_switchKeyboardButton(self:_decideKbType('qwerty'), keyboardButtonText.qwerty, 92), 
					self:_spaceBar(),
					self:_go(92),
				},
		},
		}
end

function _decideKbType(self, default)
	return function()
		if self.goBack then
			return self.goBack
		else
			return default
		end
	end
end

function _layout(self)

	local x, y, w, h = self:getBounds()
	local screenWidth, screenHeight = Framework:getScreenSize()

	local keyWidth
	local defaultKeyWidth = 46
	local defaultKeyHeight = 44
	local rowWidth = 460

	-- self.keyboard has the keyboard, table of rows of key objects
	-- self.rowInfo has metadata about the keyboard, e.g., keyWidth or spacer

	for i, row in ipairs(self.keyboard) do
		local rowInfo = self.keyInfo[i]
		local spacers = 0 
		local nonSpacerKeyWidth = 0
		-- first pass for non-spacer nonSpacerKeyWidth
		for j, key in ipairs(row) do
			local style = key:getStyle()
			local keyWidth = defaultKeyWidth
			if rowInfo[j].keyWidth == 0 then 
				spacers = spacers + 1
			else
				if rowInfo[j].keyWidth then
					keyWidth = tonumber(rowInfo[j].keyWidth)
				end
				nonSpacerKeyWidth = keyWidth + nonSpacerKeyWidth
			end
		end
		-- second pass, layout the keys
		local extraSpacerPixels = ( rowWidth - nonSpacerKeyWidth) % spacers
		spacerWidth = math.floor( ( rowWidth - nonSpacerKeyWidth ) / spacers )

		x = 10
		local numberOfSpacers = 0
		for j, key in ipairs(row) do
			local style = key:getStyle()
			local keyWidth
			if rowInfo[j].keyWidth == 0 then 
				numberOfSpacers = numberOfSpacers + 1
				if numberOfSpacers == 1 and extraSpacerPixels then
					keyWidth = spacerWidth + extraSpacerPixels
				else
					keyWidth = spacerWidth	
				end
			else
				if rowInfo[j].keyWidth then
					keyWidth = tonumber(rowInfo[j].keyWidth)
				else
					keyWidth = defaultKeyWidth
				end
			end
			
			log:debug('keyWidth for this key set to: ', keyWidth)
			key:setBounds(x, y, keyWidth, defaultKeyHeight)

			local keyType = 'key_'
			if string.match(style, "^key") or string.match(style, "^spacer") then
				if rowInfo[j].spacer then
					keyType = 'spacer_'
				end	
				-- upper left
				if i == 1 and j == 1 then
					location = 'topLeft'
				-- top middle
				elseif i == 1 and j < #row then
					location = 'top'
				-- top right
				elseif i == 1 and j == #row then
					location = 'topRight'
				-- left
				elseif i < #self.keyboard and j == 1 then
					location = 'left'
				-- middle
				elseif i < #self.keyboard and j < #row then
					location = 'middle'
				-- right edge
				elseif i < #self.keyboard and j == #row then
					location = 'right'
				-- bottom left
				elseif i == #self.keyboard and j == 1 then
					location = 'bottomLeft'
				-- bottom
				elseif i == #self.keyboard and j < #row then
					location = 'bottom'
				-- bottom right
				elseif i == #self.keyboard and j == #row then
					location = 'bottomRight'
				end
				if rowInfo[j].fontSize == 'small' and keyType == 'key_' then
					location = location .. '_small'
				end
				key:setStyle(keyType .. location)
			end

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
	local infoTable     = {}

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
		local rowButtons, info = self:_buttonsFromChars(row)
		table.insert(keyboardTable, rowButtons)
		table.insert(infoTable, info)
		for _, widget in ipairs(rowButtons) do
			table.insert(widgetTable, widget)
		end
	end

	self.keyboard   = keyboardTable
	self.widgets    = widgetTable
	self.keyInfo    = infoTable

	for _,widget in ipairs(self.widgets) do
		widget.parent = self
	end

	self:reLayout()

end



-- turn the key in a row into Group widgets with Button widgets
function _buttonsFromChars(self, charTable)
	_assert(type(charTable) == 'table')

	local buttonTable = {}
	local infoTable = {}

	for k, v in ipairs(charTable) do
		local button
		local info = {}
		if type(v) == 'table' then
			local keyStyle = v.style or 'key'
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
			info = v
		else
			local label  = Label("key", v)
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
		table.insert(infoTable, info)
	end
	return buttonTable, infoTable
end

function _macroKeyButton(self, keyText, keyWidth)
	if not keyWidth then
		keyWidth = 0
	end
	return {	
		text     = keyText,
		keyWidth = keyWidth,
		style    = 'key',
		fontSize = 'small',
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


function _switchKeyboardButton(self, kbType, keyText, keyWidth, goBack)
	if not keyWidth then
		keyWidth = 0
	end
	
	return {	
		text     = keyText,
		fontSize = 'small',
		keyWidth = keyWidth,
		callback = function()
			local keyboardType = kbType
			-- sometimes keyboardType needs to be determined from self.goBack via a closure
			if type(kbType) == "function" then
				keyboardType = kbType()
			end
			if goBack then
				self.goBack = goBack
			end
			self.kbType = kbType
			self.pushed = keyText
			self:playSound("SELECT")
			self:setKeyboard(keyboardType)
			-- unset any one key shift behavior if a switch keyboard button is hit directly
			self.last = nil
			return EVENT_CONSUME 
		end
	}
end

-- return a table that can be used as a space bar in keyboards
function _go(self, keyWidth)
	if not keyWidth then
		keyWidth = 0
	end
	return {	
		icon     = Label('done'),
		keyWidth = keyWidth,
		callback = function()
			Framework:pushAction("finish_operation") 
			return EVENT_CONSUME 
		end
	}
end

function _spacer(self, keyWidth)
	if not keyWidth then
		keyWidth = 0
	end
	return {
		text = '',
		keyWidth = keyWidth,
		spacer = 1,
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
			self.goBack = switchTo
			self:setKeyboard(switchTo)
			self:playSound("SELECT")
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
function _spaceBar(self, keyWidth)
	if not keyWidth then
		keyWidth = 0
	end
	return {	
		icon     = Label('space'),
		keyWidth = keyWidth,
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
