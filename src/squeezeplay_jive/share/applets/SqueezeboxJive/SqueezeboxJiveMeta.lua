
local pairs = pairs

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local LocalPlayer   = require("jive.slim.LocalPlayer")
local SlimServer    = require("jive.slim.SlimServer")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return { 
		brightness	= 32,
		dimmedTimeout	= 10000,	-- 10 seconds
		sleepTimeout	= 60000,	-- 60 seconds
		suspendWhenPlayingTimeout = 2400000, -- 40 minutes
		suspendWhenStoppedTimeout = 1200000, -- 20 minutes
		suspendEnabled  = true,
		dimmedAC	= false,
		wlanPSEnabled   = true,

		alsaPlaybackDevice = "default",
		alsaPlaybackBufferTime = 30000,
		alsaPlaybackPeriodCount = 2,
		alsaSampleSize = 16,
	}
end


function upgradeSettings(meta, settings)
	-- fix broken settings
	if not settings.brightness or settings.brightness > 40 then
		settings.brightness = 40	-- max
	end

	-- fill in any blanks
	local defaults = defaultSettings(meta)
	for k, v in pairs(defaults) do
		-- Bug 15566: Check if setting is missing and not whether its value is false
		if settings[k] == nil then
			settings[k] = v
		end
	end

	return settings
end


function registerApplet(meta)
	-- Fixup settings after upgrade
	local settings = meta:getSettings()
	if not settings.suspendWhenPlayingTimeout then
		settings.suspendTimeout = nil
		settings.suspendWhenPlayingTimeout = 2400000
		settings.suspendWhenStoppedTimeout = 1200000
		meta:storeSettings()
	end


	-- Set player device type
	LocalPlayer:setDeviceType("controller", "Controller")

	-- SH hostname
	jnt:setSNHostname("jive.squeezenetwork.com")

	-- Set the minimum support server version
	SlimServer:setMinimumVersion("7.0")

	-- SqueezeboxJive is a resident Applet
	appletManager:loadApplet("SqueezeboxJive")

	-- audio playback defaults
	appletManager:addDefaultSetting("Playback", "enableAudio", 2)

	jiveMain:addItem(meta:menuItem('backlightSetting', 'screenSettings', "BSP_BACKLIGHT_TIMER", function(applet, ...) applet:settingsBacklightTimerShow(...) end))
	jiveMain:addItem(meta:menuItem('brightnessSetting', 'screenSettings', "BSP_BRIGHTNESS", function(applet, ...) applet:settingsBrightnessShow(...) end))
	jiveMain:addItem(meta:menuItem('powerDown', 'advancedSettings', "POWER_DOWN", function(applet, ...) applet:settingsPowerDown(...) end))
	jiveMain:addItem(meta:menuItem('suspendTest', 'factoryTest', "POWER_MANAGEMENT_SETTINGS", function(applet, ...) applet:settingsTestSuspend(...) end, _, { noCustom = 1 }))

	meta:registerService("getBrightness")
	meta:registerService("setBrightness")
	meta:registerService("isBatteryLow")
	meta:registerService("poweroff")
	meta:registerService("reboot")
	meta:registerService("wasLastShutdownUnclean")
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

