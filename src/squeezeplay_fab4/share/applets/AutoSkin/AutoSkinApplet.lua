
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
local pairs, type = pairs, type

local table           = require("table")

local oo              = require("loop.simple")
local logging         = require("logging")

local Applet          = require("jive.Applet")

local Window          = require("jive.ui.Window")
local Framework       = require("jive.ui.Framework")
local Surface         = require("jive.ui.Surface")

local log             = require("jive.utils.log").logger("ui")

local jiveMain        = jiveMain
local appletManager   = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


function __init(self)
	-- skins, could be configurable via settings
	local touchSkin = "Fab4Skin"
	local remoteSkin = "Fab4RemoteSkin"

	-- load skins at start up, this makes switching skins faster
--	local touchSkinApplet = appletManager:loadApplet(touchSkin)
--	local remoteSkinApplet = appletManager:loadApplet(remoteSkin)

	self.mode = jiveMain:getSelectedSkin()

	--temp workaround, until it is resolved how to avoid self.mode being null on startup
	if not self.mode then
		self.mode = touchSkin
	end

	local eatIREvents = false
	Framework:addListener(EVENT_IR_ALL,
		function(event)
			if eatIREvents then
				local type = event:getType()
				if type == EVENT_IR_UP then
					eatIREvents = false
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
			if eatTouchEvents then
				local type = event:getType()
				if type == EVENT_MOUSE_UP then
					eatTouchEvents = false
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
end


function changeSkin(self, skin)
	if  self.mode == skin then
		return false
	end

	Framework:playSound("CLICK")

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
	-- use a fast transition, 0.25 sec
	local frames = FRAME_RATE / 4

	local scale = 255 / frames
	local sw, sh = Framework:getScreenSize()

	return function(widget, surface)
			local x = frames * scale

			newImage:blit(surface, 0, 0)
			oldImage:blitAlpha(surface, 0, 0, x)

			frames = frames - 1
			if frames <= 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

