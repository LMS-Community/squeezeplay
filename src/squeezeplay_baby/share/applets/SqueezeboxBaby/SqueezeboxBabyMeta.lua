
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local LocalPlayer   = require("jive.slim.LocalPlayer")
local SlimServer    = require("jive.slim.SlimServer")

local Sample        = require("squeezeplay.sample")

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
		brightness = 40,		-- max
		brightnessControl = "manual", -- Automatic Brightness
		initTimeout = 60000,		-- 60 seconds
		dimmedTimeout = 30000,		-- 30 seconds
	}
end


function upgradeSettings(meta, settings)
	if not settings.brightness or settings.brightness > 40 then
		settings.brightness = 40	-- max
	end
	if not settings.brightnessControl then
		settings.brightnessControl = "manual"
	end
	if not settings.initTimeout then
		settings.initTimeout = 60000	-- 60 seconds
	end
	if not settings.dimmedTimeout then
		settings.dimmedTimeout = 30000	-- 30 seconds
	end

	return settings
end


function registerApplet(meta)
	-- Set player device type
	LocalPlayer:setDeviceType("baby", "Squeezebox Radio")

	-- Set the minimum support server version
	SlimServer:setMinimumVersion("7.4")

	-- System sound effects attenuation
	Sample:setEffectAttenuation(Sample.MAXVOLUME / 25)

	-- Bug 9900
	-- Use SN test during development
	jnt:setSNHostname("baby.squeezenetwork.com")

	-- BSP is a resident Applet
	appletManager:loadApplet("SqueezeboxBaby")


	-- audio playback defaults
	appletManager:addDefaultSetting("Playback", "enableAudio", 1)

	appletManager:addDefaultSetting("Playback", "alsaPlaybackDevice", "default")
	appletManager:addDefaultSetting("Playback", "alsaCaptureDevice", "dac")
	appletManager:addDefaultSetting("Playback", "alsaPlaybackBufferTime", 20000)
	appletManager:addDefaultSetting("Playback", "alsaPlaybackPeriodCount", 2)

	jiveMain:setDefaultSkin("QVGAlandscapeSkin")

	-- settings
	jiveMain:addItem(meta:menuItem('brightnessSetting', 'settingsBrightness', "BSP_BRIGHTNESS", function(applet, ...) applet:settingsBrightnessShow(...) end))
	jiveMain:addItem(meta:menuItem('brightnessSettingControl', 'settingsBrightness', "BSP_BRIGHTNESS_CTRL", function(applet, ...) applet:settingsBrightnessControlShow(...) end))

	-- services
	meta:registerService("getBrightness")
	meta:registerService("setBrightness")
	meta:registerService("getDefaultWallpaper")
	meta:registerService("performHalfDuplexBugTest")
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

