
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

local Framework        = require("jive.ui.Framework")
local Window           = require("jive.ui.Window")
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

function openScreensaver(self, menuItem)
	self.window:show(Window.transitionFadeIn)
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

