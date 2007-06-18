
-- stuff we use
local assert, string, tostring, type, unpack = assert, string, tostring, type, unpack

local oo                = require("loop.simple")
local Widget            = require("jive.ui.Widget")
local Label             = require("jive.ui.Label")

local string            = require("string")
local log               = require("jive.utils.log").logger("ui")

local EVENT_ALL         = jive.ui.EVENT_ALL
local EVENT_UNUSED      = jive.ui.EVENT_UNUSED

local EVENT_KEY_PRESS   = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL      = jive.ui.EVENT_SCROLL
local EVENT_WINDOW_RESIZE = jive.ui.EVENT_WINDOW_RESIZE

local KEY_FWD           = jive.ui.KEY_FWD
local KEY_REW           = jive.ui.KEY_REW
local KEY_GO            = jive.ui.KEY_GO
local KEY_BACK          = jive.ui.KEY_BACK
local KEY_UP            = jive.ui.KEY_UP
local KEY_DOWN          = jive.ui.KEY_DOWN
local KEY_LEFT          = jive.ui.KEY_LEFT
local KEY_RIGHT         = jive.ui.KEY_RIGHT
local KEY_PLAY          = jive.ui.KEY_PLAY
local KEY_ADD           = jive.ui.KEY_ADD


-- our class
module(...)
oo.class(_M, Widget)


function _validchars(self)
	return " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()_+{}|:\\\"'<>?-=,./~`[];0123456789"
end


--[[

=head2 jive.ui.Label:getValue()

Returns the text displayed in the label.

=cut
--]]
function getValue(self)
	return self.value
end


--[[

=head2 jive.ui.Label:setValue(value)

Sets the text displayed in the label.

=cut
--]]
function setValue(self, value)
	assert(value ~= nil)

	if self.value ~= value then
		self.value = value
		self:rePrepare()
	end
end


function _scroll(self, dir)
	local cursor = self.cursor
	local str = self.value

	local v = self:_validchars()

	local s1 = string.sub(str, 1, cursor - 1)
	local s2 = string.sub(str, cursor, cursor)
	local s3 = string.sub(str, cursor + 1)

	-- find current character
	local i = string.find(v, s2, 1, true)

	-- move dir characters
	i = i + dir
	if i < 1 then
		i = i + #v
	elseif i > #v then
		i = i - #v
	end

	-- new string
	s2 = string.sub(v, i, i)
	self:setValue(s1 .. s2 .. s3)
end


function _moveCursor(self, dir)
	self.cursor = self.cursor + dir

	if self.cursor < #self.value then
		if self.cursor > self.indent + self._maxChars - 2 then
			self.indent =  self.cursor - self._maxChars + 2
		end
	else
		if self.cursor > self.indent + self._maxChars then
			self.indent =  self.cursor - self._maxChars
		end
	end

	if self.cursor > 2 then
		if self.cursor < self.indent + 3 then
			self.indent =  self.cursor - 3
		end
	else
		if self.cursor < 2 then
			self.indent =  self.cursor - 1
		end
	end
end


function _delete(self)
	local cursor = self.cursor
	local str = self.value

	local s1 = string.sub(str, 1, cursor - 1)
	local s3 = string.sub(str, cursor + 1)

	self:setValue(s1 .. s3)
end


function _insert(self)
	local cursor = self.cursor
	local str = self.value

	local s1 = string.sub(str, 1, cursor)
	local s3 = string.sub(str, cursor + 1)

	self:setValue(s1 .. " " .. s3)
	_moveCursor(self, 1)
end


function _eventHandler(self, event)
	local type = event:getType()

	if type == EVENT_SCROLL then
		_scroll(self, -event:getScroll())
		return EVENT_CONSUME

	elseif type == EVENT_WINDOW_RESIZE then
		_moveCursor(self, 0)

	elseif type == EVENT_KEY_PRESS then
		local keycode = event:getKeycode()

		if keycode == KEY_UP then
			_scroll(self, 1)
			return EVENT_CONSUME

		elseif keycode == KEY_DOWN then
			_scroll(self, -1)
			return EVENT_CONSUME

		elseif keycode == KEY_PLAY then
			_delete(self)
			return EVENT_CONSUME

		elseif keycode == KEY_ADD then
			_insert(self)
			return EVENT_CONSUME

		elseif keycode == KEY_GO or
			keycode == KEY_RIGHT or
			keycode == KEY_FWD then

			log:warn("cursor=", self.cursor)
			log:warn("#value=", #self.value)
			if self.cursor > #self.value then
				if self.closure then
					self.closure(self, self.value)
				else
					self:getWindow():bumpRight()
				end
			else
				_moveCursor(self, 1)
				self:reDraw()
			end
			return EVENT_CONSUME

		elseif keycode == KEY_BACK or
			keycode == KEY_LEFT then

			if self.cursor == 1 then
				self:hide()
			else
				_moveCursor(self, -1)
				self:reDraw()
			end
			return EVENT_CONSUME

		elseif keycode == KEY_REW then
			self:hide()
			return EVENT_CONSUME

		end
	end

	return EVENT_UNUSED
end


-- XXXX FIXME
function __init(self, style, value, closure)
	assert(type(style) == "string")
	assert(value ~= nil)

	local obj = oo.rawnew(self, Label(style, value))

	obj.cursor = 1
	obj.indent = 0
	obj.maxWidth = 0
	obj.closure = closure

	obj:addListener(EVENT_KEY_PRESS | EVENT_SCROLL | EVENT_WINDOW_RESIZE,
			function(event)
				return _eventHandler(obj, event)
			end)

	return obj
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

