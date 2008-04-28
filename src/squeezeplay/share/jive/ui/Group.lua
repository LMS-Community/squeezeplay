
--[[
=head1 NAME

jive.ui.Group - A group widget.

=head1 DESCRIPTION

A group widget, extends L<jive.ui.Widget>, it is a container for other widgets. The widgets are arranged horizontally.

=head1 SYNOPSIS

 -- Create a new group
 local group = jive.ui.Group("item", { text = Label("text", "Hello World"), icon = Icon("icon") })

=head1 STYLE

The Group includes the following style parameters in addition to the widgets basic parameters.

=over

B<order> : a table specifing the order of the widgets, by key. For example { "text", "icon" }

=head1 METHODS

=cut
--]]


local _assert, pairs, string, tostring, type = _assert, pairs, string, tostring, type

local oo                = require("loop.simple")
local Widget            = require("jive.ui.Widget")

local table             = require("jive.utils.table")
local debug             = require("jive.utils.debug")
local log               = require("jive.utils.log").logger("ui")

local EVENT_ALL         = jive.ui.EVENT_ALL
local EVENT_MOUSE_ALL   = jive.ui.EVENT_MOUSE_ALL
local EVENT_UNUSED      = jive.ui.EVENT_UNUSED

local EVENT_SHOW      = jive.ui.EVENT_SHOW
local EVENT_HIDE      = jive.ui.EVENT_HIDE


module(...)
oo.class(_M, Widget)


--[[

=head2 jive.ui.Group(style, widgets)

Constructs a new Group widget. I<style> is the widgets style. I<widgets> is a table with the widgets in this group.

=cut
--]]
function __init(self, style, widgets)
	_assert(type(style) == "string")

	local obj = oo.rawnew(self, Widget(style))
	obj.widgets = widgets

	for _,widget in pairs(obj.widgets) do
		widget.parent = obj
	end

	-- forward events to contained widgets
	obj:addListener(EVENT_ALL,
			 function(event)
				 local notMouse = (event:getType() & EVENT_MOUSE_ALL) == 0

				 for _,widget in pairs(obj.widgets) do
					 if notMouse or widget:mouseInside(event) then
						 local r = widget:_event(event)
						 if r ~= EVENT_UNUSED then
							 return r
						 end
					 end
				 end
				 return EVENT_UNUSED
			 end)

	return obj
end


--[[

=head2 jive.ui.Widget:getWidget(key)

Returns a widget in this group.

=cut
--]]
function getWidget(self, key)
	return self.widgets[key]
end


--[[

=head2 jive.ui.Widget:setWidget(key, widget)

Sets or replaces a widget in this group.

=cut
--]]
function setWidget(self, key, widget)
	if self.widgets[key] == widget then
		return
	end

	if self.widgets[key] then
		if self.visible then
			self.widgets[key]:dispatchNewEvent(EVENT_HIDE)
		end

		if self.widgets[key].parent == self then
			self.widgets[key].parent = nil
		end
	end

	self.widgets[key] = widget

	if self.widgets[key] then
		self.widgets[key].parent = self
		self.widgets[key]:reSkin()

		if self.visible then
			self.widgets[key]:dispatchNewEvent(EVENT_SHOW)
		end
	end
end


--[[

=head2 jive.ui.Widget:getWidgetValue(widget)

Returns the value of a widget in this Group.

=cut
--]]
function getWidgetValue(self, w)
	return self.widgets[w]:getValue()
end


--[[

=head2 jive.ui.Widget:setWidgetValue(widget, value)

Set the value of a widget in this Group.

=cut
--]]
function setWidgetValue(self, w, value)
	return self.widgets[w]:setValue(value)
end


function __tostring(self)
	local str = {}

	str[1] = "Group("
	for k,v in pairs(self.widgets) do
		str[#str + 1] = tostring(v)
	end
	str[#str + 1] = ")"

	return table.concat(str)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
