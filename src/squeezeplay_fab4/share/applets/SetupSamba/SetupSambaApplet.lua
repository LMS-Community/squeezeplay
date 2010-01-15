
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


function settingsShow(self, menuItem)
	local window = Window("help_text", menuItem.text, 'settingstitle')
	
	local sambaEnabled = _fileMatch("/etc/samba/status", "enabled")

	self.howto = Textarea("help_text", self:string("SAMBA_HOWTO"))
	
        local menu = SimpleMenu("menu", {
					{
						text = self:string("SAMBA_ENABLE"),
						style = 'item_choice',
						check = Checkbox("checkbox",
								function(_, isSelected)
									if isSelected then
										self:_enableSamba()
									else
										self:_disableSamba()
									end
								end,
								sambaEnabled
							)
					},
				})
				
	menu:setHeaderWidget(self.howto)
	window:addWidget(menu)

	self.window = window
	self.menu = menu

	self:tieAndShowWindow(window)
	return window
end


function _enableSamba(self, window)
	-- enable Samba	
	log:info("Enabling Samba Access")
	os.execute("echo enabled > /etc/samba/status");
	os.execute("/etc/init.d/samba restart");
end


function _disableSamba(self, window)
	-- disable Samba	
	log:info("Disabling Samba Access")
	os.execute("echo disabled > /etc/samba/status");
	os.execute("/etc/init.d/samba stop");
end

function _fileMatch(file, pattern)
	local fi = io.open(file, "r")

	for line in fi:lines() do
		if string.match(line, pattern) then
			fi:close()
			return true
		end
	end
	fi:close()
	
	return false
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
