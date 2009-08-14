--[[
=head1 NAME

jive.ui.Timeinput - Base class for timeinput helper methods

=head1 DESCRIPTION

Base class for Timeinpupt helper methods

=head1 METHODS

=cut
--]]


-- stuff we use
local _assert, assert, ipairs, require, tostring, type, tonumber = _assert, assert, ipairs, require, tostring, type, tonumber

local oo            = require("loop.base")
local string        = require("jive.utils.string")
local table         = require("jive.utils.table")
local Event         = require("jive.ui.Event")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("squeezeplay.ui")

local EVENT_SHOW    = jive.ui.EVENT_SHOW
local EVENT_HIDE    = jive.ui.EVENT_HIDE
local EVENT_UPDATE  = jive.ui.EVENT_UPDATE
local EVENT_CONSUME = jive.ui.EVENT_CONSUME
local ACTION        = jive.ui.ACTION


-- our class
module(..., oo.class)

local Framework		= require("jive.ui.Framework")


function __init(self, window, submitCallback, initTime)
	local obj = oo.rawnew(self, {})

	obj.window = window
	obj.submitCallback = submitCallback

	if initTime and type(initTime) == 'table' then
		obj.initHour   = initTime.hour and tonumber(initTime.hour)
		obj.initMinute = initTime.minute and tonumber(initTime.minute)
		obj.initampm   = initTime.ampm
	end

	addTimeInputWidgets(obj)

	return obj
end

function _minuteString(minute)
	local returnVal
	if minute < 10 then
		returnVal = '0' .. tostring(minute)
	else
		returnVal = tostring(minute)
	end
	return returnVal
end
function addTimeInputWidgets(self)

	local hours = { '10', '11', '12', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '1' }
	local minutes = { '58', '59', '00' }

	-- deal with inital hour setting
	if self.initHour then
		if self.initHour == 1 then
			hours = { '11', '12', '1' }
		elseif self.initHour == 2 then
			hours = { '12', '1', '2' }
		else
			hours = { self.initHour - 2, self.initHour - 1, self.initHour }
		end
		local nextItem = self.initHour + 1
		local inc = 1
		while inc < 14 do
			if nextItem > 12 then
				nextItem = 1
			end
			table.insert(hours, tostring(nextItem))
			nextItem = nextItem + 1
			inc = inc + 1
		end
	end

	self.hourMenu = SimpleMenu("hour")
	for i, hour in ipairs(hours) do
		self.hourMenu:addItem({
			text = hour,
		})
	end
	self.hourMenu.wraparoundGap = 2
	self.hourMenu.itemsBeforeScroll = 2
	self.hourMenu.noBarrier = true
	local initHour = 3
	if self.initHour then
		initHour = initHour + self.initHour
	end
	self.hourMenu:setSelectedIndex(3)

	self.minuteMenu = SimpleMenu('minuteUnselected')
	-- deal with inital minute setting
	if self.initMinute then
		if self.initMinute == 0 then
			minutes = { '58', '59', '00' }
		elseif self.initMinute == 1 then
			minutes = { '59', '00', '01' }
		else
			minutes = { 
				_minuteString(self.initMinute - 2), 
				_minuteString(self.initMinute - 1), 
				_minuteString(self.initMinute) 
			}
		end
		local nextItem = self.initMinute + 1
		local inc = 1
		while inc < 62 do
			if nextItem > 59 then
				nextItem = 0
			end
			local nextItemString = _minuteString(nextItem)
			table.insert(minutes, nextItemString)
			nextItem = nextItem + 1
			inc = inc + 1
		end
	end

	for i, minute in ipairs(minutes) do
		self.minuteMenu:addItem({
			text = minute,
		})
	end
	local minute = 0

	self.minuteMenu.wraparoundGap = 2
	self.minuteMenu.itemsBeforeScroll = 2
	self.minuteMenu.noBarrier = true
	self.minuteMenu:setSelectedIndex(3)

	self.ampmMenu = SimpleMenu('ampmUnselected')
	local ampm = { '', '', 'pm', 'am', '', '' }
	if self.initampm == 'am' then
		ampm = { '', '', 'am', 'pm', '', '' }
	end

	for i, t in ipairs(ampm) do
		self.ampmMenu:addItem({
			text = t,
		})
	end
	self.ampmMenu.wraparoundGap = 2
	self.ampmMenu.itemsBeforeScroll = 2
	self.ampmMenu.noBarrier = true
	self.ampmMenu:setSelectedIndex(3)

	self.hourMenu:setHideScrollbar(true)
	self.minuteMenu:setHideScrollbar(true)
	self.ampmMenu:setHideScrollbar(true)

	self.hourMenu:addActionListener('back', self, function() self.window:hide() end)
	self.hourMenu:addActionListener('go', self, 
		function() 
			self.hourMenu:setStyle('hourUnselected')
			self.minuteMenu:setStyle('minute')
			--next is evil, but not sure how to get style change for a menu the right way, trying various options. Richard?
			Framework:styleChanged()
			self.window:focusWidget(self.minuteMenu)
		end
	)

	self.minuteMenu:addActionListener('go', self, 
		function() 
			self.ampmMenu:setStyle('ampm')
			self.minuteMenu:setStyle('minuteUnselected')
			--next is evil, but not sure how to get style change for a menu the right way, trying various options. Richard?
			Framework:styleChanged()
			self.window:focusWidget(self.ampmMenu)
		end)
	self.minuteMenu:addActionListener('back', self, 
		function() 
			self.hourMenu:setStyle('hour')
			self.minuteMenu:setStyle('minuteUnselected')
			--next is evil, but not sure how to get style change for a menu the right way, trying various options. Richard?
			Framework:styleChanged()
			self.window:focusWidget(self.hourMenu)
		end)

	self.ampmMenu:addActionListener('go', self, 
		function() 
			local hour   = self.hourMenu:getItem(self.hourMenu:getSelectedIndex()).text
			local minute = self.minuteMenu:getItem(self.minuteMenu:getSelectedIndex()).text
			local ampm   = self.ampmMenu:getItem(self.ampmMenu:getSelectedIndex()).text
			self.window:hide() 
			self.submitCallback( hour, minute, ampm )
		end)
	self.ampmMenu:addActionListener('back', self, 
		function() 
			self.ampmMenu:setStyle('ampmUnselected')
			self.minuteMenu:setStyle('minute')
			--next is evil, but not sure how to get style change for a menu the right way, trying various options. Richard?
			Framework:styleChanged()
			self.window:focusWidget(self.minuteMenu)
		end)

	self.window:addWidget(self.minuteMenu)
	self.window:addWidget(self.hourMenu)
	self.window:addWidget(self.ampmMenu)
	self.window:focusWidget(self.hourMenu)

end

