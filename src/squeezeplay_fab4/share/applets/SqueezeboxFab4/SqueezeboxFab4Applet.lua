
local tonumber, tostring = tonumber, tostring

-- board specific driver
local fab4_bsp               = require("fab4_bsp")

local oo                     = require("loop.simple")
local os                     = require("os")
local io                     = require("io")
local string                 = require("string")

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


module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	local uuid, mac

	local settings = self:getSettings()

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
		local window = Window("one_button", self:string("INVALID_MAC_TITLE"))

		window:setAllowScreensaver(false)
		window:setAlwaysOnTop(true)
		window:setAutoHide(false)

		local text = Textarea("text", self:string("INVALID_MAC_TEXT"))
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

	self:setBrightness(settings.brightness or 64)

	-- find out when we connect to player
	jnt:subscribe(self)
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
	local window = Window("window", menuItem.text, squeezeboxjiveTitleStyle)

	local settings = self:getSettings()
	local level = self:getBrightness()

	local slider = Slider("slider", 1, 64, level,
			      function(slider, value, done)
				      self:setBrightness(value)
				      settings.brightness = value

				      if done then
					      window:playSound("WINDOWSHOW")
					      window:hide(Window.transitionPushLeft)
				      end
			      end)

	window:addWidget(Textarea("helptext", self:string("BSP_BRIGHTNESS_ADJUST_HELP")))
	window:addWidget(Group("sliderGroup", {
				       Icon("sliderMin"),
				       slider,
				       Icon("sliderMax")
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
