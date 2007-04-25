
--[[
=head1 NAME

jive.ui.Checkbox - A checkbox widget

=head1 DESCRIPTION

A checkbox widget, extends L<jive.ui.Widget>.

=head1 SYNOPSIS

 -- New checkbox
 local checkbox = jive.ui.Checkbox(
	"checkbox", 
	function(object, isSelected)
		print("Checkbox is selected: " .. tostring(isSelected))
	end,
	true)

 -- Change checkbox state
 checkbox:setSelected(false)

=head1 STYLE

The Checkbox includes the following style parameters in addition to the widgets basic parameters.

=over

B<imgOn> : the image when the checkbox is checked.

B<imgOff> : the image when the checkbox is not checked.

=head1 METHODS

=cut
--]]


-- stuff we use
local assert, tostring, type = assert, tostring, type

local oo              = require("loop.simple")
local Icon            = require("jive.ui.Icon")

local EVENT_ACTION    = jive.ui.EVENT_ACTION
local EVENT_KEY_PRESS = jive.ui.EVENT_KEY_PRESS
local EVENT_CONSUME   = jive.ui.EVENT_CONSUME


-- our class
module(...)
oo.class(_M, Icon)


--[[

=head2 jive.ui.Checkbox(style, closure, isSelected)

Constructs a Checkbox widget. I<style> is the widgets style. I<isSelected> is true if the checkbox is selected, false otherwise (default). I<closure> is a function that will get called whenever the 
checkbox value changes; the function prototype is:
 function(checkboxObject, isSelected)

=cut
--]]
function __init(self, style, closure, isSelected)
	assert(type(style) == "string")
	
	isSelected = isSelected or false
	assert(type(isSelected) == "boolean")
	
	local obj = oo.rawnew(self, Icon(style))

	obj:setSelected(isSelected)
	obj.closure = closure

	obj:addListener(EVENT_ACTION | EVENT_KEY_PRESS,
		 function(event)
			 obj:setSelected(not obj.selected)
			 return EVENT_CONSUME
		 end)

	return obj
end


--[[

=head2 jive.ui.Checkbox:isSelected()

Returns true if the checkbox is selected, or false otherwise.

=cut
--]]
function isSelected(self)
	return self.selected
end


--[[

=head2 jive.ui.Checkbox:setSelected(isSelected)

Sets the state of the checkbox. I<selected> true if the checkbox is selected, false otherwise.

Note that using this function calls the defined closure.

=cut
--]]
function setSelected(self, isSelected)
	assert(type(isSelected) == "boolean")

	if self.selected == isSelected then
		return
	end

	self.selected = isSelected

	if isSelected then
		self.imgStyleName = "imgOn"
	else
		self.imgStyleName = "imgOff"
	end

	self:layout()
	if self.closure then
		self.closure(self, isSelected)
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

