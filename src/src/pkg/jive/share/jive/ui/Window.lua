
--[[
=head1 NAME

jive.ui.Window - The window widget.

=head1 DESCRIPTION

The window widget, extends L<jive.ui.Widget>. This is a container for other widgets on the screen.

=head1 SYNOPSIS

 -- Create a new window with title "Jive"
 local window = jive.ui.Window("window", "Jive")

 -- Show the window on the screen
 window:show()

 -- Hide the window from the screen
 window:hide()


=head1 STYLE

The Window includes the following style parameters in addition to the widgets basic parameters.

=over

B<popup> : true if this is a popup window that includes transparency.

=head1 METHODS

=cut
--]]


-- stuff we use
local assert, ipairs, require, tostring, type, unpack = assert, ipairs, require, tostring, type, unpack

local debug                   = require("debug")
local oo                      = require("loop.simple")
local table                   = require("jive.utils.table")
local SimpleMenu              = require("jive.ui.SimpleMenu")
local Label                   = require("jive.ui.Label")
local Timer                   = require("jive.ui.Timer")
local Widget                  = require("jive.ui.Widget")

local log                     = require("jive.utils.log").logger("ui")

local EVENT_ALL               = jive.ui.EVENT_ALL
local EVENT_ACTION            = jive.ui.EVENT_ACTION
local EVENT_SCROLL            = jive.ui.EVENT_SCROLL
local EVENT_KEY_PRESS         = jive.ui.EVENT_KEY_PRESS
local EVENT_WINDOW_PUSH       = jive.ui.EVENT_WINDOW_PUSH
local EVENT_WINDOW_POP        = jive.ui.EVENT_WINDOW_POP
local EVENT_WINDOW_ACTIVE     = jive.ui.EVENT_WINDOW_ACTIVE
local EVENT_WINDOW_INACTIVE   = jive.ui.EVENT_WINDOW_INACTIVE
local EVENT_SHOW              = jive.ui.EVENT_SHOW
local EVENT_HIDE              = jive.ui.EVENT_HIDE
local EVENT_CONSUME           = jive.ui.EVENT_CONSUME
local EVENT_UNUSED            = jive.ui.EVENT_UNUSED

local FRAME_RATE              = jive.ui.FRAME_RATE
local LAYER_ALL               = jive.ui.LAYER_ALL
local LAYER_CONTENT           = jive.ui.LAYER_CONTENT
local LAYER_CONTENT_OFF_STAGE = jive.ui.LAYER_CONTENT_OFF_STAGE
local LAYER_CONTENT_ON_STAGE  = jive.ui.LAYER_CONTENT_ON_STAGE
local LAYER_FRAME             = jive.ui.LAYER_FRAME

local LAYOUT_NORTH            = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST             = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH            = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST             = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER           = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE             = jive.ui.LAYOUT_NONE


-- our class
module(...)
oo.class(_M, Widget)


local Framework = require("jive.ui.Framework")


--[[

=head2 jive.ui.Window(style, title)

Constructs a new window widget. I<style> is the widgets style. The window can have an optional I<title>.

=cut
--]]
function __init(self, style, title)
	assert(type(style) == "string", "style parameter is " .. type(style) .. " expected string - " .. debug.traceback())
	assert(title == nil or type(title) == "string", "title is not nil and not string - " .. debug.traceback())

	local obj = oo.rawnew(self, Widget(style))

	obj.widgets = {} -- child widgets
	obj.layoutRoot = true
	obj.focus = nil

	-- default window to screen size
	local sw, sh = Framework:getScreenSize()
	obj:setBounds(0, 0, sw, sh)

	if title then
		obj:setTitle(title)
	end

	obj:addListener(EVENT_ALL,
			 function(event)
			 	return obj:_eventHandler(event)
			 end)
	
	return obj
end


--[[

=head2 jive.ui.Window:show(transition)

Show this window, adding it to the top of the window stack. The I<transition> is used to move the window on stage.

=cut
--]]
function show(self, transition)
	local stack = Framework.windowStack

	-- make sure the window layout is done
	self:doLayout()

	local topwindow = stack[1]

	if topwindow == self then
		-- we're already on top
		return
	end

	-- remove the window if it is already in the stack
	local onstack = table.delete(stack, self)

	if not onstack then
		-- this window is being pushed to the stack
		self:dispatchNewEvent(EVENT_WINDOW_PUSH)
	end

	-- this window is now active
	self:dispatchNewEvent(EVENT_WINDOW_ACTIVE)

	-- this window and it's widgets are now visible
	self:dispatchNewEvent(EVENT_SHOW)

	-- insert the window in the window stack
	table.insert(stack, 1, self)

	if (topwindow) then
		-- push transitions
		if transition == nil then
			transition = transitionPushLeft
		end
		Framework:_startTransition(transition(topwindow, self))

		-- the old window and widgets are no longer visible
		topwindow:dispatchNewEvent(EVENT_HIDE)

		-- the old window is inactive
		topwindow:dispatchNewEvent(EVENT_WINDOW_INACTIVE)
	end

	Framework:reDraw(nil)
end


--[[

=head2 jive.ui.Window:showInstead(transition)

Shows this window as a replacement for the window at the top of the window stack. The I<transition> is used to move the window on stage.

=cut
--]]
function showInstead(self, transition)
	local last = Framework.windowStack[1]

	self:show(transition)
	last:hide()
end


--[[

=head2 jive.ui.Window:showBriefly(msecs, closure, pushTransition, popTransition)

Shows this window briefly for I<msecs> milliseconds. When the timeout occurs, or a key has been pressed then window is hidden and the I<closure> is called. The I<pushTransition> and I<popTransition> transitions are used to move the window on and off stage.

If the window has already been displayed with showBriefly then the timer is restarted with the new I<msecs> value.

=cut
--]]
function showBriefly(self, msecs, callback,
		     pushTransition,
		     popTransition)

	if self.brieflyTimer ~= nil then
		if msecs then
			self.brieflyTimer:setInterval(msecs)
		else
			self.brieflyTimer:restart()
		end
		return

	elseif msecs == nil then
		return
	end

	self:addListener(EVENT_KEY_PRESS | EVENT_SCROLL,
			 function(event)
				 local r = EVENT_CONSUME
				 if callback then
					 r = callback()
				 end

				 self:hide(popTransition)
				 return r
			 end)

	self.brieflyTimer = Timer(msecs,
				  function(timer)
					  self.brieflyTimer = nil
					  if callback then
						  callback()
					  end
					  self:hide(popTransition)
				  end,
				  true)
	self.brieflyTimer:start()

	self:show(pushTransition)
end


--[[

=head2 jive.ui.Window:hide(transition)

Hides this window. It it is currently at the top of the window stack then the I<transition> is used to move the window off stage.

=cut
--]]
function hide(self, transition)
	local stack = Framework.windowStack

	local wasVisible = (stack[1] == self)

	-- remove the window from window stack
	table.delete(stack, self)

	local topWindow = stack[1]
	if wasVisible and topWindow then
		-- top window is now active
		topWindow:dispatchNewEvent(EVENT_WINDOW_ACTIVE)

		-- top window and widgets are now visible
		topWindow:dispatchNewEvent(EVENT_SHOW)
		topWindow:reDraw()

		-- push transitions
		if transition == nil then
			transition = transitionPushRight
		end
		Framework:_startTransition(transition(self, topWindow))

		-- this window and widgets are now not visible
		self:dispatchNewEvent(EVENT_HIDE)

		-- this window is inactive
		self:dispatchNewEvent(EVENT_WINDOW_INACTIVE)
	end

	self:dispatchNewEvent(EVENT_WINDOW_POP)
end


--[[

=head2 jive.ui.Window:bumpLeft()

Makes the window bump left.

=cut
--]]
function bumpLeft(self)
	Framework:_startTransition(self:transitionBumpLeft(self))
end


--[[

=head2 jive.ui.Window:bumpRight()

Makes the window bump right.

=cut
--]]
function bumpRight(self)
	Framework:_startTransition(self:transitionBumpRight(self))
end


--[[

=head2 jive.ui.Window:hideAll()

Hides all windows, removing them from the window stack.

=cut
--]]
function hideAll(self)
	local stack = Framework.windowStack

	-- hide windows in reverse order
	for i=#stack, 1, -1 do
		stack[i]:hide()
	end

	-- FIXME window events
end


--[[

=head2 jive.ui.Window:setTitle(title)

Sets the windows title to I<title>.

=cut
--]]
function setTitle(self, title)
	assert(type(title) == "string")

	if self.title then
		self:removeWidget(self.title)
	end

	self.title = Label("title", title)
	self:addWidget(self.title)
end


--[[

=head2 jive.ui.Window:setTitleWidget(titleWidget)

Sets the windows title to I<titleWidget>.

=cut
--]]
function setTitleWidget(self, titleWidget)

	if self.title then
		self:removeWidget(self.title)
	end

	self.title = titleWidget
	self:addWidget(self.title)
end


--[[

=head2 jive.ui.Window:getWindow()

Returns I<self>.

=cut
--]]
function getWindow(self)
	return self
end


--[[

=head2 jive.ui.Window:addWidget(widget)

Add the widget I<widget> to the window.

=cut
--]]
function addWidget(self, widget)
	assert(oo.instanceof(widget, Widget), "jive.ui.Window:addWidget(widget): widget is not an instance of Widget!")

	self.widgets[#self.widgets + 1] = widget
	widget.parent = self

	-- FIXME last widget added always has focus
	self.focus = widget

	if self:isVisible() then
		widget:dispatchNewEvent(EVENT_SHOW)
	end

	widget:reSkin()
end


--[[

=head2 jive.ui.Window:removeWidget(widget)

Remove the widget I<widget> from the window.

=cut
--]]
function removeWidget(self, widget)
	assert(oo.instanceof(widget, Widget))

	if self:isVisible() then
		widget:dispatchNewEvent(EVENT_HIDE)
	end

	table.delete(self.widgets, widget)

	self:reLayout()
end


function __tostring(self)
	if self.title then
		return "Window(" .. self.title:getValue() .. ")"
	else
		return "Window()"
	end
end


--[[

=head2 jive.ui.Window:transitionNone()

Returns an empty window transition. i.e. the window is just displayed without any animations.

=cut
--]]
function transitionNone(self)
	return nil
end


--[[

=head2 jive.ui.Window:transitionBumpLeft()

Returns a bump left window transition.

=cut
--]]
function transitionBumpLeft(self)

	local frames = 2
	local screenWidth = Framework:getScreenSize()

	return function(widget, surface)
			local x = frames * 3

			surface:setOffset(x, 0)
			self:draw(surface, LAYER_CONTENT | LAYER_CONTENT_OFF_STAGE | LAYER_CONTENT_ON_STAGE)

			surface:setOffset(0, 0)
			self:draw(surface, LAYER_FRAME)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:transitionBumpRight()

Returns a bump right window transition.

=cut
--]]
function transitionBumpRight(self)

	local frames = 2
	local screenWidth = Framework:getScreenSize()

	return function(widget, surface)
			local x = frames * 3

			surface:setOffset(-x, 0)
			self:draw(surface, LAYER_CONTENT | LAYER_CONTENT_OFF_STAGE | LAYER_CONTENT_ON_STAGE)

			surface:setOffset(0, 0)
			self:draw(surface, LAYER_FRAME)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:transitionPushLeft(newWindow)

Returns a push left window transition.

=cut
--]]
function transitionPushLeft(oldWindow, newWindow)
	assert(oo.instanceof(oldWindow, Widget))
	assert(oo.instanceof(newWindow, Widget))

	local frames = FRAME_RATE / 2 -- 0.5 sec
	local screenWidth = Framework:getScreenSize()
	local scale = (frames * frames * frames) / screenWidth

	return function(widget, surface)
			local x = screenWidth - ((frames * frames * frames) / scale)

			surface:setOffset(0, 0)
			newWindow:draw(surface, LAYER_FRAME)

			surface:setOffset(-x, 0)
			oldWindow:draw(surface, LAYER_CONTENT | LAYER_CONTENT_OFF_STAGE)

			surface:setOffset(screenWidth - x, 0)
			newWindow:draw(surface, LAYER_CONTENT | LAYER_CONTENT_ON_STAGE)

			surface:setOffset(0, 0)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:transitionPushRight(newWindow)

Returns a push right window transition.

=cut
--]]
function transitionPushRight(oldWindow, newWindow)
	assert(oo.instanceof(oldWindow, Widget))
	assert(oo.instanceof(newWindow, Widget))

	local frames = FRAME_RATE / 2 -- 0.5 sec
	local screenWidth = Framework:getScreenSize()
	local scale = (frames * frames * frames) / screenWidth

	return function(widget, surface)
			local x = screenWidth - ((frames * frames * frames) / scale)

			surface:setOffset(0, 0)
			newWindow:draw(surface, LAYER_FRAME)

			surface:setOffset(x, 0)
			oldWindow:draw(surface, LAYER_CONTENT | LAYER_CONTENT_OFF_STAGE)

			surface:setOffset(x - screenWidth, 0)
			newWindow:draw(surface, LAYER_CONTENT | LAYER_CONTENT_ON_STAGE)

			surface:setOffset(0, 0)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:transitionPushPopupLeft(newWindow)

Returns a push left window transition for use with popup windows.

=cut
--]]
function transitionPushPopupLeft(oldWindow, newWindow)
	assert(oo.instanceof(oldWindow, Widget))
	assert(oo.instanceof(newWindow, Widget))

	local frames = FRAME_RATE / 2 -- 0.5 sec
	local screenWidth = Framework:getScreenSize()
	local scale = (frames * frames * frames) / screenWidth

	return function(widget, surface)
			local x = screenWidth - ((frames * frames * frames) / scale)

			surface:setOffset(0, 0)
			newWindow:draw(surface, LAYER_ALL)

			surface:setOffset(-x, 0)
			oldWindow:draw(surface, LAYER_CONTENT | LAYER_CONTENT_OFF_STAGE)

			surface:setOffset(0, 0)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:transitionPushPopupRight(newWindow)

Returns a push right window transition for use with popup windows.

=cut
--]]
function transitionPushPopupRight(oldWindow, newWindow)
	assert(oo.instanceof(oldWindow, Widget))
	assert(oo.instanceof(newWindow, Widget))

	local frames = FRAME_RATE / 2 -- 0.5 sec
	local screenWidth = Framework:getScreenSize()
	local scale = (frames * frames * frames) / screenWidth

	return function(widget, surface)
			local x = screenWidth - ((frames * frames * frames) / scale)

			surface:setOffset(0, 0)
			newWindow:draw(surface, LAYER_ALL)

			surface:setOffset(x, 0)
			oldWindow:draw(surface, LAYER_CONTENT | LAYER_CONTENT_OFF_STAGE)

			surface:setOffset(0, 0)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:noLayout()

Layout function that does not modify the window layout

=cut
--]]
function noLayout(self)
	iterate(self, function(widget) widget:doLayout() end)
end


--[[

=head2 jive.ui.Window:borderLayout(window)

Layout function similar to the Java Border Layout.

=cut
--]]
function borderLayout(self)
	-- discover bounder dimensions
	local sw, sh = Framework:getScreenSize()
	local maxN, maxE, maxS, maxW = 0, 0, 0, 0
	iterate(
		self, 
		function(widget)
			local x,y,w,h = widget:getPreferredBounds()
			local lb,tb,rb,bb = widget:getBorder()
			local position = widget:styleInt("position") or LAYOUT_CENTER

			if position == LAYOUT_NORTH then
				h = h + tb + bb or tb + bb
				maxN = (h > maxN) and h or maxN

			elseif position == LAYOUT_SOUTH then
				h = h + tb + bb or tb + bb
				maxS = (h > maxS) and h or maxS

			elseif position == LAYOUT_EAST then
				w = w + lb + rb or lb + rb
				maxE = (w > maxE) and w or maxE

			elseif position == LAYOUT_WEST then
				w = w + lb + rb or lb + rb
				maxW = (w > maxW) and w or maxW
			end
		end
	)


	-- set widget bounds
	iterate(self,
		function(widget)
			local x,y,w,h = widget:getPreferredBounds()
			local lb,tb,rb,bb = widget:getBorder()
			local position = widget:styleInt("position") or LAYOUT_CENTER

			rb = rb + lb
			bb = bb + tb

			if position == LAYOUT_NORTH then
				widget:setBounds(x + lb, y + tb, w - rb, h)

			elseif position == LAYOUT_SOUTH then
				x = x or 0
				y = y or (sh - maxS)
				widget:setBounds(x + lb, y + tb, w - rb, h)

			elseif position == LAYOUT_EAST then
				x = x or (sw - maxE)
				y = y or 0
				widget:setBounds(x + lb, y + tb, w, h - bb)

			elseif position == LAYOUT_WEST then
				x = x or 0
				y = y or 0
				widget:setBounds(x + lb, y + tb, w, h - bb)

			elseif position == LAYOUT_CENTER then
				widget:setBounds(maxW + lb, maxN + tb, (sw - maxW - maxE) - rb, (sh - maxN - maxS) - bb)

			elseif position == LAYOUT_NONE then
				widget:setBounds(x, y, w, h)
			end

			widget:doLayout()
		end
	)
end



--[[ C optimized:

jive.ui.Window:pack()
jive.ui.Window:draw()
jive.ui.Window:_eventHandler()

--]]

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

