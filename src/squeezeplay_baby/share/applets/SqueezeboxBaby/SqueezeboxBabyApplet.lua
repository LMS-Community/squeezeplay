
local pcall, unpack, tonumber, tostring = pcall, unpack, tonumber, tostring

-- board specific driver
local bsp                    = require("baby_bsp")

local oo                     = require("loop.simple")
local os                     = require("os")
local io                     = require("io")
local string                 = require("jive.utils.string")
local table                  = require("jive.utils.table")
local math                   = require("math")
local squeezeos              = require("squeezeos_bsp")

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
local Event                  = require("jive.ui.Event")
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

local SqueezeboxApplet       = require("applets.Squeezebox.SqueezeboxApplet")

local EVENT_IR_DOWN          = jive.ui.EVENT_IR_DOWN
local EVENT_IR_REPEAT        = jive.ui.EVENT_IR_REPEAT

local jnt                    = jnt
local iconbar                = iconbar
local jiveMain               = jiveMain
local appletManager          = appletManager

local settings               = nil
local brightnessTable        = {}

local UPDATE_WIRELESS        = 0x01
local UPDATE_POWER           = 0x02


module(..., Framework.constants)
oo.class(_M, SqueezeboxApplet)


--[[

Power states:

ACTIVE
  The user is interacting with the system, everything is on.

IDLE
  The user has stopped interating with the system, the lcd is dimmed.

SLEEP
  A low power mode, the power amp is off.

HIBERNATE
  Suspend to ram. Not currently supported on baby.


State transitions (with default times):

* -> ACTIVE
  Any user activity changes to the active state.

ACTIVE -> IDLE
  After 30 seconds of inactivity, player power is on

ACTIVE -> SLEEP
  After 30 seconds of inactivity, player power is off

IDLE -> SLEEP
  After 10 minutes of inactivity, when not playing

SLEEP -> HIBERNATE
  After 1 hour of inactivity

--]]



-----------------------------
-- Ambient Light Init Stuff
----------------------------- 

-- Maximum brightness will be initialized when the brightnessTable is calculated
local MAX_BRIGHTNESS_LEVEL = -1
-- Minium Brightness (as dark as it gets)
local MIN_BRIGHTNESS_LEVEL = 1
-- Minium Brightness after factory reset
local MIN_BRIGHTNESS_LEVEL_INIT = 20

-- Automatic brightness timer rate
local BRIGHTNESS_REFRESH_RATE = 100						-- was 500
local BRIGHTNESS_READ_RATE_DIVIDER = 5						-- This gives 2 times a seconds

-- Lux Value Smoothing
local MAX_SMOOTHING_VALUES = math.floor( 4000 / (BRIGHTNESS_REFRESH_RATE * BRIGHTNESS_READ_RATE_DIVIDER))	-- was 8
local luxSmooth = {}

-- Maximum number of brightness levels up/down per run of the timer
local AMBIENT_RAMPSTEPS = 4

local STATIC_AMBIENT_MIN_TOSHIBA = 90000
local STATIC_AMBIENT_MIN_LITEON	 =  5000
local staticAmbientMin = -1

local brightCur = -1
local brightTarget = -1
local brightMin = MIN_BRIGHTNESS_LEVEL_INIT
local brightLast = -1
local brightReadRateDivider = 1


function init(self)
	settings = self:getSettings()

	self.isLowBattery = false

	-- read uuid, serial and revision
	parseCpuInfo(self)

	System:init({
		machine = "baby",
		uuid = self._uuid,
		revision = self._revision,
	})

	System:setCapabilities({
		["ir"] = 1,
		["coreKeys"] = 1,
		["presetKeys"] = 1,
		["alarmKey"] = 1,
		["powerKey"] = 1,
		["muteKey"] = 1,
		["volumeKnob"] = 1,
		["audioByDefault"] = 1,
		["wiredNetworking"] = 1,
		["batteryCapable"] = 1,
	})

	-- warn if uuid or mac are invalid
	verifyMacUUID(self)

	if not self._serial then
		log:warn("Serial not found")
	end

	if self._revision < 1 then
		betaHardware(self, true) -- euthanize
	elseif self._revision < 3 then
		betaHardware(self, false) -- warning
	end

	-- sys interface
	sysOpen(self, "/sys/class/backlight/mxc_lcdc_bl.0/", "brightness", "rw")
	sysOpen(self, "/sys/class/backlight/mxc_lcdc_bl.0/", "bl_power", "rw")
	sysOpen(self, "/sys/bus/i2c/devices/1-0010/", "ambient")
	sysOpen(self, "/sys/devices/platform/i2c-adapter:i2c-1/1-0010/", "power_mode")
	sysOpen(self, "/sys/devices/platform/i2c-adapter:i2c-1/1-0010/", "battery_charge")
	sysOpen(self, "/sys/devices/platform/i2c-adapter:i2c-1/1-0010/", "battery_capacity")
	sysOpen(self, "/sys/devices/platform/i2c-adapter:i2c-1/1-0010/", "charger_state")
	sysOpen(self, "/sys/bus/i2c/devices/1-0010/", "alarm_time", "rw")

	-- register wakeup/sleep functions
	Framework:registerWakeup(function() wakeup(self) end)
	Framework:addListener(EVENT_ALL_INPUT,
		function(event)
			Framework.wakeup()
		end, true)

	self.powerTimer = Timer(settings.initTimeout,
		function() sleep(self) end)

	self:initBrightness()

	-- Needs stuff from brightness
	-- Needs to be after initBrightness()
	self:setPowerState("ACTIVE")

	local brightnessTimer = Timer( BRIGHTNESS_REFRESH_RATE,
		function()
			if settings.brightnessControl != "manual" then
				if not self:isScreenOff() then
					self:doAutomaticBrightnessTimer()
				end
			end
		end)
	brightnessTimer:start()

	-- status bar updates
	local updateTask = Task("statusbar", self, _updateTask)
	updateTask:addTask(UPDATE_WIRELESS | UPDATE_POWER)
	iconbar.iconWireless:addTimer(5000, function()  -- every five seconds
		updateTask:addTask(UPDATE_WIRELESS | UPDATE_POWER)
	end)

	Framework:addActionListener("soft_reset", self, _softResetAction, true)

        Framework:addActionListener("shutdown", self, function()
		appletManager:callService("setWakeupAlarm", 'none')
		appletManager:callService("poweroff")
	end)

	-- for testing:
	self.testLowBattery = false
	--Framework:addActionListener("start_demo", self, function()
	--	self.testLowBattery = not self.testLowBattery
	--	log:warn("battery low test ", self.testLowBattery)
	--end, true)

	Framework:addListener(EVENT_SWITCH, function(event)
		local sw,val = event:getSwitch()

		if sw == 1 then
			-- headphone
			self:_headphoneJack(val == 1)

		elseif sw == 2 then
			-- line in
			self:_lineinJack(val == 1, true)

		elseif sw == 3 then
			-- power event
			updateTask:addTask(UPDATE_POWER)
		end
	end)

	-- open audio device
	local isHeadphone = (bsp:getMixer("Headphone Switch") > 0)
	if isHeadphone then
		-- set endpoint before the device is opened
		bsp:setMixer("Endpoint", "Headphone")
	end

	Decode:open(settings)

	-- disable crossover after the device is opened
	self:_headphoneJack(isHeadphone)

	-- find out when we connect to player
	jnt:subscribe(self)

	local now = os.time()
	local alarmTime = sysReadNumber(self, "alarm_time")

	-- FIXME before 19 January 2038 (Y2K38)
	if (alarmTime > 0 and (alarmTime < now)) then
		log:info("supress splash sound, alarm wakeup")

		-- clear the alarm time, otherwise the system can't be
		-- powered down
		self:setWakeupAlarm('none')
	else
		playSplashSound(self)
	end
end

--called during the configure portion of applet initialization
function _configureInit(self)
	if self:isLineInConnected() then
		self:_lineinJack(true)
	end
end

--service method
function isLineInConnected(self)
	return bsp:getMixer("Line In Switch")
end

function overrideAudioEndpoint(self, override) -- 'Speaker' | 'Headphone' | nil => default
	self:_setEndpoint(override)
end

-----------------------------
-- Ambient Light Stuff Start
-----------------------------

function initBrightness(self)
	-- Do not change sequence
	-- - _initBrightnessTable()
	-- - set MAX_BRIGHTNESS_LEVEL
	-- - set settings.brightness
	-- - check settings.brightness max value

	-- Setup nonlinear brightness table
	self:_initBrightnessTable()

	-- Static Variables
	MAX_BRIGHTNESS_LEVEL = #brightnessTable

	-- Value of manual brightness slider
	settings.brightness = settings.brightness or MAX_BRIGHTNESS_LEVEL
	-- Value of minimal brightness (auto) slider
	settings.brightnessMinimal = settings.brightnessMinimal or (MIN_BRIGHTNESS_LEVEL_INIT)
	-- Value of brightness control
	settings.brightnessControl = settings.brightnessControl or "automatic"

	-- Make sure brightness is not set higher than we have table entries
	if settings.brightness > MAX_BRIGHTNESS_LEVEL then
		settings.brightness = MAX_BRIGHTNESS_LEVEL
		self:storeSettings()
	end

	-- Value of current LCD brightness
	self.lcdBrightness = settings.brightness

	-- Init some values to a default value
	brightCur = MAX_BRIGHTNESS_LEVEL
	brightTarget = MAX_BRIGHTNESS_LEVEL
	brightMin = settings.brightnessMinimal

	if self._revision >= 7 then
		-- LiteOn ambient light sensor
		staticAmbientMin = STATIC_AMBIENT_MIN_LITEON
	else
		-- Toshiba ambient light sensor
		staticAmbientMin = STATIC_AMBIENT_MIN_TOSHIBA
	end

	brightLast = MAX_BRIGHTNESS_LEVEL
	brightReadRateDivider = 1

	self.brightPrev = self:getBrightness()
	if self.brightPrev and self.brightPrev == 0 then
		--don't ever fallback to off
		self.brightPrev = MAX_BRIGHTNESS_LEVEL
	end

	-- Set Brightness after reboot
	self:setBrightness(settings.brightness)

	self:storeSettings()
end


function doBrightnessRamping(self, target)
	local diff = 0
	diff = (target - brightCur)
	--log:debug("ramp: target(" .. target .. "), brightCur(" .. brightCur ..")")
	--log:info("Diff: " .. diff)

	if math.abs(diff) > AMBIENT_RAMPSTEPS then
		diff = AMBIENT_RAMPSTEPS

		-- is there an easier solution for this?
		if brightCur > target then
			diff = diff * -1.0
		end
	end

	brightCur = brightCur + diff

	-- make sure brighCur is a integer
	brightCur = math.floor(brightCur)

	if brightCur > MAX_BRIGHTNESS_LEVEL then
		brightCur = MAX_BRIGHTNESS_LEVEL
	elseif brightCur < MIN_BRIGHTNESS_LEVEL then
		brightCur = MIN_BRIGHTNESS_LEVEL
	end
end


function getSmoothedLux()
	local sum = 0.0

	-- First Pass, Average
	for i = 1, #luxSmooth do
		--log:info("#" .. i .. " " .. luxSmooth[i])
		sum = sum + luxSmooth[i]
	end
	local avg = sum / #luxSmooth;
	--log:debug("AVG: " .. avg)

	-- Second Pass, Standard Deviation
	sum = 0.0
	for i = 1, #luxSmooth do
		local variation = (luxSmooth[i] - avg)
		sum = sum + (variation * variation)
	end
	local sdev = math.sqrt(sum / #luxSmooth)
	--log:info("SDEV: " .. sdev);

	-- If not deviation, return average
	if sdev == 0 then
		return avg
	end

	-- Third Pass, Filter out values > Standard Deviation
	sum = 0.0;
	local values = 0;
	local high = avg + sdev;
	local low  = avg - sdev
	for i = 1, #luxSmooth do
		if luxSmooth[i] > low and luxSmooth[i] < high then
			--log:info("##" .. i .. " " .. luxSmooth[i])
			values = values + 1
			sum = sum + luxSmooth[i]
		end
	end

	if values >= 1 then
		avg = sum / values;
		--log:debug("AVG2: " .. avg)
	end

	return avg
end


-- This function is called every 100 ms to make the
--  brightness ramping up / down smoothly
function doAutomaticBrightnessTimer(self)
	-- But only read ambient light sensor value
	--  every 500 ms to reduce load
	if brightReadRateDivider > 1 then
		brightReadRateDivider = brightReadRateDivider - 1
	else
		brightReadRateDivider = BRIGHTNESS_READ_RATE_DIVIDER

		local luxvalue = sysReadNumber(self, "ambient")

		-- Use the table to smooth out ambient value spikes
		table.insert(luxSmooth, luxvalue)
		if( MAX_SMOOTHING_VALUES < #luxSmooth ) then
			table.remove(luxSmooth, 1)
		end

		brightLast = self:getSmoothedLux(luxSmooth)
	end

	local ambient = brightLast

	--[[
	log:info("Ambient:      " .. tostring(ambient))
	log:info("MaxBright:    " .. tostring(MAX_BRIGHTNESS_LEVEL))
	log:info("Brightness:   " .. tostring(settings.brightness))
	]]--

	-- switch around ambient value (darker is higher)
	ambient = staticAmbientMin - ambient
	if ambient < 0 then
		ambient = 0
	end
	--log:info("AmbientFixed: " .. tostring(ambient))

	brightTarget = (MAX_BRIGHTNESS_LEVEL / staticAmbientMin) * ambient

	self:doBrightnessRamping(brightTarget);

	-- Bug: 14040 - Fix race condition with blank screensaver
	if self:isScreenOff() then
		return
	end

	-- Make sure bright Cur stays above minimum
	if brightMin > brightCur then
		brightCur = brightMin
	end

	-- Set Brightness
	self:setBrightness( brightCur )

	--log:info("CurTarMax:    " .. tostring(brightCur) .. " - ".. tostring(brightTarget))
end


function isScreenOff(self)
	return self:getBrightness() == 0
end


function getBrightness (self)
	return self.lcdBrightness
end


function setBrightness (self, level)
	-- FIXME a quick hack to prevent the display from dimming
	if level == "off" then
		level = 0
	elseif level == "on" then
		level = self.brightPrev
	elseif level == nil then
		return
	else
		self.brightPrev = level
	end

	_setBrightness(self, level)
end


function _setBrightness(self, level)
	if level == nil then
		return
	end

	--log:debug("_setBrightness: ", level)

	self.lcdBrightness = level

	level = level + 1 -- adjust 0 based to one based for the brightnessTable

	if level > MAX_BRIGHTNESS_LEVEL  then
		level = MAX_BRIGHTNESS_LEVEL
	end

	-- Gradually reduce display brightness in IDLE mode when over half brightness
	if self.powerState == "IDLE" then
		if level > (MAX_BRIGHTNESS_LEVEL / 2) then
			level = level - math.floor(10 * (level - (MAX_BRIGHTNESS_LEVEL / 2)) / (MAX_BRIGHTNESS_LEVEL / 2))
		end
	end

	brightness = brightnessTable[level][2]
	bl_power   = brightnessTable[level][1]

	sysWrite(self, "brightness", brightness)
	sysWrite(self, "bl_power",   bl_power)
end


function _initBrightnessTable( self)
	local pwm_steps = 256
	local brightness_step_percent = 10
	local k = 1

	--first value is "off" value
	brightnessTable[k] = {0, 0}
	k = k + 1

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

-- Debug
--	local a
--	for k = 1, #brightnessTable, 1 do
--		a = brightnessTable[k][1]
--		a = brightnessTable[k][2]
--	end
end

---
-- END BRIGHTNESS
---


--service method
function performHalfDuplexBugTest(self)
	return self._revision < 5
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


function _setEndpoint(self, override)
	if self.isHeadphone == nil then
		-- don't change state during initialization
		return
	end

	local endpoint
	if override then
		if override == "Speaker" then
			endpoint = "Speaker"
		elseif override == "Headphone" then
			endpoint = "Headphone"
		else
			log:warn("Invalid audio endpoint override ignored: ", override)
			endpoint = self.endpoint
		end
	elseif self.isHeadphone then
		endpoint = "Headphone"
	elseif self.powerState == "ACTIVE" or self.powerState == "IDLE" then
		endpoint = "Speaker"
	else
		-- only power off when using the power amp to prevent
		-- pops on headphones
		endpoint = "Off"
	end

	if self.endpoint == endpoint then
		return
	end
	self.endpoint = endpoint

	if endpoint == "Speaker" then
		bsp:setMixer("Crossover", true)
		bsp:setMixer("Endpoint", endpoint)
	else
		bsp:setMixer("Endpoint", endpoint)
		bsp:setMixer("Crossover", false)
	end
end


function _headphoneJack(self, val)
	self.isHeadphone = val
	self:_setEndpoint()
end


function _lineinJack(self, val, activate)
	if val then
		if activate then
			appletManager:callService("activateLineIn", true)
		else
			appletManager:callService("addLineInMenuItem")
		end
	else
		appletManager:callService("removeLineInMenuItem")
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
		log:debug('date sync epoch: ', chunk.data.date_epoch)
		if chunk.data.date_epoch then
                	self:setDate(chunk.data.date_epoch)
		end
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


function setDate(self, epoch)
	squeezeos.swclockSetEpoch(epoch);
	local success,err = squeezeos.sys2hwclock()
	if not success then
		log:warn("sys2hwclock() failed: ", err)
	end
	iconbar:update()
end


local function _updateWirelessDone(self, iface, success)
	local player = Player:getLocalPlayer()

	-- wireless
	if iface:isWireless() then
		if success then
			local percentage, quality = iface:getSignalStrength()
			iconbar:setWirelessSignal((quality ~= nil and quality or "ERROR"), iface)
			if player then
				player:setSignalStrength(percentage)
			end
		else		
			iconbar:setWirelessSignal("ERROR", iface)
			if player then
				player:setSignalStrength(nil)
			end
		end
	-- wired
	else
		if success then
			iconbar:setWirelessSignal("ETHERNET", iface)
		else
			iconbar:setWirelessSignal("ETHERNET_ERROR", iface)
		end
		if player then
			player:setSignalStrength(nil)
		end
	end
end


local function _updateWireless(self)
	local iface = Networking:activeInterface()

	-- After factory reset iface is nil (none selected yet)
	if iface == nil or not appletManager:callService("isSetupDone") then
		return
	end

	Networking:checkNetworkHealth(
		iface,
		function(continue, result)
			log:debug("_updateWireless: ", result)

			if not continue then
				_updateWirelessDone(self, iface, (result >= 0))
			end
		end,
		false,
		nil
	)
end


-- return true to prevent firmware updates
function isBatteryLow(self)
	local chargerState = sysReadNumber(self, "charger_state")

	if chargerState  ==  3 then
		local batteryCharge = sysReadNumber(self, "battery_charge")
		local batteryCapacity = sysReadNumber(self, "battery_capacity")

		local batteryRemain = (batteryCharge / batteryCapacity) * 100

		return batteryRemain < 10

	elseif chargerState == (3 |(1<<5)) then
	        -- this state means the battery is really low and will fail 
		-- soon.
		return true
	else
		return false
	end
end


local function _updatePower(self)
	local isLowBattery = false
	local chargerState = sysReadNumber(self, "charger_state")
	local batteryState = false

	if chargerState == nil then
		return
	end

	if chargerState == 1 then
		-- no battery is installed, we must be on ac!
		log:debug("no battery")
		batteryState = "battery"
		iconbar:setBattery(nil)

	elseif chargerState == 2 then
		log:debug("on ac, fully charged")
		batteryState = "ac"
		iconbar:setBattery("AC")

	elseif chargerState == 3 then
		-- running on battery
		batteryState = "battery"

		local batteryCharge = sysReadNumber(self, "battery_charge")
		local batteryCapacity = sysReadNumber(self, "battery_capacity")

		local batteryRemain = (batteryCharge / batteryCapacity) * 100
		log:debug("on battery power ", batteryRemain, "%")

		iconbar:setBattery(math.min(math.floor(batteryRemain / 25) + 1, 4))

	elseif chargerState == (3| (1<<5)) then
		log:debug("low battery")
		isLowBattery = true
		batteryState = "battery"
		iconbar:setBattery(0)

	elseif (chargerState & 8) == 8 then
		log:debug("on ac, charging")
		batteryState = "ac"
		iconbar:setBattery("CHARGING")

	else
		log:warn("invalid chargerState")
		iconbar:setBattery(nil)
	end

	-- wake up on ac power changes
	if batteryState and batteryState ~= self.batteryState then
		self:wakeup()
		if batteryState == "ac" then                                                                            
			iconbar.iconBattery:playSound("DOCKING")                            
		end                                                                                       
	end

	if batteryState then
		self.batteryState = batteryState
	end

	self:_lowBattery(isLowBattery or self.testLowBattery)
end


function _lowBattery(self, isLowBattery)
	if self.isLowBattery == isLowBattery then
		return
	end

	self.isLowBattery = isLowBattery

	if not isLowBattery then
		appletManager:callService("lowBatteryCancel")
	else
		appletManager:callService("lowBattery")
	end
end


function _updateTask(self)
	while true do
		local what = unpack(Task:running().args)

		if (what & UPDATE_POWER) == UPDATE_POWER then
			_updatePower(self)
		end
		if (what & UPDATE_WIRELESS) == UPDATE_WIRELESS then
			_updateWireless(self)
		end

		-- suspend task
		Task:yield(false)
	end
end


function sleep(self)
	local state = self.powerState
	local player = Player:getLocalPlayer()

	log:debug("sleep: ", state)

	if state == "ACTIVE" then
		if player then
			if jiveMain:getSoftPowerState() ~= "on" then
				return self:setPowerState("SLEEP")
			end
		end

		return self:setPowerState("IDLE")

	elseif state == "IDLE" then
		if player then
			local playmode = player:getEffectivePlayMode()

			if playmode == "play" then
				return self.powerTimer:stop()
			end
		end

		return self:setPowerState("SLEEP")

	elseif state == "SLEEP" then
		return self:setPowerState("HIBERNATE")
	end
end


function wakeup(self)
	log:debug("wakeup: ", self.powerState)

	self:setPowerState("ACTIVE")
end


function notify_playerPower(self, player, power)
	if not player:isLocal() then
		return
	end

	if power then
		self:wakeup()
	else
		self:setPowerState(self.powerState)
	end
end


function notify_playerModeChange(self, player, mode)
	if not player:isLocal() then
		return
	end

	if mode == 'play' then
		self:wakeup()
	else
		self:setPowerState(self.powerState)
	end
end


function setPowerState(self, state)
	local poweroff = false

	if state == "ACTIVE" then
		self.powerTimer:restart(settings.idleTimeout)

	elseif state == "IDLE" then
		self.powerTimer:restart(settings.sleepTimeout)

	elseif state == "SLEEP" then
		self.powerTimer:restart(settings.hibernateTimeout)

	elseif state == "HIBERNATE" then
		self.powerTimer:stop()

		local chargerState = sysReadNumber(self, "charger_state")
		poweroff = ((chargerState & 3) == 3)
		log:debug("hibernate chargerState=", chargerState, " poweroff=", poweroff)
	end

	if self.powerState == state then
		return
	end

	log:debug("powerState: ", self.powerState, "->", state)

	self.powerState = state

	-- Bug 16100, only setEndpoint if alarm is not in state: active, snooze or active_fallback
	if self.player and (self.player:getAlarmState() == 'active' or self.player:getAlarmState() == 'snooze' or self.player:getAlarmState() == 'active_fallback') then
		-- leave audio coming out speaker when alarm is active or in snooze (alarm forces output out speaker)
		log:info('Alarm either in progress or snooze, do not call _setEndpoint()')
	else
		_setEndpoint(self)
	end

	_setBrightness(self, self.lcdBrightness)

	if (poweroff) then
		appletManager:callService("poweroff", true)
	end
end




function getWakeupAlarm(self)
	return self.wakeupAlarm
end


function setWakeupAlarm (self, epochsecs)
	if not epochsecs then
		return
	end
	local wakeup
	if epochsecs == 'none' then
		-- to unset, pass in the largest integer possible
		-- pass it as a string or else this fails
		wakeup = '4294967295'
	else
		wakeup = epochsecs
	end
	self.wakeupAlarm = wakeup

	sysWrite(self, "alarm_time", wakeup)
end

-- Minimal brightness slider (Auto)
function settingsMinBrightnessShow (self, menuItem)
	local window = Window("text_list", self:string("BSP_BRIGHTNESS_MIN"), squeezeboxjiveTitleStyle)

	local settings = self:getSettings()
	local level = settings.brightnessMinimal

	local slider = Slider("slider", 1, #brightnessTable, level,
		function(slider, value, done)
--			log:info("Value: " .. value)

			-- Set to automatic when changing minimal brightness
			settings.brightnessControl = "automatic"

			if value < MIN_BRIGHTNESS_LEVEL then
				value = MIN_BRIGHTNESS_LEVEL
			end

			-- Prepare setting to store later
			settings.brightnessMinimal = value
			-- Update min value for timer loop
			brightMin = value
			-- Make sure preview min brightness does
			-- not go below actual brightness
			if value > brightTarget then
				self:setBrightness( value)
			else
				self:setBrightness( math.floor( brightTarget))
			end

			-- done is true for 'go' and 'play' but we do not want to leave
			if done then
				window:playSound("BUMP")
				window:bumpRight()
			end
	end)

	window:addWidget(Textarea("help_text", self:string("BSP_BRIGHTNESS_MIN_ADJUST_HELP")))
	window:addWidget(Group("sliderGroup", {
		min = Icon("button_slider_min"),
		slider = slider,
		max = Icon("button_slider_max"),
	}))

	-- If we are here already, eat this event to avoid piling up this screen over and over
	window:addActionListener("go_brightness", self,
				function()
					return EVENT_CONSUME
				end)

	window:addListener(EVENT_WINDOW_POP,
		function()
			brightMin = settings.brightnessMinimal
			self:storeSettings()
		end
	)

	window:show()
	return window
end


-- Manual brightness slider
function settingsBrightnessShow (self, menuItem)
	local window = Window("text_list", self:string("BSP_BRIGHTNESS_MANUAL"), squeezeboxjiveTitleStyle)

	local settings = self:getSettings()
	local level = settings.brightness

	local slider = Slider("slider", 1, #brightnessTable, level,
		function(slider, value, done)
			settings.brightness = value

			-- If user modifies manual brightness - switch to manaul brightness
			settings.brightnessControl = "manual"

			local bright = value

			self:setBrightness(bright)

			-- done is true for 'go' and 'play' but we do not want to leave
			if done then
				window:playSound("BUMP")
				window:bumpRight()
			end
	end)

	window:addWidget(Textarea("help_text", self:string("BSP_BRIGHTNESS_ADJUST_HELP")))
	window:addWidget(Group("sliderGroup", {
		min = Icon("button_slider_min"),
		slider = slider,
		max = Icon("button_slider_max"),
	}))

	-- If we are here already, eat this event to avoid piling up this screen over and over
	window:addActionListener("go_brightness", self,
				function()
					return EVENT_CONSUME
				end)

	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
		end
	)

	window:show()
	return window
end


-- Manual / auto brightness selection
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
	window:show()

end


function free(self)
	log:error("free should never be called for this resident applet")

	return false
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
