
local pairs = pairs

local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local LocalPlayer   = require("jive.slim.LocalPlayer")
local SlimServer    = require("jive.slim.SlimServer")

local Sample        = require("squeezeplay.sample")

local appletManager = appletManager
local jive          = jive
local jiveMain      = jiveMain
local jnt           = jnt


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return {
		initTimeout = 60000,		-- 60 seconds
		idleTimeout = 30000,		-- 30 seconds
		sleepTimeout = 10 * 60000,	-- 10 minutes
		hibernateTimeout = 20 * 60000,	-- 20 minutes (30 minutes after idle)

		-- audio settings
		alsaPlaybackDevice = "default",
		alsaCaptureDevice = "dac",
		alsaPlaybackBufferTime = 20000,
		alsaPlaybackPeriodCount = 2,
		alsaSampleSize = 16,
	}
end


function upgradeSettings(meta, settings)
	-- fill in any blanks
	local defaults = defaultSettings(meta)
	for k, v in pairs(defaults) do
		if not settings[k] then
			settings[k] = v
		end
	end

	return settings
end


function registerApplet(meta)
        -- profile functions, 1 second warn, 10 second die - this cuts down app performance so only use for testing....
--        jive.perfhook(1000, 10000)

	-- Set player device type
	LocalPlayer:setDeviceType("baby", "Squeezebox Radio")

	-- Set the minimum support server version
	SlimServer:setMinimumVersion("7.4")

	-- System sound effects attenuation
	Sample:setEffectAttenuation(Sample.MAXVOLUME / 25)

	-- SN hostname
	jnt:setSNHostname("baby.squeezenetwork.com")

	-- BSP is a resident Applet
	appletManager:loadApplet("SqueezeboxBaby")


	-- audio playback defaults
	appletManager:addDefaultSetting("Playback", "enableAudio", 1)
	appletManager:addDefaultSetting("ScreenSavers", "whenStopped", "false:false")
	appletManager:addDefaultSetting("ScreenSavers", "whenOff", "Clock:openDetailedClockBlack")

	jiveMain:setDefaultSkin("QVGAlandscapeSkin")

	-- settings
	jiveMain:addItem(meta:menuItem('brightnessSetting', 'settingsBrightness', "BSP_BRIGHTNESS_MANUAL", function(applet, ...) applet:settingsBrightnessShow(...) end, _, _, "hm_settingsBrightness"))
	jiveMain:addItem(meta:menuItem('minBrightnessSetting', 'settingsBrightness', "BSP_BRIGHTNESS_MIN", function(applet, ...) applet:settingsMinBrightnessShow(...) end)) 
	jiveMain:addItem(meta:menuItem('brightnessSettingControl', 'settingsBrightness', "BSP_BRIGHTNESS_CTRL", function(applet, ...) applet:settingsBrightnessControlShow(...) end, _, _, "hm_settingsBrightness"))

	-- services
	meta:registerService("getBrightness")
	meta:registerService("setBrightness")
	meta:registerService("getWakeupAlarm")
	meta:registerService("setWakeupAlarm")
	meta:registerService("getDefaultWallpaper")
	meta:registerService("performHalfDuplexBugTest")
	meta:registerService("poweroff")
	meta:registerService("lowBattery")
	meta:registerService("lowBatteryCancel")
	meta:registerService("isBatteryLow")
	meta:registerService("reboot")
	meta:registerService("wasLastShutdownUnclean")
	meta:registerService("isLineInConnected")
	meta:registerService("overrideAudioEndpoint")	-- 'Speaker' | 'Headphone' | nil => default
end


function configureApplet(meta)
	local applet = appletManager:getAppletInstance("SqueezeboxBaby")

	applet:_configureInit()
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

