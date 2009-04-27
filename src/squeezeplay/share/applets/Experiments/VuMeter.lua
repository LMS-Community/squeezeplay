local oo            = require("loop.simple")
local math          = require("math")

local Canvas        = require("jive.ui.Canvas")
local Framework     = require("jive.ui.Framework")
local Surface       = require("jive.ui.Surface")
local Timer         = require("jive.ui.Timer")
local Widget        = require("jive.ui.Widget")

local decode        = require("squeezeplay.decode")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("ui")

local FRAME_RATE    = jive.ui.FRAME_RATE

local SLICE_HEIGHT = 2
local SLICE_SPACE = 2

local METER_COLORS = {
	0x0DFF007F, --GREEN
	0x19FF007F,
	0x26FF007F,
	0x33FF007F,
	0x40FF007F,
	0x4DFF007F,
	0x59FF007F,
	0x66FF007F,
	0x73FF007F,
	0x80FF007F,
	0x8CFF007F,
	0x99FF007F,
	0xA6FF007F,
	0xB2FF007F,
	0xBFFF007F,
	0xCCFF007F,
	0xD9FF007F,
	0xE6FF007F,
	0xF2FF007F,
	0xFFFF007F, -- YELLOW
	0xFFE6007F,
	0xFFCC007F,
	0xFFB2007F,
	0xFF99007F,
	0xFF80007F,
	0xFF66007F,
	0xFF4D007F,
	0xFF33007F,
	0xFF19007F,
	0xFF00007F, --RED
}

-- our class
module(..., oo.class)

function __init(self, windowOrFramework)
	local obj = oo.rawnew(self)

	obj.windowOrFramework = windowOrFramework

	obj.val = { 0, 0 }

	obj.screenWidth, obj.screenHeight = Framework:getScreenSize()

	_predraw(obj, 40, obj.screenHeight)

	return obj
end


function enableMeter(self, enable)
	if enable ~= nil and not enable then
		if self.canvas then
			log:error("Removing meter")
			self.windowOrFramework:removeWidget(self.canvas)
			self.canvas = nil
		end
		return
	end

	--enable, unless already enabled
	if self.canvas then
		log:error("Meter already on")
		return
	end

	log:info("Enabling meter")
	self.canvas = Canvas("debug_canvas", function(screen)
		_drawMeters(self, screen)
	end)

	self.canvas:addAnimation(
		function()
			--expensive, redrawing entire screen
			Framework:reDraw(nil)
		end,
		FRAME_RATE
	)
	self.windowOrFramework:addWidget(self.canvas)
end



local RMS_MAP = {
	0, 2, 5, 7, 10, 21, 33, 45, 57, 82, 108, 133, 159, 200, 
	242, 284, 326, 387, 448, 509, 570, 652, 735, 817, 900, 
	1005, 1111, 1217, 1323, 1454, 1585, 1716, 1847, 2005, 
	2163, 2321, 2480, 2666, 2853, 3040, 3227, 
}


function _predraw(self, w, h)
	self.surface = Surface:newRGBA(w, h)
	self.w = w
	self.h = h
	self.vh = {}

	local meterY = h
	for i = 1, #RMS_MAP do
		self.vh[i] = h - math.ceil(i * (h / #RMS_MAP))
	end

	for i = 1, (h / (SLICE_HEIGHT + SLICE_SPACE)) do
		local idx = math.ceil((h - meterY)/h * (#METER_COLORS - 1) ) + 1

		self.surface:filledRectangle(0, meterY, w, meterY + SLICE_HEIGHT -1, METER_COLORS[idx])

		meterY = meterY - (SLICE_HEIGHT + SLICE_SPACE)
	end
end


function _drawMeters(self, screen)
	local sampleAcc = decode:vumeter()

	_drawMeter(self, screen, sampleAcc, 1, self.screenWidth - 100, 0)
	_drawMeter(self, screen, sampleAcc, 2, self.screenWidth - 50, 0)
end


function _drawMeter(self, screen, sampleAcc, ch, x, y)
	local val = 1
	for i = #RMS_MAP, 1, -1 do
		if sampleAcc[ch] > RMS_MAP[i] then
			val = i
			break
		end
	end

	if val < self.val[ch] then
		self.val[ch] = self.val[ch] - 1
	else
		self.val[ch] = val
	end

	self.surface:blitClip(0, self.vh[self.val[ch]], self.w, self.h, screen, x, y + self.vh[self.val[ch]])
end
