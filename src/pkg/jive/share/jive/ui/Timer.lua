
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
local _assert, string, tostring, type = _assert, string, tostring, type

local oo	= require("loop.base")
local debug	= require("jive.utils.debug")


-- our class
module(..., oo.class)



--[[

=head2 jive.ui.Timer(interval, closure, once)

Constructs a new timer. The I<closure> is called every I<interval> milliseconds. If <once> is true then the closure is only called once each time the timer is started.

The I<closure> is called with a single argument, the Timer object.

=cut
--]]
function __init(self, interval, callback, once)
	_assert(type(interval) == "number", debug.traceback())
	_assert(type(callback) == "function")

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

-- C implementation


--[[

=head2 jive.ui.Timer:stop()

Stops the timer.

=cut
--]]

-- C implementation


--[[

=head2 jive.ui.Timer:restart(interval)

Restarts the timer. Optionally the timer interval can be modified
to I<interval>, otherwise the interval is unchanged.

=cut
--]]
function restart(self, interval)
	_assert(interval == nil or type(interval) == "number")

	self:stop()
	if interval then
		self.interval = interval
	end
	self:start()
end


--[[

=head2 jive.ui.Timer:setInterval(interval)

Sets the timers interval to I<interval> and restarts the timer if
it is already running.

=cut
--]]
function setInterval(self, interval)
	_assert(type(interval) == "number")

	self.interval = interval
	if self._timerData then
		self:restart()
	end
end


--[[

=head2 jive.ui.Timer:isRunning()

Returns true if the timer is running.

=cut
--]]
function isRunning(self)
	return self._timerData ~= nil
end



--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

