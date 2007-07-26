
--[[
=head1 NAME

applets.Bounce.BounceApplet - Demonstration screensaver featuring a bouncing Squeezebox!

=head1 DESCRIPTION

Bounce is a screen saver for Jive. It is an applet that implements a screen saver
performing simple animations.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. BounceApplet overrides the
following methods:

=cut
--]]


-- stuff we use
local ipairs, tostring = ipairs, tostring

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local Window           = require("jive.ui.Window")
local Surface          = require("jive.ui.Surface")
local Icon             = require("jive.ui.Icon")
local Framework        = require("jive.ui.Framework")

local log              = require("jive.utils.log").logger("applets.screensavers")

local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_WINDOW_RESIZE = jive.ui.EVENT_WINDOW_RESIZE
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local FRAME_RATE       = jive.ui.FRAME_RATE


module(...)
oo.class(_M, Applet)


-- Sprite class
Sprite = oo.class()


function Sprite:__init(screen_w, screen_h, surface, step)
	local obj = oo.rawnew(self)
	
	local w,h = surface:getSize()

	obj.icon = Icon("sprite", surface)
	local x = screen_w / 2 - w / 2
	local y = screen_h / 2 - h / 2
	obj.icon:setPosition(x, y)

	-- motion
	obj.dx = step or 1
	obj.dy = step or 1

	-- work out bounding rectangle
	obj.min_w = 10
	obj.max_w = screen_w - w - 10
	obj.min_h = 10
	obj.max_h = screen_h - h - 10
	
	return obj
end


function Sprite:animate()
	local icon = self.icon

	-- move the icon
	local x, y = icon:getPosition()
	x = x + self.dx
	y = y + self.dy

	-- hit screen edge?
	if x > self.max_w or x < self.min_w then
		self.dx = -self.dx
	end
	if y > self.max_h or y < self.min_h then
		self.dy = -self.dy
	end

	-- update icon
	icon:setPosition(x, y)
end


-- bounce
-- the main applet function, the meta arranges for it to be called
-- by the ScreenSaversApplet.
function bounce(self)

	local window = Window("bounce")
	local w, h = Framework:getScreenSize()

	self.sprits = {}

	-- squeezebox string
	local str = "squeezebox"
	local font = window:styleFont(str)
	local txt = Surface:drawText(font, 0xFFFFFF80, str)
	self.sprits[1] = Sprite(w, h, txt, -2)


	-- squeezebox icon
	local img = Surface:loadImage("applets/Bounce/squeezebox.png")
	self.sprits[2] = Sprite(w, h, img, 1)


	-- background
	local srf  = Surface:newRGBA(w, h)
	srf:filledRectangle(0, 0, w, h, 0x000000FF)
	srf:rectangle(10, 10, w - 10, h - 10, 0xFFFFFFFF)

	self.bg = Icon("background", srf)

	-- animation function
	self.bg:addAnimation(
		function()
			-- animate all sprits
			for i,sprit in ipairs(self.sprits) do
				sprit:animate()
			end
		end, 
		FRAME_RATE
	)


	-- any button to exit
	window:addListener(
		EVENT_KEY_PRESS,
		function(event)
			window:hide()
			return EVENT_CONSUME
		end
	)

	window:addListener(EVENT_WINDOW_RESIZE,
			   function(event)
				   self:bounce():show(Window.transitionNone)
				   window:hide()
			   end)

	-- add sprits and background to window
	window:addWidget(self.bg)
	for i,sprit in ipairs(self.sprits) do
		window:addWidget(sprit.icon)
	end

	return window
end


-- applet skin
function skin(self, s)
	s.bounce.layout = Window.noLayout
end


--[[

=head2 applets.Bounce.BounceApplet:displayName()

Overridden to return the string "Bounce"

=cut
--]]
function displayName(self)
	return "Bounce"
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]


