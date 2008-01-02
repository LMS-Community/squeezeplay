
--[[

Class to handle scroll acceleration

--]]

local oo                   = require("loop.simple")

local math                 = require("math")

local debug                = require("jive.utils.debug")
local log                  = require("jive.utils.log").logger("ui")


-- our class
module(...)
oo.class(_M, Widget)


function __init(self)
	local obj = oo.rawnew(self,{
				      listIndex   = 1,
				      scrollDir   = 0,
				      scrollLastT = nil,
			      })

	return obj
end


--[[

Called on a scroll event.

listIndex is the current selection index.
listSize is the total number of items in the list.

--]]
function event(self, event, listIndex, listSize)

	local scroll = event:getScroll()

	log:warn("scroll=", scroll, " listIndex=", listIndex, " listSize=", listSize)

	local now = event:getTicks()
	local dir = scroll > 0 and 1 or -1

	if dir == self.scrollDir and now - self.scrollLastT < 250 then
		if self.scrollAccel then
			self.scrollAccel = self.scrollAccel + 1
			if     self.scrollAccel > 50 then
				scroll = dir * math.max(math.ceil(listSize/50), math.abs(scroll) * 16)
			elseif self.scrollAccel > 40 then
				scroll = scroll * 16
			elseif self.scrollAccel > 30 then
				scroll = scroll * 8
			elseif self.scrollAccel > 20 then
				scroll = scroll * 4
			elseif self.scrollAccel > 10 then
				scroll = scroll * 2
			end
		else
			self.scrollAccel = 1
		end
	else
		self.scrollAccel = nil
	end

	self.listIndex   = listIndex or 1
	self.scrollDir   = dir
	self.scrollLastT = now

--	log:warn("scroll=", scroll)

	return scroll
end


function predictIndex(self)
	local predict = self.listIndex + ((self.scrollAccel or 1) * self.scrollDir)
	log:warn("predict=", predict)

	return predict
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
