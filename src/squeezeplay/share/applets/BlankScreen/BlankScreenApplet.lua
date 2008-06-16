
--[[
=head1 NAME

applets.BlankScreen.BlankScreenApplet - A screensaver displaying a BlankScreen photo stream.

=head1 DESCRIPTION

This screensaver applet blanks the screen

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
BlankScreenApplet overrides the following methods:

=cut
--]]


-- stuff we use
local oo               = require("loop.simple")

--local jiveBSP          = require("jiveBSP")
local Framework        = require("jive.ui.Framework")
local Window           = require("jive.ui.Window")
local Timer            = require("jive.ui.Timer")
local Surface          = require("jive.ui.Surface")
local Icon             = require("jive.ui.Icon")
local debug            = require("jive.utils.debug")
local log              = require("jive.utils.log").logger("applets.screensavers")

local jnt              = jnt
local appletManager    = appletManager

module(..., Framework.constants)
oo.class(_M, Applet)

function init(self)

	self.sw, self.sh = Framework:getScreenSize()

	-- create window and icon
	self.window = Window("window")
	self.bg  = Surface:newRGBA(self.sw, self.sh)
	self.bg:filledRectangle(0, 0, self.sw, self.sh, 0x000000FF)

	self.bgicon = Icon("background", self.bg)
	self.window:addWidget(self.bgicon)

	-- register window as a screensaver
	local manager = appletManager:getAppletInstance("ScreenSavers")
	manager:screensaverWindow(self.window, true)

end

function closeScreensaver(self)
	_brightness(self.lcdLevel, self.keyLevel)
end

function openScreensaver(self, menuItem)
	self.window:show(Window.transitionFadeIn)
	local lcdTimer = Timer(2000,
                function()
			_brightness(0, 0)
                end,
                true)
	lcdTimer:start()
end

function _brightness(lcdLevel, keyLevel)

	--[[ FIXME, don't use ioctl calls here, 
	but instead register some brightness services from SqueezeboxJive and use those
	this will be added when the SlimDiscovery refactoring work is merged in

	if lcdLevel ~= nil then
		-- don't update the screen when the lcd is off
		--Framework:setUpdateScreen(lcdLevel ~= 0)
		jiveBSP.ioctl(11, lcdLevel * 2048)
	end

	if keyLevel ~= nil then
		jiveBSP.ioctl(13, keyLevel * 512)
	end
	--]]

end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

