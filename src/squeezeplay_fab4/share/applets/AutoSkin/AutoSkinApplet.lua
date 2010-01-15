
--[[
=head1 NAME

applets.AutoSkin.AutoSkinApplet - An applet to select different SqueezePlay skins

=head1 DESCRIPTION

This applet allows the SqueezePlay skin to be selected.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
AutoSkinApplet overrides the following methods:

=cut
--]]


-- stuff we use
local pairs, type, tostring = pairs, type, tostring

local table           = require("table")

local io                     = require("io")
local oo              = require("loop.simple")

local Applet          = require("jive.Applet")

local Window          = require("jive.ui.Window")
local Framework       = require("jive.ui.Framework")
local Surface         = require("jive.ui.Surface")
local Timer                  = require("jive.ui.Timer")

local jiveMain        = jiveMain
local appletManager   = appletManager

local SW_TABLET_MODE	     = 1
local SYSPATH = "/sys/bus/i2c/devices/0-0047/"

local RECENTLY_NEAR_TIMEOUT = 15000

local PROX_NEAR = 1
local PROX_FAR = 0

local skinByProximity = {
	[PROX_NEAR] = "WQVGAsmallSkin",
	[PROX_FAR] = "WQVGAlargeSkin",
}

module(..., Framework.constants)
oo.class(_M, Applet)


function _changeDutyCycle(self, newValue)
	-- Send The Command
	local f = io.open(SYSPATH .. "proximity_duty_cycle", "w")
	f:write(tostring(newValue))
	f:close()
end


function init(self, ...)

	-- skins, could be configurable via settings
	local touchSkin = "WQVGAsmallSkin"
	local remoteSkin = "WQVGAlargeSkin"

	-- load skins at start up, this makes switching skins faster
--	local touchSkinApplet = appletManager:loadApplet(touchSkin)
--	local remoteSkinApplet = appletManager:loadApplet(remoteSkin)

	--trial and error suggested this result - todo: talk to maurice about this
	--Yikes touch and ir freezeup on boot when trying to change duty cycle early - Richard looking into why
	--commenting out for now
--	self:_changeDutyCycle(7)

	self.mode = jiveMain:getSelectedSkin()

	self.proximity = PROX_NEAR

	--temp workaround, until it is resolved how to avoid self.mode being null on startup
	if not self.mode then
		self.mode = touchSkin
	end

	local eatIREvents = false

	Framework:addListener(EVENT_SWITCH,
		function(event)
--			log:warn("switch: ", event:tostring())
			local code, value = event:getSwitch()
			if code == SW_TABLET_MODE  then
				if value == 1 then
					self.proximity = PROX_NEAR
					self:_resetRecentlyNearTimer()
					self:changeSkin(skinByProximity[PROX_NEAR])
				else
--					self.proximity = PROX_FAR
					--for now only change on IR, todo clean up, still waiting on direction
--					if not self.recentlyNearTimer then
--						self:changeSkin(skinByProximity[PROX_FAR])
--					end
				end

			end

		end,
		-100)
		
	Framework:addListener(EVENT_IR_ALL,
		function(event)
			if self.recentlyNearTimer then
				--when recently near (via prox or touch), stay on near mode
				self.proximity = PROX_FAR
				return EVENT_UNUSED
			end
			if eatIREvents then
				local type = event:getType()
				if type == EVENT_IR_UP then
					eatIREvents = false
					self:_disableAnyScreensaver()
				end
				return EVENT_CONSUME
			elseif self:changeSkin(remoteSkin) then
				eatIREvents = true
				return EVENT_CONSUME
			else
				return EVENT_UNUSED
			end
		end,
		-100)

	local eatTouchEvents = false
	Framework:addListener(EVENT_MOUSE_ALL,
		function(event)
			self.proximity = PROX_NEAR
			self:_resetRecentlyNearTimer()
			if eatTouchEvents then
				local type = event:getType()
				if type == EVENT_MOUSE_UP then
					eatTouchEvents = false
					self:_disableAnyScreensaver()
				end
				return EVENT_CONSUME
			elseif self:changeSkin(touchSkin) then
				eatTouchEvents = true
				return EVENT_CONSUME
			else
				return EVENT_UNUSED
			end
		end,
		-100)

	return self
end


-- self.recentlyNearTimer starts a timer when either touch occurs or near proximity occurs. After timeout,
--  the skin moves to the skin associated with the current proximity 
function _resetRecentlyNearTimer(self)
	if not self.recentlyNearTimer then
		self.recentlyNearTimer = Timer(
						RECENTLY_NEAR_TIMEOUT,
						function ()
							log:info("timeout since last touch, shift to skin for current proximity")
							self:changeSkin(skinByProximity[self.proximity])
							self.recentlyNearTimer = nil
						end
						,true)
	end

	self.recentlyNearTimer:restart()
end


function _disableAnyScreensaver(self)
	if appletManager:callService("isScreensaverActive") then
		appletManager:callService("deactivateScreensaver")
		appletManager:callService("restartScreenSaverTimer")
	end
end


function changeSkin(self, skin)
	if  self.mode == skin then
		return false
	end

--	Framework:playSound("CLICK")

	local img1 = _capture("foo")

	jiveMain:setSelectedSkin(skin)
	self.mode = skin

	local img2 = _capture("bar")

	Framework:_startTransition(self._transitionFadeIn(img1, img2))

	return true
end


function _capture(name)
	local sw, sh = Framework:getScreenSize()
	local img = Surface:newRGB(sw, sh)

	Framework:draw(img)

	return img
end


function _transitionFadeIn(oldImage, newImage)
	-- use a fast transition

	local startT
	local transitionDuration = 100
	local remaining = transitionDuration
	local sw, sh = Framework:getScreenSize()
	local scale = (transitionDuration * transitionDuration * transitionDuration) / sw
	local animationCount = 0

	local scale = 255 / transitionDuration


	return function(widget, surface)
			if animationCount == 0 then
				--getting start time on first loop avoids initial delay that can occur
				startT = Framework:getTicks()
			end
			local x = remaining * scale

			newImage:blit(surface, 0, 0)
			oldImage:blitAlpha(surface, 0, 0, x)

			local elapsed = Framework:getTicks() - startT
			remaining = transitionDuration - elapsed

			if remaining <= 0 then
				Framework:_killTransition()
			end
			animationCount = animationCount + 1
		end
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

