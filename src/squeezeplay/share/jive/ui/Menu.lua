-----------------------------------------------------------------------------
-- Menu.lua
-----------------------------------------------------------------------------

--[[
=head1 NAME

jive.ui.Menu - A menu widget.

=head1 DESCRIPTION

A menu widget, extends L<jive.ui.Widget>.

=head1 SYNOPSIS

 -- Create a new menu
 local menu = jive.ui.Menu("menu")

 -- Add widgets to the menu
 menu:addItem(jive.ui.Label("One"))
 menu:addItem(jive.ui.Label("Two"))
 menu:addItem(jive.ui.Label("Three"))

=head1 STYLE

The Label includes the following style parameters in addition to the widgets basic parameters.

=over

B<itemHeight> : the height of each menu item.

=head1 METHODS

=cut
--]]


-- stuff we use
local _assert, ipairs, pairs, string, tostring, type, getmetatable = _assert, ipairs, pairs, string, tostring, type, getmetatable

local oo                   = require("loop.simple")
local debug                = require("jive.utils.debug")
                           
local table                = require("jive.utils.table")
local Framework            = require("jive.ui.Framework")
local Event                = require("jive.ui.Event")
local Widget               = require("jive.ui.Widget")
local Label                = require("jive.ui.Label")
local Scrollbar            = require("jive.ui.Scrollbar")
local Surface              = require("jive.ui.Surface")
local ScrollAccel          = require("jive.ui.ScrollAccel")
local IRMenuAccel          = require("jive.ui.IRMenuAccel")
local Timer                = require("jive.ui.Timer")

local log                  = require("jive.utils.log").logger("ui")

local math                 = require("math")


local EVENT_ALL            = jive.ui.EVENT_ALL
local EVENT_ALL_INPUT      = jive.ui.EVENT_ALL_INPUT
local ACTION               = jive.ui.ACTION
local EVENT_ACTION         = jive.ui.EVENT_ACTION
local EVENT_SCROLL         = jive.ui.EVENT_SCROLL
local EVENT_IR_ALL         = jive.ui.EVENT_IR_ALL
local EVENT_IR_DOWN        = jive.ui.EVENT_IR_DOWN
local EVENT_IR_REPEAT      = jive.ui.EVENT_IR_REPEAT
local EVENT_KEY_ALL        = jive.ui.EVENT_KEY_ALL
local EVENT_KEY_PRESS      = jive.ui.EVENT_KEY_PRESS
local EVENT_SHOW           = jive.ui.EVENT_SHOW
local EVENT_HIDE           = jive.ui.EVENT_HIDE
local EVENT_SERVICE_JNT    = jive.ui.EVENT_SERVICE_JNT
local EVENT_FOCUS_GAINED   = jive.ui.EVENT_FOCUS_GAINED
local EVENT_FOCUS_LOST     = jive.ui.EVENT_FOCUS_LOST
local EVENT_MOUSE_PRESS    = jive.ui.EVENT_MOUSE_PRESS
local EVENT_MOUSE_DOWN     = jive.ui.EVENT_MOUSE_DOWN
local EVENT_MOUSE_UP       = jive.ui.EVENT_MOUSE_UP
local EVENT_MOUSE_MOVE     = jive.ui.EVENT_MOUSE_MOVE
local EVENT_MOUSE_DRAG     = jive.ui.EVENT_MOUSE_DRAG
local EVENT_MOUSE_ALL      = jive.ui.EVENT_MOUSE_ALL

local EVENT_CONSUME        = jive.ui.EVENT_CONSUME
local EVENT_UNUSED         = jive.ui.EVENT_UNUSED
                           
local KEY_FWD              = jive.ui.KEY_FWD
local KEY_REW              = jive.ui.KEY_REW
local KEY_GO               = jive.ui.KEY_GO
local KEY_BACK             = jive.ui.KEY_BACK
local KEY_UP               = jive.ui.KEY_UP
local KEY_DOWN             = jive.ui.KEY_DOWN
local KEY_LEFT             = jive.ui.KEY_LEFT
local KEY_RIGHT            = jive.ui.KEY_RIGHT
local KEY_PLAY             = jive.ui.KEY_PLAY
local KEY_PAGE_UP           = jive.ui.KEY_PAGE_UP
local KEY_PAGE_DOWN         = jive.ui.KEY_PAGE_DOWN

--speed (pixels/ms) that must be surpassed for flick to start.
local FLICK_THRESHOLD_START_SPEED = 80/1000

--speed (pixels/ms) at which flick scrolling will stop
local FLICK_STOP_SPEED =  3/1000

--if initial speed is greater than this, "letter" accelerators will occur for the flick
local FLICK_FORCE_ACCEL_SPEED = 72 * 30/1000

--time after flick starts that decel occurs
local FLICK_DECEL_START_TIME = 400

--time from decel start to scroll stop (trying new linger setting, which throws this off)
local FLICK_DECEL_TOTAL_TIME = 600

--If non zero, extra afterscroll time (FLICK_SPEED_DECEL_TIME_FACTOR * flickSpeed ) is
 -- added to FLICK_DECEL_TOTAL_TIME.  flick speed maxes out at about 3.
local FLICK_SPEED_DECEL_TIME_FACTOR = 1500

-- our class
module(...)
oo.class(_M, Widget)



-- _selectedItem
-- returns the selected Item or nil if off stage
local function _selectedItem(self)
	if self.selected then
		return self.widgets[self.selected - self.topItem + 1]
	else
		return self.widgets[self.topItem]
	end
end


-- _coerce
-- returns value coerced between 1 and max
local function _coerce(value, max)
	if value < 1 then 
		return 1
	elseif value > max then
		return max
	end
	return value
end


local function _itemListener(self, item, event)

	local r = EVENT_UNUSED

	if item then
		r = self.itemListener(self, self.list, item, self.selected or 1, event)

		if r == EVENT_UNUSED then
			r = item:_event(event)
		end
	end
	return r
end


function _selectAndHighlightItemUnderPointer(self, event)
	local x,y,w,h = self:mouseBounds(event)
	local i = (y - self.pixelOffsetY) / self.itemHeight --(h / self.numWidgets)

	local itemShift = math.floor(i)
	if itemShift >= 0 and itemShift <= self.numWidgets then
		--select item under cursor
		local selectedIndex = self.topItem + itemShift
		if selectedIndex <= self.listSize then
			self:setSelectedIndex(selectedIndex)
			self.usePressedStyle = true
		else
			--outside of any menu item
			return false
		end
	else
		--outside of any menu item
		return false

	end

	return true
end

function resetDragData(self)
	self.pixelOffsetY = 0
	self.dragYSinceShift = 0
end

function handleDrag(self, dragAmountY)

	if dragAmountY ~= 0 then
--		log:error("handleDrag dragAmountY: ", dragAmountY )

		self.dragYSinceShift = self.dragYSinceShift + dragAmountY
--		log:error("handleDrag dragYSinceShift: ", self.dragYSinceShift )

		if (self.dragYSinceShift > 0 and math.floor(self.dragYSinceShift / self.itemHeight) > 0) or
				(self.dragYSinceShift < 0 and math.floor(self.dragYSinceShift / self.itemHeight) < 0) then
			local itemShift = math.floor(self.dragYSinceShift / self.itemHeight)
			self.dragYSinceShift = self.dragYSinceShift % self.itemHeight
			self.pixelOffsetY = -1 * self.dragYSinceShift

			if itemShift > 0 and self.currentShiftDirection <= 0 then
				--changing shift direction, move cursor so scroll wil occur
				self:setSelectedIndex(self.topItem + self.numWidgets - 2)
				self.currentShiftDirection = 1
			elseif itemShift < 0 and self.currentShiftDirection >= 0 then
				--changing shift direction, move cursor so scroll wil occur
				self:setSelectedIndex(self.topItem + 1)
				self.currentShiftDirection = -1
			end

			log:debug("self:scrollBy( itemShift ) ", itemShift )
			self:scrollBy( itemShift, true, false )

			if self.selected == 1 or self.selected == self.listSize then
				self:resetDragData()
			end

		else
			--smooth scroll

			self.pixelOffsetY = -1 * self.dragYSinceShift
			if self.selected and ((self.selected == 1 and self.currentShiftDirection == 1) or self.selected >= self.listSize - 1) then
				self:resetDragData()
			end

			log:debug("Scroll offset by: ", self.pixelOffsetY, " item height: ", self.itemHeight)
			self:reDraw()
		end
	end
end


-- _eventHandler
-- manages all menu events
local function _eventHandler(self, event)

	local evtype = event:getType()

	if (evtype & (EVENT_IR_ALL | EVENT_KEY_ALL | EVENT_SCROLL | EVENT_SHOW )) > 0 then
		self.usePressedStyle = false
		self.lastInputType = nil
	end

	if self.flickTimer and (evtype & (EVENT_IR_ALL | EVENT_KEY_ALL | EVENT_SCROLL | EVENT_SHOW | EVENT_HIDE)) > 0 then
		--only all input other than mouse input, stop flick (mouse input will also stop flick but has special handling)
		log:debug("Flick stopped due to input: ", event:tostring())
		self:stopFlick()
	end

	if self.selectItemAfterFingerDownTimer and (evtype & EVENT_ALL_INPUT ) > 0 then
		self.selectItemAfterFingerDownTimer:stop()
	end

	if evtype == EVENT_SCROLL then
		if self.locked == nil then
			self:resetDragData()
			self:scrollBy(self.scroll:event(event, self.topItem, self.selected or 1, self.numWidgets, self.listSize))
			return EVENT_CONSUME
		end

	elseif evtype == EVENT_IR_DOWN or evtype == EVENT_IR_REPEAT then
		--todo add lock cancelling like in key press - let action hanlding take care of this
		if event:isIRCode("arrow_up") or event:isIRCode("arrow_down") then
			self:resetDragData()
			if self.locked == nil then
				self:scrollBy(self.irAccel:event(event, self.topItem, self.selected or 1, self.numWidgets, self.listSize), true, evtype == EVENT_IR_DOWN)
				return EVENT_CONSUME
			end
		end

	elseif evtype == ACTION then
		local action = event:getAction()

		if self.locked ~= nil then
			if action == "back" then

				if type(self.locked) == "function" then
					self.locked(self)
				end
				self:unlock()

				return EVENT_CONSUME
			end
		else
			-- first send actions to selected widgets
			local r = _itemListener(self, _selectedItem(self), event)
			if r ~= EVENT_UNUSED then
				return r
			end

			-- otherwise try default behaviour
			if action == "page_up" then
				self:scrollBy( -( self.numWidgets - 1 ), true);
				return EVENT_CONSUME

			elseif action == "page_down" then
				self:scrollBy( self.numWidgets - 1 , true);
				return EVENT_CONSUME

			elseif action == "go" or action == "play" then

				local r = self:dispatchNewEvent(EVENT_ACTION)

				if r == EVENT_UNUSED then
					self:playSound("BUMP")
					self:getWindow():bumpRight()
				end
				return r

			elseif action == "back" then
				if self.closeable then
					self:playSound("WINDOWHIDE")
					self:hide()
					return EVENT_CONSUME
				else
					self:playSound("BUMP")
					self:getWindow():bumpLeft()
					return EVENT_CONSUME
				end
			end
		end

	elseif evtype == EVENT_KEY_PRESS then
		local keycode = event:getKeycode()

		if self.locked == nil then
			self:resetDragData()
			-- send keys to selected widgets, otherwise ignore, will return as actions
			local r = _itemListener(self, _selectedItem(self), event)
			if r ~= EVENT_UNUSED then
				return r
			end
		end

	elseif evtype == EVENT_MOUSE_PRESS then

		if self.scrollbar:mouseInside(event) then

			-- forward event to scrollbar
			local result =  self.scrollbar:_event(event)
			_scrollList(self)

			return result


		else
			if self.flickInterruptedByFinger then
				--flick just stopped (on the down event), so ignore this press - do the same for hold when implemented
				self.flickInterruptedByFinger = nil
				return EVENT_CONSUME
			end

			if not self:_selectAndHighlightItemUnderPointer(event) then
				return EVENT_CONSUME
			end

			--relayout so selected item is shown during transition
			self:reLayout()

			--need to allow screen to be repainted before event is sent, so put on a 0-length timer

			local tempDispatchTimer = Timer(0,
			       function()
					local r = self:dispatchNewEvent(EVENT_ACTION)
					if r == EVENT_UNUSED then
						self:playSound("BUMP")
						self:getWindow():bumpRight()
					end
			       end,
			       true)

			tempDispatchTimer:start()
			
			--returning event_unused after a bump here seems like a bug, so I'm not returning it (plus it would break the 0-length timer idea)
--			return r
			return EVENT_CONSUME
		end

	elseif evtype == EVENT_MOUSE_DOWN or
		evtype == EVENT_MOUSE_MOVE or
		evtype == EVENT_MOUSE_DRAG then

		self.lastInputType = "mouse"

		if evtype == EVENT_MOUSE_DOWN then
			--sometimes up doesn't occur so we must again try to reset state
			-- note: sometimes down isn't called either (if drag starts outside of bounds), so bug still exists where scrollbar drag falsely continues
			self.sliderDragInProgress = false
			self.bodyDragInProgress = false

			--stop any running flick on contact
			if self.flickTimer:isRunning() then
				self:stopFlick(true)
				return EVENT_CONSUME
			end

		end

		--Note: on a down outside the scrollbar boundary, we don't want to forward this to the scrollbar
		--Normally that should never happen, but will if an up event is nevet sent to this widget, which would have cleared the
		-- sliderDragInProgress flag
		if self.scrollbar:mouseInside(event) or (self.sliderDragInProgress and evtype ~= EVENT_MOUSE_DOWN ) then
			if (evtype ~= EVENT_MOUSE_MOVE) then
				--allows slider drag to continue even when listitem area is entered
				-- a more comprehensive solution is needed so that drag of a slider is respected no matter
				-- where the mouse cursor is on the screen
				self.sliderDragInProgress = true
			end

			-- forward event to scrollbar
			local r = self.scrollbar:_event(event)
			_scrollList(self)
			if evtype == EVENT_MOUSE_DOWN then
				--slider doesnt' consume the DOWN, but we require it to be consumed so menu is marked as the mouse focus widget.
				r = EVENT_CONSUME
			end
			return r

		else
			--mouse is inside menu region
			local x,y,w,h = self:mouseBounds(event)
			local i = y / self.itemHeight --(h / self.numWidgets)

			local itemShift = math.floor(i)

			if not self:isTouchMouseEvent(event) then

				if evtype == EVENT_MOUSE_DRAG then
					self:setSelectedIndex(self.topItem + itemShift)
					_scrollList(self)
				elseif (itemShift >= 0 and itemShift < self.numWidgets) then
					-- menu selection follows mouse, but no scrolling occurs
					self:setSelectedIndex(self.topItem + itemShift)
				end
			else --touchpad - for now to test on desktop mouse Right-Click acts as single finger touch

				if evtype == EVENT_MOUSE_DOWN then
					self.dragOrigin.x, self.dragOrigin.y = event:getMouse();
					--self.dragYSinceShift = 0
					self.currentShiftDirection = 0

					resetFlickData(self.flickData)

					--don't highlight item right away (to avoid highlighting when finger go off screen and then
					-- on screen during a drag
					  -- first unhighlight last selected item - todo: try just setting style on current item instead of a full relayout
	                                self.usePressedStyle = false

	                                --unhighlight any selected item
	                                if _selectedItem(self) then
						_selectedItem(self):setStyleModifier(nil)
						_selectedItem(self):reDraw()
					end
					
					if self.selectItemAfterFingerDownTimer then
						self.selectItemAfterFingerDownTimer:stop()
					end
					self.selectItemAfterFingerDownTimer = Timer(100,
							       function()
									self:_selectAndHighlightItemUnderPointer(event)
							       end,
							       true)
				       self.selectItemAfterFingerDownTimer:start()

				elseif evtype == EVENT_MOUSE_DRAG then
					self.usePressedStyle = false

					if not self.bodyDragInProgress then
						self.bodyDragInProgress = true
						--unhighlight any selected item
						_selectedItem(self):setStyleModifier(nil)
					end

					if ( self.dragOrigin.y == nil) then
						--might have started drag outside of this textarea's bounds, so reset origin
						self.dragOrigin.x, self.dragOrigin.y = event:getMouse();
					end

					local mouseX, mouseY = event:getMouse()

					local dragAmountY = self.dragOrigin.y - mouseY

					--reset origin
					self.dragOrigin.x, self.dragOrigin.y = mouseX, mouseY

					updateFlickData(self.flickData, event)

					self:handleDrag(dragAmountY)
					
--					log:error("self.pixelOffsetY                              : ", self.pixelOffsetY)

                               end
			end
			return EVENT_CONSUME
		end
		
	elseif evtype == EVENT_MOUSE_UP then

		--todo: UP not called if we are outside widget bounds, need this widget to handle events when drag in progress
		self.dragOrigin.x, self.dragOrigin.y = nil, nil;

		local flickSpeed, flickDirection = getFlickSpeed(self.flickData, self.itemHeight)

		if flickSpeed then
			self:flick(flickSpeed, flickDirection)
		end

		resetFlickData(self.flickData)


		self.sliderDragInProgress = false
		self.bodyDragInProgress = false
		--turn off accel keys (may have been on from a scrollbar slide)
		if (self.accel or self.accelKey) then
			self.accel = false
			self.accelKey = nil
			self:reDraw()
		end
		return EVENT_UNUSED

	elseif evtype == EVENT_SHOW or
		evtype == EVENT_HIDE then

               if evtype == EVENT_SHOW then
			local window = self:getWindow()
			window:setIconWidget("xofy", self.xofy)
		end

		for i,widget in ipairs(self.widgets) do
			widget:_event(event)
		end

		self:reLayout()
		return EVENT_UNUSED
	end

	-- other events to selected widgets
	return _itemListener(self, _selectedItem(self), event)
end


function isTouchMouseEvent(self, mouseEvent)
	local x, y, fingerCount = mouseEvent:getMouse()

	return fingerCount ~= nil
end


function stopFlick(self, byFinger)

	self.flickTimer:stop()
	self.flickInterruptedByFinger = byFinger

	resetFlickData(self.flickData)
end


function updateFlickData(flickData, mouseEvent)
	local x, y = mouseEvent:getMouse()
	local ticks = mouseEvent:getTicks()

	--hack until reason for 0 ticks is resolved
	if (ticks == 0) then
		return
	end

	--hack until reason for false "far out of range" ticks is happening

	if #flickData.points >=1 then
		local previousTicks = flickData.points[#flickData.points].ticks
		if math.abs(ticks - previousTicks ) > 10000 then
			log:error("Erroneous tick value occurred, ignoring : ", ticks, "  after previuos tick value of: ", previousTicks)
			return
		end
	end

	table.insert(flickData.points, {y = y, ticks = ticks})
	if #flickData.points >= 20 then
		--only keep last 20 values
		table.remove(flickData.points, 1)
	end

end

function resetFlickData(flickData)
	flickData.points = {}
end

function getFlickSpeed(flickData, itemHeight)
	if not flickData.points or #flickData.points < 2 then
		return nil
	end


	local distance = flickData.points[#flickData.points].y - flickData.points[1].y
	local time = flickData.points[#flickData.points].ticks - flickData.points[1].ticks

	--speed = pixels/ms
	local speed = distance/time


	log:debug("Flick info: speed: ", speed, "  distance: ", distance, "  time: ", time )

	local direction = speed >= 0 and -1 or 1
	return math.abs(speed), direction
end



--if initialSpeed nil, then continue any existing flick. If non nil, start a new flick at that rate
function flick(self, initialSpeed, direction)
	if initialSpeed then
		self:stopFlick()
		if initialSpeed < FLICK_THRESHOLD_START_SPEED then
			log:debug("Under threshold, not flicking: ", initialSpeed )

			return
		end

		self.flickInitialSpeed = initialSpeed
		self.flickDirection = direction
		self.flickTimer:start()
		self.flickInitialScrollT = Framework:getTicks()

		self.flickLastY = 0
		self.flickInitialDecelerationScrollT = nil
		self.flickPreDecelY = 0

		local decelTime = FLICK_DECEL_TOTAL_TIME + math.abs(FLICK_SPEED_DECEL_TIME_FACTOR * self.flickInitialSpeed)
		self.flickAccelRate = -self.flickInitialSpeed / decelTime
		log:debug("*****Starting flick - decelTime: ", decelTime )
	end

	--continue flick
	local now = Framework:getTicks()

	--slow speed if past decel time
	if self.flickInitialDecelerationScrollT == nil and now - self.flickInitialScrollT > FLICK_DECEL_START_TIME then
		log:debug("*****Starting flick slow down")
		self.flickInitialDecelerationScrollT = now
	end

	local flickCurrentY
	if not self.flickInitialDecelerationScrollT then
		--still at full speed
		flickCurrentY = self.flickInitialSpeed * (now - self.flickInitialScrollT)
		self.flickPreDecelY = flickCurrentY
	else
		local elapsedTime = now - self.flickInitialDecelerationScrollT

		-- y = v0*t +.5 * a * t^2
		flickCurrentY = self.flickPreDecelY + self.flickInitialSpeed * elapsedTime + (.5 * self.flickAccelRate * elapsedTime * elapsedTime )

		--v = v0 + at
		local flickCurrentSpeed = self.flickInitialSpeed + (self.flickAccelRate * elapsedTime)
		if flickCurrentSpeed <= FLICK_STOP_SPEED then
			log:debug("*******Stopping Flick at slow down point. current speed:", flickCurrentSpeed)
			self:stopFlick()
			return
		end
	end


	local pixelOffset = math.floor(flickCurrentY - self.flickLastY)
	self:handleDrag(self.flickDirection * pixelOffset)

	self.flickLastY = self.flickLastY + pixelOffset

	if (self.selected == self.listSize and self.flickDirection > 0)
		or (self.selected == 1 and self.flickDirection < 0) then
		--stop at boundaries
		log:debug("*******Stopping Flick at boundary") -- need a ui cue that this has happened
		self:stopFlick()
	end
end


--[[

=head2 jive.ui.Menu(style)

Constructs a new Menu object. I<style> is the widgets style.

=cut
--]]
function __init(self, style, itemRenderer, itemListener, itemAvailable)
	_assert(type(style) == "string")
	_assert(type(itemRenderer) == "function")
	_assert(type(itemListener) == "function")
	_assert(itemAvailable == nil or type(itemAvailable) == "function")

	local obj = oo.rawnew(self, Widget(style))
	obj.irAccel = IRMenuAccel()
	
	obj.scroll = ScrollAccel(function(...)
					 if itemAvailable then
						 
					 else
						 return true
					 end
				 end)
	obj.scrollbar = Scrollbar("scrollbar",
				  function(_, value)
  					  obj.accel = true
					  obj:setSelectedIndex(value + 1) -- value comes in zero based, one based is needed
				  end)

	obj.xofy = Label("xofy", "")

	obj.scrollbar.parent = obj
	obj.layoutRoot = true
	obj.closeable = true

	obj.itemRenderer = itemRenderer
	obj.itemListener = itemListener
	if itemAvailable then
		obj.scroll = ScrollAccel(function(...) return itemAvailable(obj, obj.list, ...) end)
	else
		obj.scroll = ScrollAccel()
	end


	obj.list = nil
	obj.listSize = 0
	obj.scrollDir = 0

	obj.widgets = {}        -- array of widgets
	obj.lastWidgets = {}    -- hash of widgets
	obj.numWidgets = 0      -- number of visible widges
	obj.topItem = 1         -- index of top widget
	obj.selected = nil      -- index of selected widget
	obj.accel = false       -- true if the window is accelerated
	obj.dir = 0             -- last direction of scrolling

	obj.usePressedStyle = true

	obj.dragOrigin = {}
	obj.dragYSinceShift = 0
	obj.pixelOffsetY = 0
	obj.currentShiftDirection = 0

	obj.flickData = {}
	obj.flickData.points = {}

	-- timer to drop out of accelerated mode
	obj.accelTimer = Timer(200,
			       function()
				       obj.accel = false
				       obj:reLayout()
			       end,
			       true)
			       
	obj.accelKeyTimer = Timer(500,
					function()
				    	obj.accelKey = nil
						obj:reLayout()	
					end,
					true)
	obj.flickTimer = Timer(25,
			       function()
			                obj:flick()
			       end)

	obj:addListener(EVENT_ALL,
			 function (event)
				return (_eventHandler(obj, event))
			 end)
	
	return obj
end


--[[

=head2 jive.ui.Menu:setItems(list, listSize, min, max)

Set the items in the menu. list is the data structure containing the menu data
in a format suitable for the itemRenderer and itemListener. listSize is the
total number of items in the menu. Optionally min and max indicate the range of
menu items that have changed.

=cut
--]]
function setItems(self, list, listSize, min, max)
	self.list = list
	self.listSize = listSize

	if min == nil then
		min = 1
	end
	if max == nil then
		max = listSize
	end

	-- check if the scrollbar position is out of range
	if self.selected and self.selected > listSize then
		self.selected = listSize
	end

	-- update if changed items are visible
	local topItem, botItem = self:getVisibleIndicies()
	if not (max < topItem or min > botItem) then
		self:reLayout()
	end
end


--[[

=head2 jive.ui.Menu:setCloseable(isCloseable)

Sets if this menu is closeable. A closeable menu will pop from the window stack on the left button, if it is not closeable the menu will bump instead.

=cut
--]]
function setCloseable(self, isCloseable)
	_assert(type(isCloseable) == "boolean")

	self.closeable = isCloseable
end


--[[

=head2 jive.ui.Menu:getVisibleIndices()

Returns the indicies of the top and bottom visible items.

=cut
--]]
function getVisibleIndicies(self)
	local min = self.topItem
	local max = min + self.numWidgets - 1
	
	if max > self.listSize then
		return min, min + self.listSize
	else
		return min, max
	end
end


--[[

=head2 jive.ui.Menu:isScrollable()

Returns true if the menu is scrollable, otherwise it returns false.

=cut
--]]
function isScrollable(self)
	return self.listSize > self.numWidgets
end


--[[

=head2 jive.ui.Menu:getSelectedIndex()

Returns the index of the selected item.

=cut
--]]
function getSelectedIndex(self)
	return self.selected
end


--[[

=head2 jive.ui.Menu:getSelectedItem()

Returns the widget of the selected item.

=cut
--]]
function getSelectedItem(self)
	return _selectedItem(self)
end

--[[

=head2 jive.ui.Menu:getItems()

Returns the list items from a menu

=cut
--]]
function getItems(self)
	return self.list
end

--[[

=head2 jive.ui.Menu:setSelectedIndex(index)

Sets I<index> as the selected menu item. 

=cut
--]]
function setSelectedIndex(self, index)
	_assert(type(index) == "number", "setSelectedIndex index is not a number")

	if index >= 1 and index <= self.listSize then
		self.selected = index
		self:reLayout()
	end
end


function isAccelerated(self)
	return self.accel, self.dir, self.selected
end


--[[

=head2 jive.ui.Menu:lock(self, cancel)

Lock the menu. Pressing back unlocks it and calls the I<cancel> closure. The style of the selected menu item is changed. This can be used for a loading animation.

=cut
--]]
function lock(self, cancel)
	self.locked = cancel or true
	self:reLayout()

	-- don't allow screensaver while locked
	local window = self:getWindow()
	self.lockedScreensaver = window:getAllowScreensaver()
	window:setAllowScreensaver(false)
end


--[[

=head2 jive.ui.Menu:lock(self, cancel)

Unlock the menu.

=cut
--]]
function unlock(self)
	-- restore screensaver setting
	local window = self:getWindow()
	window:setAllowScreensaver(self.lockedScreensaver)
	self.lockedScreensaver = nil

	self.locked = nil
	self:reLayout()
end


--[[

=head2 jive.ui.Menu:scrollBy(scroll, allowMultiple, allowMultiple, isNewOperation, forceAccel)

Scroll the menu by I<scroll> items. If I<scroll> is negative the menu scrolls up, otherwise the menu scrolls down. By
 default, restricts to scrolling one item unless at the edge of the visible list. If I<allowMultiple> is non-nil,
 ignore that behavior and scroll the requested scroll amount.

=cut
--]]
function scrollBy(self, scroll, allowMultiple, isNewOperation, forceAccel)
	_assert(type(scroll) == "number")

	local selected = (self.selected or 1)

	-- acceleration
	local now = Framework:getTicks()
	local dir = scroll > 0 and 1 or -1

--[[
	if dir == self.scrollDir and now - self.scrollLastT < 250 then
		if self.scrollAccel then
			self.scrollAccel = self.scrollAccel + 1
			if     self.scrollAccel > 50 then
				scroll = dir * math.max(math.ceil(self.listSize/50), math.abs(scroll) * 16)
			elseif self.scrollAccel > 40 then
				scroll = scroll * 16
			elseif self.scrollAccel > 30 then
				scroll = scroll * 8
			elseif self.scrollAccel > 20 then
				scroll = scroll * 4
			elseif self.scrollAccel > 10 then
				scroll = scroll * 2
			end
		else
			self.scrollAccel = 1
		end
	else
		self.scrollAccel = nil
	end
--]]
	self.scrollDir   = dir
	self.scrollLastT = now

	-- restrict to scrolling one item unless at the edge of the
	-- visible list, to stop it from visibly missing items when using the controller scroll wheel.
	if scroll > 0 then
		self.dir = 1
		self.accel = scroll > 1

		if not allowMultiple and selected < self.topItem + self.numWidgets - 2 then
			scroll = 1
		end

	elseif scroll < 0 then
		self.dir = -1
		self.accel = scroll < -1

		if not allowMultiple and selected > self.topItem + 1 then
			scroll = -1
		end
	else
		self.dir = 0
		self.accel = false
	end

	if forceAccel then
		self.accel = true
	end

	if self.accel then
		self.accelTimer:restart()
		self.accelKeyTimer:restart()
	else
		self.accelTimer:stop()
	end

	selected = selected  + scroll

	--for input sources such as ir remote, follow the "ir remote" list behavior seen on classic players
	if isNewOperation == false then
		if selected > self.listSize then
			selected = self.listSize
		elseif selected < 1 then
			selected = _coerce(1, self.listSize)
		end	
	elseif isNewOperation == true then
		if selected > self.listSize then
			selected = _coerce(1, self.listSize)
		elseif selected < 1 then
			selected = self.listSize
		end	
		   
	else -- isNewOperation nil, so use breakthrough barrier
		-- virtual barrier when scrolling off the ends of the list
		if self.barrier and Framework:getTicks() > self.barrier + 1000 then
			self.barrier = nil
		end
	
		if selected > self.listSize then
			selected = self.listSize
			if self.barrier == nil then
				self.barrier = Framework:getTicks()
			elseif Framework:getTicks() > self.barrier + 500 then
				selected = _coerce(1, self.listSize)
				self.barrier = nil
			end
	
		elseif selected < 1 then
			selected = _coerce(1, self.listSize)
			if self.barrier == nil then
				self.barrier = Framework:getTicks()
			elseif Framework:getTicks() > self.barrier + 500 then
				selected = self.listSize
				self.barrier = nil
			end
	
		else
			self.barrier = nil
		end
	end
	

	-- if selection has change, play click and redraw
	if (self.selected ~= nil and selected ~= self.selected) or (self.selected == nil and selected ~= 0) then
		if not self.bodyDragInProgress and not self.flickTimer:isRunning() then
			--todo come up with more comprehensive "when to click" design once the requirement is better understood
			self:playSound("CLICK")
		end
		self.selected = selected

		_scrollList(self)
		self:reLayout()
	end
end


-- move the list to keep the selection in view, called during layout
function _scrollList(self)

	-- empty list, nothing to do
	if self.listSize == 0 then
		return
	end

	-- make sure selected stays in bounds
	local selected = _coerce(self.selected or 1, self.listSize)
	local topItem = self.topItem

	-- show the first item if the first item is selected
	if selected == 1 then
		topItem = 1
		
	-- otherwise, try to leave one item above the selected one (we've scrolled out of the view)
	elseif selected <= topItem then
		-- if we land here, selected > 1 so topItem cannot become < 1
		topItem = selected - 1

	-- show the last item if it is selected
	elseif selected == self.listSize then
		if self.listSize < self.numWidgets or self.numWidgets == 0 then
			topItem = 1
		else
			topItem = self.listSize - self.numWidgets + 1
		end
	
	-- otherwise, try to leave one item below the selected one (we've scrolled out of the view)
	elseif selected >= topItem + self.numWidgets - 1 then
		topItem = selected - self.numWidgets + 2
	end

	self.topItem = topItem
end


function _updateWidgets(self)

	local indexSize = self.numWidgets + 1 -- one extra for smooth scrolling
	local min = self.topItem
	local max = self.topItem + indexSize - 1
	if max > self.listSize then
		max = self.listSize
	end
	local indexSize = (max - min) + 1


	-- create index list
	local indexList = {}
	for i = min,max do
		indexList[#indexList + 1] = i
	end

	local lastSelected = self._lastSelected
	local lastSelectedIndex = self._lastSelectedIndex
	local lastHighlightedIndex = self._lastHighlightedIndex
	local nextSelectedIndex = self.selected or 1

	-- clear focus -- todo support "no highlight scroll"
	if lastSelectedIndex ~= nextSelectedIndex then
		if lastSelected then
			lastSelected:setStyleModifier(nil)
			_itemListener(self, lastSelected, Event:new(EVENT_FOCUS_LOST))
		end
	end

	-- reorder widgets to maintain the position of the selected widgets
	-- this avoids having to change the widgets skin modifier, and
	-- therefore avoids having to reskin the widgets during scrolling.
	if self._lastSelectedOffset then
		local lastSelectedOffset = self._lastSelectedOffset
		local selectedOffset = self.selected and self.selected - self.topItem + 1 or self.topItem

		if lastSelectedOffset ~= selectedOffset then
			self.widgets[lastSelectedOffset], self.widgets[selectedOffset] = self.widgets[selectedOffset], self.widgets[lastSelectedOffset]

			self._lastSelected = self.widgets[lastSelectedOffset]
		end
	end

	-- render menu widgets
	self.itemRenderer(self, self.list, self.widgets, indexList, indexSize)

	-- show or hide widgets
	local nextWidgets = {}
	local lastWidgets = self.lastWidgets

	for i = 1, indexSize do
		
		local widget = self.widgets[i]
		
		if widget then
			if widget.parent ~= self then
				widget.parent = self
				widget:dispatchNewEvent(EVENT_SHOW)
			end

			lastWidgets[widget] = nil
			nextWidgets[widget] = 1
		end
	end

	for widget,i in pairs(lastWidgets) do
		widget:dispatchNewEvent(EVENT_HIDE)
		widget.parent = nil
	end

	self.lastWidgets = nextWidgets

	-- unreference menu widgets out off stage
	for i = indexSize + 1, #self.widgets do
		self.widgets[i] = nil
	end


	local nextSelected = _selectedItem(self)

	-- clear selection
	if lastSelected and lastSelected ~= nextSelected then
		lastSelected:setStyleModifier(nil)
	end

	-- set selection and focus
	if nextSelected then
		if self.accel then
			self.accelKey = nextSelected:getAccelKey()
		end

		if self.locked then
			nextSelected:setStyleModifier("locked")
		else
			if self.usePressedStyle then
				nextSelected:setStyleModifier("pressed")
			else
				nextSelected:setStyleModifier("selected")
			end
		end

		if self.lastInputType == "mouse" then
			if self.usePressedStyle and lastHighlightedIndex ~= nextSelectedIndex then
				_itemListener(self, nextSelected, Event:new(EVENT_FOCUS_GAINED))
			end
		else
			if lastSelectedIndex ~= nextSelectedIndex then
				_itemListener(self, nextSelected, Event:new(EVENT_FOCUS_GAINED))
			end
		end
	end

	self._lastSelected = nextSelected
	self._lastSelectedIndex = nextSelectedIndex
	if self.usePressedStyle then
		self._lastHighlightedIndex = nextSelectedIndex
	end
	self._lastSelectedOffset = self.selected and self.selected - self.topItem + 1 or self.topItem

	-- update scrollbar
	self.scrollbar:setScrollbar(0, self.listSize, self.topItem, self.numWidgets)
	self.xofy:setValue(nextSelectedIndex .. " of " .. self.listSize)

--	log:warn("_update menu:\n", self:dump())


end


function __tostring(self)
	return "Menu(" .. self.listSize .. ")"
end


--[[ C optimized:

jive.ui.Icon:pack()
jive.ui.Icon:draw()

--]]

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

