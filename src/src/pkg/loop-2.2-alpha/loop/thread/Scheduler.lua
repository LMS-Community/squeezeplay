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
-- Title  : Cooperative Threads Scheduler based on Coroutines                 --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 05/03/2006 20:33                                                  --
--------------------------------------------------------------------------------

--[[VERBOSE]] local type        = type
--[[VERBOSE]] local unpack      = unpack
--[[VERBOSE]] local rawget      = rawget
--[[VERBOSE]] local select      = select
--[[VERBOSE]] local tostring    = tostring
--[[VERBOSE]] local string      = require "string"
--[[VERBOSE]] local table       = require "table"
--[[VERBOSE]] local math        = require "math"
--[[VERBOSE]] local ObjectCache = require "loop.collection.ObjectCache"
--[[VERBOSE]] local Verbose     = require "loop.debug.Verbose"
-- [[DEBUG]] local Inspector   = require "loop.debug.Inspector"

local luaerror      = error
local assert        = assert
local getmetatable  = getmetatable
local coroutine     = require "coroutine"
local os            = require "os"
local oo            = require "loop.base"
local OrderedSet    = require "loop.collection.OrderedSet"
local PriorityQueue = require "loop.collection.PriorityQueue"

local traceback = debug and debug.traceback or function(_, err) return err end

module("loop.thread.Scheduler", oo.class)

--------------------------------------------------------------------------------
-- Initialization Code ---------------------------------------------------------
--------------------------------------------------------------------------------

local WeakSet = oo.class{ __mode = "k" }
function __init(class, self)
	self = oo.rawnew(class, self)
	self.traps           = WeakSet()
	self.running         = OrderedSet()
	self.sleeping        = PriorityQueue()
	self.sleeping.wakeup = self.sleeping.priority
	self.current         = false
	self.currentkey      = OrderedSet.firstkey
	return self
end
__init(getmetatable(_M), _M)

--------------------------------------------------------------------------------
-- Coroutine Compatible pcall --------------------------------------------------
--------------------------------------------------------------------------------

-- NOTE:[maia] Maps running threads to the scheduled threads they were created
--             and also keeps a linked list of upper pcall threads that starts
--             at the scheduled thread. See below for an example:
--             Coroutine hierarchy:
--               current -> pcall1 -> pcall2 -> pcall3 -> pcall4
--             PCallMap = {
--               [pcall4] = current,
--               [current] = pcall3,
--               [pcall3] = pcall2,
--               [pcall2] = pcall1,
--             }
local PCallMap = {}

local function resumepcall(pcall, success, ...)
	if coroutine.status(pcall) == "suspended" then
		return resumepcall(pcall, coroutine.resume(pcall, coroutine.yield(...)))
	else
		local current = PCallMap[pcall]                                             --[[VERBOSE]] verbose:copcall(false, "protected call finished in ",current)
		local running = PCallMap[current]
		if running then
			PCallMap[current] = PCallMap[running]
			PCallMap[running] = current
		end
		PCallMap[pcall] = nil
		return success, ...
	end
end

function pcall(func, ...)
	local pcall = coroutine.create(func)
	local running = coroutine.running()
	local current = PCallMap[running]                                             --[[VERBOSE]] verbose:copcall(true, "new protected call in ",current or running)
	if current then
		PCallMap[running] = PCallMap[current]
		PCallMap[current] = running
		PCallMap[pcall] = current
	else
		PCallMap[pcall] = running
	end
	return resumepcall(pcall, coroutine.resume(pcall, ...))
end

function checkcurrent(self)
	local current = self.current
	local running = coroutine.running()
	assert(current,
		"attempt to call scheduler operation out of a scheduled routine context.")
	assert(current == running or PCallMap[running] == current,
		"inconsistent internal state, current scheduled routine is not running.")
	return current
end

--------------------------------------------------------------------------------
-- Internal Functions ----------------------------------------------------------
--------------------------------------------------------------------------------

function resumeall(self, success, ...)
	local routine = self.current
	if routine then                                                               --[[VERBOSE]] verbose:threads(false, routine," yielded")
		if coroutine.status(routine) == "dead" then      														--[[VERBOSE]] verbose:threads(routine," has finished")
			self.current = false
			self.running:remove(routine, self.currentkey)
			local trap = self.traps[routine]
			if trap then                                                              --[[VERBOSE]] verbose:threads(true, "executing trap for ",routine)
				trap(self, routine, success, ...)                                       --[[VERBOSE]] verbose:threads(false)
			elseif not success then                                                   --[[VERBOSE]] verbose:threads("uncaptured error on ",routine)
				self:error(routine, ...)
			end
		elseif self.running:contains(routine) then
			self.currentkey = routine
		end                                                                         --[[VERBOSE]] else verbose:scheduler(true, "resuming running threads")
	end
	routine = self.running[self.currentkey] 
	if routine then
		self.current = routine                                                      --[[VERBOSE]] verbose:threads(true, "resuming ",routine)
		return self:resumeall(coroutine.resume(routine, ...))
	else                                                                          --[[VERBOSE]] verbose:scheduler(false, "running threads resumed")
		self.currentkey = OrderedSet.firstkey
		self.current = false
		return success ~= nil
	end
end

function wakeupall(self)
	local sleeping = self.sleeping
	if sleeping:head() then                                                       --[[VERBOSE]] verbose:scheduler(true, "waking sleeping threads up")
		local running = self.running
		local now = self:time()
		repeat
			if sleeping:wakeup(sleeping:head()) <= now
				then running:enqueue(sleeping:dequeue())                                --[[VERBOSE]] verbose:threads(self.running:tail()," woke up")
				else break
			end
		until sleeping:empty()                                                      --[[VERBOSE]] verbose:scheduler(false, "sleeping threads waken")
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Customizable Behavior -------------------------------------------------------
--------------------------------------------------------------------------------

local StartTime = os.time()
function time(self)
	return os.difftime(os.time(), StartTime)
end

function idle(self, timeout)                                                    --[[VERBOSE]] verbose:scheduler(true, "starting busy-waiting for ",timeout," seconds")
	if timeout then repeat until self:time() > timeout end                        --[[VERBOSE]] verbose:scheduler(false, "busy-waiting ended")
end

function error(self, routine, errmsg)
	luaerror(traceback(routine, errmsg))
end

--------------------------------------------------------------------------------
-- Exported API ----------------------------------------------------------------
--------------------------------------------------------------------------------

function register(self, routine, previous)                                      --[[VERBOSE]] verbose:threads("registering ",routine)
	return not self.sleeping:contains(routine) and
	       self.running:insert(routine, previous)
end

function remove(self, routine)                                                  --[[VERBOSE]] verbose:threads("removing ",routine)
	if self.current == routine
		then return self.running:remove(routine, self.currentkey)
		else return self.running:remove(routine) or self.sleeping:remove(routine)
	end
end

function suspend(self, time)
	local routine = self:checkcurrent()
	self.running:remove(routine, self.currentkey)
	if time then self.sleeping:enqueue(routine, self:time() + time) end           --[[VERBOSE]] verbose:threads(routine," waiting for ",time," seconds")
	return coroutine.yield()
end

function resume(self, routine, ...)                                             --[[VERBOSE]] verbose:threads("resuming ",routine)
	local current = self:checkcurrent()
	if not self:register(routine, current) then
		self:register(self:remove(routine), current)
	end                        
	return coroutine.yield(...)
end

function start(self, func, ...)
	self.running:insert(coroutine.create(func), self:checkcurrent())
	return coroutine.yield(...)
end

--------------------------------------------------------------------------------
-- Control Functions -----------------------------------------------------------
--------------------------------------------------------------------------------

function step(self)                                                             --[[VERBOSE]] verbose:scheduler(true, "performing scheduling step")
	local woken = self:wakeupall()
	local resumed = self:resumeall()                                              --[[VERBOSE]] verbose:scheduler(false, "scheduling step performed")
	return woken or resumed
end

function run(self, timeout)                                                     --[[VERBOSE]] verbose:scheduler(true, "running scheduler until ",timeout)
	if self:step() then
		local now = self:time()
		if not timeout or timeout > now then
			local running = self.running
			local sleeping = self.sleeping
			if running:empty() then
				local nextwake = sleeping:head()
				if nextwake then
					nextwake = sleeping:wakeup(nextwake)
					if timeout and timeout < nextwake then nextwake = timeout end 
				end                                                                     --[[VERBOSE]] verbose:scheduler(true, "idle until ",nextwake)
				self:idle(nextwake)                                                     --[[VERBOSE]] verbose:scheduler(false, "resuming scheduling")
			end                                                                       --[[VERBOSE]] verbose:scheduler(false, "reissue scheduling")
			return self:run(timeout)                                                  --[[VERBOSE]] else verbose:scheduler(false, "scheduling timed out")
		end                                                                         --[[VERBOSE]] else verbose:scheduler(false, "no thread pending scheduling")
	end
end

--------------------------------------------------------------------------------
-- Verbose Support -------------------------------------------------------------
--------------------------------------------------------------------------------

--[[VERBOSE]] local LabelStart = string.byte("A")
--[[VERBOSE]] local labels = ObjectCache{ current = 0 }
--[[VERBOSE]] function labels:retrieve()
--[[VERBOSE]] 	local id = self.current
--[[VERBOSE]] 	local label = {}
--[[VERBOSE]] 	repeat
--[[VERBOSE]] 		table.insert(label, LabelStart + (id % 26))
--[[VERBOSE]] 		id = math.floor(id / 26)
--[[VERBOSE]] 	until id <= 0
--[[VERBOSE]] 	self.current = self.current + 1
--[[VERBOSE]] 	return string.char(unpack(label))
--[[VERBOSE]] end
--[[VERBOSE]] 
--[[VERBOSE]] verbose = Verbose()
--[[VERBOSE]] verbose.groups.concurrency = { "scheduler", "threads", "copcall" }
--[[VERBOSE]] function verbose.custom:threads(...)
--[[VERBOSE]] 	local viewer  = self.viewer
--[[VERBOSE]] 	local output  = self.viewer.output
--[[VERBOSE]] 	
--[[VERBOSE]] 	for i = 1, select("#", ...) do
--[[VERBOSE]] 		local value = select(i, ...)
--[[VERBOSE]] 		if type(value) == "string" then
--[[VERBOSE]] 			output:write(value)
--[[VERBOSE]] 		elseif type(value) == "thread" then
--[[VERBOSE]] 			output:write("thread ")
--[[VERBOSE]] 			output:write(labels[value])
--[[VERBOSE]] 		else
--[[VERBOSE]] 			viewer:write(value)
--[[VERBOSE]] 		end
--[[VERBOSE]] 	end
--[[VERBOSE]] 	
--[[VERBOSE]] 	local scheduler = rawget(self, "schedulerdetails")
--[[VERBOSE]] 	if scheduler then
--[[VERBOSE]] 		local newline = "\n"..viewer.prefix..viewer.indentation
--[[VERBOSE]] 	
--[[VERBOSE]] 		output:write(newline)
--[[VERBOSE]] 		output:write("Current: ")
--[[VERBOSE]] 		output:write(tostring(labels[scheduler.current]))
--[[VERBOSE]] 	
--[[VERBOSE]] 		output:write(newline)
--[[VERBOSE]] 		output:write("Running:")
--[[VERBOSE]] 		for current in scheduler.running:sequence() do
--[[VERBOSE]] 			output:write(" ")
--[[VERBOSE]] 			output:write(tostring(labels[current]))
--[[VERBOSE]] 		end
--[[VERBOSE]] 	
--[[VERBOSE]] 		output:write(newline)
--[[VERBOSE]] 		output:write("Sleeping:")
--[[VERBOSE]] 		for current in scheduler.sleeping:sequence() do
--[[VERBOSE]] 			output:write(" ")
--[[VERBOSE]] 			output:write(tostring(labels[current]))
--[[VERBOSE]] 		end
--[[VERBOSE]] 	end
--[[VERBOSE]] end
--[[VERBOSE]] 
-- [[DEBUG]] verbose.I = Inspector()
-- [[DEBUG]] function verbose.inspect:debug() self.I:stop(4) end
-- [[DEBUG]] verbose:flag("debug", true)
