
--[[
=head1 NAME

jive.net.Socket - An abstract socket that sends/receives data using a NetworkThread.

=head1 DESCRIPTION

An abstract socket that sends/receives data using a NetworkThread. It proposes
services to close/free sockets and interface with the main thread, along with 
convenient proxy functions.

=head1 SYNOPSIS

 -- jive.net.Socket is abstract so this is not a useful example
 local mySocket = Socket(jnt, "mySocket")

 -- FROM THE MAIN THREAD
 -- transform a sink into a network thread one
 local t_Sink = mySocket:safeSink(sink)

 -- information about the socket
 log:debug("Freeing: ", mySocket)
 -- print
 Freeing: Socket {mySocket}

 -- free the socket
 mySocket:free()


=head1 FUNCTIONS

=cut
--]]
-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------


-- stuff we use
local tostring, _assert = tostring, _assert

local oo            = require("loop.base")

local NetworkThread = require("jive.net.NetworkThread")

local log           = require("jive.utils.log").logger("net.socket")


-- jive.net.Socket is a base class
module(..., oo.class)


--[[

=head2 jive.net.Socket(jnt, name)

Creates a socket named I<name> to interface with the given I<jnt> 
(a L<jive.net.NetworkThread> instance). I<name> is used for debugging and
defaults to "".
Must be called by subclasses.

=cut
--]]
function __init(self, jnt, name)
--	log:debug("Socket:__init(", name, ")")

--	_assert(
--		jnt and oo.instanceof(jnt, NetworkThread), 
--		"Cannot create Socket without NetworkThread object"
--	)

	return oo.rawnew(self, {
		jnt = jnt,
		jsName = name or "",
		t_sock = false
	})
end


--[[

=head2 jive.net.Socket:close()

Closes the socket.

=cut
--]]
function close(self)
--	log:debug(self, ":close()")

	self:perform(function() self:t_close() end)
end
--[[

=head2 jive.net.Socket:free()

Frees and closes the socket including any reference in the jnt.
Must be called by subclasses.

=cut
--]]
function free(self)
--	log:debug(self, ":free()")

	self:perform(function() self:t_free() end)
end


--[[

=head2 jive.net.Socket:getSafeSinkGenerator()

Returns a function that transforms a main thread sink in 
a network thread sink. The function accepts an optional boolean
indicating if nil must be sent (i.e. standard source behaviour)

=cut
--]]
function getSafeSinkGenerator(self)

	return function (sink, callNil, priority)

		return function(chunk, err)
			if chunk ~= "" then
				self.jnt:t_perform(
					function() 
						sink(chunk, err) 
						if callNil then sink(nil) end 
					end,
					priority
				)
			end
			return 1
		end
	end
end


--[[

=head2 jive.net.Socket:safeSink()

Transforms a main thread sink in a network thread sink.

=cut
--]]
function safeSink(self, sink)
	local gen = self:getSafeSinkGenerator()
	return gen(sink)
end


-- t_free
-- frees (and closes) the socket
function t_free(self)
--	log:debug(self, ":t_free()")

	-- we store nothing so closing is all we need
	self:t_close()
end


-- t_close
-- closes the socket
function t_close(self)
--	log:debug(self, ":t_close()")

	if self.t_sock then
		self:t_removeRead()
		self:t_removeWrite()
		self.t_sock:close()
		self.t_sock = nil
	end
end


--[[

=head2 tostring(aSocket)

if I<aSocket> is a L<jive.net.Socket>, prints
 Socket {name}

=cut
--]]
function __tostring(self)
	return "Socket {" .. tostring(self.jsName) .. "}"
end


-- Proxy functions for NetworkThread, for convenience of subclasses

-- t_add/remove/read/write
function t_addRead(self, pump)
	self.jnt:t_addRead(self.t_sock, pump)
end

function t_removeRead(self)
	self.jnt:t_removeRead(self.t_sock)
end

function t_addWrite(self, pump)
	self.jnt:t_addWrite(self.t_sock, pump)
end

function t_removeWrite(self)
	self.jnt:t_removeWrite(self.t_sock)
end

--[[

=head2 jive.net.Socket:perform(func)

A proxy for the I<perform> method of L<jive.net.NetworkThread>.

=cut
--]]
function perform(self, func)
	self.jnt:perform(func)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

