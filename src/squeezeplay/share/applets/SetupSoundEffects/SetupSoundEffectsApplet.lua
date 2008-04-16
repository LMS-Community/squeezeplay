
--[[
=head1 NAME

applets.SetupSoundEffects.SetupSoundEffectsApplet - An applet to control Jive sound effects.

=head1 DESCRIPTION

This applets lets the user setup what sound effects are played.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
SetupSoundEffectsApplet overrides the following methods:

=cut
--]]


-- stuff we use
local ipairs, pairs, tostring = ipairs, pairs, tostring

local table           = require("table")

local oo              = require("loop.simple")
local os              = require("os")
local io              = require("io")
local lfs             = require("lfs")

local AppletManager   = require("jive.AppletManager")
local Applet          = require("jive.Applet")
local Audio           = require("jive.ui.Audio")
local Checkbox        = require("jive.ui.Checkbox")
local RadioButton     = require("jive.ui.RadioButton")
local RadioGroup      = require("jive.ui.RadioGroup")
local Framework       = require("jive.ui.Framework")
local SimpleMenu      = require("jive.ui.SimpleMenu")
local Window          = require("jive.ui.Window")
local Icon            = require("jive.ui.Icon")
local Group           = require("jive.ui.Group")
local Slider          = require("jive.ui.Slider")
local Textarea        = require("jive.ui.Textarea")
local jul             = require("jive.utils.log")

local RequestHttp     = require("jive.net.RequestHttp")
local SocketHttp      = require("jive.net.SocketHttp")

local log             = jul.logger("applets.setup")

local jnt             = jnt

local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP
local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_UNUSED           = jive.ui.EVENT_UNUSED

local KEY_VOLUME_UP          = jive.ui.KEY_VOLUME_UP
local KEY_VOLUME_DOWN        = jive.ui.KEY_VOLUME_DOWN


module(...)
oo.class(_M, Applet)


local PATH = "applets/DefaultSkin/sounds/"

local REFRESH_TIME = 300

local sounds = {
	BUMP       = { default = "bump.wav",      chan = 1 },
	CLICK      = { default = "click.wav",     chan = 0 },
	JUMP       = { default = "jump.wav",      chan = 0 },
	WINDOWSHOW = { default = "pushleft.wav",  chan = 1 },
	WINDOWHIDE = { default = "pushright.wav", chan = 1 },
	SELECT     = { default = "select.wav",    chan = 0 },
	PLAYBACK   = { default = "select.wav",    chan = 0 },
	DOCKING    = { default = "docking.wav",   chan = 1 },
	STARTUP    = { default = "splash.wav",    chan = 1 },
	SHUTDOWN   = { default = "shutdown.wav",  chan = 1 }
}

local groups = {
	SOUND_NAVIGATION = {
		"WINDOWSHOW",
		"WINDOWHIDE",
		"BUMP",
		"JUMP",
		"SELECT"
	},
	SOUND_SCROLL = {
		"CLICK"
	},
	SOUND_PLAYBACK = {
		"PLAYBACK"
	},
	SOUND_CHARGING = {
		"DOCKING"
	},
	SOUND_NONE = {
		"STARTUP",
		"SHUTDOWN"
	},
}


-- logSettings
-- returns a window with Choices to set the level of each log category
-- the log category are discovered
function settingsShow(self, menuItem)

	local settings = self:getSettings()

	local window = Window("window", menuItem.text, 'settingstitle')
	local menu = SimpleMenu("menu")
	menu:setComparator(menu.itemComparatorWeightAlpha)

	local allButtons = {}

	-- off switch
	local offButton = Checkbox("checkbox", 
				   function(obj, isSelected)
					   local notSelected = not isSelected

					   for b,v in pairs(allButtons) do
						   b:setSelected(notSelected)
						   for i,snd in ipairs(v) do
							   settings[snd] = notSelected
							   Framework:enableSound(snd, notSelected)
						   end
					   end
				   end,
				   false
			   )

	menu:addItem({
			     text = self:string("SOUND_NONE"),
			     icon = offButton,
			     weight = 1
		     })


	-- add sounds
	local effectsEnabled = false
	for k,v in pairs(groups) do
		local soundEnabled = Framework:isSoundEnabled(v[1])
		effectsEnabled = effectsEnabled or soundEnabled

		local button = Checkbox(
			"checkbox", 
			function(obj, isSelected)
				for i,snd in ipairs(v) do
					settings[snd] = isSelected
					Framework:enableSound(snd, isSelected)
				end

				if isSelected then
					offButton:setSelected(false)
				end

				-- turn on off switch?
				local s = false
				for b,_ in pairs(allButtons) do
					s = s or b:isSelected()
				end
				
				if s == false then
					offButton:setSelected(true)
				end
			end,
			soundEnabled
		)

		allButtons[button] = v

		if k ~= "SOUND_NONE" then
			-- insert suitable entry for Choice menu
			menu:addItem({
					     text = self:string(k),
					     icon = button,
					     weight = 10
				     })
		end
	end

	offButton:setSelected(not effectsEnabled)

	-- volume
	menu:addItem({
			     text = self:string("SOUND_VOLUME"),
			     sound = "WINDOWSHOW",
			     weight = 20,
			     callback = function()
						self:volumeShow()
					end
		     })


	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
		end
	)

	window:addWidget(menu)

	self.menu = menu
	self.server = self:_getCurrentServer()

	-- look for any server based sounds
	if self.server then
		log:info("found server - requesting sounds list")
		self.server.comet:request(
			function(chunk, err)
				if err then
					log:debug(err)
				elseif chunk then
					self:_serverSink(chunk.data)
				end
			end,
			false,
			{ "jivesounds" }
		)
	elseif self:getSettings()["_CUSTOM"] then
		self:_customMenu({})
	end

	self:tieAndShowWindow(window)
	return window
end


local VOLUME_STEPS = 20
local VOLUME_STEP = Audio.MAXVOLUME / VOLUME_STEPS


function _setVolume(self, value)
	local settings = self:getSettings()

	Audio:setEffectVolume(value * VOLUME_STEP)

	self.slider:setValue(value)
	self.slider:playSound("CLICK")

	settings["_VOLUME"] = value * VOLUME_STEP
end


function volumeShow(self)
	local window = Window("window", self:string("SOUND_EFFECTS_VOLUME"), "settingstitle")

	self.slider = Slider("volume", 0, VOLUME_STEPS, Audio:getEffectVolume() / VOLUME_STEP,
			     function(slider, value)
				     self:_setVolume(value)
			     end)

	self.slider:addListener(EVENT_KEY_PRESS,
				function(event)
					local code = event:getKeycode()
					if code == KEY_VOLUME_UP then
						self:_setVolume(self.slider:getValue() + 1)
						return EVENT_CONSUME
					elseif code == KEY_VOLUME_DOWN then
						self:_setVolume(self.slider:getValue() - 1)
						return EVENT_CONSUME
					end
					return EVENT_UNUSED
				end)

	window:addWidget(Textarea("help", self:string("SOUND_VOLUME_HELP")))
	window:addWidget(Group("volumeGroup", {
				     Icon("volumeMin"),
				     self.slider,
				     Icon("volumeMax")
			     }))

	self:tieAndShowWindow(window)
	return window
end


function _getCurrentServer(self)
	local manager = AppletManager:getAppletInstance("SlimDiscovery")
	local server
	if manager and manager:getCurrentPlayer() then
		server = manager:getCurrentPlayer():getSlimServer()
		if server:isSqueezeNetwork() then
			server = nil
		end
	end
	return server
end


function _serverSink(self, data)
	local custom = {}
	if data.item_loop then
		for _,entry in pairs(data.item_loop) do
			log:info("server sounds: ", entry.name)
			custom[entry.name] = entry
		end
		self:_customMenu(custom)
	elseif self:getSettings()["_CUSTOM"] then
		self:_customMenu({})
	end
end


function _customMenu(self, custom)
	self.menu:addItem({
		text = self:string("SOUND_CUSTOMIZE"),
		weight = 100,
		callback = function(event, item)
 					   local window = Window("window", item.text)
					   local menu = SimpleMenu("menu")
					   menu:setComparator(menu.itemComparatorAlpha)
					   window:addWidget(Textarea("help", self:string("SOUND_CUSTOM_HELP")))
					   window:addWidget(menu)
					   for k,v in pairs(sounds) do
						   menu:addItem({
											text = self:string("SOUND_" .. k),
											callback = function() self:_customSoundMenu(k, custom) end
										})
					   end
					   window:show()
				   end
	})
end


function _customSoundMenu(self, sound, custom)
	local window = Window("window", self:string("SOUND_" .. sound))
	local menu = SimpleMenu("menu")
	local group = RadioGroup()
	menu:setComparator(menu.itemComparatorWeightAlpha)
	window:addWidget(Textarea("help", self:string("SOUND_CUSTOMSOUND_HELP")))
	window:addWidget(menu)

	local settings = self:getSettings()

	menu:addItem({
		weight = 1,
		text = self:string("SOUND_DEFAULT"),
		icon = RadioButton("radio",
						   group,
						   function()
							   log:info("setting default as active sound for ", sound)
							   self:_setCustom(sound, nil)
							   Framework:playSound(sound)
						   end,
						   settings["_CUSTOM"] == nil or settings["_CUSTOM"][sound] == nil
		)
	})

	for _,v in pairs(custom) do
		menu:addItem({
			weight = 10,
			text = v.name,
			icon = RadioButton("radio",
							   group,
							   function()
								   local path = Framework:findFile(PATH) .. v.file
								   local attr = lfs.attributes(path)
								   if attr then
									   log:info("setting ", v.file, " as active sound for ", sound)
									   self:_setCustom(sound, v.file)
									   Framework:playSound(sound)
								   end
							   end,
							   settings["_CUSTOM"] ~= nil and settings["_CUSTOM"][sound] == v.file
						   ),
			focusGained = function()
							  local path = Framework:findFile(PATH) .. v.file
							  local attr = lfs.attributes(path)
							  if attr and os.time() - attr.modification < REFRESH_TIME then
								  log:info("using local copy of: ", v.file)
							  else
								  log:info("fetching: ", v.file)
								  self:_fetchFile(v.url, path, function() end)
							  end
						  end
		})
	end

	window:show()
end


function _setCustom(self, sound, file)
	local settings = self:getSettings()

	if settings["_CUSTOM"] == nil then
		settings["_CUSTOM"] = {}
	end
	settings["_CUSTOM"][sound] = file

	local cust = 0
	for k,_ in pairs(settings["_CUSTOM"]) do
		cust = cust + 1
	end
	if cust == 0 then
		settings["_CUSTOM"] = nil
	end
	
	self:_loadSounds(sound)
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


function _loadSounds(self, sound)
	local settings = self:getSettings()

	for k,v in pairs(sounds) do
		if sound == nil or sound == k then
			local file = settings["_CUSTOM"] and settings["_CUSTOM"][k] or sounds[k]["default"]
			Framework:loadSound(k, PATH .. file, sounds[k]["chan"])

			local enabled = settings[k]
			if enabled == nil then
				enabled = true
			end
			Framework:enableSound(k, enabled)
		end
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

