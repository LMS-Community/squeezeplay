
-- Private class to handle player volume 

local tostring = tostring

local oo                     = require("loop.base")
local os                     = require("os")
local math                   = require("math")

local Group                  = require("jive.ui.Group")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local Slider                 = require("jive.ui.Slider")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("player")


local EVENT_KEY_ALL          = jive.ui.EVENT_KEY_ALL
local EVENT_KEY_DOWN         = jive.ui.EVENT_KEY_DOWN
local EVENT_KEY_UP           = jive.ui.EVENT_KEY_UP
local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL           = jive.ui.EVENT_SCROLL

local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_UNUSED           = jive.ui.EVENT_UNUSED

local KEY_VOLUME_DOWN        = jive.ui.KEY_VOLUME_DOWN
local KEY_VOLUME_UP          = jive.ui.KEY_VOLUME_UP


-- number of volume steps
local VOLUME_STEP = 100 / 40


module(..., oo.class)


local function _openPopup(self)
	if self.player == nil then
		return
	end

	-- we need a local copy of the volume
	self.volume = self.player:getVolume()

	local popup = Popup("volumePopup")
	popup:setAutoHide(false)

	popup:addWidget(Label("title", "Volume"))

	local slider = Slider("volume")
	slider:setRange(-1, 100, self.volume)
	popup:addWidget(Group("volumeGroup", {
				      Icon("volumeMin"),
				      slider,
				      Icon("volumeMax")
			      }))

	popup:addListener(EVENT_KEY_ALL | EVENT_SCROLL,
			  function(event)
				  return self:event(event)
			  end)

	-- we handle events
	popup.brieflyHandler = false

	-- open the popup
	self.popup = popup
	self.slider = slider

	popup:showBriefly(2000,
		function()
			self.popup = nil
		end,
		Window.transitionPushPopupUp,
		Window.transitionPushPopupDown
	)
end


local function _updateVolume(self, mute)
	if not self.popup then
		self.timer:stop()
		return
	end

	-- keep the popup window open
	self.popup:showBriefly()

	-- ignore updates while muting
	if self.muting then
		return
	end

	-- mute?
	if mute then
		self.muting = true
		self.volume = self.player:mute(true)
		return
	end

	-- accelation for key holds
	local accel = 1
	if self.downAt then
		accel = 1 + (os.time() - self.downAt)
	end

	-- change volume
	local new = math.abs(self.volume) + self.delta * accel * VOLUME_STEP
	
	if new > 100 then 
		new = 100
	elseif new < 0 then
		new = 0
	end
			
	self.volume = self.player:volume(new) or self.volume
	self.slider:setValue(self.volume)
end


function __init(self)
	local obj = oo.rawnew(self, {})

	self.muting = false
	self.downAt = false
	obj.timer = Timer(300, function()
				       _updateVolume(obj)
			       end)

	return obj
end


function setPlayer(self, player)
	self.player = player
end


function event(self, event)
	if not self.popup then
		_openPopup(self)
	else
		self.popup:showBriefly()
	end

	local type = event:getType()
	
	if type == EVENT_SCROLL then
		local scroll = event:getScroll()

		if scroll > 0 then
			self.delta = 1
		elseif scroll < 0 then
			self.delta = -1
		else
			self.delta = 0
		end
		_updateVolume(self)

	elseif type == EVENT_KEY_PRESS then
		local keycode = event:getKeycode()

		-- we're only interested in volume keys
		if keycode & (KEY_VOLUME_UP|KEY_VOLUME_DOWN) ~= (KEY_VOLUME_UP|KEY_VOLUME_DOWN) then
			return EVENT_CONSUME
		end

		self.downAt = false
		_updateVolume(self, self.volume >= 0)

	else
		local keycode = event:getKeycode()

		-- we're only interested in volume keys
		if keycode & (KEY_VOLUME_UP|KEY_VOLUME_DOWN) == 0 then
			return EVENT_CONSUME
		end

		-- stop volume update on key up
		if type == EVENT_KEY_UP then
			self.delta = 0
			self.muting = false
			self.downAt = false
			self.timer:stop()
			return EVENT_CONSUME
		end

		-- update volume
		if type == EVENT_KEY_DOWN then
			if keycode == KEY_VOLUME_UP then
				self.delta = 1
			elseif keycode == KEY_VOLUME_DOWN then
				self.delta = -1
			else
				self.delta = 0
			end

			self.downAt = os.time()
			self.timer:restart()
			_updateVolume(self)

			return EVENT_CONSUME
		end
	end

	return EVENT_CONSUME
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
