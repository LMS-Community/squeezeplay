-----------------------------------------------------------------------------
-- Flick.lua
-----------------------------------------------------------------------------

--[[
=head1 NAME

jive.ui.Flicks - Manages Finger Flicks

=head1 METHODS

=cut
--]]


-- stuff we use
local _assert, ipairs, pairs, string, tostring, type, getmetatable = _assert, ipairs, pairs, string, tostring, type, getmetatable

local oo                   = require("loop.simple")
local debug                = require("jive.utils.debug")
                           
local table                = require("jive.utils.table")
local Framework            = require("jive.ui.Framework")
local Event                = require("jive.ui.Event")
local Widget               = require("jive.ui.Widget")
local Label                = require("jive.ui.Label")
local Scrollbar            = require("jive.ui.Scrollbar")
local Surface              = require("jive.ui.Surface")
local ScrollAccel          = require("jive.ui.ScrollAccel")
local IRMenuAccel          = require("jive.ui.IRMenuAccel")
local Timer                = require("jive.ui.Timer")

local log                  = require("jive.utils.log").logger("squeezeplay.ui")

local math                 = require("math")


local EVENT_ALL            = jive.ui.EVENT_ALL
local EVENT_ALL_INPUT      = jive.ui.EVENT_ALL_INPUT
local ACTION               = jive.ui.ACTION
local EVENT_ACTION         = jive.ui.EVENT_ACTION
local EVENT_SCROLL         = jive.ui.EVENT_SCROLL
local EVENT_IR_ALL         = jive.ui.EVENT_IR_ALL
local EVENT_IR_DOWN        = jive.ui.EVENT_IR_DOWN
local EVENT_IR_REPEAT      = jive.ui.EVENT_IR_REPEAT
local EVENT_KEY_ALL        = jive.ui.EVENT_KEY_ALL
local EVENT_KEY_PRESS      = jive.ui.EVENT_KEY_PRESS
local EVENT_SHOW           = jive.ui.EVENT_SHOW
local EVENT_HIDE           = jive.ui.EVENT_HIDE
local EVENT_SERVICE_JNT    = jive.ui.EVENT_SERVICE_JNT
local EVENT_FOCUS_GAINED   = jive.ui.EVENT_FOCUS_GAINED
local EVENT_FOCUS_LOST     = jive.ui.EVENT_FOCUS_LOST
local EVENT_MOUSE_PRESS    = jive.ui.EVENT_MOUSE_PRESS
local EVENT_MOUSE_DOWN     = jive.ui.EVENT_MOUSE_DOWN
local EVENT_MOUSE_UP       = jive.ui.EVENT_MOUSE_UP
local EVENT_MOUSE_MOVE     = jive.ui.EVENT_MOUSE_MOVE
local EVENT_MOUSE_DRAG     = jive.ui.EVENT_MOUSE_DRAG
local EVENT_MOUSE_HOLD     = jive.ui.EVENT_MOUSE_HOLD
local EVENT_MOUSE_ALL      = jive.ui.EVENT_MOUSE_ALL

local EVENT_CONSUME        = jive.ui.EVENT_CONSUME
local EVENT_UNUSED         = jive.ui.EVENT_UNUSED
                           
local KEY_FWD              = jive.ui.KEY_FWD
local KEY_REW              = jive.ui.KEY_REW
local KEY_GO               = jive.ui.KEY_GO
local KEY_BACK             = jive.ui.KEY_BACK
local KEY_UP               = jive.ui.KEY_UP
local KEY_DOWN             = jive.ui.KEY_DOWN
local KEY_LEFT             = jive.ui.KEY_LEFT
local KEY_RIGHT            = jive.ui.KEY_RIGHT
local KEY_PLAY             = jive.ui.KEY_PLAY
local KEY_PAGE_UP           = jive.ui.KEY_PAGE_UP
local KEY_PAGE_DOWN         = jive.ui.KEY_PAGE_DOWN

--speed (pixels/ms) that must be surpassed for flick to start.
local FLICK_THRESHOLD_START_SPEED = 90/1000


--"recent" distance that must be surpassed for flick to start.
-- is used to check for drag then quick finger stop then release. Normal averaging doesn't handle this case well, thus we have this further check.
local FLICK_RECENT_THRESHOLD_DISTANCE = 5

--speed (pixels/ms) that per pixel afterscrolling occurs, otherwise is per item when faster.
local FLICK_THRESHOLD_BY_PIXEL_SPEED = 400/1000

--speed (pixels/ms) at which flick scrolling will stop
local FLICK_STOP_SPEED =  3/1000

--if initial speed is greater than this, "letter" accelerators will occur for the flick
local FLICK_FORCE_ACCEL_SPEED = 72 * 30/1000

--time after flick starts that decel occurs
local FLICK_DECEL_START_TIME = 400

--time from decel start to scroll stop (trying new linger setting, which throws this off)
local FLICK_DECEL_TOTAL_TIME = 600

--If non zero, extra afterscroll time (FLICK_SPEED_DECEL_TIME_FACTOR * flickSpeed ) is
 -- added to FLICK_DECEL_TOTAL_TIME.  flick speed maxes out at about 3.
local FLICK_SPEED_DECEL_TIME_FACTOR = 1500

-- Only the mouse points gathered for the last FLICK_STALE_TIME will be used for flick calculation
local FLICK_STALE_TIME = 100

-- our class
module(..., oo.class)





function stopFlick(self, byFinger)

	self.flickTimer:stop()
	self.flickInterruptedByFinger = byFinger
	self.flickInProgress = false
--	self.flickInitialScrollT = nil

	self:resetFlickData()
end


function updateFlickData(self, mouseEvent)
	local x, y = mouseEvent:getMouse()
	local ticks = mouseEvent:getTicks()

	--hack until reason for 0 ticks is resolved
	if (ticks == 0) then
		return
	end

	--hack until reason for false "far out of range" ticks is happening

	if #self.flickData.points >=1 then
		local previousTicks = self.flickData.points[#self.flickData.points].ticks
		if math.abs(ticks - previousTicks ) > 10000 then
			log:error("Erroneous tick value occurred, ignoring : ", ticks, "  after previuos tick value of: ", previousTicks)
			return
		end
	end
--	log:error("y:, ", y, " ticks:", ticks, " #self.flickData.points: ", #self.flickData.points)

	--use last flick data collection time as initital scroll time to avoid jerky delay when afterscroll starts 
	self.flickInitialScrollT = Framework:getTicks()

	table.insert(self.flickData.points, {y = y, ticks = ticks})

	local time = 0

	if #self.flickData.points > 1 then
		time = self.flickData.points[#self.flickData.points].ticks - self.flickData.points[1].ticks
	end

	if #self.flickData.points >= 20 or time > 100 then
		--only keep last 20 values (number was come up by trial and error, flick and quick stopping, quick flicks, multi-speed flicks)
		-- if ound that having this number lower (less averging) made the afterscroll "jump"
		-- also only collect events that occurred in the last 100ms
		table.remove(self.flickData.points, 1)
	end

end

function resetFlickData(self)
	self.flickData.points = {}
end

function getFlickSpeed(self, itemHeight, mouseUpT)
	--remove stale points
	if #self.flickData.points > 1 then
		local staleRemoved = false
		repeat
			if self.flickData.points[#self.flickData.points].ticks - self.flickData.points[1].ticks > FLICK_STALE_TIME then
				table.remove(self.flickData.points, 1)
			else
				staleRemoved = true
			end
		until staleRemoved
	end

	if not self.flickData.points or #self.flickData.points < 2 then
		return nil
	end

	if mouseUpT then
		local delayUntilUp = mouseUpT - self.flickData.points[#self.flickData.points].ticks
		if delayUntilUp > 25 then
			-- a long delay since last point is one indication of a finger stop
			return nil
		end
	end

	--finger stop checking
	-- finger may have stopped after a drag, but the averaging might make it appear that a flick occurred
	local recentPoints = 5
	if #self.flickData.points > recentPoints then
		local recentIndex = 1 + #self.flickData.points - recentPoints
		local recentDistance = self.flickData.points[#self.flickData.points].y - self.flickData.points[recentIndex].y

		if math.abs(recentDistance) <= FLICK_RECENT_THRESHOLD_DISTANCE then
			log:debug("Returning nil, didn't surpase 'recent' threshold distance: ", recentDistance)
			return nil
		end

	end

	local distance = self.flickData.points[#self.flickData.points].y - self.flickData.points[1].y
	local time = self.flickData.points[#self.flickData.points].ticks - self.flickData.points[1].ticks

	--speed = pixels/ms
	local speed = distance/time


	log:debug("Flick info: speed: ", speed, "  distance: ", distance, "  time: ", time )

	local direction = speed >= 0 and -1 or 1
	return math.abs(speed), direction
end



--if initialSpeed nil, then continue any existing flick. If non nil, start a new flick at that rate
function flick(self, initialSpeed, direction)
	if initialSpeed then
		self:stopFlick()
		if initialSpeed < FLICK_THRESHOLD_START_SPEED then
			log:debug("Under threshold, not flicking: ", initialSpeed )

			return
		end
		self.flickInProgress = true
		self.flickInitialSpeed = initialSpeed
		self.flickDirection = direction
		self.flickTimer:start()

		if not self.flickInitialScrollT then
			self.flickInitialScrollT = Framework:getTicks()
		end
		self.flickLastY = 0
		self.flickInitialDecelerationScrollT = nil
		self.flickPreDecelY = 0

		local decelTime = FLICK_DECEL_TOTAL_TIME + math.abs(FLICK_SPEED_DECEL_TIME_FACTOR * self.flickInitialSpeed)
		self.flickAccelRate = -self.flickInitialSpeed / decelTime
		log:debug("*****Starting flick - decelTime: ", decelTime )
	end

	--continue flick
	local now = Framework:getTicks()

	local flickCurrentY, byItemOnly
	if not self.flickInitialDecelerationScrollT then
		--still at full speed

		flickCurrentY = self.flickInitialSpeed * (now - self.flickInitialScrollT)
		self.flickPreDecelY = flickCurrentY

		--slow speed if past decel time
		if self.flickInitialDecelerationScrollT == nil and now - self.flickInitialScrollT > FLICK_DECEL_START_TIME then
			log:debug("*****Starting flick slow down")
			self.flickInitialDecelerationScrollT = now
		end
	end

	if self.flickInitialDecelerationScrollT then	
		local elapsedTime = now - self.flickInitialDecelerationScrollT

		-- y = v0*t +.5 * a * t^2
		flickCurrentY = self.flickPreDecelY + self.flickInitialSpeed * elapsedTime + (.5 * self.flickAccelRate * elapsedTime * elapsedTime )

		--v = v0 + at
		local flickCurrentSpeed = self.flickInitialSpeed + (self.flickAccelRate * elapsedTime)
		byItemOnly = flickCurrentSpeed > FLICK_THRESHOLD_BY_PIXEL_SPEED
		if flickCurrentSpeed <= FLICK_STOP_SPEED then
			log:debug("*******Stopping Flick at slow down point. current speed:", flickCurrentSpeed)
			self:stopFlick()
			return
		end
	end


	local pixelOffset = math.floor(flickCurrentY - self.flickLastY)

	self.parent:handleDrag(self.flickDirection * pixelOffset, byItemOnly)

	self.flickLastY = self.flickLastY + pixelOffset

	if (self.parent:isAtBottom() and self.flickDirection > 0)
		or (self.parent:isAtTop() and self.flickDirection < 0) then
		--stop at boundaries
		log:debug("*******Stopping Flick at boundary") -- need a ui cue that this has happened
		self:stopFlick()
	end
end


--[[

=head2 jive.ui.Drag()

Constructs a new Drag object.

=cut
--]]
function __init(self, parent)
	local obj = oo.rawnew(self)

	obj.parent = parent

	obj.flickData = {}
	obj.flickData.points = {}

	obj.flickTimer = Timer(25,
			       function()
			                obj:flick()
			       end)

	return obj
end



--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

