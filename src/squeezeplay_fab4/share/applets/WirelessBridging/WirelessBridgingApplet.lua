
-- stuff we use
local tostring, unpack, pairs = tostring, unpack, pairs

local oo                     = require("loop.simple")
local io                     = require("io")
local os                     = require("os")
local math                   = require("math")
local string                 = require("string")

local Applet                 = require("jive.Applet")
local Checkbox               = require("jive.ui.Checkbox")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")
local Networking             = require("jive.net.Networking")

local jnt                    = jnt

module(..., Framework.constants)
oo.class(_M, Applet)


function settingsShow( self, menuItem)
	local window = Window( "text_list", menuItem.text, 'settingstitle')
	
	self.howto = Textarea( "help_text", self:string( "BRIDGE_HOWTO"))

	local menu = SimpleMenu( "menu", {
					{
						text = self:string( "BRIDGE_ENABLE"),
						style = 'item_choice',
						check = Checkbox( "checkbox",
								function( _, isSelected)
									if isSelected then
										self:_enableBridge()
									else
										self:_disableBridge()
									end
								end,
								self:_bridgeEnabled()
							)
					},
				})

	menu:setHeaderWidget( self.howto)
	window:addWidget( menu)

	self.window = window
	self.menu = menu

	self:tieAndShowWindow( window)
	return window
end


function _enableBridge(self, window)
	os.execute( "/etc/init.d/bridge start");
end


function _disableBridge(self, window)
	os.execute( "/etc/init.d/bridge stop");
end


function _bridgeEnabled()
	local bridge = _pidfor( 'dhcp%-fwd')
	
	if( bridge ~= nil) then
		return true
	end
	
	return false
end


function _pidfor( process)
	local pid

	local pattern = "%s*(%d+).*" .. process

	log:warn( "pattern is ", pattern)

	local cmd = io.popen( "/bin/ps -o pid,command")
	for line in cmd:lines() do
		pid = string.match( line, pattern)
		if pid then break end
	end
	cmd:close()

	return pid
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
