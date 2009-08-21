
local pcall, unpack, tonumber, tostring = pcall, unpack, tonumber, tostring

-- board specific driver
local bsp                    = require("baby_bsp")

local oo                     = require("loop.simple")
local os                     = require("os")
local io                     = require("io")
local string                 = require("jive.utils.string")
local table                  = require("jive.utils.table")
local math                   = require("math")

local Applet                 = require("jive.Applet")
local Decode                 = require("squeezeplay.decode")
local System                 = require("jive.System")

local Networking             = require("jive.net.Networking")

local Player                 = require("jive.slim.Player")
local LocalPlayer            = require("jive.slim.LocalPlayer")

local Checkbox               = require("jive.ui.Checkbox")
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
local RadioGroup             = require("jive.ui.RadioGroup")
local RadioButton            = require("jive.ui.RadioButton")

local debug                  = require("jive.utils.debug")


local jnt                    = jnt
local iconbar                = iconbar
local jiveMain               = jiveMain
local appletManager          = appletManager

local brightnessTable        = {}

module(..., Framework.constants)
oo.class(_M, Applet)


local function _sysOpen(self, path, attr, mode)
	if not mode or string.match(mode, "r") then
		local fh = io.open(path .. attr, "r")
		if not fh then
			log:warn("Can't open (read) ", path, attr)
			return
		end

		self["sysr_" .. attr] = fh
	end

	if mode and string.match(mode, "w") then
		local fh = io.open(path .. attr, "w")
		if not fh then
			log:warn("Can't open (read) ", path, attr)
			return
		end

		self["sysw_" .. attr] = fh
	end
end


local function _sysReadNumber(self, attr)
	local fh = self["sysr_" .. attr]
	if not fh then
		return -1
	end

	fh:seek("set")
	return tonumber(fh:read("*a"))
end


local function _sysWrite(self, attr, val)
	local fh = self["sysw_" .. attr]
	if not fh then
		return -1
	end

	fh:write(val)
	fh:flush(val)
end

local brightnessTimer = nil

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

			if string.match(line, "Revision") then
				self._revision = tonumber(string.match(line, ".+:%s+([^%s]+)"))
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

	local settings = self:getSettings()

	-- sys interface
	_sysOpen(self, "/sys/class/backlight/mxc_lcdc_bl.0/", "brightness", "rw")
	_sysOpen(self, "/sys/class/backlight/mxc_lcdc_bl.0/", "bl_power", "rw")
	_sysOpen(self, "/sys/bus/i2c/devices/1-0010/", "ambient")
	_sysOpen(self, "/sys/devices/platform/i2c-adapter:i2c-1/1-0010/", "wall_voltage")
	_sysOpen(self, "/sys/devices/platform/i2c-adapter:i2c-1/1-0010/", "battery_charge")
	_sysOpen(self, "/sys/devices/platform/i2c-adapter:i2c-1/1-0010/", "battery_capacity")

	-- register wakeup/sleep functions
	Framework:registerWakeup(function() wakeup(self) end)
	Framework:addListener(EVENT_ALL_INPUT,
		function(event)
			Framework.wakeup()
		end, true)

	self.powerTimer = Timer(settings.initTimeout,
		function() sleep(self) end)

	-- initial power settings
	self:_initBrightnessTable()
	if settings.brightness > #brightnessTable then
		settings.brightness = #brightnessTable
	end
	self.lcdBrightness = settings.brightness
	self:setPowerState("active")

	self:initBrightness()
	brightnessTimer = Timer( 2000,
		function()
			if settings.brightnessControl != "manual" then
				self:doAutomaticBrightnessTimer()
			end
		end)
	brightnessTimer:start()	
	
	-- status bar updates
	self:update()
	iconbar.iconWireless:addTimer(2000, function()  -- every two seconds
	      self:update()
	end)

	Framework:addActionListener("soft_reset", self, _softResetAction, true)

        Framework:addActionListener("shutdown", self, _shutdown)


	Framework:addListener(EVENT_SWITCH, function(event)
		local sw,val = event:getSwitch()

		if sw == 1 then
			-- headphone
			self:_headphoneJack(val)

		elseif sw == 2 then
			-- headphone
			self:_lineinJack(val == 1)
		end
	end)

	-- open audio device
	local isHeadphone = (bsp:getMixer("Headphone Switch") > 0)
	if isHeadphone then
		-- set endpoint before the device is opened
		bsp:setMixer("Endpoint", "Headphone")
	end

	Decode:open(settings)

	if isHeadphone then
		-- disable crossover after the device is opened
		bsp:setMixer("Crossover", false)
	end

	-- find out when we connect to player
	jnt:subscribe(self)

	self:storeSettings()


	-- XXXX for testing only
	if bsp:getMixer("Line In Switch") then
		self:_lineinJack(true)
	end
end

local MAX_BRIGHTNESS_LEVEL = -1
local STATIC_AMBIENT_MIN = -1

-- Maximum number of brightness levels up/down per run of the timer
local AMBIENT_RAMPSTEPS = -1

local wasDimmed = false
local brightCur = -1

function initBrightness(self) 
	-- Static Variables
	MAX_BRIGHTNESS_LEVEL = #brightnessTable
	STATIC_AMBIENT_MIN = 10000
	AMBIENT_RAMPSTEPS = 4
	
	-- Init some values to a default value
	brightCur = MAX_BRIGHTNESS_LEVEL
end

function doBrightnessRamping(self, target)
	local diff = 0
	diff = (target - brightCur)
	log:warn("ramp: target(" .. target .. "), brightCur(" .. brightCur ..")")	
	--log:info("Diff: " .. diff)

	if math.abs(diff) > AMBIENT_RAMPSTEPS then
		diff = AMBIENT_RAMPSTEPS
			
		-- is there an easier solution for this?
		if brightCur > target then
			diff = diff * -1.0
		end
	end
		
	brightCur = brightCur + diff	

	if brightCur > MAX_BRIGHTNESS_LEVEL then
		brightCur = MAX_BRIGHTNESS_LEVEL
	elseif brightCur < 1 then
		brightCur = 1	
	end
	
end

function doAutomaticBrightnessTimer(self)

	-- As long as the power state is active don't do anything
	if self.powerState ==  "active" then
		if wasDimmed == true then
			log:info("SWITCHED TO ACTIVE")
			-- set brightness so that the active power state removes the 60% dimming
			self:setBrightness( brightCur )
			wasDimmed = false
		end
		return
	else 
		wasDimmed = true
	end

	local settings = self:getSettings()	
	
	-- Now continue with the real ambient code 
	local ambient = _sysReadNumber(self, "ambient")
	
	--[[
	log:info("Ambient:      " .. tostring(ambient))
	log:info("MaxBright:    " .. tostring(MAX_BRIGHTNESS_LEVEL))
	log:info("Brightness:   " .. tostring(settings.brightness))
	]]--
	
	-- switch around ambient value
	ambient = STATIC_AMBIENT_MIN - ambient
	if ambient < 0 then
		ambient = 0
	end
	--log:info("AmbientFixed: " .. tostring(ambient))
	
	
	local brightTarget = (MAX_BRIGHTNESS_LEVEL / STATIC_AMBIENT_MIN) * ambient
	
	self:doBrightnessRamping(brightTarget);
	
	-- Set Brightness
	self:setBrightness( brightCur )
	
	--log:info("CurTarMax:    " .. tostring(brightCur) .. " - ".. tostring(brightTarget))

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
			wallpaper = "bb_encorered.png"
		else
			log:warn("No case color found (assuming black) examining serial: ", self._serial )
		end
	end

	return wallpaper
end


function _headphoneJack(self, val)
	if val == 0 then
		bsp:setMixer("Crossover", true)
		bsp:setMixer("Endpoint", "Speaker")
	else
		bsp:setMixer("Endpoint", "Headphone")
		bsp:setMixer("Crossover", false)
	end
end


function _lineinJack(self, val)
	if val then
		jiveMain:addItem({
			id = "linein",
			node = "home",
			text = "Line-In",
			style = 'item_choice',
			check = Checkbox("checkbox", function(_, checked)
				-- XXXX stop track playback
				Decode:capture(checked)
			end),
			weight = 50,
		})
	else
		jiveMain:removeItemById("linein")
		Decode:capture(false)
	end
end


function _softResetAction(self, event)
	LocalPlayer:disconnectServerAndPreserveLocalPlayer()
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

	-- set RTC to system time
	os.execute("hwclock -w")

	iconbar:update()
end


function update(self)
	 Task("statusbar", self, _updateTask):addTask()
end


local function _updateWireless(self)
	local iface = Networking:activeInterface()
	local player = Player:getLocalPlayer()

	if not iface then
		iconbar:setWirelessSignal(nil)
	else	
		if iface:isWireless() then
			-- wireless strength
			local quality, strength = iface:getLinkQuality()
			iconbar:setWirelessSignal(quality ~= nil and quality or "ERROR")

			if player then
				player:setSignalStrength(strength)
			end
		else
			-- wired
			local status = iface:t_wpaStatus()
			iconbar:setWirelessSignal(not status.link and "ERROR" or nil)

			if player then
				player:setSignalStrength(nil)
			end
		end
	end
end


local function _updatePower(self)
	local wallVoltage = _sysReadNumber(self, "wall_voltage")
	local batteryCharge = _sysReadNumber(self, "battery_charge")
	local batteryCapacity = _sysReadNumber(self, "battery_capacity")

	log:debug("wallVoltage=", wallVoltage,
		" batteryCharge=", batteryCharge,
		" batteryCapacity=", batteryCapacity)

	if batteryCharge == 0 then
		-- no battery
		log:debug("no battery")
		iconbar:setBattery(nil)

	elseif wallVoltage > 16000 then    -- FIXME 16000 is just a guess
		if batteryCharge == batteryCapacity then
			log:debug("on ac, fully charged")
			iconbar:setBattery("AC")

		else
			log:debug("on ac, charging")
			iconbar:setBattery("CHARGING")

		end
	else
		local batteryRemain = (batteryCharge / batteryCapacity) * 100
		log:debug("on battery power ", batteryRemain, "%")

		iconbar:setBattery(math.max(math.floor(batteryRemain / 25) + 1, 4))
	end
end


function sleep(self)
	self:setPowerState("dimmed")
end


function wakeup(self)
	self:setPowerState("active")
end


function setPowerState(self, state)
	local settings = self:getSettings()

	if state == "active" then
		self.powerTimer:restart(settings.dimmedTimeout)

	elseif state == "dimmed" then
		self.powerTimer:stop()

	end

	if self.powerState == state then
		return
	end

	self.powerState = state

	_setBrightness(self, self.lcdBrightness)
end

function _updateTask(self)
	-- FIXME ac power / battery

	_updatePower(self)
	_updateWireless(self)
end


function _initBrightnessTable( self)
	local pwm_steps = 256
	local brightness_step_percent = 10
	local k = 1

	if self._revision >= 3 then
		-- Brightness table for PB3 and newer
		-- First parameter can be 1 to achieve very low brightness
		brightnessTable[k] = {1, 1}
		for step = 1, pwm_steps, 1 do
			if 100 * ( step - brightnessTable[k][2]) / brightnessTable[k][2] >= brightness_step_percent then
				k = k + 1
				brightnessTable[k] = {1, step}
			end
		end
		k = k + 1
		brightnessTable[k] = {0, 33}
		for step = 33, pwm_steps, 1 do
			if 100 * ( step - brightnessTable[k][2]) / brightnessTable[k][2] >= brightness_step_percent then
				k = k + 1
				brightnessTable[k] = {0, step}
			end
		end
	else
		-- Brightness table for PB1 and PB2
		-- First parameter need to be 0 at all times, else brightness is really dark
		brightnessTable[k] = {0, 1}
		for step = 1, pwm_steps, 1 do
			if 100 * ( step - brightnessTable[k][2]) / brightnessTable[k][2] >= brightness_step_percent then
				k = k + 1
				brightnessTable[k] = {0, step}
			end
		end
	end

-- This is debugging stuff, Caleb, isn't it?
--	local a
--	for k = 1, #brightnessTable, 1 do
--		a = brightnessTable[k][1]
--		a = brightnessTable[k][2]
--	end
end


function _setBrightness(self, level)
	self.lcdBrightness = level
	-- 60% brightness in dimmed power mode
	if self.powerState == "dimmed" then
		level = level - 10
	end
	brightness = brightnessTable[level][2]
	bl_power   = brightnessTable[level][1]
		
	_sysWrite(self, "brightness", brightness)
	_sysWrite(self, "bl_power",   bl_power)
end


function getBrightness (self)
	return self.lcdBrightness
end


function setBrightness (self, level)
	-- FIXME a quick hack to prevent the display from dimming
	if level == "off" then
		level = 0
	elseif level == "on" then
		level = 70
	elseif level == nil then
		return
	end

	_setBrightness(self, level)
end


function settingsBrightnessShow (self, menuItem)
	local window = Window("text_list", menuItem.text, squeezeboxjiveTitleStyle)

	local settings = self:getSettings()
	local level = settings.brightness

	local slider = Slider("slider", 1, #brightnessTable, level,
		function(slider, value, done)
			settings.brightness = value
			
			-- If the user modifies the slider - automatically switch to manaul brightness
			settings.brightnessControl = "manual"
			
			local bright = value

			self:setBrightness(bright)

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

function settingsBrightnessControlShow(self, menuItem)
	local window = Window("text_list", self:string("BSP_BRIGHTNESS_CTRL"), squeezeboxjiveTitleStyle)
	local settings = self:getSettings()

	local group = RadioGroup()
	--log:info("Setting: " .. settings.brightnessControl)
	local menu = SimpleMenu("menu", {
		{
			text = self:string("BSP_BRIGHTNESS_AUTOMATIC"),
			style = "item_choice",
			check = RadioButton("radio", group, function(event, menuItem)
						settings.brightnessControl = "automatic"
					end,
					settings.brightnessControl == "automatic")
		},	
		{
			text = self:string("BSP_BRIGHTNESS_MANUAL"),
			style = "item_choice",
			check = RadioButton("radio", group, function(event, menuItem)
						settings.brightnessControl = "manual"
						self:setBrightness(settings.brightness)
					end,
					settings.brightnessControl == "manual")
		}
	})
	
	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
		end
	)

	window:addWidget(menu)
	self:tieAndShowWindow(window)

end


function _shutdown(self)
	log:info("Shuting down ...")

	-- disconnect from SqueezeCenter
	appletManager:callService("disconnectPlayer")

	local popup = Popup("waiting_popup")

	popup:addWidget(Icon("icon_restart"))
	popup:addWidget(Label("text", self:string("GOODBYE")))

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
