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

	obj:addAnimation(function() obj:reDraw() end, FRAME_RATE)

	return obj
end


function _skin(self)
	Icon._skin(self)

-- Black background instead of image
---	self.bgImg = self:styleImage("bgImg")
	self.bgCol = self:styleColor("bg", { 0xff, 0xff, 0xff, 0xff })

	self.barCol = self:styleColor("bar", { 0xff, 0xff, 0xff, 0xff })
	self.capCol = self:styleColor("cap", { 0xff, 0xff, 0xff, 0xff })
end


function _layout(self)
	local x,y,w,h = self:getBounds()
	local l,t,r,b = self:getPadding()

	self.channelWidth = {}
	self.channelFlipped = {}
	self.barWidth = {}
	self.barSpacing = {}
	self.clipSubbands = {}

	self.capSize = 4
	self.capSpacing = 4
	self.isMono = 0

	self.channelWidth[1] = (w - l - r) / 2
	self.channelFlipped[1] = 0
	self.barWidth[1] = 1
	self.barSpacing[1] = 6
	self.clipSubbands[1] = 0

	self.channelWidth[2] = (w - l - r) / 2
	self.channelFlipped[2] = 1
	self.barWidth[2] = 1
	self.barSpacing[2] = 6
	self.clipSubbands[2] = 0


	local barSize = self.barWidth[1] + self.barSpacing[1]

	local numBars = {}

	numBars = decode:spectrum_init(	self.isMono,

					self.channelWidth[1],
					self.channelFlipped[1],
					self.barWidth[1],
					self.barSpacing[1],
					self.clipSubbands[1],

					self.channelWidth[2],
					self.channelFlipped[2],
					self.barWidth[2],
					self.barSpacing[2],
					self.clipSubbands[2]
	)

	log:warn("** 1: " .. numBars[1] .. " 2: " .. numBars[2])

	local barHeight = h - t - b - self.capSize - self.capSpacing

	-- max bin value from C code is 31
	self.barHeightMulti = barHeight / 31

	self.x1 = x + w / 2 - numBars[1] * barSize
	self.x2 = x + w / 2 + self.barSpacing[2]
	self.y = y + h - b

	self.cap = { {}, {} }
	for i = 1, numBars[1] do
		self.cap[1][i] = 0
	end

	for i = 1, numBars[2] do
		self.cap[2][i] = 0
	end

end


function draw(self, surface)
-- Black background instead of image
--	self.bgImg:blit(surface, self:getBounds())
	local x, y, w, h = self:getBounds()
	surface:filledRectangle(x, y, w, h, self.bgCol)


	local bins = { {}, {}}

	bins[1], bins[2] = decode:spectrum()

	_drawBins(self, surface, bins, 1, self.x1, self.y, self.barWidth[1], self.barSpacing[1], self.barHeightMulti)
	_drawBins(self, surface, bins, 2, self.x2, self.y, self.barWidth[2], self.barSpacing[2], self.barHeightMulti)
end


function _drawBins(self, surface, bins, ch, x, y, barWidth, barSpacing, barHeightMulti)
	local bch = bins[ch]
	local cch = self.cap[ch]

	for i = 1, #bch do
		bch[i] = bch[i] * barHeightMulti

		-- bar
		surface:filledRectangle(x, y, x + barWidth - 1, y - bch[i], self.barCol)
		
		if bch[i] >= cch[i] then
			cch[i] = bch[i]
		elseif cch[i] > 0 then
			cch[i] = cch[i] - barHeightMulti
			if cch[i] < 0 then
				cch[i] = 0
			end
		end

		-- cap
		surface:filledRectangle(x, y - cch[i] - self.capSpacing, x + barWidth - 1, y - cch[i] - self.capSize - self.capSpacing, self.capCol)

		x = x + barWidth + barSpacing
	end
end


--[[

=head1 LICENSE

Copyright 2009 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

