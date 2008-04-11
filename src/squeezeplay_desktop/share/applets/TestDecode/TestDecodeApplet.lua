
--[[
=head1 NAME

applets.Test.TestApplet - User Interface Tests

=head1 DESCRIPTION

This applets is used to test and demonstrate the jive.ui.* stuff.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
TestApplet overrides the following methods:

=cut
--]]


-- stuff we use
local setmetatable, tonumber, tostring = setmetatable, tonumber, tostring

local oo                     = require("loop.simple")
local string                 = require("string")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Group                  = require("jive.ui.Group")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Window                 = require("jive.ui.Window")

local Decode                 = require("squeezeplay.decode")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").addCategory("test", jive.utils.log.DEBUG)

local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME



module(...)
oo.class(_M, Applet)


function menu(self, menuItem)
	local values = {}
	for i=1,5 do
			values[i] = Label("value", "")
	end


	local menu = SimpleMenu("menu",
		{
--[[
			{ text = "VolUp",
				callback = function()
					sp:send({
							opcode = "IR  ",
							format = 1,
							noBits = 1,
							code = 0x7689807f,
						})
				end,
			},
			{ text = "VolDown",
				callback = function()
				sp:send({
							opcode = "IR  ",
							format = 1,
							noBits = 1,
							code = 0x768900ff,
						})
				end,
			},
--]]
			{ text = "State:", icon = values[1] },
			{ text = "Decode:", icon = values[2] },
			{ text = "Output:", icon = values[3] },
			{ text = "Elapsed:", icon = values[4] },
			{ text = "Tracks:", icon = values[5] },
			
			{ text = "Decode Stop",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					Decode:stop()
				end
			},
			{ text = "Decode Flush",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					Decode:flush()
				end
			},
			{ text = "Decode Pause",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					Decode:pause()
				end
			},
			{ text = "Decode Resume",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					Decode:resume()
				end
			},
			
			{ text = "Decode WMA",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					Decode:start(
						string.byte('w'), 0, 0, 0, 0, 0, 0
					)
				end
			},
			{ text = "Decode Tone Multitone",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					Decode:start(
						string.byte('t'), 0, 0, 0, 0, 0, 1
					)
				end
			},
			{ text = "Decode Tone Sine 44.1k",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					Decode:start(
						string.byte('t'), 0, 0, 0, 0, 0, 10
					)
				end
			},
			{ text = "Decode Tone Sine 48k",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					Decode:start(
						string.byte('t'), 0, 0, 0, 0, 0, 11
					)
				end
			},
			{ text = "Decode Tone Sine 88.2k",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					Decode:start(
						string.byte('t'), 0, 0, 0, 0, 0, 12
					)
				end
			},
			{ text = "Decode Tone Sine 96k",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					Decode:start(
						string.byte('t'), 0, 0, 0, 0, 0, 13
					)
				end
			},			

			-- XXXX pause and resume in interval
			-- XXXX resume at jiffies
			-- XXXX skip ahead interval
		})

	local window = Window("window", "Test Decode")
	window:addWidget(menu)

	window:addTimer(1000, function()
			local status = Decode:status()

			values[1]:setValue(status.decodeState .. " " .. status.audioState)
			values[2]:setValue(string.format('%0.2f', status.decodeFull / status.decodeSize * 100))
			values[3]:setValue(string.format('%0.2f', status.outputFull / status.outputSize * 100))
			values[4]:setValue(status.elapsed)
			values[5]:setValue(status.tracksStarted)
	end)

	window:show()
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

