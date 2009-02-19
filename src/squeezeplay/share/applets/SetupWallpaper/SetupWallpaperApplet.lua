
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
local ipairs, pairs, type, print, tostring, string = ipairs, pairs, type, print, tostring, string

local oo                     = require("loop.simple")
local io                     = require("io")
local table                  = require("jive.utils.table")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")
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

local jnt                    = jnt
local appletManager          = appletManager

module(..., Framework.constants)
oo.class(_M, Applet)


-- Wallpapers
local localwallpapers = {
	{
		["SUNRISE"] = "sunrise.png",
	},
	{
		['RULED_LINES'] = 'ruled_lines.png',
		['WAVE1'] = 'wave1.png',
		['WAVE2'] = 'wave2.png',
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
	},
	{

		['WEATHEREDRED'] = 'redgrunge.jpg',
		['PURPLENOTE'] = 'purplenote.jpg',
		['ORANGEMARBLE'] = 'orangemarble.jpg',
		['NOTE'] = 'note.jpg',
		['GREENFLOWERS'] = 'flowersgreen.jpg'
	},
	{
		["STONE"] = "stone.png",
		["DUNES"] = "Chapple_1.jpg",
		["IRIS"] = "Clearly-Ambiguous_1.jpg",
		["SMOKE"] = "Clearly-Ambiguous_3.jpg",
		["AMBER"] = "Clearly-Ambiguous_4.jpg",
		["FLAME"] = "Clearly-Ambiguous_6.jpg",
		["GRAFFITI"] = "Los-Cardinalos_1.jpg",
		["WEATHERED_WOOD"] = "Orin-Optiglot_1.jpg",
	}
}

local authors = { "Chapple", "Scott Robinson", "Los Cardinalos", "Orin Optiglot", "Ryan McD", "Robbie Fisher" }

local firmwarePrefix = "applets/SetupWallpaper/wallpaper/"
local downloadPrefix


function init(self)
	jnt:subscribe(self)

	downloadPrefix = System.getUserDir().. "/wallpapers"
	appletManager._mkdirRecursive(downloadPrefix)
	downloadPrefix = downloadPrefix .. "/"

	log:info("downloaded wallpapers stored at: ", downloadPrefix)

	self.download = {}
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
		self.player = appletManager:callService("getCurrentPlayer")
	end

	if self.player then
		self.currentPlayerId = self.player:getId()
		self.playerName    = self.player:getName()
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

	-- get list of downloadable wallpapers from the server
	if self.server then

		local x, y = Framework:getScreenSize()
		local screen = x .. "x" .. y
		if screen ~= "480x272" and screen ~= "240x320" then
			screen = nil
		end

		log:info("found server - requesting wallpapers list ", screen)

		self.server:userRequest(
			function(chunk, err)
				if err then
					log:debug(err)
				elseif chunk then
					self:_serverSink(chunk.data)
				end
			end,
			false,
			screen and { "jivewallpapers", "target:" .. screen } or { "jivewallpapers" }
		)
	end

	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
		function()
			self:showBackground(nil, self.currentPlayerId)
			self:storeSettings()
			self.download = {}
		end
	)

	self:tieAndShowWindow(window)
	return window
end


function _getCurrentServer(self)

	local server
	if self.player then
		server = self.player:getSlimServer()
	else
		for _, s in appletManager:callService("iterateSqueezeCenters") do
			server = s
			break
		end
	end

	return server
end


function _serverSink(self, data)

	local ip, port = self.server:getIpPort()

	local wallpaper = self:getSettings()[self.currentPlayerId]

	if data.item_loop then
		for _,entry in pairs(data.item_loop) do
			local url
			if entry.relurl then
				url = 'http://' .. ip .. ':' .. port .. entry.relurl
			else
				url = entry.url
			end
			log:info("remote wallpaper: ", entry.title, " ", url)
			self.menu:addItem(
				{
					weight = 50,	  
					text = entry.title,
					icon = RadioButton("radio",
									   self.group,
									   function()
										   if self.download[url] then
											   self:setBackground(url, self.currentPlayerId)
										   end
									   end,
									   wallpaper == url
								   ),
					focusGained = function()
									  if self.download[url] and self.download[url] ~= "fetch" and self.download[url] ~= "fetchset" then
										  log:info("using cached: ", url)
										  self:showBackground(url, self.currentPlayerId)
									  else
										  self:_fetchFile(url, 
														  function(set) 
															  if set then
																  self:setBackground(url, self.currentPlayerId)
															  else
																  self:showBackground(url, self.currentPlayerId)
															  end
														  end )
									  end
								  end
				}
			)
			if wallpaper == url then
				self.menu:setSelectedIndex(self.menu:numItems() - 1)
			end
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


function _fetchFile(self, url, callback)
	self.last = url

	if self.download[url] then
		log:warn("already fetching ", url, " not fetching again")
		return
	else
		log:info("fetching background: ", url)
	end
	self.download[url] = "fetch"

	-- FIXME
	-- need something here to contrain size of self.download

	local req = RequestHttp(
		function(chunk, err)
			if err then
				log:error("error fetching background: ", url)
				self.download[url] = nil
			end
			local state = self.download[url]
			if chunk and (state == "fetch" or state == "fetchset") then
				log:info("fetched background: ", url)
				self.download[url] = chunk
				if url == self.last then
					callback(state == "fetchset")
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

	local srf
	if self.download[wallpaper] then
		-- image in download cache
		if self.download[wallpaper] ~= "fetch" and self.download[url] ~= "fetchset" then
			local data = self.download[wallpaper]
			srf = Tile:loadImageData(data, #data)
		end
	elseif string.match(wallpaper, "http://(.*)") then
		-- saved remote image for this player
		srf = Tile:loadImage(downloadPrefix .. playerId:gsub(":", "-"))
	else
		-- try firmware wallpaper
		srf = Tile:loadImage(firmwarePrefix .. wallpaper)
	end
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

		if self.download[wallpaper] then
			if self.download[wallpaper] == "fetch" then
				self.download[wallpaper] = "fetchset"
				return
			end
			local path = downloadPrefix .. playerId:gsub(":", "-")
			local fh = io.open(path, "wb")
			if fh then
				log:info("saving image to ", path)
				fh:write(self.download[wallpaper])
				fh:close()
			else
				log:warn("unable to same image to ", path)
			end
		end

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

