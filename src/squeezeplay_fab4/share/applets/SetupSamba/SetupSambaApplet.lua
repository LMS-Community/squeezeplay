
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
	
	self.howto = Textarea( "help_text", self:string( "SAMBA_HOWTO"))
	window:addWidget( self.howto)

	local menu = SimpleMenu( "menu", {
					{
						text = self:string( "SAMBA_ENABLE"),
						style = 'item_choice',
						check = Checkbox( "checkbox",
								function( _, isSelected)
									if isSelected then
										self:_enableSamba()
									else
										self:_disableSamba()
									end
								end,
								self:_sambaEnabled()
							)
					},
				})

	window:addWidget( menu)

	self.window = window
	self.menu = menu

	self:tieAndShowWindow( window)
	return window
end


function _enableSamba(self, window)
	os.execute( "/etc/init.d/samba start");
end


function _disableSamba(self, window)
	os.execute( "/etc/init.d/samba stop");
end


function _sambaEnabled()
	local samba = _pidfor( 'smb')
	
	if( samba ~= nil) then
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

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
