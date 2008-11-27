

-- stuff we use
local pairs, setmetatable, tostring, tonumber  = pairs, setmetatable, tostring, tonumber

local oo            = require("loop.simple")
local string        = require("string")
local table         = require("jive.utils.table")

local Applet        = require("jive.Applet")
local System        = require("jive.System")
local SlimServer    = require("jive.slim.SlimServer")
local LocalPlayer   = require("jive.slim.LocalPlayer")

local Decode        = require("squeezeplay.decode")

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
local log           = require("jive.utils.log").logger("applets.setup")

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


-- main setting menu
function settingsShow(self, metaState)
	local settings = self:getSettings()

	local window = Window("window", self:string("AUDIO_PLAYBACK"))
	local menu = SimpleMenu("menu", items)
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	window:addWidget(menu)

	menu:addItem({
		text = self:string("ENABLE_AUDIO"),
		sound = "SELECT",
		weight = 1,
		icon = Checkbox(
                	"checkbox",
			function(_, isSelected)
				local settings = self:getSettings()
				settings.enableAudio = isSelected and 3 or 2

				if isSelected then
					-- Create player instance
					local uuid = System:getUUID()
					local playerid = System:getMacAddress()
					metaState.player = LocalPlayer(jnt, playerid, uuid)

				else
					-- Disconnect and free player
					local currentPlayer = appletManager:callService("getCurrentPlayer")
					if currentPlayer == metaState.player then
						appletManager:callService("setCurrentPlayer", null)
					end


					metaState.player:destroy(metaState.player:getSlimServer())
					metaState.player = nil

					settings.serverName = nil
					settings.serverInit = nil
					settings.playerName = nil
				end

				self:storeSettings()
			end,
                        settings.enableAudio & 1 == 1
		)})

	menu:addItem({
		text = self:string("DEBUG_AUDIO"),
		sound = "WINDOWSHOW",
		weight = 2,
		callback = function(event, menuItem)
				   self:_debugMenu()
			   end,
	})

	menu:addItem({
		text = self:string("TEST_TONES"),
		sound = "WINDOWSHOW",
		weight = 2,
		callback = function(event, menuItem)
				   self:_tonesMenu()
			   end,
	})

	self:tieAndShowWindow(window)
end


local decoders = {
      ['p'] = 'wav',
      ['f'] = 'flac',
      ['w'] = 'wma',
      ['9'] = 'ogg',
      ['m'] = 'mp3',
      ['t'] = 'tone',
}

function _debugMenu(self)
	local window = Window("window", self:string("DEBUG_AUDIO"))
	window:setAllowScreensaver(false)

	local values = {}
	for i=1,6 do
			values[i] = Label("value", "")
	end

	local menu = SimpleMenu("menu", {
		{ text = self:string("FORMAT"), icon = values[1] },
		{ text = self:string("DECODE_BUFFER"), icon = values[2] },
		{ text = self:string("OUTPUT_BUFFER"), icon = values[3] },
		{ text = self:string("ELAPSED_SECS"), icon = values[4] },
		{ text = self:string("NUM_TRACKS"), icon = values[5] },
		{ text = self:string("DECODE_STATE"), icon = values[6] },
	})

	window:addWidget(menu)

	window:addTimer(1000, function()
			local status = Decode:status()

			values[1]:setValue(decoders[string.char(status.decoder or 0)] or "?")
			values[2]:setValue(string.format('%0.1f%%', status.decodeFull / status.decodeSize * 100))
			values[3]:setValue(string.format('%0.1f%%', status.outputFull / status.outputSize * 100))
			values[4]:setValue(status.elapsed)
			values[5]:setValue(status.tracksStarted)
			values[6]:setValue(status.decodeState .. " " .. status.audioState)
	end)

	window:show()
	return window
end


function _tonesMenu(self)
	local window = Window("window", self:string("TEST_TONES"))

	local menu = SimpleMenu("menu", {
		{ text = self:string("MULTITONE"),
		  sound = "WINDOWSHOW",
		  callback = function(event)
		  	Decode:start(
				string.byte('t'), 0, 0, 0, 0, 0, 1
			)
			Decode:resume()
		  end
		},
		{ text = self:string("SINE_44.1k"),
		  sound = "WINDOWSHOW",
		  callback = function(event)
		  	Decode:start(
				string.byte('t'), 0, 0, 0, 0, 0, 10
			)
			Decode:resume()
		  end
		},
		{ text = self:string("SINE_48k"),
		  sound = "WINDOWSHOW",
		  callback = function(event)
		  	Decode:start(
				string.byte('t'), 0, 0, 0, 0, 0, 11
			)
			Decode:resume()
		  end
		},
		{ text = self:string("SINE_88.2K"),
		  sound = "WINDOWSHOW",
		  callback = function(event)
		  	Decode:start(
				string.byte('t'), 0, 0, 0, 0, 0, 12
			)
			Decode:resume()
		  end
		},
		{ text = self:string("SINE_96K"),
		  sound = "WINDOWSHOW",
		  callback = function(event)
		  	Decode:start(
				string.byte('t'), 0, 0, 0, 0, 0, 13
			)
			Decode:resume()
		  end
		},			
		{ text = self:string("SINE_STOP"),
		  sound = "WINDOWSHOW",
		  callback = function(event)
			Decode:stop()
		  end
		},			
	})

	window:addWidget(menu)

	window:show()
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

