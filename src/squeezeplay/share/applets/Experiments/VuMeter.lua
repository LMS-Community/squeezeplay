local oo            = require("loop.simple")

local Canvas        = require("jive.ui.Canvas")
local Framework     = require("jive.ui.Framework")
local Timer         = require("jive.ui.Timer")
local Widget    = require("jive.ui.Widget")

local math             = require("math")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("ui")
local FRAME_RATE       = jive.ui.FRAME_RATE

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

	obj.samplePoints = {3, 9, 9, 8, 4, 5, 4, 10, 10, 9, 10, 3, 3, 1, 1, 4, 8, 3, 3, 7,7 ,9 ,9 ,1 , 1, 3, 3, 3, 3, 4, 3, 7, 8, 9, 8, 9, 1, 9, }
	obj.sampleIndex = 1
	obj.sampleDelay = 4
	obj.sampleDelayIndex = 1

	obj.heightL = 0

	obj.screenWidth, obj.screenHeight = Framework:getScreenSize()

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

	log:error("Enabling meter")
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



function _drawMeters(self, screen)
	--todo: get real audio input values!!
	local valueL = self.samplePoints[math.ceil(self.sampleIndex)]


	local heightL = valueL * .1 * self.screenHeight

	if heightL < self.heightL then
		--decay when next input is quieter than the previous
		self.heightL = self.heightL - 9 * (SLICE_HEIGHT + SLICE_SPACE)
		if self.heightL < 0 then
			self.heightL = 0
		end
--		log:error("decaying")
	else
		self.heightL = heightL
	end

	local sliceCountL = math.ceil(self.heightL / (SLICE_HEIGHT + SLICE_SPACE))


	local meterYL = self.screenHeight
	for i = 1, sliceCountL do
		screen:filledRectangle(10 ,meterYL, 30, meterYL + SLICE_HEIGHT -1, self:getSliceColor(meterYL))
		--bogus R
		screen:filledRectangle(self.screenWidth - 30 ,meterYL, self.screenWidth - 10, meterYL + SLICE_HEIGHT -1, self:getSliceColor(meterYL))

		meterYL = meterYL - (SLICE_HEIGHT + SLICE_SPACE)
	end


	self.sampleDelayIndex = self.sampleDelayIndex + 1
	if self.sampleDelayIndex == self.sampleDelay then
		self.sampleDelayIndex = 1

		self.sampleIndex = self.sampleIndex + 1
		if self.sampleIndex  == #self.samplePoints then
			self.sampleIndex = 1
		end
	end
end


function getSliceColor(self, meterY)

	local index = math.ceil((self.screenHeight - meterY)/self.screenHeight * (#METER_COLORS - 1) ) + 1

	return METER_COLORS[index]
end
