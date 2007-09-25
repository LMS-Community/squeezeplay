------------------------------------------------------------------------------
-- queue.lua
-----------------------------------------------------------------------------

--[[
=head1 NAME

jive.util.queue - mutexed queue for thread operations

=head1 DESCRIPTION

Queue protected by a mutex useful for inter-thread communications. 
This is derived from the queue module provided in the Luathread distribution
by Diego Nehab, but changed so that locking is optional when removing from an empty queue.

=head1 SYNOPSIS

 -- Create a new queue holding 10 elements
 local queue = jive.utils.queue.newqueue(10)

 -- insert element. this will lock the thread if the queue is full
 queue:insert(something)

 -- remove element. If lock is true, the thread may be locked
 local something = queue:remove(true)

=head1 FUNCTIONS

=cut
--]]


local thread = require("thread")
local metat = { __index = {} }
local setmetatable = setmetatable

module(...)


--[[

=head2 insert(value)

Inserts value in the queue. Will lock if the queue is full.

=cut
--]]
function metat.__index:insert(value)
	self.mutex:lock()
	
	while self.last - self.first >= self.size do
		self.notfull:wait(self.mutex)
	end
	
	local wasempty = (self.first == self.last)
	
	self[self.last] =  value
	self.last = self.last + 1
	
	if wasempty then 
		self.notempty:signal()
	end
	self.mutex:unlock()
end


--[[

=head2 remove(lock)

Removes an element from the queue. If lock is true, the thread may lock if the 
queue is empty. If lock is false and the queue is empty, the function returns nil.
Locking is false by default.

=cut
--]]
function metat.__index:remove(lock)

	-- no lock by default
--	if lock == nil then
--		lock = false
--	end

	self.mutex:lock()
	
	-- the queue is empty
	while self.first == self.last do
		
		-- if we don't want to lock, return nil
		if not lock then
			self.mutex:unlock()
			return nil
		end
		
		-- or wait for the notempty signal
		self.notempty:wait(self.mutex) 
	end
	
	local value = self[self.first]
	local wasfull = (self.last - self.first >= self.size)
	self[self.first] = nil
	self.first = self.first + 1
	
	if wasfull then
		self.notfull:signal() 
	end
	self.mutex:unlock()
	return value
end


--[[

=head2 len()

Returns the length of the queue

=cut
--]]
function metat.__index:len(lock)
	return self.last - self.first
end


--[[

=head2 newqueue(size)

Creates a new mutexed queue holding size elements.

=cut
--]]
function newqueue(size)
	local q = {
		mutex = thread.newmutex(), 
		notempty = thread.newcond(), 
		notfull = thread.newcond(), 
		first = 0, 
		last = 0,
		size = size
	}    
	return setmetatable(q, metat)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

