
--[[
=head1 NAME

jive.net.SocketTcp - A TCP socket to send/recieve data using a NetworkThread

=head1 DESCRIPTION

Implements a tcp socket that sends/receive data using a NetworkThread. 
jive.net.SocketTcp is a subclass of L<jive.net.Socket> and therefore inherits
its methods.
This class is mainly designed as a superclass for L<jive.net.SocketHttp> and
therefore is not fully useful as is.

=head1 SYNOPSIS

 -- create a jive.net.SocketTcp
 local mySocket = jive.net.SocketTcp(jnt, "192.168.1.1", 9090, "cli")

 -- print the connected state
 if mySocket:connected() then
   print(tostring(mySocket) .. " is connected")
 end

=head1 FUNCTIONS

=cut
--]]
-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------


-- stuff we use
local _assert, tostring = _assert, tostring

local debug    = require("debug")

local socket   = require("socket")
local thread   = require("thread")
local oo       = require("loop.simple")

local Socket   = require("jive.net.Socket")

local log      = require("jive.utils.log").logger("net.http")


-- jive.net.SocketTcp is a subclass of jive.net.Socket
module(...)
oo.class(_M, Socket)


-- _createTcpSocket
local _createTcpSocket = socket.protect(function()
	--log:debug("_createTcpSocket()")
	
	local sock = socket.try(socket.tcp())
	-- create a try function that closes 'c' on error
    local try = socket.newtry(function() sock:close() end)
    -- do everything reassured c will be closed
	try(sock:settimeout(2))
	
	return sock
end)


--[[

=head2 jive.net.SocketTcp(jnt, ip, port, name)

Creates a TCP/IP socket named I<name> to interface with the given I<jnt> 
(a L<jive.net.NetworkThread> instance). I<name> is used for debugging and
defaults to "". I<ip> and I<port> are the IP address and port to 
send/receive data from/to.
Must be called by subclasses.

=cut
--]]
function __init(self, jnt, ip, port, name)
	--log:debug("SocketTcp:__init(", name, ", ", ip, ", ", port, ")")

--	_assert(ip, "Cannot create SocketTcp without ip address - " .. debug.traceback())
--	_assert(port, "Cannot create SocketTcp without port")

	local obj = oo.rawnew(self, Socket(jnt, name))

	obj.t_tcp = {
		ip = ip,
		port = port,
		connected = false,
		mutex = thread.newmutex(),
	}

	return obj
end


-- t_connect
-- connects our socket
function t_connect(self)
	--log:debug(self, ":t_connect()")
	
	-- create a tcp socket
	local sock, err = _createTcpSocket()
	
	self.t_sock = socket.tcp()

	-- set a long timeout for connection
	self.t_sock:settimeout(30)
	local err = socket.skip(1, self.t_sock:connect(self.t_tcp.ip, self.t_tcp.port))

	if err then
	
		log:error("SocketTcp:t_connect: ", err)
		return nil, err
	
	else
	
		-- reduce timeout for further operations
		self.t_sock:settimeout(1)
		self:t_setConnected(true)
		return 1
	end
end


-- t_setConnected
-- changes the connected state. Mutexed because main thread clients might care about this status
function t_setConnected(self, state)
	--log:debug(self, ":t_setConnected(", state, ")")

	self.t_tcp.mutex:lock()
	self.t_tcp.connected = state
	self.t_tcp.mutex:unlock()
end


-- t_getConnected
-- returns the connected state, network thread side (i.e. safe, no mutex)
function t_getConnected(self)
	return self.t_tcp.connected
end


-- t_free
-- frees our socket
function t_free(self)
	--log:debug(self, ":t_free()")
	
	-- we store nothing, just call superclass
	Socket.t_free(self)
end


-- t_close
-- closes our socket
function t_close(self)
	--log:debug(self, ":t_close()")
	
	self:t_setConnected(false)
	
	Socket.t_close(self)
end


-- t_getIpPort
-- returns the IP and port
function t_getIpPort(self)
	return self.t_tcp.ip, self.t_tcp.port
end


--[[

=head2 jive.net.SocketTcp:connected()

Returns the connected state of the socket. This is mutexed
to enable querying the state from the main thread while operations
on the socket occur network thread-side.

=cut
--]]
function connected(self)

	self.t_tcp.mutex:lock()
	local connected = self.t_tcp.connected
	self.t_tcp.mutex:unlock()
	
	--log:debug(self, ":connected() = ", connected)
	return connected
end


--[[

=head2 tostring(aSocket)

if I<aSocket> is a L<jive.net.SocketTcp>, prints
 SocketTcp {name}

=cut
--]]
function __tostring(self)
	return "SocketTcp {" .. tostring(self.jsName) .. "}"
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

