
local pairs, tonumber, tostring = pairs, tonumber, tostring

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

local jnt                    = jnt
local iconbar                = iconbar
local jiveMain               = jiveMain
local settings	             = nil

-- hack around global scope to allow bsp c code to call back to applet
local ourUeventHandler
ueventHandler = function(...)
	ourUeventHandler(...)
end


module(..., Framework.constants)
oo.class(_M, SqueezeboxApplet)


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
	})

	--account for fab4 touchpad hardware issue: the bottom pixels aren't reported correctly 
	System:setTouchpadBottomCorrection(30)
	
	-- warn if uuid or mac are invalid
	verifyMacUUID(self)

	settings.brightness = settings.brightness or 100
	settings.brightnessMinimal = settings.brightnessMinimal or 1
	settings.ambient = settings.ambient or 0
	settings.brightnessControl = settings.brightnessControl or "manual"

	self:initBrightness()
	local brightnessTimer = Timer( 500,
		function()
			if settings.brightnessControl == "manual" then
				self:doManualBrightnessTimer()
			else
				self:doAutomaticBrightnessTimer()
			end
		end)
	brightnessTimer:start()
	
	-- status bar updates
	self:update()
	iconbar.iconWireless:addTimer(5000, function()  -- every 5 seconds
	      self:update()
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
-- Ambient SysFS Path
local AMBIENT_SYSPATH = "/sys/bus/i2c/devices/0-0039/"

-- 3500 Is about the value I've seen in my room during full daylight
-- so set it somewhere below that
local STATIC_LUX_MAX = 2000

-- Lux Value Smoothing
local MAX_SMOOTHING_VALUES = 8
local luxSmooth = {}

-- Default/Start Values
local TOUCHBRIGHTNESS_INCREASE = 10
local MAX_BRIGHTNESS_LEVEL = 100
local MIN_BRIGHTNESS_LEVEL = 1

local brightCur = 100
local brightTarget = 100
local brightSettings = 0;
local brightMin = 1;
local brightOverride = 0


-- Maximum number of brightness levels up/down per run of the timer
local AMBIENT_RAMPSTEPS = 7

-- Initialize Brightness Stuff (Factor)
function initBrightness(self)
	self.brightPrev = self:getBrightness()
	if self.brightPrev and self.brightPrev == 0 then
		--don't ever fallback to off
		self.brightPrev = 50
	end
	
	-- Initialize the Ambient Sensor with a factor of 30
	local f = io.open(AMBIENT_SYSPATH .. "factor", "w")
	f:write("30")
	f:close()
		
	-- Set Initial Settings Brightness
	if not settings.brightness then
		settings.brightness = MAX_BRIGHTNESS_LEVEL
	end

	-- Set Initial minimal brightness
	brightMin = settings.brightnessMinimal
	
	-- Set Brightness after reboot
	self:setBrightness(settings.brightness)	
	
	brightSettings = settings.brightness
		
	-- Create a global listener to set 
	Framework:addListener(ACTION | EVENT_SCROLL | EVENT_MOUSE_ALL | EVENT_MOTION | EVENT_IR_ALL,
		function(event)
			if settings.brightnessControl == "manual" then 
				return
			end
					
			-- if this is a new 'touch' event set brightness to max
			if brightOverride == 0 then
				b = brightCur + TOUCHBRIGHTNESS_INCREASE;
				if  b > MAX_BRIGHTNESS_LEVEL then
					b = MAX_BRIGHTNESS_LEVEL
				end
				
				self:setBrightness( math.floor(b) )
			end
			
			brightOverride = 6	
			return EVENT_UNUSED
		end
		,true)		
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


function doAutomaticBrightnessTimer(self)

	-- As long as the user is touching the screen don't do anything more
	if brightOverride > 0 then
		-- count down once per cycle
		brightOverride = brightOverride - 1
		return
	end
	
	-- Now continue with the real ambient code 
	local f = io.open(AMBIENT_SYSPATH .. "lux")
	local lux = f:read("*all")
	f:close()
	
	local luxvalue = tonumber(string.sub(lux, 0, string.len(lux)-1))
	
	if luxvalue > STATIC_LUX_MAX then
		-- Fix calculation for very high lux values
		luxvalue = STATIC_LUX_MAX
	end
	
	-- Use the table to smooth out ambient value spikes
	table.insert(luxSmooth, luxvalue)	
	if( MAX_SMOOTHING_VALUES < #luxSmooth ) then
		table.remove(luxSmooth, 1)
	end
	
	ambient = self:getSmoothedLux(luxSmooth)	
	local brightTarget = (MAX_BRIGHTNESS_LEVEL / STATIC_LUX_MAX) * ambient

	--[[
	log:info("Ambient:      " .. tostring(ambient))
	log:info("BrightTarget: " .. tostring(brightTarget))
	log:info("Brightness:   " .. tostring(settings.brightness))	
	log:info("MinBrightness:" .. tostring(settings.brightnessMinimal))	
	]]--
	
	self:doBrightnessRamping(brightTarget);
	
	-- Make sure bright Cur stays above minimum
	if brightMin > brightCur then
		brightCur = brightMin
	end

	-- Set Brightness
	self:setBrightness( brightCur )

	--log:info("CurTarMax:    " .. tostring(brightCur) .. " - ".. tostring(brightTarget))
	
end

-- Valid Brightness goes from 1 - 100, 0 = display off
function doManualBrightnessTimer(self)
	-- First Check if it is automatic or manual brightness control
	if settings.brightnessControl == "manual" then
		if settings.brightness != brightSettings then
			self:setBrightness(settings.brightness)
			brightSettings = settings.brightness
		end
		return
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
	iconbar:update()
end

function update(self)
	 Task("statusbar", self, _updateTask):addTask()
end


function _updateTask(self)
	local iface = Networking:activeInterface()
	local player = Player:getLocalPlayer()

	if not iface then
		iconbar:setWirelessSignal(nil)
		player:setSignalStrength(nil)
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
			local status = iface:status()
			iconbar:setWirelessSignal(not status.link and "ERROR" or nil)

			if player then
				player:setSignalStrength(nil)
			end
		end
	end
end


function getBrightness (self)
	local f = io.open("/sys/class/backlight/mxc_ipu_bl.0/brightness", "r")
	local level = f:read("*a")
	f:close()

	--opposite of setBrigtness translation
	return math.floor(100 * math.pow(tonumber(level)/255, 1/1.38)) -- gives 0 to 100
end


function setBrightness (self, level)
	if level == "off" or level == 0 then
		level = 0
	elseif level == "on" then
		level = self.brightPrev
	else
		self.brightPrev = level
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

function settingsMinBrightnessShow (self, menuItem)
	local window = Window("text_list", self:string("BSP_BRIGHTNESS_MIN"), squeezeboxjiveTitleStyle)

	local settings = self:getSettings()
	local level = settings.brightnessMinimal

	local slider = Slider('brightness_slider', 1, 75, level,
				function(slider, value, done)
										
					log:info("Value: " .. value)
					settings.brightnessMinimal = value
					
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

function settingsBrightnessShow (self, menuItem)
	local window = Window("text_list", self:string("BSP_BRIGHTNESS"), squeezeboxjiveTitleStyle)

	local settings = self:getSettings()
	local level = settings.brightness

	local slider = Slider('brightness_slider', 1, 100, level,
				function(slider, value, done)
					
					if settings.brightnessControl != "manual" then
						settings.brightnessControl = "manual"
					end
					
					settings.brightness = value

					local bright = settings.brightness + settings.ambient
					if bright > 100 then
						bright = 100
					end

					if settings.brightnessControl == "manual" then
						self:setBrightness( bright)
					end
					--
					-- Quick fix to avoid error
					if settings.ambient == nil then
						settings.ambient = 0
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

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
