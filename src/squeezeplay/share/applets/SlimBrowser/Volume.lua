
-- Private class to handle player volume

local tostring = tostring

local oo                     = require("loop.base")
local os                     = require("os")
local math                   = require("math")

local Framework              = require("jive.ui.Framework")
local Group                  = require("jive.ui.Group")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local Slider                 = require("jive.ui.Slider")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("applet.SlimBrowser")


local EVENT_KEY_ALL          = jive.ui.EVENT_KEY_ALL
local EVENT_KEY_DOWN         = jive.ui.EVENT_KEY_DOWN
local EVENT_KEY_UP           = jive.ui.EVENT_KEY_UP
local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_SCROLL           = jive.ui.EVENT_SCROLL
local ACTION                 = jive.ui.ACTION

local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_UNUSED           = jive.ui.EVENT_UNUSED

local KEY_GO                 = jive.ui.KEY_GO
local KEY_VOLUME_DOWN        = jive.ui.KEY_VOLUME_DOWN
local KEY_VOLUME_UP          = jive.ui.KEY_VOLUME_UP


-- number of volume steps
local VOLUME_STEP = 100 / 40


module(..., oo.class)


local function _updateDisplay(self)
	if self.volume <= 0 then
		self.title:setValue(self.applet:string("SLIMBROWSER_VOLUME_MUTED"))
		self.slider:setValue(0)

	else
		self.title:setValue(self.applet:string("SLIMBROWSER_VOLUME", tostring(self.volume) ) )
		self.slider:setValue(self.volume)
	end
end


local function _openPopup(self)
	if self.popup or not self.player then
		return
	end

	-- we need a local copy of the volume
	self.volume = self.player:getVolume()
	if not self.volume then
		-- don't show the popup if the player state is not loaded
		return
	end

	local popup = Popup("slider_popup")
	popup:setAutoHide(false)

	local title = Label("heading", "")
	popup:addWidget(title)

        popup:addWidget(Icon('icon_popup_volume'))

	--slider is focused widget so it will receive events before popup gets a chance
	local slider = Slider("volume_slider", -1, 100, self.volume,
                              function(slider, value, done)
					self.delta = value - self.volume
					self:_updateVolume(false, value)
                              end)

	popup:addWidget(Group("slider_group", {
		slider = slider,
	}))

	popup:focusWidget(nil)
	popup:addListener(ACTION | EVENT_KEY_ALL,
			  function(event)
				  return self:event(event)
			  end)

	-- we handle events
	popup.brieflyHandler = false

	-- open the popup
	self.popup = popup
	self.title = title
	self.slider = slider

	_updateDisplay(self)

	popup:showBriefly(3000,
		function()
			self.popup = nil
		end,
		Window.transitionPushPopupUp,
		Window.transitionPushPopupDown
	)
end


function _updateVolume(self, mute, directSet, noAccel)
	if not self.popup then
		self.timer:stop()
		return
	end

	-- keep the popup window open
	self.popup:showBriefly()

	-- ignore updates while muting
	if self.muting then
		return _updateDisplay(self)
	end

	-- mute?
	if mute then
		self.muting = true
		self.volume = self.player:mute(true)
		return _updateDisplay(self)
	end

	local new

	if directSet then
		new = math.floor(directSet)
	else
		if noAccel then
			new = math.abs(self.volume) + self.delta
			local now = Framework:getTicks()
			if (now - self.lastUpdate) < 350 then
				--add any additional delta suppressed by rate limiting

				new = new + self.rateLimitDelta
				self.rateLimitDelta = 0
			else
				--beyond time where built up delta from rate limiting is abandoned
				self.rateLimitDelta = 0
			end
			self.lastUpdate = now
		else
			-- accelation
			local now = Framework:getTicks()
			if self.accelDelta ~= self.delta or (now - self.lastUpdate) > 350 then
				self.accelCount = 0
			end

			self.accelCount = math.min(self.accelCount + 1, 20)
			self.accelDelta = self.delta
			self.lastUpdate = now

			-- change volume
			local accel = self.accelCount / 4
			new = math.floor(math.abs(self.volume) + self.delta * accel * VOLUME_STEP)
		end
	end

	if new > 100 then
		new = 100
	elseif new > 0 and self.delta < 0 and new <= math.abs(self.delta) then
		new = 1 -- when negative delta is greater than 1, always allow for stop at lowest value, so lowest volume can be heard, used for instanve by volume_down ACTION handling which goes down in steps
	elseif new < 0 then
		new = 0
	end
	local remoteVolume = self.player:volume(new)

	if not remoteVolume then
		self.rateLimitDelta = self.rateLimitDelta + self.delta
	end

	self.volume = remoteVolume or self.volume
	_updateDisplay(self)
end


function __init(self, applet)
	local obj = oo.rawnew(self, {})

	obj.applet = applet
	obj.muting = false
	obj.lastUpdate = 0
	obj.rateLimitDelta = 0
	obj.timer = Timer(100, function()
				       _updateVolume(obj)
			       end)

	return obj
end


function setPlayer(self, player)
	self.player = player
end


function event(self, event)
	local onscreen = true
	if not self.popup then
		onscreen = false
		_openPopup(self)
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

	elseif type == ACTION then
		local action = event:getAction()
		if action == "volume_up" then
			self.delta = 3
			_updateVolume(self, nil, nil, true)
			self.delta = 0
			return EVENT_CONSUME
		end
		if action == "volume_down" then
			self.delta = -3
			_updateVolume(self, nil, nil, true)
			self.delta = 0
			return EVENT_CONSUME
		end

		-- GO closes the volume popup
		if action == "go" then
			self.popup:showBriefly(0)
			return EVENT_CONSUME
		end

		-- any other actions forward to the lower window
		local lower = self.popup:getLowerWindow()
		if lower then
			Framework:dispatchEvent(lower, event)
		end

		self.popup:showBriefly(0)
		return EVENT_CONSUME

	elseif type == EVENT_KEY_PRESS then
		local keycode = event:getKeycode()


		-- volume + and - for mute
		if keycode & (KEY_VOLUME_UP|KEY_VOLUME_DOWN) == (KEY_VOLUME_UP|KEY_VOLUME_DOWN) then
			_updateVolume(self, self.volume >= 0)
			return EVENT_CONSUME
		end

		-- any other keys forward to the lower window
		if keycode & (KEY_VOLUME_UP|KEY_VOLUME_DOWN) == 0 then
			local lower = self.popup:getLowerWindow()
			if lower then
				Framework:dispatchEvent(lower, event)
			end

			self.popup:showBriefly(0)
			return EVENT_CONSUME
		end

		--handle keyboard volume change
		if (keycode == KEY_VOLUME_UP) then
			self.delta = 1
			_updateVolume(self)
			self.delta = 0
		end
		if (keycode == KEY_VOLUME_DOWN) then
			self.delta = -1
			_updateVolume(self)
			self.delta = 0
		end

		return EVENT_CONSUME

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

			self.timer:restart()
			if onscreen then
				_updateVolume(self)
			end

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
