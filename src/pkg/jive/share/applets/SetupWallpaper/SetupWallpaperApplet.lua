
--[[
=head1 NAME

applets.SetupWallpaper.SetupWallpaperApplet - Wallpaper selection.

=head1 DESCRIPTION

This applet implements selection of the wallpaper for the jive background image.

The applet includes a selection of local wallpapers which are shipped with jive. It
also allows wallpapers to be downloaded and selected from the currently  attached server.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
SetupWallpaperApplet overrides the following methods:

=cut
--]]


-- stuff we use
local ipairs, pairs, type, print, tostring = ipairs, pairs, type, print, tostring

local oo                     = require("loop.simple")
local io                     = require("io")
local os                     = require("os")
local table                  = require("jive.utils.table")
local lfs                    = require("lfs")

local Applet                 = require("jive.Applet")
local AppletManager          = require("jive.AppletManager")
local Framework              = require("jive.ui.Framework")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Tile                   = require("jive.ui.Tile")
local Window                 = require("jive.ui.Window")
local Framework              = require("jive.ui.Framework")

local RequestHttp            = require("jive.net.RequestHttp")
local SocketHttp             = require("jive.net.SocketHttp")

local log                    = require("jive.utils.log").logger("applets.setup")
local debug                  = require("jive.utils.debug")

local EVENT_FOCUS_GAINED     = jive.ui.EVENT_FOCUS_GAINED
local EVENT_FOCUS_LOST       = jive.ui.EVENT_FOCUS_LOST
local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP

local jnt                    = jnt

module(...)
oo.class(_M, Applet)


-- Wallpapers
local localwallpapers = {
	{
		["SUNRISE"] = "sunrise.png",
	},
	{
		["SUNLIGHT"] = "sunlight.png",
		["FADETOBLACK"] = "fade_to_black.png",
	},
	{
		["CONCRETE"] = "concrete.png",
		["MIDNIGHT"] = "midnight.png",
		["PEA"] = "pea.png",
		["BLACK"] = "black.png",
		["STONE"] = "stone.png",
	},
	{
		["DUNES"] = "Chapple_1.jpg",
		["IRIS"] = "Clearly-Ambiguous_1.jpg",
		["SMOKE"] = "Clearly-Ambiguous_3.jpg",
		["AMBER"] = "Clearly-Ambiguous_4.jpg",
		["FLAME"] = "Clearly-Ambiguous_6.jpg",
		["GRAFFITI"] = "Los-Cardinalos_1.jpg",
		["WEATHERED_WOOD"] = "Orin-Optiglot_1.jpg",
	}
}

local authors = { "Chapple", "Scott Robinson", "Los Cardinalos", "Orin Optiglot" }

local PREFIX = "applets/SetupWallpaper/wallpaper/"

local REFRESH_TIME = 300 -- only fetch remote wallpapers while browsing if the file is older than this (seconds)

function init(self)
	jnt:subscribe(self)
end

-- notify_playerCurrent
-- this is called when the current player changes (possibly from no player)
function notify_playerCurrent(self, player)
        log:info("SetupWallpaper:notify_playerCurrent(", player, ")")
	if player == self.player then
		return
	end

	self.player = player
	if player and player:getId() then
		self:setBackground(nil, player:getId())
	else
		self:setBackground(nil, 'wallpaper')
	end
end

function settingsShow(self)
	local window = Window("window", self:string('WALLPAPER'), 'settingstitle')

	self.currentPlayerId = 'wallpaper'

	local _playerName    = false

	if not self.player then
		self.player = _getCurrentPlayer()
	end

	if self.player then
		self.currentPlayerId = self.player:getId()
		self.playerName    = self.player:getName()
	end

	if self.playerName then
		window:addWidget(Textarea("help", self:string("WALLPAPER_HELP_PLAYER", self.playerName)))
	else
		window:addWidget(Textarea("help", self:string("WALLPAPER_HELP_NO_PLAYER")))
	end

	self.menu = SimpleMenu("menu")
	window:addWidget(self.menu)

	local wallpaper = self:getSettings()[self.currentPlayerId]

	self.server = self:_getCurrentServer()

	self.group  = RadioGroup()

	self.menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	
	for w, section in ipairs(localwallpapers) do
		for name, file in table.pairsByKeys(section) do
			self.menu:addItem({
				weight = w,
				text = self:string(name), 
				sound = "WINDOWSHOW",
				icon = RadioButton("radio", 
								   self.group, 
								   function()
									   self:setBackground(file, self.currentPlayerId)
								   end,
								   wallpaper == file
							   ),
				focusGained = function(event)
								  self:showBackground(file, self.currentPlayerId)
							  end
			})

			if wallpaper == file then
				self.menu:setSelectedIndex(self.menu:numItems())
			end
		end
	end

	self.menu:addItem(self:_licenseMenuItem())

	-- look for any server based wallpapers
	if self.server then
		log:info("found server - requesting wallpapers list")
		self.server.comet:request(
			function(chunk, err)
				if err then
					log:debug(err)
				elseif chunk then
					self:_serverSink(chunk.data)
				end
			end,
			false,
			{ "jivewallpapers" }
		)
	end

	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
		function()
			self:showBackground(nil, self.currentPlayerId)
			self:storeSettings()
		end
	)

	self:tieAndShowWindow(window)
	return window
end

function _getCurrentPlayer(self)
	local manager = AppletManager:getAppletInstance("SlimDiscovery")

	if manager and manager:getCurrentPlayer() then
		return manager:getCurrentPlayer()
	end
	return false
end

function _getCurrentServer(self)

	local server
	if self.player then
		server = self.player:getSlimServer()
	else
		local manager = AppletManager:getAppletInstance("SlimDiscovery")
		for _, s in manager:allServers() do
			server = s
			break
		end
	end

	return server
end


function _serverSink(self, data)

	local ip, port = self.server:getIpPort()

	if data.item_loop then
		for _,entry in pairs(data.item_loop) do
			log:info("server wallpaper: ", entry.name)
			self.menu:addItem(
				{
					weight = 50,	  
					text = entry.name,
					icon = RadioButton("radio",
									   self.group,
									   function()
										   local path = Framework:findFile(PREFIX) .. entry.file
										   local attr = lfs.attributes(path)
										   if attr then
											   self:setBackground(entry.file, self.currentPlayerId)
										   end
									   end
								   ),
					focusGained = function()
									  local path = Framework:findFile(PREFIX) .. entry.file
									  local attr = lfs.attributes(path)
									  if attr and os.time() - attr.modification < REFRESH_TIME then
										  log:info("using local copy of: ", entry.file)
										  self:showBackground(entry.file, self.currentPlayerId)
									  else
										  log:info("fetching: ", entry.file)
										  local url
										  if entry.relurl then
											  url = 'http://' .. ip .. ':' .. port .. entry.relurl
										  else
											  url = entry.url
										  end
										  self:_fetchFile(url, path, function() self:showBackground(entry.file, self.currentPlayerId) end)
									  end
								  end
				}
			)
		end
	end
end


function _licenseMenuItem(self)
	return {
		weight = 99,
		text = self:string("CREDITS"),
		sound = "WINDOWSHOW",
		callback = function()
			local window = Window("window", self:string("CREDITS"))
			
			local text =
				tostring(self:string("CREATIVE_COMMONS")) ..
				"\n\n" ..
				tostring(self:string("CREDITS_BY")) ..
				"\n " ..
				table.concat(authors, "\n ")

			window:addWidget(Textarea("textarea", text))
			self:tieAndShowWindow(window)
		end,
		focusGained = function(event) self:showBackground(nil, self.currentPlayerId) end
	}
end


function _fetchFile(self, url, path, callback)
	self.last = path

	if self.fetch == nil then
		self.fetch = {}
	end
	if self.fetch[path] then
		log:warn("already fetching ", path, " not fetching again")
		return
	end
	self.fetch[path] = 1

	local req = RequestHttp(
		function(chunk, err)
			self.fetch[path] = nil
			if err then
				log:error("error fetching background from server: ", path, " ", url)
			end
			if chunk then
				log:info("fetched background from server: ", path, " ", url)
				local fh = io.open(path, "wb")
				if fh then
					fh:write(chunk)
					fh:close()
					if path == self.last then
						callback()
					end
				else
					log:error("unable to open ", path, " for writing")
				end
			end
		end,
		'GET',
		url
	)

	local uri  = req:getURI()
	local http = SocketHttp(jnt, uri.host, uri.port, uri.host)

	http:fetch(req)
end


function showBackground(self, wallpaper, playerId)
	if not playerId then playerId = 'wallpaper' end
	if not wallpaper then
		wallpaper = self:getSettings()[playerId]
		if not wallpaper then
			wallpaper = self:getSettings()["wallpaper"]
		end
	end

	if self.currentWallpaper == wallpaper then
		-- no change
		return
	end
	self.currentWallpaper = wallpaper

	local srf = Tile:loadImage(PREFIX .. wallpaper)
	if srf ~= nil then
		Framework:setBackground(srf)
	end
end


function setBackground(self, wallpaper, playerId)

	if not playerId then 
		playerId = 'wallpaper' 
	end
	log:info('SetupWallpaper, setting wallpaper for ', playerId)
	-- set the new wallpaper, or use the existing setting
	if wallpaper then
		self:getSettings()[playerId] = wallpaper
	end

	self:showBackground(wallpaper, playerId)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

