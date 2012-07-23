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
-- Title  : Lua Socket Wrapper for Cooperative Scheduling                     --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 05/03/2006 20:43                                                  --
--------------------------------------------------------------------------------

--[[VERBOSE]] local verbose = require("loop.thread.Scheduler").verbose
--[[VERBOSE]] verbose.groups.concurrency[#verbose.groups.concurrency+1] = "cosocket"

local ipairs       = ipairs
local assert       = assert
local setmetatable = setmetatable
local type         = type
local next         = next
local coroutine    = require "coroutine"
local oo           = require "loop.base"
local Wrapper      = require "loop.object.Wrapper"

module("loop.thread.CoSocket", oo.class)

--------------------------------------------------------------------------------
-- Initialization Code ---------------------------------------------------------
--------------------------------------------------------------------------------

function __init(class, self, scheduler)
	self = oo.rawnew(class, self)
	self.readlocks = {}
	self.writelocks = {}
	if not self.scheduler then
		self.scheduler = scheduler
	end
	return self
end

function __index(self, field)
	return _M[field] or self.socketapi[field]
end

--------------------------------------------------------------------------------
-- Wrapping functions ----------------------------------------------------------
--------------------------------------------------------------------------------

local function wrappedsettimeout(self, timeout)
	self.timeout = timeout or false
end

--------------------------------------------------------------------------------

local function wrappedconnect(self, host, port)                                 --[[VERBOSE]] verbose:cosocket(true, "performing blocking connect")
	local socket = self.__object
	socket:settimeout(-1)
	local result, errmsg = socket:connect(host, port)
	socket:settimeout(0)                                                          --[[VERBOSE]] verbose:cosocket(false, "blocking connect done")
	return result, errmsg
end

--------------------------------------------------------------------------------

local function wrappedaccept(self)                                              --[[VERBOSE]] verbose:cosocket(true, "performing wrapped accept")
	local socket    = self.__object
	local timeout   = self.timeout
	local cosocket  = self.cosocket
	local readlocks = cosocket.readlocks
	local scheduler = cosocket.scheduler
	local current   = scheduler:checkcurrent()

	assert(socket, "bad argument #1 to `accept' (wrapped socket expected)")
	assert(readlocks[socket] == nil, "attempt to read a socket in use")
	
	local conn, errmsg = socket:accept()
	if conn then                                                                  --[[VERBOSE]] verbose:cosocket(false, "connection accepted without waiting")
		return cosocket:wrap(conn)
	elseif timeout == 0 or errmsg ~= "timeout" then                               --[[VERBOSE]] verbose:cosocket(false, "returning error ",errmsg," without waiting")
		return nil, errmsg
	end                                                                           --[[VERBOSE]] verbose:cosocket(true, "waiting for results")

	local sleeping = scheduler.sleeping
	local reading = scheduler.reading

	-- subscribing current thread for reading signal
	reading:add(socket, current)                                                  --[[VERBOSE]] verbose:threads(current," subscribed for read signal")
	
	-- lock socket for reading and wait for signal until timeout
	readlocks[socket] = current
	scheduler:suspend(timeout)                                                    --[[VERBOSE]] verbose:cosocket(false, "wrapped accept resumed")
	readlocks[socket] = nil

	-- if thread is still blocked for reading then waiting timed out
	if reading[socket] == current then
		reading:remove(socket)                                                      --[[VERBOSE]] verbose:threads(current," unsubscribed for read signal")
		return nil, "timeout"                                                       --[[VERBOSE]] , verbose:cosocket(false, "waiting timed out")
	elseif timeout then
		sleeping:remove(current)                                                    --[[VERBOSE]] verbose:threads(current," removed from sleeping queue")
	end                                                                           --[[VERBOSE]] verbose:cosocket(false, "returing results after waiting")
	
	return cosocket:wrap(socket:accept())
end

--------------------------------------------------------------------------------

local function wrappedreceive(self, pattern)                                    --[[VERBOSE]] verbose:cosocket(true, "performing wrapped receive")
	local socket    = self.__object
	local timeout   = self.timeout
	local readlocks = self.cosocket.readlocks
	local scheduler = self.cosocket.scheduler
	local current   = scheduler:checkcurrent()

	assert(socket, "bad argument #1 to `receive' (wrapped socket expected)")
	assert(readlocks[socket] == nil, "attempt to read a socket in use")

	-- get data already avaliable
	local result, errmsg, partial = socket:receive(pattern)

	-- check if job has completed
	if not result and errmsg == "timeout" and timeout ~= 0 then                   --[[VERBOSE]] verbose:cosocket(true, "waiting for remaining of results")
		local running = scheduler.running
		local sleeping = scheduler.sleeping
		local reading = scheduler.reading
		
		-- set to be waken at timeout, if specified
		if timeout and timeout > 0 then
			sleeping:enqueue(current, scheduler:time() + timeout)                     --[[VERBOSE]] verbose:threads(current," registered for signal in ",timeout," seconds")
		end
	
		-- lock socket to avoid use by other coroutines
		readlocks[socket] = true
	
		-- block current thread on the socket
		reading:add(socket, current)                                                --[[VERBOSE]] verbose:threads(current," subscribed for read signal")
	
		-- reduce the number of required bytes
		if type(pattern) == "number" then
			pattern = pattern - #partial                                              --[[VERBOSE]] verbose:cosocket("amount of required bytes reduced to ",pattern)
		end
		
		repeat
			-- stop current thread
			running:remove(current, self.currentkey)                                  --[[VERBOSE]] verbose:threads(current," suspended")
			coroutine.yield()                                                         --[[VERBOSE]] verbose:cosocket(false, "wrapped receive resumed")
		
			-- check if the socket is ready
			if reading[socket] == current then
				reading:remove(socket)                                                  --[[VERBOSE]] verbose:threads(current," unsubscribed for read signal")
				errmsg = "timeout"                                                      --[[VERBOSE]] verbose:cosocket(false, "wrapped send timed out")
			else                                                                      --[[VERBOSE]] verbose:cosocket "reading more data from socket"
				local newdata
				result, errmsg, newdata = socket:receive(pattern)
				if result then                                                          --[[VERBOSE]] verbose:cosocket "received all requested data"
					result, errmsg, partial = partial..result, nil, nil                   --[[VERBOSE]] verbose:cosocket(false, "returning results after waiting")
				else                                                                    --[[VERBOSE]] verbose:cosocket "received only partial data"
					partial = partial..newdata
					
					if errmsg == "timeout" then
						-- block current thread on the socket for more data
						reading:add(socket, current)                                        --[[VERBOSE]] verbose:threads(current," subscribed for another read signal")
						
						-- reduce the number of required bytes
						if type(pattern) == "number" then
							pattern = pattern - #newdata                                      --[[VERBOSE]] verbose:cosocket("amount of required bytes reduced to ",pattern)
						end
						
						-- cancel error message
						errmsg = nil                                                        --[[VERBOSE]] else verbose:cosocket(false, "returning error ",errmsg," after waiting")
					end
				end
			end
		until result or errmsg
	
		-- remove from sleeping queue if it was waken because of data on socket.
		if timeout and timeout > 0 and errmsg ~= "timeout" then
			sleeping:remove(current)                                                  --[[VERBOSE]] verbose:threads(current," removed from sleeping queue")
		end
	
		-- unlock socket to allow use by other coroutines
		readlocks[socket] = nil                                                     --[[VERBOSE]] else verbose:cosocket(false, "returning results without waiting")
	end
	
	return result, errmsg, partial
end

--------------------------------------------------------------------------------

local function wrappedsend(self, data, i, j)                                    --[[VERBOSE]] verbose:cosocket(true, "performing wrapped send")
	local socket     = self.__object
	local timeout    = self.timeout
	local writelocks = self.cosocket.writelocks
	local scheduler  = self.cosocket.scheduler
	local current    = scheduler:checkcurrent()

	assert(socket, "bad argument #1 to `send' (wrapped socket expected)")
	assert(writelocks[socket] == nil, "attempt to write a socket in use")

	-- fill buffer space already avaliable
	local sent, errmsg, partial = socket:send(data, i, j)

	-- check if job has completed
	if not sent and errmsg == "timeout" and timeout ~= 0 then                     --[[VERBOSE]] verbose:cosocket(true, "waiting to send remaining data")
		local running = scheduler.running
		local sleeping = scheduler.sleeping
		local writing = scheduler.writing

		-- set to be waken at timeout, if specified
		if timeout and timeout > 0 then
			sleeping:enqueue(current, scheduler:time() + timeout)                     --[[VERBOSE]] verbose:threads(current," registered for signal in ",timeout," seconds")
		end
	
		-- lock socket to avoid use by other coroutines
		writelocks[socket] = true
	
		-- block current thread on the socket
		writing:add(socket, current)                                                --[[VERBOSE]] verbose:threads(current," subscribed for write signal")
	
		if not i then i = 1 end
	
		repeat
			-- stop current thread
			running:remove(current, self.currentkey)                                  --[[VERBOSE]] verbose:threads(current," suspended")
			coroutine.yield()                                                         --[[VERBOSE]] verbose:cosocket(false, "wrapped send resumed")
		
			-- check if the socket is ready
			if writing[socket] == current then
				writing:remove(socket)                                                  --[[VERBOSE]] verbose:threads(current," unsubscribed for write signal")
				errmsg = "timeout"                                                      --[[VERBOSE]] verbose:cosocket(false, "wrapped send timed out")
			else                                                                      --[[VERBOSE]] verbose.cosocket "writing remaining data into socket"
				local moresent
				sent, errmsg, moresent = socket:send(data, i + partial, j)
				if sent then                                                            --[[VERBOSE]] verbose.cosocket "sent all supplied data"
					sent, errmsg, partial = partial + sent, nil, nil                      --[[VERBOSE]] verbose:cosocket(false, "send completed after waiting")
				else                                                                    --[[VERBOSE]] verbose.cosocket "sent only partial data"
					partial = partial + moresent
					if errmsg == "timeout" then
						-- block current thread on the socket to write data
						writing:add(socket, current)                                        --[[VERBOSE]] verbose:threads(current," subscribed for another write signal")
						
						-- cancel error message
						errmsg = nil                                                        --[[VERBOSE]] else verbose:cosocket(false, "returning error ",errmsg," after waiting")
					end
				end
			end
		until sent or errmsg
	
		-- remove from sleeping queue, if it was waken because of data on socket.
		if timeout and timeout > 0 and errmsg ~= "timeout" then
			sleeping:remove(current)                                                  --[[VERBOSE]] verbose:threads(current," removed from sleeping queue")
		end
	
		-- unlock socket to allow use by other coroutines
		writelocks[socket] = nil                                                    --[[VERBOSE]] else verbose:cosocket(false, "send done without waiting")
	end
	
	return sent, errmsg, partial
end

--------------------------------------------------------------------------------
-- Wrapped Socket API ----------------------------------------------------------
--------------------------------------------------------------------------------

function select(self, recvt, sendt, timeout)                                    --[[VERBOSE]] verbose:cosocket(true, "performing wrapped select")
	local scheduler = self.scheduler
	local current = scheduler:checkcurrent()
		
	if (recvt and #recvt > 0) or (sendt and #sendt > 0) then
		local readlocks  = self.readlocks
		local writelocks = self.writelocks
		
		-- assert that no thread is already blocked on these sockets
		if recvt then
			for _, socket in ipairs(recvt) do
				assert(readlocks[socket] == nil, "attempt to read a socket in use")
			end
		end
		if sendt then
			for _, socket in ipairs(sendt) do
				assert(writelocks[socket] == nil, "attempt to write a socket in use")
			end
		end
		
		local readok, writeok, errmsg = scheduler.select(recvt, sendt, 0)
	
		if
			timeout ~= 0 and
			errmsg == "timeout" and
			next(readok) == nil and
			next(writeok) == nil
		then                                                                        --[[VERBOSE]] verbose:cosocket(true, "waiting for ready socket selection")
			local running = scheduler.running
			local sleeping = scheduler.sleeping
			local reading = scheduler.reading
			local writing = scheduler.writing
	
			-- block current thread on the sockets and lock them
			if recvt then
				for _, socket in ipairs(recvt) do
					readlocks[socket] = current
					reading:add(socket, current)                                          --[[VERBOSE]] verbose:threads(current," subscribed for read signal")
				end
			end
			if sendt then
				for _, socket in ipairs(sendt) do
					writelocks[socket] = current
					writing:add(socket, current)                                          --[[VERBOSE]] verbose:threads(current," subscribed for write signal")
				end
			end
			
			-- set to be waken at timeout, if specified
			if timeout and timeout > 0 then
				sleeping:enqueue(current, scheduler:time() + timeout)                   --[[VERBOSE]] verbose:threads(current," registered for signal in ",timeout," seconds")
			end
		
			-- stop current thread
			running:remove(current, self.currentkey)                                  --[[VERBOSE]] verbose:threads(current," suspended")
			coroutine.yield()                                                         --[[VERBOSE]] verbose:cosocket(false, "wrapped select resumed")
		
			-- remove from sleeping queue, if it was waken because of data on socket.
			if timeout and timeout > 0 then
				if sleeping:remove(current)
					then errmsg = nil                                                     --[[VERBOSE]] verbose:threads(current," removed from sleeping queue")
					else errmsg = "timeout"                                               --[[VERBOSE]] verbose:cosocket "wrapped select timed out"
				end
			end
		
			-- check which sockets are ready and remove block for other sockets
			if recvt then
				for _, socket in ipairs(recvt) do
					readlocks[socket] = nil
					if reading[socket] == current
						then reading:remove(socket)                                         --[[VERBOSE]] verbose:threads(current," unsubscribed for read signal")
						else readok[socket] = true
					end
				end
			end
			if sendt then
				for _, socket in ipairs(sendt) do
					writelocks[socket] = nil
					if writing[socket] == current
						then writing:remove(socket)                                         --[[VERBOSE]] verbose:threads(current," unsubscribed for write signal")
						else writeok[socket] = true
					end
				end
			end
		end                                                                         --[[VERBOSE]] verbose:cosocket(false, "returning selected sockets after waiting")
		
		return readok, writeok, errmsg
	else                                                                          --[[VERBOSE]] verbose:cosocket(false, "no sockets for selection")
		return {}, {}
	end
end

function sleep(self, timeout)
	assert(timeout, "bad argument #1 to `sleep' (number expected)")
	return self.scheduler:suspend(timeout)
end

function tcp(self)
	return self:wrap(self.socketapi.tcp())
end

function udp(self)
	return self:wrap(self.socketapi.udp())
end

function connect(self, address, port)
	return self:wrap(self.socketapi.connect(address, port))
end

function bind(self, address, port)
	return self:wrap(self.socketapi.bind(address, port))
end

function wrap(self, socket, ...)                                                --[[VERBOSE]] verbose:cosocket "new wrapped socket"
	if socket then
		socket:settimeout(0)
		socket = Wrapper {
			__object = socket,
			cosocket = self,
			timeout = false,

			settimeout = wrappedsettimeout,
			connect    = wrappedconnect,
			accept     = wrappedaccept,
			send       = wrappedsend,
			receive    = wrappedreceive,
		}
	end
	return socket, ...
end