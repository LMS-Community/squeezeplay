
-- stuff we use
local tostring               = tostring
local oo                     = require("loop.simple")

local string                 = require("string")
local table                  = require("jive.utils.table")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Tile                   = require("jive.ui.Tile")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")

local log                    = require("jive.utils.log").logger("applets.setup")
local debug                  = require("jive.utils.debug")

local jnt                    = jnt

local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME

module(...)
oo.class(_M, Applet)

function forcePin(self, player)
	local window = Window("window", self:string("SQUEEZENETWORK_PIN_TITLE"), "settingstitle")
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu")
	menu:setCloseable(false)
	
	local slimServer = player.slimServer

	menu:addItem( {
		text     = self:string( "SQUEEZENETWORK_PIN", player:getPin() ),
		sound    = "WINDOWSHOW",
		callback = function()
			-- When the user clicks the button, ask SN if we're registered
			local uuid, mac = jnt:getUUID()
			local cmd = { 'islinked', uuid }
			
			local checkLinkedSink = function(chunk, err)
				if err then
					log:warn(err)
					return
				end

				if chunk.data.islinked and chunk.data.islinked == 1 then
					-- Jive is linked!
					log:debug("checkLinkedSink: Jive is linked")
					
					-- Reconnect to SN, refreshes the list of players
					slimServer:reconnect()
				
					-- close pin menu, back to main
					-- XXX: Not sure if this should so something more...
					menu:hide()
				else
					log:debug("checkLinkedSink: Jive is not linked yet")
			
					-- display error
					self:displayNotLinked()
				end
			end
			
			slimServer.comet:request( checkLinkedSink, nil, cmd )
		end
	} )

	-- XXX this is temporary until the :3000 "production" beta goes away by
	-- some means or other 
	local addport = "";
	if not jnt:getSNBeta() then
		addport = ":3000"
	end

	local help = Textarea("help", self:string("SQUEEZENETWORK_PIN_HELP", jnt:getSNHostname() .. addport))
	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end

function displayNotLinked(self)
	local window = Window("window", self:string("SQUEEZENETWORK_PIN_TITLE"), "settingstitle")
	window:setAllowScreensaver(false)

	local textarea = Textarea("textarea", self:string("SQUEEZENETWORK_NOT_LINKED"))

	window:addWidget(textarea)

	window:addListener(EVENT_KEY_PRESS,
		function(event)
			window:hide()

			return EVENT_CONSUME
		end
	)

	self:tieAndShowWindow(window)
	return window
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
