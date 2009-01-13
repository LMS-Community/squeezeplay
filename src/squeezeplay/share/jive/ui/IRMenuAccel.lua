--[[
=head1 NAME

jive.ui.IrMenuAccel

=head1 DESCRIPTION

Class to handle ir events with acceleration.

--]]

local oo                   = require("loop.simple")
local math                 = require("math")

local ScrollWheel          = require("jive.ui.ScrollWheel")

local debug                = require("jive.utils.debug")
local log                  = require("jive.utils.log").logger("ui")

local EVENT_IR_DOWN        = jive.ui.EVENT_IR_DOWN
local EVENT_IR_REPEAT      = jive.ui.EVENT_IR_REPEAT

local INITIAL_ITEM_CHANGE_PERIOD = 350 -- ms

-- our class
module(..., oo.class)


--[[
=head2 IrMenuAccel(positiveCode, negativeCode)

Creates a filter for accelerated ir events.

positiveCode indicate the ir code that will trigger positive acceleration
negativeCode indicate the ir code that will trigger negative acceleration


=cut
--]]
function __init(self, positiveCode, negativeCode)
	local obj = oo.rawnew(self, {})

	obj.positiveCode = positiveCode
	obj.negativeCode = negativeCode
	obj.listIndex   = 1
	obj.lastItemChangeT = 0
	obj.itemChangePeriod = INITIAL_ITEM_CHANGE_PERIOD
	obj.itemChangeCycles = 0
	return obj
end


--[[
=head2 self:event(event, listTop, listIndex, listVisible, listSize)

Called with an ir event I<event>. Returns how far the selection should
move by.

I<listTop> is the index of the list item at the top of the screen.
I<listIndex> is the selected list item.
I<listVisible> is the number of items on the screen.
I<listSize> is the total number of items in the list.

=cut
--]]
function event(self, event, listTop, listIndex, listVisible, listSize)

	local dir = nil
	if event:getIRCode() == self.positiveCode then 
		dir = 1
	elseif event:getIRCode() == self.negativeCode then
		dir = -1
	else
		log:error("Unexpected irCode: " , event:getIRCode())
	end
		

	-- update state
	local now = event:getTicks()

	self.listIndex   = listIndex or 1

	--restart accelaration if new DOWN event seen
	if event:getType() == EVENT_IR_DOWN then
		self.itemChangeCycles = 1
		self.itemChangePeriod = INITIAL_ITEM_CHANGE_PERIOD
		self.lastItemChangeT = now
		
		--always move just one on a IR_DOWN
		local scrollBy = 1
		log:debug("IR Acceleration params -- scrollBy: " , scrollBy, " dir: ", dir, " itemChangePeriod: ", self.itemChangePeriod, " itemChangeCycles: ", self.itemChangeCycles)
		return scrollBy * dir
	end

	-- apply the acceleration, purely time based, not "amount of input" based
	-- Initial technique: increase the "item change rate" initially and move just by one, later increase scrollBy amount - not quite as sophisticated as SC accel

	if now > self.itemChangePeriod + self.lastItemChangeT then
		self.lastItemChangeT = now
		self.itemChangeCycles = self.itemChangeCycles + 1
		
		local scrollBy = 1
		--early on, only move one item at a time, but increase item change period
		if self.itemChangeCycles == 3 then
			self.itemChangePeriod = self.itemChangePeriod / 2
		elseif self.itemChangeCycles == 9 then
			self.itemChangePeriod = self.itemChangePeriod / 2
		elseif self.itemChangeCycles > 50 then
			scrollBy = 32
		elseif self.itemChangeCycles > 40 then
			scrollBy = 16
		elseif self.itemChangeCycles > 30 then
			scrollBy = 8
		elseif self.itemChangeCycles > 20 then
			scrollBy = 4
		elseif self.itemChangeCycles > 12 then
		scrollBy = 2
		end
		
		--don't move move than half a list
		if scrollBy > listSize / 2 then
			scrollBy = listSize / 2
		end

		log:debug("IR Acceleration params -- scrollBy: " , scrollBy, " dir: ", dir, " itemChangePeriod: ", self.itemChangePeriod, " itemChangeCycles: ", self.itemChangeCycles)
					
		return scrollBy * dir
	end
	
	return 0
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
