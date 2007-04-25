
--[[
=head1 NAME

jive.ui.Label - A label widget.

=head1 DESCRIPTION

A label widget, extends L<jive.ui.Widget>. A label displays multi-line text. Optionally in contains another widget, typically an L<jive.ui.Icon>.

Any lua value can be set in the lua, tostring() is used to convert the value to a string before it is displayed.

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

B<textAlign> : the text alignment.

B<iconAlign> : the icon alignment.

=head1 METHODS

=cut
--]]


-- stuff we use
local assert, string, tostring, type = assert, string, tostring, type

local oo           = require("loop.simple")
local Widget       = require("jive.ui.Widget")
local Icon         = require("jive.ui.Icon")

local EVENT_ALL    = jive.ui.EVENT_ALL
local EVENT_UNUSED = jive.ui.EVENT_UNUSED


-- our class
module(...)
oo.class(_M, Widget)


--[[

=head2 jive.ui.Label(style, value, widget)

Constructs a new Label widget. I<style> is the widgets style. I<value> is the text displayed in the widget. I<widget> is an optional widget contained in the label, if not given a L<jive.ui.Icon> is used as a default value.

=cut
--]]
function __init(self, style, value, widget)
	assert(type(style) == "string")
	assert(value ~= nil)
	assert(widget == nil or (oo.instanceof(widget, Widget) and widget.parent == nil))

	local obj = oo.rawnew(self, Widget(style))

	obj.value = value
	obj.widget = widget or Icon("icon")
	obj.widget.parent = obj

	obj:addListener(EVENT_ALL,
			 function(event)
				if obj.widget then
					return obj.widget:_event(event)
				end
				return EVENT_UNUSED
			 end)
	
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
		self.text = nil
		self:layout()
	end
end


-- FIXME optimize in C
function _makeText(self)

	self.text = {}
	for v in string.gmatch(tostring(self.value) or '', "[^\r\n]+") do
		self.text[#self.text + 1] = v
	end

	return self.text
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

