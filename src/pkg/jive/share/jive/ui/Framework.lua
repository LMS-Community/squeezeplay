
--[[
=head1 NAME

jive.ui.Framework - User interface framework 

=head1 DESCRIPTION

User interface framework

=head1 SYNOPSIS

 -- Called from the mail application
 jive.ui.Framework:init()
 jive.ui.Framework:run()
 jive.ui.Framework:quit()

 -- Add a global event listener
 jive.ui.Framework:addListener(jive.ui.EVENT_KEY_PRESS,
			       function(event)
				       print("key pressed:" .. event.getKeyCode()
			       end)

=head1 METHODS

=cut
--]]


-- stuff we use
local assert, jive, ipairs, pairs, require, string, tostring, type = assert, jive, ipairs, pairs, require, string, tostring, type

local oo            = require("loop.simple")
local table         = require("jive.utils.table")

local EVENT_SHOW    = jive.ui.EVENT_SHOW
local EVENT_HIDE    = jive.ui.EVENT_HIDE
local EVENT_CONSUME = jive.ui.EVENT_CONSUME
local EVENT_UNUSED  = jive.ui.EVENT_UNUSED


-- our class
module(..., oo.class)


local Checkbox      = require("jive.ui.Checkbox")
local Choice        = require("jive.ui.Choice")
local Event         = require("jive.ui.Event")
local Font          = require("jive.ui.Font")
local Icon          = require("jive.ui.Icon")
local Label         = require("jive.ui.Label")
local Menu          = require("jive.ui.Menu")
local RadioButton   = require("jive.ui.RadioButton")
local RadioGroup    = require("jive.ui.RadioGroup")
local Slider        = require("jive.ui.Slider")
local Surface       = require("jive.ui.Surface")
local Textarea      = require("jive.ui.Textarea")
local Timer         = require("jive.ui.Timer")
local Widget        = require("jive.ui.Widget")
local Window        = require("jive.ui.Window")


-- import C functions
jive.frameworkOpen()


-- initial global state
windowStack = {}
widgets = {} -- global widgets
listeners = {} -- global listeners
animations = {} -- active widget animations
layoutCount = 1

screen = {}
screen.bounds = { 0, 0, 240, 320 }
screen.bpp = 16


--[[ C functions:

=head2 jive.ui.Framework.init()

Initialise the ui.

=head2 jive.ui.Framework.quit()

Free all ui resources.

=head2 jive.ui.Framework.run()

The main display and event loop.

=head2 jive.ui.Framework.dirty(r)

Mark an area of the screen as dirty, of the while screen if r is nil.

=head2 jive.ui.Framework.pushEvent(event)

Push an event onto the event queue for later processing. This can be called from any thread.

=head2 jive.ui.Framework.dispatchEvent(widget, event)

Dispatch an event I<event> to the listeners of the widget I<widget>. Any global event listeners are called first. This can only be called from the main thread.

=head2 jive.ui.Framework.findFile(path)

Find a file on the lua path. Returns the full path of the file, or nil if it was not found.

=head2 jive.ui.Framework:getTicks()

Return the number of milliseconds since the Jive initialization.

=head2 jive.ui.Framework:getBackground()

Returns the current background image.

=head2 jive.ui.Framework:setBackground(image)

Sets the background image I<image>.

=cut
--]]



--[[

=head2 jive.ui.Framework:setEmulation(w, h, bpp)

Sets the screen size I<w, h>, and bbp I<bpp>. This must be called before jive.ui.Framework:init(). This has no effect on a hardware platform.

=cut
--]]
function setScreenSize(self, w, h, bpp)
	assert(type(w) == "number")
	assert(type(h) == "number")
	assert(type(bpp) == "number")

	screen.bounds[3] = w
	screen.bounds[4] = h
	screen.bpp = bpp
end


--[[

=head2 jive.ui.Framework:getScreenSize()

Returns I<w, h> the current screen size.

=cut
--]]
function getScreenSize(self)
	local bounds = screen.bounds
	return bounds[3], bounds[4]
end


--[[

=head2 jive.ui.Framework:addWidget(widget)

Add a global widget I<widget> to the screen. The global widgets are shown on all windows.

=cut
--]]
function addWidget(self, widget)
	assert(oo.instanceof(widget, Widget))

	widgets[#widgets + 1] = widget
	widget:dispatchNewEvent(EVENT_SHOW)

	self:dirty(nil)
end


--[[

=head2 jive.ui.Framework:removeWidget(widget)

Remove the global widget I<widget> from the screen.

=cut
--]]
function removeWidget(self, widget)
	assert(oo.instanceof(widget, Widget))

	table.delete(widget, widget)
	widget:dispatchNewEvent(EVENT_HIDE)

	self:dirty(nil)
end


--[[

=head2 jive.ui.Framework:layoutDirty()

Mark the layout as dirty.

=cut
--]]
function layoutDirty(self)
	self.layoutCount = self.layoutCount + 1
end


--[[

=head2 jive.ui.Framework:addListener(mask, listener)

Add a global event listener I<listener>. The listener is called for events that match the event mask I<mask>. The listener is called before any widget event listeners, and can stop event processing by returned EVENT_CONSUME. Returns a I<handle> to use in removeEventListener().

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

=head2 jive.ui.Framework:removeListener(handle)

Removes the listener I<handle> from the widget.

=cut
--]]
function removeListener(self, handle)
	assert(type(handle) == "table")

	for i,v in pairs(self.listeners) do
		if v == handle then
			table.remove(self.listeners, i)
			return
		end
	end
end


function _addAnimationWidget(self, widget)
	assert(not table.contains(animations, widget))

	animations[#animations + 1] = widget
end


function _removeAnimationWidget(self, widget)
	table.delete(animations, widget)
end


function _startTransition(self, newTransition)
	transition = newTransition
end


function _killTransition(self)
	transition = nil
	self:dirty(nil)
end


function _event(self, event)
	local r = 0

	for i,v in ipairs(self.listeners) do
		local mask,callback = v[1], v[2]
		if event:getType() & mask ~= 0 then
			r = r | (callback(event) or 0)
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

