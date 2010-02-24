
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

local ipairs, pairs = ipairs, pairs

local oo              = require("loop.simple")
local Applet          = require("jive.Applet")

local Framework       = require("jive.ui.Framework")
local Surface         = require("jive.ui.Surface")

local jiveMain        = jiveMain
local appletManager   = appletManager

local debug           = require("jive.utils.debug")

module(..., Framework.constants)
oo.class(_M, Applet)

--service method
function getActiveSkinType(self)
	return self.mode
end

function init(self, ...)

	-- skins, could be configurable via settings
	local touchSkin = "touch"
	local remoteSkin = "remote"

	--temp workaround, until it is resolved how to avoid self.mode being null on startup
	if not self.mode then
		self.mode = touchSkin
	end
	
	if not self.irBlacklist then
		self.irBlacklist = {}

		-- see jive.irMap_default for defined buttons
		for x, button in ipairs({
			"arrow_up",
			"arrow_down",
		--	"arrow_left",
			"arrow_right",
			"play",
		--	"add",
		--	"now_playing",
		}) do
			local irCodes = Framework:getIRCodes(button)
			
			for name, irCode in pairs(irCodes) do
				self.irBlacklist[irCode] = button
			end
		end

	end

	local eatIREvents = false
		
	Framework:addListener(EVENT_IR_ALL,
		function(event)
			-- ignore initial keypress after switching from touch to IR control
			if eatIREvents then

				if event:getType() == EVENT_IR_UP then
					eatIREvents = false
				end
				return EVENT_CONSUME

			elseif self:changeSkin(remoteSkin) and self.irBlacklist[event:getIRCode()] ~= nil then

				log:warn("ignore me - key " .. self.irBlacklist[event:getIRCode()] .. " is context sensitive")
				eatIREvents = true
				return EVENT_CONSUME

			end

			return EVENT_UNUSED
		end,
		-100)

	Framework:addListener(EVENT_MOUSE_ALL,
		function(event)

			-- ignore event when switching from remote to touch: we don't know what we're touching
			-- wake up if in screensaver mode - this is a non critical action
			if self:changeSkin(touchSkin) and not appletManager:callService("isScreensaverActive") then
				log:warn("ignore me - I don't know what I'm touching!")
				return EVENT_CONSUME
			end

			return EVENT_UNUSED
		end,
		-100)

	return self
end



function changeSkin(self, skinType)
	if  self.mode == skinType then
		return false
	end

	local skinName = appletManager:callService("getSelectedSkinNameForType", skinType)
	if jiveMain:getSelectedSkin() == skinName then
		log:debug("skin already selected, not switching: ", skinName)
		return false
	end

	local img1 = _capture("foo")

	self.mode = skinType
	jiveMain:setSelectedSkin(skinName)

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

