
-- stuff we use
local tostring               = tostring
local oo                     = require("loop.simple")

local string                 = require("string")
local table                  = require("jive.utils.table")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Tile                   = require("jive.ui.Tile")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")

local debug                  = require("jive.utils.debug")

local jnt                    = jnt

module(..., Framework.constants)
oo.class(_M, Applet)


function enterPin(self, server, player, next)
	self:_enterPin(false, server, player, next)
end


function forcePin(self, player)
	self:_enterPin(false, player:getSlimServer(), player)
end


function _enterPin(self, force, server, player, next)
	local window = Window("help_list", self:string("SQUEEZENETWORK_PIN_TITLE"), "settingstitle")
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu")
	if force then
		menu:setCloseable(false)
	end

	self.pin = player and player:getPin() or server:getPin()

	if not server then
		server = player:getSlimServer()
	end
	
	local nextfunc = function()
		-- Always close the pin entry window
		window:hide()
		if next then
			next()
		end
	end

	menu:addItem( {
		text     = self:string( "SQUEEZENETWORK_PIN", self.pin ),
		sound    = "WINDOWSHOW",
		callback = function()
			self:_checkLinked(server,
					  nextfunc,
					  function()
						  self:displayNotLinked()
					  end)
		end
	} )

	-- automatically check if we are linked every 5 seconds
	-- XXX check this is ok with Andy and Dean...
	menu:addTimer(5000,
		      function()
			      self:_checkLinked(server,
						nextfunc,
						nil)
		      end)

	menu:setHeaderWidget(Textarea("help_text", self:string("SQUEEZENETWORK_PIN_HELP", jnt:getSNHostname())))
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function _checkLinked(self, server, next, fail)
	-- When the user clicks the button, ask SN if we're registered
	local uuid = System:getUUID()
	local cmd = { 'islinked', uuid }

	local checkLinkedSink = function(chunk, err)
		if err then
			log:warn(err)
			return
		end

		if chunk.data.islinked and chunk.data.islinked == 1 then

			-- Jive is linked!
			log:debug("checkLinkedSink: Jive is linked")

			-- The pin will be cleared on the next serverstatus,
			-- but this is not instant, so clear the pin now
			server:linked(self.pin)
					
			-- Reconnect to SN, refreshes the list of players
			server:reconnect()
				
			if next then
				next()
			end
		else
			log:debug("checkLinkedSink: Jive is not linked yet")
			
			if fail then
				fail()
			end
		end
	end
			
	-- make sure the server is connected
	server:connect()

	server:userRequest( checkLinkedSink, nil, cmd )
end


function displayNotLinked(self)
	local window = Window("text_list", self:string("SQUEEZENETWORK_PIN_TITLE"), "settingstitle")
	window:setAllowScreensaver(false)

	local textarea = Textarea("text", self:string("SQUEEZENETWORK_NOT_LINKED"))

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("SQUEEZENETWORK_GO_BACK"),
						sound = "WINDOWHIDE",
						callback = function()
								   window:hide()
							   end
					},
				})


	window:addWidget(textarea)
	window:addWidget(menu)

	window:hideOnAllButtonInput()

	self:tieAndShowWindow(window)
	return window
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
