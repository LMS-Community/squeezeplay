
-- stuff we use
local _assert, getmetatable, ipairs, setmetatable = _assert, getmetatable, ipairs, setmetatable
local string, tonumber, tostring, type, unpack = string, tonumber, tostring, type, unpack

local oo                = require("loop.simple")
local Widget            = require("jive.ui.Widget")
local ScrollAccel       = require("jive.ui.ScrollAccel")
local IRMenuAccel       = require("jive.ui.IRMenuAccel")
local Timer             = require("jive.ui.Timer")
local Framework         = require("jive.ui.Framework")

local math              = require("math")
local string            = require("string")
local table             = require("jive.utils.table")
local log               = require("jive.utils.log").logger("ui")
local locale            = require("jive.utils.locale")
local debug             = require("jive.utils.debug")

local EVENT_ALL         = jive.ui.EVENT_ALL
local EVENT_UNUSED      = jive.ui.EVENT_UNUSED

local EVENT_IR_DOWN     = jive.ui.EVENT_IR_DOWN
local EVENT_IR_REPEAT   = jive.ui.EVENT_IR_REPEAT
local EVENT_IR_HOLD     = jive.ui.EVENT_IR_HOLD
local EVENT_IR_PRESS    = jive.ui.EVENT_IR_PRESS
local EVENT_IR_UP       = jive.ui.EVENT_IR_UP
local EVENT_IR_ALL       = jive.ui.EVENT_IR_ALL
local EVENT_KEY_PRESS   = jive.ui.EVENT_KEY_PRESS
local EVENT_CHAR_PRESS   = jive.ui.EVENT_CHAR_PRESS
local EVENT_SCROLL      = jive.ui.EVENT_SCROLL
local EVENT_WINDOW_RESIZE = jive.ui.EVENT_WINDOW_RESIZE
local EVENT_CONSUME     = jive.ui.EVENT_CONSUME

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

local NUMBER_LETTER_OVERSHOOT_TIME = 150 --ms
local NUMBER_LETTER_TIMER_TIME = 1100 --ms

-- our class
module(...)
oo.class(_M, Widget)

-- layout is from SC
local numberLettersMixed = {
	[0x76899867] = {' ','0'}, -- 0
	[0x7689f00f] = {'.',',',"'",'?','!','@','-','1'}, -- 1
	[0x768908f7] = {'a','b','c','A','B','C','2'}, 	   -- 2
	[0x76898877] = {'d','e','f','D','E','F','3'}, 	   -- 3
	[0x768948b7] = {'g','h','i','G','H','I','4'}, 	   -- 4
	[0x7689c837] = {'j','k','l','J','K','L','5'}, 	   -- 5
	[0x768928d7] = {'m','n','o','M','N','O','6'}, 	   -- 6
	[0x7689a857] = {'p','q','r','s','P','Q','R','S','7'}, 	-- 7
	[0x76896897] = {'t','u','v','T','U','V','8'}, 		-- 8
	[0x7689e817] = {'w','x','y','z','W','X','Y','Z','9'}   -- 9
}

-- return valid characters at cursor position.
function _getChars(self)
	if self.value.getChars then
		return tostring(self.value:getChars(self.cursor, self.allowedChars))
	end

	return tostring(self.allowedChars)
end

-- for ui input types like ir and for input like ip or date, down/up scroll polarity will be reversed
function _reverseScrollPolarityOnUpDownInput(self)
	if self.value.reverseScrollPolarityOnUpDownInput then
		return self.value:reverseScrollPolarityOnUpDownInput()
	end

	return false
end


-- returns true if text entry is valid.
function _isValid(self)
	if self.value.isValid then
		return self.value:isValid(self.cursor)
	end

	return true
end


-- returns true if text entry is completed.
function _isEntered(self)
	if self:_isValid() then
		return self.cursor > #tostring(self.value)
	else
		return false
	end
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


--[[

=head2 jive.ui.Textinput:_scroll(value)

Param chars may optionally be set to use an alternative set of chars rather than from self:_getChars(), which
 is useful for numberLetter scrolling, for instance.
 
Param restart may optionally be set. If true, _scroll() will always use the first char found in in the list of characters to scroll.


=cut
--]]
function _scroll(self, dir, chars, restart)
	if dir == 0 then
		return
	end	
	local cursor = self.cursor
	local str = tostring(self.value)

	local v = chars and chars or self:_getChars()
	if #v == 0 then
		return
	end

	local s1 = string.sub(str, 1, cursor - 1)
	local s2 = string.sub(str, cursor, cursor)
	local s3 = string.sub(str, cursor + 1)

	if not restart and s2 == "" then
		-- new char, keep cursor near the last letter
		if cursor > 1 then
			s2 = string.sub(str, cursor - 1, cursor - 1)
		end

		-- compensate for the initial nil value
		if dir > 0 then
			dir = dir - 1
		end
	end

	-- find current character, unless overriden by optional restart param 
	local i = nil
	if restart then
		i = 0
	else
		i = string.find(v, s2, 1, true)
	end

	-- move dir characters
	i = i + dir

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

function _getMatchingChars(self, charsTable)
	local validChars = ""
	for i,char in ipairs(charsTable) do
		if string.find(self:_getChars(), char, 1, true) then
			validChars = validChars .. char
		end
	end

	return validChars
end

function _cursorAtEnd(self)
	return self.cursor > #tostring(self.value)
end

function _deleteAction(self)
	if not _delete(self) then
		self:playSound("BUMP")
		self:getWindow():bumpRight()
	end
	return EVENT_CONSUME

end


function _insertAction(self)
	if not _insert(self) then
		self:playSound("BUMP")
		self:getWindow():bumpRight()
	end
	return EVENT_CONSUME
end

function _goAction(self)
	if _isEntered(self) then
		local valid = false

		if self.closure then
			valid = self.closure(self, self:getValue())
		end

		if not valid then
			self:playSound("BUMP")
			self:getWindow():bumpRight()
		end
	elseif self.cursor <= #tostring(self.value) then
		_moveCursor(self, 1)
		self:reDraw()
	else
		self:playSound("BUMP")
		self:getWindow():bumpRight()
	end
	return EVENT_CONSUME
end

function _cursorBackAction(self)
	if self.cursor == 1 then
		self:playSound("WINDOWHIDE")
		self:hide()
	else
		_moveCursor(self, -1)
		self:reDraw()
	end

	return EVENT_CONSUME
end


function _escapeAction(self)
	self.cursor = 1
	self:playSound("WINDOWHIDE")
	self:hide()
	return EVENT_CONSUME
end


function _eventHandler(self, event)
	local type = event:getType()

	--hold and press left works as cursor left. hold added here since it is intuitive to hold down left to go back several characters.
	--todo: also handle longhold when this is added.
	if (type == EVENT_IR_HOLD or type == EVENT_IR_PRESS) and (event:isIRCode("arrow_left") or event:isIRCode("arrow_right")) then
		--left and right and in down/repeat handling; consume so that it is not seen as an action
		return EVENT_CONSUME
	end

	if type == EVENT_IR_PRESS then
		--play is delete, add is insert, just like jive
		if event:isIRCode("play") then
			self.numberLetterTimer:stop()
			if not _delete(self) then
				self:playSound("BUMP")
				self:getWindow():bumpRight()
			end
			return EVENT_CONSUME
		end
		if event:isIRCode("add") then
			self.numberLetterTimer:stop()
			if not _insert(self) then
				self:playSound("BUMP")
				self:getWindow():bumpRight()
			end
			return EVENT_CONSUME
		end
	elseif type == EVENT_IR_UP and self.upHandlesCursor and (event:isIRCode("arrow_left") or event:isIRCode("arrow_right")) then
		self.upHandlesCursor = false
		
		--handle right and left on the up while at the ends of the text so that hold/repeat doesn't push past the ends of the screen
		if event:isIRCode("arrow_left") and self.cursor == 1 then
			self:_cursorBackAction()
		end
		if event:isIRCode("arrow_right") and self:_cursorAtEnd() then
			self:_goAction()
		end

		return EVENT_CONSUME
	elseif type == EVENT_IR_DOWN or type == EVENT_IR_REPEAT or type == EVENT_IR_HOLD then
		local irCode = event:getIRCode()
		if type == EVENT_IR_DOWN or type == EVENT_IR_REPEAT then

			--IR left/right
			if event:isIRCode("arrow_left") or event:isIRCode("arrow_right") then
				self.numberLetterTimer:stop()
				if self.locked == nil then
					local direction =  self.leftRightIrAccel:event(event, 1, 1, 1, #self:getValue())

					--move cursor, but when ir held down move to ends and stop so the user doesn't
					 --inadvertantly jump into the next page before lifting the the key.
					 --So, on the ends only move on a new press
					if direction < 0 then
						if self.cursor ~= 1 then
							self:_cursorBackAction()
						elseif type == EVENT_IR_DOWN then
							self.upHandlesCursor = true
						end
					end
					if direction > 0 then
						if not self:_cursorAtEnd() then
							self:_goAction()
						elseif type == EVENT_IR_DOWN then
							self.upHandlesCursor = true
						end
					end
					return EVENT_CONSUME
				end
			end

			--IR down/up
			if event:isIRCode("arrow_up") or event:isIRCode("arrow_down") then
				self.numberLetterTimer:stop()
				if self.locked == nil then
					local chars = self:_getChars()
					local idx = string.find(chars, string.sub(tostring(self.value), self.cursor, self.cursor), 1, true)

					-- for ui input types like ir and for input like ip or date, down/up scroll polarity will be reversed
					local polarityModifier = 1
					if self:_reverseScrollPolarityOnUpDownInput() then
						polarityModifier = -1
					end

					_scroll(self, polarityModifier * self.irAccel:event(event, idx, idx, 1, #chars))
					return EVENT_CONSUME
				end
			end
		end
		if type == EVENT_IR_DOWN or type == EVENT_IR_HOLD then
			local timerWasRunning = self.numberLetterTimer:isRunning()
		
			local numberLetters = numberLettersMixed[irCode]
			if numberLetters then
				self.numberLetterTimer:stop()
				if timerWasRunning and self.lastNumberLetterIrCode and irCode != self.lastNumberLetterIrCode then
					_moveCursor(self, 1)
					self:reDraw()
					
					_scroll(self, 1, tostring(_getMatchingChars(self, numberLetters)), true)
				else
					---First check for "overshoot"
					if self.lastNumberLetterT then
						local numberLetterTimeDelta = event:getTicks() - self.lastNumberLetterT
						if not timerWasRunning and numberLetterTimeDelta > NUMBER_LETTER_TIMER_TIME and 
								numberLetterTimeDelta < NUMBER_LETTER_TIMER_TIME + NUMBER_LETTER_OVERSHOOT_TIME then
							--If timer has just fired and another press on the same key is entered, 
							 -- follow observed SC behavior: don't use the input, making for
							 -- less unexpected input due to the key press happening right
							 -- as the timer fired even though the user meant for the press to refer to the last letter.
							return EVENT_CONSUME				
						end
					end

					----continue scroll if timer was active, otherwise start new scroll
					
					local availableNumberLetters = tostring(_getMatchingChars(self, numberLetters))
					
					local lastCharacterIfNumber = string.match(availableNumberLetters, "%d$")
					if type == EVENT_IR_HOLD and lastCharacterIfNumber then
						-- on hold, select the number character directly (always the last character), if it is available
						
						_scroll(self, 1, tostring(lastCharacterIfNumber), true)

						_moveCursor(self, 1)
						self.lastNumberLetterIrCode = nil
						
						return EVENT_CONSUME
					end
					
					local resetNumberLettersIndex = not timerWasRunning or self:_cursorAtEnd()
					_scroll(self, 1, availableNumberLetters, resetNumberLettersIndex)
				end
				
				self.lastNumberLetterIrCode = irCode
				
				self.lastNumberLetterT = event:getTicks()
				self.numberLetterTimer:restart()
							
				return EVENT_CONSUME
				
			end
		end
		
	elseif type == EVENT_SCROLL then
		-- XXX optimize by caching v and i in _scroll?
		self.numberLetterTimer:stop()
		local v = self:_getChars()
		local idx = string.find(v, string.sub(tostring(self.value), self.cursor, self.cursor), 1, true)

		_scroll(self, self.scroll:event(event, idx, idx, 1, #v))
		return EVENT_CONSUME

	elseif type == EVENT_CHAR_PRESS then
		self.numberLetterTimer:stop()
		
		--assuming ascii level values for now
		local keyboardEntry = string.char(event:getUnicode())
		if (keyboardEntry == "\b") then --backspace
			return _deleteAction(self)

		elseif (keyboardEntry == "\27") then --escape
			return _escapeAction(self)

		elseif not string.find(self:_getChars(), keyboardEntry, 1, true) then
			--also check for possibility of uppercase match
			if (string.find(keyboardEntry, "%l")) then
				keyboardEntry = string.upper(keyboardEntry)
			end
			if not string.find(self:_getChars(), keyboardEntry, 1, true) then
				self:playSound("BUMP")
				self:getWindow():bumpRight()
				return EVENT_CONSUME
			end
		end
		
		local before = string.sub(tostring(self.value), 1, self.cursor - 1)
		local after = string.sub(tostring(self.value), self.cursor + 1)
		self:setValue(before .. keyboardEntry .. after)
		
		_moveCursor(self, 1)
		
		return EVENT_CONSUME
		
	elseif type == EVENT_WINDOW_RESIZE then
		self.numberLetterTimer:stop()
		_moveCursor(self, 0)

	elseif type == EVENT_KEY_PRESS then
		self.numberLetterTimer:stop()
		local keycode = event:getKeycode()

		if keycode == KEY_REW then
			self.cursor = 1
			self:playSound("WINDOWHIDE")
			self:hide()
			return EVENT_CONSUME

		elseif keycode == KEY_FWD then
			if _isValid(self) then
				local valid = false

				if self.closure then
					valid = self.closure(self, self:getValue())
				end

				if valid then
					-- forward to end of input
					self.cursor = #tostring(self.value) + 1
				else
					self:playSound("BUMP")
					self:getWindow():bumpRight()
				end
			else
				self:playSound("BUMP")
				self:getWindow():bumpRight()
			end
		elseif keycode == KEY_BACK then
			return _cursorBackAction(self)

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
	obj.scroll = ScrollAccel()
	obj.leftRightIrAccel = IRMenuAccel("arrow_right", "arrow_left")
	obj.leftRightIrAccel.onlyScrollByOne = true

	obj.irAccel = IRMenuAccel()
	obj.lastNumberLetterIrCode = nil
	obj.lastNumberLetterT = nil
	obj.numberLetterTimer = Timer(NUMBER_LETTER_TIMER_TIME,     
					function() 
						obj.lastNumberLetterIrCode = nil
						obj:_moveCursor(1) 
						obj:reDraw()
					end, 
					true)
	
	obj:addActionListener("play", obj, _deleteAction)
	obj:addActionListener("add", obj, _insertAction)
	obj:addActionListener("go", obj, _goAction)

	--only touch back action will be handled this way (as escape), other back sources are use _cursorBackAction, and are handled directly in the main listener
	obj:addActionListener("back", obj, _escapeAction)

	obj:addListener(EVENT_CHAR_PRESS| EVENT_KEY_PRESS | EVENT_SCROLL | EVENT_WINDOW_RESIZE | EVENT_IR_ALL,
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
							if max and cursor > max then
								return ""
							end
							return allowedChars
						end,

				     isValid = function(obj, cursor)
						       if min and #obj.s < min then
							       return false
						       elseif max and #obj.s > max then
							       return false
						       else
							       return true
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
function timeValue(default, format)
	local obj = {}
	if not format then
		format = '24'
	end
	if tostring(format) == '12' then
		setmetatable(obj, {
		     __tostring =
				function(e)
				if type(e) == 'table' and e[3] then
					return e[1] .. ":" .. e[2] .. e[3]
				else
					return table.concat(e, ":")
				end
			end,

		     __index = {
				setValue =
					function(value, str)
						local i = 1
						for dd in string.gmatch(str, "(%d+)") do
							local n = tonumber(dd)
							if n > 12 and i == 1 then 
								n = 0 
							end
							value[i] = string.format("%02d", n)
							i = i + 1
							if i > 2 then 
								break
							end
						end
						local ampm = string.match(str, "[ap]", i)
						value[i] = ampm
				    	end,
				getValue =
					function(value)
						-- remove leading zeros
						local norm = {}
						for i,v in ipairs(value) do
							if type(v) == 'number' then
								norm[i] = tostring(tonumber(v))
							elseif type(v) == 'string' then
								norm[i] = v
							end
						end
						return norm[1] .. ":" .. norm[2] .. norm[3]
					end,

                               getChars = 
					function(value, cursor)
						if cursor == 7 then 
							return "" 
						end
						local v = tonumber(value[math.floor(cursor/3)+1])
						if cursor == 1 then
							-- first char can only be 1 if hour is 10
							if v == 10 then
								return "1"
							-- first char can be 0 or 1 if hour is 1,2,11,or 12
							elseif v < 3 or v > 10 then
								return "01"
							-- hour 3-9 only allows first num in hour to be 0
							else 
								return "0"
							end
						elseif cursor == 2 then
							if v > 9 then
								return "012"
							else
								return "123456789"
							end
						elseif cursor == 3 then
							return ""
						elseif cursor == 4 then
							return "012345"
						elseif cursor == 5 then
							return "0123456789"
						elseif cursor == 6 then
							return "ap"
						end
				end,
				reverseScrollPolarityOnUpDownInput =
					function()
					     return true
					end,

				isValid =
					function(value, cursor)
						return #value == 3 
					end
			}
		})
	else
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
				     reverseScrollPolarityOnUpDownInput =
					     function()
						     return true
					     end,

				     isValid =
					     function(value, cursor)
						    return #value == 2
					     end
			     }
		     })
	end

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
	if Framework:isMostRecentInput("mouse") then
		if default == "0.0.0.0" then
			--the typically seen "0.0.0.0" is not useful when doing touch
			default = ""
		end
		return ipAddressValueMouse(default)
	else
		return ipAddressValueNonMouse(default)
	end
end


function ipAddressValueNonMouse(default)
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
				     reverseScrollPolarityOnUpDownInput =
					     function()
						     return true
					     end,
				     isValid =
					     function(value, cursor)
						     return #value == 4
					     end
			     }
		     })

	if default then
		obj:setValue(default)
	end

	return obj
end


function ipAddressValueMouse(default)
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
							return ".0123456789"
						end,

				     reverseScrollPolarityOnUpDownInput =
					     function()
						     return true
					     end,
				     isValid = function(obj, cursor)
							local i = 0
							for ddd in string.gmatch(obj.s, "(%d+)") do
							     local n = tonumber(ddd)
							     if n < 0 or n > 255 then
							        return false
							     end
							     i = i + 1
							end
							if i ~= 4 then
								return false
							end

							return true
					       end
			     }
		     })

	return obj
end



--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

