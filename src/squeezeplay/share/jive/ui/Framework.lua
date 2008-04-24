
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
local _assert, collectgarbage, jive, ipairs, load, pairs, require, setfenv, string, tostring, type = _assert, collectgarbage, jive, ipairs, load, pairs, require, setfenv, string, tostring, type

local oo            = require("loop.simple")
local table         = require("jive.utils.table")

local EVENT_SHOW    = jive.ui.EVENT_SHOW
local EVENT_HIDE    = jive.ui.EVENT_HIDE
local EVENT_CONSUME = jive.ui.EVENT_CONSUME
local EVENT_UNUSED  = jive.ui.EVENT_UNUSED

local FRAME_RATE    = jive.ui.FRAME_RATE

local jnt           = jnt


-- our class
module(..., oo.class)

local math          = require("math")

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
local Task          = require("jive.ui.Task")
local Tile          = require("jive.ui.Tile")
local Timer         = require("jive.ui.Timer")
local Widget        = require("jive.ui.Widget")
local Window        = require("jive.ui.Window")

local log           = require("jive.utils.log").logger("ui")
local logTask       = require("jive.utils.log").logger("ui.task")

local dumper        = require("jive.utils.dumper")
local io            = require("io")

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

-- Put default global settings here
default_global_settings = {
}

-- To be filled in later when someone tries
--  to access a setting...
global_settings_file = nil

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

=head2 jive.ui.Framework:threadTicks()

Return the number of milliseconds spent in current thread.  Note this is lower resolution than getTicks().

=head2 jive.ui.Framework:getBackground()

Returns the current background image.

=head2 jive.ui.Framework:setBackground(image)

Sets the background image I<image>.

=head2 jive.ui.Framework:styleChanged()

Indicates the style parameters have changed, this clears any caching of the style values used.

=cut
--]]


--[[

=head2 jive.ui.Framework:constants()

Import constants into a module.

=cut
--]]
function constants(module)
	module.EVENT_UNUSED = jive.ui.EVENT_UNUSED
	module.EVENT_CONSUME = jive.ui.EVENT_CONSUME
	module.EVENT_QUIT = jive.ui.EVENT_QUIT

	module.EVENT_SCROLL = jive.ui.EVENT_SCROLL
	module.EVENT_ACTION = jive.ui.EVENT_ACTION
	module.EVENT_KEY_DOWN = jive.ui.EVENT_KEY_DOWN
	module.EVENT_KEY_UP = jive.ui.EVENT_KEY_UP
	module.EVENT_KEY_PRESS = jive.ui.EVENT_KEY_PRESS
	module.EVENT_KEY_HOLD = jive.ui.EVENT_KEY_HOLD
	module.EVENT_MOUSE_DOWN = jive.ui.EVENT_MOUSE_DOWN
	module.EVENT_MOUSE_UP = jive.ui.EVENT_MOUSE_UP
	module.EVENT_MOUSE_PRESS = jive.ui.EVENT_MOUSE_PRESS
	module.EVENT_MOUSE_HOLD = jive.ui.EVENT_MOUSE_HOLD
	module.EVENT_MOUSE_DRAG = jive.ui.EVENT_MOUSE_DRAG
	module.EVENT_WINDOW_PUSH = jive.ui.EVENT_WINDOW_PUSH
	module.EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
	module.EVENT_WINDOW_ACTIVE = jive.ui.EVENT_WINDOW_ACTIVE
	module.EVENT_WINDOW_INACTIVE = jive.ui.EVENT_WINDOW_INACTIVE
	module.EVENT_SHOW = jive.ui.EVENT_SHOW 
	module.EVENT_HIDE = jive.ui.EVENT_HIDE
	module.EVENT_FOCUS_GAINED = jive.ui.EVENT_FOCUS_GAINED
	module.EVENT_FOCUS_LOST = jive.ui.EVENT_FOCUS_LOST
	module.EVENT_WINDOW_RESIZE = jive.ui.EVENT_WINDOW_RESIZE
	module.EVENT_SWITCH = jive.ui.EVENT_SWITCH
	module.EVENT_MOTION = jive.ui.EVENT_MOTION
	module.EVENT_KEY_ALL = jive.ui.EVENT_KEY_ALL
	module.EVENT_MOUSE_ALL = jive.ui.EVENT_MOUSE_ALL
	module.EVENT_ALL_INPUT = jive.ui.EVENT_ALL_INPUT
	module.EVENT_VISIBLE_ALL = jive.ui.EVENT_VISIBLE_ALL
	module.EVENT_ALL = jive.ui.EVENT_ALL

	module.KEY_NONE = jive.ui.KEY_NONE
	module.KEY_GO = jive.ui.KEY_GO
	module.KEY_BACK = jive.ui.KEY_BACK
	module.KEY_UP = jive.ui.KEY_UP
	module.KEY_DOWN = jive.ui.KEY_DOWN
	module.KEY_LEFT = jive.ui.KEY_LEFT
	module.KEY_RIGHT = jive.ui.KEY_RIGHT
	module.KEY_HOME = jive.ui.KEY_HOME
	module.KEY_PLAY = jive.ui.KEY_PLAY
	module.KEY_ADD = jive.ui.KEY_ADD
	module.KEY_PAUSE = jive.ui.KEY_PAUSE
	module.KEY_REW = jive.ui.KEY_REW
	module.KEY_FWD = jive.ui.KEY_FWD 
	module.KEY_VOLUME_UP = jive.ui.KEY_VOLUME_UP
	module.KEY_VOLUME_DOWN = jive.ui.KEY_VOLUME_DOWN
end



--[[

=head2 jive.ui.Framework:eventLoop(netTask)

Main event loop.

=cut
--]]
function eventLoop(self, netTask)

	local eventTask =
		Task("ui",
		     self,
		     function(self)
			     -- must wrap C function
			     while self:processEvents() do end
		     end)


	collectgarbage("collect")
	collectgarbage("stop")


	-- frame rate in milliseconds
	local framerate = math.floor(1000 / FRAME_RATE)

	-- time for a vertical refesh. in the future this may need adjusting
	-- per squeezeplay platform
	local framerefresh = framerate >> 2

	-- next frame due
	local now = self:getTicks()
	local framedue = now + framerate

	local running = true
	while running do
		-- process tasks
		local tasks = false
		for task in Task:iterator() do
			local start = now
			tasks = task:resume() or tasks
			now = self:getTicks()
			if now - start > 20 then
				log:debug(task.name, " took ", now - start, " ms")
			end
			if framedue <= now then
				break
			end
		end

		-- call the network task, if no tasks are runnable this blocks
		-- until a file descriptor is ready for io or it will timeout
		-- before the next frame should be drawn
		if tasks then
			netTask:setArgs(0)
		else
			netTask:setArgs(framedue - now)
		end
		netTask:resume()

		-- draw frame and process ui event queue
		now = self:getTicks()
		if framedue <= now then
			logTask:info("--------")

			-- draw screen
			self:updateScreen()

			-- keep on top of the garbage
			collectgarbage("step")

			-- process ui event once per frame
			running = eventTask:resume()

			-- when is the next frame due?
			framedue = framedue + framerate

			now = self:getTicks()
			if now > framedue - framerefresh then
				logTask:debug("Dropped frame. delay=", now-framedue, "ms")
				framedue = now + framerefresh
			end
		end
	end

	collectgarbage("restart")
end




--[[

=head2 jive.ui.Framework:setEmulation(w, h, bpp)

Sets the screen size I<w, h>, and bbp I<bpp>. This must be called before jive.ui.Framework:init(). This has no effect on a hardware platform.

=cut
--]]
function setScreenSize(self, w, h, bpp)
	_assert(type(w) == "number")
	_assert(type(h) == "number")
	_assert(type(bpp) == "number")

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

=head2 jive.ui.Framework:wakeup()

Power management wakeup.

=cut
--]]
function wakeup(self)
end


--[[

=head2 jive.ui.Framework:registerWakeup()

Register a power management wakeup function.

=cut
--]]
function registerWakeup(self, wakeup)
	_assert(type(wakeup) == "function")
	self.wakeup = wakeup
end


--[[

=head2 jive.ui.Framework:addWidget(widget)

Add a global widget I<widget> to the screen. The global widgets are shown on all windows.

=cut
--]]
function addWidget(self, widget)
	_assert(oo.instanceof(widget, Widget))

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
	_assert(oo.instanceof(widget, Widget))

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
	_assert(type(mask) == "number")
	_assert(type(listener) == "function")

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
	_assert(type(handle) == "table")

	table.delete(self.globalListeners, handle)
	table.delete(self.unusedListeners, handle)
end


--[[

=head2 jive.ui.Framework:getGlobalSetting(key)

Get the value of a given Global Settings key

=cut
--]]
function getGlobalSetting(self, key)

	if not self._global_settings then
		-- One-shot initialization, the first
		-- time someone accesses a Global Setting

		global_settings_file = self:findFile("jive/JiveMain.lua"):sub(1,-13)
			.. "global_settings.txt"

		local fh = io.open(global_settings_file)
		if fh == nil then
			self._global_settings = default_global_settings
		else
        		local f, err = load(function() return fh:read() end)
        		fh:close()
			if not f then
				log:error("Error reading global settings: ", err)
				self._global_settings = default_global_settings
			else
				-- evalulate the settings in a sandbox
				local env = {}
				setfenv(f, env)
				f()
				self._global_settings = env.global_settings
			end
		end
        end

	return self._global_settings[key]
end


--[[

=head2 jive.ui.Framework:setGlobalSetting(key, value)

Change the value of the Global Setting indicated by key

=cut
--]]
function setGlobalSetting(self, key, value)
	-- skip no-ops
	-- as a nice side-effect, calling getGlobalSetting
	-- ensures global_settings_file and self._global_settings
	-- are initialized
	if self:getGlobalSetting(key) == value then
		return
	end

	self._global_settings[key] = value
	local file = _assert(io.open(global_settings_file, "w"))
	file:write(dumper.dump(self._global_settings, "global_settings", true))
	file:close()
end


function _addAnimationWidget(self, widget)
	_assert(not table.contains(animations, widget))

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

