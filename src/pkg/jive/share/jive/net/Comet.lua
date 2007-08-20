
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
 comet:subscribe('/slim/serverstatus', func, playerid, 'serverstatus', 0, 50, 'subscribe:60')

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

local oo           = require("loop.simple")

local CometRequest = require("jive.net.CometRequest")
local SocketHttp   = require("jive.net.SocketHttp")

local debug        = require("jive.utils.debug")
local log          = require("jive.utils.log").logger("net.comet")

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
	
	obj.jpool         = jpool    -- HttpPool from SlimServer
	obj.active        = false    -- whether or not we have an active connection
	obj.clientId      = nil      -- clientId provided by server
	obj.reqid         = 1        -- used to identify non-subscription requests
	obj.advice        = {}       -- advice from server on how to handle reconnects
	
	obj.pending_subs  = {}       -- pending subscriptions to send with connect
	obj.notify        = {}       -- callbacks to notify
	
	return obj
end

-- XXX: unsubscribe support

local function _getConnectSink(self)
	return function(chunk, err)
		-- on error, print something...
		if err then
			log:warn("Comet:_connect with ", self.jsName, " error: ", err)
			-- XXX: err will be 'closed' if we lose our connection
			-- XXX: try to reconnect according to advice
		end
		-- if we have data
		if chunk then
		
			-- Process each response event
			for i, event in ipairs(chunk) do
				if event.channel == '/meta/connect' and event.successful then
					log:debug("Comet:_connect, connect message acknowledged")
					self.active = true
				elseif event.channel == '/meta/subscribe' then
					-- subscribe was OK, we can ignore this
				elseif event.channel then
					local subscription = event.channel
					
					if subscription == '/slim/request' then
						-- an async notification from a normal request
						subscription = '/slim/request|' .. event.id
					else
						-- insert channel name into event data, this is used at least
						-- by the player sink to determine what process method to call
						event.data._channel = subscription
					end
					
					log:debug("Comet:_connect, notifiying callbacks for ", subscription)
					
					if self.notify[subscription] then
						for i2, func in ipairs( self.notify[subscription] ) do
							func(event.data)
						end
					end
				else
					log:warn("Comet:_connect error: ", event.error)
				end
			end
		end
	end
end

local function _connect(self)
	log:debug('Comet:_connect()')
	
	local data = { {
		channel        = '/meta/connect',
		clientId       = self.clientId,
		connectionType = 'streaming',
	} }
	
	-- Add any pending subscription requests
	for i, v in ipairs( self.pending_subs ) do
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
	
	-- Clear out pending subscriptions
	self.pending_subs = {}
	
	-- XXX: Add pending non-subscription requests
	
	local options = {
		headers = {
			['Content-Type'] = 'text/json',
		}
	}
	
	-- This will be our last request on this connection, it is now only
	-- for listening for responses
	
	local req = CometRequest(
		_getConnectSink(self),
		self.uri,
		data,
		options
	)
	
	self:fetch(req)
end

local function _getHandshakeSink(self)
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
				
				-- Continue with connect phase
				_connect(self)
			else
				log:warn("Comet:_handshake error: ", data.error)
			end
		end
	end
end

local function _handshake(self)
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

local function _getSubscribeSink(self)
	return function(chunk, err)
		-- on error, print something...
		if err then
			log:warn("Comet:subscribe error: ", err)
		end
		-- if we have data
		if chunk then
			local data = chunk[1]
			if data.successful then
				log:debug("Comet:subscribe OK for ", data.ext)
			else
				log:warn("Comet:subscribe error: ", data.error)
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
	
	if not self.active then
		-- Add subscription to pending subs, to be sent during connect
		table.insert( self.pending_subs, {
			subscription = subscription,
			playerid     = playerid,
			request      = request,
		} )
	else
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
			_getSubscribeSink(self),
			self.uri,
			data,
			options
		)
		
		self.jpool:queuePriority(req)
	end
end

local function _getRequestSink(self, func, reqid)
	return function(chunk, err)
		-- on error, print something...
		if err then
			log:warn("Comet:request error: ", err)
		end
		-- if we have data
		if chunk then
			for i, event in ipairs(chunk) do
				if event.error then
					log:warn("Comet:request error: ", event.error)
					func(nil, event.error)
				elseif event.channel == '/slim/request' and event.successful then
					log:debug("Comet:request OK for ", event.ext)
				elseif event.id == reqid then
					log:debug("Comet:request got result for request id ", reqid)
					
					-- Remove subscription, we know this was not an async request
					local subscription = '/slim/request|' .. reqid
					table.remove( self.notify[subscription] )
						
					func(event.data)
				end
			end
		end
	end
end

function request(self, func, playerid, request)
	if log:isDebug() then
		log:debug("Comet:request(", func, ", ", playerid, ", ", table.concat(request, ","), ")")
	end
	
	local cmd = {}
	cmd[1] = playerid or ''
	cmd[2] = request
	
	local data = { {
		channel      = '/slim/request',
		clientId     = self.clientId,
		id           = self.reqid,
		data         = cmd
	} }
	
	local options = {
		headers = {
			['Content-Type'] = 'text/json',
		}
	}
	
	local req = CometRequest(
		_getRequestSink(self, func, self.reqid),
		self.uri,
		data,
		options
	)
	
	self.jpool:queue(req)
	
	-- If the request is async, we will get the response on the persistent
	-- connection.  Store our callback until we know if it's async or not
	local subscription = '/slim/request|' .. self.reqid
	if not self.notify[subscription] then
		self.notify[subscription] = {}
	end
	table.insert( self.notify[subscription], func )
	
	-- Bump reqid for the next request
	self.reqid = self.reqid + 1
end

function start(self)
	-- Begin handshake
	_handshake(self)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]