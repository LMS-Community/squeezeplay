
--[[
=head1 NAME

jive.slim.Player - Squeezebox/Transporter player.

=head1 DESCRIPTION

TODO

=head1 SYNOPSIS

TODO

=head1 FUNCTIONS

=cut
--]]

local debug = require("jive.utils.debug")

-- stuff we need
local assert, tostring = assert, tostring

local os             = require("os")
local string         = require("string")
local table          = require("table")

local oo             = require("loop.base")

local SocketHttp     = require("jive.net.SocketHttp")
local RequestHttp    = require("jive.net.RequestHttp")
local RequestJsonRpc = require("jive.net.RequestJsonRpc")
local Framework      = require("jive.ui.Framework")
local Popup          = require("jive.ui.Popup")
local Textarea       = require("jive.ui.Textarea")

local log            = require("jive.utils.log").logger("player")
local logv           = require("jive.utils.log").logger("player.browse.volume")

require("jive.slim.RequestsCli")
local RequestStatus  = jive.slim.RequestStatus
local RequestCli     = jive.slim.RequestCli
local RequestDisplaystatus = jive.slim.RequestDisplaystatus

local iconbar        = iconbar


local fmt = string.format

-- jive.slim.Player is a base class
module(..., oo.class)


-- _getSink
-- returns a sink with a closure to self
-- this sink receives all the data from our JSON RPC interface
local function _getSink(self)

	return function(chunk, err)
	
		if err then
			log:debug(err)
			
		elseif chunk then
			log:info(chunk)
			
			local proc = "_process_" .. chunk.params[2][1]
			if self[proc] then
				self[proc](self, chunk)
			end
				
		end
	end
end


--[[

=head2 jive.slim.Player(server, jnt, jpool, playerinfo)

Create a Player object for server I<server>.

=cut
--]]
function __init(self, slimServer, jnt, jpool, playerinfo)
	log:debug("Player:__init(", tostring(playerinfo.playerid), ")")

	assert(slimServer, "Cannot create Player without SlimServer object")
	
	local obj = oo.rawnew(self,{
		
		lastSeen = os.time(),
		
		slimServer = slimServer,
		jnt = jnt,
		jpool = jpool,

		id = playerinfo.playerid,
		name = playerinfo.name,
		model = playerinfo.model,

		-- menu item of home menu that represents this player
		homeMenuItem = false,
		
		jsp = false,
		jdsp = false,
		
		isOnStage = false,
		statusSink = false,
	})
	
	-- notify we're here
	obj.jnt:notify('playerNew', obj)
	
	return obj
end


--[[

=head2 jive.slim.Player:free()

Deletes the player.

=cut
--]]
function free(self)
	self:offStage()
	self.jnt:notify("playerDelete", self)
end


--[[

=head2 jive.slim.Player:getHomeMenuItem()

Returns the home menu menuItem that represents this player. This is
used by L<jive.applet.SlimDiscovery> to remove the player from the menu
if/when it disappears.

=cut
--]]
function getHomeMenuItem(self)
	-- return nil if self.homeMenuItem is false
	if self.homeMenuItem then
		return self.homeMenuItem
	end
	return nil
end


--[[

=head2 jive.slim.Player:setHomeMenuItem(homeMenuItem)

Stores the main home menuItem that represents this player. This is
used by L<jive.applet.SlimDiscovery> to manage the home menu item.

=cut
--]]
function setHomeMenuItem(self, homeMenuItem)
	-- set self.homeMenuItem to false if sent nil
	if homeMenuItem then
		self.homeMenuItem = homeMenuItem
	else
		self.homeMenuItem = false
	end
end


--[[

=head2 tostring(aPlayer)

if I<aPlayer> is a L<jive.slim.Player>, prints
 Player {name}

=cut
--]]
function __tostring(self)
	return "Player {" .. self.name .. "}"
end


-- call
-- sends a command
function call(self, cmd)
	log:debug("Player:call():")
	log:debug(cmd)
	local req = RequestCli(
		_getSink(self), --sink, 
		self, --player, 
		cmd --cmdarray, 
		--from, 
		--to, 
		--params, 
		--options
	)
	local id = req:getJsonId()
	self:queuePriority(req)
	return id
end


-- onStage
-- we're being browsed!
function onStage(self, sink)
	log:debug("Player:onStage()")

	self.isOnStage = true
	self.statusSink = sink
	
	-- our socket for long term connections
	local ip, port = self.slimServer:getIpPort()
	self.jsp = SocketHttp(self.jnt, ip, port, self.name .. "LT")
	
	-- our long term request
	-- FIXME: check it really sends data every so many seconds!
	self.jsp:fetch(
		RequestStatus(
			_getSink(self), 
			self, 
			'-', 
			10, 
			30, 
			{menu = 'menu'}
		)
	)

	-- 2nd long term request for displaystatus
	local ip, port = self.slimServer:getIpPort()
	self.jdsp = SocketHttp(self.jnt, ip, port, self.name .. "LT")

	self.jdsp:fetch(
		RequestDisplaystatus(
			_getSink(self),
			self,
			'showbriefly'
		)
	)

end


-- offStage
-- go back to the shadows...
function offStage(self)
	log:debug("Player:offStage()")

	self.isOnStage = false
	
	if self.jsp then
		self.jsp:free()
		self.jsp = false
	end

	if self.jdsp then
		self.jdsp:free()
		self.jdsp = false
	end
	
	iconbar:setPlaymode(nil)
	iconbar:setRepeat(nil)
	iconbar:setShuffle(nil)
end


-- updateIconbar
function updateIconbar(self)
	log:debug("Player:updateIconbar()")
	
	if self.isOnStage and self.state then

		-- set the playmode (nil, stop, play, pause)
		iconbar:setPlaymode(self.state["mode"])
		
		-- set the repeat (nil, 0=off, 1=track, 2=playlist)
		iconbar:setRepeat(self.state["playlist repeat"])
	
		-- set the shuffle (nil, 0=off, 1=by song, 2=by album)
		iconbar:setShuffle(self.state["playlist shuffle"])
	end
end


-- _process_status
-- receives the status data
function _process_status(self, data)
	log:debug("Player:_process_status()")
	if self.state then
		logv:debug("-------------------------Player:volume: ", tostring(self.state["mixer volume"]), " - " , tostring(data.result["mixer volume"]))
	end
	
	-- cache result
	self.state = data.result
	
	self:updateIconbar()
	
	self:feedStatusSink()
end


-- feedStatusSink
--
function feedStatusSink(self)
	if self.state and self.statusSink then
		self.statusSink(self.state)
	end
end


-- _process_displaystatus
-- receives the display status data
function _process_displaystatus(self, data)
	log:debug("Player:_process_displaystatus()")

	debug.dump(data.result,10)

	if data.result.display then 
		if data.result.display.line then

			local popup = Popup("popup", "showBriefly")

			local text = Textarea("textarea", table.concat(data.result.display.line, "\n\n"))
			popup:addWidget(text)
			popup:showBriefly(2000)
		end
	end
end


-- togglePause
--
function togglePause(self)

	if not self.state then  return end
	
	local paused = self.state["mode"]
	log:debug("Player:togglePause(", paused, ")")

	if paused == 'stop' then
		return
	elseif paused == 'pause' then
		self:call({'pause', '0'})
		self.state["mode"] = 'play'
	elseif paused == 'play' then
		self:call({'pause', '1'})
		self.state["mode"] = 'pause'
	end
	self:updateIconbar()
end	


-- isPaused
--
function isPaused(self)
	if self.state then
		return self.state["mode"] == 'pause'
	end
end


-- isCurrent
--
function isCurrent(self, index)
	if self.state then
		return self.state["playlist_cur_index"] == index - 1
	end
end


-- stop
-- 
function stop(self)
	log:debug("Player:stop()")
	self:call({'mode', 'stop'})
	self.state["mode"] = 'stop'
	self:updateIconbar()
end


-- playlistJumpIndex
--
function playlistJumpIndex(self, index)
	log:debug("Player:playlistJumpIndex(", index, ")")
	if index < 1 then return end
	self:call({'playlist', 'index', index - 1})
end


-- playlistDeleteIndex(self, index)
--
function playlistDeleteIndex(self, index)
	log:debug("Player:playlistDeleteIndex(", index, ")")
	if index < 1 then return end
	self:call({'playlist', 'delete', index - 1})
end


-- playlistZapIndex(self, index)
--
function playlistZapIndex(self, index)
	log:debug("Player:playlistZapIndex(", index, ")")
	if index < 1 then return end
	self:call({'playlist', 'zap', index - 1})
end




function _process_button(self, data)
	log:debug("_process_button()")
	log:debug("id:", tostring(data["id"]), " waiting on:", tostring(self.buttonId))
	if data["id"] == self.buttonId then
		log:debug("cleared")
		self.buttonId = false
	end
end

function button(self, buttonName)
	log:debug("Player:button(", buttonName, ")")
	if not self.buttonId then
		log:debug(".. sent")
		self.buttonId = self:call({'button', buttonName})
	else
		log:debug(".. ignored")
	end
end

local function _t()
	return Framework:getTicks() / 1000
end


--[[
function _process_ir(self, data)
--	log:debug("_process_ir()")
--	log:debug("id:", tostring(data["id"]), " waiting on:", tostring(self.irId))
	if data["id"] == self.irId then
--		log:debug("cleared")
		self.irId = false
		log:warn("round trip:", tostring(_t() - self.irT))
	end
end

function volumeUp(self)
--	log:debug("Player:volumeUp()")
	if not self.irId then
--		log:debug(".. sent")
		local t = _t()
		self.irT = t
		self.irId = self:call({'ir', '7689807f', _t()})
--	else
--		log:debug(".. ignored")
	end
end

function volumeDown(self)
--	log:debug("Player:volumeDown")
	if not self.irId then
--		log:debug(".. sent")
		local t = _t()
		self.irT = t
		self.irId = self:call({'ir', '768900ff', _t()})
--	else
--		log:debug(".. ignored")
	end
end
--]]


function _process_mixer(self, data)
--	log:debug("_process_ir()")
--	log:debug("id:", tostring(data["id"]), " waiting on:", tostring(self.irId))
	if data["id"] == self.mixerId then
--		log:debug("cleared")
		self.mixerId = false
		log:warn("Mixer round trip:", tostring(_t() - self.mixerT))
	end
end

function volume(self, amount)

	local vol = self.state["mixer volume"]
	
	if not self.mixerId then
		logv:debug("Player:volume(", tostring(amount), ")")
		
		self.mixerT = _t()
		self.mixerId = self:call({'mixer', 'volume', fmt("%+d", amount)})
		
		vol = vol + amount
		if vol > 100 then vol = 100 elseif vol < 0 then vol = 0 end
		self.state["mixer volume"] = vol
		
	else
		logv:debug("(Player:volume(", tostring(amount), "))")
	end
	
	return vol
end


function getVolume(self)
	if self.state then
		return self.state["mixer volume"] or 0
	end
end



local function _getHtmlSink(self)

	return function(chunk, err)
	
		if err then
			log:debug(err)
			
		elseif chunk then
			log:info(chunk)
			
			local proc = "_process_html"
			if self[proc] then
				self[proc](self, chunk)
			end
				
		end
	end
end

function _process_html(self, chunk)
	self.htmltime = self.htmltime + (_t() - self.htmlT)
	self.htmlcalls = self.htmlcalls + 1
	log:error("HTML average round trip:", tostring(self.htmltime), "/", tostring(self.htmlcalls), " = ", tostring(self.htmltime/self.htmlcalls))
end

function indexhtml2(self)
	log:error("Player:indexhtml2():")
	log:error({whatevr='whatever'})
	local req = RequestHttp(
		_getHtmlSink(self), --sink, 
		'GET', --player, 
		"/index.html")
	self:queuePriority(req)
end

function indexhtml(self)
	if not 	self.htmlcalls then
			self.htmlcalls = 0
			self.htmltime = 0
		end
	self.htmlT = _t()
	self:indexhtml2()
end
	



-- (accessors)
function getName(self)
	return self.name
end

function getId(self)
	return self.id
end

function getSlimServer(self)
	return self.slimServer
end


-- queue
-- proxy function for the slimserver pool
function queue(self, request)
	self.jpool:queue(request)
end


-- queuePriority
-- proxy function for the slimserver pool
function queuePriority(self, request)
	self.jpool:queuePriority(request)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

