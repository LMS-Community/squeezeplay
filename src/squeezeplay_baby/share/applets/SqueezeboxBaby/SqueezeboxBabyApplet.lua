
local tonumber, tostring = tonumber, tostring

-- board specific driver
local baby_bsp               = require("baby_bsp")

local oo                     = require("loop.simple")
local os                     = require("os")
local io                     = require("io")
local string                 = require("string")
local math                   = require("math")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")

local Networking             = require("jive.net.Networking")

local Framework              = require("jive.ui.Framework")
local Group                  = require("jive.ui.Group")
local Icon                   = require("jive.ui.Icon")
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

	-- watchdog timer
	local watchdog = io.open("/var/run/squeezeplay.wdog", "w")
	if watchdog then
		io.close(watchdog)

		local timer = Timer(2000, function()
			local watchdog = io.open("/var/run/squeezeplay.wdog", "w")
			io.close(watchdog)
		end)
		timer:start()
	else
		log:warn("Watchdog timer is disabled")
	end

	-- status bar updates
	self:update()
	iconbar.iconWireless:addTimer(5000, function()  -- every 5 seconds
	      self:update()
	end)

	Framework:addActionListener("soft_reset", self, _softResetAction, true)

	-- find out when we connect to player
	jnt:subscribe(self)

	self:storeSettings()
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


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
