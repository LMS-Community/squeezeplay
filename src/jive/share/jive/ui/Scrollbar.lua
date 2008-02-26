
--[[
=head1 NAME

jive.ui.Scrollbar - A scrollbar widget.

=head1 DESCRIPTION

A scrollbar widget, extends L<jive.ui.Widget>.

=head1 SYNOPSIS

 -- Create a new label to display 'Hello World'
 local scrollbar = jive.ui.Scrollbar("label")

 -- Set the scrollbar range, 10 items bubble is in the middle
 scrollbar:setScroll(1, 10, 5)

=head1 STYLE

The Scrollbar includes the following style parameters in addition to the widgets basic parameters.

=over

B<bg_img> : the background image tile.

B<img> : the bar image tile.

B<horizontal> : true if the scrollbar is horizontal, otherwise the scrollbar is vertial (defaults to horizontal).

=head1 METHODS

=cut
--]]


-- stuff we use
local tostring, type = tostring, type

local oo	= require("loop.simple")
local Slider	= require("jive.ui.Slider")
local Widget	= require("jive.ui.Widget")


local log       = require("jive.utils.log").logger("ui")

local EVENT_KEY_PRESS = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL    = jive.ui.EVENT_SCROLL
local EVENT_CONSUME   = jive.ui.EVENT_CONSUME

local KEY_BACK        = jive.ui.KEY_BACK
local KEY_UP          = jive.ui.KEY_UP
local KEY_DOWN        = jive.ui.KEY_DOWN
local KEY_LEFT        = jive.ui.KEY_LEFT


-- our class
module(...)
oo.class(_M, Slider)



function __init(self, style)

	local obj = oo.rawnew(self, Slider(style))

	obj.range = 1
	obj.value = 1
	obj.size = 1

	return obj
end


--[[

=head2 jive.ui.Scrollbar:setScrollbar(min, max, pos, size)

Set the scrollbar range I<min> to I<max>, the bar position to I<pos> and
the bar size to I<size>.  This method can be used when using this widget 
as a scrollbar.

=cut
--]]
function setScrollbar(self, min, max, pos, size)
	self.range = max - min
	self.value = pos - min
	self.size = size

	self:reDraw()
end


function _eventHandler(self, event)
	-- XXXX FIXME todo
end


--[[ C optimized:

jive.ui.Scrollbar:pack()
jive.ui.Scrollbar:draw()

--]]

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
