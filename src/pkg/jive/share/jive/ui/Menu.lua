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
local assert, ipairs, pairs, string, tostring, type = assert, ipairs, pairs, string, tostring, type

local oo                   = require("loop.simple")
local debug                = require("debug")
                           
local table                = require("jive.utils.table")
local Framework            = require("jive.ui.Framework")
local Widget               = require("jive.ui.Widget")
local Scrollbar            = require("jive.ui.Scrollbar")

local log                  = require("jive.utils.log").logger("ui")
                           
local EVENT_ALL            = jive.ui.EVENT_ALL
local EVENT_ACTION         = jive.ui.EVENT_ACTION
local EVENT_SCROLL         = jive.ui.EVENT_SCROLL
local EVENT_KEY_PRESS      = jive.ui.EVENT_KEY_PRESS
local EVENT_SHOW           = jive.ui.EVENT_SHOW
local EVENT_HIDE           = jive.ui.EVENT_HIDE
local EVENT_SERVICE_JNT    = jive.ui.EVENT_SERVICE_JNT
local EVENT_FOCUS_GAINED = jive.ui.EVENT_FOCUS_GAINED
local EVENT_FOCUS_LOST   = jive.ui.EVENT_FOCUS_LOST

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


local function _itemListener(self, event)

	local r = EVENT_UNUSED

	item = _selectedItem(self)

	if item then
		r = self.itemListener(self, item, self.list, self.selected or 1, event)

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
			self:scrollBy(event:getScroll())
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
			if keycode == KEY_UP then
				self:scrollBy( -1 )
				return EVENT_CONSUME

			elseif keycode == KEY_DOWN then
				self:scrollBy( 1 )
				return EVENT_CONSUME

			elseif keycode == KEY_GO or
				keycode == KEY_RIGHT then

				local r = EVENT_UNUSED

				r = self:dispatchNewEvent(EVENT_ACTION)

				if r == EVENT_UNUSED then
					self:getWindow():bumpRight()
				end
				return r

			elseif keycode == KEY_BACK or
				keycode == KEY_LEFT then
				if self.closeable then
					self:hide()
					return EVENT_CONSUME
				else
					self:getWindow():bumpLeft()
				end

			else
				-- other keys to selected widgts
				return _itemListener(self, event)
			end
		end

	elseif evtype == EVENT_SHOW or
		evtype == EVENT_HIDE then

		for i,widget in ipairs(self.widgets) do
			widget:_event(event)
		end

		return EVENT_UNUSED
		
	-- swallow these?
	elseif evtype == EVENT_SERVICE_JNT  then
		return EVENT_UNUSED
	end

	-- other events to selected widgets
	return _itemListener(self, event)
end


--[[

=head2 jive.ui.Menu(style)

Constructs a new Menu object. I<style> is the widgets style.

=cut
--]]
function __init(self, style, itemRenderer, itemListener)
	assert(type(style) == "string")
	assert(type(itemRenderer) == "function")
	assert(type(itemListener) == "function")

	local obj = oo.rawnew(self, Widget(style))
	obj.scrollbar = Scrollbar("scrollbar")
	obj.scrollbar.parent = obj
	obj.layoutRoot = true
	obj.closeable = true

	obj.itemRenderer = itemRenderer
	obj.itemListener = itemListener

	obj.list = nil
	obj.listSize = 0

	obj.widgets = {}        -- array of widgets
	obj.lastWidgets = {}    -- hash of widgets
	obj.numWidgets = 0      -- number of visible widges
	obj.topItem = 1         -- index of top widget
	obj.selected = nil      -- index of selected widget

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

	-- update selection
	self:scrollBy(0)

	-- update if changed items are visible
	local topItem, botItem = self:getVisibleIndicies()
	if min >= topItem and min <= botItem
		or max >= topItem and max <= botItem then

		self:rePrepare()
	end
end


--[[

=head2 jive.ui.Menu:setCloseable(isCloseable)

Sets if this menu is closeable. A closeable menu will pop from the window stack on the left button, if it is not closeable the menu will bump instead.

=cut
--]]
function setCloseable(self, isCloseable)
	assert(type(isCloseable) == "boolean")

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

=head2 jive.ui.Menu:setSelectedIndex(index)

Sets I<index> as the selected menu item. 

=cut
--]]
function setSelectedIndex(self, index)
	assert(type(index) == "number", "setSelectedIndex index is not a number")

	if index <= self.listSize then
		self:scrollBy(index - (self.selected or 1))
	end
end


--[[

=head2 jive.ui.Menu:lock(self, cancel)

Lock the menu. Pressing back unlocks it and calls the I<cancel> closure. The style of the selected menu item is changed. This can be used for a loading animation.

=cut
--]]
function lock(self, cancel)
	self.locked = cancel or true
	self:reLayout()
end


--[[

=head2 jive.ui.Menu:lock(self, cancel)

Unlock the menu.

=cut
--]]
function unlock(self)
	self.locked = nil
	self:reLayout()
end


--[[

=head2 jive.ui.Menu:scrollBy(scroll)

Scroll the menu by I<scroll> items. If I<scroll> is negative the menu scrolls up, otherwise the menu scrolls down.

=cut
--]]
function scrollBy(self, scroll)
	assert(type(scroll) == "number")

	-- empty list, nothing to do
	if self.listSize == 0 then
		return
	end

	local selected = self.selected or 1
	local topItem = self.topItem

	local lastSelected = selected

	-- make sure selected stays in bounds
	selected = _coerce(selected + scroll, self.listSize)

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
		topItem = _coerce(topItem + scroll, self.listSize - self.numWidgets + 1)
	end

	if lastSelected ~= selected then
		self:playSound("CLICK")
		self.selected = selected
	end
	self.topItem = topItem

	self:reLayout()
end


function _updateWidgets(self)
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


	-- render menu widgets
	self.itemRenderer(self, self.widgets, indexList, indexSize, self.list)


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


	local lastSelected = self._lastSelected
	local nextSelected = _selectedItem(self)

	-- clear selection and focus
	if lastSelected ~= nextSelected or self._lastSelectedIndex ~= self.selected then
		if lastSelected then
			lastSelected:setStyleModifier(nil)
			lastSelected:dispatchNewEvent(EVENT_FOCUS_LOST)
		end

		nextSelected:dispatchNewEvent(EVENT_FOCUS_GAINED)
	end

	-- set selection and focus
	if nextSelected then
		if self.locked then
			nextSelected:setStyleModifier("locked")
		else
			nextSelected:setStyleModifier("selected")
		end
	end
	self._lastSelected = nextSelected
	self._lastSelectedIndex = self.selected

	-- update scrollbar
	self.scrollbar:setScrollbar(0, self.listSize, self.topItem, self.numWidgets)
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

