
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
 -- player may be nil
 comet:subscribe('/slim/serverstatus', func, player, 'serverstatus', 0, 50, 'subscribe:60')

 -- send a non-subscription request
 -- player may be nil
 comet:request(func, player, 'menu', 0, 100)

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
function __init(self, jnt, ip, port, path, name)
	log:debug("Comet:__init(", name, ", ", ip, ", ", port, ", ", path, ")")

	-- init superclass
	local obj = oo.rawnew( self, SocketHttp(jnt, ip, port, name) )
	
	obj.uri = 'http://' .. ip .. ':' .. port .. path
	
	obj.active        = false
	obj.clientId      = nil
	obj.advice        = {}
	
	obj.pending_subs  = {}
	obj.notify        = {}
	
	return obj
end

-- XXX: handle disconnects, reconnect

local function _getConnectSink(self)
	return function(chunk, err)
		-- on error, print something...
		if err then
			log:debug("Comet:_connect with ", self.jsName, " error: ", err)
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
					log:debug("Comet:_connect, notifying callbacks for ", event.channel)
					-- we got an event on another channel, notify callbacks
					if self.notify[ event.channel ] then
						for i2, func in ipairs( self.notify[ event.channel ] ) do
							func(event)
						end
					end
				else
					log:debug("Comet:_connect error: ", event.error)
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
		local request = {}
		request[1] = v.player or ''
		request[2] = v.args
		
		local sub = {
			channel      = '/meta/subscribe',
			clientId     = self.clientId,
			subscription = v.subscription,
			ext          = {
				['slim.request'] = request
			},
		}
		
		data[ #data + 1 ] = sub
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
			log:debug("Comet:_handshake with ", self.jsName, " error: ", err)
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
				log:debug("Comet:_handshake error: ", data.error)
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

function subscribe(self, subscription, func, player, ...)
	log:debug("Comet:subscribe(", subscription, ", ", func, ", ", player, ", ", ..., ")")
	
	-- Add callback
	if not self.notify[subscription] then
		self.notify[subscription] = {}
	end
	
	table.insert( self.notify[subscription], func )
	
	if not self.active then
		-- Add subscription to pending subs, to be sent during connect
		self.pending_subs[ #self.pending_subs + 1 ] = {
			subscription = subscription,
			player       = player,
			args         = {...},
		}
	else
		-- XXX: send subscription now on a pool connection
	end
end

-- XXX: function request

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