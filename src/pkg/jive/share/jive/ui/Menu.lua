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
local assert, ipairs, string, tostring, type = assert, ipairs, string, tostring, type

local oo              = require("loop.simple")
local debug           = require("debug")

local table           = require("jive.utils.table")
local Widget          = require("jive.ui.Widget")
local Slider          = require("jive.ui.Slider")

local log             = require("jive.utils.log").logger("ui")

local EVENT_ALL       = jive.ui.EVENT_ALL
local EVENT_ACTION    = jive.ui.EVENT_ACTION
local EVENT_SCROLL    = jive.ui.EVENT_SCROLL
local EVENT_KEY_PRESS = jive.ui.EVENT_KEY_PRESS
local EVENT_SHOW      = jive.ui.EVENT_SHOW
local EVENT_HIDE      = jive.ui.EVENT_HIDE

local EVENT_CONSUME   = jive.ui.EVENT_CONSUME
local EVENT_UNUSED    = jive.ui.EVENT_UNUSED

local KEY_FWD         = jive.ui.KEY_FWD
local KEY_REW         = jive.ui.KEY_REW
local KEY_GO          = jive.ui.KEY_GO
local KEY_BACK        = jive.ui.KEY_BACK
local KEY_UP          = jive.ui.KEY_UP
local KEY_DOWN        = jive.ui.KEY_DOWN
local KEY_LEFT        = jive.ui.KEY_LEFT
local KEY_RIGHT       = jive.ui.KEY_RIGHT


-- our class
module(...)
oo.class(_M, Widget)


-- _eventHandler
-- manages all menu events
local function _eventHandler(self, event)

	local type = event:getType()

	if type == EVENT_SCROLL then
		self:scrollBy(event:getScroll())
		return EVENT_CONSUME

	elseif type == EVENT_KEY_PRESS then
		local keycode = event:getKeycode()

		if keycode == KEY_UP then
			self:scrollBy( -1 )
			return EVENT_CONSUME

		elseif keycode == KEY_DOWN then
			self:scrollBy( 1 )
			return EVENT_CONSUME

		elseif keycode == KEY_GO or
			keycode == KEY_RIGHT then
			local item = self:getSelectedItem()

			local r = EVENT_UNUSED
			if item then
				r = item:dispatchNewEvent(EVENT_ACTION)
			end

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
			local item = self:getSelectedItem()
			if item then
				return item:_event(event)
			end

		end

	elseif type == EVENT_SHOW or
		type == EVENT_HIDE then

		local t,b = self:getVisibleItems()
		for i = t,b do
			if self.items[i].widget then
				self.items[i].widget:_event(event)
			end
		end

		return EVENT_UNUSED
	end

	-- other events to selected widgets
	local item = self:getSelectedItem()
	if item then
		return item:_event(event)
	end

	return EVENT_UNUSED
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


-- _safeIndex
-- returns array[index] if index is in array bounds, nil otherwise
local function _safeIndex(array, index)
	if index and index>0 and index<=#array then
		return array[index]
	end
--	log:warn("_safeIndex failed - ", debug.traceback())
	return nil
end

--[[

=head2 jive.ui.Menu(style)

Constructs a new Menu object. I<style> is the widgets style.

=cut
--]]
function __init(self, style)
	assert(type(style) == "string")

	local obj = oo.rawnew(self, Widget(style))
	obj.scrollbar = Slider("scrollbar")
	obj.scrollbar.parent = obj
	
	obj.items = {}
	obj.itemStyles = {}
	obj.selected = 1

	obj.closeable = true
	obj.topItem = 1
	obj.visibleItems = 1

	obj:addListener(EVENT_ALL,
			 function (event)
				return _eventHandler(obj, event)
			 end)
	
	return obj
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

=head2 jive.ui.Menu:numItems()

Returns the top number of items in the menu.

=cut
--]]
function numItems(self)
	return #self.items
end


--[[

=head2 jive.ui.Menu:getVisibleItems()

Returns the indexes of the top and bottom visible items.

=cut
--]]
function getVisibleItems(self)
	return self.topItem, (self.topItem + self.visibleItems - 1)
end


--[[

=head2 jive.ui.Menu:isScrollable()

Returns true if the menu is scrollable, otherwise it returns false.

=cut
--]]
function isScrollable(self)
	return #self.items > self.visibleItems
end


--[[

=head2 jive.ui.Menu:getIndex(item)

Returns the index of item I<item>, or nil if it is not in this menu.

=cut
--]]
function getIndex(self, item)
	assert(oo.instanceof(item, Widget))

	for k,v in ipairs(self.items) do
		if item == v then
			return k
		end
	end

	return nil
end


--[[

=head2 jive.ui.Menu:getItem(index)

Returns the item at the index I<index>.

=cut
--]]
function getItem(self, index)
	assert(type(index) == "number")

	return _safeIndex(self.items, index)
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

Returns the selected item.

=cut
--]]
function getSelectedItem(self)
	return self.items[self.selected]
end


--[[

=head2 jive.ui.Menu:setSelectedIndex(index)

Sets I<index> as the selected menu item. 

=cut
--]]
function setSelectedIndex(self, index)
	assert(type(index) == "number", "setSelectedIndex index is not a number")

	if _safeIndex(self.items, index) then
		self.selected = index
		self:scrollBy(0)
	end
end


--[[

=head2 jive.ui.Menu:setSelectedItem(item)

Sets I<item> as the selected item in the menu.

=cut
--]]
function setSelectedItem(self, item)
	assert(oo.instanceof(item, Widget))

	local index = self:getIndex(item)

	if index then
		self.selected = index
		self:scrollBy(0)
	else
		log:warn("setSelectedItem item not found in the menu!")
	end
end


--[[

=head2 jive.ui.Menu:addItem(item)

Add I<item> to the end of the menu.

=cut
--]]
function addItem(self, item)
	assert(oo.instanceof(item, Widget))
	
	return self:insertItem(item, nil)
end


--[[

=head2 jive.ui.Menu:insertItem(item, index)

Insert I<item> into the menu at I<index>. The item can be any type of widget.

=cut
--]]
function insertItem(self, item, index)
	assert(oo.instanceof(item, Widget))
	assert(index == nil or type(index) == "number")
	assert(item.parent == nil, "item already added to a menu")
		
	if index == nil then
		table.insert(self.items, item)
	else
		table.insert(self.items, _coerce(index, #self.items), item)
	end

	item.parent = self

	-- TODO: maintain selection

	self:layout()

	return item
end


--[[

=head2 jive.ui.Menu:replaceIndex(item, index)

Replace the item at I<index> with I<item>.

=cut
--]]
function replaceIndex(self, item, index)
	assert(oo.instanceof(item, Widget))
	assert(index and type(index) == "number")
	assert(item.parent == nil, "Widget already added")

	local lastItem = _safeIndex(self.items, index)
	if lastItem ~= nil then
		lastItem.parent = nil

		self.items[index] = item
		item.parent = self
	
		self:layout()
	end
end


--[[

=head2 jive.ui.Menu:removeIndex(index)

Remove the item at I<index> from the menu. Returns the item removed from
the menu.

=cut
--]]
function removeIndex(self, index)
	assert(type(index) == "number")

	if _safeIndex(self.items, index) then

		local item = table.remove(self.items, index)
		if item ~= nil then
			item.parent = nil

			-- TODO: maintain selection
	
			self:layout()

			return item
		end
	end
	return nil
end


--[[

=head2 jive.ui.Menu:removeItem(item)

Remove I<item> from the menu. Returns the item removed from the menu.

=cut
--]]
function removeItem(self, item)
	assert(oo.instanceof(item, Widget))

	local index = self:getIndex(item)
	if index ~= nil then
		return self:removeIndex(index)
	else
		return nil
	end
end


--[[

=head2 jive.ui.Menu:styleIndex(index, style)

Override the style of the menu item at I<index> using I<style> instead.

=cut
--]]
function styleIndex(self, index, style)
	assert(type(index) == "number")

	if self.itemStyles[index] ~= style then
		self.itemStyles[index] = style
		self:layout()
	end
end


--[[

=head2 jive.ui.Menu:styleItem(item, style)

Override the style of the menu I<item> using I<style> instead.

=cut
--]]
function styleItem(self, item, style)
	assert(oo.instanceof(item, Widget))

	self:styleIndex(self:getIndex(item), style)
end


--[[

=head2 jive.ui.Menu:scrollBy(scroll)

Scroll the menu by I<scroll> items. If I<scroll> is negative the menu scrolls up, otherwise the menu scrolls down.

=cut
--]]
function scrollBy(self, scroll)
	assert(type(scroll) == "number")

	log:debug("scrollBy(", tostring(scroll), ")")
	
	log:debug("selected = ", tostring(self.selected), " top = ", tostring(self.topItem), " visible = ", tostring(self.visibleItems), " items = ", tostring(#self.items))

	-- NOTE: the C layer keeps visibleItems <= $items !!

	-- make sure selected stays in bounds
	self.selected = _coerce(self.selected + scroll, #self.items)

	log:debug("_coerce selected")
	log:debug("selected = ", tostring(self.selected), " top = ", tostring(self.topItem), " visible = ", tostring(self.visibleItems), " items = ", tostring(#self.items))

	-- show the first item if the first item is selected
	if self.selected == 1 then
		self.topItem = 1
		
	-- otherwise, try to leave one item above the selected one (we've scrolled out of the view)
	elseif self.selected <= self.topItem then
		-- if we land here, selected > 1 so topItem cannot become < 1
		self.topItem = self.selected - 1
	end

	log:debug("after top update")
	log:debug("selected = ", tostring(self.selected), " top = ", tostring(self.topItem), " visible = ", tostring(self.visibleItems), " items = ", tostring(#self.items))


	-- show the last item if it is selected
	if self.selected == #self.items then
		self.topItem = #self.items - self.visibleItems + 1
	
	-- otherwise, try to leave one item below the selected one (we've scrolled out of the view)
	elseif self.selected >= self.topItem + self.visibleItems - 1 then
		self.topItem = _coerce(self.topItem + scroll, #self.items - self.visibleItems + 1)
	end

	log:debug("after bottom update")
	log:debug("selected = ", tostring(self.selected), " top = ", tostring(self.topItem), " visible = ", tostring(self.visibleItems), " items = ", tostring(#self.items))


	self:layout()
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

