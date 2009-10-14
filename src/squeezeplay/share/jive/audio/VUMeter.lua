local oo            = require("loop.simple")
local math          = require("math")

local Framework     = require("jive.ui.Framework")
local Icon          = require("jive.ui.Icon")
local Surface       = require("jive.ui.Surface")
local Timer         = require("jive.ui.Timer")
local Widget        = require("jive.ui.Widget")

local decode        = require("squeezeplay.decode")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("audio.decode")

local FRAME_RATE    = jive.ui.FRAME_RATE


module(...)
oo.class(_M, Icon)


function __init(self, style)
	local obj = oo.rawnew(self, Icon(style))

	obj.cap = { 0, 0 }

	obj:addAnimation(function() obj:reDraw() end, FRAME_RATE / 4)

	return obj
end


function _skin(self)
	Icon._skin(self)

	self.bgImg = self:styleImage("bgImg")
	self.tickCap = self:styleImage("tickCap")
	self.tickOn = self:styleImage("tickOn")
	self.tickOff = self:styleImage("tickOff")
end


function _layout(self)
	local x,y,w,h = self:getBounds()
	local l,t,r,b = self:getPadding()

	local tw,th = self.tickOn:getMinSize()

	self.w = w - l - r
	self.h = h - t - b

	self.x1 = x + l + ((self.w - tw * 2) / 3)
	self.x2 = x + l + ((self.w - tw * 2) / 3) * 2 + tw

	self.bars = self.h / th
	self.y = y + t + (self.bars * th)
end


function draw(self, surface)
	self.bgImg:blit(surface, self:getBounds())

	local sampleAcc = decode:vumeter()

	_drawMeter(self, surface, sampleAcc, 1, self.x1, self.y, self.w, self.h)
	_drawMeter(self, surface, sampleAcc, 2, self.x2, self.y, self.w, self.h)
end


-- FIXME dynamic based on number of bars
local RMS_MAP = {
	0, 2, 5, 7, 10, 21, 33, 45, 57, 82, 108, 133, 159, 200, 
	242, 284, 326, 387, 448, 509, 570, 652, 735, 817, 900, 
	1005, 1111, 1217, 1323, 1454, 1585, 1716, 1847, 2005, 
	2163, 2321, 2480, 2666, 2853, 3040, 3227, 
}


function _drawMeter(self, surface, sampleAcc, ch, x, y, w, h)
	local val = 1
	for i = #RMS_MAP, 1, -1 do
		if sampleAcc[ch] > RMS_MAP[i] then
			val = i
			break
		end
	end

	-- FIXME when rms map scaled
	val = math.floor(val / 2)

	if val >= self.cap[ch] then
		self.cap[ch] = val
	elseif self.cap[ch] > 0 then
		self.cap[ch] = self.cap[ch] - 1
	end

	local tw,th = self.tickOn:getMinSize()

	for i = 1, self.bars do
		if i == self.cap[ch] then
			self.tickCap:blit(surface, x, y, tw, th)
		elseif i < val then
			self.tickOn:blit(surface, x, y, tw, th)
		else
			self.tickOff:blit(surface, x, y, tw, th)
		end

		y = y - th
	end
end
