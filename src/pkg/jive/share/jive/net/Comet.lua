
--[[
=head1 NAME

jive.net.Comet - An HTTP socket that implements the Cometd Bayeux protocol.

=head1 DESCRIPTION

This class implements a HTTP socket running in a L<jive.net.NetworkThread>.

=head1 SYNOPSIS

 -- create a Comet socket to communicate with http://192.168.1.1:9000/
 local comet = jive.net.Comet(jnt, "192.168.1.1", 9000, "/cometd", "slimserver")

 -- subscribe to an event
 -- will callback to func whenever there is an event
 -- playerid may be nil
 comet:subscribe('/slim/serverstatus', func, playerid, {'serverstatus', 0, 50, 'subscribe:60'})

 -- unsubscribe from an event
 comet:unsubscribe('/slim/serverstatus', func)

 -- or unsubscribe all callbacks
 comet:unsubscribe('/slim/serverstatus')

 -- send a non-subscription request
 -- playerid may be nil
 -- request is a table (array) containing the raw request to pass to SlimServer
 comet:request(func, playerid, request)

 -- start!
 comet:start()

 -- disconnect
 comet:disconnect()

=head1 FUNCTIONS

=cut
--]]
-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------


-- stuff we use
local ipairs, table, pairs, string = ipairs, table, pairs, string

local oo            = require("loop.simple")

local CometRequest  = require("jive.net.CometRequest")
local HttpPool      = require("jive.net.HttpPool")
local SocketHttp    = require("jive.net.SocketHttp")
local Timer         = require("jive.ui.Timer")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("net.comet")

-- times are in ms
local RETRY_DEFAULT = 5000  -- default delay time to retry connection
local SUB_DELAY     = 1000  -- how long to wait before sending subscription requests
local UNSUB_DELAY   = 3000  -- how long to wait before sending unsubscription requests

-- jive.net.Comet is a subclass of jive.net.SocketHttp
module(...)
oo.class(_M, SocketHttp)

--[[

=head2 jive.net.Comet(jnt, ip, port, path, name)

Creates A Comet socket named I<name> to interface with the given I<jnt> 
(a L<jive.net.NetworkThread> instance). I<name> is used for debugging and
defaults to "". I<ip> and I<port> are the IP address and port of the HTTP server.
I<path> is the absolute path to the server's cometd handler and defaults to
'/cometd'.

=cut
--]]
function __init(self, jnt, ip, port, path, name)
	log:debug("Comet:__init(", name, ", ", ip, ", ", port, ", ", path, ")")

	-- init superclass
	local obj = oo.rawnew( self, SocketHttp(jnt, ip, port, name) )
	
	obj.uri = 'http://' .. ip .. ':' .. port .. path
	
	-- Comet uses 2 pools, 1 for chunked responses and 1 for requests
	obj.cpool          = HttpPool(jnt, ip, port, 1, 1, name .. "_Chunked")
	obj.rpool          = HttpPool(jnt, ip, port, 1, 1, name .. "_Request")
	
	obj.active         = false    -- whether or not we have an active connection
	obj.clientId       = nil      -- clientId provided by server
	obj.reqid          = 1        -- used to identify non-subscription requests
	obj.advice         = {}       -- advice from server on how to handle reconnects
	obj.failures       = 0        -- count of connection failures
	
	obj.subs           = {}       -- all subscriptions
	obj.pending_unsubs = {}       -- pending unsubscribe requests
	obj.pending_reqs   = {}       -- pending requests to send with connect
	obj.notify         = {}       -- callbacks to notify
	
	-- Subscribe to networkConnected events, which happen if we change wireless networks
	jnt:subscribe(obj)
	
	return obj
end

-- forward declarations
local _addPendingRequests
local _connect
local _getEventSink
local _handleAdvice
local _handshake
local _getHandshakeSink
local _getRequestSink
local _reconnect

function start(self)
	-- Begin handshake
	_handshake(self)
end

function notify_networkConnected(self)
	if self.active then
		log:warn("Comet: Got networkConnected event, will try to reconnect to ", self.uri)
		_handleAdvice(self)
	else
		log:warn("Comet: Got networkConnected event, but not currently connected")
	end
end

_addPendingRequests = function(self, data)
	-- Add any pending subscription requests
	for i, v in ipairs( self.subs ) do
		if v.pending then
			-- really hating the lack of true arrays!
			local cmd = {}
			cmd[1] = v.playerid or ''
			cmd[2] = v.request
			
			-- Prepend clientId to subscription name
			v.subscription = '/' .. self.clientId .. v.subscription
	
			local sub = {
				channel = '/slim/subscribe',
				id      = v.reqid,
				data    = {
					request  = cmd,
					response = v.subscription,
					priority = v.priority,
				},
			}

			-- Add callback
			if not self.notify[v.subscription] then
				self.notify[v.subscription] = {}
			end
			self.notify[v.subscription][v.func] = v.func
			
			-- remove pending status and the callback from this sub
			v.pending = nil
			v.func    = nil
	
			table.insert( data, sub )
		end
	end

	-- Add pending unsubscribe requests
	for i, v in ipairs( self.pending_unsubs ) do
		local unsub = {
			channel = '/slim/unsubscribe',
			data    = {
				unsubscribe = v,
			},
		}
	
		table.insert( data, unsub )
	end

	-- Clear pending unsubs
	self.pending_unsubs = {}

	-- Add pending non-subscription requests
	for i, v in ipairs( self.pending_reqs ) do
		-- really hating the lack of true arrays!
		local cmd = {}
		cmd[1] = v.playerid or ''
		cmd[2] = v.request
	
		local req = {
			channel = '/slim/request',
			id      = v.reqid,
			data    = {
				request  = cmd,
				priority = v.priority,
			},
		}
		
		-- only ask for a response if we have a callback function
		if v.func then
			req["data"]["response"] = '/' .. self.clientId .. '/slim/request'
			
			-- Store this request's callback
			local subscription = req["data"]["response"] .. '|' .. v.reqid
			if not self.notify[subscription] then
				self.notify[subscription] = {}
			end
			self.notify[subscription][v.func] = v.func
		end
	
		table.insert( data, req )
	end

	-- Clear out pending requests
	self.pending_reqs = {}

	return
end

_connect = function(self)
	log:debug('Comet:_connect()')
	
	-- Connect and subscribe to all events for this clientId
	local data = { {
		channel        = '/meta/connect',
		clientId       = self.clientId,
		connectionType = 'streaming',
	},
	{
		channel      = '/meta/subscribe',
		clientId     = self.clientId,
		subscription = '/' .. self.clientId .. '/**',
	} }
	
	-- Add any other pending requests to the outgoing data
	_addPendingRequests( self, data )
	
	-- This will be our last request on this connection, it is now only
	-- for listening for responses
	
	local req = function()
		return CometRequest(
			_getEventSink(self),
			self.uri,
			data
		)
	end
	
	self.cpool:queuePriority(req)
end

_getEventSink = function(self)
	return function(chunk, err)
		-- on error, print something...
		if err then
			log:warn("Comet:_getEventSink: error: ", err)
			
			-- try to reconnect according to advice
			_handleAdvice(self)
		end
		
		-- if we have data
		if chunk then
		
			-- Process each response event
			for i, event in ipairs(chunk) do
			
				-- update advice if any
				if event.advice then
					self.advice = event.advice
					log:debug("Comet:_getEventSink, advice updated from server")
				end
				
				if event.channel == '/meta/connect' then
				 	if event.successful then
						log:debug("Comet:_getEventSink, connect message acknowledged")
						self.active   = true
						self.failures = 0
					else
						log:warn("Comet:_getEventSink, connect failed: ", event.error)
						_handleAdvice(self)
						break
					end
				elseif event.channel == '/meta/reconnect' then
					if event.successful then
						log:debug("Comet:_getEventSink, reconnect OK")
						self.active   = true
						self.failures = 0
					else
						log:warn("Comet:_getEventSink, reconnect failed: ", event.error)
						_handleAdvice(self)
						break
					end
				elseif event.channel == '/meta/subscribe' then
					if event.successful then
						log:debug("Comet:_getEventSink, /meta/subscribe OK for ", event.subscription)
					else
						log:warn("Comet:_getEventSink, /meta/subscribe failed: ", event.error)
					end
				elseif event.channel == '/meta/unsubscribe' then
					if event.successful then
						log:debug("Comet:_getEventSink, /meta/unsubscribe OK for ", event.subscription)
					else
						log:warn("Comet:_getEventSink, /meta/unsubscribe error: ", event.error)
					end
				elseif event.channel == '/slim/subscribe' then
					if event.successful then
						log:debug("Comet:_getEventSink, /slim/subscribe OK for reqid ", event.id)
					else
						log:warn("Comet:_getEventSink, /slim/subscribe error for reqid ", event.id, ": ", event.error)
					end
				elseif event.channel == '/slim/unsubscribe' then
					if event.successful then
						log:debug("Comet:_getEventSink, /slim/unsubscribe OK for reqid ", event.id)
					else
						log:warn("Comet:_getEventSink, /slim/unsubscribe error for reqid ", event.id, ": ", event.error)
					end
				elseif event.channel then
					local subscription    = event.channel
					local onetime_request = false
					
					if string.find(subscription, '/slim/request') then
						-- an async notification from a normal request
						subscription = subscription .. '|' .. event.id
						onetime_request = true
					end
					
					if self.notify[subscription] then
						log:debug("Comet:_getEventSink, notifiying callbacks for ", subscription)
					
						for _, func in pairs( self.notify[subscription] ) do
							func(event)
						end
						
						if onetime_request then
							-- this was a one-time request, so remove the callback
							self.notify[subscription] = nil
						end
					else
						-- this is normal, since unsub's are delayed by a few seconds, we may receive events
						-- after we unsubscribed but before the server is notified about it
						log:debug("Comet:_getEventSink, got data for an event we aren't subscribed to, ignoring -> ", subscription)
					end
				else
					log:warn("Comet:_getEventSink, unknown error: ", event.error)
					if event.advice then
						_handleAdvice(self)
						break
					end
				end
			end
		end
	end
end

_handshake = function(self)
	log:debug('Comet:_handshake(), calling: ', self.uri)
	
	local data = { {
		channel                  = '/meta/handshake',
		version                  = '1.0',
		supportedConnectionTypes = { 'streaming' },
	} }
	
	-- XXX: according to the spec this should be sent as application/x-www-form-urlencoded
	-- with message=<url-encoded json> but it works as straight JSON
	
	local req = function()
		return CometRequest(
			_getHandshakeSink(self),
			self.uri,
			data
		)
	end
	
	self.cpool:queuePriority(req)
end

_getHandshakeSink = function(self)
	return function(chunk, err)
		-- on error, print something...
		if err then
			log:warn("Comet:_handshake with ", self.jsName, " error: ", err)
		end
		-- if we have data
		if chunk then
			local data = chunk[1]
			if data.successful then
				self.active    = true
				self.failures  = 0
				self.clientId  = data.clientId
				self.advice    = data.advice
				
				log:debug("Comet:_handshake OK with ", self.jsName, ", clientId: ", self.clientId)
				
				-- Reset error count
				self.failures = 0
				
				-- Continue with connect phase
				_connect(self)
			else
				log:warn("Comet:_handshake error: ", data.error)
				if data.advice then
					self.advice = data.advice
					_handleAdvice(self)
				end
			end
		end
	end
end

function subscribe(self, subscription, func, playerid, request, priority)
	local id = self.reqid

	if log:isDebug() then
		log:debug("Comet:subscribe(", subscription, ", reqid:", id, ", ", func, ", ", playerid, ", ", table.concat(request, ","), ", priority:", priority, ")")
	end
	
	-- Remember subs to send during connect now, or if we get
	-- disconnected
	table.insert( self.subs, {
		subscription = subscription,
		playerid     = playerid,
		request      = request,
		reqid        = id,
		func         = func,
		priority     = priority,
		pending      = true, -- pending means we haven't send this sub request yet
	} )
	
	self.reqid = self.reqid + 1
	
	if self.active and not self.sub_timer then
		-- batch subscription requests on a short timer
		self.sub_timer = Timer(
			SUB_DELAY,
			function()
				self.sub_timer = nil
				
				if self.active then
					-- add all pending unsub requests, and any others we need to send
					local data = {}
					_addPendingRequests(self, data)
					
					-- Only continue if we have some data to send
					if data[1] then
						if log:isDebug() then
							log:debug("Sending pending subscribe request(s):")
							debug.dump(data, 5)
						end

						local req = function()
							return CometRequest(
								_getEventSink(self),
								self.uri,
								data
							)
						end
				
						self.rpool:queuePriority(req)
					end
				end
			end,
			true -- run timer only once
		)
		
		log:debug("Comet:subscribe: delaying subscribe requests for ", SUB_DELAY / 1000, " seconds")
		
		self.sub_timer:start()
	end
end

function unsubscribe(self, subscription, func)
	log:debug("Comet:unsubscribe(", subscription, ", ", func, ")")
	
	-- Prepend clientId to subscription name
	subscription = '/' .. self.clientId .. subscription
	
	-- Remove from notify list
	if func then
		-- Remove only the given callback
		self.notify[subscription][func] = nil
	else
		-- Remove all callbacks
		self.notify[subscription] = nil
	end
	
	-- If we unsubscribed the last one for this subscription, clear it out
	if not self.notify[subscription] then
		log:debug("No more callbacks for ", subscription, " unsubscribing at server")
		
		-- Remove from subs list
		for i, v in ipairs( self.subs ) do
			if v.subscription == subscription then
				table.remove( self.subs, i )
				break
			end
		end
		
		-- Unsub requests are always batched and sent after a short delay
		table.insert( self.pending_unsubs, subscription )
		
		if self.active and not self.unsub_timer then
			-- Send unsub requests in 3 seconds
			self.unsub_timer = Timer(
				UNSUB_DELAY,
				function()
					self.unsub_timer = nil
					
					if self.active and self.pending_unsubs then
						-- add all pending unsub requests, and any others we need to send
						local data = {}
						_addPendingRequests(self, data)
						
						-- Only continue if we have stuff to send
						if data[1] then
							if log:isDebug() then
								log:debug("Sending pending unsubscribe request(s):")
								debug.dump(data, 5)
							end

							local req = function()
								return CometRequest(
									_getEventSink(self),
									self.uri,
									data
								)
							end

							-- unsubscribe doesn't need to be high priority						
							self.rpool:queue(req)
						end
					end
				end,
				true -- run timer only once
			)
			
			log:debug("Comet:unsubscribe: delaying unsubscribe requests for ", UNSUB_DELAY / 1000, " seconds")
			
			self.unsub_timer:start()
		end
	end
end

function request(self, func, playerid, request, priority)
	local id = self.reqid
	
	if log:isDebug() then
		log:debug("Comet:request(", func, ", reqid:", id, ", ", playerid, ", ", table.concat(request, ","), ", priority:", priority, ")")
	end
	
	if not self.active then
		-- Add subscription to pending requests, to be sent during connect/reconnect
		table.insert( self.pending_reqs, {
			reqid    = id,
			func     = func,
			playerid = playerid,
			request  = request,
			priority = priority,
		} )
	else	
		local cmd = {}
		cmd[1] = playerid or ''
		cmd[2] = request
		
		local data = { {
			channel = '/slim/request',
			id      = id,
			data    = {
				request  = cmd,
				priority = priority,
			},
		} }
		
		-- only ask for a response if we have a callback function
		if func then
			data[1]["data"]["response"] = '/' .. self.clientId .. '/slim/request'
		end
		
		local sink = nil
		if func then
			sink = _getRequestSink(self, func, id)
		end
	
		local req = function()
			return CometRequest(
				sink,
				self.uri,
				data
			)
		end
	
		self.rpool:queuePriority(req)
	
		-- If we expect a response, we will get the response on the persistent 
		-- connection.  Store our callback for later
		if func then
			local subscription = data[1]["data"]["response"] .. '|' .. id
			if not self.notify[subscription] then
				self.notify[subscription] = {}
			end
			self.notify[subscription][func] = func
		else
			log:debug('  No sink defined for this request, no response will be received')
		end
	end
	
	-- Bump reqid for the next request
	self.reqid = self.reqid + 1
	
	-- Return the request id to the caller
	return id
end

_getRequestSink = function(self, func, reqid)
	return function(chunk, err)
		-- on error, print something...
		if err then
			log:warn("Comet:request error: ", err)
			
			-- XXX: need to handle this error by retrying the failed request?
		end
		-- if we have data
		if chunk then
			for i, event in ipairs(chunk) do
				if event.advice then
					self.advice = event.advice
				end
				
				if event.error then
					log:warn("Comet:request error: ", event.error)
					func(nil, event.error)
				elseif event.channel == '/slim/request' and event.successful then
					log:debug("Comet:request id ", reqid, " sent OK")
				elseif event.id == reqid then
					log:debug("Comet:request got result for request id ", reqid)
					
					-- Remove subscription, we know this was not an async request
					local subscription = '/' .. self.clientId .. '/slim/request|' .. reqid
					self.notify[subscription] = nil
					
					func(event)
				end
			end
		end
	end
end

-- Decide what to do if we get disconnected or get an error while handshaking/connecting
-- XXX: Need a way to propagate errors/retry notice up to the UI
_handleAdvice = function(self)
	-- make sure our connection is closed
	if self.active then
		self.active = false
		self:perform(function() self:t_close() end)
	end
	
	self.failures = self.failures + 1
	
	local advice = self.advice
	
	-- Keep retrying after multiple failures but backoff gracefully
	local retry_interval = ( advice.interval or RETRY_DEFAULT ) * self.failures
	
	-- XXX: Work around a bug in Timer where interval of 0 causes a loop
	if retry_interval < 1 then
		retry_interval = 1
	end
	
	if advice.reconnect == 'retry' then
		log:warn(
			"Comet: advice is ", advice.reconnect, ", reconnecting in ",
			retry_interval / 1000, " seconds"
		)
	
		self.reconnect_timer = Timer(
			retry_interval,
			function()
				_reconnect(self)
			end,
			true -- run timer only once
		)
		self.reconnect_timer:start()
	elseif advice.reconnect == 'handshake' or advice.reconnect == 'recover' then
		log:warn(
			"Comet: advice is ", advice.reconnect, ", re-handshaking in ",
			retry_interval / 1000, " seconds"
		)
	
		self.clientId = nil
		self.reconnect_timer = Timer(
			retry_interval,
			function()
				-- This will re-subscribe to any old subscriptions
				-- during _connect()
				_handshake(self)
			end,
			true -- run timer only once
		)
		self.reconnect_timer:start()
	else
		self.clientId = nil
		log:warn("Comet:_connect, server told us not to reconnect")
	end
end

-- Reconnect to the server, try to maintain our previous clientId
_reconnect = function(self)
	log:debug('Comet:_reconnect()')
	
	if not self.clientId then
		log:debug("Comet:_reconnect error: cannot reconnect without clientId, handshaking instead")
		_handshake(self)
		do return end
	end
	
	local data = { {
		channel        = '/meta/reconnect',
		clientId       = self.clientId,
		connectionType = 'streaming',
	} }
	
	local req = function()
		return CometRequest(
			_getEventSink(self),
			self.uri,
			data
		)
	end
	
	self.cpool:queuePriority(req)	
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]