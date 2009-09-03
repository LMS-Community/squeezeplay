
local pcall, unpack, tonumber, tostring = pcall, unpack, tonumber, tostring

local oo                     = require("loop.simple")
local os                     = require("os")
local io                     = require("io")
local string                 = require("jive.utils.string")
local table                  = require("jive.utils.table")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")

local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Event                  = require("jive.ui.Event")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local Task                   = require("jive.ui.Task")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Window                 = require("jive.ui.Window")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("applet.SqueezeboxSqueezeOS")

local jnt                    = jnt
local jiveMain               = jiveMain
local appletManager          = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


function sysOpen(self, path, attr, mode)
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


function sysReadNumber(self, attr)
	local fh = self["sysr_" .. attr]
	if not fh then
		return -1
	end

	fh:seek("set")

	local line, err = fh:read("*a")
	if err then
		return 0
	else
		return tonumber(line)
	end
end


function sysWrite(self, attr, val)
	local fh = self["sysw_" .. attr]
	if not fh then
		return -1
	end

	fh:write(val)
	fh:flush(val)
end


-- read uuid, serial and revision from cpuinfo
function parseCpuInfo(self)
	local f = io.open("/proc/cpuinfo")
	if f then
		for line in f:lines() do
			if string.match(line, "UUID") then
				local uuid = string.match(line, "UUID%s+:%s+([%x-]+)")
				self._uuid = string.gsub(uuid, "[^%x]", "")
			end

			if string.match(line, "Serial") then
				local serial = string.match(line, "Serial%s+:%s+([%x-]+)")
				self._serial = string.gsub(serial, "[^%x]", "")
			end

			if string.match(line, "Revision") then
				self._revision = tonumber(string.match(line, ".+:%s+([^%s]+)"))
			end
		end
		f:close()
	end
end


function verifyMacUUID(self)
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
end


function playSplashSound(self)
	local settings = self:getSettings()

	if settings.cleanReboot == false then
		-- unclean reboot, not splash sound
		log:info("unclean reboot")
		return
	end

	settings.cleanReboot = false
	self:storeSettings()

	-- The startup sound needs to be played with the minimum
	-- delay, load and play it first
	appletManager:callService("loadSounds", "STARTUP")
	Framework:playSound("STARTUP")
end


function _cleanReboot(self)
	local settings = self:getSettings()

	settings.cleanReboot = true
	self:storeSettings()
end


-- power off
function poweroff(self)
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

	_cleanReboot(self)

	local timer = Timer(4000, function()
		-- force poweroff (don't go through init)
		os.execute("/bin/busybox poweroff -f")
	end)
	timer:start()
end


-- low battery
function lowBattery(self)
	if self.lowBatteryWindow then
		return
	end

	log:info("battery low")

	local popup = Popup("waiting_popup")

	popup:addWidget(Icon("icon_battery_low"))
	popup:addWidget(Label("text", self:string("BATTERY_LOW")))
	popup:addWidget(Label("subtext", self:string("BATTERY_LOW_2")))

	-- make sure this popup remains on screen
	popup:setAllowScreensaver(false)
	popup:setAlwaysOnTop(true)
	popup:setAutoHide(false)
	popup:ignoreAllInputExcept({})

	popup:show()

	-- FIXME jive made sure the brightness was on (do we really
	-- want this, I don't think so as it may wake people up)

	self.lowBatteryTimer = Timer(30000, function()
		-- force poweroff (don't go through init)
		os.execute("/bin/busybox poweroff -f")
	end)
	self.lowBatteryTimer:start()

	self.lowBatteryWindow = popup
end


-- low battery cancel
function lowBatteryCancel(self)
	if not self.lowBatteryWindow then
		return
	end

	log:info("battery low cancelled")

	self.lowBatteryTimer:stop()
	self.lowBatteryWindow:hide()

	self.lowBatteryTimer = nil
	self.lowBatteryWindow = nil
end


-- reboot
function reboot(self)
	_cleanReboot(self)

	-- force reboot (don't go through init)
	os.execute("/bin/busybox reboot -f")
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
