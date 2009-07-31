
local unpack, tonumber, tostring = unpack, tonumber, tostring

-- board specific driver
local bsp                    = require("baby_bsp")

local oo                     = require("loop.simple")
local os                     = require("os")
local io                     = require("io")
local string                 = require("jive.utils.string")
local table                  = require("jive.utils.table")
local math                   = require("math")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")

local Networking             = require("jive.net.Networking")

local Framework              = require("jive.ui.Framework")
local Group                  = require("jive.ui.Group")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local Task                   = require("jive.ui.Task")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Slider                 = require("jive.ui.Slider")
local Window                 = require("jive.ui.Window")

local debug                  = require("jive.utils.debug")


local jnt                    = jnt
local iconbar                = iconbar
local jiveMain               = jiveMain
local appletManager          = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	local uuid, mac, serial
	
	-- read device uuid
	local f = io.open("/proc/cpuinfo")
	if f then
		for line in f:lines() do
			if string.match(line, "UUID") then
				uuid = string.match(line, "UUID%s+:%s+([%x-]+)")
				uuid = string.gsub(uuid, "[^%x]", "")
			end

			if string.match(line, "Serial") then
				serial = string.match(line, "Serial%s+:%s+([%x-]+)")
				self._serial = string.gsub(serial, "[^%x]", "")
			end
		end
		f:close()
	end

	if not self._serial then
		log:warn("Serial not found")
	end

	System:init({
		uuid = uuid,
		machine = "baby",
	})

	mac = System:getMacAddress()
	uuid = System:getUUID()

	if not uuid or string.match(mac, "^00:40:20") 
		or uuid == "00000000-0000-0000-0000-000000000000"
		or mac == "00:04:20:ff:ff:01" then
		local window = Window("help_list", self:string("INVALID_MAC_TITLE"))

		window:setAllowScreensaver(false)
		window:setAlwaysOnTop(true)
		window:setAutoHide(false)

		local text = Textarea("help_text", self:string("INVALID_MAC_TEXT"))
		local menu = SimpleMenu("menu", {
			{
				text = self:string("INVALID_MAC_CONTINUE"),
				sound = "WINDOWHIDE",
				callback = function()
						   window:hide()
					   end
			},
		})

		window:addWidget(text)
		window:addWidget(menu)
		window:show()
	end

	-- status bar updates
	self:update()
	iconbar.iconWireless:addTimer(5000, function()  -- every 5 seconds
	      self:update()
	end)

	Framework:addActionListener("soft_reset", self, _softResetAction, true)

        Framework:addActionListener("shutdown", self, _shutdown)


	Framework:addListener(EVENT_SWITCH, function(event)
		local sw,val = event:getSwitch()

		if sw == 1 then
			-- headphone
			self:_headphoneJack(val)
		end
	end)

--	self:_setupCrossover()

	self:_headphoneJack(bsp:getMixer("Headphone Switch"))
	-- find out when we connect to player
	jnt:subscribe(self)

	self:storeSettings()
end


--service method
function performHalfDuplexBugTest(self)
	return true
end


--service method
function getDefaultWallpaper(self)
	local wallpaper = "bb_encore.png" -- default, if none found examining serial
	if self._serial then
		local colorCode = self._serial:sub(11,12)

		if colorCode == "00" then
			log:debug("case is black")
			wallpaper = "bb_encore.png"
		elseif colorCode == "01" then
			log:debug("case is red")
			wallpaper = "bb_encore_red.png"
		else
			log:warn("No case color found (assuming black) examining serial: ", self._serial )
		end
	end

	return wallpaper
end

function _amixerCommand(self, name, ...)
	local value = table.concat({...}, ",")
	log:debug("amixer: ", name, " value: ", value)

--      uncomment to call os amixer command directly for debug comparison
--	log:warn("os command")
--	os.execute('amixer sset "' .. name .. '" ' .. value)

	bsp:setMixer(name, ...)
end

function _setupCrossover(self)
	log:info("_setupCrossover")

	self:_amixerCommand("Audio Codec Digital Filter Control" , "0")
	self:_amixerCommand("Audio Effects Filter N0 Coefficient", "22555", "65072")
	self:_amixerCommand("Audio Effects Filter N1 Coefficient", "42981", "65072")
	self:_amixerCommand("Audio Effects Filter N2 Coefficient", "22555", "65072")
	self:_amixerCommand("Audio Effects Filter N3 Coefficient", "32767", "32767")
	self:_amixerCommand("Audio Effects Filter N3 Coefficient", "32767", "32767")
	self:_amixerCommand("Audio Effects Filter N3 Coefficient", "32767", "32767")
	self:_amixerCommand("Audio Effects Filter N3 Coefficient", "32767", "32767")
	self:_amixerCommand("Audio Effects Filter N4 Coefficient", "0", "0")
	self:_amixerCommand("Audio Effects Filter N5 Coefficient", "0", "0")
	self:_amixerCommand("Audio Effects Filter D1 Coefficient", "24546", "24546")
	self:_amixerCommand("Audio Effects Filter D1 Coefficient", "24546", "24546")
	self:_amixerCommand("Audio Effects Filter D1 Coefficient", "24546", "24546")
	self:_amixerCommand("Audio Effects Filter D1 Coefficient", "24546", "24546")
	self:_amixerCommand("Audio Effects Filter D1 Coefficient", "24546", "24546")
	self:_amixerCommand("Audio Effects Filter D1 Coefficient", "24546", "24546")
	self:_amixerCommand("Audio Effects Filter D1 Coefficient", "24546", "24546")
	self:_amixerCommand("Audio Effects Filter D2 Coefficient", "47149", "47149")
	self:_amixerCommand("Audio Effects Filter D4 Coefficient", "0", "0")
	self:_amixerCommand("Audio Effects Filter D5 Coefficient", "0", "0")
end


function _enableCrossover(self)
	log:info("_enableCrossover")
	self:_amixerCommand("Audio Codec Digital Filter Control" , "10")
end

function _disableCrossover(self)
	log:info("_enableCrossover")
	self:_amixerCommand("Audio Codec Digital Filter Control" , "0")
end

function _headphoneJack(self, val)
	if val == 0 then
--		self:_enableCrossover()
		bsp:setMixer("Endpoint", "Speaker")
	else
		bsp:setMixer("Endpoint", "Headphone")
--		self:_disableCrossover()
	end
end


function _softResetAction(self, event)
	jiveMain:goHome()
end


function notify_playerCurrent(self, player)
	-- if not passed a player, or if player hasn't change, exit
	if not player or not player:isConnected() then
		return
	end

	if self.player == player then
		return
	end
	self.player = player

	local sink = function(chunk, err)
		if err then
			log:warn(err)
			return
		end
		log:debug('date sync: ', chunk.data.date)
                self:setDate(chunk.data.date)
 	end
 
	-- setup a once/hour
        player:subscribe(
		'/slim/datestatus/' .. player:getId(),
		sink,
		player:getId(),
		{ 'date', 'subscribe:3600' }
	)
end


function notify_playerDelete(self, player)
	if self.player ~= player then
		return
	end
	self.player = false

	log:debug('unsubscribing from datestatus/', player:getId())
	player:unsubscribe('/slim/datestatus/' .. player:getId())
end


function setDate(self, date)
	-- matches date format 2007-09-08T20:40:42+00:00
	local CCYY, MM, DD, hh, mm, ss, TZ = string.match(date, "(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)([-+]%d%d:%d%d)")

	log:debug("CCYY=", CCYY, " MM=", MM, " DD=", DD, " hh=", hh, " mm=", mm, " ss=", ss, " TZ=", TZ)

	-- set system date
	os.execute("/bin/date " .. MM..DD..hh..mm..CCYY.."."..ss)

	iconbar:update()
end


function update(self)
	 Task("statusbar", self, _updateTask):addTask()
end


function _updateTask(self)
	-- FIXME ac power / battery

	local iface = Networking:activeInterface()

	if not iface then
		iconbar:setWirelessSignal(nil)
	else	
		if iface:isWireless() then
			-- wireless strength
			local quality = iface:getLinkQuality()
			iconbar:setWirelessSignal(quality ~= nil and quality or "ERROR")
		else
			-- wired
			local status = iface:t_wpaStatus()
			iconbar:setWirelessSignal(not status.link and "ERROR" or nil)
		end
	end
end


function getBrightness (self)
	local f = io.open("/sys/class/backlight/mxc_lcdc_bl.0/brightness", "r")
	local level = f:read("*a")
	f:close()

	return tonumber(level / 4)
end


function setBrightness (self, level)
	-- FIXME a quick hack to prevent the display from dimming
	if level == "off" then
		level = 0
	elseif level == "on" then
		level = 32
	elseif level == nil then
		return
	end

	local f = io.open("/sys/class/backlight/mxc_lcdc_bl.0/brightness", "w")
	f:write(tostring(level * 4))
	f:close()
end


function settingsBrightnessShow (self, menuItem)
	local window = Window("text_list", menuItem.text, squeezeboxjiveTitleStyle)

	local settings = self:getSettings()
	local level = settings.brightness

	local slider = Slider("slider", 1, 64, level,
			      function(slider, value, done)
				      settings.brightness = value

			              local bright = settings.brightness
			              if bright > 64 then
			                bright = 64
			              end
			              self:setBrightness( bright)

				      if done then
					      window:playSound("WINDOWSHOW")
					      window:hide(Window.transitionPushLeft)
				      end
			      end)

	window:addWidget(Textarea("help_text", self:string("BSP_BRIGHTNESS_ADJUST_HELP")))
	window:addWidget(Group("sliderGroup", {
	       min = Icon("button_slider_min"),
	       slider = slider,
	       max = Icon("button_slider_max"),
	}))

	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
		end
	)

	window:show()
	return window
end


function _shutdown(self)
	log:info("Shuting down ...")

	-- disconnect from SqueezeCenter
	appletManager:callService("disconnectPlayer")

	local popup = Popup("waiting_popup")

	popup:addWidget(Icon("icon_restart"))
	popup:addWidget(Label("subtext", self:string("GOODBYE")))

	-- make sure this popup remains on screen
	popup:setAllowScreensaver(false)
	popup:setAlwaysOnTop(true)
	popup:setAutoHide(false)
	popup:ignoreAllInputExcept({})

	popup:show()

	popup:playSound("SHUTDOWN")	

	local timer = Timer(3500, function()
		os.execute("/sbin/poweroff")
	end)
	timer:start()
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
