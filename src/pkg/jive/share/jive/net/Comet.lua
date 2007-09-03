
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
local ipairs, table = ipairs, table

local oo            = require("loop.simple")

local CometRequest  = require("jive.net.CometRequest")
local SocketHttp    = require("jive.net.SocketHttp")
local Timer         = require("jive.ui.Timer")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("net.comet")

local RETRY_DEFAULT = 5000

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
function __init(self, jnt, jpool, ip, port, path, name)
	log:debug("Comet:__init(", name, ", ", ip, ", ", port, ", ", path, ")")

	-- init superclass
	local obj = oo.rawnew( self, SocketHttp(jnt, ip, port, name) )
	
	obj.uri = 'http://' .. ip .. ':' .. port .. path
	
	obj.jpool          = jpool    -- HttpPool from SlimServer
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
local _connect
local _getEventSink
local _handleAdvice
local _handshake
local _getHandshakeSink
local _getRequestSink
local _getUnsubscribeSink
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

_connect = function(self)
	log:debug('Comet:_connect()')
	
	local data = { {
		channel        = '/meta/connect',
		clientId       = self.clientId,
		connectionType = 'streaming',
	} }
	
	-- Add any pending subscription requests
	for i, v in ipairs( self.subs ) do
		-- really hating the lack of true arrays!
		local cmd = {}
		cmd[1] = v.playerid or ''
		cmd[2] = v.request
		
		local sub = {
			channel      = '/meta/subscribe',
			clientId     = self.clientId,
			subscription = v.subscription,
			ext          = {
				['slim.request'] = cmd
			},
		}
		
		table.insert( data, sub )
	end
	
	-- Add pending unsubscribe requests
	for i, v in ipairs( self.pending_unsubs ) do
		local unsub = {
			channel      = '/meta/unsubscribe',
			clientId     = self.clientId,
			subscription = v,
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
			channel      = '/slim/request',
			clientId     = self.clientId,
			id           = v.reqid,
			data         = cmd
		}
		
		table.insert( data, req )
		
		-- Store this request's callback
		local subscription = '/slim/request|' .. self.reqid
		if not self.notify[subscription] then
			self.notify[subscription] = {}
		end
		table.insert( self.notify[subscription], v.func )
	end
	
	-- Clear out pending requests
	self.pending_reqs = {}
	
	local options = {
		headers = {
			['Content-Type'] = 'text/json',
		}
	}
	
	-- This will be our last request on this connection, it is now only
	-- for listening for responses
	
	local req = CometRequest(
		_getEventSink(self),
		self.uri,
		data,
		options
	)
	
	self:fetch(req)
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
						log:debug("Comet:_getEventSink, connect failed: ", event.error)
						_handleAdvice(self)
						break
					end
				elseif event.channel == '/meta/reconnect' then
					if event.successful then
						log:debug("Comet:_getEventSink, reconnect OK")
						self.active   = true
						self.failures = 0
					else
						log:debug("Comet:_getEventSink, reconnect failed: ", event.error)
						_handleAdvice(self)
						break
					end
				elseif event.channel == '/meta/subscribe' then
					if event.successful then
						log:debug("Comet:_getEventSink, subscription OK for ", event.subscription)
					else
						log:warn("Comet:_getEventSink, subscription failed for ", event.subscription, ": ", event.error)
					end
				elseif event.channel then
					local subscription    = event.channel
					local onetime_request = false
					
					if subscription == '/slim/request' then
						-- an async notification from a normal request
						subscription = '/slim/request|' .. event.id
						onetime_request = true
					end
					
					log:debug("Comet:_getEventSink, notifiying callbacks for ", subscription)
					
					if self.notify[subscription] then
						for i2, func in ipairs( self.notify[subscription] ) do
							func(event)
						end
						
						if onetime_request then
							-- this was a one-time request, so remove the callback
							self.notify[subscription] = nil
						end
					else
						log:warn("Comet:_getEventSink, got data for an event we aren't subscribed to! -> ", subscription)
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
	
	local options = {
		headers = {
			['Content-Type'] = 'text/json',
		}
	}
	
	-- XXX: according to the spec this should be sent as application/x-www-form-urlencoded
	-- with message=<url-encoded json> but it works as straight JSON
	
	local req = CometRequest(
		_getHandshakeSink(self),
		self.uri,
		data,
		options
	)
	
	self:fetch(req)
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

function subscribe(self, subscription, func, playerid, request)
	if log:isDebug() then
		log:debug("Comet:subscribe(", subscription, ", ", func, ", ", playerid, ", ", table.concat(request, ","), ")")
	end
	
	-- Add callback
	if not self.notify[subscription] then
		self.notify[subscription] = {}
	end
	
	table.insert( self.notify[subscription], func )
	
	-- Remember subs to send during connect now, or if we get
	-- disconnected
	table.insert( self.subs, {
		subscription = subscription,
		playerid     = playerid,
		request      = request,
	} )
	
	if self.active then
		-- send subscription request on a pool connection
		local cmd = {}
		cmd[1] = playerid or ''
		cmd[2] = request
		
		local data = { {
			channel      = '/meta/subscribe',
			clientId     = self.clientId,
			subscription = subscription,
			ext          = {
				['slim.request'] = cmd
			},
		} }

		local options = {
			headers = {
				['Content-Type'] = 'text/json',
			}
		}
		
		local req = CometRequest(
			_getEventSink(self),
			self.uri,
			data,
			options
		)
		
		self.jpool:queuePriority(req)
	end
end

function unsubscribe(self, subscription, func)
	log:debug("Comet:unsubscribe(", subscription, ", ", func, ")")
	
	-- Remove from notify list
	if func then
		-- Remove only the given callback
		for i, v in ipairs( self.notify[subscription] ) do
			if v == func then
				self.notify[subscription][i] = nil
				break
			end
		end
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
	
		if not self.active then
			table.insert( self.pending_unsubs, subscription )
		else
			local data = { {
				channel      = '/meta/unsubscribe',
				clientId     = self.clientId,
				subscription = subscription
			} }
	
			local options = {
				headers = {
					['Content-Type'] = 'text/json',
				}
			}
		
			local req = CometRequest(
				_getUnsubscribeSink(self),
				self.uri,
				data,
				options
			)
	
			self.jpool:queuePriority(req)
		end
	end
end

_getUnsubscribeSink = function(self)
	return function(chunk, err)
		-- on error, print something...
		if err then
			log:warn("Comet:unsubscribe error: ", err)
		end
		-- if we have data
		if chunk then
			local data = chunk[1]
			
			if data.advice then
				self.advice = data.advice
			end
			
			if data.successful then
				log:debug("Comet:unsubscribe OK for ", data.subscription)
			else
				log:warn("Comet:unsubscribe error: ", data.error)
			end
		end
	end
end

function request(self, func, playerid, request)
	if log:isDebug() then
		log:debug("Comet:request(", func, ", ", playerid, ", ", table.concat(request, ","), ")")
	end
	
	if not self.active then
		-- Add subscription to pending requets, to be sent during connect/reconnect
		table.insert( self.pending_reqs, {
			reqid    = self.reqid,
			func     = func,
			playerid = playerid,
			request  = request,
		} )
	else	
		local cmd = {}
		cmd[1] = playerid or ''
		cmd[2] = request
	
		local data = { {
			channel      = '/slim/request',
			clientId     = self.clientId,
			id           = self.reqid,
			data         = cmd
		} }
		
		-- Requests can be sent that don't want a response
		-- to save CPU time on Jive.  'no-response' tells the
		-- server to send only a minimal HTTP response that we
		-- will then ignore
		if not func then
			data[1]["ext"] = {
				["no-response"] = 1
			}
		end
	
		local options = {
			headers = {
				['Content-Type'] = 'text/json',
			}
		}
		
		local sink = nil
		if func then
			sink = _getRequestSink(self, func, self.reqid)
		end
	
		local req = CometRequest(
			sink,
			self.uri,
			data,
			options
		)
	
		self.jpool:queuePriority(req)
	
		-- If we expect a response, and the request is async, we will get the 
		-- response on the persistent connection.  Store our callback until we
		-- know if it's async or not
		if func then
			local subscription = '/slim/request|' .. self.reqid
			if not self.notify[subscription] then
				self.notify[subscription] = {}
			end
			table.insert( self.notify[subscription], func )
		else
			log:debug('  No sink defined for this request, no response will be received')
		end
	end
	
	-- Bump reqid for the next request
	self.reqid = self.reqid + 1
	
	-- Return the request id to the caller
	return self.reqid - 1
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
				elseif event.id == reqid then
					log:debug("Comet:request got result for request id ", reqid)
					
					-- Remove subscription, we know this was not an async request
					local subscription = '/slim/request|' .. reqid
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

	local options = {
		headers = {
			['Content-Type'] = 'text/json',
		}
	}
	
	local req = CometRequest(
		_getEventSink(self),
		self.uri,
		data,
		options
	)
	
	self:fetch(req)	
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]