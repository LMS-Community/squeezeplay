
-- stuff we use
local pcall, tostring = pcall, tostring

local oo                     = require("loop.simple")
local string                 = require("string")
local math                   = require("math")
local os                     = require("os")

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
local iconbar                = iconbar

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
					      self.acpower = (val == 0)
					      self:update()

					      if self.acpower then
						      self:setPowerState("ac_dimmed")
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

	-- ac or battery
	self.acpower = (jiveBSP.ioctl(23) == 0)
	if self.acpower then
		self:setPowerState("ac_dimmed")
	else
		self:setPowerState("active")
	end

	-- headphone or speaker
	local headphone = jiveBSP.ioctl(18)
	if headphone == 1 then
		jiveBSP.mixer(0, 97, 97)
		jiveBSP.mixer(5, 0, 0)
	else
		jiveBSP.mixer(0, 0, 0)
		jiveBSP.mixer(5, 97, 97)
	end

	-- set initial state
	self:update()

	-- find out when we connect to player
	jnt:subscribe(self)

	return self
end


function notify_playerCurrent(self, player)
	local sink = function(chunk, err)
			     if err then
				     log:warn(err)
				     return
			     end

			     self:setDate(chunk.data.date)

			     -- FIXME schedule updates from server
		     end

	player.slimServer.comet:request(sink,
					player:getId(),
					{ 'date' }
				)
end


function setDate(self, date)
	-- matches date format 2007-09-08T20:40:42+00:00
	local CCYY, MM, DD, hh, mm, ss, TZ = string.match(date, "(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)([-+]%d%d:%d%d)")

	log:warn("date=", date)
	log:warn("CCYY=", CCYY, " MM=", MM, " DD=", DD, " hh=", hh, " mm=", mm, " ss=", ss, " TZ=", TZ)

	-- set system date
	os.execute("date " .. MM..DD..hh..mm..CCYY.."."..ss)

	-- set RTC to system time
	os.execute("hwclock -w")

	iconbar:update()
end


function update(self)

	-- ac power / battery
	if self.acpower then
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


function _brightness(self, lcdLevel, keyLevel)
	local settings = self:getSettings()

	if lcdLevel ~= nil then
		self.lcdLevel = lcdLevel
		jiveBSP.ioctl(11, lcdLevel * 2048)
	end

	if keyLevel ~= nil then
		self.keyLevel = keyLevel
		jiveBSP.ioctl(13, keyLevel * 1024)
	end
end


function _setBrightness(self, fade, lcdLevel, keyLevel)
	-- stop existing fade
	if self.fadeTimer then
		self.fadeTimer:stop()
		self.fadeTimer = nil
	end

	if not fade then
		_brightness(self, lcdLevel, keyLevel)
		return
	end

	-- FIXME implement smooth fade in kernel using pwm interrupts

	local steps = 30
	local lcdVal = self.lcdLevel
	local lcdInc = (lcdVal - lcdLevel) / steps
	local keyVal = self.keyLevel
	local keyInc = (keyVal - keyLevel) / steps

	if lcdVal == lcdLevel and keyVal == keyLevel then
		-- already at level, nothing to do
		return
	end

	self.fadeTimer = Timer(20, function()
					   if steps == 0 then
						   if self.fadeTimer then
							   self.fadeTimer:stop()
							   self.fadeTimer = nil
						   end

						   -- ensure we hit the set value
						   _brightness(self, lcdLevel, keyLevel)
						   return
					   end

					   steps = steps - 1
					   lcdVal = lcdVal - lcdInc
					   keyVal = keyVal - keyInc
					   _brightness(self, math.ceil(lcdVal), math.ceil(keyVal))
				   end)
	self.fadeTimer:start()
end


function setBrightness(self, level)
	local settings = self:getSettings()

	if level then
		settings.brightness = level
	end

	local lcdLevel = level or settings.brightness
	local keyLevel = 0

	if self.powerState == "active" or self.powerState == "ac_active" then
		keyLevel = level or settings.brightness
	end

	_setBrightness(self, false, lcdLevel, keyLevel)
end


function settingsBrightnessShow(self, menuItem)
	local window = Window("window", menuItem.text)

	local level = jiveBSP.ioctl(12) / 2047
	log:warn("level is ", level);

	local slider = Slider("slider", 1, 32, level,
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
	if self.lockedPopup then
		-- we're locked do nothing
		return
	end

	if self.powerState == "ac_active" then
		self.powerTimer:restart()
	elseif self.powerState == "ac_dimmed" then
		self:setPowerState("ac_active")
	elseif self.powerState == "active" then
		self.powerTimer:restart()
	else
		self:setPowerState("active")
	end
end


-- called to sleep jive
function sleep(self)
	if self.powerState == "ac_active" then
		self:setPowerState("ac_dimmed")
	elseif self.powerState == "ac_dimmed" then
		-- do nothing
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
	if state == "ac_active" then
		self:setBrightness()
		interval = settings.dimmedTimeout
		
	elseif state == "ac_dimmed" then
		self:setBrightness()

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
		self:_setBrightness(true, 8, 0)
		self.isAudioEnabled = Audio:isEffectsEnabled()
		Audio:effectsEnable(false)

		interval = settings.sleepTimeout

	else
		self:_setBrightness(true, 0, 0)

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
	popup:addWidget(Icon("iconLocked"))
	popup:addWidget(Label("text", self:string("BSP_SCREEN_LOCKED")))
	popup:addWidget(Textarea("help", self:string("BSP_SCREEN_LOCKED_HELP")))
	self:tieAndShowWindow(popup)

	self.lockedPopup = popup
	self.lockedTimer = Timer(2000,
				 function()
					 self:_setBrightness(true, 0, 0)
				 end,
				 true)

	self:setPowerState("locked")

	self.lockedListener = 
		Framework:addListener(EVENT_KEY_DOWN | EVENT_KEY_PRESS,
				      function(event)
					      if event:getType() == EVENT_KEY_PRESS and event:getKeycode() == (KEY_ADD | KEY_PLAY) then
						      lockScreen(self)
						      return EVENT_CONSUME
					      end

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


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
