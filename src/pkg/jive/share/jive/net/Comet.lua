
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

 -- add a callback function for an already-subscribed event
 comet:addCallback('/slim/serverstatus', func)

 -- remove a callback function
 comet:removeCallback('/slim/serverstatus', func)

 -- start!
 comet:start()

 -- disconnect
 comet:disconnect()

 -- batch a set of calls together into one request
  comet:startBatch()
  comet:subscribe(...)
  comet:request(...)
  comet:endBatch()

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

local Icon          = require("jive.ui.Icon")
local Label         = require("jive.ui.Label")
local Popup         = require("jive.ui.Popup")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("net.comet")

local JIVE_VERSION  = jive.JIVE_VERSION

-- times are in ms
local RETRY_DEFAULT = 5000  -- default delay time to retry connection

-- jive.net.Comet is a base class
module(..., oo.class)

--[[

=head2 jive.net.Comet(jnt, ip, port, path, name)

Creates A Comet socket named I<name> to interface with the given I<jnt> 
(a L<jive.net.NetworkThread> instance). I<name> is used for debugging and
defaults to "". I<ip> and I<port> are the IP address and port of the HTTP server.
I<path> is the absolute path to the servers cometd handler and defaults to
'/cometd'.

Notifications:

 cometConnected(self)
 cometDisconnected(self, numPendingRequests)

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
	
	obj.jnt            = jnt
	obj.name           = name
	obj.active         = false    -- whether or not we have an active connection
	obj.clientId       = nil      -- clientId provided by server
	obj.reqid          = 1        -- used to identify non-subscription requests
	obj.advice         = {}       -- advice from server on how to handle reconnects
	obj.failures       = 0        -- count of connection failures
	obj.batch          = false    -- are we batching queries?
	
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
local _active

function start(self)
	if not self.active then
		-- Begin handshake
		_handshake(self)
	end
end

function disconnect(self)
	if self.active then
	
		log:debug('Comet:disconnect()')

		local data = { {
			channel  = '/meta/disconnect',
			clientId = self.clientId,
		} }

		local req = function()
			_active(self, false)
		
			-- Mark all subs as pending so they can be resubscribed later
			for i, v in ipairs( self.subs ) do
				log:debug("Will re-subscribe to ", v.subscription, " on next connect")
				v.pending = true
			end
		
			return CometRequest(
				_getEventSink(self),
				self.uri,
				data
			)
		end

		self.rpool:queuePriority(req)
	end
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
			local subscription = '/' .. self.clientId .. v.subscription
	
			local sub = {
				channel = '/slim/subscribe',
				id      = v.reqid,
				data    = {
					request  = cmd,
					response = subscription,
					priority = v.priority,
				},
			}

			-- Add callback
			if not self.notify[v.subscription] then
				self.notify[v.subscription] = {}
			end
			self.notify[v.subscription][v.func] = v.func
			
			-- remove pending status from this sub
			v.pending = nil
	
			table.insert( data, sub )
		end
	end

	-- Add pending unsubscribe requests
	for i, v in ipairs( self.pending_unsubs ) do
		local subscription = '/' .. self.clientId .. v
		
		local unsub = {
			channel = '/slim/unsubscribe',
			data    = {
				unsubscribe = subscription,
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
			data    = {
				request  = cmd,
				response = '/' .. self.clientId .. '/slim/request',
				priority = v.priority,
			},
		}

		-- only ask for a response if we have a callback function
		if v.func then
			req["id"] = v.reqid
			
			-- Store this request's callback
			local subscription = '/slim/request|' .. v.reqid
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
						_active(self, true)
					else
						log:warn("Comet:_getEventSink, connect failed: ", event.error)
						_handleAdvice(self)
						break
					end
				elseif event.channel == '/meta/disconnect' then
					if event.successful then
						log:debug("Comet:_getEventSink, disconnect OK")
					else
						log:warn("Comet:_getEventSink, disconnect failed: ", event.error)
					end
				elseif event.channel == '/meta/reconnect' then
					if event.successful then
						log:debug("Comet:_getEventSink, reconnect OK")
						_active(self, true)
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
				elseif event.channel == '/slim/request' and event.successful then
					log:debug("Comet:request id ", event.id, " sent OK")
				elseif event.channel then
					local subscription    = event.channel
					local onetime_request = false
					
					-- strip clientId from channel
					subscription = string.gsub(subscription, "^/[0-9A-Za-z]+", "")
					
					if string.find(subscription, '/slim/request') then
						-- an async notification from a normal request
						subscription = subscription .. '|' .. event.id
						onetime_request = true
					end

					if self.notify[subscription] then
						log:debug("Comet:_getEventSink, notifiying callbacks for ", subscription)
					
						for _, func in pairs( self.notify[subscription] ) do
							log:debug("  callback to: ", func)
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
		ext                      = {
			rev = JIVE_VERSION,
		},
	} }
	
	local uuid, mac = self.jnt:getUUID()

	if mac then
		data[1].ext.mac = mac
	end
	if uuid then
		data[1].ext.uuid = uuid
	end

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

			-- try to reconnect according to advice
			_handleAdvice(self)
		end
		-- if we have data
		if chunk then
			local data = chunk[1]
			if data.successful then
				_active(self, true)
				self.clientId  = data.clientId
				self.advice    = data.advice

				log:debug("Comet:_handshake OK with ", self.jsName, ", clientId: ", self.clientId)
				
				
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

	-- Send immediately unless we're batching queries
	if self.active and not self.batch then
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
end

function unsubscribe(self, subscription, func)
	log:debug("Comet:unsubscribe(", subscription, ", ", func, ")")
	
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
		
		table.insert( self.pending_unsubs, subscription )
		
		if self.active and not self.batch then
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
	end
end

function request(self, func, playerid, request, priority)
	local id = self.reqid
	
	if log:isDebug() then
		log:debug("Comet:request(", func, ", reqid:", id, ", ", playerid, ", ", table.concat(request, ","), ", priority:", priority, ")")
	end
	
	if not self.active or self.batch then
		-- Add subscription to pending requests, to be sent during connect/reconnect
		table.insert( self.pending_reqs, {
                        reqid    = id,
                        func     = func,
                        playerid = playerid,
                        request  = request,
                        priority = priority,
		} )
		self.jnt:notify('cometDisconnected', self, #self.pending_reqs)
	else	
		local cmd = {}
		cmd[1] = playerid or ''
		cmd[2] = request
		
		local data = { {
			channel = '/slim/request',
			data    = {
				request  = cmd,
				response = '/' .. self.clientId .. '/slim/request',
				priority = priority,
			},
		} }

		-- only pass id if we have a callback function, this tells
		-- SlimServer we don't want a response
		if func then
			data[1]["id"] = id
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
			local subscription = '/slim/request|' .. id
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

				else
					log:warn("Comet:request unknown response")
				end
			end
		end
	end
end

function addCallback(self, subscription, func)
	log:debug("Comet:addCallback(", subscription, ", ", func, ")")

	if not self.notify[subscription] then
		self.notify[subscription] = {}
	end
	
	self.notify[subscription][func] = func
end

function removeCallback(self, subscription, func)
	log:debug("Comet:removeCallback(", subscription, ", ", func, ")")
	
	self.notify[subscription][func] = nil
end

-- Decide what to do if we get disconnected or get an error while handshaking/connecting
_handleAdvice = function(self)
	-- make sure our connection is closed
	if self.active then
		_active(self, false)
	end

	-- stop any existing reconnect timer
	if self.reconnect_timer then
		self.reconnect_timer:stop()
		self.reconnect_timer = nil
	end

	self.failures = self.failures + 1
	
	local advice = self.advice
	
	-- Keep retrying after multiple failures but backoff gracefully
	local retry_interval = ( advice.interval or RETRY_DEFAULT ) * self.failures
	
	-- XXX: Work around a bug in Timer where interval of 0 causes a loop
	if retry_interval < 1 then
		retry_interval = 1
	end
	
	if advice.reconnect == 'none' then
		self.clientId  = nil
		log:warn("Comet:_connect, server told us not to reconnect")

	elseif advice.reconnect == 'handshake' then
		log:warn(
			"Comet: advice is ", advice.reconnect, ", re-handshaking in ",
			retry_interval / 1000, " seconds"
		)
	
		self.clientId  = nil

		self.reconnect_timer = Timer(
			retry_interval,
			function()
				-- Go through all existing subscriptions and reset the pending flag
				-- so they are re-subscribed to during _connect()
				for i, v in ipairs( self.subs ) do
					log:debug("Will re-subscribe to ", v.subscription)
					v.pending = true
				end
				
				_handshake(self)
			end,
			true -- run timer only once
		)
		self.reconnect_timer:start()

	else -- if advice.reconnect == 'retry' then
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

-- Notify changes in connection state
_active = function(self, active)
        if self.active == active then
		return
	end

	self.active = active

	if active then
		-- Reset error count
		self.failures = 0

		self.jnt:notify('cometConnected', self)
	else
		-- force connections closed
		self.cpool:close()
		self.rpool:close()

		self.jnt:notify('cometDisconnected', self, #self.pending_reqs)
	end
end

-- Begin a set of batched queries
function startBatch(self)
	log:debug("Comet:startBatch()")

	self.batch = true
end

-- End batch mode, send all batched queries together
function endBatch(self)
	log:debug("Comet:endBatch()")
	
	self.batch = false
	
	-- add all pending requests
	local data = {}
	_addPendingRequests(self, data)

	-- Only continue if we have some data to send
	if data[1] then
		if log:isDebug() then
			log:debug("Sending pending queries:")
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

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
