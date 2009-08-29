
-- Private class to handle player volume

local tostring, ipairs, tonumber = tostring, ipairs, tonumber

local oo                     = require("loop.base")
local os                     = require("os")
local math                   = require("math")

local System                 = require("jive.System")
local Framework              = require("jive.ui.Framework")
local Group                  = require("jive.ui.Group")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local Player                 = require("jive.slim.Player")
local Slider                 = require("jive.ui.Slider")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")
local IRMenuAccel            = require("jive.ui.IRMenuAccel")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("applet.SlimBrowser")


local EVENT_KEY_ALL          = jive.ui.EVENT_KEY_ALL
local EVENT_KEY_DOWN         = jive.ui.EVENT_KEY_DOWN
local EVENT_KEY_UP           = jive.ui.EVENT_KEY_UP
local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_IR_REPEAT        = jive.ui.EVENT_IR_REPEAT
local EVENT_IR_DOWN          = jive.ui.EVENT_IR_DOWN
local EVENT_IR_ALL           = jive.ui.EVENT_IR_ALL
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
	if tonumber(self:_getVolume()) <= 0 then
		self.title:setValue(self.applet:string("SLIMBROWSER_MUTED"))
		self.icon:setStyle('icon_popup_mute')
		self.slider:setValue(0)

	else
		self.title:setValue(tostring(self:_getVolume()) )
		self.icon:setStyle('icon_popup_volume')
		self.slider:setValue(self:_getVolume())
	end
end

function _getVolume(self)
	if not self.player then
		return nil
	end

	if self.player:isLocal() then
		--use local player volume
		return self.player:getVolume()
	else
		--use self.volume which is updated with server
		return self.volume
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
	popup:setAlwaysOnTop(true)

	local title = Label("heading", "")
	popup:addWidget(title)

	local icon = Icon('icon_popup_volume')
        popup:addWidget(icon)

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
	popup:addListener(ACTION | EVENT_KEY_ALL | EVENT_IR_DOWN | EVENT_IR_REPEAT | EVENT_SCROLL,
			  function(event)
				  return self:event(event)
			  end)

	-- we handle events
	popup.brieflyHandler = false

	-- open the popup
	self.popup  = popup
	self.title  = title
	self.icon   = icon
	self.slider = slider

	_updateDisplay(self)

	popup:showBriefly(3000,
		function()
			--This happens on ANY window pop, not necessarily the popup window's pop (todo: actually, I think this is not happening (i.e. POP is for this window only), Investigae)
			local isPopupOnStack = false
			local stack = Framework.windowStack
			for i in ipairs(stack) do
				if stack[i] == popup then
					isPopupOnStack = true
					break
				end
			end

			--don't clear it out if the pop was from another window
			if not isPopupOnStack then
				self.popup = nil
			end
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
			if self.volume == 0 and self.delta > 1 then
				--allow lowest possible level (1) from 0 (for use in cases like knob where volume moves in multiple steps/event
				self.delta = 1
			end

			new = math.abs(self.volume) + self.delta

			local now = Framework:getTicks()
			new = new + self.rateLimitDelta
			self.rateLimitDelta = 0
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

	new = self:_coerceVolume(new)

	local remoteVolume = self.player:volume(new)

	if not remoteVolume then -- player suppressed volume due to rate limiting, hold onto difference lost
		self.rateLimitDelta = new - self.volume
	end

	self.volume = remoteVolume or self.volume
	_updateDisplay(self)

	if not self.rateLimiterCleanupTimer then
		local delay = Player:getRateLimitTime()
		self.rateLimiterCleanupTimer = Timer(   delay,
							function()
								if self.rateLimitDelta and self.rateLimitDelta ~= 0 then

									local rateLimitCleanupVolume = math.abs(self.volume) + self.rateLimitDelta
									self.rateLimitDelta = 0
									rateLimitCleanupVolume = self:_coerceVolume(rateLimitCleanupVolume)

									log:debug("**Sending cleanup volume: ", rateLimitCleanupVolume)

									local returnedVolume = self.player:volume(rateLimitCleanupVolume, true)
									if not returnedVolume then
										log:warn("any timer set volume value should always go through, since send param is 'true'" )
										return
									end
									self.volume = returnedVolume or self.volume
									_updateDisplay(self)
								end
							end,
							true)
	end
	self.rateLimiterCleanupTimer:restart()

end


function _coerceVolume(self, volume)
	local new = volume
	if volume > 100 then
		new = 100
	elseif volume > 0 and self.delta < 0 and volume <= math.abs(self.delta) then
		new = 1 -- when negative delta is greater than 1, always allow for stop at lowest value, so lowest volume can be heard, used for instanve by volume_down ACTION handling which goes down in steps
	elseif volume < 0 then
		new = 0
	end

	return new
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
        obj.irAccel = IRMenuAccel("volup", "voldown")
        --kick in accel sooner than default
	obj.irAccel:setCyclesBeforeAccelerationStarts(2)
	
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

	elseif (type & EVENT_IR_ALL) > 0 then
		if event:isIRCode("volup") or event:isIRCode("voldown") then
			--IR vol up/down
			if type == EVENT_IR_DOWN or type == EVENT_IR_REPEAT then
				local value = self.irAccel:event(event, 1, 1, 1, 100)
				if value ~= 0 then
					self.delta = value
					_updateVolume(self, nil, nil, true)
					self.delta = 0
				end
			end
			--ignore other volume ir events
			return EVENT_CONSUME
		end
		--all non-volume IR, pass through.
		return EVENT_UNUSED

	elseif type == ACTION then
		local action = event:getAction()
		if action == "volume_up" then
			self.delta = 1
			_updateVolume(self, nil, nil, true)
			self.delta = 0
			return EVENT_CONSUME
		end
		if action == "volume_down" then
			self.delta = -1
			_updateVolume(self, nil, nil, true)
			self.delta = 0
			return EVENT_CONSUME
		end

		-- GO closes the volume popup
		if action == "go" then
			self.popup:showBriefly(0)
			return EVENT_CONSUME
		end

		if action == "back" then
			self.popup:showBriefly(0)
			return EVENT_CONSUME
		end
		
		-- any other actions forward to the lower window
		local lower = self.popup:getLowerWindow()

		if self.popup then
			self.popup:showBriefly(0)
		end

		if lower then
			Framework:dispatchEvent(lower, event)
		end

		return EVENT_CONSUME

	elseif type == EVENT_KEY_PRESS then
		local keycode = event:getKeycode()

		--Baby volume keys have no down/up and must have unique handling
		if (keycode & (KEY_VOLUME_UP|KEY_VOLUME_DOWN) ~= 0) and System:getMachine() == "baby" then
			--handle keyboard volume change
			if (keycode == KEY_VOLUME_UP) then
				self.delta = 1
				_updateVolume(self, nil, nil, true)
				self.delta = 0
			end
			if (keycode == KEY_VOLUME_DOWN) then
				self.delta = -1
				_updateVolume(self, nil, nil, true)
				self.delta = 0
			end

			return EVENT_CONSUME
		end

		-- volume + and - pressed at same time for mute
		if keycode & (KEY_VOLUME_UP|KEY_VOLUME_DOWN) == (KEY_VOLUME_UP|KEY_VOLUME_DOWN) then
			_updateVolume(self, self.volume >= 0)
			return EVENT_CONSUME
		end

		-- any other keys allow to come back as an action
		if keycode & (KEY_VOLUME_UP|KEY_VOLUME_DOWN) == 0 then
			return EVENT_UNUSED
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
			-- anything but volume keys should com back as an action
			return EVENT_UNUSED
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
