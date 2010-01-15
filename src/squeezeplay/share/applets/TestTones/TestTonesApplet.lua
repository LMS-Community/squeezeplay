

-- stuff we use
local pairs, setmetatable, tostring, tonumber  = pairs, setmetatable, tostring, tonumber

local oo            = require("loop.simple")
local string        = require("string")
local table         = require("jive.utils.table")

local Applet        = require("jive.Applet")
local System        = require("jive.System")
local SlimServer    = require("jive.slim.SlimServer")
local LocalPlayer   = require("jive.slim.LocalPlayer")

local decode        = require("squeezeplay.decode")

local Framework     = require("jive.ui.Framework")
local Checkbox      = require("jive.ui.Checkbox")
local Label         = require("jive.ui.Label")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local Textarea      = require("jive.ui.Textarea")
local Textinput     = require("jive.ui.Textinput")
local Popup         = require("jive.ui.Popup")
local Icon          = require("jive.ui.Icon")

local SlimProto     = require("jive.net.SlimProto")
local Playback      = require("jive.audio.Playback")

local debug         = require("jive.utils.debug")

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


-- main setting menu
function testTonesShow(self)
	-- test tones menu
	local window = Window("text_list", self:string("TEST_TONES"))
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu", items)
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	window:addWidget(menu)

	menu:addItem({
		text = self:string("TONE_STOP"),
		sound = "WINDOWSHOW",
		weight = 2,
		callback = function(event, menuItem)
			decode:stop()
		end,
	})

	for entry in self:readdir("tones") do
		local name = string.gsub(string.match(entry, "([^/]-)$"), "[^%w]", "_")

		menu:addItem({
			text = self:string("TONE_" .. string.upper(name)),
			sound = "SELECT",
			weight = 1,
			callback = function(event, menuItem)
				_playTone(self, entry)
			end,
		})
	end

	window:addListener(EVENT_WINDOW_ACTIVE, function()
		decode:stop()

		-- stop playback
		local localPlayer = nil
		for mac, player in appletManager:callService("iteratePlayers") do
			if player:isLocal() then
				localPlayer = player
				break
			end
       		end

		localPlayer:stop()
	end)

	window:addListener(EVENT_WINDOW_INACTIVE, function()
		decode:stop()
	end)

	self:tieAndShowWindow(window)
end


function _playTone(self, tone)
	local localPlayer = nil
	for mac, player in appletManager:callService("iteratePlayers") do
		if player:isLocal() then
			localPlayer = player
			break
		end
       	end
			
	if localPlayer then
		-- fixed volume (50%)
		decode:audioGain(0x01000, 0x01000)

		localPlayer:playFileInLoop(tone)
	end
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

