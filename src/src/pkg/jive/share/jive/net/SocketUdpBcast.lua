
--[[
=head1 NAME

jive.net.SocketUdpBcast - A socket for UDP broadcast.

=head1 DESCRIPTION

Implements a socket that performs some udp broadcast and returns packets
obtained in response. This is used to discover slimservers on the network.
jive.net.SocketUdbBcast is a subclass of L<jive.net.Socket> to be used with a
L<jive.net.NetworkSocket>.

Note the implementation uses the source and sink concept of luasocket.

=head1 SYNOPSIS

 -- create a source to send some data
 local function mySource()
   return "Hello"
 end

 -- create a sink to receive data from the network
 local function mySink(chunk, err)
   if err then
     print("error!: " .. err)
   elseif chunk then
     print("received: " .. chunk.data .. " from " .. chunk.ip)
   end
 end

 -- create a SocketUdpBcast
 local mySocket = jive.net.SocketUdpBcast(jnt, mySink)

 -- broadcast some data on port 3333
 mySocket:send(mySource, 3333)

=head1 FUNCTIONS

=cut
--]]
-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------


-- stuff we use
local assert = assert

local socket  = require("socket")
local ltn12   = require("ltn12")
local oo      = require("loop.simple")

local strings = require("jive.utils.strings")
local Socket  = require("jive.net.Socket")

local log     = require("jive.utils.log").logger("net.socket")

-- jive.net.SocketUdpBcast is a subclass of jive.net.Socket
module(...)
oo.class(_M, Socket)


-- _createUdpSocket
-- creates our socket safely
local _createUdpSocket = socket.protect(function()
	--log:debug("_createUdpSocket()")
	
	local sock = socket.try(socket.udp())
	-- create a try function that closes 'c' on error
    local try = socket.newtry(function() sock:close() end)
    -- do everything reassured c will be closed
	try(sock:setoption("broadcast", true))
	try(sock:settimeout(2))
	
	return sock
end)


--[[

=head2 jive.net.SocketUdpBcast(jnt, sink, name)

Creates a UDP broadcast socket named I<name> to interface with the given I<jnt> 
(a L<jive.net.NetworkThread> instance). I<name> is used for debugging and
defaults to "". I<sink> is the main thread ltn12 sink that will receive the data.
Must be called by subclasses.

The sink receives chunks that are tables. NIL is never sent as the network source
cannot determine the "end" of the stream. The table contains the following members:
=over

B<data> : the data.

B<ip> : the source ip address.

B<port> : the source port


=cut
--]]
function __init(self, jnt, sink, name)
	--log:debug("SocketUdpBcast:__init()")

--	assert(sink)
	
	-- init superclass
	local obj = oo.rawnew(self, Socket(jnt, name))

	-- create a udp socket
	local sock, err = _createUdpSocket()
	
	if err then
		log:error(err)
	else
	
		-- save the socket, we might need it later :)
		obj.t_sock = sock
		
		-- transform the main thread sink in something that can be called network thread side
		local safeSink = obj:safeSink(sink)
	
		-- add our read function (thread side)
		jnt:perform(function() obj:t_addRead(obj:t_getReadPump(safeSink)) end)
	end
	
	return obj
end


-- t_getReadPump
-- returns a pump to read udp data using the read sources/sinks
function t_getReadPump(self, sink)

	-- a ltn12 source that reads from a udp socket, including the source address
	-- NOTE: this source produces chunks as tables and cannot be generally chained
	local source = function()
		local dgram, ssIp, ssPort, err = self.t_sock:receivefrom()

		if not err then
			return {ip = ssIp, port = ssPort, data = dgram}
		else
			return nil, err
		end
	end

	return function()
		--log:debug("SocketUdpBcast:readPump()")

		local err = socket.skip(1, ltn12.pump.step(source, sink))

		if err then
			-- do something
			log:error("SocketUdpBcast:readPump:", err)
		end
	end
end


-- t_getWritePump
-- returns a pump to write out bcast data. It removes itself after each pump
function t_getWritePump(self, t_source, port)

	-- a ltn12 sink than sends udp bcast datagrams
	local sink = function(chunk, err)
		if chunk and chunk ~= "" then
			return self.t_sock:sendto(chunk, "255.255.255.255", port)
		else
			return 1
		end
	end

	return function()
		--log:debug("SocketUdpBcast:writePump()")
		
		-- pump data once
		local err = socket.skip(1, ltn12.pump.step(t_source, sink))
		
		if err then
			log:error("SocketUdpBcast:writePump:", err)
		end
		
		-- stop the pumping...
		self:t_removeWrite()
	end
end


--[[

=head2 jive.net.SocketUdpBcast:send(t_source, port)

Broadcasts the data obtained through I<t_source> to the 
given I<port>. I<t_source> is a ltn12 source called from 
the network thread.

=cut
--]]
function send(self, t_source, port)
	--log:debug("SocketUdpBcast:send()")

--	assert(t_source)
--	assert(port)

	if self.t_sock then
		self:perform(function() self:t_addWrite(self:t_getWritePump(t_source, port)) end)	
	end
end


--[[

=head2 tostring(aSocket)

if I<aSocket> is a L<jive.net.SocketUdpBcast>, prints
 SocketUdpBcast {name}

=cut
--]]
function __tostring(self)
	return "SocketUdpBcast {" .. tostring(self.jsName) .. "}"
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

