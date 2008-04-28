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
local _assert, ipairs, pairs, string, tostring, type = _assert, ipairs, pairs, string, tostring, type

local oo                   = require("loop.simple")
local debug                = require("jive.utils.debug")
                           
local table                = require("jive.utils.table")
local Framework            = require("jive.ui.Framework")
local Event                = require("jive.ui.Event")
local Widget               = require("jive.ui.Widget")
local Scrollbar            = require("jive.ui.Scrollbar")
local ScrollAccel          = require("jive.ui.ScrollAccel")
local Timer                = require("jive.ui.Timer")

local log                  = require("jive.utils.log").logger("ui")

local math                 = require("math")


local EVENT_ALL            = jive.ui.EVENT_ALL
local EVENT_ACTION         = jive.ui.EVENT_ACTION
local EVENT_SCROLL         = jive.ui.EVENT_SCROLL
local EVENT_KEY_PRESS      = jive.ui.EVENT_KEY_PRESS
local EVENT_SHOW           = jive.ui.EVENT_SHOW
local EVENT_HIDE           = jive.ui.EVENT_HIDE
local EVENT_SERVICE_JNT    = jive.ui.EVENT_SERVICE_JNT
local EVENT_FOCUS_GAINED   = jive.ui.EVENT_FOCUS_GAINED
local EVENT_FOCUS_LOST     = jive.ui.EVENT_FOCUS_LOST
local EVENT_MOUSE_PRESS    = jive.ui.EVENT_MOUSE_PRESS
local EVENT_MOUSE_DOWN     = jive.ui.EVENT_MOUSE_DOWN
local EVENT_MOUSE_MOVE     = jive.ui.EVENT_MOUSE_MOVE
local EVENT_MOUSE_DRAG     = jive.ui.EVENT_MOUSE_DRAG

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

-- _eventHandler
-- manages all menu events
local function _eventHandler(self, event)

	local evtype = event:getType()

	if evtype == EVENT_SCROLL then
		if self.locked == nil then
			self:scrollBy(self.scroll:event(event, self.topItem, self.selected or 1, self.numWidgets, self.listSize))
			return EVENT_CONSUME
		end

	elseif evtype == EVENT_KEY_PRESS then
		local keycode = event:getKeycode()

		if self.locked ~= nil then
			if keycode == KEY_BACK or
				keycode == KEY_LEFT then

				if type(self.locked) == "function" then
					self.locked(self)
				end
				self:unlock()

				return EVENT_CONSUME
			end
		else
			-- first send keys to selected widgets
			local r = _itemListener(self, _selectedItem(self), event)
			if r ~= EVENT_UNUSED then
				return r
			end

			-- otherwise try default behaviour
			if keycode == KEY_UP then
				self:scrollBy( -1 )
				return EVENT_CONSUME

			elseif keycode == KEY_DOWN then
				self:scrollBy( 1 )
				return EVENT_CONSUME

			elseif keycode == KEY_GO or 
				keycode == KEY_PLAY or
				 keycode == KEY_RIGHT then

				r = self:dispatchNewEvent(EVENT_ACTION)

				if r == EVENT_UNUSED then
					self:playSound("BUMP")
					self:getWindow():bumpRight()
				end
				return r

			elseif keycode == KEY_BACK or
				keycode == KEY_LEFT then
				if self.closeable then
					self:playSound("WINDOWHIDE")
					self:hide()
					return EVENT_CONSUME
				else
					self:playSound("BUMP")
					self:getWindow():bumpLeft()
				end
			end
		end

	elseif evtype == EVENT_MOUSE_PRESS then

		if self.scrollbar:mouseInside(event) then
			-- forward event to scrollbar
			self.scrollbar:_event(event)

		else
			r = self:dispatchNewEvent(EVENT_ACTION)

			if r == EVENT_UNUSED then
				self:playSound("BUMP")
				self:getWindow():bumpRight()
			end
			return r
		end

	elseif evtype == EVENT_MOUSE_DOWN or
		evtype == EVENT_MOUSE_MOVE or
		evtype == EVENT_MOUSE_DRAG then

		if self.scrollbar:mouseInside(event) then
			-- forward event to scrollbar
			return self.scrollbar:_event(event)

		else
			-- menu selection follows mouse
			local x,y,w,h = self:mouseBounds(event)
			local i = y / self.itemHeight --(h / self.numWidgets)

			self:setSelectedIndex(self.topItem + math.floor(i))

			if evtype == EVENT_MOUSE_DRAG then
				_scrollList(self)
			end

			return EVENT_CONSUME
		end

	elseif evtype == EVENT_SHOW or
		evtype == EVENT_HIDE then

		for i,widget in ipairs(self.widgets) do
			widget:_event(event)
		end

		return EVENT_UNUSED
	end

	-- other events to selected widgets
	return _itemListener(self, _selectedItem(self), event)
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
	obj.scroll = ScrollAccel(function(...)
					 if itemAvailable then
						 
					 else
						 return true
					 end
				 end)
	obj.scrollbar = Scrollbar("scrollbar",
				  function(_, value)
					  obj:setSelectedIndex(value)
				  end)

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

	obj:addListener(EVENT_ALL,
			 function (event)
				return _eventHandler(obj, event)
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

=head2 jive.ui.Menu:scrollBy(scroll)

Scroll the menu by I<scroll> items. If I<scroll> is negative the menu scrolls up, otherwise the menu scrolls down.

=cut
--]]
function scrollBy(self, scroll)
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
	-- visible list
	if scroll > 0 then
		self.dir = 1
		self.accel = scroll > 1

		if selected < self.topItem + self.numWidgets - 2 then
			scroll = 1
		end

	elseif scroll < 0 then
		self.dir = -1
		self.accel = scroll < -1

		if selected > self.topItem + 1 then
			scroll = -1
		end
	else
		self.dir = 0
		self.accel = false
	end

	if self.accel then
		self.accelTimer:restart()
		self.accelKeyTimer:restart()
	else
		self.accelTimer:stop()
	end

	selected = selected  + scroll

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

	

	-- if selection has change, play click and redraw
	if (self.selected ~= nil and selected ~= self.selected) or (self.selected == nil and selected ~= 0) then
		self:playSound("CLICK")
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

	-- update the list to keep the selection in view
	local selected = _coerce(self.selected or 1, self.listSize)
	if selected < self.topItem
		or selected >= self.topItem + self.numWidgets then
		_scrollList(self)
	end

	local indexSize = self.numWidgets
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
	local nextSelectedIndex = self.selected or 1

	-- clear focus
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
			nextSelected:setStyleModifier("selected")
		end

		if lastSelectedIndex ~= nextSelectedIndex then
			_itemListener(self, nextSelected, Event:new(EVENT_FOCUS_GAINED))
		end
	end

	self._lastSelected = nextSelected
	self._lastSelectedIndex = nextSelectedIndex
	self._lastSelectedOffset = self.selected and self.selected - self.topItem + 1 or self.topItem

	-- update scrollbar
	self.scrollbar:setScrollbar(0, self.listSize, self.topItem, self.numWidgets)

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

