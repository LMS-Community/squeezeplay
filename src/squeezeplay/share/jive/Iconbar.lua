
--[[
=head1 NAME

jive.Iconbar - icon raw at the bottom of the screen

=head1 DESCRIPTION

The Iconbar class implements the Jive iconbar at the bottom of the screen. It refreshes itself every second.

=head1 SYNOPSIS

 -- Create the iconbar (this done for you in JiveMain)
 iconbar = Iconbar()

 -- Update playmode icon
 iconbar:setPlaymode('stop')

 -- force iconbar update
 iconbar:update()

=head1 FUNCTIONS

=cut
--]]

-- stuff we use
local tostring  = tostring

local os        = require("os")

local oo        = require("loop.base")

local Framework = require("jive.ui.Framework")
local Icon      = require("jive.ui.Icon")
local Label     = require("jive.ui.Label")

local string    = require("string")
local datetime  = require("jive.utils.datetime")
local log       = require("jive.utils.log").logger("ui")


-- our class
module(..., oo.class)


--[[

=head2 Iconbar:setPlaymode(val)

Set the playmode icon of the iconbar. Values are nil (off), "stop", "play" or "pause".

=cut
--]]
function setPlaymode(self, val)
	log:debug("Iconbar:setPlaymode(", val, ")")
	self.iconPlaymode:setStyle("iconPlaymode" .. string.upper((val or "OFF")))
end


--[[

=head2 Iconbar:setRepeat(val)

Set the repeat icon of the iconbar. Values are nil (no repeat), 1 for repeat single track and 2 for repeat all playlist tracks.

=cut
--]]
function setRepeat(self, val)
	log:debug("Iconbar:setRepeat(", val, ")")
	self.iconRepeat:setStyle("iconRepeat" .. string.upper((val or "OFF")))
end


--[[

=head2 Iconbar:setShuffle(val)

Set the shuffle icon of the iconbar. Values are nil (no shuffle), 1 for shuffle by track and 2 for shuffle by album.

=cut
--]]
function setShuffle(self, val)
	log:debug("Iconbar:setShuffle(", val, ")")
	self.iconShuffle:setStyle("iconShuffle" .. string.upper((val or "OFF")))
end


--[[

=head2 Iconbar:setBattery(val)

Set the state of the battery icon of the iconbar. Values are nil (no battery), CHARGING, AC or 0-4.

=cut
--]]
function setBattery(self, val)
	log:debug("Iconbar:setBattery(", val, ")")
	self.iconBattery:setStyle("iconBattery" .. string.upper((val or "NONE")))
end


--[[

=head2 Iconbar:setWirelessSignal(val)

Set the state of the network icon of the iconbar. Values are nil (no network), ERROR or 1-3.

=cut
--]]
function setWirelessSignal(self, val)
	log:debug("Iconbar:setWireless(", val, ")")

	self.wirelessSignal = val

	if val == "ERROR" then
		self.iconWireless:setStyle("iconWireless" .. val)
	elseif self.serverError == "ERROR" then
		self.iconWireless:setStyle("iconWirelessSERVERERROR")
	else
		self.iconWireless:setStyle("iconWireless" .. (val or "NONE"))
	end
end


--[[

=head2 Iconbar:setServerError(val)

Set the state of the SqueezeCenter connection. Values are nil, OK or ERROR.

=cut
--]]
function setServerError(self, val)
	self.serverError = val
	self:setWirelessSignal(self.wirelessSignal)
end


--[[

=head2 Iconbar:update()

Updates the iconbar.

=cut
--]]
function update(self)
	log:debug("Iconbar:update()")

	self.iconTime:setValue(datetime:getCurrentTime())
end


--[[

=head2 Iconbar()

Creates the iconbar.

=cut
--]]
function __init(self)
	log:debug("Iconbar:__init()")

	local obj = oo.rawnew(self, {
	        -- FIXME the background should be an icon, but icons use Surfaces not Tiles.
		iconBackground = Label("iconBackground", ""),
		iconPlaymode = Icon("iconPlaymodeOFF"),
		iconRepeat = Icon("iconRepeatOFF"),
		iconShuffle = Icon("iconShuffleOFF"),
		iconBattery = Icon("iconBatteryNONE"),
		iconWireless = Icon("iconWirelessNONE"),
		iconTime = Label("iconTime", "XXXX"),
	})


	obj:update()

	Framework:addWidget(obj.iconBackground)
	Framework:addWidget(obj.iconPlaymode)
	Framework:addWidget(obj.iconRepeat)
	Framework:addWidget(obj.iconShuffle)
	Framework:addWidget(obj.iconBattery)
	Framework:addWidget(obj.iconWireless)
	Framework:addWidget(obj.iconTime)

	obj.iconTime:addTimer(1000,  -- every second
			      function() 
				      obj:update()
			      end)
	
	return obj
end
--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

