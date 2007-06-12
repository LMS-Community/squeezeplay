
--[[
=head1 NAME

jive.ui.Label - A label widget.

=head1 DESCRIPTION

A label widget, extends L<jive.ui.Widget>. A label displays multi-line text. Optionally in contains another widget, typically an L<jive.ui.Icon>.

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

local log          = require("jive.utils.log").logger("ui")

local EVENT_ALL    = jive.ui.EVENT_ALL
local EVENT_UNUSED = jive.ui.EVENT_UNUSED

local EVENT_SHOW      = jive.ui.EVENT_SHOW
local EVENT_HIDE      = jive.ui.EVENT_HIDE


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
	if widget == nil then
		obj.icon = Icon("icon")
		obj.widget = obj.icon
	else
		obj.widget = widget
	end
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


-- iterator function
function iterate(self, closure)
	if self.widget then
		closure(self.widget)
	end
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
		self:rePrepare()
	end
end


--[[

=head2 jive.ui.Label:getWidget()

Returns the widget displayed in this label, or nil for the skin's default widget.

=cut
--]]
function getWidget(self)
	return self.widget
end


--[[

=head2 jive.ui.Label:setWidget(widget)

Sets the widget displayed in this label to I<widget>. If set to nil the skin's default widget is displayed.

=cut

--]]
function setWidget(self, widget)
	assert(widget == nil or (oo.instanceof(widget, Widget)))

	if widget == nil then
		if self.icon == nil then
			self.icon = Icon("icon")
		end
		widget = self.icon
	end

	if self.widget ~= widget then
		if self.widget then
			if self.visible then
				self.widget:dispatchNewEvent(EVENT_HIDE)
			end

			if self.widget.parent == self then
				self.widget.parent = nil
			end
		end

		self.widget = widget
		self.widget.parent = self
		self.widget:reSkin()

		if self.visible then
			self.widget:dispatchNewEvent(EVENT_SHOW)
		end

		self:reLayout()
	end
end


function __tostring(self)
	return "Label(" .. tostring(self.value) .. ")"
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

