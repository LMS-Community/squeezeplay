
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
local Group            = require("jive.ui.Group")
local Label            = require("jive.ui.Label")
local debug            = require("jive.utils.debug")
local datetime         = require("jive.utils.datetime")
local System           = require("jive.System")
local Applet        = require("jive.Applet")

local jnt              = jnt
local appletManager    = appletManager

module(..., Framework.constants)
oo.class(_M, Applet)


function closeScreensaver(self)
	-- nothing to do here, brightness is refreshed via window event handler in init()
end

function openScreensaver(self, menuItem)
	self.sw, self.sh = Framework:getScreenSize()

	-- create window and icon
	self.window = Window("text_list")
	self.bg  = Surface:newRGBA(self.sw, self.sh)
	self.bg:filledRectangle(0, 0, self.sw, self.sh, 0x000000FF)

	self.bgicon = Icon("icon", self.bg)
	self.window:addWidget(self.bgicon)

	self.window:setShowFrameworkWidgets(false)

	self.window:addListener(EVENT_WINDOW_ACTIVE | EVENT_HIDE,
		function(event)
			local type = event:getType()
			if type == EVENT_WINDOW_ACTIVE then
				self:_setBrightness("off")
			else
				self:_setBrightness("on")
			end
			return EVENT_UNUSED
		end,
		true
	)

	self.window:addListener(EVENT_MOTION,
		function()
			self.window:hide()
			return EVENT_CONSUME
		end)

	-- register window as a screensaver
	local manager = appletManager:getAppletInstance("ScreenSavers")
	manager:screensaverWindow(self.window, _, _, _, 'BlankScreen')

	self.window:show(Window.transitionFadeIn)
end

function _getBrightness(self)
	-- store existing brightness levels in self
	return appletManager:callService("getBrightness")
end


--called when an overlay window (such as the power on window) will be shown, allows SS to do actoins at that time, such as turning on the brightess
function onOverlayWindowShown(self)
	self:_setBrightness("on")

	local clockSet = datetime:isClockSet()

	if clockSet then
		local time = datetime:getCurrentTime()
		self.timeLabel = Group("text_block_black", {
			text = Label("text", time)
		})
		self.window:addWidget(self.timeLabel)
	else
		if self.timeLabel then
			self.window:removeWidget(self.timeLabel)
		end
		self.timeLabel = nil
	end

end


function onOverlayWindowHidden(self)
	self:_setBrightness("off")
	if self.timeLabel then
		self.window:removeWidget(self.timeLabel)
		self.timeLabel = nil
	end
end


function _setBrightness(self, brightness)
	appletManager:callService("setBrightness", brightness)
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

