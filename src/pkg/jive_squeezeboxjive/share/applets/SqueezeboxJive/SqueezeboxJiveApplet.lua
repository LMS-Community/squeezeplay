
-- stuff we use
local pcall, tostring = pcall, tostring

local oo                     = require("loop.simple")
local string                 = require("string")
local math                   = require("math")

local jiveBSP                = require("jiveBSP")
local Wireless               = require("jive.net.Wireless")

local Applet                 = require("jive.Applet")
local Audio                  = require("jive.ui.Audio")
local Font                   = require("jive.ui.Font")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Slider                 = require("jive.ui.Slider")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Tile                   = require("jive.ui.Tile")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")

local log                    = require("jive.utils.log").logger("applets.setup")

local jnt                    = jnt

local EVENT_ACTION           = jive.ui.EVENT_ACTION
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP
local LAYER_FRAME            = jive.ui.LAYER_FRAME
local LAYER_CONTENT_ON_STAGE = jive.ui.LAYER_CONTENT_ON_STAGE

local LAYOUT_NORTH           = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST            = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH           = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST            = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER          = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE            = jive.ui.LAYOUT_NONE

local EVENT_KEY_DOWN         = jive.ui.EVENT_KEY_DOWN
local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL           = jive.ui.EVENT_SCROLL
local EVENT_SWITCH           = 0x400000 -- XXXX fixme when public
local EVENT_MOTION           = 0x800000 -- XXXX fixme when public
local EVENT_WINDOW_PUSH      = jive.ui.EVENT_WINDOW_PUSH
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_UNUSED           = jive.ui.EVENT_UNUSED

local KEY_ADD                = jive.ui.KEY_ADD
local KEY_PLAY               = jive.ui.KEY_PLAY

local SW_AC_POWER            = 0
local SW_PHONE_DETECT        = 1


module(...)
oo.class(_M, Applet)


function init(self)

	self.Wireless = Wireless(jnt, "eth0")

	self.iconWireless = Icon("")
	self.iconBattery = Icon("")

	Framework:addWidget(self.iconWireless)
	Framework:addWidget(self.iconBattery)

	self.iconWireless:addTimer(5000,  -- every 5 seconds
				  function() 
					  self:update()
				  end)

	Framework:addListener(EVENT_SWITCH,
			      function(event)
				      local type = event:getType()
				      local sw,val = event:getSwitch()

				      if sw == SW_AC_POWER then
					      self:update()
					      if val == 0 then
						      self:setPowerState("power")
						      self.iconBattery:playSound("DOCKING")
					      else
						      self:setPowerState("active")
					      end

				      elseif sw == SW_PHONE_DETECT then
					      if val == 1 then
						      jiveBSP.mixer(0, 97, 97)
						      jiveBSP.mixer(5, 0, 0)
					      else
						      jiveBSP.mixer(0, 0, 0)
						      jiveBSP.mixer(5, 97, 97)
					      end
				      end

				      return EVENT_CONSUME
			      end)

	-- power management
	self.powerTimer = Timer(0, function() sleep(self) end)
	Framework:addListener(EVENT_SCROLL | EVENT_MOTION,
			      function(event) 
				      wakeup(self)
				      return EVENT_UNUSED
			      end)

	Framework:addListener(EVENT_WINDOW_PUSH,
			      function(event) 
				      if self.powerState == "active" then
					      wakeup(self)
				      end
				      return EVENT_UNUSED
			      end)

	Framework:addListener(EVENT_KEY_PRESS,
			      function(event) 
				      local keycode = event:getKeycode()

				      -- key lock
				      if keycode == (KEY_ADD | KEY_PLAY) then
					      lockScreen(self)
					      return EVENT_CONSUME
				      end

				      wakeup(self)
				      return EVENT_UNUSED
			      end)

	local nACPR = jiveBSP.ioctl(23)
	if nACPR == 0 then
		self:setPowerState("power")
	else
		self:setPowerState("active")
	end

	-- set initial state
	self:update()

	return self
end


function update(self)

	-- ac power / battery
	local nACPR = jiveBSP.ioctl(23)
	if nACPR == 0 then
		local nCHRG = jiveBSP.ioctl(25)
		if nCHRG == 0 then
			self.iconBattery:setStyle("iconBatteryCharging")
		else
			self.iconBattery:setStyle("iconBatteryAC")
		end
	else
		local bat = jiveBSP.ioctl(17)
		if bat < 190 then
			self.iconBattery:setStyle("iconBattery0")
		elseif bat < 195 then
			self.iconBattery:setStyle("iconBattery1")
		elseif bat < 200 then
			self.iconBattery:setStyle("iconBattery2")
		elseif bat < 205 then
			self.iconBattery:setStyle("iconBattery3")
		else
			self.iconBattery:setStyle("iconBattery4")
		end
	end

	-- wireless strength
	local quality = self.Wireless:getLinkQuality()

	if quality == nil then
		self.iconWireless:setStyle("iconWirelessOff")
	else
		self.iconWireless:setStyle("iconWireless" .. quality)
	end
end


function _brightness(self, level)
	local settings = self:getSettings()

	level = level or settings.brightness

	log:debug("brightness level=", level, " value=", (level * 128))
	self.brightnessLevel = level
	jiveBSP.ioctl(11, level * 128)
	jiveBSP.ioctl(13, level * 128)
end


function _fadeBrightness(self, level)
	local s = 20
	local l = self.brightnessLevel
	local i = (l - level) / s

	if l == level then
		-- already at level, nothing to do
		return
	end

	self.fadeTimer = Timer(30, function()
					    if s == 0 then
						    if self.fadeTimer then
							    self.fadeTimer:stop()
							    self.fadeTimer = nil
						    end
						    return
					    end

					    s = s - 1
					    l = l - i
					    _brightness(self, math.ceil(l))

				    end)
	self.fadeTimer:start()
end


function setBrightness(self, level)
	local settings = self:getSettings()

	if self.fadeTimer then
		self.fadeTimer:stop()
		self.fadeTimer = nil
	end

	if level then
		settings.brightness = level
	end
	self:_brightness()
end


function settingsBrightnessShow(self, menuItem)
	local window = Window("window", menuItem.text)

	local level = jiveBSP.ioctl(12) / 128
	log:warn("level is ", level);

	local slider = Slider("slider", 8, 32, level,
			      function(slider, value)
				      self:setBrightness(value)
			      end)

	local help = Textarea("help", self:string("BSP_BRIGHTNESS_ADJUST_HELP"))

	window:addWidget(help)
	window:addWidget(slider)

	self:tieAndShowWindow(window)
	return window
end


function setBacklightTimeout(self, timeout)
	local settings = self:getSettings()
	settings.dimmedTimeout = timeout

	self:setPowerState(self.powerState)	
end


function settingsBacklightTimerShow(self, menuItem)
	local window = Window("window", menuItem.text)

	local settings = self:getSettings()
	local timeout = settings.dimmedTimeout

	local group = RadioGroup()
	local menu = SimpleMenu("menu", {
					{
						text = self:string("BSP_TIMER_10_SEC"),
						icon = RadioButton("radio", group, function() self:setBacklightTimeout(10000) end, timeout == 10000),
					},
					{
						text = self:string("BSP_TIMER_20_SEC"),
						icon = RadioButton("radio", group, function() self:setBacklightTimeout(20000) end, timeout == 20000),
					},
					{
						text = self:string("BSP_TIMER_30_SEC"),
						icon = RadioButton("radio", group, function() self:setBacklightTimeout(30000) end, timeout == 30000),
					},
					{
						text = self:string("BSP_TIMER_1_MIN"),
						icon = RadioButton("radio", group, function() self:setBacklightTimeout(60000) end, timeout == 60000),
					},
					{
						text = self:string("BSP_TIMER_NEVER"),
						icon = RadioButton("radio", group, function() self:setBacklightTimeout(0) end, timeout == 0),
					}
				})

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


-- called to wake up jive
function wakeup(self)
	if self.powerState == "power" then
		-- do nothing
	elseif self.powerState == "active" then
		self.powerTimer:restart()
	elseif not self.lockedPopup then
		self:setPowerState("active")
	end
end


-- called to sleep jive
function sleep(self)
	if self.powerState == "power" then
		log:warn("sleep should not be called in 'power' state")
	elseif self.powerState == "active" then
		self:setPowerState("dimmed")
	elseif self.powerState == "locked" then
		self:setPowerState("sleep")
	elseif self.powerState == "dimmed" then
		self:setPowerState("sleep")
	elseif self.powerState == "sleep" then
		self:setPowerState("hibernate")
	elseif self.powerState == "hibernate" then
		-- we can't go to sleep anymore
	end
end


-- set the power state and update devices
function setPowerState(self, state)
	local settings = self:getSettings()

	log:warn("setPowerState=", state)
	self.powerState = state

	-- kill the timer
	self.powerTimer:stop()

	local interval = 0
	if state == "power" then
		self:setBrightness()
		return

	elseif state == "active" then
		self:setBrightness()
		if self.isAudioEnabled ~= nil then
			Audio:effectsEnable(self.isAudioEnabled)
			self.isAudioEnabled = nil
		end
		interval = settings.dimmedTimeout

	elseif state == "locked" then
		self:setBrightness()
		self.lockedTimer:restart()
		if self.isAudioEnabled ~= nil then
			Audio:effectsEnable(self.isAudioEnabled)
			self.isAudioEnabled = nil
		end
		interval = settings.dimmedTimeout

	elseif state == "dimmed" then
		self:_fadeBrightness(8)
		self.isAudioEnabled = Audio:isEffectsEnabled()
		Audio:effectsEnable(false)

		interval = settings.sleepTimeout

	else
		self:_fadeBrightness(0)

		if state == "sleep" then
			interval = settings.hibernateTimeout
		elseif state == "hibernate" then
			log:error("FIXME hibernate now...")
		end
	end

	if interval > 0 then
		log:warn("interval=", interval)
		self.powerTimer:setInterval(interval)
		self.powerTimer:start()
	end
end


function lockScreen(self)
	log:warn("lock screen")

	if self.lockedPopup then
		-- unlock
		Framework:removeListener(self.lockedListener)
		self.lockedTimer:stop()
		self.lockedPopup:hide()

		self.lockedPopup = nil
		self.lockedTimer = nil
		self.lockedListener = nil

		return
	end

	-- lock
	local popup = Popup("popupIcon")
	-- FIXME change icon and text
	popup:addWidget(Icon("iconConnected"))
	popup:addWidget(Textarea("text", self:string("BSP_SCREEN_LOCKED")))
	self:tieAndShowWindow(popup)

	self.lockedPopup = popup
	self.lockedTimer = Timer(2000,
				 function()
					 self:_fadeBrightness(0)
				 end,
				 true)

	self:setPowerState("locked")

	self.lockedListener = Framework:addListener(EVENT_KEY_DOWN | EVENT_KEY_PRESS | EVENT_SCROLL,
						    function()
							    self:setPowerState("locked")
							    return EVENT_CONSUME
						    end,
						    true)
end


function factoryReset(self, menuItem)
	local window = Window("window", menuItem.text)

	local menu = SimpleMenu("menu", {
					{
						text = "Cancel",
						callback = function()
								   window:hide()
							   end
					},
					{
						text = "Continue",
						callback = function()
								   self:_doFactoryReset()
							   end
					},
				})

	window:addWidget(menu)

	return window
end


function _doFactoryReset(self)
	local window = Popup("popupIcon")
	window:addWidget(Icon("iconConnected"))
	window:addWidget(Textarea("text", "Rebooting"))

	window:addTimer(2000, function()
				      log:warn("Factory reset...")

				      -- touch .factoryreset and reboot
				      io.open("/.factoryreset", "w"):close()
				      os.execute("/bin/busybox reboot -n -f")
			      end)

	self:tieAndShowWindow(window)
end




-- skin
local imgpath = "applets/SqueezeboxJive/images/"
local skinimgpath = "applets/DefaultSkin/images/"
local fontpath = "fonts/"

local function _icon(var, x, y, img)
	var.x = x
	var.y = y
	var.img = Surface:loadImage(imgpath .. img)
	var.layer = LAYER_FRAME
	var.position = LAYOUT_SOUTH
end

function skin(self, s)
	local screenWidth, screenHeight = Framework:getScreenSize()

	Framework:loadSound("DOCKING", "applets/SqueezeboxJive/sounds/docking.wav", 1)

	-- wireless status
	_icon(s.iconWireless0, 107, screenHeight - 30, "icon_wireless_0.png")
	_icon(s.iconWireless1, 107, screenHeight - 30, "icon_wireless_1.png")
	_icon(s.iconWireless2, 107, screenHeight - 30, "icon_wireless_2.png")
	_icon(s.iconWireless3, 107, screenHeight - 30, "icon_wireless_3.png")
	_icon(s.iconWireless4, 107, screenHeight - 30, "icon_wireless_4.png")
	_icon(s.iconWirelessOff, 107, screenHeight - 30, "icon_wireless_off.png")

	-- battery status
	_icon(s.iconBatteryAC, 137, screenHeight - 30, "icon_battery_ac.png")

	_icon(s.iconBatteryCharging, 137, screenHeight - 30, "icon_battery_charging.png")
	_icon(s.iconBattery0, 137, screenHeight - 30, "icon_battery_0.png")
	_icon(s.iconBattery1, 137, screenHeight - 30, "icon_battery_1.png")
	_icon(s.iconBattery2, 137, screenHeight - 30, "icon_battery_2.png")
	_icon(s.iconBattery3, 137, screenHeight - 30, "icon_battery_3.png")
	_icon(s.iconBattery4, 137, screenHeight - 30, "icon_battery_4.png")

	s.iconBatteryCharging.frameRate = 1
	s.iconBatteryCharging.frameWidth = 37


	-- wireless icons for menus
	s.wirelessLevel0.img = Surface:loadImage(imgpath .. "icon_wireless_0_shadow.png")
	s.wirelessLevel1.img = Surface:loadImage(imgpath .. "icon_wireless_1_shadow.png")
	s.wirelessLevel2.img = Surface:loadImage(imgpath .. "icon_wireless_2_shadow.png")
	s.wirelessLevel3.img = Surface:loadImage(imgpath .. "icon_wireless_3_shadow.png")
	s.wirelessLevel4.img = Surface:loadImage(imgpath .. "icon_wireless_4_shadow.png")

	s.iconConnecting.img = Surface:loadImage(imgpath .. "icon_connecting.png")
	s.iconConnecting.frameRate = 4
	s.iconConnecting.frameWidth = 161
	s.iconConnecting.align = "center"

	s.iconConnected.img = Surface:loadImage(imgpath .. "icon_connected.png")
	s.iconConnected.align = "center"
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
