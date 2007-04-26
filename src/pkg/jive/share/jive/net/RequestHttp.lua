
--[[
=head1 NAME

jive.net.RequestHttp - An HTTP request.

=head1 DESCRIPTION

jive.net.RequestHttp implements an HTTP request to be processed
by a L<jive.net.SocketHttp>.

=head1 SYNOPSIS

 -- create a sink to receive XML
 local function sink(chunk, err)
   if err then
     print("error!: " .. err)
   elseif chunk then
     print("received: " .. chunk)
   end
 end
 
 -- create a HTTP socket (see L<jive.net.SocketHttp>)
 local http = jive.net.SocketHttp(jnt, "192.168.1.1", 9000, "slimserver")

 -- create a request to GET http://192.168.1.1:9000/xml/status.xml
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
local assert, tostring, type, pairs = assert, tostring, type, pairs

local oo  = require("loop.base")

local log = require("jive.utils.log").logger("net.http")


-- our class
module(..., oo.class)


--[[

=head2 jive.net.RequestHttp(sink, method, uri, options)

Creates a RequestHttp. Parameters:

I<sink> : a main thread lnt12 sink. Will be called with nil when data is complete,
in order to be compatible with filters and other ltn12 stuff. However for performance
reasons, data is concatenated on the network thread side.

I<method> : the HTTP method to use, 'POST' or 'GET'. If POST, a POST body source must be provided in I<options>.

I<uri> : the URI to GET/POST to

I<options> : table with optional parameters: I<t_bodySource> is a lnt12 source required for POST operation;
I<headers> is a table with aditional headers to use for the request.

=cut
--]]
function __init(self, sink, method, uri, options)
	log:debug("RequestHttp:__init()")

	if sink then
		assert(type(sink) == 'function', "HTTP sink must be a function")
	end
	assert(method, "Cannot create a RequestHttp without method")
	assert(type(method) == 'string', "HTTP method shall be a string")
	assert(method == 'GET' or method == 'POST', "HTTP methods other than POST or GET not supported")
	assert(uri, "Cannot create a RequestHttp without uri")
	assert(type(uri) == 'string', "HTTP uri shall be a string")
	
	-- default set of request side headers
	local defHeaders = {
		["User-Agent"] = "Jive",
	}

	local t_bodySource, headersSink

	-- handle the options table
	if options then
		-- validate t_bodySource
		t_bodySource = options.t_bodySource
		if t_bodySource then
			assert(type(t_bodySource) == 'function', "HTTP body source shall be a function")
			if method == 'GET' then
				log:warn("Body source provided in HTTP request won't be used by GET request")
			end
		else
			assert(method == 'GET', "HTTP POST requires body source")
		end
		
		-- override/add provided headers, if any
		if options.headers then
			for k, v in pairs(options.headers) do
				defHeaders[k] = v
			end
		end
		
		headersSink = options.headersSink
		if headersSink then
			assert(type(headersSink) == 'function', "HTTP header sink must be a function")
		end
	end
	
	return oo.rawnew(self, {
		-- request params
		t_httpRequest = {
			["method"] = method,
			["uri"] = uri,
			["src"] = t_bodySource,
			["headers"] = defHeaders,
		},
		-- response
		t_httpResponse = {
			["statusCode"] = false,
			["statusLine"] = false,
			["headers"] = false,
			["headersSink"] = headersSink,
			["body"] = "",
			["done"] = false,
			["sink"] = sink,
		},
	})
end


-- t_hasBody
-- returns if the request has a body to send, i.e. is POST
function t_hasBody(self)
	return self.t_httpRequest.method == 'POST'
end


-- t_getRequestString
-- returns the HTTP request string, i.e. "GET uri"
function t_getRequestString(self)
	return self.t_httpRequest.method .. " " .. self.t_httpRequest.uri
end


-- t_getRequestHeaders
-- returns the request specific headers
function t_getRequestHeaders(self)
	return self.t_httpRequest.headers
end


-- t_getRequestHeader
-- returns a specific request header
function t_getRequestHeader(self, key)
	return self.t_httpRequest.headers[key]
end


-- t_getBodySource
-- returns the body source
function t_getBodySource(self)
	log:debug("RequestHttp:t_getBodySource()")

	return self.t_httpRequest.src
end


-- t_setResponseHeaders
-- receives the response headers from the HTTP layer
function t_setResponseHeaders(self, statusCode, statusLine, headers, safeSinkGen)
	log:debug(
		"RequestHttp:t_setResponseHeaders(", 
		tostring(self), 
		": ", 
		tostring(statusCode), 
		", ", 
		tostring(statusLine), 
		")"
	)

	self.t_httpResponse.statusCode = statusCode
	self.t_httpResponse.statusLine = statusLine
	self.t_httpResponse.headers = headers
	
	-- transform our sink into a safe one using handy function
	local safeSink = self:sinkToSafeSink(self.t_httpResponse.headersSink, safeSinkGen)
	
	-- abort if we have no sink
	if safeSink then
		safeSink(headers)
	end
end


-- t_getResponseHeader
-- returns a response header
function t_getResponseHeader(self, key)
	return self.t_httpResponse.headers[key]
end


-- t_getResponseStatus
-- returns the status code and the status line
function t_getResponseStatus(self)
	return self.t_httpResponse.statusCode, self.t_httpResponse.statusLine
end


-- t_getResponseSinkMode
-- returns the sink mode
function t_getResponseSinkMode(self)
	log:debug("RequestHttp:t_getResponseSinkMode()")
	
	return 'jive-concat'
end


-- t_getResponseSink
-- returns the sink mode
function t_getResponseSink(self)
	log:debug("RequestHttp:t_getResponseSink()")
	
	return self.t_httpResponse.sink
end


-- t_setResponseBody
-- HTTP socket data to process, along with a safe sink to send it to customer
function t_setResponseBody(self, data, safeSinkGen)
	log:info("RequestHttp:t_setResponseBody(", tostring(self), ")")

	-- transform our sink into a safe one using handy function
	local safeSink = self:sinkToSafeSink(self:t_getResponseSink(), safeSinkGen, true)
	
	-- abort if we have no sink
	if safeSink then
	
		-- the HTTP layer has read any data coming with a 404, but we do not care
		-- only send data back in case of 200!
		local code, err = self:t_getResponseStatus()
		if code == 200 then
			safeSink(data)
			safeSink(nil)
		else
			safeSink(nil, err)
		end
	end
end


-- t_canDequeue
-- called by the HTTP layer to determine if the next request in the queue
-- can be sent
function t_canDequeue(self)
	return false
end


-- sinkToSafeSink
--
function sinkToSafeSink(self, sink, gen, callNil)
	if sink and gen then
		local safeSink = gen(sink, callNil)
		if type(safeSink) == 'function' then
			return safeSink
		else
			log:error("safeSink is not a function!")
		end
	end
	return nil
end


--[[

=head2 tostring(aRequest)

If I<aRequest> is a L<jive.net.RequestHttp>, prints
 RequestHttp {name}

=cut
--]]
function __tostring(self)
	return "RequestHttp {" .. self:t_getRequestString() .. "}"
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

