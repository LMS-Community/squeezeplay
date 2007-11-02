
-- stuff we use
local _assert, getmetatable, ipairs, setmetatable = _assert, getmetatable, ipairs, setmetatable
local string, tonumber, tostring, type, unpack = string, tonumber, tostring, type, unpack

local oo                = require("loop.simple")
local Widget            = require("jive.ui.Widget")

local math              = require("math")
local string            = require("string")
local table             = require("jive.utils.table")
local log               = require("jive.utils.log").logger("ui")
local locale            = require("jive.utils.locale")

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


-- return valid characters at cursor position.
function _getChars(self)
	if self.value.getChars then
		return tostring(self.value:getChars(self.cursor, self.allowedChars))
	end

	return tostring(self.allowedChars)
end


-- returns true if text entry is completed.
function _isEntered(self)
	if self.value.isEntered then
		return self.value:isEntered(self.cursor)
	end

	return self.cursor > #tostring(self.value)
end



--[[

=head2 jive.ui.Textinput:getValue()

Returns the text displayed in the label.

=cut
--]]
function getValue(self)
	return self.value
end


--[[

=head2 jive.ui.Textinput:setValue(value)

Sets the text displayed in the label.

=cut
--]]
function setValue(self, value)
	_assert(value ~= nil)

	if self.value ~= value then
		if self.value.setValue  then
			self.value:setValue(value)
		else
			self.value = value
		end

		self:reLayout()
	end
end


function _scroll(self, dir)
	local cursor = self.cursor
	local str = tostring(self.value)

	local v = self:_getChars()
	if #v == 0 then
		return
	end

	local s1 = string.sub(str, 1, cursor - 1)
	local s2 = string.sub(str, cursor, cursor)
	local s3 = string.sub(str, cursor + 1)

	-- find current character
	local i = string.find(v, s2, 1, true)

	-- move dir characters, compensating for the initial nil value
	if (not (dir > 0 and s2 == "")) then
		i = i + dir
	end

	-- handle wrap around conditions
	if i < 1 then
		i = i + #v
	elseif i > #v then
		i = i - #v
	end

	-- new string
	local s2 = string.sub(v, i, i)

	self:setValue(s1 .. s2 .. s3)
	self:playSound("CLICK")
end


function _moveCursor(self, dir)
	local oldCursor = self.cursor

	self.cursor = self.cursor + dir

	-- check for a valid character at the cursor position, if
	-- we don't find one then move again. this allows for 
	-- formatted text entry, for example pairs of hex digits
	local str = tostring(self.value)
	local v = self:_getChars()
	local s2 = string.sub(str, self.cursor, self.cursor)

	if (not string.find(v, s2, 1, true)) then
		return _moveCursor(self, dir)
	end

	if self.cursor ~= oldCursor then
		self:playSound("SELECT")
	end
end


function _delete(self)
	local cursor = self.cursor
	local str = tostring(self.value)

	if cursor <= #str then

		-- delete at cursor
		local s1 = string.sub(str, 1, cursor - 1)
		local s3 = string.sub(str, cursor + 1)

		self:setValue(s1 .. s3)
		return true

	elseif cursor > 1 then
		-- backspace
		local s1 = string.sub(str, 1, cursor - 2)

		self:setValue(s1)
		self.cursor = cursor - 1
		return true

	else
		return false

	end
end


function _insert(self)
	local cursor = self.cursor
	local str = tostring(self.value)

	local s1 = string.sub(str, 1, cursor)
	local s3 = string.sub(str, cursor + 1)

	self:setValue(s1 .. " " .. s3)
	_moveCursor(self, 1)

	return true
end


function _eventHandler(self, event)
	local type = event:getType()

	if type == EVENT_SCROLL then
		_scroll(self, event:getScroll())
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
			if not _delete(self) then
				self:getWindow():bumpRight()
			end
			return EVENT_CONSUME

		elseif keycode == KEY_ADD then
			if not _insert(self) then
				self:getWindow():bumpRight()
			end
			return EVENT_CONSUME

		elseif keycode == KEY_GO or
			keycode == KEY_RIGHT then

			if _isEntered(self) then
				local valid = false

				if self.closure then
					valid = self.closure(self, self:getValue())
				end

				if not valid then
					self:getWindow():bumpRight()
				end
			elseif self.cursor <= #tostring(self.value) then
				_moveCursor(self, 1)
				self:reDraw()
			else
				self:getWindow():bumpRight()
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
			self.cursor = 1
			self:hide()
			return EVENT_CONSUME

		elseif keycode == KEY_FWD then
			if _isEntered(self) then
				local valid = false

				if self.closure then
					valid = self.closure(self, self:getValue())
				end

				if valid then
					-- forward to end of input
					self.cursor = #tostring(self.value) + 1
				else
					self:getWindow():bumpRight()
				end
			else
				self:getWindow():bumpRight()
			end
		end
	end

	return EVENT_UNUSED
end


--[[

=head2 jive.ui.Textinput:init(style, value, closure, allowedChars)

Creates a new Textinput widget with initial value I<value>. The I<closure>
is a function that will be called at the end of the text input. This function
should return false if the text is invalid (the window will then bump right)
or return true when the text is valid.
I<allowedChars> is an optional parameter containing the list of chars to propose.

=cut
--]]
function __init(self, style, value, closure, allowedChars)
	_assert(type(style) == "string")
	_assert(value ~= nil)

	local obj = oo.rawnew(self, Widget(style))
	 _globalStrings = locale:readGlobalStringsFile()

	obj.cursor = 1
	obj.indent = 0
	obj.maxWidth = 0
	obj.value = value
	obj.closure = closure
	obj.allowedChars = allowedChars or
		_globalStrings:str("ALLOWEDCHARS_WITHCAPS")

	obj:addListener(EVENT_KEY_PRESS | EVENT_SCROLL | EVENT_WINDOW_RESIZE,
			function(event)
				return _eventHandler(obj, event)
			end)

	return obj
end


--[[

=head2 jive.ui.Textinput.textValue(default, min, max)

Returns a value that can be used for entering a length bounded text string

=cut
--]]
function textValue(default, min, max)
	local obj = {
		s = default or ""
	}

	setmetatable(obj, {
			     __tostring = function(obj)
						  return obj.s
					  end,

			     __index = {
				     setValue = function(obj, str)
							obj.s = str
						end,

				     getValue = function(obj)
							return obj.s
						end,

				     getChars = function(obj, cursor, allowedChars)
							if cursor > max then
								return ""
							end
							return allowedChars
						end,

				     isEntered = function(obj, cursor)
							 if cursor <= min then
								 return false
							 elseif cursor >= max + 1 then
								 return true
							 else
								 return cursor > #obj.s
							 end
						 end
			     }
		     })

	return obj
end


--[[

=head2 jive.ui.Textinput.timeValue(default)

Returns a value that can be used for entering time setting

=cut
--]]
function timeValue(default)
	local obj = {}
	setmetatable(obj, {
			     __tostring =
				     function(e)
					     return table.concat(e, ":")
				     end,

			     __index = {
				     setValue =
					     function(value, str)
						     local i = 1
						     for dd in string.gmatch(str, "(%d+)") do
							     local n = tonumber(dd)
							     if n > 23 and i == 1 then i = 0 end
							     value[i] = string.format("%02d", n)
							     i = i + 1
							     if i > 2 then break end
						     end
					     end,

				     getValue =
					     function(value)
						     -- remove leading zeros
						     local norm = {}
						     for i,v in ipairs(value) do
							     norm[i] = tostring(tonumber(v))
						     end
						     return table.concat(norm, ":")
					     end,

                                     getChars = 
                                             function(value, cursor)
							if cursor == 6 then return "" end
							local v = tonumber(value[math.floor(cursor/3)+1])
							if cursor == 1 then
								return "012"
							elseif cursor == 2 then
								if v > 19 then
									return "0123"
								else
									return "0123456789"
								end
							elseif cursor == 3 then
								return ""
							elseif cursor == 4 then
								return "012345"
							elseif cursor == 5 then
								return "0123456789"
							end
                                             end,

				     isEntered =
					     function(value, cursor)
						    return cursor == 6
					     end
			     }
		     })

	if default then
		obj:setValue(default)
	end

	return obj
end

--[[

=head2 jive.ui.Textinput.hexValue(default)

Returns a value that can be used for entering an hexadecimal value.

=cut
--]]
function hexValue(default)
	local obj = {}
	setmetatable(obj, {
			     __tostring =
				     function(e)
					     return table.concat(e, " ")
				     end,

			     __index = {
				     setValue =
					     function(value, str)
						     local i = 1
						     for dd in string.gmatch(str, "%x%x") do
							     value[i] = dd
							     i = i + 1
						     end
						     
					     end,

				     getValue =
					     function(value)
						     return table.concat(value)
					     end,

				     getChars = 
					     function(value, cursor)
						     if cursor == (#value * 3) then
							     return ""
						     end
						     return "0123456789ABCDEF"
					     end,

				     isEntered =
					     function(value, cursor)
						     return cursor == (#value * 3)
					     end
			     }
		     })

	if default then
		obj:setValue(default)
	end

	return obj
end


--[[

=head2 jive.ui.Textinput.ipAddressValue(default)

Returns a value that can be used for entering an ip address.

=cut
--]]
function ipAddressValue(default)
	local obj = {}
	setmetatable(obj, {
			     __tostring =
				     function(e)
					     return table.concat(e, ".")
				     end,

			     __index = {
				     setValue =
					     function(value, str)
						     local i = 1
						     for ddd in string.gmatch(str, "(%d+)") do
							     local n = tonumber(ddd)
							     if n > 255 then n = 255 end

							     value[i] = string.format("%03d", n)
							     i = i + 1
							     if i > 4 then break end
						     end
					     end,

				     getValue =
					     function(value)
						     -- remove leading zeros
						     local norm = {}
						     for i,v in ipairs(value) do
							     norm[i] = tostring(tonumber(v))
						     end
						     return table.concat(norm, ".")
					     end,

				     getChars = 
					     function(value, cursor)
						     local n = (cursor % 4)
						     if n == 0 then return "" end

						     local v = tonumber(value[math.floor(cursor/4)+1])
						     local a = math.floor(v / 100)
						     local b = math.floor(v % 100 / 10)
						     local c = math.floor(v % 10)

						     if n == 1 then
							     if b > 6 or (b == 5 and c > 5) then
								     return "01"
							     else
								     return "012"
							     end
						     elseif n == 2 then
							     if a >= 2 and c > 5 then
								     return "01234"
							     elseif a >= 2 then
								     return "012345"
							     else
								     return "0123456789"
							     end
						     elseif n == 3 then
							     if a >= 2 and b >= 5 then
								     return "012345"
							     else
								     return "0123456789"
							     end
						     end
					     end,

				     isEntered =
					     function(value, cursor)
						     return cursor == 16
					     end
			     }
		     })

	if default then
		obj:setValue(default)
	end

	return obj
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

