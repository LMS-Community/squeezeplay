
--[[
=head1 NAME

jive.net.SocketHttpQueue - A SocketHttp that uses an external queue

=head1 DESCRIPTION

jive.net.SocketHttpQueue is a subclass of L<jive.net.SocketHttp> designed
to use an external request queue, such as the one proposed by L<jive.net.HttpPool>.

=head1 SYNOPSIS

None provided.

=head1 FUNCTIONS

=cut
--]]
-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------


-- stuff we use
local assert, tostring = assert, tostring

local oo         = require("loop.simple")

local SocketHttp = require("jive.net.SocketHttp")

local log        = require("jive.utils.log").logger("net.http")


-- jive.net.SocketHttpQueue is a subclass of jive.net.SocketHttp
module(...)
oo.class(_M, SocketHttp)


--[[

=head2 jive.net.SocketHttpQueue(jnt, ip, port, queueObj, name)

Same as L<jive.net.SocketHttp>, save for the I<queueObj> parameter
which must refer to an object implementing a B<t_dequeue> function
that returns a request from its queue and a boolean indicating if
the connection must close.

=cut
--]]
function __init(self, jnt, ip, port, queueObj, name)
	log:debug("SocketHttpQueue:__init(", tostring(name), ", ".. tostring(ip), ", ", tostring(port), ")")

	assert(queueObj)

	-- init superclass
	local obj = oo.rawnew(self, SocketHttp(jnt, ip, port, name))

	obj.httpqueue = queueObj
	
	return obj
end


-- t_sendDequeue
--
function t_sendDequeue(self)
	log:debug(tostring(self), ":t_sendDequeue()")
	
	local request, close = self.httpqueue:t_dequeue()
	
	if request then
		self.t_httpSending = request
		log:info(tostring(self), " processing ", tostring(self.t_httpSending))
		self:t_sendNext(true, 't_sendConnect')
	end
	
	if close then
		self:t_close()
	end
end


--[[

=head2 tostring(aSocket)

if I<aSocket> is a L<jive.net.SocketHttpQueue>, prints
 SocketHttpQueue {name}

=cut
--]]
function __tostring(self)
	return "SocketHttpQueue {" .. tostring(self.jsName) .. "}"
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

