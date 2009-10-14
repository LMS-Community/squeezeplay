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

	obj.val = { 0, 0 }

	obj:addAnimation(function() obj:reDraw() end, FRAME_RATE / 4)

	return obj
end


function _skin(self)
	Icon._skin(self)

	self.bgImg = self:styleImage("bgImg")
	self.barCol = self:styleColor("bar", { 0xff, 0xff, 0xff, 0xff })
	self.capCol = self:styleColor("cap", { 0xff, 0xff, 0xff, 0xff })
end


function _layout(self)
	local x,y,w,h = self:getBounds()
	local l,t,r,b = self:getPadding()

	self.capSize = 5

	self.w = w - l - r
	self.h = h - t - b - self.capSize

	self.x = x + l
	self.y = y + t + self.h

	self.numBins = self.w / 3 / 2

	self.cap = { {}, {} }
	for i = 1, self.numBins do
		self.cap[1][i] = 0
		self.cap[2][i] = 0
	end
end


function _randBins(num, h)
	local bins = { {}, {} }

	for i = 1, num do
		bins[1][i] = math.random(h)
		bins[2][i] = math.random(h)
	end

	return bins
end


function draw(self, surface)
	self.bgImg:blit(surface, self:getBounds())

	local bins = _randBins(self.numBins, self.h)

	_drawBins(self, surface, bins, 1, self.x, self.y, 1)
	_drawBins(self, surface, bins, 1, self.x + (self.numBins*3), self.y, 1)
end


function _drawBins(self, surface, bins, ch, x, y, w)
	local bch = bins[ch]
	local cch = self.cap[ch]

	for i = 1, #bch do
		surface:filledRectangle(x, y, x+w, y-bch[i], self.barCol)
		
		if bch[i] >= cch[i] then
			cch[i] = bch[i]
		elseif cch[i] > 0 then
			cch[i] = cch[i] - 1
		end

		surface:filledRectangle(x, y-cch[i]-self.capSize, x+w, y-cch[i], self.capCol)

		x = x + w + 2
	end
end
