
--[[
=head1 NAME

jive.ui.Widget - Base class for UI widgets.

=head1 DESCRIPTION

Base class for UI widgets.

=head1 SYNOPSIS

See examples in subclasses.

=head1 STYLE

All widgets support the following style parameters that can be set in the skin.

=over

B<x> : absolute x co-ordinate in pixels

B<y> : absolute y co-ordinate in pixels

B<w> : width in pixels

B<h> : height in pixels

B<padding> : padding around the widget content in pixels. Defaults to 0.

B<padding-left> : padding on the left of the widget in pixels. Overrides padding is specified.

B<padding-top> : padding on the top of the widget in pixels. Overrides padding is specified.

B<padding-right> : padding on the right of the widget in pixels. Overrides padding is specified.

B<padding-bottom> : padding on the bottom of the widget in pixels. Overrides padding is specified.

B<layer> : the layer can be one of the following values.

=over 4

=item B<LAYER_FRAME>

Widgets in the Frame layer are not animated during window transitions.

=item B<LAYER_CONTENT>

Widgets in the Content layer are animated during window transitions. This is the default value.

=item B<LAYER_CONTENT_OFF_STAGE>

Widgets in  the Content Off Stage layer are only animated when moving off stage. These widgets are not drawn when moving on stage.

=item B<LAYER_CONTENT_ON_STAGE>

Widgets in  the Content On Stage layer are only animated when moving on stage. These widgets are not drawn when moving off stage.

=back

=head1 METHODS

=cut
--]]


-- stuff we use
local assert, ipairs, require, tostring, type = assert, ipairs, require, tostring, type

local oo            = require("loop.base")
local table         = require("jive.utils.table")
local Event         = require("jive.ui.Event")
local Timer         = require("jive.ui.Timer")

local log           = require("jive.utils.log").logger("ui")

local FRAME_RATE    = jive.ui.FRAME_RATE
local EVENT_SHOW    = jive.ui.EVENT_SHOW
local EVENT_HIDE    = jive.ui.EVENT_HIDE
local EVENT_UPDATE  = jive.ui.EVENT_UPDATE
local EVENT_CONSUME = jive.ui.EVENT_CONSUME


-- our class
module(..., oo.class)

local Framework		= require("jive.ui.Framework")


-- Constructs a new widget. This is only used by subclasses
function __init(self, style)
	assert(type(style) == "string")

	return oo.rawnew(self, {
		bounds = { 0, 0, 0, 0 },
		-- FIXME: useless to assign nil here
		parent = nil, -- parent widget
		visible = false, -- are we on stage?
		timers = {}, -- all timers associated with this widget
		listeners = {}, -- event callback functions
		animations = {}, -- amination functions
		layoutCount = Framework.layoutCount - 1,
		style = style,
	})
end



--[[

=head2 jive.ui.Widget:getPosition()

Returns I<x, y> the widgets position.

=cut
--]]
function getBounds(self)
	return self.bounds[1], self.bounds[2], self.bounds[3], self.bounds[4]
end


--[[

=head2 jive.ui.Widget:getPosition()

Returns I<x, y> the widgets position.

=cut
--]]
getPosition = getBounds



--[[

=head2 jive.ui.Widget:getSize()

Returns I<w, h> the widgets size.

=cut
--]]
function getSize(self)
	return self.bounds[3], self.bounds[4]
end


--[[

=head2 jive.ui.Widget:setSize(w, h)

Sets the widgets size to I<w, h>

=cut
--]]
function setSize(self, w, h)
	assert(type(w) == "number")
	assert(type(h) == "number")

	-- mark the existing screen position as dirty
	self:dirty()

	self.bounds[3] = w
	self.bounds[4] = h

	-- mark the existing screen position as dirty
	self:layout()
end


--[[

=head2 jive.ui.Widget:setBounds(x, y, w, h)

Sets the widgets bounds to I<x, y, w, h>

=cut
--]]
function setBounds(self, x, y, w, h)
	assert(type(x) == "number")
	assert(type(y) == "number")
	assert(w == nil or type(w) == "number")
	assert(h == nil or type(h) == "number")

	-- mark the existing screen position as dirty
	self:dirty()

	self.bounds[1] = x
	self.bounds[2] = y
	if w then
		self.bounds[3] = w
	end
	if h then
		self.bounds[4] = h
	end

	-- mark the existing screen position as dirty
	self:layout()
end


--[[

=head2 jive.ui.Widget:setPosition(x, y)

Sets the widgets position to I<x, y>.

=cut
--]]
setPosition = setBounds


--[[

=head2 jive.ui.Widget:getStyle()

Returns the widgets style.

=cut
--]]
function getStyle(self)
	return self.style
end


--[[

=head2 jive.ui.Widget:setStyle(style)

Sets the widgets style.

=cut
--]]
function setStyle(self, style)
	assert(type(style) == "string")

	if (self.style == style) then
		return
	end

	self.style = style

	self:layout()
	self:dirty()
end


--[[

=head2 jive.ui.Widget:isVisible()

Returns true if the widget is visible, otherwise returns false.

=cut
--]]
function isVisible(self)
	return self.visible
end


--[[

=head2 jive.ui.Widget:hide()

Hides the window containing this widget.

=cut
--]]
function hide(self)
	if self.parent then
		self.parent:hide()
	end
end


--[[

=head2 jive.ui.Widget:getParent()

Returns the widgets parent.

=cut
--]]
function getParent(self)
	return self.parent
end


--[[

=head2 jive.ui.Widget:getWindow()

Returns the window containing this widget, or nil if the widget is not in a window.

=cut
--]]
function getWindow(self)
	if self.parent then
		return self.parent:getWindow()
	end
	return nil
end


--[[

=head2 jive.ui.Widget:layout()

Marks the widget as needing layout.

=cut
--]]
function layout(self)
	self.layoutCount = Framework.layoutCount - 1
	
--	print("Layout in " .. tostring(self))

	if self.parent then
		self.parent:layout()
	end
end


--[[

=head2 jive.ui.Widget:dirty()

Marks the bounding box of this widget as dirty. It will be redrawn soon.

=cut
--]]
function dirty(self)
	if self:isVisible() then
		Framework:dirty(self.bounds)
	end
end


function pack(self)
	-- must overridden by widgets
	assert(false)
end


function draw(self)
	-- must overridden by widgets
	assert(false)
end


--[[

=head2 jive.ui.Widget:addListener(mask, listener)

Add a listener I<listener> to the widget. The listener is called for events that match the event mask I<mask>. Returns a I<handle> to use in removeListener().

=cut
--]]
function addListener(self, mask, listener)
	assert(type(mask) == "number")
	assert(type(listener) == "function")

	local handle = { mask, listener }
	self.listeners[#self.listeners + 1]  = handle

	return handle
end


--[[

=head2 jive.ui.Widget:removeListener(handle)

Removes the listener I<handle> from the widget.

=cut
--]]
function removeListener(self, handle)
	assert(type(handle) == "table")

	table.delete(self.listeners, handle)
end


--[[

=head2 jive.ui.Widget:addAnimation(animation, frameRate)

Add an animation function I<animation> to the widget. This function will be called before the frame is drawn at the requested I<frameRate>. Returns a I<handle> to use in removeAnimation().

=cut
--]]
function addAnimation(self, animation, frameRate)
	assert(type(animation) == "function")
	assert(type(frameRate) == "number")

	frameRate = FRAME_RATE / frameRate

	local handle = { animation, frameRate, frameRate }
	self.animations[#self.animations + 1] = handle

	if self.visible then
		Framework:_addAnimationWidget(self)
	end

	return handle
end


--[[

=head2 jive.ui.Widget:removeAnimation(handle)

Remove the animation function I<handle> from the widget.

=cut
--]]
function removeAnimation(self, handle)
	assert(type(handle) == "table")

	table.delete(self.animations, handle)

	if self.visible then
		Framework:_removeAnimationWidget(self)
	end
end


--[[

=head2 jive.ui.Widget:dispatchNewEvent(eventType)

Send a new event of type I<type> with value I<value> to this widgets listeners.

=cut
--]]
function dispatchNewEvent(self, eventType)
	assert(type(eventType) == "number")

	local event = Event:new(eventType)
	return Framework:dispatchEvent(self, event)
end


--[[

=head2 jive.ui.Widget:dispatchUpdateEvent(value)

Send an EVENT_UPDATE with value I<value> to this widgets listeners.

=cut
--]]
function dispatchUpdateEvent(self, value)
	assert(type(value) == "number")

	local event = Event:new(EVENT_UPDATE, value)
	return Framework:dispatchEvent(self, event)
end


--[[

=head2 jive.ui.Widget:addTimer(interval, closure)

Add a timer to this timer that calls I<closure> in I<interval> milliseconds. The timer is only called while the widget is shown on the screen.

=cut
--]]
function addTimer(self, interval, callback)
	assert(type(interval) == "number")
	assert(type(callback) == "function")

	timer = Timer(interval, callback) 
	self.timers[#self.timers + 1] = timer
	timer:start()

	return timer
end


--[[

=head2 jive.ui.Widget:removeTimer(timer)

Remove timer I<timer> from this Widget.

=cut
--]]
function removeTimer(self, timer)
	assert(oo.instanceof(timer, Timer))

	timer:stop()
	table.delete(self.timers, timer)
end



function _event(self, event)
	local type = event:getType()
	if type == EVENT_SHOW then
		self.visible = true
		if #self.animations > 0 then
			Framework:_addAnimationWidget(self)
		end
		for i,timer in ipairs(self.timers) do
			timer:start()
		end
	elseif type == EVENT_HIDE then
		self.visible = false
		if #self.animations > 0 then
			Framework:_removeAnimationWidget(self)
		end
		for i,timer in ipairs(self.timers) do
			timer:stop()
		end
	end

	local r = 0
	for i,v in ipairs(self.listeners) do
		local mask,callback = v[1], v[2]
		if type & mask ~= 0 then
			r = r | (callback(event) or 0)

			if r & EVENT_CONSUME ~= 0 then
				break
			end
		end
	end

	return r
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

