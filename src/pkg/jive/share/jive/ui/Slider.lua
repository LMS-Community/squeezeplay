
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

B<bg_img> : the background image.

B<img> : the bar image.

B<cap1> : the bar cap (either top or left) image.

B<cap2> : the bar cap (either bottom or right) image.

B<horizontal> : true if the slider is horizontal, otherwise the slider is vertial (defaults to horizontal).

=head1 METHODS

=cut
--]]


-- stuff we use
local assert, tostring, type = assert, tostring, type
local print = print

local oo	= require("loop.simple")
local Widget	= require("jive.ui.Widget")

local log               = require("jive.utils.log").logger("ui")


-- our class
module(...)
oo.class(_M, Widget)



function __init(self, style)

	local obj = oo.rawnew(self, Widget(style))

	obj.range = 1
	obj.value = 1

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

	self:dirty()
end


--[[

=head2 jive.ui.Slider:setSlider(min, max, value)

Set the slider range I<min> to I<max>, and the bar size to I<value>. This
method can be used when using this widget as a scrollbar.

=cut
--]]
function setSlider(self, min, max, value)
	self.range = max - min
	self.value = 0
	self.size = value - min

	self:dirty()
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
