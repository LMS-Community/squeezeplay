
--[[
=head1 NAME

jive.ui.Label - A label widget.

=head1 DESCRIPTION

A label widget, extends L<jive.ui.Widget>. A label displays multi-line text.

Any lua value can be set as Label value, tostring() is used to convert the value to a string before it is displayed.

=head1 SYNOPSIS

 -- Create a new label to display 'Hello World'
 local label = jive.ui.Label("label", "Hello World")

 -- Update the label to multi-line text
 label.setValue("Multi-line\ntext")

=head1 STYLE

The Label includes the following style parameters in addition to the widgets basic parameters.

=over

B<bg> : the background color, defaults to no background color.

B<fg> : the foreground color, defaults to black.

B<bgImg> : the background image.

B<font> : the text font, a L<jive.ui.Font> object.

B<lineHeight> : the line height to use, defaults to the font ascend height.
=back

B<align> : the text alignment.

B<line> : optionally an array of I<font>, I<lineHeight>, I<fg> and I<sh> attribtues foreach line in the Label.

=head1 METHODS

=cut
--]]


-- stuff we use
local assert, string, tostring, type = assert, string, tostring, type

local oo           = require("loop.simple")
local Widget       = require("jive.ui.Widget")
local Icon         = require("jive.ui.Icon")

local log          = require("jive.utils.log").logger("ui")

local EVENT_ALL    = jive.ui.EVENT_ALL
local EVENT_UNUSED = jive.ui.EVENT_UNUSED

local EVENT_SHOW      = jive.ui.EVENT_SHOW
local EVENT_HIDE      = jive.ui.EVENT_HIDE
local EVENT_FOCUS_GAINED = jive.ui.EVENT_FOCUS_GAINED
local EVENT_FOCUS_LOST   = jive.ui.EVENT_FOCUS_LOST


-- our class
module(...)
oo.class(_M, Widget)


--[[

=head2 jive.ui.Label(style, value)

Constructs a new Label widget. I<style> is the widgets style. I<value> is the text displayed in the widget.

=cut
--]]
function __init(self, style, value)
	assert(type(style) == "string")
	assert(value ~= nil)
	
	local obj = oo.rawnew(self, Widget(style))

	obj.value = value

	obj:addListener(EVENT_FOCUS_GAINED, function() obj:animate(true) end)
	obj:addListener(EVENT_FOCUS_LOST, function() obj:animate(false) end)

	return obj
end


--[[

=head2 jive.ui.Label:getValue()

Returns the text displayed in the label.

=cut
--]]
function getValue(self)
	return self.value
end


--[[

=head2 jive.ui.Label:setValue(value)

Sets the text displayed in the label.

=cut
--]]
function setValue(self, value)
	assert(value ~= nil)

	if self.value ~= value then
		self.value = value
		self:reLayout()
	end
end


function __tostring(self)
	return "Label(" .. string.gsub(tostring(self.value), "[%c]", " ") .. ")"
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

