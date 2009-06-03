
local tonumber, tostring = tonumber, tostring

-- board specific driver
local fab4_bsp               = require("fab4_bsp")

local oo                     = require("loop.simple")
local os                     = require("os")
local io                     = require("io")
local string                 = require("string")
local math                   = require("math")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")

local Framework              = require("jive.ui.Framework")
local Group                  = require("jive.ui.Group")
local Icon                   = require("jive.ui.Icon")
local Popup                  = require("jive.ui.Popup")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Slider                 = require("jive.ui.Slider")
local RadioGroup             = require("jive.ui.RadioGroup")
local RadioButton            = require("jive.ui.RadioButton")
local Window                 = require("jive.ui.Window")

local debug                  = require("jive.utils.debug")

local jnt                    = jnt
local iconbar                = iconbar
local jiveMain               = jiveMain
local settings	             = nil

module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	local uuid, mac

	settings = self:getSettings()

	-- read device uuid
	local f = io.open("/proc/cpuinfo")
	if f then
		for line in f:lines() do
			if string.match(line, "UUID") then
				uuid = string.match(line, "UUID%s+:%s+([%x-]+)")
				uuid = string.gsub(uuid, "[^%x]", "")
			end
		end
		f:close()
	end

	System:init({
		uuid = uuid,
		machine = "fab4",
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


	settings.brightness = settings.brightness or 32
	settings.ambient = settings.ambient or 0
	settings.brightnessControl = settings.brightnessControl or "manual"

	self:initBrightness()
	local brightnessTimer = Timer( 2000,
		function()
			if settings.brightnessControl == "automatic" or 
				settings.brightnessControl == "manual" then
				self:doBrightnessTimer()
			else 
				-- fullauto
				self:doStaticBrightnessTimer()
			end
		end)
	brightnessTimer:start()
	
	Framework:addActionListener("soft_reset", self, _softResetAction, true)

	-- find out when we connect to player
	jnt:subscribe(self)

	self:storeSettings()
end

-----------------------------
-- Ambient Light Stuff Start
-----------------------------
-- Ambient SysFS Path
local AMBIENT_SYSPATH = "/sys/bus/i2c/devices/0-0039/"

-- Default/Start Values
local ambientMax = 0
local ambientMin = 1
local brightCur = 64
local brightMax = 64
local brightTarget = 64
local brightSettings = 0;

local brightOverride = 0

-- Minimum Brightness - Default:1, calculated using settings.brightness
-- 	- This variable should probably be configurable by the users
local brightMinMax = 32
local brightMin = 1

-- Maximum number of brightness levels up/down per run of the timer
local AMBIENT_RAMPSTEPS = 7

-- Initialize Brightness Stuff (Factor)
function initBrightness(self)
	self.brightPrev = brightMinMax

	-- Initialize the Ambient Sensor with a factor of 30
	local f = io.open(AMBIENT_SYSPATH .. "factor", "w")
	f:write("30")
	f:close()
		
	-- Set Initial Settings Brightness
	if not settings.brightness then
		settings.brightness = brightMax
	end

	brightSettings = settings.brightness
	brightMax = (settings.brightness/2) + brightMinMax
		
	-- Create a global listener to set 
	Framework:addListener(ACTION | EVENT_SCROLL | EVENT_MOUSE_ALL | EVENT_MOTION | EVENT_IR_ALL,
		function(event)
			if settings.brightnessControl == "manual" then 
				return
			end
					
			-- if this is a new 'touch' event set brightness to max
			if brightOverride == 0 then
				self:setBrightness( math.floor(brightCur) )
			end
			
			brightOverride = 2	
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

	if brightCur > 64 then
		brightCur = 64
	elseif brightCur < 1 then
		brightCur = 1	
	end
	
	--log:info("Cur: " .. brightCur)
end

-- Fully Automatic Brigthness

-- 3500 Is about the value I've seen in my room during full daylight
-- so set it somewhere below that
local staticLuxMax = 2000

function doStaticBrightnessTimer(self)

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
	
	local brightTarget = (64 / staticLuxMax) * luxvalue
	
	self:doBrightnessRamping(brightTarget);
	
	-- Set Brightness
	self:setBrightness( math.floor(brightCur) )
	
	--log:info("LuxValue: " .. tostring(luxvalue))
	--log:info("CurTarMax: " .. tostring(brightCur) .. " - ".. tostring(brightTarget))
	
end

-- Valid Brightness goes from 1 - 64, 0 = display off
function doBrightnessTimer(self)
	
	-- First Check if it is automatic or manual brightness control
	if settings.brightnessControl == "manual" then
		if settings.brightness != brightSettings then
			self:setBrightness(settings.brightness)
			brightSettings = settings.brightness
		end
		return
	end
	
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

	if luxvalue > ambientMax then
		ambientMax = luxvalue
	end
		
	brightTarget = (luxvalue / ambientMax) * 64
	
	-- Ramp Brightness to target unless the brightness setting has changed
	if settings.brightness != brightSettings then
		-- Directly Set Target
		brightCur = (settings.brightness/2)
		
		-- Update local brightness variables after settings change
		brightSettings = settings.brightness
		brightMax = (settings.brightness/2) + brightMinMax
	else 
		-- Do Ramping
		self:doBrightnessRamping(brightTarget)
		
	end
	
	
	-- Set Brightness
	self:setBrightness( math.floor(brightCur) )
	
	--log:info("Brightness: " .. settings.brightness)
	--log:info("CurTarMax: " .. tostring(brightCur) .. " - ".. tostring(brightTarget) .. " - " .. tostring(brightMax))
	
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


function getBrightness (self)
	local f = io.open("/sys/class/backlight/mxc_ipu_bl.0/brightness", "r")
	local level = f:read("*a")
	f:close()

	return tonumber(level / 4)
end


function setBrightness (self, level)
	if level == "off" or level == 0 then
		level = 0
	elseif level == "on" then
		level = self.brightPrev
	else
		self.brightPrev = level
	end
	local f = io.open("/sys/class/backlight/mxc_ipu_bl.0/brightness", "w")
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

					local bright = settings.brightness + settings.ambient
					if bright > 64 then
						bright = 64
					end
						  
					if settings.brightnessControl == "manual" then
						self:setBrightness( bright)
					end
					--
					-- Quick fix to avoid error					
					if settings.ambient == nil then
						settings.ambient = 0
					end

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


function settingsBrightnessAutomaticShow(self, menuItem)
	local window = Window("text_list", menuItem.text, squeezeboxjiveTitleStyle)
	local settings = self:getSettings()

	local group = RadioGroup()
	log:info("Setting: " .. settings.brightnessControl)
	local menu = SimpleMenu("menu", {
		{
			text = self:string("BSP_BRIGHTNESS_MANUAL"),
			style = "item_choice",
			check = RadioButton("radio", group, function(event, menuitem)
						settings.brightnessControl = "manual"
					end,
					settings.brightnessControl == "manual")
		},
		{
			text = self:string("BSP_BRIGHTNESS_AUTOMATIC"),
			style = "item_choice",
			check = RadioButton("radio", group, function(event, menuItem)
						settings.brightnessControl = "automatic"
					end,
					settings.brightnessControl == "automatic")
		},
		{
			text = self:string("BSP_BRIGHTNESS_FULLYAUTOMATIC"),
			style = "item_choice",
			check = RadioButton("radio", group, function(event, menuitem)
						settings.brightnessControl = "fullauto"
					end,
					settings.brightnessControl == "fullauto")
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

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
