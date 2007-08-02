
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

local log       = require("jive.utils.log").logger("ui")

require("jive.ui.Icon")
require("jive.ui.Label")
local Icon      = jive.ui.Icon
local Label     = jive.ui.Label

-- our class
module(..., oo.class)


--[[

=head2 Iconbar:setPlaymode(val)

Set the playmode icon of the iconbar. Values are nil (off), "stop", "play" or "pause".

=cut
--]]
function setPlaymode(self, val)
	log:debug("Iconbar:setPlaymode(", val, ")")
	
	self.icon_playmode:setStyle("icon_playmode_" .. (val or "off"))
end


--[[

=head2 Iconbar:setRepeat(val)

Set the repeat icon of the iconbar. Values are nil (no repeat), 1 for repeat single track and 2 for repeat all playlist tracks.

=cut
--]]
function setRepeat(self, val)
	log:debug("Iconbar:setRepeat(", val, ")")

	self.icon_repeat:setStyle("icon_repeat_" .. (val or "off"))
end


--[[

=head2 Iconbar:setShuffle(val)

Set the shuffle icon of the iconbar. Values are nil (no shuffle), 1 for shuffle by track and 2 for shuffle by album.

=cut
--]]
function setShuffle(self, val)
	log:debug("Iconbar:setShuffle(", val, ")")

	self.icon_shuffle:setStyle("icon_shuffle_" .. (val or "off"))
end


--[[

=head2 Iconbar:update()

Updates the iconbar.

=cut
--]]
function update(self)
	log:debug("Iconbar:update()")

	local now = os.date("%I:%M%p")
	self.icon_time:setValue(now)
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
		icon_background = Label("icon_background", ""),
		icon_playmode = Icon("icon_playmode_off"),
		icon_repeat = Icon("icon_repeat_off"),
		icon_shuffle = Icon("icon_shuffle_off"),
		icon_time = Label("icon_time", "XXXX"),
	})


	obj:update()

	Framework:addWidget(obj.icon_background)
	Framework:addWidget(obj.icon_playmode)
	Framework:addWidget(obj.icon_repeat)
	Framework:addWidget(obj.icon_shuffle)
	Framework:addWidget(obj.icon_time)

	obj.icon_time:addTimer(1000,  -- every second
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

