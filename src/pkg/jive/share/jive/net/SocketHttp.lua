
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
local assert, tostring, tonumber, type = assert, tostring, tonumber, type
local setmetatable, pairs = setmetatable, pairs

local math        = require("math")
local table       = require("table")
local string      = require("string")
local debug       = require("debug")

local oo          = require("loop.simple")
local socket      = require("socket")
local socketHttp  = require("socket.http")
local ltn12       = require("ltn12")

local SocketTcp   = require("jive.net.SocketTcp")
local RequestHttp = require("jive.net.RequestHttp")

local log         = require("jive.utils.log").logger("net.http")


-- jive.net.SocketHttp is a subclass of jive.net.SocketTcp
module(...)
oo.class(_M, SocketTcp)


--[[

=head2 jive.net.SocketHttp(jnt, ip, port, name)

Creates an HTTP socket named I<name> to interface with the given I<jnt> 
(a L<jive.net.NetworkThread> instance). I<name> is used for debugging and
defaults to "". I<ip> and I<port> are the IP address and port of the HTTP server.

=cut
--]]
function __init(self, jnt, ip, port, name)
	log:debug("SocketHttp:__init(", tostring(name), ", ", tostring(ip), ", ", tostring(port), ")")

	-- init superclass
	local obj = oo.rawnew(self, SocketTcp(jnt, ip, port, name))

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
	assert(oo.instanceof(request, RequestHttp), tostring(self) .. ":fetch() parameter must be RequestHttp - " .. type(request) .. " - ".. debug.traceback())
	self:perform(function() self:t_fetch(request) end)
end


-- t_fetch
-- fetches a request (network thread side)
function t_fetch(self, request)
	
	-- push the request
	table.insert(self.t_httpSendRequests, request)

	log:info(tostring(self), " queuing ", tostring(request), " - ", #self.t_httpSendRequests, " requests in queue")
		
	-- start the state machine if it is idle
	self:t_sendDequeueIfIdle()
end


-- t_sendNext
-- manages the http state machine for sending stuff to the server
function t_sendNext(self, go, newState)
	log:debug(tostring(self), ":t_sendNext(", tostring(go), ", ", tostring(newState), ")")
	
	if newState then
		assert(self[newState] and type(self[newState]) == 'function')
		self.t_httpSendState = newState
	end
	
	if go then
		-- call the function
		-- self:XXX(bla) is really the same as self["XXX"](self, bla)
		self[self.t_httpSendState](self)
	end
end


-- t_sendDequeue
-- removes a request from the queue
function t_sendDequeue(self)
	log:debug(tostring(self), ":t_sendDequeue()")
	
	if #self.t_httpSendRequests > 0 then
	
		self.t_httpSending = table.remove(self.t_httpSendRequests, 1)
		log:info(tostring(self), " processing ", tostring(self.t_httpSending))
		self:t_sendNext(true, 't_sendConnect')
		return
	end
	
	-- back to idle
	log:info(tostring(self), ": no request in queue")
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
	log:debug(tostring(self), ":t_sendConnect()")
	
	if not self:connected() then
	
		local err = socket.skip(1, self:t_connect())
	
		if err then
	
			log:error(tostring(self), ":t_sendConnect: ", err)
			self:t_close(err)
			return
		end
	end
		
	self:t_sendNext(true, 't_sendHeaders')
end


-- t_getSendHeaders
-- calculates the headers to send from a socket perspective
function t_getSendHeaders(self)
	log:debug(tostring(self), ":t_getSendHeaders()")

	-- default set
	local headers = {
		["Host"] = (self:t_getIpPort()),
		["Connection"] = 'keep-open',
		["User-Agent"] = 'Jive',
	}
	
	if self.t_httpSending:t_hasBody() then
	
		if self.t_httpProtocol == '1.1' then
			headers["Transfer-Encoding"] = 'chunked'
		else
			-- FIXME: we should get the body length here
			error(tostring(self) .. ":POST with HTTP 1.0 not supported")
		end
	end
	
	return headers
end


-- t_sendHeaders
-- send the headers, aggregates request and socket headers
function t_sendHeaders(self)
	log:debug(tostring(self), ":t_sendHeaders()")
	
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
		table.insert(t, "")

		return table.concat(t, "\r\n")
	end

	local sink = socket.sink('keep-open', self.t_sock)
	
	local pump = function ()
		log:debug(tostring(self), ":t_sendHeaders.pump()")
		
		local ret, err = ltn12.pump.step(source, sink)
		
		if err then
			log:error(tostring(self), ":t_sendHeaders.pump: ", err)
			self:t_close(err)
			return
		end
		
		self:t_removeWrite()
		
		if self.t_httpSending:t_hasBody() then
			self:t_sendNext(true, 't_sendBody')
		else
			self:t_sendNext(true, 't_sendReceive')
		end
	end


	self:t_addWrite(pump)
end


-- t_sendBody
-- sends the body
function t_sendBody(self)
	log:debug(tostring(self), ":t_sendBody()")
	
	local source = self.t_httpSending:t_getBodySource()
	
	local sink = socket.sink('http-chunked', self.t_sock)

	local pump = function ()
		log:debug(tostring(self), ":t_sendBody.pump()")
		
		local ret, err = ltn12.pump.step(source, sink)
		
		if err then
			log:error(tostring(self), ":t_sendBody.pump: ", err)
			self:t_close(err)
			return
			
		-- we pump until the source returns nil -> send last chunk
		elseif not ret then

			self:t_removeWrite()
			self:t_sendNext(true, 't_sendReceive')
		end
	end
	
	self:t_addWrite(pump)
end


-- t_sendReceive
--
function t_sendReceive(self)
	log:debug(tostring(self), ":t_sendReceive()")
	
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
	log:debug(tostring(self), ":t_rcvNext(", tostring(go), ", ", tostring(newState), ")")

	if newState then
		assert(self[newState] and type(self[newState]) == 'function')
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
	log:debug(tostring(self), ":t_rcvDequeue()")
	
	if #self.t_httpRcvRequests > 0 then
		self.t_httpReceiving = table.remove(self.t_httpRcvRequests, 1)
		self:t_rcvNext(true, 't_rcvHeaders')
	end
end


-- t_rcvHeaders
--
function t_rcvHeaders(self)
	log:debug(tostring(self), ":t_rcvHeaders()")
	
	local source = function()
	
		local line, err = self.t_sock:receive()
		
		if err then
			log:debug(tostring(self), ":t_rcvHeaders.source:", err)
			return nil, err
		end
		
		if line == "" then
			-- we're done
			return nil
		end
		
		return line
	end

	local headers = {}
	local statusCode = false
	local statusLine = false
	local sink = function(chunk, err)
		log:debug(tostring(self), ":t_rcvHeaders.sink: ", tostring(chunk))
		
		if chunk then
			
			-- first line is status line
			if not statusCode then
			
				local data = socket.skip(2, string.find(chunk, "HTTP/%d*%.%d* (%d%d%d)"))
				
				if data then
					statusCode = tonumber(data)
					statusLine = chunk
				else
					return false, "cannot parse: " .. chunk
				end
				
			else
				
				local name, value = socket.skip(2, string.find(chunk, "^(.-):%s*(.*)"))
				
				if not (name and value) then 
					return false, "malformed reponse headers"
				else
					headers[name] = value
					log:debug(tostring(self), ":t_rcvHeaders.sink header: ", name, ":", value)
				end
			end
		end
		return 1
	end

	local pump = function ()
		log:debug(tostring(self), ":t_rcvHeaders.pump()")
		
		local ret, err = ltn12.pump.step(source, sink)
	
		if err then
		
			log:error(tostring(self), ":t_rcvHeaders.pump:", err)
			self:t_removeRead()
			self:t_close(err)
			return
			
		elseif not ret then
		
			-- we're done
			self:t_removeRead()
			
			self.t_httpReceiving:t_setResponseHeaders(statusCode, statusLine, headers, self:getSafeSinkGenerator())
		
			-- release send queue
			self:t_sendNext(false, 't_sendDequeue')
		
			-- we've received response headers, check with request if OK to send next query now
			if self.t_httpReceiving:t_canDequeue() then
				self:t_sendDequeueIfIdle()
			end
			
			-- move on to our future...
			self:t_rcvNext(true, 't_rcvResponse')
		end
	end
	
	self:t_addRead(pump)
end


-- jive-until-close socket source
-- our "until-close" source, added to the socket namespace so we can use it like any other
-- the code is identical to the one in socket, except we return the closed error when 
-- it happens. The source/sink concept is based on the fact sources are called until 
-- they signal no more data (by returning nil). We can't use that however since the 
-- pump won't be called in select!
socket.sourcet["jive-until-closed"] = function(sock, self)
    local done
    return setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function()
            if done then return nil end
            local chunk, err, partial = sock:receive(socket.BLOCKSIZE)
            if not err then return chunk
            elseif err == "closed" then
            	--close the socket using self
                SocketTcp.t_close(self)
                done = 1
                return partial, 'done'
            else return nil, err end
        end
    })
end


-- jive-by-length socket source
-- same principle as until-close, we need to return somehow the fact we're done
socket.sourcet["jive-by-length"] = function(sock, length)
    return setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function()
            if length <= 0 then return nil, 'done' end
            local size = math.min(socket.BLOCKSIZE, length)
            local chunk, err = sock:receive(size)
            if err then return nil, err end
            length = length - string.len(chunk)
            if length <= 0 then
            	return chunk, 'done'
            else
            	return chunk
            end
        end
    })
end


-- jive-http-chunked source
-- same as the one in http, except does not attempt to read headers after
-- last chunk and returns 'done' pseudo error
socket.sourcet["jive-http-chunked"] = function(sock)
    return setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function()
            -- get chunk size, skip extention
            local line, err = sock:receive()
            if err then return nil, err end
            local size = tonumber(string.gsub(line, ";.*", ""), 16)
            if not size then return nil, "invalid chunk size" end
            -- was it the last chunk?
            if size > 0 then
                -- if not, get chunk and skip terminating CRLF
                local chunk, err, part = sock:receive(size)
                if chunk then sock:receive() end
                return chunk, err
            else
                return nil, 'done'
            end
        end
    })
end


local sinkt = {}


-- jive-concat sink
-- a sink that concats chunks and forwards to the request once done
sinkt["jive-concat"] = function(request, safeSinkGen)
	local data = {}
	return function(chunk, src_err)
		log:debug("SocketHttp.jive-concat.sink(", tostring(chunk and #chunk), ", ", tostring(src_err), ")")
		
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
			request:t_setResponseBody(blob, safeSinkGen)
			log:debug("SocketHttp.jive-concat.sink: done ", tostring(#blob))
			return nil
		end
		
		return true
	end
end


-- jive-by-chunk sink
-- a sink that forwards each received chunk as complete data to the request
sinkt["jive-by-chunk"] = function(request, safeSinkGen)
	return function(chunk, src_err)
		log:debug("SocketHttp.jive-by-chunk.sink(", tostring(chunk and #chunk), ", ", tostring(src_err), ")")
	
		if src_err and src_err != "done" then
			-- let the pump handle errors
			return nil, src_err
		end
	
		-- forward any chunk
		if chunk and chunk != "" then
			-- let request decide what to do with data
			request:t_setResponseBody(chunk, safeSinkGen)
			log:debug("SocketHttp.jive-by-chunk.sink: chunk bytes: ", tostring(#chunk))
		end

		if not chunk or src_err == "done" then
			log:debug("SocketHttp.jive-by-chunk.sink: done")
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
			
		if self.t_httpReceiving:t_getResponseHeader("Content-Length")  and 
			self.t_httpReceiving:t_getResponseHeader("Connection") != 'close' then
		
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
	local sink = _getSink(sinkMode, self.t_httpReceiving, self:getSafeSinkGenerator())

	local pump = function ()
		log:debug(tostring(self), ":t_rcvResponse.pump(", mode, ")")
		
		local continue, err = ltn12.pump.step(source, sink)
		
		if not continue then
			-- we're done
			log:debug(tostring(self), ":t_rcvResponse.pump: done (", tostring(err), ")")
			
			-- remove read handler
			self:t_removeRead()
			
			-- handle any error
			if err and err != "done" then
				self:t_close(err)
				return
			end
			
			-- move on to our future
			self:t_rcvNext(true, 't_rcvSend')
			
		-- else let the request decide if we can send another request, if any	
		else
			if self.t_httpReceiving:t_canDequeue() then
				self:t_sendDequeueIfIdle()
			end
		end
	end
	
	self:t_addRead(pump)
end


-- t_rcvSend
--
function t_rcvSend(self)
	log:debug(tostring(self), ":t_rcvSend()")
	
	-- we're done receiving request, drop it
	if self.t_httpReceiving then
	
		log:debug(tostring(self), " done with ", tostring(self.t_httpReceiving))

		self.t_httpReceiving = nil
		
		-- get the send game rolling if possible
		self:t_sendDequeueIfIdle()
	end
	
	-- move to dequeue
	self:t_rcvNext(true, 't_rcvDequeue')
end


-- t_free
-- frees our socket
function t_free(self)
	log:debug(tostring(self), ":t_free()")

	-- dump queues
	-- FIXME: should it free requests?
	self.t_httpSendRequests = nil
	self.t_httpSending = nil
	self.t_httpRcvRequests = nil
	self.t_httpReceiving = nil
	
	SocketTcp.t_free(self)
end


-- t_close
-- close our socket
function t_close(self, err)
	log:info(tostring(self), " closing with err: ", tostring(err), ")")

	-- assumption is sending and receiving queries are never the same
	if self.t_httpSending then
		local errorSink = self.t_httpSending:t_getResponseSink()
		local safeSink = self:safeSink(errorSink)
		safeSink(nil, err)
		self.t_httpSending = nil
	end

	if self.t_httpReceiving then
		local errorSink = self.t_httpReceiving:t_getResponseSink()
		local safeSink = self:safeSink(errorSink)
		safeSink(nil, err)
		self.t_httpReceiving = nil
	end

	self:t_sendNext(false, 't_sendDequeue')
	self:t_rcvNext(false, 't_rcvDequeue')

	-- FIXME: manage the queues
	
	SocketTcp.t_close(self)
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

