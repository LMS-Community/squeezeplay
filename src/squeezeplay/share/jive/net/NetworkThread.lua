
--[[
=head1 NAME

jive.net.NetworkThread - thread for network IO

=head1 DESCRIPTION

Implements a separate thread (using luathread) for network functions. The base class for network protocols is Socket. Messaging from/to the thread uses mutexed queues. The queues contain functions executed once they leave the queue in the respective thread.
The network thread queue is polled repeatedly. The main thread queue shall serviced by the main code; currently, an event EVENT_SERVICE_JNT exists for this purpose.

FIXME: Subscribe description

=head1 SYNOPSIS

 -- Create a NetworkThread (done for you in JiveMain stored in global jnt)
 jnt = NetworkThread()

 -- Create an HTTP socket that uses this jnt
 local http = SocketHttp(jnt, '192.168.1.1', 80)

=head1 FUNCTIONS

=cut
--]]
-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------


-- stuff we use
local _assert, tostring, table, ipairs, pairs, pcall, select, type  = _assert, tostring, table, ipairs, pairs, pcall, select, type

local socket            = require("socket")
local coroutine         = require("coroutine")
local table             = require("jive.utils.table")
local debug             = require("jive.utils.debug")
local oo                = require("loop.base")

local Event             = require("jive.ui.Event")
local Framework         = require("jive.ui.Framework")
local Task              = require("jive.ui.Task")
local DNS               = require("jive.net.DNS")

local log               = require("jive.utils.log").logger("net.thread")

local perfhook          = jive.perfhook

local EVENT_SERVICE_JNT = jive.ui.EVENT_SERVICE_JNT
local EVENT_CONSUME     = jive.ui.EVENT_CONSUME


-- jive.net.NetworkThread is a base class
module(..., oo.class)


-- _add
-- adds a socket to the read or write list
-- timeout == 0 => no time out!
local function _add(sock, task, sockList, timeout)
	if not sock then 
		return
	end
	
	if not sockList[sock] then
		-- add us if we're not already in there
		table.insert(sockList, sock)
	else
		-- else remove previous task
		sockList[sock].task:removeTask()
	end	
	
	-- remember the pump, the time and the desired timeout
	sockList[sock] = {
		task = task,
		lastSeen = Framework:getTicks(),
		timeout = (timeout or 60) * 1000
	}
end


-- _remove
-- removes a socket from the read or write list
local function _remove(sock, sockList)
	if not sock then 
		return 
	end

	-- remove the socket from the sockList
	if sockList[sock] then
		sockList[sock].task:removeTask()
		
		sockList[sock] = nil
		table.delete(sockList, sock)
	end
end


-- t_add/remove/read/write
-- add/remove sockets api
function t_addRead(self, sock, task, timeout)
--	log:warn("NetworkThread:t_addRead()", sock)

	_add(sock, task, self.t_readSocks, timeout)
end

function t_removeRead(self, sock)
--	log:warn("NetworkThread:t_removeRead()", sock)
	
	_remove(sock, self.t_readSocks)
end

function t_addWrite(self, sock, task, timeout)
--	log:warn("NetworkThread:t_addWrite()", sock)
	
	_add(sock, task, self.t_writeSocks, timeout)
end

function t_removeWrite(self, sock)
--	log:warn("NetworkThread:t_removeWrite()", sock)
	
	_remove(sock, self.t_writeSocks)
end


-- _timeout
-- manages the timeout of our sockets
local function _timeout(now, sockList)
--	log:debug("NetworkThread:_timeout()")

	for v, t in pairs(sockList) do
		-- the sockList contains both sockList[i] = sock and sockList[sock] = {pumpIt=,lastSeem=}
		-- we want the second case, the sock is a userdata (implemented by LuaSocket)
		-- we also want the timeout to exist and have expired
		if type(v) == "userdata" and t.timeout > 0 and now - t.lastSeen > t.timeout then
			log:error("network thread timeout for ", t.task)
			t.task:addTask("inactivity timeout")
		end
	end
end


-- _t_select
-- runs our sockets through select
local function _t_select(self, timeout)
--	log:debug("_t_select(r", #self.t_readSocks, " w", #self.t_writeSocks, ")")

	local r,w,e = socket.select(self.t_readSocks, self.t_writeSocks, timeout)

	local now = Framework:getTicks()
		
	if e then
		-- timeout is a normal error for select if there's nothing to do!
		if e ~= 'timeout' then
			log:error(e)
		end

	else
		-- call the write pumps
		for i,v in ipairs(w) do
			self.t_writeSocks[v].lastSeen = now
			if not self.t_writeSocks[v].task:addTask() then
				_remove(v, self.t_writeSocks)
			end
		end
		
		-- call the read pumps
		for i,v in ipairs(r) do
			self.t_readSocks[v].lastSeen = now
			if not self.t_readSocks[v].task:addTask() then
				_remove(v, self.t_readSocks)
			end
		end
	end

	-- manage timeouts
	_timeout(now, self.t_readSocks)
	_timeout(now, self.t_writeSocks)
end


-- _thread
-- the thread function with the endless loop
local function _run(self, timeout)
	local ok, err

	log:info("NetworkThread starting...")

	while true do
		local timeoutSecs = timeout / 1000
		if timeoutSecs < 0 then
			timeoutSecs = 0
		end

		ok, err = pcall(_t_select, self, timeoutSecs)
		if not ok then
			log:error("error in _t_select: " .. err)
		end

		_, timeout = Task:yield(true)
	end
end


function task(self)
	return Task("networkTask", self, _run)
end


function t_perform(self, func, priority)
	-- XXXX deprecated
	log:error("t_perform: ", debug.traceback())
end
function perform(self, func)
	-- XXXX deprecated
	log:error("perform: ", debug.traceback())
end


-- add/remove subscriber
function subscribe(self, object)
--	log:debug("NetworkThread:subscribe()")
	
	if not self.subscribers[object] then
		self.subscribers[object] = 1
	end
end


function unsubscribe(self, object)
--	log:debug("NetworkThread:unsubscribe()")
	
	if self.subscribers[object] then
		self.subscribers[object] = nil
	end
end


-- notify
function notify(self, event, ...)
	-- detailed logging for events
	local a = {}
	for i=1, select('#', ...) do
		a[i] = tostring(select(i, ...))
	end
	log:info("NOTIFY ", event, ": ", table.concat(a, ", "))
	
	local method = "notify_" .. event
	
	for k,v in pairs(self.subscribers) do
		if k[method] and type(k[method]) == 'function' then
			k[method](k, ...)
		end
	end
end


-- Called by the network layer when the network is active
function networkActive(self)
	if self.activeCount == 0 then
		if self.activeCallback then
			self.activeCallback(true)
		end
	end

	self.activeCount = self.activeCount + 1
end


-- Called by the network layer when the network is inactive
function networkInactive(self)
	self.activeCount = self.activeCount - 1

	if self.activeCount == 0 then
		if self.activeCallback then
			self.activeCallback(false)
		end
	end
end


-- Register a network active callback for power management
function registerNetworkActive(self, callback)
	self.activeCallback = callback
end



--[[

=head2 getUUID()

Returns the UUID and Mac address of this device.

=cut
--]]
function getUUID(self)
	return self.uuid, self.mac
end


--[[

=head2 setUUID(uuid, mac)

Sets the UUID and Mac address of this device.

=cut
--]]
function setUUID(self, uuid, mac)
	self.uuid = uuid
	self.mac = mac
end

--[[

=head2 getSNHostname()

Retreive the hostname to be used to connect to SqueezeNetwork

=cut
--]]
function getSNHostname(self)
	return "www.squeezenetwork.com"
end

--[[

=head2 __init()

Creates a new NetworkThread. The thread starts immediately.

=cut
--]]
function __init(self)
--	log:debug("NetworkThread:__init()")

	local obj = oo.rawnew(self, {
		-- list of sockets for select
		t_readSocks = {},
		t_writeSocks = {},

		-- list of objects for notify
		subscribers = {},

		activeCount = 0,
	})

	-- create dns resolver
	DNS(obj)

	return obj
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

