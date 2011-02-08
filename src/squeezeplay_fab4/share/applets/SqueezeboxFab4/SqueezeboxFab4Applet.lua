
local pairs, tonumber, tostring, unpack = pairs, tonumber, tostring, unpack

-- board specific driver
local fab4_bsp               = require("fab4_bsp")

local oo                     = require("loop.simple")
local os                     = require("os")
local io                     = require("io")
local string                 = require("string")
local table                  = require("jive.utils.table")
local math                   = require("math")
local squeezeos              = require("squeezeos_bsp")

local Applet                 = require("jive.Applet")
local Decode                 = require("squeezeplay.decode")
local System                 = require("jive.System")

local Networking             = require("jive.net.Networking")

local Player                 = require("jive.slim.Player")

local Framework              = require("jive.ui.Framework")
local Group                  = require("jive.ui.Group")
local Icon                   = require("jive.ui.Icon")
local Button                 = require("jive.ui.Button")
local Event                  = require("jive.ui.Event")
local Popup                  = require("jive.ui.Popup")
local Task                   = require("jive.ui.Task")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Slider                 = require("jive.ui.Slider")
local RadioGroup             = require("jive.ui.RadioGroup")
local RadioButton            = require("jive.ui.RadioButton")
local Window                 = require("jive.ui.Window")

local debug                  = require("jive.utils.debug")

local SqueezeboxApplet       = require("applets.Squeezebox.SqueezeboxApplet")

local EVENT_IR_DOWN          = jive.ui.EVENT_IR_DOWN
local EVENT_IR_REPEAT        = jive.ui.EVENT_IR_REPEAT

local EVENT_WINDOW_INACTIVE  = jive.ui.EVENT_WINDOW_INACTIVE

local jnt                    = jnt
local iconbar                = iconbar
local jiveMain               = jiveMain
local appletManager          = appletManager
local settings	             = nil

local UPDATE_WIRELESS        = 0x01
local UPDATE_POWER           = 0x02


-- hack around global scope to allow bsp c code to call back to applet
local ourUeventHandler
ueventHandler = function(...)
	ourUeventHandler(...)
end


module(..., Framework.constants)
oo.class(_M, SqueezeboxApplet)



-----------------------------
-- Ambient Light Init Stuff
-----------------------------
-- Default/Start Values
local MAX_BRIGHTNESS_LEVEL = 100
local MIN_BRIGHTNESS_LEVEL = 1

-- Timer values
local BRIGHTNESS_REFRESH_RATE = 100						-- 100ms (was 500ms)
local BRIGHTNESS_OVERRIDE = math.floor( 10 * 1000 / BRIGHTNESS_REFRESH_RATE)	-- 10s (was 6 * 500ms = 3s)
local BRIGHTNESS_READ_RATE_DIVIDER = 5						-- This gives 2 times a seconds


-- Lux Value Smoothing
local MAX_SMOOTHING_VALUES = math.floor( 4000 / (BRIGHTNESS_REFRESH_RATE * BRIGHTNESS_READ_RATE_DIVIDER))	-- 40 (was 8)
local luxSmooth = {}

-- Maximum number of brightness levels up/down per run of the timer
local AMBIENT_RAMPSTEPS = 7

-- Ambient SysFS Path
local AMBIENT_SYSPATH = "/sys/bus/i2c/devices/0-0039/"

-- This value determinds sensibility - smaller values = more sensible
--  brightness = (MAX_BRIGHTNESS_LEVEL / STATIC_LUX_MAX) * <sensorvalue>
local STATIC_LUX_MAX = 500

local brightCur = MAX_BRIGHTNESS_LEVEL
local brightTarget = MAX_BRIGHTNESS_LEVEL
local brightMin = MIN_BRIGHTNESS_LEVEL + 25;
local brightReadRateDivider = 1

-- brightOverride == 0 -> IDLE
-- brightOverride > 0  -> ACTIVE (Someone is touching the screen or using a remote)
local brightOverride = 0


function init(self)
	settings = self:getSettings()

	-- read uuid, serial and revision
	parseCpuInfo(self)

	System:init({
		machine = "fab4",
		uuid = self._uuid,
		revision = self._revision,
	})

	System:setCapabilities({
		["touch"] = 1,
		["ir"] = 1,
		["audioByDefault"] = 1,
		["wiredNetworking"] = 1,
		["usb"] = 1,
		["sdcard"] = 1,
		["hasDigitalOut"] = 1,
		["hasTinySC"] = 1,
		["IRBlasterCapable"] = 0,
	})

	--account for fab4 touchpad hardware issue: the bottom pixels aren't reported correctly 
	System:setTouchpadBottomCorrection(30)
	
	-- warn if uuid or mac are invalid
	verifyMacUUID(self)

	self:initBrightness()
	local brightnessTimer = Timer( BRIGHTNESS_REFRESH_RATE,
		function()
			if not self:isScreenOff() then
				if settings.brightnessControl == "manual" then
					-- Still ACTIVE, don't do anything
					if brightOverride > 0 then
						-- Count down once per cycle
						brightOverride = brightOverride - 1
						return
					end
					-- IDLE: Reduce brightness
					self:setBrightness( self:getBrightness())
				else
					self:doAutomaticBrightnessTimer()
				end
			end
		end)
	brightnessTimer:start()
	
	-- status bar updates
	local updateTask = Task("statusbar", self, _updateTask)
	updateTask:addTask(UPDATE_WIRELESS)
	iconbar.iconWireless:addTimer(5000, function()  -- every five seconds
		updateTask:addTask(UPDATE_WIRELESS)
	end)
	
	Framework:addActionListener("soft_reset", self, _softResetAction, true)

	-- open audio device
	Decode:open(settings)

	-- find out when we connect to player
	jnt:subscribe(self)

	playSplashSound(self)
end


local ueventListeners = {}

function addUeventListener(self, pattern, listener)
	ueventListeners[listener] = pattern
end

function ourUeventHandler(evt, msg)
	for listener,pattern in pairs(ueventListeners) do
		if string.match(evt, pattern) then
			listener(evt, msg)
		end
	end
end

-----------------------------
-- Ambient Light Stuff Start
-----------------------------
function initBrightness(self)
	-- Value of manual brightness slider
	settings.brightness = settings.brightness or MAX_BRIGHTNESS_LEVEL
	-- Value of minimal brightness (auto) slider
	settings.brightnessMinimal = settings.brightnessMinimal or (MIN_BRIGHTNESS_LEVEL + 25)
	-- Value of brightness control
	settings.brightnessControl = settings.brightnessControl or "automatic"

	-- Enable gain in Ambient Light Sensor
	local f1 = io.open(AMBIENT_SYSPATH .. "gain", "w")
	f1:write("1")
	f1:close()

	-- Set factor in Ambient Sensor
	local f2 = io.open(AMBIENT_SYSPATH .. "factor", "w")
	f2:write("40")
	f2:close()

	-- Value of current LCD brightness
	self.lcdBrightness = settings.brightness

	-- Init some values to a default value
	brightCur = MAX_BRIGHTNESS_LEVEL
	brightTarget = MAX_BRIGHTNESS_LEVEL
	brightMin = settings.brightnessMinimal
	brightReadRateDivider = 1

	self.brightPrev = self:getBrightness()
	if self.brightPrev and self.brightPrev == 0 then
		--don't ever fallback to off
		self.brightPrev = MAX_BRIGHTNESS_LEVEL
	end

	-- Set Brightness after reboot
	self:setBrightness(settings.brightness)
	
	-- Create a global listener to set 
	Framework:addListener(ACTION | EVENT_SCROLL | EVENT_MOUSE_ALL | EVENT_MOTION | EVENT_IR_ALL,
		function(event)
			-- Prevent non Squeezebox IR remotes from increasing brightness
			if (event:getType() & EVENT_IR_ALL) > 0 then
				if (not Framework:isValidIRCode(event)) then
					return EVENT_UNUSED
				end
			end
			-- Set to >0 means we're ACTIVE
			brightOverride = BRIGHTNESS_OVERRIDE
			-- ACTIVE: Increase brightness
			self:setBrightness( self:getBrightness())
			return EVENT_UNUSED
		end
		,true)		

	self:storeSettings()
end


function doBrightnessRamping(self, target)
	local diff = 0
	diff = (target - brightCur)
	
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
	
	--log:info("Cur: " .. brightCur)
end


function getSmoothedLux() 
	local sum = 0.0
	
	-- First Pass, Average
	for i = 1, #luxSmooth do
		--log:info("#" .. i .. " " .. luxSmooth[i])
		sum = sum + luxSmooth[i]
	end	
	local avg = sum / #luxSmooth;	
	log:debug("AVG: " .. avg)
	
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
		log:debug("AVG2: " .. avg)
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

		local f = io.open(AMBIENT_SYSPATH .. "lux")
		local lux = f:read("*all")
		f:close()
	
		f = io.open(AMBIENT_SYSPATH .. "adc")
		local adc = f:read("*all")
		f:close()

		local luxvalue = tonumber(string.sub(lux, 0, string.len(lux)-1))
	
		local s, e = string.find(adc, ",")
		local valCh0 = tonumber(string.sub(adc, 0, s-1))

		-- If channel 0 (visible and ir light) is at maximum
		--  the calculated lux value isn't correct anymore
		--  and goes down again. Use max lux value in this case.
		if (luxvalue > STATIC_LUX_MAX) or (valCh0 == 65535) then
			-- Fix calculation for very high lux values
			luxvalue = STATIC_LUX_MAX
		end
	
		-- Use the table to smooth out ambient value spikes
		table.insert(luxSmooth, luxvalue)	
		if( MAX_SMOOTHING_VALUES < #luxSmooth ) then
			table.remove(luxSmooth, 1)
		end
	end
	
	local ambient = self:getSmoothedLux(luxSmooth)	
	brightTarget = (MAX_BRIGHTNESS_LEVEL / STATIC_LUX_MAX) * ambient

	--[[
	log:info("Ambient:      " .. tostring(ambient))
	log:info("BrightTarget: " .. tostring(brightTarget))
	log:info("Brightness:   " .. tostring(settings.brightness))	
	log:info("MinBrightness:" .. tostring(settings.brightnessMinimal))	
	]]--
	
	self:doBrightnessRamping(brightTarget);
	
	-- Bug: 14040 - Fix race condition with blank screensaver
	if self:isScreenOff() then
		return
	end

	-- Make sure bright Cur stays above minimum
	if brightMin > brightCur then
		brightCur = brightMin
	end

	-- ACTIVE mode
	-- As long as the user is touching the screen don't do anything more
	if brightOverride > 0 then
		-- count down once per cycle
		brightOverride = brightOverride - 1
		return
	end

	-- Set Brightness
	self:setBrightness( brightCur )

	--log:info("CurTarMax:    " .. tostring(brightCur) .. " - ".. tostring(brightTarget))
end


function isScreenOff(self)
	return self:getBrightness() == 0
end


function getBrightness (self)
	--[[ Avoid reading value from filesystem every time and use locally stored value
	local f = io.open("/sys/class/backlight/mxc_ipu_bl.0/brightness", "r")
	local level = f:read("*a")
	f:close()

	--opposite of setBrigtness translation
	return math.floor(100 * math.pow(tonumber(level)/255, 1/1.38)) -- gives 0 to 100
	--]]

	return self.lcdBrightness
end


function setBrightness (self, level)
	if level == "off" or level == 0 then
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

	log:debug("_setBrightness: ", level)

	-- Store LCD level so we do not have to query it all the time in getBrightness()
	self.lcdBrightness = level

	-- Gradually reduce LCD brightness when IDLE and level is over half of maximum brightness
	--  to increase lifetime of LCD backlight
	if brightOverride == 0 then
		if level > (MAX_BRIGHTNESS_LEVEL / 2) then
			level = level - math.floor(40 * (level - (MAX_BRIGHTNESS_LEVEL / 2)) / (MAX_BRIGHTNESS_LEVEL / 2))
		end
	end

	--ceil((percentage_bright)^(1.58)*255)
	local deviceLevel = math.ceil(math.pow((level/100.0), 1.38) * 255) -- gives 1 to 1 for first 6, and 255 for max (100)
	if deviceLevel > 255 then -- make sure we don't exceed
		deviceLevel = 255 --max
	end


	local f = io.open("/sys/class/backlight/mxc_ipu_bl.0/brightness", "w")
	f:write(tostring(deviceLevel))
	f:close()
	if log:isDebug() then
		log:debug(" level: ", level, " deviceLevel:", deviceLevel, " getBrightness: ", self:getBrightness())
	end
end

---
-- END BRIGHTNESS
---


--disconnect from player and server and re-set "clean (no server)" LocalPlayer as current player
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
		if chunk and chunk.data and chunk.data.date_epoch then
		log:debug('date sync epoch: ', chunk.data.date_epoch)
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


function _updateTask(self)
	while true do
		local what = unpack(Task:running().args)

		if (what & UPDATE_WIRELESS) == UPDATE_WIRELESS then
			_updateWireless(self)
		end

		-- suspend task
		Task:yield(false)
	end
end


-- Minimal brightness slider (auto)
function settingsMinBrightnessShow (self, menuItem)
	local window = Window("text_list", self:string("BSP_BRIGHTNESS_MIN"), squeezeboxjiveTitleStyle)

	local settings = self:getSettings()
	local level = settings.brightnessMinimal

	local slider = Slider('brightness_slider', 1, 75, level,
				function(slider, value, done)
--					log:info("Value: " .. value)

					-- Set to automatic when changing minimal brightness
					settings.brightnessControl = "automatic"
					-- Prepare setting to store later
					settings.brightnessMinimal = value
					-- Update min value for timer loop
					brightMin = value
					-- Make sure preview min brightness does
					--  not go below actual brightness
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
	slider.jumpOnDown = false
	slider.dragThreshold = 5

--	window:addWidget(Textarea("help_text", self:string("BSP_BRIGHTNESS_ADJUST_HELP")))
	window:addWidget(Group('brightness_group', {
				div1 = Icon('div1'),
				div2 = Icon('div2'),


				down  = Button(
					Icon('down'),
					function()
						local e = Event:new(EVENT_SCROLL, -1)
						Framework:dispatchEvent(slider, e)
						return EVENT_CONSUME
					end
				),
				up  = Button(
					Icon('up'),
					function()
						local e = Event:new(EVENT_SCROLL, 1)
						Framework:dispatchEvent(slider, e)
						return EVENT_CONSUME
					end
				),
				slider = slider,
			}))

	window:addActionListener("page_down", self,
				function()
					local e = Event:new(EVENT_SCROLL, 1)
					Framework:dispatchEvent(self.volSlider, e)
					return EVENT_CONSUME
				end)
	window:addActionListener("page_up", self,
				function()
					local e = Event:new(EVENT_SCROLL, -1)
					Framework:dispatchEvent(self.volSlider, e)
					return EVENT_CONSUME
				end)


	window:addListener(EVENT_WINDOW_POP,
		function()
			brightMin = settings.brightnessMinimal
			--log:info("Save: " .. brightMin)			
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

	local slider = Slider('brightness_slider', 1, 100, level,
				function(slider, value, done)
					
					settings.brightnessControl = "manual"
					
					settings.brightness = value

					local bright = settings.brightness
					if bright > 100 then
						bright = 100
					end

					self:setBrightness( bright)

					-- done is true for 'go' and 'play' but we do not want to leave
					if done then
						window:playSound("BUMP")
						window:bumpRight()
					end
				end)
	slider.jumpOnDown = false
	slider.dragThreshold = 5

--	window:addWidget(Textarea("help_text", self:string("BSP_BRIGHTNESS_ADJUST_HELP")))
	window:addWidget(Group('brightness_group', {
				div6 = Icon('div6'),
				div7 = Icon('div7'),


				down  = Button(
					Icon('down'),
					function()
						local e = Event:new(EVENT_SCROLL, -1)
						Framework:dispatchEvent(slider, e)
						return EVENT_CONSUME
					end
				),
				up  = Button(
					Icon('up'),
					function()
						local e = Event:new(EVENT_SCROLL, 1)
						Framework:dispatchEvent(slider, e)
						return EVENT_CONSUME
					end
				),
				slider = slider,
			}))

	window:addActionListener("page_down", self,
				function()
					local e = Event:new(EVENT_SCROLL, 1)
					Framework:dispatchEvent(self.volSlider, e)
					return EVENT_CONSUME
				end)
	window:addActionListener("page_up", self,
				function()
					local e = Event:new(EVENT_SCROLL, -1)
					Framework:dispatchEvent(self.volSlider, e)
					return EVENT_CONSUME
				end)

	-- If we are here already, eat this event to avoid piling up this screen over and over
	window:addActionListener("go_brightness", self,
				function()
					return EVENT_CONSUME
				end)

--	window:addWidget(slider) - for focus purposes (todo: get style right for this so slider can be focused)


	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
		end
	)

	window:show()
	return window
end


-- Brightness control slider - automatic / manual
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


-- Moved here from SqueezeCenter applet since SC applet is not resident
--  but we need scGuardTimer to survive
function SCGuardianTimer(self, action)

	if (action == 'start') or (action == 'restart') then
		log:debug("SC guard timer - start")

		if self.scGuardTimer then
			self.scGuardTimer:stop()
			self.scGuardTimer = nil
		end

		self.scGuardTimer = Timer( 5000,	-- Check every 5 seconds if still running
			function()
				-- don't use shell script, we might be out of memory
				local running = appletManager:callService("isBuiltInSCRunning")

				log:debug("SC guard timer - check SC running: ", running)

				if not running then
					log:warn("SC guard timer - SC got killed!!!")
					appletManager:callService("deactivateScreensaver")
					self.scGuardTimer:stop()
					self.scGuardTimer = nil
					self:_showSCHasBeenStoppedMessage()
				end
			end,
			false
		)
		self.scGuardTimer:start()

	elseif (action == 'stop') or (action == 'rescan') then
		log:debug("SC guard timer - stop")

		if self.scGuardTimer then
			self.scGuardTimer:stop()
			self.scGuardTimer = nil
		end
	end
end


-- Moved here from SqueezeCenter applet since SC applet is not resident
--  but we need scGuardTimer to survive
function _showSCHasBeenStoppedMessage(self)
	local window = Window("text_list", self:string("SERVER_HAS_BEEN_STOPPED"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	menu:addItem({
		text = self:string("OK"),
		style = 'item',
		sound = "WINDOWSHOW",		
		callback = function ()
			window:hide()
		end
	})

	menu:setHeaderWidget( Textarea("help_text", self:string("SERVER_HAS_BEEN_STOPPED_INFO")))

	window:addWidget(menu)

	-- Remove ourselfs if we are not on top anymore, i.e. another window gets activated
	window:addListener( EVENT_WINDOW_INACTIVE,
		function()
			log:debug("Message window removed as we aren't active anymore.")
			window:hide()
			return EVENT_UNUSED
		end
	)

	window:show()
	return window
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
