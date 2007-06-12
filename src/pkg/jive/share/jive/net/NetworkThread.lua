
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
local tostring, table, ipairs, pairs, type  = tostring, table, ipairs, pairs, type
local require = require

local thread            = require("thread")
local socket            = require("socket")
local oo                = require("loop.base")

local queue             = require("jive.utils.queue")
local Event             = require("jive.ui.Event")
local Framework         = require("jive.ui.Framework")

local log               = require("jive.utils.log").logger("net.thread")

local EVENT_SERVICE_JNT = jive.ui.EVENT_SERVICE_JNT
local EVENT_CONSUME     = jive.ui.EVENT_CONSUME

-- jive.net.NetworkThread is a base class
module(..., oo.class)

-- constants
local QUEUE_SIZE        = 50   -- size of the queue from/to the jnt
local TIMEOUT           = 0.1  -- select timeout
local QUEUE_PROCESS     = 5    -- number of queue items processed by loop (network thread side)


-- _add
-- adds a socket to the read or write list
local function _add(sock, pump, sockList)
--	log:debug("_add(", tostring(sock), ", ", tostring(pump), ")")
	
	if not sock then 
		return
	end
	
	-- add us if we're not already in there
	if not sockList[sock] then
	
		-- add the socket to the sockList
		table.insert(sockList, sock)
	end	
	
	-- remember the pump
	sockList[sock] = pump
end


-- _remove
-- removes a socket from the read or write list
local function _remove(sock, sockList)
--	log:debug("_remove(", tostring(sock), ")")
	
	if not sock then 
		return 
	end

	-- remove the socket from the sockList
	if sockList[sock] then
		
		sockList[sock] = nil

		for i,v in ipairs(sockList) do
			if v == sock then
				table.remove(sockList, i)
				return
			end
		end
	end
end


-- t_add/remove/read/write
-- add/remove sockets api
function t_addRead(self, sock, pump)
--	log:debug("NetworkThread:t_addRead()")
	
	_add(sock, pump, self.t_readSocks)
end

function t_removeRead(self, sock)
--	log:debug("NetworkThread:t_removeRead()")
	
	_remove(sock, self.t_readSocks)
end

function t_addWrite(self, sock, pump)
--	log:debug("NetworkThread:t_addWrite()")
	
	_add(sock, pump, self.t_writeSocks)
end

function t_removeWrite(self, sock)
--	log:debug("NetworkThread:t_removeWrite()")
	
	_remove(sock, self.t_writeSocks)
end


-- _t_select
-- runs our sockets through select
local function _t_select(self)
--	log:debug("_t_select(r", tostring(#self.t_readSocks), " w", tostring(#self.t_writeSocks), ")")
	
	local r,w,e = socket.select(self.t_readSocks, self.t_writeSocks, TIMEOUT)
	
	if e and self.running then
		-- timeout is a normal error for select if there's nothing to do!
		if e ~= 'timeout' then
			log:error(e)
		end
	else

		log:warn("profiler is " .. tostring(profiler))

		profiler.start("lprof.out")

		-- call the write pumps
		for i,v in ipairs(w) do
			self.t_writeSocks[v]()
		end
		
		-- call the read pumps
		for i,v in ipairs(r) do
			self.t_readSocks[v]()
		end

		profiler.stop()
	end
end


-- _t_dequeue
-- fetches messages from the main thread
local function _t_dequeue(self)
--	log:debug("_t_dequeue()")
	
	local msg = true
	local count = 0
	
	while msg and count < QUEUE_PROCESS do
	
		msg = self.in_queue:remove(false)
		
		if msg then
			msg()
			count = count + 1
		end
	end
end


-- _thread
-- the thread function with the endless loop
local function _t_thread(self)
--	log:debug("_t_thread()")
	
--	log:info("NetworkThread starting...")

	profiler = require("profiler")
	
	while self.running do
		
		_t_select(self)
		
		_t_dequeue(self)
	end
	
	-- clean up here
--	log:info("NetworkThread exiting...")
	self.t_readSocks = nil
	self.t_writeSocks = nil
end


-- t_perform
-- queues a function for execution main thread side
function t_perform(self, func)

	self.out_queue:insert(func)

	-- push event to wake up main thread
	local evt = Event:new(EVENT_SERVICE_JNT)
	Framework:pushEvent(evt)
end


--[[

=head2 NetworkThread:stop()

Sends a message to stop the thread.

=cut
--]]
function stop(self)
--	log:info("NetworkThread:stop()")
	
	self:perform(function() self.running = false end)
end


--[[

=head2 NetworkThread:perform(func)

Queues a function for execution thread side.

=cut
--]]
function perform(self, func)
--	log:debug("NetworkThread:perform()")
	
	if func then
		self.in_queue:insert(func)	
	end
end


--[[

=head2 NetworkThread:idle()

Processes the queue on the main thread side. Messages are closures (functions), and simply called.

=cut
--]]
function idle(self)
--	log:debug("NetworkThread:idle()")
	
	msg = self.out_queue:remove(false)
	if msg then
		msg()
	end
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
--	log:info("NetworkThread:notify(", tostring(event), ")")
	
	local method = "notify_" .. event
	
	for k,v in pairs(self.subscribers) do
		if k[method] and type(k[method]) == 'function' then
			k[method](k, ...)
		end
	end
end


--[[

=head2 __init()

Creates a new NetworkThread. The thread starts immediately.

=cut
--]]
function __init(self)
--	log:debug("NetworkThread:__init()")

	local obj = oo.rawnew(self, {
		-- create our in and out queues (mutexed)
		in_queue = queue.newqueue(QUEUE_SIZE),
		out_queue = queue.newqueue(QUEUE_SIZE),

		-- list of sockets for select
		t_readSocks = {},
		t_writeSocks = {},

		-- list of objects for notify
		subscribers = {},
		
		running = true,
	})


	-- create callback to service queue in main thread
	Framework:addListener(EVENT_SERVICE_JNT,
			      function()
				      obj:idle()
				      return EVENT_CONSUME
			      end)
	
	-- we're running
	thread.newthread(_t_thread, {obj})
	
	return obj
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

