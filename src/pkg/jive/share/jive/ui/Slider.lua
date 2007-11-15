
--[[
=head1 NAME

jive.ui.Slider - A slider widget.

=head1 DESCRIPTION

A slider widget, extends L<jive.ui.Widget>.

=head1 SYNOPSIS

 -- Create a new label to display 'Hello World'
 local slider = jive.ui.Slider("label")

 -- Set the slider range, 10 items bubble is in the middle
 slider:setScroll(1, 10, 5)

=head1 STYLE

The Slider includes the following style parameters in addition to the widgets basic parameters.

=over

B<bg_img> : the background image tile.

B<img> : the bar image tile.

B<horizontal> : true if the slider is horizontal, otherwise the slider is vertial (defaults to horizontal).

=head1 METHODS

=cut
--]]


-- stuff we use
local tostring, type = tostring, type

local oo	= require("loop.simple")
local Widget	= require("jive.ui.Widget")

local log       = require("jive.utils.log").logger("ui")

local EVENT_KEY_PRESS = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL    = jive.ui.EVENT_SCROLL
local EVENT_CONSUME   = jive.ui.EVENT_CONSUME
local EVENT_UNUSED    = jive.ui.EVENT_UNUSED

local KEY_BACK        = jive.ui.KEY_BACK
local KEY_UP          = jive.ui.KEY_UP
local KEY_DOWN        = jive.ui.KEY_DOWN
local KEY_LEFT        = jive.ui.KEY_LEFT
local KEY_GO          = jive.ui.KEY_GO
local KEY_RIGHT       = jive.ui.KEY_RIGHT
local KEY_FWD         = jive.ui.KEY_FWD


-- our class
module(...)
oo.class(_M, Widget)



function __init(self, style, min, max, value, closure)

	local obj = oo.rawnew(self, Widget(style))

	obj.min = min or 1
	obj.range = max or 1
	obj.value = 1
	obj.closure = closure

	obj:setValue(value or obj.min)

	obj:addListener(EVENT_SCROLL | EVENT_KEY_PRESS,
			function(event)
				obj:_eventHandler(event)
			end)
	return obj
end


--[[

=head2 jive.ui.Slider:setScrollbar(min, max, pos, size)

Set the slider range I<min> to I<max>, the bar position to I<pos> and
the bar size to I<size>.  This method can be used when using this widget 
as a slider.

=cut
--]]
function setScrollbar(self, min, max, pos, size)

	self.range = max - min
	self.value = pos - min
	self.size = size

	self:reDraw()
end


--[[

=head2 jive.ui.Slider:setRange(min, max, value)

Set the slider range I<min> to I<max>, and the bar size to I<value>. This
method can be used when using this widget as a scrollbar.

=cut
--]]
function setRange(self, min, max, value)
	self.range = max
	self.min = min
	self.value = 1

	self:setValue(value)
end


--[[

=head2 jive.ui.Slider:setValue(value)

Set the slider value to I<value>.

=cut
--]]
function setValue(self, value)
	if self.size == value then
		return
	end

	self.size = value or 0

	if self.size < self.min then
		self.size = self.min
	elseif self.size > self.range then
		self.size = self.range
	end

	self:reDraw()
end


--[[

=head2 jive.ui.Slider:getValue()

Returns the value of the slider.

=cut
--]]
function getValue(self)
	return self.size
end

function _adjustSlider(self, value)
	local oldSize = self.size

	self:setValue(self.size + value)

	if self.size ~= oldSize then
		if self.closure then
			self.closure(self, self.size, false)
		end
	end
end


function _eventHandler(self, event)
	local type = event:getType()

	if type == EVENT_SCROLL then
		self:_adjustSlider(event:getScroll())
		return EVENT_CONSUME

	elseif type == EVENT_KEY_PRESS then
		local keycode = event:getKeycode()

		if keycode == KEY_UP then
			self:_adjustSlider(1)
			return EVENT_CONSUME

		elseif keycode == KEY_DOWN then
			self:_adjustSlider(-1)
			return EVENT_CONSUME

		elseif keycode == KEY_BACK or
			keycode == KEY_LEFT then
			self:playSound("WINDOWHIDE")
			self:hide()
			return EVENT_CONSUME

		elseif keycode == KEY_GO or
			keycode == KEY_RIGHT or
			keycode == KEY_FWD then

			self.closure(self, self.size, true)
			return EVENT_CONSUME
		end
	end
end


--[[ C optimized:

jive.ui.Slider:pack()
jive.ui.Slider:draw()

--]]

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
