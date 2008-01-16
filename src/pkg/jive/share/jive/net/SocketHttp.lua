
--[[
=head1 NAME

jive.net.SocketHttp - An HTTP socket.

=head1 DESCRIPTION

This class implements a HTTP socket running in a L<jive.net.NetworkThread>.

=head1 SYNOPSIS

 -- create a HTTP socket to communicate with http://192.168.1.1:9000/
 local http = jive.net.SocketHttp(jnt, "192.168.1.1", 9000, "slimserver")

 -- create a request (see L<jive.net.RequestHttp)
 local req = RequestHttp(sink, 'GET', '/xml/status.xml')

 -- go get it!
 http:fetch(req)


=head1 FUNCTIONS

=cut
--]]
-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------


-- stuff we use
local _assert, tostring, tonumber, type = _assert, tostring, tonumber, type
local setmetatable, pairs = setmetatable, pairs

local math        = require("math")
local table       = require("table")
local string      = require("string")
local debug       = require("debug")
local coroutine   = require("coroutine")

local oo          = require("loop.simple")
local socket      = require("socket")
local socketHttp  = require("socket.http")
local ltn12       = require("ltn12")

local SocketTcp   = require("jive.net.SocketTcp")
local RequestHttp = require("jive.net.RequestHttp")

local locale      = require("jive.utils.locale")
local log         = require("jive.utils.log").logger("net.http")

local JIVE_VERSION = jive.JIVE_VERSION

-- jive.net.SocketHttp is a subclass of jive.net.SocketTcp
module(...)
oo.class(_M, SocketTcp)


local SOCKET_TIMEOUT = 70 -- timeout for socket operations (seconds)


--[[

=head2 jive.net.SocketHttp(jnt, address, port, name)

Creates an HTTP socket named I<name> to interface with the given I<jnt> 
(a L<jive.net.NetworkThread> instance). I<name> is used for debugging and
defaults to "". I<address> and I<port> are the hostname/IP address and port of the HTTP server.

=cut
--]]
function __init(self, jnt, address, port, name)
	--log:debug("SocketHttp:__init(", name, ", ", address, ", ", port, ")")

	-- init superclass
	local obj = oo.rawnew(self, SocketTcp(jnt, address, port, name))

	-- init states
	obj.t_httpSendState = 't_sendDequeue'
	obj.t_httpRcvState = 't_rcvDequeue'
	
	-- init queues
	obj.t_httpSendRequests = {}
	obj.t_httpSending = false
	obj.t_httpRcvRequests = {}
	obj.t_httpReceiving = false
	
	obj.t_httpProtocol = '1.1'
	
	return obj
end


--[[

=head2 jive.net.SocketHttp:fetch(request)

Use the socket to fetch an HTTP request.
I<request> must be an instance of class L<jive.net.RequestHttp>.
The class maintains an internal queue of requests to fetch.

=cut
--]]
function fetch(self, request)
	_assert(oo.instanceof(request, RequestHttp), tostring(self) .. ":fetch() parameter must be RequestHttp - " .. type(request) .. " - ".. debug.traceback())

	-- push the request
	table.insert(self.t_httpSendRequests, request)

--	log:info(self, " queuing ", request, " - ", #self.t_httpSendRequests, " requests in queue")
		
	-- start the state machine if it is idle
	self:t_sendDequeueIfIdle()
end


-- t_sendNext
-- manages the http state machine for sending stuff to the server
function t_sendNext(self, go, newState)
--	log:debug(self, ":t_sendNext(", go, ", ", newState, ")")

	if newState then
		_assert(self[newState] and type(self[newState]) == 'function')
		self.t_httpSendState = newState
	end
	
	if go then
		-- call the function
		-- self:XXX(bla) is really the same as self["XXX"](self, bla)
		self[self.t_httpSendState](self)
	end
end


-- t_dequeueRequest
-- removes a request from the queue, can be overridden by sub-classes
function _dequeueRequest(self)
	if #self.t_httpSendRequests > 0 then
		return table.remove(self.t_httpSendRequests, 1)
	end

	return nil
end


-- t_sendDequeue
-- removes a request from the queue
function t_sendDequeue(self)
--	log:debug(self, ":t_sendDequeue()")
	
	self.t_httpSending = self:_dequeueRequest()

	if self.t_httpSending then
--		log:info(self, " processing ", self.t_httpSending)
		self:t_sendNext(true, 't_sendConnect')
		return
	end
	
	-- back to idle
--	log:info(self, ": no request in queue")

	if self:connected() then
		local pump = function(NetworkThreadErr)
				     self:close("connect closed")
			     end

		self:t_addRead(pump, 0) -- No timeout
	end
end


-- t_sendDequeueIfIdle
-- causes a dequeue and processing on the send queue if possible
function t_sendDequeueIfIdle(self)
	if self.t_httpSendState == 't_sendDequeue' then
		self:t_sendNext(true)
	end
end


-- t_sendConnect
-- open our socket
function t_sendConnect(self)
--	log:debug(self, ":t_sendConnect()")
	
	if not self:connected() then
		local err = socket.skip(1, self:t_connect())
	
		if err then
			log:error(self, ":t_sendConnect: ", err)
			self:close(err)
			return
		end
	end
		
	self:t_sendNext(true, 't_sendRequest')
end


-- t_getSendHeaders
-- calculates the headers to send from a socket perspective
function t_getSendHeaders(self)
--	log:debug(self, ":t_getSendHeaders()")

	-- default set
	local headers = {
		["User-Agent"] = 'Jive/' .. JIVE_VERSION,
	}
	
	local req_headers = self.t_httpSending:t_getRequestHeaders()
	if not req_headers["Host"] then
		local address, port = self:t_getAddressPort()
		headers["Host"] = address
		if port != 80 then
			headers["Host"] = headers["Host"] .. ':' .. port
		end
	end
	
	if self.t_httpSending:t_hasBody() then
		headers["Content-Length"] = #self.t_httpSending:t_body()
	end

	req_headers["Accept-Language"] = string.lower(locale.getLocale())	
	return headers
end


-- keep-open-non-blocking socket sink
-- our "keep-open" sink, added to the socket namespace so we can use it like any other
-- our version is non blocking
socket.sinkt["keep-open-non-blocking"] = function(sock)
	local first = 0
	return setmetatable(
		{
			getfd = function() return sock:getfd() end,
			dirty = function() return sock:dirty() end
		}, 
		{
			__call = function(self, chunk, err)
--				log:debug("keep-open-non-blocking sink(", chunk and #chunk, ", ", tostring(err), ", ", tostring(first), ")")
				if chunk then 
					local res, err
					-- if send times out, err is 'timeout' and first is updated.
					res, err, first = sock:send(chunk, first+1)
--					log:debug("keep-open-non-blocking sent - first is ", tostring(first), " returning ", tostring(res), ", " , tostring(err))
					-- we return the err
					return res, err
				else 
					return 1 
				end
			end
		}
	)
end


-- t_sendRequest
-- send the headers, aggregates request and socket headers
function t_sendRequest(self)
--	log:debug(self, ":t_sendRequest()")
	
	local source = function()
	
		local line1 = string.format("%s HTTP/%s", self.t_httpSending:t_getRequestString(), self.t_httpProtocol)

		local t = {}
		
		table.insert(t, line1)
		
		for k, v in pairs(self:t_getSendHeaders()) do
			table.insert(t, k .. ": " .. v)
		end
		for k, v in pairs(self.t_httpSending:t_getRequestHeaders()) do
			table.insert(t, k .. ": " .. v)
		end
		
		table.insert(t, "")
		if self.t_httpSending:t_hasBody() then
			table.insert(t, self.t_httpSending:t_body())
		else
			table.insert(t, "")
		end

		return table.concat(t, "\r\n")
	end

	local sink = socket.sink('keep-open-non-blocking', self.t_sock)
	
	local pump = function (NetworkThreadErr)
--		log:debug(self, ":t_sendRequest.pump()")
		
		if NetworkThreadErr then
			log:error(self, ":t_sendRequest.pump: ", NetworkThreadErr)
			self:close(NetworkThreadErr)
			return
		end
		
		local ret, err = ltn12.pump.step(source, sink)
		
		
		if err then
			-- do nothing on timeout, we will be called again to send the rest of the data...
			if err == 'timeout' then
				return
			end

			-- handle any "real" error
			log:error(self, ":t_sendRequest.pump: ", err)
			self:close(err)
			return
		end
		
		-- no error, we're done, move on!
		self:t_removeWrite()
		self:t_sendNext(true, 't_sendReceive')
	end

	self:t_addWrite(pump, SOCKET_TIMEOUT)
end


-- t_sendReceive
--
function t_sendReceive(self)
--	log:debug(self, ":t_sendReceive()")
	
	-- we're done sending request, add it to receive queue
	if self.t_httpSending then
		table.insert(self.t_httpRcvRequests, self.t_httpSending)
		self.t_httpSending = nil
		
		-- get the receive game rolling if possible
		if self.t_httpRcvState == 't_rcvDequeue' then
			self:t_rcvNext(true)
		end
	end
	
	-- stay put until told we can dequeue next
	self:t_sendNext(false, 't_sendReceive')
end


-- t_rcvNext
-- manages the http state machine for receiving server data
function t_rcvNext(self, go, newState)
--	log:debug(self, ":t_rcvNext(", go, ", ", newState, ")")

	if newState then
		_assert(self[newState] and type(self[newState]) == 'function')
		self.t_httpRcvState = newState
	end
	
	if go then
		-- call the function
		-- self:XXX(bla) is really the same as self["XXX"](self, bla)
		self[self.t_httpRcvState](self)
	end
end


-- t_rcvDequeue
--
function t_rcvDequeue(self)
--	log:debug(self, ":t_rcvDequeue()")
	
	if #self.t_httpRcvRequests > 0 then
		self.t_httpReceiving = table.remove(self.t_httpRcvRequests, 1)
		self:t_rcvNext(true, 't_rcvHeaders')
	end
end


-- t_rcvHeaders
--
function t_rcvHeaders(self)
--	log:debug(self, ":t_rcvHeaders()")

	local line, err, partial = true
	local source = function()
		line, err, partial = self.t_sock:receive('*l', partial)
		if err then
			if err == 'timeout' then
				return
			end

			log:error(self, ":t_rcvHeaders.pump:", err)
			self:close(err)
			return false, err
		end

		return line
	end


	local headers = {}
	local statusCode = false
	local statusLine = false

	local pump = function (NetworkThreadErr)
--		log:debug(self, ":t_rcvHeaders.pump()")
		if NetworkThreadErr then
			log:error(self, ":t_rcvHeaders.pump:", err)
			--self:t_removeRead()
			self:close(err)
			return
		end

		-- read status line
		if not statusCode then
			local line, err = source()
			if err then
				return false, err
			end

			local data = socket.skip(2, string.find(line, "HTTP/%d*%.%d* (%d%d%d)"))
				
			if data then
				statusCode = tonumber(data)
				statusLine = chunk
			else
				return false, "cannot parse: " .. chunk
			end
		end

		-- read headers
		while true do
			local line, err = source()
			if err then
				return false, err
			end

			if line ~= "" then
				local name, value = socket.skip(2, string.find(line, "^(.-):%s*(.*)"))
				if not (name and value) then
					err = "malformed reponse headers"
					log:warn(err)
					self:close(err)
					return false, err
				end

				headers[name] = value
			else
				-- we're done
				self.t_httpReceiving:t_setResponseHeaders(statusCode, statusLine, headers)

				-- release send queue
				self:t_sendNext(false, 't_sendDequeue')
		
				-- move on to our future...
				self:t_rcvNext(true, 't_rcvResponse')
				return
			end
		end
	end
	
	self:t_addRead(pump, SOCKET_TIMEOUT)
end


-- jive-until-close socket source
-- our "until-close" source, added to the socket namespace so we can use it like any other
-- the code is identical to the one in socket, except we return the closed error when 
-- it happens. The source/sink concept is based on the fact sources are called until 
-- they signal no more data (by returning nil). We can't use that however since the 
-- pump won't be called in select!
socket.sourcet["jive-until-closed"] = function(sock, self)
	local done
	local partial
	return setmetatable(
		{
			getfd = function() return sock:getfd() end,
			dirty = function() return sock:dirty() end
		}, 
		{
			__call = function()
			
				if done then 
					return nil 
				end
			
				local chunk, err
				chunk, err, partial = sock:receive(socket.BLOCKSIZE, partial)
				
				if not err then 
					return chunk
				elseif err == "closed" then
					--close the socket using self
					SocketTcp.close(self)
					done = true
					return partial, 'done'
				else -- including timeout
					return nil, err 
				end
			end
		}
	)
end


-- jive-by-length socket source
-- same principle as until-close, we need to return somehow the fact we're done
socket.sourcet["jive-by-length"] = function(sock, length)
	local partial
	return setmetatable(
		{
			getfd = function() return sock:getfd() end,
			dirty = function() return sock:dirty() end
		}, 
		{
			__call = function()
				if length <= 0 then 
					return nil, 'done' 
				end
				
				local size = math.min(socket.BLOCKSIZE, length)
				
				local chunk, err
				chunk, err, partial = sock:receive(size, partial)
				
				if err then -- including timeout
					return nil, err 
				end
				length = length - string.len(chunk)
				if length <= 0 then
					return chunk, 'done'
				else
					return chunk
				end
			end
		}
	)
end


-- jive-http-chunked source
-- same as the one in http, except does not attempt to read headers after
-- last chunk and returns 'done' pseudo error
socket.sourcet["jive-http-chunked"] = function(sock)
	local partial
	local schunk
	local pattern = '*l'
	local step = 1
	return setmetatable(
		{
			getfd = function() return sock:getfd() end,
			dirty = function() return sock:dirty() end
		}, 
		{
			__call = function()

				-- read
				local chunk, err
				chunk, err, partial = sock:receive(pattern, partial)

--				log:debug("SocketHttp.jive-http-chunked.source(", chunk and #chunk, ", ", err, ")")

				if err then
--					log:debug("SocketHttp.jive-http-chunked.source - RETURN err")
					return nil, err 
				end
				
				if step == 1 then
					-- read size
					local size = tonumber(string.gsub(chunk, ";.*", ""), 16)
					if not size then 
						return nil, "invalid chunk size" 
					end
--					log:debug("SocketHttp.jive-http-chunked.source - size: ", tostring(size))
			
					-- last chunk ?
					if size > 0 then
						step = 2
						pattern = size
						return nil, 'timeout'
					else
						return nil, 'done'
					end
				end
				
				if step == 2 then
--					log:debug("SocketHttp.jive-http-chunked.source(", chunk and #chunk, ", ", err, ", ", part and #part, ")")
					
					-- remember chunk, go read terminating CRLF
					step = 3
					pattern = '*l'
					schunk = chunk
					return nil, 'timeout'
				end
				
				if step == 3 then
--					log:debug("SocketHttp.jive-http-chunked.source 3 (", chunk and #chunk, ", ", err, ", ", part and #part, ")")
					
					-- done
					step = 1
					return schunk
				end
			end
		}
	)
end


local sinkt = {}


-- jive-concat sink
-- a sink that concats chunks and forwards to the request once done
sinkt["jive-concat"] = function(request)
	local data = {}
	return function(chunk, src_err)
--		log:debug("SocketHttp.jive-concat.sink(", chunk and #chunk, ", ", src_err, ")")
		
		if src_err and src_err != "done" then
			-- let the pump handle errors
			return nil, src_err
		end
		
		-- concatenate any chunk
		if chunk and chunk != "" then
			table.insert(data, chunk)
		end

		if not chunk or src_err == "done" then
			local blob = table.concat(data)
			-- let request decide what to do with data
			request:t_setResponseBody(blob)
--			log:debug("SocketHttp.jive-concat.sink: done ", #blob)
			return nil
		end
		
		return true
	end
end


-- jive-by-chunk sink
-- a sink that forwards each received chunk as complete data to the request
sinkt["jive-by-chunk"] = function(request)
	return function(chunk, src_err)
--		log:debug("SocketHttp.jive-by-chunk.sink(", chunk and #chunk, ", ", src_err, ")")
	
		if src_err and src_err != "done" then
			-- let the pump handle errors
			return nil, src_err
		end

		-- forward any chunk
		if chunk and chunk != "" then
			-- let request decide what to do with data
--			log:debug("SocketHttp.jive-by-chunk.sink: chunk bytes: ", #chunk)
			request:t_setResponseBody(chunk)
		end

		if not chunk or src_err == "done" then
--			log:debug("SocketHttp.jive-by-chunk.sink: done")
			request:t_setResponseBody(nil)
			return nil
		end
	
		return true
	end
end


-- _getSink
-- returns a sink for the request
local function _getSink(mode, request, customerSink)
	local f = sinkt[mode]
	if not f then 
		log:error("Unknown mode: ", mode, " - using jive-concat")
		f = sinkt["jive-concat"]
	end
	return f(request, customerSink)
end


-- t_rcvResponse
-- acrobatics to read the response body
function t_rcvResponse(self)
	
	local mode
	local len
	
	if self.t_httpReceiving:t_getResponseHeader('Transfer-Encoding') == 'chunked' then
	
		mode = 'jive-http-chunked'
		
	else
			
		if self.t_httpReceiving:t_getResponseHeader("Content-Length") then
			-- if we have a length, use it!
			len = tonumber(self.t_httpReceiving:t_getResponseHeader("Content-Length"))
			mode = 'jive-by-length'
			
		else
			-- by default we close and we start from scratch for the next request
			mode = 'jive-until-closed'
		end
	end
	
	local source = socket.source(mode, self.t_sock, len or self)
	
	local sinkMode = self.t_httpReceiving:t_getResponseSinkMode()
	local sink = _getSink(sinkMode, self.t_httpReceiving)

	local pump = function (NetworkThreadErr)
--		log:debug(self, ":t_rcvResponse.pump(", mode, ", ", tostring(nt_err) , ")")
		
		if NetworkThreadErr then
			log:error(self, ":t_rcvResponse.pump() error:", NetworkThreadErr)
			self:close(NetworkThreadErr)
			return
		end
		
		
		local continue, err = ltn12.pump.step(source, sink)
		
		-- shortcut on timeout
		if err == 'timeout' then
			return
		end
		
		if not continue then
			-- we're done
--			log:debug(self, ":t_rcvResponse.pump: done (", err, ")")
			
			-- remove read handler
			self:t_removeRead()
			
			-- handle any error
			if err and err != "done" then
				self:close(err)
				return
			end

			-- move on to our future
			self:t_rcvNext(true, 't_rcvSend')
		end
	end
	
	self:t_addRead(pump, SOCKET_TIMEOUT)
end


-- t_rcvSend
--
function t_rcvSend(self)
--	log:debug(self, ":t_rcvSend()")
	
	-- we're done receiving request, drop it
	if self.t_httpReceiving then
	
--		log:debug(self, " done with ", self.t_httpReceiving)

		self.t_httpReceiving = nil
		
		-- get the send game rolling if possible
		self:t_sendDequeueIfIdle()
	end
	
	-- move to dequeue
	self:t_rcvNext(true, 't_rcvDequeue')
end


-- free
-- frees our socket
function free(self)
--	log:debug(self, ":free()")

	-- dump queues
	-- FIXME: should it free requests?
	self.t_httpSendRequests = nil
	self.t_httpSending = nil
	self.t_httpRcvRequests = nil
	self.t_httpReceiving = nil
	
	SocketTcp.free(self)
end


-- close
-- close our socket
function close(self, err)
--	log:info(self, " closing with err: ", err, ")")

	-- assumption is sending and receiving queries are never the same
	if self.t_httpSending then
		local errorSink = self.t_httpSending:t_getResponseSink()
		errorSink(nil, err)
		self.t_httpSending = nil
	end

	if self.t_httpReceiving then
		local errorSink = self.t_httpReceiving:t_getResponseSink()
		errorSink(nil, err)
		self.t_httpReceiving = nil
	end

	self:t_sendNext(false, 't_sendDequeue')
	self:t_rcvNext(false, 't_rcvDequeue')

	-- FIXME: manage the queues
	
	SocketTcp.close(self)
end


--[[

=head2 tostring(aSocket)

if I<aSocket> is a L<jive.net.SocketHttp>, prints
 SocketHttp {name}

=cut
--]]
function __tostring(self)
	return "SocketHttp {" .. tostring(self.jsName) .. "}"
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

