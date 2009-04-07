
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
local Window                 = require("jive.ui.Window")

local Watchdog               = require("jiveWatchdog")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("applets.setup")


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


	-- watchdog timer
	self.watchdog = Watchdog:open()
	if self.watchdog then
		-- allow 30 seconds to boot
		self.watchdog:setTimeout(30)
		local timer = Timer(2000, -- 2 seconds
			function()
				-- 10 second when running
				if not self.watchdogRunning then
					self.watchdog:setTimeout(10)
					self.watchdogRunning = true
				end
				self.watchdog:keepAlive()
			end)
		timer:start()
	else
		log:warn("Watchdog timer is disabled")
	end

	settings.brightness = settings.brightness or 64
	settings.ambient = settings.ambient or 0
	self:setBrightness( settings.brightness)

	local brightnessTimer = Timer( 2000,
		function()
                        local bright = settings.brightness
                        if bright > 64 then
                                bright = 64
                        end
                        self:setBrightness( bright)
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
local brightTarget = 64

-- Minimum Brightness - Default:1, calculated using settings.brightness
-- 	- This variable should probably be configurable by the users
local brightMinMax = 32
local brightMin = 1

-- Maximum number of brightness levels up/down per run of the timer
local AMBIENT_RAMPSTEPS = 7

-- Initialize Brightness Stuff (Factor)
function initBrightness(self)
        -- Initialize the Ambient Sensor with a factor of 30
        local f = io.open(AMBIENT_SYSPATH .. "factor", "w")
        f:write("30")
        f:close()
end

-- Valid Brighness goes from 1 - 64, 0 = display off
function doBrightnessTimer(self)
        local f = io.open(AMBIENT_SYSPATH .. "lux")
        local lux = f:read("*all")
        f:close()

        local luxvalue = tonumber(string.sub(lux, 0, string.len(lux)-1))

        if luxvalue > ambientMax then
                ambientMax = luxvalue
        end
	brightTarget = (luxvalue / ambientMax) * 64
	
	-- Ramp Brightness to target
	local diff = 0
	diff = (brightTarget - brightCur)
	if math.abs(diff) > AMBIENT_RAMPSTEPS then
		diff = AMBIENT_RAMPSTEPS
		
		-- is there an easier solution for this?
		if brightCur > brightTarget then
			diff = diff * -1.0
		end
	end
	
	brightCur = brightCur + diff	
	brightMin = brightMinMax / settings.brightness * brightMinMax
	if brightMin < 1 then
		brightMin = 1
	end

	-- Limit to 64 max
	if brightCur > 64 then
		brightCur = 64
	elseif brightCur < brightMin then
		brightCur = brightMin	
	end
	
	-- Set Brightness
	self:setBrightness( math.floor(brightCur) )
	
	log:debug("Brightness: " .. settings.brightness)
	log:debug("CurTarMax: " .. tostring(brightCur) .. " - ".. tostring(brightTarget) .. " - " .. tostring(ambientMax))
	
	-- Set Settings Value
	settings.ambient = ambientCur
end

---
-- END BRIGHTNESS
---


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


function getBrightness (self)
	local f = io.open("/sys/class/backlight/mxc_ipu_bl.0/brightness", "r")
	local level = f:read("*a")
	f:close()

	return tonumber(level / 4)
end


function setBrightness (self, level)
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


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
