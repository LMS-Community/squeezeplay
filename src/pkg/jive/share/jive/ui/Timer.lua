
--[[
=head1 NAME

jive.ui.Time - A timer.

=head1 DESCRIPTION

A timer object.

=head1 SYNOPSIS

 -- Create a timer that prints "hi" every second
 local timer = jive.ui.Timer(1000,
			     function()
				     print "hi"
			     end)

 -- stop the timer
 timer:stop()

=head1 METHODS

=cut
--]]


-- stuff we use
local assert, string, tostring, type = assert, string, tostring, type

local oo	= require("loop.base")
local debug	= require("jive.utils.debug")


-- our class
module(..., oo.class)


-- NOTE: this class has a C counterpart that defines _addTimer and _removeTimer


-- global variables, needed for the C code
static = {}
static.timers = {} -- hash of all running timers
static.maxId = 1 -- the C code needs a unique id for timers


--[[

=head2 jive.ui.Timer(interval, closure, once)

Constructs a new timer. The I<closure> is called every I<interval> milliseconds. If <once> is true then the closure is only called once each time the timer is started.

The I<closure> is called with a single argument, the Timer object.

=cut
--]]
function __init(self, interval, callback, once)
	assert(type(interval) == "number", debug.traceback())
	assert(type(callback) == "function")

	return oo.rawnew(self, {
		interval = interval,
		callback = callback,
		once = once or false,
	})
end


--[[

=head2 jive.ui.Timer:start()

Starts the timer.

=cut
--]]
function start(self)

	self.objectId = static.maxId

	repeat
		static.maxId = static.maxId + 1
	until static.timers[static.maxId] == nil

	self:_addTimer()
	static.timers[self.objectId] = self
end


--[[

=head2 jive.ui.Timer:stop()

Stops the timer.

=cut
--]]
function stop(self)
	self:_removeTimer()
	if self.objectId then
		static.timers[self.objectId] = nil
	end
end


--[[

=head2 jive.ui.Timer:restart()

Restarts the timer.

=cut
--]]
function restart(self)
	self:stop()
	self:start()
end


--[[

=head2 jive.ui.Timer:setInterval(interval)

Sets the timers interval to I<interval>.

=cut
--]]
function setInterval(self, interval)
	assert(type(interval) == "number")

	self.interval = interval
	if self.timer then
		self:restart()
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

