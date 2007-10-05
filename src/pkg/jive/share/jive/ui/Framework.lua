
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


local Audio         = require("jive.ui.Audio")
local Checkbox      = require("jive.ui.Checkbox")
local Choice        = require("jive.ui.Choice")
local Event         = require("jive.ui.Event")
local Font          = require("jive.ui.Font")
local Group         = require("jive.ui.Group")
local Icon          = require("jive.ui.Icon")
local Label         = require("jive.ui.Label")
local Menu          = require("jive.ui.Menu")
local Popup         = require("jive.ui.Popup")
local RadioButton   = require("jive.ui.RadioButton")
local RadioGroup    = require("jive.ui.RadioGroup")
local Scrollbar     = require("jive.ui.Scrollbar")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Slider        = require("jive.ui.Slider")
local Surface       = require("jive.ui.Surface")
local Textarea      = require("jive.ui.Textarea")
local Textinput     = require("jive.ui.Textinput")
local Tile          = require("jive.ui.Tile")
local Timer         = require("jive.ui.Timer")
local Widget        = require("jive.ui.Widget")
local Window        = require("jive.ui.Window")

local log             = require("jive.utils.log").logger("ui")


-- import C functions
jive.frameworkOpen()


-- initial global state
windowStack = {}
widgets = {} -- global widgets
globalListeners = {} -- global listeners
unusedListeners = {} -- unused listeners
animations = {} -- active widget animations
sound = {} -- sounds
soundEnabled = {} -- sound enabled state

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

=head2 jive.ui.Framework.reDraw(r)

Mark an area of the screen for redrawing, of the while screen if r is nil.

=head2 jive.ui.Framework.pushEvent(event)

Push an event onto the event queue for later processing. This can be called from any thread.

=head2 jive.ui.Framework.dispatchEvent(widget, event)

Dispatch an event I<event> to the listeners of the widget I<widget>. Any global event listeners are called first. If I<widget> is nil then the event will be sent to the top most window. This can only be called from the main thread.

=head2 jive.ui.Framework.findFile(path)

Find a file on the lua path. Returns the full path of the file, or nil if it was not found.

=head2 jive.ui.Framework:getTicks()

Return the number of milliseconds since the Jive initialization.

=head2 jive.ui.Framework:getBackground()

Returns the current background image.

=head2 jive.ui.Framework:setBackground(image)

Sets the background image I<image>.

=head2 jive.ui.Framework:styleChanged()

Indicates the style parameters have changed, this clears any caching of the style values used.

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

	self:reDraw(nil)
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

	self:reDraw(nil)
end


--[[
=head2 jive.ui.Framework:loadSound(file, name, channel)

Load the wav file I<file> to play on the mixer channel I<channel>. Currently two channels are supported.

=cut
--]]
function loadSound(self, name, file, channel)
	self.sound[name] = Audio:loadSound(file, channel)

	if self.soundEnabled[name] ~= nil then
		self.sound[name]:enable(self.soundEnabled[name])
	end
end


--[[
=head2 jive.ui.Framework:enableSound(name, enabled)

Enables or disables the sound I<name>.

=cut
--]]
function enableSound(self, name, enabled)
	self.soundEnabled[name] = enabled

	if self.sound[name] then
		self.sound[name]:enable(enabled)
	end
end


--[[
=head2 jive.ui.Framework:isEnableSound(name)

Returns true if the sound I<name> is enabled.

=cut
--]]
function isSoundEnabled(self, name)
	if self.soundEnabled[name] ~= nil then
		return self.soundEnabled[name]
	else
		return true
	end
end


--[[
=head2 jive.ui.Framework:playSound(name)

Play sound.

=cut
--]]
function playSound(self, name)
	if self.sound[name] ~= nil then
		self.sound[name]:play()
	end
end


--[[
=head2 jive.ui.Framework:getSounds()

Returns the table of available sounds.

=cut
--]]
function getSounds(self)
	return self.sound
end


--[[

=head2 jive.ui.Framework:addListener(mask, listener, priority)

Add a global event listener I<listener>. The listener is called for events that match the event mask I<mask>. By default the listener is called before any widget event listeners, and can stop event processing by returned EVENT_CONSUME. If priority is false then the listener is only called if no other global or widget listeners have processed the event. Returns a I<handle> to use in removeEventListener().

=cut
--]]
function addListener(self, mask, listener, priority)
	assert(type(mask) == "number")
	assert(type(listener) == "function")

	local handle = { mask, listener }
	if priority == false then
		table.insert(self.unusedListeners, 1, handle)
	else
		table.insert(self.globalListeners, 1, handle)
	end

	return handle
end


--[[

=head2 jive.ui.Framework:removeListener(handle)

Removes the listener I<handle> from the widget.

=cut
--]]
function removeListener(self, handle)
	assert(type(handle) == "table")

	table.delete(self.globalListeners, handle)
	table.delete(self.unusedListeners, handle)
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
	self:reDraw(nil)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

