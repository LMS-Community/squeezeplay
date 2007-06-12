
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
oo.class(_M, Label)


function _validchars(self)
	return " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()_+{}|:\\\"'<>?-=,./~`[];0123456789"
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
	self.cursor = cursor + 1
end


function _eventHandler(self, event)
	local type = event:getType()

	if type == EVENT_SCROLL then
		_scroll(self, -event:getScroll())
		return EVENT_CONSUME

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
				self.cursor = self.cursor + 1
			end
			return EVENT_CONSUME

		elseif keycode == KEY_BACK or
			keycode == KEY_LEFT then

			if self.cursor == 1 then
				self:hide()
			else
				self.cursor = self.cursor - 1
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
	obj.closure = closure

	obj:addListener(EVENT_KEY_PRESS | EVENT_SCROLL,
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

