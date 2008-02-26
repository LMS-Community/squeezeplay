--------------------------------------------------------------------------------
---------------------- ##       #####    #####   ######  -----------------------
---------------------- ##      ##   ##  ##   ##  ##   ## -----------------------
---------------------- ##      ##   ##  ##   ##  ######  -----------------------
---------------------- ##      ##   ##  ##   ##  ##      -----------------------
---------------------- ######   #####    #####   ##      -----------------------
----------------------                                   -----------------------
----------------------- Lua Object-Oriented Programming ------------------------
--------------------------------------------------------------------------------
-- Project: LOOP Class Library                                                --
-- Release: 2.2 alpha                                                         --
-- Title  : Cooperative Threads Scheduler with Integrated I/O                 --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 05/03/2006 20:41                                                  --
--------------------------------------------------------------------------------

local ipairs             = ipairs
local getmetatable       = getmetatable
local math               = require "math"
local oo                 = require "loop.simple"
local MapWithArrayOfKeys = require "loop.collection.MapWithArrayOfKeys"
local Scheduler          = require "loop.thread.Scheduler"

module "loop.thread.IOScheduler"

oo.class(_M, Scheduler)

--------------------------------------------------------------------------------
-- Initialization Code ---------------------------------------------------------
--------------------------------------------------------------------------------

function __init(class, self)
	self = Scheduler.__init(class, self)
	self.reading = MapWithArrayOfKeys()
	self.writing = MapWithArrayOfKeys()
	return self
end
__init(getmetatable(_M), _M)

--------------------------------------------------------------------------------
-- Internal Functions ----------------------------------------------------------
--------------------------------------------------------------------------------

function signalall(self, timeout)
	if timeout then timeout = math.max(timeout - self:time(), 0) end
	local reading, writing = self.reading, self.writing
	if #reading > 0 or #writing > 0 then                                          --[[VERBOSE]] verbose:scheduler(true, "signaling blocked threads for ",timeout," seconds")
		local running = self.running
		local readok, writeok = self.select(reading, writing, timeout)
		local index = 1
		while index <= #reading do
			local channel = reading[index]
			if readok[channel] then                                                   --[[VERBOSE]] verbose:threads("unblocking reading ",reading[channel])
				running:enqueue(reading[channel])
				reading:removeat(index)
			else
				index = index + 1
			end
		end
		index = 1
		while index <= #writing do
			local channel = writing[index]
			if writeok[channel] then                                                  --[[VERBOSE]] verbose:threads("unblocking writing ", writing[channel])
				running:enqueue(writing[channel])
				writing:removeat(index)         
			else
				index = index + 1
			end
		end                                                                         --[[VERBOSE]] verbose:scheduler(false,  "blocked threads signaled")
		return true
	elseif timeout and timeout > 0 then                                           --[[VERBOSE]] verbose:scheduler("no threads blocked, sleeping for ",timeout," seconds")
		self.sleep(timeout)
	end
	return false
end

--------------------------------------------------------------------------------
-- Customizable Behavior -------------------------------------------------------
--------------------------------------------------------------------------------

idle = signalall

--------------------------------------------------------------------------------
-- Exported API ----------------------------------------------------------------
--------------------------------------------------------------------------------

function register(self, routine, previous)
	local reading, writing = self.reading, self.writing
	for _, channel in ipairs(reading) do
		if reading[channel] == routine then return end
	end
	for _, channel in ipairs(writing) do
		if writing[channel] == routine then return end
	end
	return Scheduler.register(self, routine, previous)
end

function remove(self, routine)                                                  --[[VERBOSE]] verbose:threads("removing ",routine)
	if self.current == routine
		then self.running:remove(routine, self.currentkey)
		else self.running:remove(routine)
	end
	
	self.sleeping:remove(routine)

	local reading, writing = self.reading, self.writing
	local index = 1
	while index <= #reading do
		local channel = reading[index]
		if reading[channel] == routine
			then reading:removeat(index)
			else index = index + 1
		end
	end
	index = 1
	while index <= #writing do
		local channel = writing[index]
		if writing[channel] == routine
			then writing:removeat(index)         
			else index = index + 1
		end
	end
end

--------------------------------------------------------------------------------
-- Control Functions -----------------------------------------------------------
--------------------------------------------------------------------------------

function step(self)                                                             --[[VERBOSE]] verbose:scheduler(true, "performing scheduling step")
	local signaled = self:signalall(0)
	local wokenup = self:wakeupall()
	local resumed = self:resumeall()                                              --[[VERBOSE]] verbose:scheduler(false, "scheduling step performed")
	return signaled or wokenup or resumed
end
